import AppKit
import CoreGraphics
import SwiftUI

final class PreviewWindowController {
    private var window: NSWindow?
    private let model = PreviewModel()

    func showImage(
        _ image: CGImage,
        title: String,
        onCopy: @escaping () -> Void,
        onSave: @escaping () -> Void,
        onPin: @escaping () -> Void
    ) {
        model.title = title
        model.image = NSImage(cgImage: image, size: CGSize(width: image.width, height: image.height))
        model.text = nil
        model.onCopy = onCopy
        model.onSave = onSave
        model.onPin = onPin
        model.onClose = { [weak self] in self?.close() }
        present()
    }

    func showText(_ text: String, title: String, onCopy: @escaping () -> Void) {
        model.title = title
        model.image = nil
        model.text = text
        model.onCopy = onCopy
        model.onSave = nil
        model.onPin = nil
        model.onClose = { [weak self] in self?.close() }
        present()
    }

    private func present() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 760, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = model.title.isEmpty ? L10n.longScreenshot : model.title
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: PreviewView(model: model))
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window?.orderOut(nil)
        window?.close()
        window = nil
    }
}
