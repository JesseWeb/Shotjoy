import AppKit
import CoreGraphics
import ShotjoyCore

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

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        CGDrawing.drawImage(image, in: bounds, context: context, flipped: true)
    }

    override func mouseDown(with event: NSEvent) {
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
    private(set) var panel: NSPanel
    private let image: CGImage
    private var onClose: (() -> Void)?

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

        panel = NSPanel(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
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
