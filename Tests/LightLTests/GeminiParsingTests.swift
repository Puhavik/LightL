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
        #expect(GeminiModelOption.availableModels.count == 4)
        #expect(GeminiModelOption.availableModels.contains(where: { $0.modelId == "gemini-3.1-flash-lite" }))
        #expect(GeminiModelOption.availableModels.contains(where: { $0.modelId == "gemini-3.6-flash" }))
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

    @Test("GeminiModelOption contains flash lite and 3.6 flash")
    func geminiModelOptionAndSupportsThinking() {
        let flash31Option = GeminiModelOption.availableModels.first(where: { $0.modelId == "gemini-3.1-flash-lite" })
        #expect(flash31Option != nil)
        #expect(flash31Option?.modelId == "gemini-3.1-flash-lite")
        #expect(flash31Option?.id == "gemini-3.1-flash-lite")
        #expect(flash31Option?.localizedDisplayName == "Gemini 3.1 Flash-Lite")
        #expect(!flash31Option!.localizedDescription.isEmpty)

        let flash36Option = GeminiModelOption.availableModels.first(where: { $0.modelId == "gemini-3.6-flash" })
        #expect(flash36Option != nil)
        #expect(flash36Option?.modelId == "gemini-3.6-flash")
        #expect(flash36Option?.localizedDisplayName == "Gemini 3.6 Flash")
        #expect(!flash36Option!.localizedDescription.isEmpty)
    }

    @Test("GeminiService thinkingConfig selects minimal level for 3.x and zero budget for 2.x")
    func geminiThinkingConfigSelection() {
        let config35 = GeminiService.thinkingConfig(for: "gemini-3.5-flash-lite")
        #expect(config35["thinkingLevel"] as? String == "minimal")
        #expect(config35["thinkingBudget"] == nil)

        let config31 = GeminiService.thinkingConfig(for: "gemini-3.1-flash-lite")
        #expect(config31["thinkingLevel"] as? String == "minimal")

        let config25 = GeminiService.thinkingConfig(for: "gemini-2.5-flash")
        #expect(config25["thinkingBudget"] as? Int == 0)
        #expect(config25["thinkingLevel"] == nil)

        let config20 = GeminiService.thinkingConfig(for: "gemini-2.0-flash")
        #expect(config20["thinkingBudget"] as? Int == 0)

        let configPrefixed = GeminiService.thinkingConfig(for: "models/gemini-2.5-flash")
        #expect(configPrefixed["thinkingBudget"] as? Int == 0)
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
