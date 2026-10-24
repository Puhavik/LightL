import Testing
import SwiftUI
import Foundation
import Carbon
import AppKit
@testable import LightL

extension LightLTests {
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
        #expect(!proofread.wordingBehavior.isEmpty)
        #expect(!proofread.temperatureDescription.isEmpty)
        #expect(!proofread.exampleOriginal.isEmpty)
        #expect(!proofread.exampleResult.isEmpty)

        let improve = RewriteMode.improveStyle
        #expect(!improve.title.isEmpty)
        #expect(!improve.title.contains("DeepL"))
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
        settings.selectedModelId = (originalModel == "gemini-3.5-flash-lite") ? "gemini-3.6-flash" : "gemini-3.5-flash-lite"
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
}
