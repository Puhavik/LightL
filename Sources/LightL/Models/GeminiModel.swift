import Foundation

public struct GeminiModelOption: Identifiable, Hashable, Codable, Sendable {
    public var id: String { modelId }
    public let modelId: String

    public init(modelId: String) {
        self.modelId = modelId
    }

    public var localizedDisplayName: String {
        switch modelId {
        case "gemini-3.5-flash-lite":
            return L10n.tr(ru: "Gemini 3.5 Flash-Lite (Рекомендуется)", en: "Gemini 3.5 Flash-Lite (Recommended)")
        case "gemini-3.1-flash-lite":
            return "Gemini 3.1 Flash-Lite"
        case "gemini-3.5-flash":
            return "Gemini 3.5 Flash"
        case "gemini-3.6-flash":
            return "Gemini 3.6 Flash"
        default:
            return modelId
        }
    }

    public var localizedDescription: String {
        switch modelId {
        case "gemini-3.5-flash-lite":
            return L10n.tr(
                ru: "Основная рекомендуемая модель. Сверхбыстрый ответ за ~0.5с.",
                en: "Primary recommended model. Ultra-fast responses in ~0.5s."
            )
        case "gemini-3.1-flash-lite":
            return L10n.tr(
                ru: "Самая экономичная и быстрая модель. Ответ за ~1.0с.",
                en: "Most economical and fast model. Responses in ~1.0s."
            )
        case "gemini-3.5-flash":
            return L10n.tr(
                ru: "Сбалансированная модель для повседневных задач. Ответ за ~1.0с.",
                en: "Balanced model for everyday translation. Responses in ~1.0s."
            )
        case "gemini-3.6-flash":
            return L10n.tr(
                ru: "Повышенное качество перевода сложных текстов. Ответ за ~0.9с.",
                en: "Higher quality translation for complex texts. Responses in ~0.9s."
            )
        default:
            return ""
        }
    }

    public static let availableModels: [GeminiModelOption] = [
        GeminiModelOption(modelId: "gemini-3.5-flash-lite"),
        GeminiModelOption(modelId: "gemini-3.1-flash-lite"),
        GeminiModelOption(modelId: "gemini-3.5-flash"),
        GeminiModelOption(modelId: "gemini-3.6-flash")
    ]

    public static let defaultModel = availableModels.first(where: { $0.modelId == "gemini-3.5-flash-lite" }) ?? availableModels[0]
}
