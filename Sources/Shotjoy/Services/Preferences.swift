import Foundation
import ShotjoyCore

final class Preferences {
    static let shared = Preferences()

    private enum Key {
        static let hotKeyCode = "hotKeyCode"
        static let hotKeyModifiers = "hotKeyModifiers"
        static let copyAfterCapture = "copyAfterCapture"
        static let playSound = "playSound"
        static let saveToDesktop = "saveToDesktop"
        static let lastSaveDirectory = "lastSaveDirectory"
        static let hasShownHotKeyWarning = "hasShownHotKeyWarning"
    }

    private let defaults = UserDefaults.standard

    private init() {
        defaults.register(defaults: [
            Key.hotKeyCode: Int(HotKeyConfig.default.keyCode),
            Key.hotKeyModifiers: Int(HotKeyConfig.default.modifiers.rawValue),
            Key.copyAfterCapture: true,
            Key.playSound: true,
            Key.saveToDesktop: false
        ])
    }

    var shortcut: HotKeyConfig {
        get {
            let code = UInt32(defaults.integer(forKey: Key.hotKeyCode))
            let modifiers = ShortcutModifiers(rawValue: UInt32(defaults.integer(forKey: Key.hotKeyModifiers)))
            let config = HotKeyConfig(keyCode: code, modifiers: modifiers)
            return config.isUsable ? config : .default
        }
        set {
            defaults.set(Int(newValue.keyCode), forKey: Key.hotKeyCode)
            defaults.set(Int(newValue.modifiers.rawValue), forKey: Key.hotKeyModifiers)
        }
    }

    var copyAfterCapture: Bool {
        get { defaults.bool(forKey: Key.copyAfterCapture) }
        set { defaults.set(newValue, forKey: Key.copyAfterCapture) }
    }

    var playSound: Bool {
        get { defaults.bool(forKey: Key.playSound) }
        set { defaults.set(newValue, forKey: Key.playSound) }
    }

    var saveToDesktop: Bool {
        get { defaults.bool(forKey: Key.saveToDesktop) }
        set { defaults.set(newValue, forKey: Key.saveToDesktop) }
    }

    var lastSaveDirectory: URL? {
        get {
            guard let path = defaults.string(forKey: Key.lastSaveDirectory) else { return nil }
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        set {
            defaults.set(newValue?.path, forKey: Key.lastSaveDirectory)
        }
    }

    var hasShownHotKeyWarning: Bool {
        get { defaults.bool(forKey: Key.hasShownHotKeyWarning) }
        set { defaults.set(newValue, forKey: Key.hasShownHotKeyWarning) }
    }

    var defaultSaveDirectory: URL {
        FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
    }
}
