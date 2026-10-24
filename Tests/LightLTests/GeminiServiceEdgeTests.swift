import Testing
import Foundation
@testable import LightL

extension LightLTests {
    private func stubbedService() -> GeminiService {
        TruncatedStreamURLProtocol.reset()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [TruncatedStreamURLProtocol.self]
        return GeminiService(session: URLSession(configuration: config))
    }

    @Test("a 401 from the stream is surfaced after exactly one request")
    func unauthorizedIsNotRetried() async {
        let service = stubbedService()
        defer { TruncatedStreamURLProtocol.reset() }
        TruncatedStreamURLProtocol.queuedResponses = [
            (status: 401, body: "{\"error\": {\"code\": 401, \"message\": \"API key not valid\"}}")
        ]
        var thrown: Error?
        do {
            _ = try await service.translate(text: "hi", targetLanguage: LanguageModel.defaultTarget, apiKey: "bad", model: "gemini-edge", onChunk: { _ in })
        } catch { thrown = error }
        if case GeminiError.badServerResponse(let code, _)? = thrown { #expect(code == 401) } else { Issue.record("expected 401, got \(String(describing: thrown))") }
        #expect(TruncatedStreamURLProtocol.requestCount == 1)
    }

    @Test("a 429 quota error is surfaced after exactly one request")
    func quotaIsNotRetried() async {
        let service = stubbedService()
        defer { TruncatedStreamURLProtocol.reset() }
        TruncatedStreamURLProtocol.queuedResponses = [
            (status: 429, body: "{\"error\": {\"code\": 429, \"message\": \"Quota exceeded\"}}")
        ]
        var thrown: Error?
        do {
            _ = try await service.translate(text: "hi", targetLanguage: LanguageModel.defaultTarget, apiKey: "k", model: "gemini-edge", onChunk: { _ in })
        } catch { thrown = error }
        if case GeminiError.badServerResponse(let code, _)? = thrown { #expect(code == 429) } else { Issue.record("expected 429, got \(String(describing: thrown))") }
        #expect(TruncatedStreamURLProtocol.requestCount == 1)
    }

    @Test("a 500 from the stream falls back to one non-streaming request")
    func serverErrorFallsBack() async throws {
        let service = stubbedService()
        defer { TruncatedStreamURLProtocol.reset() }
        TruncatedStreamURLProtocol.queuedResponses = [
            (status: 500, body: "{\"error\": {\"code\": 500, \"message\": \"internal\"}}"),
            (status: 200, body: "{\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"Recovered\"}]}, \"finishReason\": \"STOP\"}]}")
        ]
        let result = try await service.translate(text: "hi", targetLanguage: LanguageModel.defaultTarget, apiKey: "k", model: "gemini-edge", onChunk: { _ in })
        #expect(result == "Recovered")
        #expect(TruncatedStreamURLProtocol.requestCount == 2)
    }

    @Test("input over the limit is rejected before any request")
    func inputTooLongMakesNoRequest() async {
        let service = stubbedService()
        defer { TruncatedStreamURLProtocol.reset() }
        let text = String(repeating: "a", count: GeminiService.maxInputCharacters + 1)
        var thrown: Error?
        do {
            _ = try await service.translate(text: text, targetLanguage: LanguageModel.defaultTarget, apiKey: "k", model: "gemini-edge", onChunk: { _ in })
        } catch { thrown = error }
        if case GeminiError.inputTooLong? = thrown {} else { Issue.record("expected inputTooLong, got \(String(describing: thrown))") }
        #expect(TruncatedStreamURLProtocol.requestCount == 0)
    }

    @Test("a model ID with invalid characters is rejected before any request")
    func invalidModelMakesNoRequest() async {
        let service = stubbedService()
        defer { TruncatedStreamURLProtocol.reset() }
        var thrown: Error?
        do {
            _ = try await service.rewrite(text: "hi", mode: .proofread, apiKey: "k", model: "gemini/../x")
        } catch { thrown = error }
        if case GeminiError.invalidModel? = thrown {} else { Issue.record("expected invalidModel, got \(String(describing: thrown))") }
        #expect(TruncatedStreamURLProtocol.requestCount == 0)
    }

    @Test("SSE parsing handles CRLF, data without a space and several events")
    func sseLineEdgeCases() throws {
        let lines = [
            "data:{\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"A\"}]}}]}\r",
            "\r",
            "data: {\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"B\"}]}, \"finishReason\": \"STOP\"}]}\r",
            "\r"
        ]
        #expect(try GeminiService.parseSSELines(lines) == "AB")
    }

    @Test("SSE parsing ignores comments, other fields and invalid JSON events")
    func sseIgnoresNoise() throws {
        let lines = [
            ": keep-alive",
            "event: message",
            "data: not json",
            "",
            "data: {\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"OK\"}]}, \"finishReason\": \"STOP\"}]}",
            ""
        ]
        #expect(try GeminiService.parseSSELines(lines) == "OK")
    }

    @Test("a stream with text but no finish reason is rejected by default and accepted when not required")
    func sseRequiresFinishByDefault() throws {
        let lines = ["data: {\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"Half\"}]}}]}", ""]
        #expect(throws: GeminiError.self) { _ = try GeminiService.parseSSELines(lines) }
        #expect(try GeminiService.parseSSELines(lines, requireFinish: false) == "Half")
    }

    @Test("stripInputTag keeps a trailing less-than sign in the final text but drops a partial tag while streaming")
    func stripTagFinalVersusStreaming() {
        let tag = "input-abc123def456"
        #expect(GeminiService.stripInputTag("a <", tag: tag, isFinal: true) == "a <")
        #expect(GeminiService.stripInputTag("a <", tag: tag) == "a")
        #expect(GeminiService.stripInputTag("a </input-abc", tag: tag) == "a")
        #expect(GeminiService.stripInputTag("x < y", tag: tag) == "x < y")
    }
}
