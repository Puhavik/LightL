import Testing
import Foundation
import AppKit
@testable import LightL

final class MockTransformer: TextTransforming, @unchecked Sendable {
    private let lock = NSLock()
    private var _translateCalls = 0
    private var _lastText = ""
    private var _lastTarget: LanguageModel?

    var result: Result<String, Error> = .success("Translated text")
    var chunksToStream: [String] = []

    var translateCalls: Int {
        lock.withLock { _translateCalls }
    }

    var lastText: String {
        lock.withLock { _lastText }
    }

    var lastTarget: LanguageModel? {
        lock.withLock { _lastTarget }
    }

    func prewarm() async {}

    func translate(
        text: String,
        targetLanguage: LanguageModel,
        apiKey: String,
        model: String,
        onChunk: (@Sendable (String) -> Void)?
    ) async throws -> String {
        lock.withLock {
            _translateCalls += 1
            _lastText = text
            _lastTarget = targetLanguage
        }
        for chunk in chunksToStream {
            onChunk?(chunk)
        }
        return try result.get()
    }

    func rewrite(text: String, mode: RewriteMode, apiKey: String, model: String) async throws -> String {
        return ""
    }
}

@MainActor
func waitUntil(_ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now + .seconds(5)
    while !condition() && ContinuousClock.now < deadline {
        try await Task.sleep(nanoseconds: 10_000_000)
    }
}

@Suite("StatusBarPopover Tests")
struct StatusBarPopoverTests {
    @Test("Status dot derivation matches expected state colors and tooltips")
    func statusDotDerivation() {
        let noKeyState = StatusDotState.derive(
            hasApiKey: false,
            isAccessibilityGranted: true,
            lastError: nil
        )
        #expect(noKeyState.color == .red)
        #expect(noKeyState.tooltip.contains("API") || noKeyState.tooltip.contains("ключ") || noKeyState.tooltip.contains("key"))

        let axRequiredState = StatusDotState.derive(
            hasApiKey: true,
            isAccessibilityGranted: false,
            lastError: nil
        )
        #expect(axRequiredState.color == .orange)
        #expect(axRequiredState.tooltip.contains("Универсальн") || axRequiredState.tooltip.contains("Accessibility"))

        let errorState = StatusDotState.derive(
            hasApiKey: true,
            isAccessibilityGranted: true,
            lastError: "Quota exceeded"
        )
        #expect(errorState.color == .orange)
        #expect(errorState.tooltip == "Quota exceeded")

        let allGoodState = StatusDotState.derive(
            hasApiKey: true,
            isAccessibilityGranted: true,
            lastError: nil
        )
        #expect(allGoodState.color == .green)
        #expect(allGoodState.tooltip.contains("Всё в порядке") || allGoodState.tooltip.contains("All good"))
    }

    @Test("Empty input clears output and error")
    @MainActor
    func emptyInputClearsOutput() async {
        let defaults = UserDefaults(suiteName: "StatusBarPopoverTests_\(UUID().uuidString)")!
        defer { defaults.removePersistentDomain(forName: defaults.description) }
        let settings = AppSettings(defaults: defaults, domain: "StatusBarPopoverTests_\(UUID().uuidString)")
        settings.geminiApiKey = "test-key"

        let mock = MockTransformer()
        let vm = StatusBarPopoverViewModel(
            settings: settings,
            transformer: mock,
            isAccessibilityGrantedProvider: { true },
            debounceNanoseconds: 50_000_000
        )

        vm.inputText = "Hello"
        vm.outputText = "Привет"
        vm.errorMessage = "Some old error"

        vm.inputText = "   "
        vm.onInputTextChanged()

        #expect(vm.outputText == "")
        #expect(vm.errorMessage == nil)
        #expect(!vm.isTranslating)
        #expect(vm.detectedSourceLanguage == nil)
    }

    @Test("Debounce translates text after delay")
    @MainActor
    func debounceTranslation() async throws {
        let defaults = UserDefaults(suiteName: "StatusBarPopoverTests_\(UUID().uuidString)")!
        defer { defaults.removePersistentDomain(forName: defaults.description) }
        let settings = AppSettings(defaults: defaults, domain: "StatusBarPopoverTests_\(UUID().uuidString)")
        settings.geminiApiKey = "test-key"

        let mock = MockTransformer()
        mock.result = .success("Bonjour le monde")
        mock.chunksToStream = ["Bonjour", "Bonjour le monde"]

        let vm = StatusBarPopoverViewModel(
            settings: settings,
            transformer: mock,
            isAccessibilityGrantedProvider: { true },
            debounceNanoseconds: 30_000_000
        )

        vm.inputText = "Hello world"
        vm.onInputTextChanged()

        try await waitUntil { vm.outputText == "Bonjour le monde" && !vm.isTranslating }

        #expect(mock.translateCalls == 1)
        #expect(mock.lastText == "Hello world")
        #expect(vm.outputText == "Bonjour le monde")
        #expect(vm.errorMessage == nil)
        #expect(!vm.isTranslating)
    }

    @Test("Target language change persists to settings and triggers immediate translation")
    @MainActor
    func targetLanguageChangePersistence() async throws {
        let defaults = UserDefaults(suiteName: "StatusBarPopoverTests_\(UUID().uuidString)")!
        defer { defaults.removePersistentDomain(forName: defaults.description) }
        let settings = AppSettings(defaults: defaults, domain: "StatusBarPopoverTests_\(UUID().uuidString)")
        settings.geminiApiKey = "test-key"
        settings.targetLanguageCode = "ru"

        let mock = MockTransformer()
        mock.result = .success("Guten Tag")

        let vm = StatusBarPopoverViewModel(
            settings: settings,
            transformer: mock,
            isAccessibilityGrantedProvider: { true },
            debounceNanoseconds: 600_000_000
        )

        vm.inputText = "Good day"
        vm.targetLanguageCode = "de"

        #expect(settings.targetLanguageCode == "de")

        try await waitUntil { vm.outputText == "Guten Tag" }

        #expect(mock.translateCalls == 1)
        #expect(mock.lastTarget?.code == "de")
        #expect(vm.outputText == "Guten Tag")
    }

    @Test("Missing API key produces inline error")
    @MainActor
    func missingApiKeyShowsInlineError() async throws {
        let defaults = UserDefaults(suiteName: "StatusBarPopoverTests_\(UUID().uuidString)")!
        defer { defaults.removePersistentDomain(forName: defaults.description) }
        let settings = AppSettings(defaults: defaults, domain: "StatusBarPopoverTests_\(UUID().uuidString)")
        settings.geminiApiKey = ""

        let mock = MockTransformer()
        let vm = StatusBarPopoverViewModel(
            settings: settings,
            transformer: mock,
            isAccessibilityGrantedProvider: { true },
            debounceNanoseconds: 10_000_000
        )

        vm.inputText = "Sample text"
        vm.onInputTextChanged()

        try await waitUntil { vm.errorMessage != nil }

        #expect(mock.translateCalls == 0)
        #expect(vm.errorMessage != nil)
        #expect(vm.statusState.color == .red)
    }

    @Test("Translation failure reflects in inline error and orange status dot")
    @MainActor
    func translationFailureUpdatesStatusState() async throws {
        let defaults = UserDefaults(suiteName: "StatusBarPopoverTests_\(UUID().uuidString)")!
        defer { defaults.removePersistentDomain(forName: defaults.description) }
        let settings = AppSettings(defaults: defaults, domain: "StatusBarPopoverTests_\(UUID().uuidString)")
        settings.geminiApiKey = "valid-key"

        struct SampleError: LocalizedError {
            var errorDescription: String? { "Rate limit exceeded" }
        }

        let mock = MockTransformer()
        mock.result = .failure(SampleError())

        let vm = StatusBarPopoverViewModel(
            settings: settings,
            transformer: mock,
            isAccessibilityGrantedProvider: { true },
            debounceNanoseconds: 10_000_000
        )

        vm.inputText = "Translate this"
        vm.onInputTextChanged()

        try await waitUntil { vm.errorMessage != nil }

        #expect(vm.errorMessage == "Rate limit exceeded")
        #expect(vm.statusState.color == .orange)
        #expect(vm.statusState.tooltip == "Rate limit exceeded")
    }
}
