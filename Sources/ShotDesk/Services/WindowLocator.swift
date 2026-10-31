import AppKit
import CoreGraphics

/// Finds the topmost normal window under the pointer. WeChat highlights a
/// window before you click; this is the same behaviour, built from
/// `CGWindowListCopyWindowInfo` (one of the APIs WeChat imports).
enum WindowLocator {
    static func windowRect(at point: CGPoint) -> CGRect? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        for info in list {
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            guard let alpha = info[kCGWindowAlpha as String] as? Double, alpha > 0.05 else { continue }
            guard let pid = info[kCGWindowOwnerPID as String] as? pid_t, pid != ownPID else { continue }
            guard let owner = info[kCGWindowOwnerName as String] as? String else { continue }
            if owner == "Window Server" || owner == "Dock" || owner == "SystemUIServer" {
                continue
            }
            guard let bounds = info[kCGWindowBounds as String] as? [String: Any],
                  let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary) else {
                continue
            }
            guard rect.width >= 40, rect.height >= 40 else { continue }
            if rect.contains(point) {
                return rect
            }
        }
        return nil
    }
}
