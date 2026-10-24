import Foundation
import AppKit

@MainActor
protocol TextCapturing: AnyObject {
    func captureSelection() async -> CapturedSelection?
    func replaceSelection(with newText: String, verifying original: CapturedSelection?) async -> Bool
}

protocol TextTransforming: Sendable {
    func prewarm() async
    func translate(
        text: String,
        targetLanguage: LanguageModel,
        apiKey: String,
        model: String,
        onChunk: (@Sendable (String) -> Void)?
    ) async throws -> String
    func rewrite(text: String, mode: RewriteMode, apiKey: String, model: String) async throws -> String
}

@MainActor
protocol StatusIndicating: AnyObject {
    func setLoading(_ loading: Bool)
    func triggerErrorBlink(message: String)
    func triggerSuccessFlash()
    func destroy()
}

@MainActor
protocol TranslationPresenting: AnyObject {
    var onDismiss: (() -> Void)? { get set }
    var canReplace: Bool { get set }
    func show(
        originalText: String,
        targetLanguage: LanguageModel,
        near pointOrRect: FloatingTranslationPanel.EitherPointOrRect,
        onCopy: @escaping () -> Void,
        onReplace: @escaping () -> Void
    )
    func updateTranslation(
        originalText: String,
        translatedText: String,
        targetLanguage: LanguageModel,
        isStreaming: Bool,
        onCopy: @escaping () -> Void,
        onReplace: @escaping () -> Void
    )
    func showError(
        originalText: String,
        error: String,
        targetLanguage: LanguageModel,
        onCopy: @escaping () -> Void,
        onReplace: @escaping () -> Void
    )
    func dismiss()
}

extension TextCaptureService: TextCapturing {}
extension GeminiService: TextTransforming {}
extension StatusBarController: StatusIndicating {}
extension FloatingTranslationPanel: TranslationPresenting {}
