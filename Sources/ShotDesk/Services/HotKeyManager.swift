import AppKit
import Carbon
import ShotDeskCore

/// Registers the global screenshot shortcut with Carbon. Carbon remains the
/// only API for a system-wide hotkey that does not require an event tap or
/// Accessibility permission.
final class HotKeyManager {
    var onHotKey: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private(set) var currentConfig: HotKeyConfig?

    @discardableResult
    func register(_ config: HotKeyConfig) -> Bool {
        guard config.isUsable else { return false }
        if let currentConfig, currentConfig == config, hotKeyRef != nil { return true }
        unregister()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.onHotKey?()
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
        guard handlerStatus == noErr else { return false }

        let hotKeyID = EventHotKeyID(signature: OSType(0x5344_534B), id: 1) // "SDSK"
        let status = RegisterEventHotKey(
            config.keyCode,
            carbonModifiers(from: config.modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status != noErr {
            if let handler = handlerRef {
                RemoveEventHandler(handler)
                handlerRef = nil
            }
            return false
        }
        currentConfig = config
        return true
    }

    func unregister() {
        if let hotKey = hotKeyRef {
            UnregisterEventHotKey(hotKey)
            hotKeyRef = nil
        }
        if let handler = handlerRef {
            RemoveEventHandler(handler)
            handlerRef = nil
        }
        currentConfig = nil
    }

    deinit {
        unregister()
    }

    private func carbonModifiers(from modifiers: ShortcutModifiers) -> UInt32 {
        var result: UInt32 = 0
        if modifiers.contains(.command) { result |= UInt32(cmdKey) }
        if modifiers.contains(.shift) { result |= UInt32(shiftKey) }
        if modifiers.contains(.option) { result |= UInt32(optionKey) }
        if modifiers.contains(.control) { result |= UInt32(controlKey) }
        return result
    }
}

extension ShortcutModifiers {
    init(eventFlags: NSEvent.ModifierFlags) {
        var value: UInt32 = 0
        if eventFlags.contains(.command) { value |= ShortcutModifiers.command.rawValue }
        if eventFlags.contains(.shift) { value |= ShortcutModifiers.shift.rawValue }
        if eventFlags.contains(.option) { value |= ShortcutModifiers.option.rawValue }
        if eventFlags.contains(.control) { value |= ShortcutModifiers.control.rawValue }
        self.init(rawValue: value)
    }
}
