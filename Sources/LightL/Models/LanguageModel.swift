import Foundation

public struct LanguageModel: Identifiable, Hashable, Codable, Sendable {
    public var id: String { code }
    public let code: String
    public let name: String
    public let englishName: String
    public let nativeName: String

    public var localizedName: String {
        L10n.tr(ru: name, en: englishName)
    }

    public static let supportedLanguages: [LanguageModel] = [
        LanguageModel(code: "ru", name: "Русский", englishName: "Russian", nativeName: "Русский"),
        LanguageModel(code: "en", name: "Английский", englishName: "English", nativeName: "English"),
        LanguageModel(code: "de", name: "Немецкий", englishName: "German", nativeName: "Deutsch"),
        LanguageModel(code: "fr", name: "Французский", englishName: "French", nativeName: "Français"),
        LanguageModel(code: "es", name: "Испанский", englishName: "Spanish", nativeName: "Español"),
        LanguageModel(code: "it", name: "Итальянский", englishName: "Italian", nativeName: "Italiano"),
        LanguageModel(code: "pt", name: "Португальский", englishName: "Portuguese", nativeName: "Português"),
        LanguageModel(code: "zh", name: "Китайский", englishName: "Chinese", nativeName: "中文"),
        LanguageModel(code: "ja", name: "Японский", englishName: "Japanese", nativeName: "日本語"),
        LanguageModel(code: "ko", name: "Корейский", englishName: "Korean", nativeName: "한국어"),
        LanguageModel(code: "tr", name: "Турецкий", englishName: "Turkish", nativeName: "Türkçe"),
        LanguageModel(code: "ar", name: "Арабский", englishName: "Arabic", nativeName: "العربية"),
        LanguageModel(code: "pl", name: "Польский", englishName: "Polish", nativeName: "Polski"),
        LanguageModel(code: "uk", name: "Украинский", englishName: "Ukrainian", nativeName: "Українська"),
        LanguageModel(code: "nl", name: "Нидерландский", englishName: "Dutch", nativeName: "Nederlands")
    ]

    public static let defaultTarget = supportedLanguages[0] // Russian
}
