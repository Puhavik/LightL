import Foundation

public struct GeminiModelOption: Identifiable, Hashable, Codable, Sendable {
    public var id: String { modelId }
    public let modelId: String
    public let displayName: String
    public let description: String

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
            return displayName
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
            return description
        }
    }

    public static let availableModels: [GeminiModelOption] = [
        GeminiModelOption(
            modelId: "gemini-3.5-flash-lite",
            displayName: "Gemini 3.5 Flash-Lite (Рекомендуется)",
            description: "Сверхбыстрая легковесная модель без рассуждений (thinking). Мгновенный перевод за ~200-400мс."
        ),
        GeminiModelOption(
            modelId: "gemini-3.8-flash",
            displayName: "Gemini 3.8 Flash",
            description: "Флагманская Flash-модель (режим thinking принудительно отключен для максимальной скорости)."
        ),
        GeminiModelOption(
            modelId: "gemini-3.6-flash",
            displayName: "Gemini 3.6 Flash",
            description: "Сбалансированная модель без размышлений."
        ),
        GeminiModelOption(
            modelId: "gemini-flash-latest",
            displayName: "Gemini Flash (Latest alias)",
            description: "Автоматически использует самую свежую Flash-модель."
        ),
        GeminiModelOption(
            modelId: "gemini-4-argon",
            displayName: "Gemini 4 Argon",
            description: "Флагманская модель поколения Gemini 4."
        )
    ]

    public static let defaultModel = availableModels[0] // gemini-3.5-flash-lite
}
