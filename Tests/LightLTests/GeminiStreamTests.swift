import Testing
import SwiftUI
import Foundation
import Carbon
import AppKit
@testable import LightL

extension LightLTests {
    @Test("GeminiService response parsing error paths: empty candidate, missing parts, whitespace only, and malformed JSON")
    func geminiResponseParsingErrorPaths() {
        // 1. Malformed JSON
        let malformedData = "Invalid JSON data".data(using: .utf8)!
        #expect(throws: GeminiError.self) {
            try GeminiService.parseResponseData(malformedData)
        }

        // 2. Empty candidates array
        let emptyCandidatesJson = "{\"candidates\": []}".data(using: .utf8)!
        #expect(throws: GeminiError.self) {
            try GeminiService.parseResponseData(emptyCandidatesJson)
        }

        // 3. Missing candidates entirely
        let noCandidatesJson = "{}".data(using: .utf8)!
        #expect(throws: GeminiError.self) {
            try GeminiService.parseResponseData(noCandidatesJson)
        }

        // 4. Candidate with missing content/parts without finishReason
        let noPartsJson = "{\"candidates\": [{}]}".data(using: .utf8)!
        #expect(throws: GeminiError.self) {
            try GeminiService.parseResponseData(noPartsJson)
        }

        // 5. Candidate with empty parts and finishReason "MAX_TOKENS"
        let maxTokensJson = """
        {
            "candidates": [
                {
                    "content": { "parts": [] },
                    "finishReason": "MAX_TOKENS"
                }
            ]
        }
        """.data(using: .utf8)!
        #expect(throws: GeminiError.self) {
            try GeminiService.parseResponseData(maxTokensJson)
        }

        // 6. Candidate with only thought parts (no non-thought text)
        let onlyThoughtsJson = """
        {
            "candidates": [
                {
                    "content": {
                        "parts": [
                            { "thought": true, "text": "Thinking..." }
                        ]
                    },
                    "finishReason": "STOP"
                }
            ]
        }
        """.data(using: .utf8)!
        #expect(throws: GeminiError.self) {
            try GeminiService.parseResponseData(onlyThoughtsJson)
        }

        // 7. Candidate with whitespace-only non-thought text
        let whitespaceJson = """
        {
            "candidates": [
                {
                    "content": {
                        "parts": [
                            { "text": "   \\n\\t  " }
                        ]
                    },
                    "finishReason": "STOP"
                }
            ]
        }
        """.data(using: .utf8)!
        #expect(throws: GeminiError.self) {
            try GeminiService.parseResponseData(whitespaceJson)
        }
    }

    @Test("GeminiService SSE line parsing handles data: with and without spaces, and multiline payloads")
    func geminiSSELineParsing() throws {
        // 1. Single chunk with "data: " (with space)
        let sseWithSpace = [
            "data: {\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"Hello \"}]}}]}",
            ""
        ]
        var chunks: [String] = []
        let result1 = try GeminiService.parseSSELines(sseWithSpace, requireFinish: false) { chunk in
            chunks.append(chunk)
        }
        #expect(result1 == "Hello")
        #expect(chunks == ["Hello "])

        // 2. Single chunk with "data:" (without space)
        let sseWithoutSpace = [
            "data:{\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"World!\"}]}}]}",
            ""
        ]
        let result2 = try GeminiService.parseSSELines(sseWithoutSpace, requireFinish: false)
        #expect(result2 == "World!")

        // 3. Multiline payload chunking across multiple "data:" lines ending with empty line
        let multilineSSE = [
            "data: {",
            "data:   \"candidates\": [",
            "data:     {",
            "data:       \"content\": {",
            "data:         \"parts\": [",
            "data:           {\"text\": \"Line1 \"},",
            "data:           {\"text\": \"Line2\"}",
            "data:         ]",
            "data:       }",
            "data:     }",
            "data:   ]",
            "data: }",
            ""
        ]
        let result3 = try GeminiService.parseSSELines(multilineSSE, requireFinish: false)
        #expect(result3 == "Line1 Line2")

        // 4. Multiple distinct events in sequence, with mixed prefixes and trailing flush at EOF without final empty line
        let sequenceSSE = [
            "data: {\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"One \"}]}}]}",
            "",
            "data:{\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"Two \"}]}}]}",
            "",
            "data: {\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"Three\"}]}}]}" // no trailing newline
        ]
        var progressiveChunks: [String] = []
        let result4 = try GeminiService.parseSSELines(sequenceSSE, requireFinish: false) { chunk in
            progressiveChunks.append(chunk)
        }
        #expect(result4 == "One Two Three")
        #expect(progressiveChunks == ["One ", "One Two ", "One Two Three"])

        // 5. Lines with CRLF (\r\n) stripping
        let crlfSSE = [
            "data: {\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"CRLF Test\"}]}}]}\r",
            "\r"
        ]
        let result5 = try GeminiService.parseSSELines(crlfSSE, requireFinish: false)
        #expect(result5 == "CRLF Test")

        // 6. Comments or non-data lines ignored
        let commentSSE = [
            ": keepalive ping",
            "data: {\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"Real Content\"}]}}]}",
            ""
        ]
        let result6 = try GeminiService.parseSSELines(commentSSE, requireFinish: false)
        #expect(result6 == "Real Content")
    }

    @Test("GeminiService mid-stream GeminiErrorResponse JSON error detection and extraction")
    func geminiMidStreamErrorDetection() throws {
        // 1. Direct decoding of GeminiErrorResponse
        let errorJson = """
        {
            "error": {
                "code": 429,
                "message": "Resource has been exhausted (e.g. check quota)."
            }
        }
        """
        let errorData = errorJson.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(GeminiService.GeminiErrorResponse.self, from: errorData)
        #expect(decoded.error?.code == 429)
        #expect(decoded.error?.message == "Resource has been exhausted (e.g. check quota).")

        // 2. Mid-stream error event in SSE lines throws GeminiError.badServerResponse with code and message
        let errorSSE = [
            "data: {\"error\": {\"code\": 403, \"message\": \"API key not valid. Please pass a valid API key.\"}}",
            ""
        ]
        #expect(throws: GeminiError.self) {
            try GeminiService.parseSSELines(errorSSE)
        }

        do {
            _ = try GeminiService.parseSSELines(errorSSE)
            #expect(Bool(false), "Expected error to be thrown")
        } catch let GeminiError.badServerResponse(code, message) {
            #expect(code == 403)
            #expect(message == "API key not valid. Please pass a valid API key.")
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }

        // 3. Error without code defaults to 500
        let errorNoCodeSSE = [
            "data: {\"error\": {\"message\": \"Internal backend timeout\"}}",
            ""
        ]
        do {
            _ = try GeminiService.parseSSELines(errorNoCodeSSE)
            #expect(Bool(false), "Expected error to be thrown")
        } catch let GeminiError.badServerResponse(code, message) {
            #expect(code == 500)
            #expect(message == "Internal backend timeout")
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }

        // 4. Initial content followed by mid-stream error aborts and throws
        let contentThenErrorSSE = [
            "data: {\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"Starting stream...\"}]}}]}",
            "",
            "data: {\"error\": {\"code\": 503, \"message\": \"Service Unavailable\"}}",
            ""
        ]
        do {
            _ = try GeminiService.parseSSELines(contentThenErrorSSE)
            #expect(Bool(false), "Expected error to be thrown")
        } catch let GeminiError.badServerResponse(code, message) {
            #expect(code == 503)
            #expect(message == "Service Unavailable")
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
    }

    @Test("GeminiService does not retry a blocked stream and falls back when a stream ends without finishReason")
    func blockedAndIncompleteStreams() async throws {
        defer { TruncatedStreamURLProtocol.body = TruncatedStreamURLProtocol.truncatedBody }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [TruncatedStreamURLProtocol.self]
        let service = GeminiService(session: URLSession(configuration: config))

        TruncatedStreamURLProtocol.requestCount = 0
        TruncatedStreamURLProtocol.body = "data: {\"candidates\": [{\"content\": {\"parts\": []}, \"finishReason\": \"SAFETY\"}]}\n\n"
        await #expect(throws: GeminiError.self) {
            _ = try await service.translate(text: "hello", targetLanguage: LanguageModel.defaultTarget, apiKey: "k", model: "gemini-test", onChunk: { _ in })
        }
        #expect(TruncatedStreamURLProtocol.requestCount == 1)

        TruncatedStreamURLProtocol.requestCount = 0
        TruncatedStreamURLProtocol.body = "data: {\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"Hel\"}]}}]}\n\n"
        _ = try? await service.translate(text: "hello", targetLanguage: LanguageModel.defaultTarget, apiKey: "k", model: "gemini-test", onChunk: { _ in })
        #expect(TruncatedStreamURLProtocol.requestCount == 2)
    }

    @Test("GeminiService remembers a model that rejects thinking only after the retry succeeds")
    func thinkingRejectionCache() async throws {
        defer { TruncatedStreamURLProtocol.reset() }
        TruncatedStreamURLProtocol.reset()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [TruncatedStreamURLProtocol.self]
        let service = GeminiService(session: URLSession(configuration: config))
        let ok = "data: {\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"Hello\"}]}, \"finishReason\": \"STOP\"}]}\n\n"
        TruncatedStreamURLProtocol.queuedResponses = [
            (status: 400, body: "{\"error\": {\"code\": 400, \"message\": \"Thinking budget is not supported\"}}"),
            (status: 200, body: ok)
        ]
        let first = try await service.translate(text: "hi", targetLanguage: LanguageModel.defaultTarget, apiKey: "k", model: "gemini-cache-test", onChunk: { _ in })
        #expect(first == "Hello")
        #expect(TruncatedStreamURLProtocol.requestBodies.count == 2)
        #expect(TruncatedStreamURLProtocol.requestBodies[0].contains("thinkingConfig"))
        #expect(!TruncatedStreamURLProtocol.requestBodies[1].contains("thinkingConfig"))

        TruncatedStreamURLProtocol.queuedResponses = [(status: 200, body: ok)]
        _ = try await service.translate(text: "hi", targetLanguage: LanguageModel.defaultTarget, apiKey: "k", model: "gemini-cache-test", onChunk: { _ in })
        #expect(TruncatedStreamURLProtocol.requestBodies.count == 3)
        #expect(!TruncatedStreamURLProtocol.requestBodies[2].contains("thinkingConfig"))
    }

    @Test("GeminiService fallback request after an incomplete stream still rejects truncated output")
    func fallbackRejectsTruncated() async {
        defer { TruncatedStreamURLProtocol.reset() }
        TruncatedStreamURLProtocol.reset()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [TruncatedStreamURLProtocol.self]
        let service = GeminiService(session: URLSession(configuration: config))
        TruncatedStreamURLProtocol.queuedResponses = [
            (status: 200, body: "data: {\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"Hel\"}]}}]}\n\n"),
            (status: 200, body: "{\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"Hello\"}]}, \"finishReason\": \"MAX_TOKENS\"}]}")
        ]
        var thrown: Error?
        do {
            _ = try await service.translate(text: "hi", targetLanguage: LanguageModel.defaultTarget, apiKey: "k", model: "gemini-fallback-test", onChunk: { _ in })
        } catch {
            thrown = error
        }
        if case GeminiError.truncated? = thrown {} else { Issue.record("expected .truncated, got \(String(describing: thrown))") }
        #expect(TruncatedStreamURLProtocol.requestCount == 2)
    }

    @Test("GeminiService streams consecutive SSE events in one request")
    func streamAccumulatesConsecutiveEvents() async throws {
        TruncatedStreamURLProtocol.requestCount = 0
        TruncatedStreamURLProtocol.body = "data: {\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"Hel\"}]}}]}\n\n"
            + "data: {\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"lo\"}]}}]}\n\n"
            + "data: {\"candidates\": [{\"content\": {\"parts\": []}, \"finishReason\": \"STOP\"}]}\n\n"
        defer { TruncatedStreamURLProtocol.body = TruncatedStreamURLProtocol.truncatedBody }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [TruncatedStreamURLProtocol.self]
        let service = GeminiService(session: URLSession(configuration: config))

        let result = try await service.translate(
            text: "hello",
            targetLanguage: LanguageModel.defaultTarget,
            apiKey: "k",
            model: "gemini-test",
            onChunk: { _ in }
        )
        #expect(result == "Hello")
        #expect(TruncatedStreamURLProtocol.requestCount == 1)
    }

    @Test("GeminiService translate surfaces a truncated stream without falling back to a second request")
    func truncatedStreamDoesNotFallBack() async {
        TruncatedStreamURLProtocol.requestCount = 0
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [TruncatedStreamURLProtocol.self]
        let service = GeminiService(session: URLSession(configuration: config))

        var thrown: Error?
        do {
            _ = try await service.translate(
                text: "hello",
                targetLanguage: LanguageModel.defaultTarget,
                apiKey: "k",
                model: "gemini-test",
                onChunk: { _ in }
            )
        } catch {
            thrown = error
        }
        if case GeminiError.truncated? = thrown {} else { Issue.record("expected .truncated, got \(String(describing: thrown))") }
        #expect(TruncatedStreamURLProtocol.requestCount == 1)
    }

    @Test("GeminiService rejects a stream that ends with MAX_TOKENS")
    func geminiMaxTokensRejectsStream() {
        let maxTokensSSE = [
            "data: {\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"Translated portion before token limit.\"}]}}]}",
            "",
            "data: {\"candidates\": [{\"content\": {\"parts\": []}, \"finishReason\": \"MAX_TOKENS\"}]}",
            ""
        ]
        #expect(throws: GeminiError.self) {
            _ = try GeminiService.parseSSELines(maxTokensSSE)
        }
    }
}
