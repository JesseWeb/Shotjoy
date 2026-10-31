import AppKit
import Carbon
import CoreGraphics
import ShotjoyCore

/// Tracks which pinned screenshot currently has focus and provides a global
/// Escape fallback while that pin is focused. Accessory apps cannot always
/// become the frontmost app just by clicking a borderless panel, so this keeps
/// Escape reliable without closing pins that are not focused.
final class PinFocusManager {
    static let shared = PinFocusManager()

    private weak var focused: PinWindowController?
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var resignObserver: NSObjectProtocol?

    private init() {
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resignAll()
        }
    }

    func focus(_ controller: PinWindowController) {
        focused = controller
        registerEscapeHotKey()
    }

    func resign(_ controller: PinWindowController) {
        guard focused === controller else { return }
        focused = nil
        unregisterEscapeHotKey()
    }

    func resignAll() {
        focused = nil
        unregisterEscapeHotKey()
    }

    private func registerEscapeHotKey() {
        guard hotKeyRef == nil else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let manager = Unmanaged<PinFocusManager>.fromOpaque(userData).takeUnretainedValue()
                manager.closeFocusedPin()
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
        guard installStatus == noErr else { return }

        let hotKeyID = EventHotKeyID(signature: OSType(0x5344_534B), id: 3)
        let status = RegisterEventHotKey(
            53,
            0,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if status != noErr {
            if let handler = handlerRef {
                RemoveEventHandler(handler)
                handlerRef = nil
            }
        }
    }

    private func unregisterEscapeHotKey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = handlerRef {
            RemoveEventHandler(handler)
            handlerRef = nil
        }
    }

    private func closeFocusedPin() {
        guard NSApp.isActive,
              let focused,
              focused.panel.isKeyWindow else { return }
        focused.close()
    }
}

final class PinPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class PinView: NSView {
    let image: CGImage
    weak var controller: PinWindowController?

    init(image: CGImage, controller: PinWindowController) {
        self.image = image
        self.controller = controller
        super.init(frame: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.35).cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        CGDrawing.drawImage(image, in: bounds, context: context, flipped: true)
        if window?.isKeyWindow == true {
            context.setStrokeColor(NSColor.systemBlue.cgColor)
            context.setLineWidth(2)
            context.stroke(bounds.insetBy(dx: 1, dy: 1))
        }
    }

    override func becomeFirstResponder() -> Bool {
        needsDisplay = true
        if let controller { PinFocusManager.shared.focus(controller) }
        return true
    }

    override func resignFirstResponder() -> Bool {
        needsDisplay = true
        if let controller { PinFocusManager.shared.resign(controller) }
        return true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Esc
            controller?.close()
            return
        }
        super.keyDown(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        controller?.close()
    }

    override func mouseDown(with event: NSEvent) {
        // Clicking a pin focuses it. Escape only closes the pin that has focus.
        NSApp.activate()
        _ = NSRunningApplication.current.activate(options: [.activateAllWindows])
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(self)
        if let controller { PinFocusManager.shared.focus(controller) }
        if event.clickCount >= 2 {
            controller?.close()
        } else {
            window?.performDrag(with: event)
        }
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        let copy = NSMenuItem(title: L10n.copy, action: #selector(copyImage), keyEquivalent: "")
        copy.target = self
        menu.addItem(copy)
        let save = NSMenuItem(title: L10n.save, action: #selector(saveImage), keyEquivalent: "")
        save.target = self
        menu.addItem(save)
        menu.addItem(.separator())
        let close = NSMenuItem(title: L10n.close, action: #selector(closeWindow), keyEquivalent: "")
        close.target = self
        menu.addItem(close)
        return menu
    }

    @objc private func copyImage() {
        controller?.copy()
    }

    @objc private func saveImage() {
        controller?.save()
    }

    @objc private func closeWindow() {
        controller?.close()
    }
}

final class PinWindowController {
    private(set) var panel: PinPanel
    private let image: CGImage
    private var onClose: (() -> Void)?
    private var isClosing = false

    init(image: CGImage, onClose: (() -> Void)? = nil) {
        self.image = image
        self.onClose = onClose

        let scale = NSScreen.main?.backingScaleFactor ?? 2
        var size = CGSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
        if let visible = NSScreen.main?.visibleFrame {
            let maxWidth = visible.width * 0.8
            let maxHeight = visible.height * 0.8
            let fit = min(1, min(maxWidth / size.width, maxHeight / size.height))
            size = CGSize(width: size.width * fit, height: size.height * fit)
        }

        panel = PinPanel(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false

        let view = PinView(image: image, controller: self)
        view.frame = CGRect(origin: .zero, size: size)
        view.autoresizingMask = [.width, .height]
        panel.contentView = view

        if let visible = NSScreen.main?.visibleFrame {
            let x = visible.midX - size.width / 2 + CGFloat.random(in: -30...30)
            let y = visible.midY - size.height / 2 + CGFloat.random(in: -30...30)
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    func show() {
        panel.orderFrontRegardless()
    }

    func close() {
        guard !isClosing else { return }
        isClosing = true
        PinFocusManager.shared.resign(self)
        panel.orderOut(nil)
        panel.close()
        onClose?()
    }

    func copy() {
        ImageExporter.copyToPasteboard(image)
    }

    func save() {
        ImageExporter.presentSavePanel(
            for: image,
            defaultDirectory: Preferences.shared.lastSaveDirectory ?? Preferences.shared.defaultSaveDirectory
        ) { url in
            if let url {
                Preferences.shared.lastSaveDirectory = url.deletingLastPathComponent()
            }
        }
    }
}
