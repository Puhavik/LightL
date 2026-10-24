import Testing
import SwiftUI
import Foundation
import Carbon
import AppKit
@testable import LightL

extension LightLTests {
    @Test("GeminiModelOption list and default model")
    func geminiModelsTests() {
        #expect(GeminiModelOption.defaultModel.modelId == "gemini-3.5-flash-lite")
        #expect(GeminiModelOption.availableModels.count >= 5)
        #expect(GeminiModelOption.availableModels.contains(where: { $0.modelId == "gemini-2.5-flash" }))
        #expect(GeminiModelOption.availableModels.contains(where: { $0.modelId == "gemini-3.8-flash" }))
    }

    @Test("GeminiError localized descriptions")
    func geminiErrorDescriptions() {
        let missingKey = GeminiError.missingApiKey
        let desc = missingKey.errorDescription ?? ""
        #expect(desc.contains("API") && (desc.contains("ключ") || desc.contains("key")))

        let badResp = GeminiError.badServerResponse(statusCode: 403, message: "Forbidden")
        #expect(badResp.errorDescription?.contains("403") == true)
    }

    @Test("GeminiService parses valid response and filters thought parts")
    func geminiParseValidAndThoughtResponse() throws {
        let jsonString = """
        {
            "candidates": [
                {
                    "content": {
                        "parts": [
                            {
                                "text": "Analyzing the sentence structure...",
                                "thought": true
                            },
                            {
                                "text": "Привет, мир!"
                            }
                        ]
                    },
                    "finishReason": "STOP"
                }
            ]
        }
        """
        let data = jsonString.data(using: .utf8)!
        let parsed = try GeminiService.parseResponseData(data)
        #expect(parsed == "Привет, мир!")
    }

    @Test("GeminiService detects safety blocks and prompt feedback blocks")
    func geminiSafetyBlocks() {
        let safetyCandidateJson = """
        {
            "candidates": [
                {
                    "finishReason": "SAFETY"
                }
            ]
        }
        """
        let data1 = safetyCandidateJson.data(using: .utf8)!
        #expect(throws: GeminiError.self) {
            try GeminiService.parseResponseData(data1)
        }

        let promptFeedbackJson = """
        {
            "promptFeedback": {
                "blockReason": "SAFETY"
            }
        }
        """
        let data2 = promptFeedbackJson.data(using: .utf8)!
        #expect(throws: GeminiError.self) {
            try GeminiService.parseResponseData(data2)
        }

        let recitationJson = """
        {
            "candidates": [
                {
                    "finishReason": "RECITATION"
                }
            ]
        }
        """
        let data3 = recitationJson.data(using: .utf8)!
        #expect(throws: GeminiError.self) {
            try GeminiService.parseResponseData(data3)
        }
    }

    @Test("GeminiService prewarm runs without error")
    func geminiPrewarmTest() async {
        await GeminiService.shared.prewarm()
    }

    @Test("GeminiModelOption localized strings and ID consistency")
    func geminiModelOptionStrings() {
        let option = GeminiModelOption(modelId: "gemini-3.5-flash-lite")
        #expect(option.id == "gemini-3.5-flash-lite")
        #expect(!option.localizedDisplayName.isEmpty)
        #expect(!option.localizedDescription.isEmpty)

        let custom = GeminiModelOption(modelId: "custom-model-id")
        #expect(custom.localizedDisplayName == "custom-model-id")
        #expect(custom.localizedDescription == "")
    }

    @Test("GeminiService parses multi-part response with interleaved thoughts and text")
    func geminiInterleavedThoughtResponse() throws {
        let jsonString = """
        {
            "candidates": [
                {
                    "content": {
                        "parts": [
                            { "thought": true, "text": "Analyzing English source text..." },
                            { "text": "Первая часть перевода. " },
                            { "thought": true, "text": "Refining style and tone..." },
                            { "text": "Вторая часть перевода." }
                        ]
                    },
                    "finishReason": "STOP"
                }
            ]
        }
        """
        let data = jsonString.data(using: .utf8)!
        let parsed = try GeminiService.parseResponseData(data)
        #expect(parsed == "Первая часть перевода. Вторая часть перевода.")
    }

    @Test("GeminiModelOption contains argon and 2.5 flash")
    func geminiModelOptionAndSupportsThinking() {
        // 1. GeminiModelOption contains gemini-4-argon and gemini-2.5-flash
        let argonOption = GeminiModelOption.availableModels.first(where: { $0.modelId == "gemini-4-argon" })
        #expect(argonOption != nil)
        #expect(argonOption?.modelId == "gemini-4-argon")
        #expect(argonOption?.id == "gemini-4-argon")
        #expect(argonOption?.localizedDisplayName == "Gemini 4 Argon")
        #expect(!argonOption!.localizedDescription.isEmpty)

        let flash25Option = GeminiModelOption.availableModels.first(where: { $0.modelId == "gemini-2.5-flash" })
        #expect(flash25Option != nil)
        #expect(flash25Option?.modelId == "gemini-2.5-flash")
        #expect(flash25Option?.localizedDisplayName == "Gemini 2.5 Flash")
        #expect(!flash25Option!.localizedDescription.isEmpty)
    }

    @Test("GeminiService API key sanitization filtering newlines, carriage returns, and whitespace")
    func geminiApiKeySanitization() {
        // 1. Sanitization filters \n, \r, tabs and spaces
        let rawKey = "  \r\n AIzaSy_FakeKey-12345 \t \n\r "
        let sanitized = GeminiService.sanitizeApiKey(rawKey)
        #expect(sanitized == "AIzaSy_FakeKey-12345")

        // 2. Whitespace inside key is also filtered
        let spacedKey = "AIza Sy Fake Key"
        #expect(GeminiService.sanitizeApiKey(spacedKey) == "AIzaSyFakeKey")

        // 3. Clean key remains completely unchanged
        let cleanKey = "AIzaSyD0NOTTOUCHmYkEY987654321"
        #expect(GeminiService.sanitizeApiKey(cleanKey) == cleanKey)

        // 4. Only whitespace and newlines becomes empty string
        let emptyish = "\r\n\t   \n"
        #expect(GeminiService.sanitizeApiKey(emptyish).isEmpty)

        // 5. Empty string remains empty
        #expect(GeminiService.sanitizeApiKey("").isEmpty)
    }
}
