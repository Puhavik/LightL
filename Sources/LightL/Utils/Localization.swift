import Foundation
import os

public enum AppLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case system = "system"
    case russian = "ru"
    case english = "en"

    public var id: String { rawValue }

    public static var systemLanguage: AppLanguage {
        for pref in Locale.preferredLanguages {
            let lower = pref.lowercased()
            if lower.hasPrefix("ru") {
                return .russian
            } else if lower.hasPrefix("en") {
                return .english
            }
        }
        if let code = Locale.current.language.languageCode?.identifier.lowercased(), code.hasPrefix("ru") {
            return .russian
        }
        return .english
    }

    public var displayName: String {
        switch self {
        case .system:
            return L10n.tr(
                ru: "Как в системе (\(Self.systemLanguage == .russian ? "Русский" : "English"))",
                en: "System Default (\(Self.systemLanguage == .russian ? "Russian" : "English"))"
            )
        case .russian:
            return "Русский"
        case .english:
            return "English"
        }
    }
}

public struct L10n: Sendable {
    private static let interfaceLanguageKey = "LightL_interfaceLanguage"
    private static let settingsNotificationName = Notification.Name("LightLAppSettingsDidChangeNotification")

    private static let cache: OSAllocatedUnfairLock<AppLanguage> = {
        let initial = loadLanguageFromUserDefaults()
        let lock = OSAllocatedUnfairLock(initialState: initial)
        NotificationCenter.default.addObserver(
            forName: settingsNotificationName,
            object: nil,
            queue: nil
        ) { _ in
            reloadCache()
        }
        return lock
    }()

    private static func loadLanguageFromUserDefaults() -> AppLanguage {
        let configured = UserDefaults.standard.string(forKey: interfaceLanguageKey)
        switch configured {
        case "ru":
            return .russian
        case "en":
            return .english
        default:
            return AppLanguage.systemLanguage
        }
    }

    public static func reloadCache() {
        let lang = loadLanguageFromUserDefaults()
        cache.withLock { $0 = lang }
    }

    public static var currentLanguage: AppLanguage {
        get {
            cache.withLock { $0 }
        }
        set {
            cache.withLock { $0 = newValue }
        }
    }

    public static func tr(ru: String, en: String) -> String {
        currentLanguage == .russian ? ru : en
    }
}
