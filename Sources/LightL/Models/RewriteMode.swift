import Foundation

public enum RewriteMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case proofread = "proofread"
    case improveStyle = "improveStyle"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .proofread:
            return L10n.tr(ru: "Исправление ошибок", en: "Fix Mistakes")
        case .improveStyle:
            return L10n.tr(ru: "Улучшение стиля", en: "Improve Style")
        }
    }

    public var shortBadge: String {
        switch self {
        case .proofread:
            return L10n.tr(ru: "Бережный", en: "Precise")
        case .improveStyle:
            return L10n.tr(ru: "Выразительный", en: "Polished")
        }
    }

    public var subtitle: String {
        switch self {
        case .proofread:
            return L10n.tr(
                ru: "Только орфография, пунктуация и опечатки",
                en: "Spelling, punctuation, and typos only"
            )
        case .improveStyle:
            return L10n.tr(
                ru: "Лаконичность, живая речь и деловой тон",
                en: "Clarity, natural phrasing, and tone"
            )
        }
    }

    public var description: String {
        switch self {
        case .proofread:
            return L10n.tr(
                ru: "Исправляет орфографию, грамматику и пунктуацию. Слова, тон и структура предложений остаются без изменений.",
                en: "Corrects spelling, grammar, and punctuation. Words, tone, and sentence structure remain strictly unchanged."
            )
        case .improveStyle:
            return L10n.tr(
                ru: "Перефразирует текст, устраняет косноязычие и канцелярит, делая формулировки ясными и убедительными.",
                en: "Rephrases sentences to eliminate clunkiness, enhancing flow, vocabulary, and professional impact."
            )
        }
    }

    public var wordingBehavior: String {
        switch self {
        case .proofread:
            return L10n.tr(
                ru: "Не меняются (1-в-1 как в исходнике)",
                en: "Unchanged (1-to-1 exact words)"
            )
        case .improveStyle:
            return L10n.tr(
                ru: "Перефразируются для лучшего звучания",
                en: "Polished & rephrased for clarity"
            )
        }
    }

    public var temperatureDescription: String {
        switch self {
        case .proofread:
            return L10n.tr(
                ru: "0.1 — максимальная строгость",
                en: "0.1 — strict precision"
            )
        case .improveStyle:
            return L10n.tr(
                ru: "0.4 — живая речь и благозвучие",
                en: "0.4 — natural flow & expression"
            )
        }
    }

    public var recommendedFor: String {
        switch self {
        case .proofread:
            return L10n.tr(
                ru: "Код, технические заметки, быстрые чаты",
                en: "Code, technical notes, quick chats"
            )
        case .improveStyle:
            return L10n.tr(
                ru: "Деловая переписка, статьи, презентации",
                en: "Business emails, essays, presentations"
            )
        }
    }

    public var exampleOriginal: String {
        L10n.tr(
            ru: "я закончил отчет и я скинул тебе его на почту проверь пжлст",
            en: "i finished the report and i sent it to your email pls check"
        )
    }

    public var exampleResult: String {
        switch self {
        case .proofread:
            return L10n.tr(
                ru: "Я закончил отчет, и я скинул тебе его на почту, проверь, пожалуйста.",
                en: "I finished the report, and I sent it to your email, please check."
            )
        case .improveStyle:
            return L10n.tr(
                ru: "Отчет готов и отправлен вам на почту. Пожалуйста, ознакомьтесь.",
                en: "The report is ready and has been sent to your email. Please review it at your convenience."
            )
        }
    }
}
