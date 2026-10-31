import AppKit
import SwiftUI

final class SettingsWindowController {
    private var window: NSWindow?
    let model: SettingsModel

    init(model: SettingsModel) {
        self.model = model
    }

    func show() {
        model.refresh()
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 470, height: 470),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.settings
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SettingsView(model: model))
        window.center()
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
