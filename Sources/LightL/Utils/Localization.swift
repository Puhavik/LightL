import Foundation

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

    public static var currentLanguage: AppLanguage {
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

    public static func tr(ru: String, en: String) -> String {
        currentLanguage == .russian ? ru : en
    }
}
