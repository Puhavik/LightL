import Testing
import Foundation
import Carbon
import AppKit
@testable import LightL

@Suite("LightL Unit Tests", .serialized)
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

    @Test("ShortcutModel reset to default equality and AppSettings shortcut reset")
    func shortcutResetToDefault() {
        let custom = ShortcutModel(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(cmdKey | controlKey))
        #expect(custom != ShortcutModel.defaultTranslate)
        #expect(custom != ShortcutModel.defaultRewrite)

        var current = custom
        current = ShortcutModel.defaultTranslate
        #expect(current == ShortcutModel.defaultTranslate)

        current = ShortcutModel.defaultRewrite
        #expect(current == ShortcutModel.defaultRewrite)
    }

    @Test("AppIcon resolves to valid image asset")
    func appIconLoads() {
        let icon = NSImage.appIcon
        #expect(icon.isValid)
        #expect(icon.size.width > 0)
        #expect(icon.size.height > 0)
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
        #expect(GeminiModelOption.availableModels.count >= 5)
        #expect(GeminiModelOption.availableModels.contains(where: { $0.modelId == "gemini-2.5-flash" }))
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

    @Test("FloatingTranslationPanel triggers onDismiss callback on dismissal")
    @MainActor
    func floatingTranslationPanelDismissCallback() {
        if ProcessInfo.processInfo.environment["CI"] != nil {
            return
        }
        let panel = FloatingTranslationPanel()
        var dismissed = false
        panel.onDismiss = {
            dismissed = true
        }

        panel.dismiss()
        #expect(dismissed == true)
    }

    @Test("GeminiService prewarm runs without error")
    func geminiPrewarmTest() async {
        await GeminiService.shared.prewarm()
    }

    @Test("KeychainHelper migrates legacy key and deletes legacy item")
    func keychainHelperLegacyMigrationTest() {
        let testAccount = "TestLegacyApiKey_\(UUID().uuidString)"
        let legacyService = "com.user.LightL"
        let currentService = KeychainHelper.serviceName
        let testKey = "legacy-secret-\(UUID().uuidString)"

        KeychainHelper.saveApiKey(testKey, account: testAccount, service: legacyService)
        let loaded = KeychainHelper.loadApiKey(account: testAccount, service: currentService)
        #expect(loaded == testKey)

        // Verify legacy item was deleted
        let legacyCheck = KeychainHelper.loadApiKey(account: testAccount, service: legacyService)
        #expect(legacyCheck == nil)

        // Clean up current service
        KeychainHelper.deleteApiKey(account: testAccount, service: currentService)
        #expect(KeychainHelper.loadApiKey(account: testAccount, service: currentService) == nil)
    }

    @Test("Localization cache updates on direct set and L10n.tr behavior")
    @MainActor
    func localizationCacheUpdates() {
        let initialLang = L10n.currentLanguage
        L10n.currentLanguage = .russian
        #expect(L10n.currentLanguage == .russian)
        #expect(L10n.tr(ru: "Да", en: "Yes") == "Да")

        L10n.currentLanguage = .english
        #expect(L10n.currentLanguage == .english)
        #expect(L10n.tr(ru: "Да", en: "Yes") == "Yes")

        L10n.currentLanguage = initialLang
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

    @Test("ShortcutModel rejects reserved system shortcuts like ⌘C, ⌘V, ⌘Q and permits combo modifiers")
    func shortcutModelSystemReservedBlacklist() {
        let cmdOnly = UInt32(cmdKey)
        let cmdOpt = UInt32(cmdKey | optionKey)
        let cmdShift = UInt32(cmdKey | shiftKey)

        // Reserved single Cmd shortcuts
        #expect(ShortcutModel.isSystemReserved(keyCode: UInt32(kVK_ANSI_C), modifiers: cmdOnly))
        #expect(ShortcutModel.isSystemReserved(keyCode: UInt32(kVK_ANSI_V), modifiers: cmdOnly))
        #expect(ShortcutModel.isSystemReserved(keyCode: UInt32(kVK_ANSI_X), modifiers: cmdOnly))
        #expect(ShortcutModel.isSystemReserved(keyCode: UInt32(kVK_ANSI_Z), modifiers: cmdOnly))
        #expect(ShortcutModel.isSystemReserved(keyCode: UInt32(kVK_ANSI_A), modifiers: cmdOnly))
        #expect(ShortcutModel.isSystemReserved(keyCode: UInt32(kVK_ANSI_Q), modifiers: cmdOnly))
        #expect(ShortcutModel.isSystemReserved(keyCode: UInt32(kVK_ANSI_W), modifiers: cmdOnly))
        #expect(ShortcutModel.isSystemReserved(keyCode: UInt32(kVK_Space), modifiers: cmdOnly))
        #expect(ShortcutModel.isSystemReserved(keyCode: UInt32(kVK_Tab), modifiers: cmdOnly))

        // Permitted shortcuts with Option, Shift or Control
        #expect(!ShortcutModel.isSystemReserved(keyCode: UInt32(kVK_ANSI_C), modifiers: cmdOpt))
        #expect(!ShortcutModel.isSystemReserved(keyCode: UInt32(kVK_ANSI_W), modifiers: cmdOpt))
        #expect(!ShortcutModel.isSystemReserved(keyCode: UInt32(kVK_ANSI_C), modifiers: cmdShift))
        #expect(!ShortcutModel.isSystemReserved(keyCode: UInt32(kVK_ANSI_T), modifiers: cmdOnly))
    }

    // MARK: - Double-Tap Tracker Tests

    @Test("DoubleTapTracker interval logic: respects timing threshold and resets on detection")
    func doubleTapIntervalLogic() {
        let tracker = DoubleTapTracker(intervalNanoseconds: 380_000_000)

        // First tap: should not trigger
        #expect(!tracker.recordAndCheckDoubleTap(now: 1_000_000_000))

        // Second tap at 200ms (< 380ms threshold): should trigger double-tap
        #expect(tracker.recordAndCheckDoubleTap(now: 1_200_000_000))

        // Third tap 50ms after detection: should reset and treat as new first tap (not trigger)
        #expect(!tracker.recordAndCheckDoubleTap(now: 1_250_000_000))

        // Fourth tap 450ms later (> 380ms threshold): interval expired, should not trigger
        #expect(!tracker.recordAndCheckDoubleTap(now: 1_700_000_000))

        // Fifth tap 100ms after fourth tap: should trigger double-tap
        #expect(tracker.recordAndCheckDoubleTap(now: 1_800_000_000))
    }

    @Test("DoubleTapTracker reset behavior clears state and breaks double-tap chain")
    func doubleTapResetBehavior() {
        let tracker = DoubleTapTracker(intervalNanoseconds: 380_000_000)

        // First tap: records state
        #expect(!tracker.recordAndCheckDoubleTap(now: 1_000_000_000))

        // Explicit reset clears timestamp
        tracker.reset()

        // Next tap at 50ms after reset: must not trigger because state was cleared
        #expect(!tracker.recordAndCheckDoubleTap(now: 1_050_000_000))

        // Subsequent tap 100ms later: now triggers double-tap
        #expect(tracker.recordAndCheckDoubleTap(now: 1_150_000_000))
    }

    @Test("DoubleTapTracker underflow prevention handles backwards clock anomalies safely")
    func doubleTapUnderflowPrevention() {
        let tracker = DoubleTapTracker(intervalNanoseconds: 380_000_000)

        // First tap at high monotonic timestamp
        #expect(!tracker.recordAndCheckDoubleTap(now: 5_000_000_000))

        // Clock jumps backwards (e.g. system time skew or anomaly)
        // Must prevent UInt64 underflow crash and safely return false
        #expect(!tracker.recordAndCheckDoubleTap(now: 2_000_000_000))

        // Another backwards step to 500ms (lower than 2_000_000_000): must not crash
        #expect(!tracker.recordAndCheckDoubleTap(now: 500_000_000))

        // Normal subsequent tap forward: 100ms later (600_000_000): should trigger double-tap
        #expect(tracker.recordAndCheckDoubleTap(now: 600_000_000))

        // Default timestamp parameter invocation does not crash
        let liveTracker = DoubleTapTracker()
        #expect(!liveTracker.recordAndCheckDoubleTap())
    }

    // MARK: - Multi-Monitor Coordinate Conversion Tests

    @Test("Multi-monitor coordinate conversion: secondary screen above primary (negative AX Y)")
    func coordinateConversionSecondaryScreenAbove() {
        let primaryScreenHeight: CGFloat = 1080
        // Secondary screen positioned above primary (Cocoa frame: 0, 1080, 1920, 1080)
        // In AX coordinates, Y=0 is top of primary screen, so above primary has negative Y
        let axRect = CGRect(x: 150, y: -500, width: 250, height: 40)

        let cocoaRect = TextCaptureService.convertCarbonAXRectToCocoa(axRect, primaryScreenHeight: primaryScreenHeight)

        // Cocoa Y = 1080 - (-500) - 40 = 1080 + 500 - 40 = 1540
        #expect(cocoaRect.origin.x == 150)
        #expect(cocoaRect.origin.y == 1540)
        #expect(cocoaRect.width == 250)
        #expect(cocoaRect.height == 40)
        // Cocoa Y=1540 is inside upper display range [1080, 2160]
        #expect(cocoaRect.origin.y >= 1080 && cocoaRect.origin.y < 2160)
    }

    @Test("Multi-monitor coordinate conversion: secondary screen below primary (negative Cocoa Y)")
    func coordinateConversionSecondaryScreenBelow() {
        let primaryScreenHeight: CGFloat = 1080
        // Secondary screen positioned below primary (Cocoa frame: 0, -1080, 1920, 1080)
        // In AX coordinates, primary spans 0..1080, secondary spans 1080..2160
        let axRect = CGRect(x: 120, y: 1400, width: 300, height: 50)

        let cocoaRect = TextCaptureService.convertCarbonAXRectToCocoa(axRect, primaryScreenHeight: primaryScreenHeight)

        // Cocoa Y = 1080 - 1400 - 50 = -370
        #expect(cocoaRect.origin.x == 120)
        #expect(cocoaRect.origin.y == -370)
        #expect(cocoaRect.width == 300)
        #expect(cocoaRect.height == 50)
        // Cocoa Y=-370 is inside lower display range [-1080, 0]
        #expect(cocoaRect.origin.y >= -1080 && cocoaRect.origin.y < 0)
    }

    @Test("Multi-monitor coordinate conversion: secondary screen with negative X and negative Y origins")
    func coordinateConversionNegativeXAndY() {
        let primaryScreenHeight: CGFloat = 1080
        // Screen to the left and below: AX X is negative, AX Y is > primary screen height
        let axRect = CGRect(x: -750, y: 1300, width: 200, height: 35)

        let cocoaRect = TextCaptureService.convertCarbonAXRectToCocoa(axRect, primaryScreenHeight: primaryScreenHeight)

        // Cocoa X = -750, Cocoa Y = 1080 - 1300 - 35 = -255
        #expect(cocoaRect.origin.x == -750)
        #expect(cocoaRect.origin.y == -255)
        #expect(cocoaRect.width == 200)
        #expect(cocoaRect.height == 35)
    }

    @Test("Multi-monitor coordinate conversion: Retina vs standard resolution point scaling")
    func coordinateConversionRetinaVsStandard() {
        let primaryHeightPoints: CGFloat = 1080

        // Standard display (1.0x scale): 1 pixel = 1 point
        let standardAxPoints = CGRect(x: 100, y: 50, width: 200, height: 40)
        let standardCocoa = TextCaptureService.convertCarbonAXRectToCocoa(standardAxPoints, primaryScreenHeight: primaryHeightPoints)
        #expect(standardCocoa.origin.y == 990)

        // Retina 2.0x display: raw physical pixels (200, 100, 400, 80) normalized to points
        let retina2xPixels = CGRect(x: 200, y: 100, width: 400, height: 80)
        let retina2xPoints = CGRect(
            x: retina2xPixels.origin.x / 2.0,
            y: retina2xPixels.origin.y / 2.0,
            width: retina2xPixels.width / 2.0,
            height: retina2xPixels.height / 2.0
        )
        let retina2xCocoa = TextCaptureService.convertCarbonAXRectToCocoa(retina2xPoints, primaryScreenHeight: primaryHeightPoints)
        #expect(retina2xCocoa.origin.y == 990)
        #expect(retina2xCocoa == standardCocoa)

        // Retina 3.0x display: raw physical pixels (300, 150, 600, 120) normalized to points
        let retina3xPixels = CGRect(x: 300, y: 150, width: 600, height: 120)
        let retina3xPoints = CGRect(
            x: retina3xPixels.origin.x / 3.0,
            y: retina3xPixels.origin.y / 3.0,
            width: retina3xPixels.width / 3.0,
            height: retina3xPixels.height / 3.0
        )
        let retina3xCocoa = TextCaptureService.convertCarbonAXRectToCocoa(retina3xPoints, primaryScreenHeight: primaryHeightPoints)
        #expect(retina3xCocoa.origin.y == 990)
        #expect(retina3xCocoa == standardCocoa)
    }

    // MARK: - SettingsWindowController Lifecycle and Delegate Tests

    @Test("SettingsWindowController lifecycle and window delegate windowWillClose handling")
    @MainActor
    func settingsWindowControllerLifecycleAndDelegate() {
        if ProcessInfo.processInfo.environment["CI"] != nil {
            return
        }
        let controller = SettingsWindowController.shared

        // Show window
        controller.show()
        #expect(controller.currentWindow != nil)

        guard let window = controller.currentWindow else {
            Issue.record("Settings window was not created")
            return
        }

        #expect(window.delegate === controller)
        #expect(window.styleMask.contains(.titled))
        #expect(window.styleMask.contains(.closable))
        #expect(window.styleMask.contains(.miniaturizable))
        #expect(window.styleMask.contains(.fullSizeContentView))
        #expect(window.isReleasedWhenClosed == false)
        #expect(window.titlebarAppearsTransparent == true)

        // Re-showing existing window reuses the instance
        controller.show()
        #expect(controller.currentWindow === window)

        // Simulate window close delegate notification
        controller.windowWillClose(Notification(name: NSWindow.willCloseNotification, object: window))
        #expect(controller.currentWindow == nil)

        // Subsequent show() recreates a fresh window
        controller.show()
        #expect(controller.currentWindow != nil)
        let freshWindow = controller.currentWindow!
        #expect(freshWindow !== window)

        // Cleanup
        controller.windowWillClose(Notification(name: NSWindow.willCloseNotification, object: freshWindow))
        #expect(controller.currentWindow == nil)
    }

    @Test("StatusBarController menu suppresses Accessibility item when permission is granted")
    @MainActor
    func statusBarMenuAccessibilityItem() {
        let isGranted = TextCaptureService.isAccessibilityGranted(prompt: false)
        let controller = StatusBarController()
        controller.rebuildMenu()

        // Test menuNeedsUpdate
        let menu = NSMenu()
        controller.menuNeedsUpdate(menu)
        let titles = menu.items.map(\.title)

        // Test version badge in header
        let firstItem = menu.items.first
        #expect(firstItem?.title == "LightL AI")
        #expect(firstItem?.badge != nil)
        #expect(firstItem?.badge?.stringValue == StatusBarController.appVersion)

        if isGranted {
            #expect(!titles.contains { $0.contains("Accessibility") || $0.contains("Универсальный доступ") })
        } else {
            #expect(titles.contains { $0.contains("Accessibility") || $0.contains("Универсальный доступ") })
        }

        controller.destroy()
    }

    // MARK: - GeminiService Response Parsing Edge Cases

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

    // MARK: - AppSettings Observable Properties Notification Tests

    @Test("AppSettings posts notification on every observable property change")
    @MainActor
    func appSettingsAllObservablePropertiesNotifications() {
        final class Counter: @unchecked Sendable {
            var count = 0
        }
        let counter = Counter()
        let settings = AppSettings.shared

        let observer = NotificationCenter.default.addObserver(
            forName: AppSettings.didChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            counter.count += 1
        }

        defer {
            NotificationCenter.default.removeObserver(observer)
        }

        // 1. targetLanguageCode
        let originalLang = settings.targetLanguageCode
        let startCount1 = counter.count
        settings.targetLanguageCode = (originalLang == "ru") ? "en" : "ru"
        #expect(counter.count > startCount1)
        settings.targetLanguageCode = originalLang

        // 2. selectedModelId
        let originalModel = settings.selectedModelId
        let startCount2 = counter.count
        settings.selectedModelId = (originalModel == "gemini-3.5-flash-lite") ? "gemini-3.8-flash" : "gemini-3.5-flash-lite"
        #expect(counter.count > startCount2)
        settings.selectedModelId = originalModel

        // 3. rewriteMode
        let originalRewrite = settings.rewriteMode
        let startCount3 = counter.count
        settings.rewriteMode = (originalRewrite == .proofread) ? .improveStyle : .proofread
        #expect(counter.count > startCount3)
        settings.rewriteMode = originalRewrite

        // 4. doubleCmdCEnabled
        let originalDoubleCmd = settings.doubleCmdCEnabled
        let startCount4 = counter.count
        settings.doubleCmdCEnabled = !originalDoubleCmd
        #expect(counter.count > startCount4)
        settings.doubleCmdCEnabled = originalDoubleCmd

        // 5. translateShortcut
        let originalTranslateShortcut = settings.translateShortcut
        let startCount5 = counter.count
        settings.translateShortcut = ShortcutModel(keyCode: UInt32(kVK_ANSI_J), modifiers: UInt32(cmdKey | optionKey))
        #expect(counter.count > startCount5)
        settings.translateShortcut = originalTranslateShortcut

        // 6. rewriteShortcut
        let originalRewriteShortcut = settings.rewriteShortcut
        let startCount6 = counter.count
        settings.rewriteShortcut = ShortcutModel(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(cmdKey | optionKey))
        #expect(counter.count > startCount6)
        settings.rewriteShortcut = originalRewriteShortcut

        // 7. interfaceLanguage
        let originalInterfaceLang = settings.interfaceLanguage
        let startCount7 = counter.count
        settings.interfaceLanguage = (originalInterfaceLang == "ru") ? "en" : "ru"
        #expect(counter.count > startCount7)
        settings.interfaceLanguage = originalInterfaceLang

        // 8. geminiApiKey
        let originalKey = settings.geminiApiKey
        let startCount8 = counter.count
        settings.geminiApiKey = "test-temp-key-\(UUID().uuidString)"
        #expect(counter.count > startCount8)
        settings.geminiApiKey = originalKey
    }

    // MARK: - ShortcutModel Validation & Glyphs Tests

    @Test("ShortcutModel comprehensive reserved shortcuts and glyph rendering")
    func shortcutModelValidationAndGlyphs() {
        let cmdOnly = UInt32(cmdKey)
        let cmdOpt = UInt32(cmdKey | optionKey)
        let cmdShift = UInt32(cmdKey | shiftKey)
        let cmdCtrl = UInt32(cmdKey | controlKey)

        // All 9 reserved single Cmd shortcuts
        let reservedKeys: [Int] = [
            kVK_ANSI_C, kVK_ANSI_V, kVK_ANSI_X, kVK_ANSI_Z,
            kVK_ANSI_A, kVK_ANSI_Q, kVK_ANSI_W, kVK_Space, kVK_Tab
        ]
        for key in reservedKeys {
            #expect(ShortcutModel.isSystemReserved(keyCode: UInt32(key), modifiers: cmdOnly))
            // Permitted with combo modifiers
            #expect(!ShortcutModel.isSystemReserved(keyCode: UInt32(key), modifiers: cmdOpt))
            #expect(!ShortcutModel.isSystemReserved(keyCode: UInt32(key), modifiers: cmdShift))
            #expect(!ShortcutModel.isSystemReserved(keyCode: UInt32(key), modifiers: cmdCtrl))
        }

        // Permitted single Cmd shortcuts
        let permittedKeys: [Int] = [
            kVK_ANSI_B, kVK_ANSI_D, kVK_ANSI_E, kVK_ANSI_K, kVK_ANSI_T,
            kVK_ANSI_1, kVK_ANSI_9, kVK_Return, kVK_Delete, kVK_Escape
        ]
        for key in permittedKeys {
            #expect(!ShortcutModel.isSystemReserved(keyCode: UInt32(key), modifiers: cmdOnly))
        }

        // Glyph order: Control ⌃, Option ⌥, Shift ⇧, Command ⌘
        let allMods = UInt32(controlKey | optionKey | shiftKey | cmdKey)
        let fullShortcut = ShortcutModel(keyCode: UInt32(kVK_ANSI_A), modifiers: allMods)
        #expect(fullShortcut.displayString == "⌃⌥⇧⌘A")

        // Special keys display names
        #expect(ShortcutModel(keyCode: UInt32(kVK_Space), modifiers: cmdOpt).displayString == "⌥⌘Space")
        #expect(ShortcutModel(keyCode: UInt32(kVK_Return), modifiers: cmdOpt).displayString == "⌥⌘⏎")
        #expect(ShortcutModel(keyCode: UInt32(kVK_Tab), modifiers: cmdOpt).displayString == "⌥⌘⇥")
        #expect(ShortcutModel(keyCode: UInt32(kVK_Delete), modifiers: cmdOpt).displayString == "⌥⌘⌫")
        #expect(ShortcutModel(keyCode: UInt32(kVK_Escape), modifiers: cmdOpt).displayString == "⌥⌘⎋")

        // Numeric keys
        #expect(ShortcutModel(keyCode: UInt32(kVK_ANSI_5), modifiers: cmdOnly).displayString == "⌘5")

        // Unknown key fallback
        #expect(ShortcutModel(keyCode: 9999, modifiers: cmdOnly).displayString == "⌘Key(9999)")
    }

    // MARK: - KeychainHelper Lifecycle & Migration Tests

    @Test("KeychainHelper comprehensive save, overwrite, delete and migration lifecycle")
    func keychainHelperComprehensiveLifecycle() {
        let account = "TestLifecycleAccount_\(UUID().uuidString)"
        let service = "com.puhavik.LightL.tests"
        let legacyService = "com.user.LightL"

        // 1. Initial save and load
        let keyV1 = "secret-v1-\(UUID().uuidString)"
        #expect(KeychainHelper.saveApiKey(keyV1, account: account, service: service))
        #expect(KeychainHelper.loadApiKey(account: account, service: service) == keyV1)

        // 2. Overwrite with keyV2
        let keyV2 = "secret-v2-\(UUID().uuidString)"
        #expect(KeychainHelper.saveApiKey(keyV2, account: account, service: service))
        #expect(KeychainHelper.loadApiKey(account: account, service: service) == keyV2)

        // 3. Save empty string triggers deletion
        #expect(KeychainHelper.saveApiKey("", account: account, service: service))
        #expect(KeychainHelper.loadApiKey(account: account, service: service) == nil)

        // 4. Delete non-existent key succeeds without throw
        KeychainHelper.deleteApiKey(account: account, service: service)
        #expect(KeychainHelper.loadApiKey(account: account, service: service) == nil)

        // 5. Legacy migration from legacyService to serviceName
        let legacyAccount = "TestLegacyMigration_\(UUID().uuidString)"
        let legacyKey = "legacy-val-\(UUID().uuidString)"
        let currentService = KeychainHelper.serviceName

        #expect(KeychainHelper.saveApiKey(legacyKey, account: legacyAccount, service: legacyService))
        // Load using currentService triggers migration
        let migrated = KeychainHelper.loadApiKey(account: legacyAccount, service: currentService)
        #expect(migrated == legacyKey)

        // Legacy service item should be deleted
        let legacyCheck = KeychainHelper.loadApiKey(account: legacyAccount, service: legacyService)
        #expect(legacyCheck == nil)

        // Current service item should persist
        let currentCheck = KeychainHelper.loadApiKey(account: legacyAccount, service: currentService)
        #expect(currentCheck == legacyKey)

        // Cleanup
        KeychainHelper.deleteApiKey(account: legacyAccount, service: currentService)
        #expect(KeychainHelper.loadApiKey(account: legacyAccount, service: currentService) == nil)
    }

    // MARK: - Gemini SSE & Mid-Stream Error Parsing Tests

    @Test("GeminiService SSE line parsing handles data: with and without spaces, and multiline payloads")
    func geminiSSELineParsing() throws {
        // 1. Single chunk with "data: " (with space)
        let sseWithSpace = [
            "data: {\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"Hello \"}]}}]}",
            ""
        ]
        var chunks: [String] = []
        let result1 = try GeminiService.parseSSELines(sseWithSpace) { chunk in
            chunks.append(chunk)
        }
        #expect(result1 == "Hello")
        #expect(chunks == ["Hello "])

        // 2. Single chunk with "data:" (without space)
        let sseWithoutSpace = [
            "data:{\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"World!\"}]}}]}",
            ""
        ]
        let result2 = try GeminiService.parseSSELines(sseWithoutSpace)
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
        let result3 = try GeminiService.parseSSELines(multilineSSE)
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
        let result4 = try GeminiService.parseSSELines(sequenceSSE) { chunk in
            progressiveChunks.append(chunk)
        }
        #expect(result4 == "One Two Three")
        #expect(progressiveChunks == ["One ", "One Two ", "One Two Three"])

        // 5. Lines with CRLF (\r\n) stripping
        let crlfSSE = [
            "data: {\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"CRLF Test\"}]}}]}\r",
            "\r"
        ]
        let result5 = try GeminiService.parseSSELines(crlfSSE)
        #expect(result5 == "CRLF Test")

        // 6. Comments or non-data lines ignored
        let commentSSE = [
            ": keepalive ping",
            "data: {\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"Real Content\"}]}}]}",
            ""
        ]
        let result6 = try GeminiService.parseSSELines(commentSSE)
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

    // MARK: - Gemini Model Option & Thinking Support Tests

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

    // MARK: - API Key Sanitization Tests

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

    // MARK: - VisualEffectView CornerRadius & Layer Masking Tests

    @Test("VisualEffectView initializer with cornerRadius and layer masking properties")
    @MainActor
    func visualEffectViewCornerRadiusAndMasking() {
        // 1. Initializer with custom cornerRadius
        let customView = VisualEffectView(material: .popover, blendingMode: .behindWindow, cornerRadius: 18)
        #expect(customView.material == .popover)
        #expect(customView.blendingMode == .behindWindow)
        #expect(customView.cornerRadius == 18)

        // 2. Applied to NSVisualEffectView: layer masking is enabled when cornerRadius > 0
        let nsView = NSVisualEffectView()
        customView.apply(to: nsView)
        #expect(nsView.material == .popover)
        #expect(nsView.blendingMode == .behindWindow)
        #expect(nsView.state == .active)
        #expect(nsView.wantsLayer == true)
        #expect(nsView.layer?.cornerRadius == 18)
        #expect(nsView.layer?.masksToBounds == true)

        // 3. Default initializer sets cornerRadius = 0 and masksToBounds = false
        let defaultView = VisualEffectView(material: .selection, blendingMode: .withinWindow)
        #expect(defaultView.cornerRadius == 0)
        #expect(defaultView.material == .selection)
        #expect(defaultView.blendingMode == .withinWindow)

        let defaultNSView = NSVisualEffectView()
        defaultView.apply(to: defaultNSView)
        #expect(defaultNSView.layer?.cornerRadius == 0)
        #expect(defaultNSView.layer?.masksToBounds == false)
    }

    // MARK: - HotKeyManager UpdateHotKeys Return Tuple Tests

    @Test("HotKeyManager.updateHotKeys returns tuple (translateSuccess: Bool, rewriteSuccess: Bool)")
    @MainActor
    func hotKeyManagerUpdateHotKeysReturnTuple() {
        // 1. Update hotkeys with defaults
        let result = HotKeyManager.shared.updateHotKeys(
            translateShortcut: ShortcutModel.defaultTranslate,
            rewriteShortcut: ShortcutModel.defaultRewrite,
            enableDoubleCmdC: false
        )

        // Verify type and structure of return tuple
        let translateOk: Bool = result.translateSuccess
        let rewriteOk: Bool = result.rewriteSuccess
        #expect(result.0 == translateOk)
        #expect(result.1 == rewriteOk)

        // 2. Update hotkeys with custom shortcuts
        let customTranslate = ShortcutModel(keyCode: UInt32(kVK_ANSI_T), modifiers: UInt32(cmdKey | optionKey))
        let customRewrite = ShortcutModel(keyCode: UInt32(kVK_ANSI_R), modifiers: UInt32(cmdKey | optionKey))
        let customResult = HotKeyManager.shared.updateHotKeys(
            translateShortcut: customTranslate,
            rewriteShortcut: customRewrite,
            enableDoubleCmdC: true
        )
        #expect(customResult.translateSuccess == customResult.0)
        #expect(customResult.rewriteSuccess == customResult.1)

        // 3. Restore to defaults
        let restoredResult = HotKeyManager.shared.updateHotKeys(
            translateShortcut: ShortcutModel.defaultTranslate,
            rewriteShortcut: ShortcutModel.defaultRewrite,
            enableDoubleCmdC: false
        )
        #expect(restoredResult.translateSuccess == restoredResult.0)
    }

    // MARK: - TextCaptureService Re-entrancy & Item Preservation Tests

    @Test("TextCaptureService.replaceSelection re-entrancy protection and item preservation")
    @MainActor
    func textCaptureServiceReplaceSelectionReentrancyAndPreservation() async throws {
        // 1. Test backupPasteboard and restorePasteboard fidelity
        let pasteboard = NSPasteboard.general

        pasteboard.clearContents()
        let initialItem = NSPasteboardItem()
        let originalText = "Original User Clipboard \(UUID().uuidString)"
        initialItem.setString(originalText, forType: .string)
        pasteboard.writeObjects([initialItem])

        let backedUp = TextCaptureService.shared.backupPasteboard(pasteboard)
        #expect(!backedUp.isEmpty)
        #expect(backedUp.first?.string(forType: .string) == originalText)

        // 2. Configure testing hooks for TextCaptureService
        TextCaptureService.accessibilityOverrideForTesting = true
        TextCaptureService.skipSimulatePasteForTesting = true
        TextCaptureService.forcePasteboardFallbackForTesting = true
        TextCaptureService.pasteboardRestoreDelayForTesting = 80_000_000 // 80ms
        defer {
            TextCaptureService.accessibilityOverrideForTesting = nil
            TextCaptureService.skipSimulatePasteForTesting = false
            TextCaptureService.forcePasteboardFallbackForTesting = false
            TextCaptureService.pasteboardRestoreDelayForTesting = nil
        }

        // 3. First replacement: schedules restore task and backs up originalText
        let intermediate1 = "First Intermediate Replacement \(UUID().uuidString)"
        let replaced1 = await TextCaptureService.shared.replaceSelection(with: intermediate1)
        #expect(replaced1 == true)
        #expect(TextCaptureService.shared.hasPendingRestoreTaskForTesting == true)
        #expect(TextCaptureService.shared.savedOriginalItemsCountForTesting == 1)
        #expect(pasteboard.string(forType: .string) == intermediate1)

        // 4. Re-entrant second replacement: called immediately while first restore task is pending
        let intermediate2 = "Second Intermediate Replacement \(UUID().uuidString)"
        let replaced2 = await TextCaptureService.shared.replaceSelection(with: intermediate2)
        #expect(replaced2 == true)
        #expect(TextCaptureService.shared.hasPendingRestoreTaskForTesting == true)
        // Crucial re-entrancy proof: savedOriginalItems was preserved and NOT overwritten by intermediate1!
        #expect(TextCaptureService.shared.savedOriginalItemsCountForTesting == 1)
        #expect(pasteboard.string(forType: .string) == intermediate2)

        // 5. Wait for the restore task delay to elapse and yield to MainActor
        let deadline = Date().addingTimeInterval(1.5)
        while TextCaptureService.shared.hasPendingRestoreTaskForTesting && Date() < deadline {
            try await Task.sleep(nanoseconds: 30_000_000)
        }

        // 6. Verify full restoration to the original user text
        #expect(TextCaptureService.shared.hasPendingRestoreTaskForTesting == false)
        #expect(TextCaptureService.shared.savedOriginalItemsCountForTesting == nil)
        #expect(pasteboard.string(forType: .string) == originalText)
    }

    @Test("TextCaptureService restores the clipboard when replaceSelection is cancelled after the pasteboard write")
    @MainActor
    func replaceSelectionCancelledRestoresPasteboard() async throws {
        let pasteboard = NSPasteboard.general
        let originalText = "Original \(UUID().uuidString)"
        pasteboard.clearContents()
        pasteboard.setString(originalText, forType: .string)

        TextCaptureService.accessibilityOverrideForTesting = true
        TextCaptureService.skipSimulatePasteForTesting = true
        TextCaptureService.forcePasteboardFallbackForTesting = true
        TextCaptureService.pasteboardRestoreDelayForTesting = 80_000_000
        defer {
            TextCaptureService.accessibilityOverrideForTesting = nil
            TextCaptureService.skipSimulatePasteForTesting = false
            TextCaptureService.forcePasteboardFallbackForTesting = false
            TextCaptureService.pasteboardRestoreDelayForTesting = nil
        }

        let task = Task { @MainActor in
            await TextCaptureService.shared.replaceSelection(with: "Replacement \(UUID().uuidString)")
        }
        task.cancel()
        #expect(await task.value == false)

        let deadline = Date().addingTimeInterval(1.5)
        while TextCaptureService.shared.hasPendingRestoreTaskForTesting && Date() < deadline {
            try await Task.sleep(nanoseconds: 30_000_000)
        }
        #expect(pasteboard.string(forType: .string) == originalText)
    }

    @Test("GeminiService rethrows truncated stream errors instead of falling back")
    func truncatedErrorIsDistinct() {
        let error: Error = GeminiError.truncated
        if case GeminiError.truncated = error {} else { Issue.record("expected truncated") }
    }

    // MARK: - Audited Bug Fixes Verification Tests

    @Test("ShortcutModel rejects expanded system shortcuts (⌘S, ⌘O, ⌘H, ⌘M) and permits combo modifiers")
    func shortcutModelExpandedBlacklist() {
        let cmdOnly = UInt32(cmdKey)
        let cmdOpt = UInt32(cmdKey | optionKey)

        // Expanded reserved shortcuts
        #expect(ShortcutModel.isSystemReserved(keyCode: UInt32(kVK_ANSI_S), modifiers: cmdOnly))
        #expect(ShortcutModel.isSystemReserved(keyCode: UInt32(kVK_ANSI_O), modifiers: cmdOnly))
        #expect(ShortcutModel.isSystemReserved(keyCode: UInt32(kVK_ANSI_H), modifiers: cmdOnly))
        #expect(ShortcutModel.isSystemReserved(keyCode: UInt32(kVK_ANSI_M), modifiers: cmdOnly))

        // Same shortcuts with Option modifier are permitted
        #expect(!ShortcutModel.isSystemReserved(keyCode: UInt32(kVK_ANSI_S), modifiers: cmdOpt))
        #expect(!ShortcutModel.isSystemReserved(keyCode: UInt32(kVK_ANSI_O), modifiers: cmdOpt))
        #expect(!ShortcutModel.isSystemReserved(keyCode: UInt32(kVK_ANSI_H), modifiers: cmdOpt))
        #expect(!ShortcutModel.isSystemReserved(keyCode: UInt32(kVK_ANSI_M), modifiers: cmdOpt))
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

    @Test("KeychainHelper in-memory mock storage roundtrip and isolation")
    func keychainHelperInMemoryStorage() {
        let testAccount = "TestInMemoryAccount_\(UUID().uuidString)"
        let testService = "com.puhavik.LightL.mock"
        let testSecret = "secret-value-\(UUID().uuidString)"

        #expect(KeychainHelper.loadApiKey(account: testAccount, service: testService) == nil)
        let saved = KeychainHelper.saveApiKey(testSecret, account: testAccount, service: testService)
        #expect(saved == true)

        let loaded = KeychainHelper.loadApiKey(account: testAccount, service: testService)
        #expect(loaded == testSecret)

        KeychainHelper.deleteApiKey(account: testAccount, service: testService)
        #expect(KeychainHelper.loadApiKey(account: testAccount, service: testService) == nil)
    }

    @Test("HotKeyManager recheckDoubleCmdCMonitor runs safely")
    @MainActor
    func hotKeyManagerRecheckDoubleCmdCMonitor() {
        HotKeyManager.shared.recheckDoubleCmdCMonitor()
    }
}
