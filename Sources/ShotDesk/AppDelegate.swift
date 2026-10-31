import AppKit
import CoreGraphics
import ShotDeskCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = Preferences.shared
    private let hotKeyManager = HotKeyManager()

    private var statusController: StatusItemController?
    private var settingsController: SettingsWindowController?
    private var settingsModel: SettingsModel?
    private var captureSession: CaptureSession?
    private var scrollController: ScrollingCaptureController?
    private var previewController: PreviewWindowController?
    private var pinWindows: [PinWindowController] = []

    private var previousApp: NSRunningApplication?
    private var lastImage: CGImage?
    private var lastURL: URL?
    private var isCapturing = false
    private var didShowHotKeyWarning = false

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = NSApp.setActivationPolicy(.accessory)

        let model = SettingsModel()
        model.onShortcutChange = { [weak self] shortcut in
            self?.applyShortcut(shortcut) ?? false
        }
        model.onOpenPermission = {
            ScreenCaptureService.openPermissionSettings()
        }
        model.onResetPermission = { [weak self] in
            self?.resetScreenPermission()
        }
        model.onLoginChange = { [weak self] enabled in
            do {
                try LaunchAtLogin.setEnabled(enabled)
            } catch {
                self?.presentError(L10n.launchAtLogin, error)
            }
        }
        settingsModel = model
        settingsController = SettingsWindowController(model: model)

        let status = StatusItemController()
        status.onCapture = { [weak self] in self?.beginCapture() }
        status.onPinLast = { [weak self] in self?.pinLast() }
        status.onSaveLast = { [weak self] in self?.saveLast() }
        status.onRecognizeLast = { [weak self] in self?.recognizeLast() }
        status.onScanLast = { [weak self] in self?.scanLast() }
        status.onSettings = { [weak self] in self?.settingsController?.show() }
        status.onFixPermission = { [weak self] in self?.resetScreenPermission() }
        status.onCheckPermission = { [weak self] in self?.checkPermission() }
        status.onAbout = { [weak self] in self?.showAbout() }
        status.onQuit = { NSApp.terminate(nil) }
        statusController = status
        status.updateShortcut(preferences.shortcut)

        hotKeyManager.onHotKey = { [weak self] in self?.beginCapture() }
        if !hotKeyManager.register(preferences.shortcut) {
            showHotKeyWarningOnce()
        }

        let arguments = CommandLine.arguments
        if arguments.contains("--status") {
            writeDebugStatus()
            NSApp.terminate(nil)
        } else if arguments.contains("--capture-test") {
            try? "start permission=\(ScreenCaptureService.hasPermission)"
                .write(to: URL(fileURLWithPath: "/tmp/shotdesk-capture-test.txt"), atomically: true, encoding: .utf8)
            Task { @MainActor in
                do {
                    let screens = try await ScreenCaptureService.captureAll()
                    if let first = screens.first,
                       let data = ImageExporter.pngData(first.image) {
                        try? data.write(to: URL(fileURLWithPath: "/tmp/shotdesk-capture-test.png"))

                        let session = CaptureSession(screens: [first])
                        let selection = CGRect(
                            x: first.bounds.midX - min(400, first.bounds.width / 3),
                            y: first.bounds.midY - min(300, first.bounds.height / 3),
                            width: min(800, first.bounds.width * 0.66),
                            height: min(600, first.bounds.height * 0.66)
                        )
                        session.setSelectionForTesting(selection)
                        session.addAnnotationForTesting(
                            Annotation(
                                kind: .rectangle,
                                start: CGPoint(x: selection.minX + 20, y: selection.minY + 20),
                                end: CGPoint(x: selection.maxX - 20, y: selection.maxY - 20),
                                color: .yellow
                            )
                        )
                        if let rendered = session.renderFinalImage(includeAnnotations: true),
                           let renderedData = ImageExporter.pngData(rendered) {
                            try? renderedData.write(to: URL(fileURLWithPath: "/tmp/shotdesk-render-real.png"))
                        }
                    }
                    try? "captured=\(screens.count) \(screens.map { "\($0.image.width)x\($0.image.height)@\($0.scale)" }.joined(separator: " | "))"
                        .write(to: URL(fileURLWithPath: "/tmp/shotdesk-capture-test.txt"), atomically: true, encoding: .utf8)
                } catch {
                    try? "error=\(error.localizedDescription)"
                        .write(to: URL(fileURLWithPath: "/tmp/shotdesk-capture-test.txt"), atomically: true, encoding: .utf8)
                }
                NSApp.terminate(nil)
            }
        } else if arguments.contains("--self-test") {
            runRenderSelfTest()
            NSApp.terminate(nil)
        } else if arguments.contains("--capture") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.beginCapture()
            }
        } else if arguments.contains("--demo-overlay") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.startDemoOverlay()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyManager.unregister()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - Capture

    private func beginCapture() {
        guard !isCapturing else { return }
        isCapturing = true

        if !ScreenCaptureService.hasPermission {
            let granted = ScreenCaptureService.requestPermission()
            if !granted {
                isCapturing = false
                showPermissionAlert()
                return
            }
        }

        let front = NSWorkspace.shared.frontmostApplication
        if front?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApp = front
        }
        settingsController?.close()

        Task { @MainActor in
            do {
                let screens = try await ScreenCaptureService.captureAll()
                self.startCaptureSession(with: screens)
            } catch {
                self.isCapturing = false
                self.presentError(L10n.screenshot, error)
            }
        }
    }

    private func startCaptureSession(with screens: [CapturedScreen]) {
        guard !screens.isEmpty else {
            isCapturing = false
            return
        }
        let session = CaptureSession(screens: screens)
        captureSession = session
        session.onFinish = { [weak self] image, action in
            self?.handleFinish(image: image, action: action)
        }
        session.onCancel = { [weak self] in
            self?.isCapturing = false
            self?.captureSession = nil
            self?.restorePreviousApp()
        }
        session.onAnalyze = { [weak self] image, action in
            self?.isCapturing = false
            self?.captureSession = nil
            self?.analyze(image: image, action: action)
        }
        session.onScroll = { [weak self] selection, displayID in
            self?.startScrollingCapture(selection: selection, displayID: displayID)
        }
        session.start()
    }

    private func handleFinish(image: CGImage, action: FinishAction) {
        isCapturing = false
        captureSession = nil
        lastImage = image

        if preferences.playSound {
            NSSound(named: "Tink")?.play()
        }

        switch action {
        case .copy:
            if preferences.copyAfterCapture {
                ImageExporter.copyToPasteboard(image)
            }
            if preferences.saveToDesktop {
                saveToDesktop(image)
            }
            restorePreviousApp()
        case .save:
            NSApp.activate()
            ImageExporter.presentSavePanel(
                for: image,
                defaultDirectory: preferences.lastSaveDirectory ?? preferences.defaultSaveDirectory
            ) { [weak self] url in
                if let url {
                    self?.lastURL = url
                    self?.preferences.lastSaveDirectory = url.deletingLastPathComponent()
                }
                self?.restorePreviousApp()
            }
        case .pin:
            if preferences.copyAfterCapture {
                ImageExporter.copyToPasteboard(image)
            }
            pin(image)
            restorePreviousApp()
        }
    }

    private func restorePreviousApp() {
        guard let previousApp else { return }
        _ = previousApp.activate(options: [.activateAllWindows])
        self.previousApp = nil
    }

    // MARK: - Scrolling capture

    private func startScrollingCapture(selection: CGRect, displayID: CGDirectDisplayID) {
        isCapturing = false
        captureSession = nil
        if let previousApp {
            _ = previousApp.activate(options: [.activateAllWindows])
        }

        let controller = ScrollingCaptureController()
        scrollController = controller
        controller.start(
            selection: selection,
            displayID: displayID,
            onFinish: { [weak self] image in
                self?.scrollController = nil
                self?.handleLongScreenshot(image)
            },
            onCancel: { [weak self] in
                self?.scrollController = nil
            }
        )
    }

    private func handleLongScreenshot(_ image: CGImage) {
        lastImage = image
        if preferences.copyAfterCapture {
            ImageExporter.copyToPasteboard(image)
        }
        if preferences.playSound {
            NSSound(named: "Tink")?.play()
        }
        if preferences.saveToDesktop {
            saveToDesktop(image)
        }
        showPreview(image: image)
    }

    // MARK: - Last screenshot actions

    private func pinLast() {
        guard let lastImage else {
            showNoScreenshotAlert()
            return
        }
        pin(lastImage)
    }

    private func saveLast() {
        guard let lastImage else {
            showNoScreenshotAlert()
            return
        }
        NSApp.activate()
        ImageExporter.presentSavePanel(
            for: lastImage,
            defaultDirectory: preferences.lastSaveDirectory ?? preferences.defaultSaveDirectory
        ) { [weak self] url in
            if let url {
                self?.lastURL = url
                self?.preferences.lastSaveDirectory = url.deletingLastPathComponent()
            }
        }
    }

    private func recognizeLast() {
        guard let lastImage else {
            showNoScreenshotAlert()
            return
        }
        analyze(image: lastImage, action: .text)
    }

    private func scanLast() {
        guard let lastImage else {
            showNoScreenshotAlert()
            return
        }
        analyze(image: lastImage, action: .qrCode)
    }

    private func pin(_ image: CGImage) {
        let pin = PinWindowController(image: image)
        pinWindows.append(pin)
        pin.show()
        pinWindows.removeAll { !$0.panel.isVisible }
    }

    private func saveToDesktop(_ image: CGImage) {
        do {
            let url = ImageNaming.uniqueURL(directory: preferences.defaultSaveDirectory)
            try ImageExporter.save(image, to: url)
            lastURL = url
        } catch {
            presentError(L10n.save, error)
        }
    }

    // MARK: - Analysis

    private func analyze(image: CGImage, action: AnalyzeAction) {
        switch action {
        case .text:
            VisionAnalyzer.recognizeText(in: image) { [weak self] text in
                guard let self else { return }
                guard !text.isEmpty else {
                    self.showInfo(L10n.recognizeText, L10n.noText)
                    return
                }
                self.copyText(text)
                self.showTextPreview(text, title: L10n.recognizeText)
            }
        case .qrCode:
            VisionAnalyzer.detectQRCode(in: image) { [weak self] values in
                guard let self else { return }
                guard let first = values.first else {
                    self.showInfo(L10n.scanQRCode, L10n.noQRCode)
                    return
                }
                self.copyText(first)
                self.showTextPreview(values.joined(separator: "\n\n"), title: L10n.scanQRCode)
            }
        }
    }

    private func copyText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func showPreview(image: CGImage) {
        previewController?.close()
        let controller = PreviewWindowController()
        previewController = controller
        controller.showImage(
            image,
            title: "\(L10n.longScreenshot) · \(image.width) × \(image.height)",
            onCopy: { ImageExporter.copyToPasteboard(image) },
            onSave: {
                ImageExporter.presentSavePanel(
                    for: image,
                    defaultDirectory: Preferences.shared.lastSaveDirectory ?? Preferences.shared.defaultSaveDirectory
                ) { _ in }
            },
            onPin: { [weak self] in self?.pin(image) }
        )
    }

    private func showTextPreview(_ text: String, title: String) {
        previewController?.close()
        let controller = PreviewWindowController()
        previewController = controller
        controller.showText(text, title: title) { [weak self] in
            self?.copyText(text)
        }
    }

    // MARK: - Permission and alerts

    private func showPermissionAlert() {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = L10n.permissionTitle
        alert.informativeText = L10n.permissionBody
        alert.addButton(withTitle: L10n.openSettings)
        alert.addButton(withTitle: L10n.retry)
        alert.addButton(withTitle: L10n.cancel)
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            ScreenCaptureService.openPermissionSettings()
        case .alertSecondButtonReturn:
            beginCapture()
        default:
            break
        }
    }

    private func checkPermission() {
        if ScreenCaptureService.hasPermission {
            showInfo(L10n.checkPermission, L10n.t("已获得屏幕录制权限。", "Screen Recording permission is granted."))
        } else {
            showPermissionAlert()
        }
    }

    private func resetScreenPermission() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", "ScreenCapture", "dev.shotdesk.ShotDesk"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        ScreenCaptureService.openPermissionSettings()
        settingsModel?.refresh()
    }

    private func applyShortcut(_ shortcut: HotKeyConfig) -> Bool {
        let previous = hotKeyManager.currentConfig ?? preferences.shortcut
        if hotKeyManager.register(shortcut) {
            preferences.shortcut = shortcut
            statusController?.updateShortcut(shortcut)
            return true
        }
        _ = hotKeyManager.register(previous)
        showHotKeyWarningOnce(force: true)
        return false
    }

    private func showHotKeyWarningOnce(force: Bool = false) {
        if !force && didShowHotKeyWarning { return }
        didShowHotKeyWarning = true
        showInfo(L10n.hotKeyFailed, L10n.hotKeyFailedBody)
    }

    private func showNoScreenshotAlert() {
        showInfo(L10n.screenshot, L10n.t("还没有截图。按 ⌃⌘A 开始截图。", "No screenshot yet. Press ⌃⌘A to take one."))
    }

    private func showInfo(_ title: String, _ body: String) {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func presentError(_ title: String, _ error: Error) {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Debug helpers

    private func writeDebugStatus() {
        let status = """
        permission=\(ScreenCaptureService.hasPermission)
        hotkeyRegistered=\(hotKeyManager.currentConfig != nil)
        shortcut=\(preferences.shortcut.displayString)
        bundle=\(Bundle.main.bundleIdentifier ?? "?")
        path=\(Bundle.main.bundlePath)
        """
        try? status.write(to: URL(fileURLWithPath: "/tmp/shotdesk-status.txt"), atomically: true, encoding: .utf8)
    }

    private func startDemoOverlay() {
        isCapturing = true
        var screens: [CapturedScreen] = []
        for (index, screen) in NSScreen.screens.enumerated() {
            let id = ScreenCaptureService.displayID(for: screen)
            let bounds = CGDisplayBounds(id)
            let scale = screen.backingScaleFactor
            let pixelWidth = Int(bounds.width * scale)
            let pixelHeight = Int(bounds.height * scale)
            guard let image = makeDemoScreenImage(
                width: pixelWidth,
                height: pixelHeight,
                index: index,
                name: screen.localizedName
            ) else { continue }
            screens.append(CapturedScreen(displayID: id, bounds: bounds, scale: scale, image: image))
        }
        guard !screens.isEmpty else { return }
        let session = CaptureSession(screens: screens)
        captureSession = session
        if let first = screens.first {
            let selection = CGRect(
                x: first.bounds.minX + first.bounds.width * 0.18,
                y: first.bounds.minY + first.bounds.height * 0.22,
                width: first.bounds.width * 0.56,
                height: first.bounds.height * 0.42
            )
            session.setSelectionForTesting(selection)
            session.addAnnotationForTesting(
                Annotation(
                    kind: .rectangle,
                    start: CGPoint(x: selection.minX + 24, y: selection.minY + 24),
                    end: CGPoint(x: selection.minX + 220, y: selection.minY + 160),
                    color: .yellow
                )
            )
            session.addAnnotationForTesting(
                Annotation(
                    kind: .arrow,
                    start: CGPoint(x: selection.minX + 80, y: selection.maxY - 60),
                    end: CGPoint(x: selection.maxX - 80, y: selection.minY + 90),
                    color: .red,
                    lineWidth: 4
                )
            )
        }
        session.onCancel = { [weak self] in
            self?.isCapturing = false
            self?.captureSession = nil
        }
        session.onFinish = { [weak self] image, action in
            ImageExporter.copyToPasteboard(image)
            self?.isCapturing = false
            self?.captureSession = nil
        }
        session.start()
        session.showToolbarForTesting()
    }

    private func makeDemoScreenImage(width: Int, height: Int, index: Int, name: String) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        let top = NSColor(srgbRed: 0.11, green: 0.42, blue: 0.85, alpha: 1)
        let bottom = NSColor(srgbRed: 0.06, green: 0.66, blue: 0.62, alpha: 1)
        let gradient = CGGradient(
            colorsSpace: space,
            colors: [top.cgColor, bottom.cgColor] as CFArray,
            locations: [0, 1]
        )!
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: CGFloat(width), y: CGFloat(height)),
            options: []
        )
        for row in 0..<8 {
            for column in 0..<12 {
                context.setFillColor(NSColor.white.withAlphaComponent(row % 2 == 0 ? 0.06 : 0.03).cgColor)
                context.fill(
                    CGRect(
                        x: CGFloat(column) * CGFloat(width) / 12,
                        y: CGFloat(row) * CGFloat(height) / 8,
                        width: CGFloat(width) / 12 - 2,
                        height: CGFloat(height) / 8 - 2
                    )
                )
            }
        }
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: CGFloat(height) * 0.055, weight: .bold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.92),
            .paragraphStyle: paragraph
        ]
        NSAttributedString(string: "ShotDesk · \(name) · \(index + 1)", attributes: attributes)
            .draw(in: CGRect(x: 0, y: CGFloat(height) * 0.42, width: CGFloat(width), height: CGFloat(height) * 0.12))
        return context.makeImage()
    }

    private func runRenderSelfTest() {
        try? "start".write(to: URL(fileURLWithPath: "/tmp/shotdesk-status.txt"), atomically: true, encoding: .utf8)
        let width = 400
        let height = 300
        let scale = 2
        guard let image = makeTestImage(width: width * scale, height: height * scale) else {
            try? "image nil".write(to: URL(fileURLWithPath: "/tmp/shotdesk-status.txt"), atomically: true, encoding: .utf8)
            return
        }
        try? "image ok".write(to: URL(fileURLWithPath: "/tmp/shotdesk-status.txt"), atomically: true, encoding: .utf8)
        let screen = CapturedScreen(
            displayID: CGMainDisplayID(),
            bounds: CGRect(x: 0, y: 0, width: width, height: height),
            scale: CGFloat(scale),
            image: image
        )
        let session = CaptureSession(screens: [screen])
        session.setSelectionForTesting(screen.bounds)
        session.addAnnotationForTesting(
            Annotation(
                kind: .rectangle,
                start: CGPoint(x: 30, y: 40),
                end: CGPoint(x: 200, y: 160),
                color: .yellow,
                lineWidth: 3
            )
        )
        session.addAnnotationForTesting(
            Annotation(
                kind: .arrow,
                start: CGPoint(x: 60, y: 220),
                end: CGPoint(x: 330, y: 100),
                color: .red,
                lineWidth: 4
            )
        )
        session.addAnnotationForTesting(
            Annotation(
                kind: .text,
                start: CGPoint(x: 40, y: 250),
                text: "ShotDesk 测试",
                color: .white
            )
        )
        session.addAnnotationForTesting(
            Annotation(
                kind: .mosaic,
                start: CGPoint(x: 230, y: 180),
                end: CGPoint(x: 360, y: 250),
                color: .white,
                lineWidth: 10
            )
        )
        guard let output = session.renderFinalImage(includeAnnotations: true) else {
            try? "output nil".write(to: URL(fileURLWithPath: "/tmp/shotdesk-status.txt"), atomically: true, encoding: .utf8)
            return
        }
        let saved = (try? ImageExporter.save(output, to: URL(fileURLWithPath: "/tmp/shotdesk-render-test.png"))) != nil
        let status = "rendered=\(output.width)x\(output.height) saved=\(saved)\n"
        try? status.write(to: URL(fileURLWithPath: "/tmp/shotdesk-status.txt"), atomically: true, encoding: .utf8)
    }

    private func makeTestImage(width: Int, height: Int) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        let colors: [NSColor] = [
            .systemTeal, .systemIndigo, .systemOrange, .systemPink,
            .systemGreen, .systemBlue
        ]
        let columns = 3
        let rows = 2
        let cellW = CGFloat(width) / CGFloat(columns)
        let cellH = CGFloat(height) / CGFloat(rows)
        for row in 0..<rows {
            for column in 0..<columns {
                context.setFillColor(colors[row * columns + column].cgColor)
                context.fill(
                    CGRect(
                        x: CGFloat(column) * cellW,
                        y: CGFloat(row) * cellH,
                        width: cellW,
                        height: cellH
                    )
                )
            }
        }
        context.setFillColor(NSColor.black.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: CGFloat(width), height: 24))
        context.fill(CGRect(x: 0, y: CGFloat(height) - 24, width: CGFloat(width), height: 24))
        return context.makeImage()
    }

    private func showAbout() {
        NSApp.activate()
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let alert = NSAlert()
        alert.messageText = "ShotDesk \(version)"
        alert.informativeText = L10n.t(
            "一个受微信截图工作流启发的 macOS 截图工具。\n\n快捷键：\(preferences.shortcut.displayString)\n屏幕录制权限由 macOS 管理。",
            "A macOS screenshot tool inspired by WeChat's capture workflow.\n\nShortcut: \(preferences.shortcut.displayString)\nScreen Recording is managed by macOS."
        )
        alert.icon = NSApp.applicationIconImage
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
