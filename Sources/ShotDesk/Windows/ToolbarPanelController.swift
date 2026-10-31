import AppKit
import SwiftUI

final class ToolbarPanel: NSPanel {
    // Keep the overlay as the key window for Esc/Return, but allow the panel
    // to take key focus temporarily if a control actually needs it.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class ToolbarPanelController {
    let panel: ToolbarPanel

    init(model: ToolbarModel) {
        panel = ToolbarPanel(
            contentRect: CGRect(x: 0, y: 0, width: 780, height: 54),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 2)
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.contentView = NSHostingView(
            rootView: ToolbarView(model: model)
                .frame(width: 780, height: 54)
        )
    }

    func show() {
        panel.orderFrontRegardless()
    }

    func close() {
        panel.orderOut(nil)
        panel.close()
    }
}
