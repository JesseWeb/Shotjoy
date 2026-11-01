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

    /// A pin has to stay exactly where the screenshot was taken, even when that
    /// means hanging over the menu bar or past a screen edge. AppKit's default
    /// constraint would shove the window down and move the image with it.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

final class PinView: NSView {
    let image: CGImage
    let padding: CGFloat
    weak var controller: PinWindowController?

    /// Window screenshots keep their own (usually larger) rounded corners as
    /// transparent pixels. Their glow has to follow that silhouette instead of
    /// the card radius used for opaque captures.
    private let followsImageAlpha: Bool

    private var dragAnchor: NSPoint?
    private var dragOrigin: NSPoint?

    init(image: CGImage, controller: PinWindowController, padding: CGFloat) {
        self.image = image
        self.controller = controller
        self.padding = padding
        self.followsImageAlpha = Self.hasTransparentCorner(image)
        super.init(frame: .zero)
        wantsLayer = true
    }

    /// Samples one corner pixel; rounded window shots are transparent there.
    private static func hasTransparentCorner(_ image: CGImage) -> Bool {
        guard let corner = image.cropping(to: CGRect(x: 0, y: 0, width: 1, height: 1)) else {
            return false
        }
        var pixel = [UInt8](repeating: 0, count: 4)
        return pixel.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(corner, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            return buffer[3] < 32
        }
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
        let focused = window?.isKeyWindow == true

        // Soft blue halo outside the pin body: a tight rim plus a wider bloom.
        let rim = NSColor(
            srgbRed: 0.50, green: 0.78, blue: 1.0,
            alpha: focused ? 0.60 : 0.40
        ).cgColor
        let halo = NSColor(
            srgbRed: 0.38, green: 0.68, blue: 1.0,
            alpha: focused ? 0.32 : 0.18
        ).cgColor

        context.saveGState()
        if followsImageAlpha {
            // Let the image's own alpha define the silhouette, so a rounded
            // window screenshot glows along its real corners.
            context.setShadow(offset: .zero, blur: 6, color: rim)
            CGDrawing.drawImage(image, in: rect, context: context, flipped: true)
            context.setShadow(offset: .zero, blur: 18, color: halo)
            CGDrawing.drawImage(image, in: rect, context: context, flipped: true)
        } else {
            NSColor.black.setFill()
            context.setShadow(offset: .zero, blur: 6, color: rim)
            path.fill()
            context.setShadow(offset: .zero, blur: 18, color: halo)
            path.fill()
        }
        context.restoreGState()

        context.saveGState()
        path.addClip()
        CGDrawing.drawImage(image, in: rect, context: context, flipped: true)
        context.restoreGState()

        // A card border only makes sense when the pin is a plain rectangle.
        guard !followsImageAlpha else { return }

        path.lineWidth = 1
        NSColor.white.withAlphaComponent(0.32).setStroke()
        path.stroke()

        if focused {
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
            // `performDrag(with:)` runs the system window-drag session, which
            // pushes the frame back inside the screen. Moving the window by hand
            // keeps our `constrainFrameRect` override in charge, so a pin can be
            // dragged back over the menu bar.
            dragAnchor = NSEvent.mouseLocation
            dragOrigin = window?.frame.origin
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragAnchor, let dragOrigin, let window else { return }
        let current = NSEvent.mouseLocation
        window.setFrameOrigin(
            NSPoint(
                x: dragOrigin.x + (current.x - dragAnchor.x),
                y: dragOrigin.y + (current.y - dragAnchor.y)
            )
        )
    }

    override func mouseUp(with event: NSEvent) {
        dragAnchor = nil
        dragOrigin = nil
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

        let padding: CGFloat = 24
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
        panel.isMovableByWindowBackground = false
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
