import AppKit
import SwiftUI
import ShotjoyCore

final class SettingsModel: ObservableObject {
    @Published var shortcut: HotKeyConfig
    @Published var isRecording = false
    @Published var copyAfterCapture: Bool
    @Published var playSound: Bool
    @Published var saveToDesktop: Bool
    @Published var permissionGranted: Bool
    @Published var launchAtLogin: Bool
    @Published var errorText: String?

    var onShortcutChange: ((HotKeyConfig) -> Bool)?
    var onLoginChange: ((Bool) -> Void)?
    var onOpenPermission: (() -> Void)?
    var onResetPermission: (() -> Void)?

    private var monitor: Any?

    init() {
        let prefs = Preferences.shared
        shortcut = prefs.shortcut
        copyAfterCapture = prefs.copyAfterCapture
        playSound = prefs.playSound
        saveToDesktop = prefs.saveToDesktop
        permissionGranted = ScreenCaptureService.hasPermission
        launchAtLogin = LaunchAtLogin.isEnabled
    }

    func refresh() {
        permissionGranted = ScreenCaptureService.hasPermission
        launchAtLogin = LaunchAtLogin.isEnabled
    }

    func startRecording() {
        stopRecording()
        isRecording = true
        errorText = nil
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 53 { // Esc
                self.stopRecording()
                return nil
            }
            let modifiers = ShortcutModifiers(eventFlags: event.modifierFlags)
            let modifierKeyCodes: Set<UInt32> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
            let keyCode = UInt32(event.keyCode)
            guard !modifiers.isEmpty, !modifierKeyCodes.contains(keyCode) else {
                return nil
            }
            let candidate = HotKeyConfig(keyCode: keyCode, modifiers: modifiers)
            if self.onShortcutChange?(candidate) == true {
                self.shortcut = candidate
                Preferences.shared.shortcut = candidate
                self.errorText = nil
                self.stopRecording()
            } else {
                self.errorText = L10n.hotKeyFailedBody
                self.stopRecording()
            }
            return nil
        }
    }

    func stopRecording() {
        isRecording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    func setCopyAfterCapture(_ value: Bool) {
        copyAfterCapture = value
        Preferences.shared.copyAfterCapture = value
    }

    func setPlaySound(_ value: Bool) {
        playSound = value
        Preferences.shared.playSound = value
    }

    func setSaveToDesktop(_ value: Bool) {
        saveToDesktop = value
        Preferences.shared.saveToDesktop = value
    }

    func setLaunchAtLogin(_ value: Bool) {
        launchAtLogin = value
        onLoginChange?(value)
        refresh()
    }
}

struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    @ObservedObject private var languageManager = LanguageManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                    .resizable()
                    .frame(width: 46, height: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Shotjoy")
                        .font(.system(size: 18, weight: .semibold))
                    Text(L10n.t("快速、纯本地的截图工具", "A fast, local-only screenshot tool"))
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Text(L10n.language)
                Spacer()
                Picker("", selection: Binding(
                    get: { languageManager.selection },
                    set: { languageManager.set($0) }
                )) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language == .system ? L10n.followSystem : language.nativeName)
                            .tag(language)
                    }
                }
                .labelsHidden()
                .frame(width: 190)
            }

            GroupBox(L10n.t("截图", "Capture")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(L10n.shortcut)
                        Spacer()
                        if model.isRecording {
                            Text(L10n.pressShortcut)
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                        } else {
                            Text(model.shortcut.displayString)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.primary.opacity(0.08))
                                )
                        }
                        Button(model.isRecording ? L10n.cancel : L10n.record) {
                            if model.isRecording {
                                model.stopRecording()
                            } else {
                                model.startRecording()
                            }
                        }
                        .controlSize(.small)
                    }
                    if let error = model.errorText {
                        Text(error)
                            .font(.system(size: 10.5))
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Toggle(L10n.copyAfterCapture, isOn: Binding(
                        get: { model.copyAfterCapture },
                        set: { model.setCopyAfterCapture($0) }
                    ))
                    Toggle(L10n.saveToDesktop, isOn: Binding(
                        get: { model.saveToDesktop },
                        set: { model.setSaveToDesktop($0) }
                    ))
                    Toggle(L10n.playSound, isOn: Binding(
                        get: { model.playSound },
                        set: { model.setPlaySound($0) }
                    ))
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox(L10n.t("权限", "Permissions")) {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(model.permissionGranted ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(model.permissionGranted
                             ? L10n.t("已获得屏幕录制权限", "Screen Recording permission granted")
                             : L10n.t("尚未获得屏幕录制权限", "Screen Recording permission not granted"))
                    }
                    HStack {
                        Button(L10n.openSettings) { model.onOpenPermission?() }
                        Button(L10n.fixPermissionShort) { model.onResetPermission?() }
                        Button(L10n.t("刷新", "Refresh")) { model.refresh() }
                    }
                    .controlSize(.small)
                    Text(L10n.permissionsHint)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Toggle(L10n.launchAtLogin, isOn: Binding(
                get: { model.launchAtLogin },
                set: { model.setLaunchAtLogin($0) }
            ))

            Spacer(minLength: 0)

            HStack {
                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Spacer()
                Text(L10n.t("默认快捷键：⌃⌘A", "Default shortcut: ⌃⌘A"))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(22)
        .frame(width: 470, height: 510)
    }
}
