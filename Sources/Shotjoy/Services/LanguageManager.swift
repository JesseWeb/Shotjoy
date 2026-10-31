import Combine
import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case simplifiedChinese
    case traditionalChinese
    case japanese
    case french
    case spanish

    var id: String { rawValue }

    var nativeName: String {
        switch self {
        case .system: return "System"
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        case .japanese: return "日本語"
        case .french: return "Français"
        case .spanish: return "Español"
        }
    }

    var resolved: AppLanguage {
        self == .system ? AppLanguage.systemLanguage : self
    }

    static var systemLanguage: AppLanguage {
        for identifier in Locale.preferredLanguages {
            let value = identifier.lowercased()
            if value.hasPrefix("zh-hant") || value.hasPrefix("zh-tw") ||
                value.hasPrefix("zh-hk") || value.hasPrefix("zh-mo") {
                return .traditionalChinese
            }
            if value.hasPrefix("zh") { return .simplifiedChinese }
            if value.hasPrefix("ja") { return .japanese }
            if value.hasPrefix("fr") { return .french }
            if value.hasPrefix("es") { return .spanish }
            if value.hasPrefix("en") { return .english }
        }
        return .english
    }
}

extension Notification.Name {
    static let shotjoyLanguageDidChange = Notification.Name("ShotjoyLanguageDidChange")
}

final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @Published private(set) var selection: AppLanguage

    private let defaults = UserDefaults.standard
    private let key = "appLanguage"

    private init() {
        let stored = defaults.string(forKey: key) ?? AppLanguage.system.rawValue
        selection = AppLanguage(rawValue: stored) ?? .system
    }

    var resolved: AppLanguage { selection.resolved }

    func set(_ language: AppLanguage) {
        guard selection != language else { return }
        selection = language
        defaults.set(language.rawValue, forKey: key)
        NotificationCenter.default.post(name: .shotjoyLanguageDidChange, object: nil)
    }
}
