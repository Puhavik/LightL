import Foundation

public struct LanguageModel: Identifiable, Hashable, Codable, Sendable {
    public var id: String { code }
    public let code: String
    public let name: String
    public let nativeName: String

    public var localizedName: String {
        switch code {
        case "ru": return L10n.tr(ru: "Русский", en: "Russian")
        case "en": return L10n.tr(ru: "Английский", en: "English")
        case "de": return L10n.tr(ru: "Немецкий", en: "German")
        case "fr": return L10n.tr(ru: "Французский", en: "French")
        case "es": return L10n.tr(ru: "Испанский", en: "Spanish")
        case "it": return L10n.tr(ru: "Итальянский", en: "Italian")
        case "pt": return L10n.tr(ru: "Португальский", en: "Portuguese")
        case "zh": return L10n.tr(ru: "Китайский", en: "Chinese")
        case "ja": return L10n.tr(ru: "Японский", en: "Japanese")
        case "ko": return L10n.tr(ru: "Корейский", en: "Korean")
        case "tr": return L10n.tr(ru: "Турецкий", en: "Turkish")
        case "ar": return L10n.tr(ru: "Арабский", en: "Arabic")
        case "pl": return L10n.tr(ru: "Польский", en: "Polish")
        case "uk": return L10n.tr(ru: "Украинский", en: "Ukrainian")
        case "nl": return L10n.tr(ru: "Нидерландский", en: "Dutch")
        default: return name
        }
    }

    public static let supportedLanguages: [LanguageModel] = [
        LanguageModel(code: "ru", name: "Русский", nativeName: "Русский"),
        LanguageModel(code: "en", name: "Английский", nativeName: "English"),
        LanguageModel(code: "de", name: "Немецкий", nativeName: "Deutsch"),
        LanguageModel(code: "fr", name: "Французский", nativeName: "Français"),
        LanguageModel(code: "es", name: "Испанский", nativeName: "Español"),
        LanguageModel(code: "it", name: "Итальянский", nativeName: "Italiano"),
        LanguageModel(code: "pt", name: "Португальский", nativeName: "Português"),
        LanguageModel(code: "zh", name: "Китайский", nativeName: "中文"),
        LanguageModel(code: "ja", name: "Японский", nativeName: "日本語"),
        LanguageModel(code: "ko", name: "Корейский", nativeName: "한국어"),
        LanguageModel(code: "tr", name: "Турецкий", nativeName: "Türkçe"),
        LanguageModel(code: "ar", name: "Арабский", nativeName: "العربية"),
        LanguageModel(code: "pl", name: "Польский", nativeName: "Polski"),
        LanguageModel(code: "uk", name: "Украинский", nativeName: "Українська"),
        LanguageModel(code: "nl", name: "Нидерландский", nativeName: "Nederlands")
    ]

    public static let defaultTarget = supportedLanguages[0] // Russian
}
