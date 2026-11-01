import Foundation
import Observation
import NaturalLanguage

public enum StatusDotColor: Equatable, Sendable {
    case red
    case orange
    case green
}

public struct StatusDotState: Equatable, Sendable {
    public let color: StatusDotColor
    public let tooltip: String

    public static func derive(
        hasApiKey: Bool,
        isAccessibilityGranted: Bool,
        lastError: String?
    ) -> StatusDotState {
        if !hasApiKey {
            return StatusDotState(
                color: .red,
                tooltip: L10n.tr(
                    ru: "Введите ключ API Gemini в Настройках",
                    en: "Enter Gemini API key in Settings"
                )
            )
        }
        if let error = lastError, !error.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return StatusDotState(
                color: .orange,
                tooltip: error
            )
        }
        if !isAccessibilityGranted {
            return StatusDotState(
                color: .orange,
                tooltip: L10n.tr(
                    ru: "Требуется доступ к Универсальному доступу",
                    en: "Accessibility permission required"
                )
            )
        }
        return StatusDotState(
            color: .green,
            tooltip: L10n.tr(
                ru: "Всё в порядке",
                en: "All good"
            )
        )
    }
}

@Observable
@MainActor
public final class StatusBarPopoverViewModel {
    public var inputText: String = ""
    public var outputText: String = ""
    public var isTranslating: Bool = false
    public var errorMessage: String? = nil
    public var detectedSourceLanguage: String? = nil

    @ObservationIgnored
    public let settings: AppSettings

    @ObservationIgnored
    public let transformer: any TextTransforming

    @ObservationIgnored
    public let isAccessibilityGrantedProvider: () -> Bool

    @ObservationIgnored
    public var debounceNanoseconds: UInt64

    @ObservationIgnored
    internal var debounceTask: Task<Void, Never>?

    @ObservationIgnored
    internal var translationTask: Task<Void, Never>?

    public init(
        settings: AppSettings = .shared,
        transformer: any TextTransforming = GeminiService.shared,
        isAccessibilityGrantedProvider: @escaping () -> Bool = { TextCaptureService.isAccessibilityGranted(prompt: false) },
        debounceNanoseconds: UInt64 = 600_000_000
    ) {
        self.settings = settings
        self.transformer = transformer
        self.isAccessibilityGrantedProvider = isAccessibilityGrantedProvider
        self.debounceNanoseconds = debounceNanoseconds
    }

    public var targetLanguageCode: String {
        get { settings.targetLanguageCode }
        set {
            guard settings.targetLanguageCode != newValue else { return }
            settings.targetLanguageCode = newValue
            onTargetLanguageChanged()
        }
    }

    public var targetLanguage: LanguageModel {
        settings.targetLanguage
    }

    public var statusState: StatusDotState {
        let hasKey = !settings.geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let axGranted = isAccessibilityGrantedProvider()
        return StatusDotState.derive(
            hasApiKey: hasKey,
            isAccessibilityGranted: axGranted,
            lastError: errorMessage
        )
    }

    public func onInputTextChanged() {
        debounceTask?.cancel()
        debounceTask = nil

        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            translationTask?.cancel()
            translationTask = nil
            outputText = ""
            errorMessage = nil
            isTranslating = false
            detectedSourceLanguage = nil
            return
        }

        updateDetectedLanguage(for: trimmed)

        debounceTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                if self.debounceNanoseconds > 0 {
                    try await Task.sleep(nanoseconds: self.debounceNanoseconds)
                }
                guard !Task.isCancelled else { return }
                await self.performTranslation(text: trimmed)
            } catch {
                return
            }
        }
    }

    public func onTargetLanguageChanged() {
        debounceTask?.cancel()
        debounceTask = nil

        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        translationTask?.cancel()
        translationTask = Task { [weak self] in
            await self?.performTranslation(text: trimmed)
        }
    }

    public func performTranslation(text: String) async {
        translationTask?.cancel()
        let task = Task { [weak self] () -> Void in
            guard let self = self else { return }
            guard !Task.isCancelled else { return }

            let apiKey = self.settings.geminiApiKey
            guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                self.errorMessage = L10n.tr(
                    ru: "Не указан API ключ Gemini. Откройте настройки и введите ключ.",
                    en: "Gemini API key is missing. Please open Settings and enter your key."
                )
                self.isTranslating = false
                return
            }

            self.isTranslating = true
            self.errorMessage = nil

            let targetLang = self.targetLanguage
            let model = self.settings.selectedModelId

            do {
                let result = try await self.transformer.translate(
                    text: text,
                    targetLanguage: targetLang,
                    apiKey: apiKey,
                    model: model,
                    onChunk: { [weak self] chunk in
                        Task { @MainActor [weak self] in
                            guard let self = self, !Task.isCancelled else { return }
                            self.outputText = chunk
                        }
                    }
                )
                guard !Task.isCancelled else { return }
                self.outputText = result
                self.errorMessage = nil
                self.isTranslating = false
            } catch {
                guard !Task.isCancelled else { return }
                self.isTranslating = false
                self.errorMessage = error.localizedDescription
            }
        }
        translationTask = task
        await task.value
    }

    private func updateDetectedLanguage(for text: String) {
        guard text.count >= 2 else {
            detectedSourceLanguage = nil
            return
        }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let lang = recognizer.dominantLanguage else {
            detectedSourceLanguage = nil
            return
        }
        let code = lang.rawValue
        if let found = LanguageModel.supportedLanguages.first(where: { $0.code == code }) {
            detectedSourceLanguage = found.localizedName
        } else {
            let locale = Locale.current
            let name = locale.localizedString(forIdentifier: code) ?? code.uppercased()
            detectedSourceLanguage = name
        }
    }
}
