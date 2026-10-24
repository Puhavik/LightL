import Testing
import Foundation
import AppKit
@testable import LightL

final class FakeGemini: TextTransforming, @unchecked Sendable {
    private let lock = NSLock()
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var _translateCalls = 0
    private var _rewriteCalls = 0

    var translateOutcome: Result<String, Error> = .success("Translated")
    var rewriteOutcome: Result<String, Error> = .success("Rewritten")
    var chunks: [String] = []
    var blocking = false

    var translateCalls: Int { lock.withLock { _translateCalls } }
    var rewriteCalls: Int { lock.withLock { _rewriteCalls } }
    var waitingCount: Int { lock.withLock { waiters.count } }

    func releaseNext() {
        let next: CheckedContinuation<Void, Never>? = lock.withLock { waiters.isEmpty ? nil : waiters.removeFirst() }
        next?.resume()
    }

    func prewarm() async {}

    func translate(
        text: String,
        targetLanguage: LanguageModel,
        apiKey: String,
        model: String,
        onChunk: (@Sendable (String) -> Void)?
    ) async throws -> String {
        lock.withLock { _translateCalls += 1 }
        if blocking {
            await withCheckedContinuation { continuation in
                lock.withLock { waiters.append(continuation) }
            }
        }
        for chunk in chunks { onChunk?(chunk) }
        return try translateOutcome.get()
    }

    func rewrite(text: String, mode: RewriteMode, apiKey: String, model: String) async throws -> String {
        lock.withLock { _rewriteCalls += 1 }
        return try rewriteOutcome.get()
    }
}

@MainActor
final class FakeCapture: TextCapturing {
    var selection: CapturedSelection?
    var replaceResult = true
    private(set) var captureCalls = 0
    private(set) var replaced: [(text: String, original: CapturedSelection?)] = []

    func captureSelection() async -> CapturedSelection? {
        captureCalls += 1
        return selection
    }

    func replaceSelection(with newText: String, verifying original: CapturedSelection?) async -> Bool {
        replaced.append((newText, original))
        return replaceResult
    }
}

@MainActor
final class FakeStatus: StatusIndicating {
    private(set) var events: [String] = []
    func setLoading(_ loading: Bool) { events.append("loading:\(loading)") }
    func triggerErrorBlink(message: String) { events.append("error") }
    func triggerSuccessFlash() { events.append("success") }
    func destroy() {}
}

@MainActor
final class FakePanel: TranslationPresenting {
    var onDismiss: (() -> Void)?
    var canReplace = true
    private(set) var shown = 0
    private(set) var shownCanReplace: Bool?
    private(set) var updates: [(text: String, streaming: Bool)] = []
    private(set) var errors: [String] = []

    func show(originalText: String, targetLanguage: LanguageModel, near pointOrRect: FloatingTranslationPanel.EitherPointOrRect, onCopy: @escaping () -> Void, onReplace: @escaping () -> Void) {
        shown += 1
        shownCanReplace = canReplace
    }

    func updateTranslation(originalText: String, translatedText: String, targetLanguage: LanguageModel, isStreaming: Bool, onCopy: @escaping () -> Void, onReplace: @escaping () -> Void) {
        updates.append((translatedText, isStreaming))
    }

    func showError(originalText: String, error: String, targetLanguage: LanguageModel, onCopy: @escaping () -> Void, onReplace: @escaping () -> Void) {
        errors.append(error)
    }

    func dismiss() {}
}

@Suite("AppCoordinator", .serialized)
@MainActor
struct AppCoordinatorTests {
    struct Harness {
        let coordinator: AppCoordinator
        let gemini: FakeGemini
        let capture: FakeCapture
        let status: FakeStatus
        let panel: FakePanel
    }

    private func makeHarness(selection: CapturedSelection? = CapturedSelection(text: "hello", bounds: nil, mouseLocation: .zero)) -> Harness {
        TextCaptureService.accessibilityOverrideForTesting = true
        let gemini = FakeGemini()
        let capture = FakeCapture()
        capture.selection = selection
        let status = FakeStatus()
        let panel = FakePanel()
        let coordinator = AppCoordinator(settings: AppSettings.shared, textCapture: capture, gemini: gemini, statusBar: status, panel: panel)
        return Harness(coordinator: coordinator, gemini: gemini, capture: capture, status: status, panel: panel)
    }

    private func finishRewrite(_ h: Harness) async {
        h.coordinator.handleRewriteTrigger()
        await h.coordinator.currentRewriteTask?.value
    }

    private func finishTranslate(_ h: Harness) async {
        h.coordinator.handleTranslateTrigger()
        await h.coordinator.currentTranslateTask?.value
    }

    private func waitUntil(_ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(2)
        while !condition() && Date() < deadline { await Task.yield() }
    }

    @Test("rewrite replaces the selection and flashes success")
    func rewriteSuccess() async {
        defer { TextCaptureService.accessibilityOverrideForTesting = nil }
        let h = makeHarness()
        await finishRewrite(h)
        #expect(h.gemini.rewriteCalls == 1)
        #expect(h.capture.replaced.map(\.text) == ["Rewritten"])
        #expect(h.status.events.last == "success")
    }

    @Test("rewrite reports an error when the replacement fails")
    func rewriteReplaceFails() async {
        defer { TextCaptureService.accessibilityOverrideForTesting = nil }
        let h = makeHarness()
        h.capture.replaceResult = false
        await finishRewrite(h)
        #expect(h.status.events.last == "error")
    }

    @Test("rewrite without a selection blinks and never calls the API")
    func rewriteNoSelection() async {
        defer { TextCaptureService.accessibilityOverrideForTesting = nil }
        let h = makeHarness(selection: nil)
        await finishRewrite(h)
        #expect(h.gemini.rewriteCalls == 0)
        #expect(h.status.events == ["error"])
    }

    @Test("rewrite without Accessibility permission blinks and never captures")
    func rewriteNoAccessibility() async {
        let h = makeHarness()
        TextCaptureService.accessibilityOverrideForTesting = false
        defer { TextCaptureService.accessibilityOverrideForTesting = nil }
        await finishRewrite(h)
        #expect(h.capture.captureCalls == 0)
        #expect(h.status.events == ["error"])
    }

    @Test("an ambiguous line capture needs a second press and then only reaches the clipboard")
    func rewriteAmbiguousConfirmation() async {
        defer { TextCaptureService.accessibilityOverrideForTesting = nil }
        let ambiguous = CapturedSelection(text: "let x = 1\n", bounds: nil, mouseLocation: .zero, isAmbiguousLineCopy: true)
        let h = makeHarness(selection: ambiguous)
        h.gemini.rewriteOutcome = .success("let y = 2")

        await finishRewrite(h)
        #expect(h.gemini.rewriteCalls == 0)
        #expect(h.status.events == ["error"])

        await finishRewrite(h)
        #expect(h.gemini.rewriteCalls == 1)
        #expect(h.capture.replaced.isEmpty)
        #expect(NSPasteboard.general.string(forType: .string) == "let y = 2")
        #expect(h.status.events.last == "success")
    }

    @Test("translate shows the panel and delivers the final non-streaming update")
    func translateSuccess() async {
        defer { TextCaptureService.accessibilityOverrideForTesting = nil }
        let h = makeHarness()
        h.gemini.chunks = ["Tra", "Transl"]
        h.gemini.translateOutcome = .success("Translated")
        await finishTranslate(h)
        #expect(h.panel.shown == 1)
        #expect(h.panel.shownCanReplace == true)
        #expect(h.panel.updates.last?.text == "Translated")
        #expect(h.panel.updates.last?.streaming == false)
        #expect(h.status.events.first == "loading:true")
        #expect(h.status.events.last == "loading:false")
    }

    @Test("translate hides Replace for an ambiguous line capture")
    func translateAmbiguousHidesReplace() async {
        defer { TextCaptureService.accessibilityOverrideForTesting = nil }
        let ambiguous = CapturedSelection(text: "line\n", bounds: nil, mouseLocation: .zero, isAmbiguousLineCopy: true)
        let h = makeHarness(selection: ambiguous)
        await finishTranslate(h)
        #expect(h.panel.shownCanReplace == false)
    }

    @Test("translate errors show the error panel and blink")
    func translateError() async {
        defer { TextCaptureService.accessibilityOverrideForTesting = nil }
        let h = makeHarness()
        h.gemini.translateOutcome = .failure(GeminiError.truncated)
        await finishTranslate(h)
        #expect(h.panel.errors.count == 1)
        #expect(h.status.events.contains("error"))
    }

    @Test("a superseded translate does not switch off the spinner of the newer one")
    func translateSupersededKeepsSpinner() async {
        defer { TextCaptureService.accessibilityOverrideForTesting = nil }
        let h = makeHarness()
        h.gemini.blocking = true

        h.coordinator.handleTranslateTrigger()
        let first = h.coordinator.currentTranslateTask
        await waitUntil { h.gemini.waitingCount == 1 }

        h.coordinator.handleTranslateTrigger()
        let second = h.coordinator.currentTranslateTask
        await waitUntil { h.gemini.waitingCount == 2 }

        h.gemini.releaseNext()
        await first?.value
        #expect(!h.status.events.contains("loading:false"))

        h.gemini.releaseNext()
        await second?.value
        #expect(h.status.events.contains("loading:false"))
    }
}
