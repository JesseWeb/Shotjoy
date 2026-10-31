import AppKit
import CoreGraphics
import ShotjoyCore
import SwiftUI

final class ScrollingCaptureController {
    private let model = ScrollingHUDModel()
    private var panel: NSPanel?
    private var timer: Timer?
    private var frames: [CGImage] = []
    private var signatures: [RowSignature] = []
    private var isCapturingFrame = false
    private var selection: CGRect = .zero
    private var onFinish: ((CGImage) -> Void)?
    private var onCancel: (() -> Void)?
    private var isFinished = false

    func start(
        selection: CGRect,
        displayID: CGDirectDisplayID,
        onFinish: @escaping (CGImage) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.selection = selection
        self.onFinish = onFinish
        self.onCancel = onCancel
        self.frames = []
        self.signatures = []
        self.isFinished = false

        model.frameCount = 0
        model.onDone = { [weak self] in self?.finish() }
        model.onCancel = { [weak self] in self?.cancel() }

        let panel = NSPanel(
            contentRect: CGRect(x: 0, y: 0, width: 368, height: 82),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 3)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.contentView = NSHostingView(rootView: ScrollingHUDView(model: model))
        position(panel)
        panel.orderFrontRegardless()
        self.panel = panel

        captureFrame()
        timer = Timer.scheduledTimer(withTimeInterval: 0.32, repeats: true) { [weak self] _ in
            self?.captureFrame()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func position(_ panel: NSPanel) {
        let mainHeight = NSScreen.main?.frame.height ?? 0
        let cocoa = GlobalCoordinates.quartzToCocoa(selection, mainScreenHeight: mainHeight)
        let screen = NSScreen.screens.first(where: { $0.frame.intersects(cocoa) }) ?? NSScreen.main
        let visible = screen?.visibleFrame ?? cocoa
        let size = panel.frame.size
        var x = cocoa.midX - size.width / 2
        var y = cocoa.maxY + 10
        if y + size.height > visible.maxY - 6 {
            y = cocoa.minY - size.height - 10
        }
        if y < visible.minY + 6 {
            y = visible.maxY - size.height - 6
        }
        x = max(visible.minX + 8, min(x, visible.maxX - size.width - 8))
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func captureFrame() {
        guard !isCapturingFrame, !isFinished else { return }
        isCapturingFrame = true
        let rect = selection
        Task { @MainActor [weak self] in
            let image = try? await ScreenCaptureService.capture(rect: rect)
            guard let self, !self.isFinished else { return }
            self.isCapturingFrame = false
            guard let image else { return }
            self.add(image)
        }
    }

    private func add(_ image: CGImage) {
        let signature = makeSignature(image)
        guard !signature.rows.isEmpty else { return }

        if let last = signatures.last, last.rows == signature.rows {
            // The page has not moved; do not accumulate duplicate frames.
            return
        }

        frames.append(image)
        signatures.append(signature)
        model.frameCount = frames.count
    }

    private func makeSignature(_ image: CGImage) -> RowSignature {
        let targetWidth = min(320, max(16, image.width))
        let targetHeight = max(1, Int((Double(image.height) * Double(targetWidth) / Double(image.width)).rounded()))
        var gray = [UInt8](repeating: 0, count: targetWidth * targetHeight)
        gray.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: targetWidth,
                height: targetHeight,
                bitsPerComponent: 8,
                bytesPerRow: targetWidth,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: 0
            ) else { return }
            context.interpolationQuality = .low
            context.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        }
        return FrameStitcher.signature(gray: gray, width: targetWidth, height: targetHeight)
    }

    private func finish() {
        guard !isFinished else { return }
        isFinished = true
        timer?.invalidate()
        timer = nil
        panel?.orderOut(nil)
        panel?.close()
        panel = nil

        guard let first = frames.first else {
            onCancel?()
            return
        }

        let plan = FrameStitcher.plan(signatures: signatures)
        if frames.count > 1 && plan.overlaps.allSatisfy({ $0 == 0 }) {
            showError(L10n.stitchFailed)
            onCancel?()
            return
        }

        let width = frames.map(\.width).max() ?? first.width
        let scale = Double(width) / Double(signatures[0].width)
        var offsets: [Int] = []
        for (index, _) in signatures.enumerated() {
            offsets.append(Int((Double(plan.offsets[index]) * scale).rounded()))
        }
        let lastIndex = frames.count - 1
        let height = offsets[lastIndex] + frames[lastIndex].height

        guard width > 0, height > 0, height <= 30_000, width * height <= 120_000_000 else {
            showError(L10n.t("截图过长，无法拼接", "The screenshot is too long to stitch."))
            onCancel?()
            return
        }

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            onCancel?()
            return
        }
        context.interpolationQuality = .high
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        for (index, image) in frames.enumerated() {
            let destination = CGRect(
                x: 0,
                y: offsets[index],
                width: width,
                height: image.height
            )
            CGDrawing.drawImage(image, in: destination, context: context, flipped: true)
        }
        guard let result = context.makeImage() else {
            onCancel?()
            return
        }
        onFinish?(result)
    }

    private func cancel() {
        guard !isFinished else { return }
        isFinished = true
        timer?.invalidate()
        timer = nil
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
        onCancel?()
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = L10n.longScreenshot
        alert.informativeText = message
        alert.runModal()
    }
}
