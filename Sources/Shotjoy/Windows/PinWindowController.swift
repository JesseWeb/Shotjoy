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
    let padding: CGFloat
    weak var controller: PinWindowController?

    init(image: CGImage, controller: PinWindowController, padding: CGFloat) {
        self.image = image
        self.controller = controller
        self.padding = padding
        super.init(frame: .zero)
        wantsLayer = true
    }

    private var imageRect: CGRect {
        bounds.insetBy(dx: padding, dy: padding)
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
        let rect = imageRect
        let path = NSBezierPath(roundedRect: rect, xRadius: 9, yRadius: 9)

        // Blue glow around the image itself, not around the whole window: a
        // tight rim, a mid halo and a wide bloom so it reads on dark and light
        // backgrounds.
        context.saveGState()
        NSColor.black.setFill()
        context.setShadow(
            offset: .zero,
            blur: 5,
            color: NSColor(srgbRed: 0.48, green: 0.78, blue: 1.0, alpha: 0.70).cgColor
        )
        path.fill()
        context.setShadow(
            offset: .zero,
            blur: 14,
            color: NSColor(srgbRed: 0.36, green: 0.68, blue: 1.0, alpha: 0.50).cgColor
        )
        path.fill()
        context.setShadow(
            offset: .zero,
            blur: 26,
            color: NSColor(srgbRed: 0.28, green: 0.58, blue: 1.0, alpha: 0.30).cgColor
        )
        path.fill()
        context.restoreGState()

        context.saveGState()
        path.addClip()
        CGDrawing.drawImage(image, in: rect, context: context, flipped: true)
        context.restoreGState()

        path.lineWidth = 1
        NSColor.white.withAlphaComponent(0.32).setStroke()
        path.stroke()

        if window?.isKeyWindow == true {
            let focusPath = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: 8, yRadius: 8)
            focusPath.lineWidth = 2
            NSColor.systemBlue.setStroke()
            focusPath.stroke()
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

    init(image: CGImage, preferredRect: CGRect? = nil, onClose: (() -> Void)? = nil) {
        self.image = image
        self.onClose = onClose

        let padding: CGFloat = 34
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        let cocoaPreferred: CGRect? = preferredRect.map {
            GlobalCoordinates.quartzToCocoa($0, mainScreenHeight: mainHeight)
        }

        var imageSize: CGSize
        if let cocoaPreferred {
            imageSize = cocoaPreferred.size
        } else {
            let scale = NSScreen.main?.backingScaleFactor ?? 2
            imageSize = CGSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
            if let visible = NSScreen.main?.visibleFrame {
                let maxWidth = visible.width * 0.8
                let maxHeight = visible.height * 0.8
                let fit = min(1, min(maxWidth / imageSize.width, maxHeight / imageSize.height))
                imageSize = CGSize(width: imageSize.width * fit, height: imageSize.height * fit)
            }
        }

        let contentSize = CGSize(
            width: imageSize.width + padding * 2,
            height: imageSize.height + padding * 2
        )
        panel = PinPanel(
            contentRect: CGRect(origin: .zero, size: contentSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false

        let view = PinView(image: image, controller: self, padding: padding)
        view.frame = CGRect(origin: .zero, size: contentSize)
        view.autoresizingMask = [.width, .height]
        panel.contentView = view

        if let cocoaPreferred {
            panel.setFrameOrigin(NSPoint(
                x: cocoaPreferred.minX - padding,
                y: cocoaPreferred.minY - padding
            ))
        } else if let visible = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(NSPoint(
                x: visible.midX - contentSize.width / 2,
                y: visible.midY - contentSize.height / 2
            ))
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
