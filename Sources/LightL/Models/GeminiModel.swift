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
        case "gemini-3.8-flash":
            return "Gemini 3.8 Flash"
        case "gemini-3.6-flash":
            return "Gemini 3.6 Flash"
        case "gemini-flash-latest":
            return "Gemini Flash (Latest alias)"
        case "gemini-4-argon":
            return "Gemini 4 Argon"
        default:
            return modelId
        }
    }

    public var localizedDescription: String {
        switch modelId {
        case "gemini-3.5-flash-lite":
            return L10n.tr(
                ru: "Сверхбыстрая легковесная модель без рассуждений (thinking). Мгновенный перевод за ~200-400мс.",
                en: "Ultra-fast lightweight model without thinking overhead. Near-instant responses (~200-400ms)."
            )
        case "gemini-3.8-flash":
            return L10n.tr(
                ru: "Флагманская Flash-модель (режим thinking принудительно отключен для максимальной скорости).",
                en: "Flagship Flash model (thinking mode disabled for maximum speed)."
            )
        case "gemini-3.6-flash":
            return L10n.tr(
                ru: "Сбалансированная модель без размышлений.",
                en: "Balanced model without thinking overhead."
            )
        case "gemini-flash-latest":
            return L10n.tr(
                ru: "Автоматически использует самую свежую Flash-модель.",
                en: "Automatically points to the newest Flash model release."
            )
        case "gemini-4-argon":
            return L10n.tr(
                ru: "Флагманская модель поколения Gemini 4.",
                en: "Flagship next-gen Gemini 4 model."
            )
        default:
            return ""
        }
    }

    public static let availableModels: [GeminiModelOption] = [
        GeminiModelOption(modelId: "gemini-3.5-flash-lite"),
        GeminiModelOption(modelId: "gemini-3.8-flash"),
        GeminiModelOption(modelId: "gemini-3.6-flash"),
        GeminiModelOption(modelId: "gemini-flash-latest"),
        GeminiModelOption(modelId: "gemini-4-argon")
    ]

    public static let defaultModel = availableModels[0] // gemini-3.5-flash-lite
}
