import AppKit
import SwiftUI

private struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(.primary)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.22), radius: 10, y: 4)
            )
            .padding(6)
    }
}

/// A small non-activating HUD used for short feedback such as "no faces
/// detected" or "text copied". It never steals focus from the overlay.
final class ToastController {
    static let shared = ToastController()

    private var panel: NSPanel?
    private var hideWorkItem: DispatchWorkItem?

    func show(_ message: String, duration: TimeInterval = 1.8) {
        guard !message.isEmpty else { return }
        DispatchQueue.main.async {
            self.hideWorkItem?.cancel()
            self.panel?.orderOut(nil)
            self.panel?.close()

            let panel = NSPanel(
                contentRect: CGRect(x: 0, y: 0, width: 320, height: 52),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 4)
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.isMovable = false
            panel.isReleasedWhenClosed = false
            panel.hidesOnDeactivate = false
            panel.contentView = NSHostingView(rootView: ToastView(message: message))

            if let visible = NSScreen.main?.visibleFrame {
                panel.setFrameOrigin(
                    NSPoint(
                        x: visible.midX - panel.frame.width / 2,
                        y: visible.maxY - panel.frame.height - 58
                    )
                )
            }
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                panel.animator().alphaValue = 1
            }
            self.panel = panel

            let item = DispatchWorkItem { [weak self, weak panel] in
                guard let panel else { return }
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.2
                    panel.animator().alphaValue = 0
                }, completionHandler: {
                    panel.orderOut(nil)
                    panel.close()
                    if self?.panel === panel { self?.panel = nil }
                })
            }
            self.hideWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: item)
        }
    }
}
