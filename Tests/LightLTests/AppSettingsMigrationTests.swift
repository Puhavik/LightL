import Testing
import Foundation
@testable import LightL

@Suite("AppSettings migration", .serialized)
@MainActor
struct AppSettingsMigrationTests {
    private func makeDefaults() -> (UserDefaults, String) {
        let name = "LightLTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return (defaults, name)
    }

    private func makeSettings(_ defaults: UserDefaults, _ name: String) -> AppSettings {
        AppSettings(defaults: defaults, domain: name)
    }

    @Test("a fresh install has double-tap off and stores that choice")
    func freshInstall() {
        KeychainHelper.resetForTesting()
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = makeSettings(defaults, name)
        #expect(settings.doubleCmdCEnabled == false)
        #expect(defaults.object(forKey: "LightL_doubleCmdCEnabled") as? Bool == false)
    }

    @Test("an upgrade with a saved API key keeps double-tap on")
    func upgradeWithKey() {
        KeychainHelper.resetForTesting()
        _ = KeychainHelper.saveApiKey("AIzaSy-test-key")
        defer { KeychainHelper.resetForTesting() }
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = makeSettings(defaults, name)
        #expect(settings.geminiApiKey == "AIzaSy-test-key")
        #expect(settings.doubleCmdCEnabled == true)
        #expect(defaults.object(forKey: "LightL_doubleCmdCEnabled") as? Bool == true)
    }

    @Test("an upgrade with other LightL defaults but an unreadable key keeps double-tap on")
    func upgradeWithPriorDefaultsOnly() {
        KeychainHelper.resetForTesting()
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("de", forKey: "LightL_targetLanguage")
        defaults.synchronize()
        let settings = makeSettings(defaults, name)
        #expect(settings.targetLanguageCode == "de")
        #expect(settings.doubleCmdCEnabled == true)
    }

    @Test("an explicit stored choice always wins")
    func explicitChoiceWins() {
        KeychainHelper.resetForTesting()
        _ = KeychainHelper.saveApiKey("AIzaSy-test-key")
        defer { KeychainHelper.resetForTesting() }
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(false, forKey: "LightL_doubleCmdCEnabled")
        let settings = makeSettings(defaults, name)
        #expect(settings.doubleCmdCEnabled == false)
    }

    @Test("a legacy key in defaults is moved to the Keychain and removed from defaults")
    func legacyKeyMigration() {
        KeychainHelper.resetForTesting()
        defer { KeychainHelper.resetForTesting() }
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("legacy-key", forKey: "LightL_geminiApiKey")
        let settings = makeSettings(defaults, name)
        #expect(settings.geminiApiKey == "legacy-key")
        #expect(defaults.string(forKey: "LightL_geminiApiKey") == nil)
        #expect(KeychainHelper.loadApiKey() == "legacy-key")
        #expect(settings.doubleCmdCEnabled == true)
    }

    @Test("a second launch does not change the stored double-tap value")
    func secondLaunchIsStable() {
        KeychainHelper.resetForTesting()
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        _ = makeSettings(defaults, name)
        _ = KeychainHelper.saveApiKey("AIzaSy-late-key")
        defer { KeychainHelper.resetForTesting() }
        let second = makeSettings(defaults, name)
        #expect(second.doubleCmdCEnabled == false)
    }
}
