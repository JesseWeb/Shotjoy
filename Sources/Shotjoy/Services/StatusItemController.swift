import AppKit
import ShotjoyCore

final class StatusItemController: NSObject {
    var onCapture: (() -> Void)?
    var onPinLast: (() -> Void)?
    var onSaveLast: (() -> Void)?
    var onRecognizeLast: (() -> Void)?
    var onScanLast: (() -> Void)?
    var onSettings: (() -> Void)?
    var onFixPermission: (() -> Void)?
    var onCheckPermission: (() -> Void)?
    var onAbout: (() -> Void)?
    var onQuit: (() -> Void)?

    private let statusItem: NSStatusItem
    private var shortcutTitle = HotKeyConfig.default.displayString

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "viewfinder", accessibilityDescription: "Shotjoy")
            image?.isTemplate = true
            button.image = image
            button.imagePosition = .imageOnly
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            _ = button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "Shotjoy — \(L10n.screenshot) (⌃⌘A)"
        }
    }

    deinit {
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func updateShortcut(_ shortcut: HotKeyConfig) {
        shortcutTitle = shortcut.displayString
        statusItem.button?.toolTip = "Shotjoy — \(L10n.screenshot) (\(shortcutTitle))"
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showMenu(from: sender)
        } else {
            onCapture?()
        }
    }

    private func showMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()

        let capture = NSMenuItem(
            title: "\(L10n.screenshot) (\(shortcutTitle))",
            action: #selector(captureAction),
            keyEquivalent: ""
        )
        capture.target = self
        menu.addItem(capture)

        let pin = NSMenuItem(title: L10n.pinLast, action: #selector(pinAction), keyEquivalent: "")
        pin.target = self
        menu.addItem(pin)

        let save = NSMenuItem(title: L10n.saveLast, action: #selector(saveAction), keyEquivalent: "")
        save.target = self
        menu.addItem(save)

        menu.addItem(.separator())

        let text = NSMenuItem(title: L10n.recognizeText, action: #selector(recognizeAction), keyEquivalent: "")
        text.target = self
        menu.addItem(text)

        let qr = NSMenuItem(title: L10n.scanQRCode, action: #selector(scanAction), keyEquivalent: "")
        qr.target = self
        menu.addItem(qr)

        menu.addItem(.separator())

        let settings = NSMenuItem(title: L10n.settings, action: #selector(settingsAction), keyEquivalent: ",")
        settings.keyEquivalentModifierMask = [.command]
        settings.target = self
        menu.addItem(settings)

        let fix = NSMenuItem(title: L10n.fixScreenPermission, action: #selector(fixPermissionAction), keyEquivalent: "")
        fix.target = self
        menu.addItem(fix)

        let check = NSMenuItem(title: L10n.checkPermission, action: #selector(checkPermissionAction), keyEquivalent: "")
        check.target = self
        menu.addItem(check)

        menu.addItem(.separator())

        let about = NSMenuItem(title: L10n.about, action: #selector(aboutAction), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        let quit = NSMenuItem(title: L10n.quit, action: #selector(quitAction), keyEquivalent: "q")
        quit.keyEquivalentModifierMask = [.command]
        quit.target = self
        menu.addItem(quit)

        menu.popUp(
            positioning: nil,
            at: NSPoint(x: 0, y: button.bounds.height + 4),
            in: button
        )
    }

    @objc private func captureAction() { onCapture?() }
    @objc private func pinAction() { onPinLast?() }
    @objc private func saveAction() { onSaveLast?() }
    @objc private func recognizeAction() { onRecognizeLast?() }
    @objc private func scanAction() { onScanLast?() }
    @objc private func settingsAction() { onSettings?() }
    @objc private func fixPermissionAction() { onFixPermission?() }
    @objc private func checkPermissionAction() { onCheckPermission?() }
    @objc private func aboutAction() { onAbout?() }
    @objc private func quitAction() { onQuit?() }
}
