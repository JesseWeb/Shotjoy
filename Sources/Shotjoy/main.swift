import AppKit

// A menu-bar-only AppKit application. AppKit owns the status item, hotkey,
// overlay windows, and pasteboard plumbing; SwiftUI hosts the toolbars and
// settings UI.
let shotjoyApplication = NSApplication.shared
let shotjoyAppDelegate = AppDelegate()
shotjoyApplication.delegate = shotjoyAppDelegate
if CommandLine.arguments.contains("--demo-overlay") {
    _ = shotjoyApplication.setActivationPolicy(.regular)
} else {
    _ = shotjoyApplication.setActivationPolicy(.accessory)
}
shotjoyApplication.run()
