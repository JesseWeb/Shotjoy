import AppKit
import SwiftUI

final class SettingsWindowController {
    private var window: NSWindow?
    private var languageObserver: NSObjectProtocol?
    let model: SettingsModel

    init(model: SettingsModel) {
        self.model = model
        languageObserver = NotificationCenter.default.addObserver(
            forName: .shotjoyLanguageDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.window?.title = L10n.settings
        }
    }

    deinit {
        if let languageObserver {
            NotificationCenter.default.removeObserver(languageObserver)
        }
    }

    func show() {
        model.refresh()
        if let window {
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 470, height: 510),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.settings
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SettingsView(model: model))
        window.center()
        self.window = window
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func close() {
        window?.orderOut(nil)
        window?.close()
        window = nil
    }
}
