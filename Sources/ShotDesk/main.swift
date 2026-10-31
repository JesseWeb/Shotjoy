import AppKit

// A menu-bar-only AppKit application. AppKit owns the status item, hotkey,
// overlay windows, and pasteboard plumbing; SwiftUI hosts the toolbars and
// settings UI.
let shotDeskApplication = NSApplication.shared
let shotDeskAppDelegate = AppDelegate()
shotDeskApplication.delegate = shotDeskAppDelegate
if CommandLine.arguments.contains("--demo-overlay") {
    _ = shotDeskApplication.setActivationPolicy(.regular)
} else {
    _ = shotDeskApplication.setActivationPolicy(.accessory)
}
shotDeskApplication.run()
