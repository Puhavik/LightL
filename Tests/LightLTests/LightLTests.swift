import Testing
import Foundation
import Carbon
@testable import LightL

@Suite("LightL Unit Tests")
struct LightLTests {

    @Test("ShortcutModel default values and display strings")
    func shortcutDefaultsAndDisplayString() {
        let translate = ShortcutModel.defaultTranslate
        #expect(translate.keyCode == UInt32(kVK_ANSI_C))
        #expect(translate.displayString.contains("⌘"))
        #expect(translate.displayString.contains("⌥"))
        #expect(translate.displayString.contains("C"))

        let rewrite = ShortcutModel.defaultRewrite
        #expect(rewrite.keyCode == UInt32(kVK_ANSI_W))
        #expect(rewrite.displayString.contains("⌘"))
        #expect(rewrite.displayString.contains("⌥"))
        #expect(rewrite.displayString.contains("W"))
    }

    @Test("ShortcutModel Codable roundtrip")
    func shortcutCodableRoundtrip() throws {
        let original = ShortcutModel(keyCode: UInt32(kVK_ANSI_T), modifiers: UInt32(cmdKey | shiftKey))
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ShortcutModel.self, from: data)

        #expect(decoded == original)
        #expect(decoded.keyCode == UInt32(kVK_ANSI_T))
    }

    @Test("LanguageModel defaults and lookups")
    func languageModelTests() {
        #expect(LanguageModel.defaultTarget.code == "ru")
        #expect(!LanguageModel.supportedLanguages.isEmpty)

        let english = LanguageModel.supportedLanguages.first(where: { $0.code == "en" })
        #expect(english != nil)
        #expect(english?.name == "Английский")
        #expect(english?.nativeName == "English")
    }

    @Test("RewriteMode titles, comparisons and no DeepL branding")
    func rewriteModeTests() throws {
        let proofread = RewriteMode.proofread
        #expect(!proofread.title.isEmpty)
        #expect(!proofread.description.isEmpty)
        #expect(!proofread.wordingBehavior.isEmpty)
        #expect(!proofread.temperatureDescription.isEmpty)
        #expect(!proofread.exampleOriginal.isEmpty)
        #expect(!proofread.exampleResult.isEmpty)

        let improve = RewriteMode.improveStyle
        #expect(!improve.title.isEmpty)
        #expect(!improve.title.contains("DeepL"))
        #expect(!improve.description.contains("DeepL"))
        #expect(!improve.wordingBehavior.isEmpty)
        #expect(!improve.temperatureDescription.isEmpty)
        #expect(!improve.exampleResult.isEmpty)

        let data = try JSONEncoder().encode(proofread)
        let decoded = try JSONDecoder().decode(RewriteMode.self, from: data)
        #expect(decoded == .proofread)
    }

    @Test("Localization system detects system language and supports manual overrides")
    func localizationTests() {
        let sys = AppLanguage.systemLanguage
        #expect(sys == .russian || sys == .english)

        let ruText = L10n.tr(ru: "Привет", en: "Hello")
        #expect(ruText == (L10n.currentLanguage == .russian ? "Привет" : "Hello"))
    }

    @Test("GeminiModelOption list and default model")
    func geminiModelsTests() {
        #expect(GeminiModelOption.defaultModel.modelId == "gemini-3.5-flash-lite")
        #expect(GeminiModelOption.availableModels.count >= 4)
        #expect(GeminiModelOption.availableModels.contains(where: { $0.modelId == "gemini-3.8-flash" }))
    }

    @Test("Coordinate conversion formula: Carbon/AX (top-left) to Cocoa (bottom-left)")
    func coordinateConversionFormula() {
        let primaryScreenHeight: CGFloat = 1080
        let axRect = CGRect(x: 100, y: 50, width: 200, height: 20) // near top of screen

        let cocoaY = primaryScreenHeight - axRect.origin.y - axRect.height
        let cocoaRect = CGRect(x: axRect.origin.x, y: cocoaY, width: axRect.width, height: axRect.height)

        #expect(cocoaRect.origin.y == 1010) // Near top of Cocoa coordinate system
        #expect(cocoaRect.origin.x == 100)
        #expect(cocoaRect.height == 20)
    }

    @Test("GeminiError localized descriptions")
    func geminiErrorDescriptions() {
        let missingKey = GeminiError.missingApiKey
        let desc = missingKey.errorDescription ?? ""
        #expect(desc.contains("API") && (desc.contains("ключ") || desc.contains("key")))

        let badResp = GeminiError.badServerResponse(statusCode: 403, message: "Forbidden")
        #expect(badResp.errorDescription?.contains("403") == true)
    }

    @Test("KeychainHelper save and load roundtrip")
    func keychainHelperTest() {
        let testAccount = "TestApiKey_\(UUID().uuidString)"
        let testService = "com.puhavik.LightL.tests"
        let testKey = "test-api-key-\(UUID().uuidString)"

        KeychainHelper.saveApiKey(testKey, account: testAccount, service: testService)
        let loaded = KeychainHelper.loadApiKey(account: testAccount, service: testService)
        #expect(loaded == testKey)

        KeychainHelper.deleteApiKey(account: testAccount, service: testService)
        #expect(KeychainHelper.loadApiKey(account: testAccount, service: testService) == nil)
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

    @Test("AppSettings posts notification on property changes")
    @MainActor
    func appSettingsNotificationTest() {
        final class Box: @unchecked Sendable {
            var received = false
        }
        let box = Box()
        let settings = AppSettings.shared

        let observer = NotificationCenter.default.addObserver(
            forName: AppSettings.didChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            box.received = true
        }

        let oldLang = settings.targetLanguageCode
        settings.targetLanguageCode = (oldLang == "ru") ? "en" : "ru"
        #expect(box.received == true)

        // Revert
        settings.targetLanguageCode = oldLang
        NotificationCenter.default.removeObserver(observer)
    }
}
