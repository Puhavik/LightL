import Foundation
import Observation

@Observable
@MainActor
public final class AppSettings {
    public static let shared = AppSettings()
    public static let didChangeNotification = Notification.Name("LightLAppSettingsDidChangeNotification")

    private enum Keys {
        static let apiKey = "LightL_geminiApiKey"
        static let targetLanguage = "LightL_targetLanguage"
        static let selectedModel = "LightL_selectedModel"
        static let rewriteMode = "LightL_rewriteMode"
        static let doubleCmdCEnabled = "LightL_doubleCmdCEnabled"
        static let translateShortcut = "LightL_translateShortcut"
        static let rewriteShortcut = "LightL_rewriteShortcut"
        static let interfaceLanguage = "LightL_interfaceLanguage"
    }

    @ObservationIgnored
    private let defaults = UserDefaults.standard

    /// True when the last attempt to persist the API key to the Keychain failed (key then lives in memory only).
    public private(set) var keychainSaveFailed = false

    public var geminiApiKey: String {
        didSet {
            let saved = KeychainHelper.saveApiKey(geminiApiKey)
            keychainSaveFailed = !saved
            if saved {
                defaults.removeObject(forKey: Keys.apiKey)
            }
            notifyChange()
        }
    }

    public var targetLanguageCode: String {
        didSet {
            defaults.set(targetLanguageCode, forKey: Keys.targetLanguage)
            notifyChange()
        }
    }

    public var selectedModelId: String {
        didSet {
            defaults.set(selectedModelId, forKey: Keys.selectedModel)
            notifyChange()
        }
    }

    public var rewriteMode: RewriteMode {
        didSet {
            defaults.set(rewriteMode.rawValue, forKey: Keys.rewriteMode)
            notifyChange()
        }
    }

    public var doubleCmdCEnabled: Bool {
        didSet {
            defaults.set(doubleCmdCEnabled, forKey: Keys.doubleCmdCEnabled)
            notifyChange()
        }
    }

    public var translateShortcut: ShortcutModel {
        didSet {
            if let data = try? JSONEncoder().encode(translateShortcut) {
                defaults.set(data, forKey: Keys.translateShortcut)
            }
            notifyChange()
        }
    }

    public var rewriteShortcut: ShortcutModel {
        didSet {
            if let data = try? JSONEncoder().encode(rewriteShortcut) {
                defaults.set(data, forKey: Keys.rewriteShortcut)
            }
            notifyChange()
        }
    }

    public var interfaceLanguage: String {
        didSet {
            defaults.set(interfaceLanguage, forKey: Keys.interfaceLanguage)
            notifyChange()
        }
    }

    private func notifyChange() {
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }

    public func migrateLegacySettings() {
        if let legacyKey = defaults.string(forKey: Keys.apiKey), !legacyKey.isEmpty {
            if KeychainHelper.saveApiKey(legacyKey) {
                defaults.removeObject(forKey: Keys.apiKey)
            }
        }
    }

    private init() {
        let hasPriorDefaults = defaults.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "")?.keys.contains { $0.hasPrefix("LightL_") } ?? false
        var hasExistingInstall = hasPriorDefaults
        if let key = KeychainHelper.loadApiKey(), !key.isEmpty {
            hasExistingInstall = true
            self.geminiApiKey = key
        } else if let legacyKey = defaults.string(forKey: Keys.apiKey), !legacyKey.isEmpty {
            hasExistingInstall = true
            self.geminiApiKey = legacyKey
            if KeychainHelper.saveApiKey(legacyKey) {
                defaults.removeObject(forKey: Keys.apiKey)
            }
        } else {
            self.geminiApiKey = ""
        }

        self.targetLanguageCode = defaults.string(forKey: Keys.targetLanguage) ?? LanguageModel.defaultTarget.code
        let storedModel = defaults.string(forKey: Keys.selectedModel)
        if let model = storedModel, !model.isEmpty {
            self.selectedModelId = model
        } else {
            self.selectedModelId = GeminiModelOption.defaultModel.modelId
        }
        if let stored = defaults.object(forKey: Keys.doubleCmdCEnabled) as? Bool {
            self.doubleCmdCEnabled = stored
        } else {
            // Off for new installs; installs that already have an API key keep the previous on-by-default behavior.
            // Prior LightL defaults also count as an existing install, so an unreadable Keychain alone cannot pick "off" for an upgrader.
            self.doubleCmdCEnabled = hasExistingInstall
            defaults.set(hasExistingInstall, forKey: Keys.doubleCmdCEnabled)
        }

        if let modeString = defaults.string(forKey: Keys.rewriteMode) {
            self.rewriteMode = RewriteMode(rawValue: modeString) ?? .proofread
        } else if let modeData = defaults.data(forKey: Keys.rewriteMode),
                  let mode = try? JSONDecoder().decode(RewriteMode.self, from: modeData) {
            self.rewriteMode = mode
        } else {
            self.rewriteMode = .proofread
        }

        if let data = defaults.data(forKey: Keys.translateShortcut),
           let shortcut = try? JSONDecoder().decode(ShortcutModel.self, from: data) {
            self.translateShortcut = shortcut
        } else {
            self.translateShortcut = ShortcutModel.defaultTranslate
        }

        if let data = defaults.data(forKey: Keys.rewriteShortcut),
           let shortcut = try? JSONDecoder().decode(ShortcutModel.self, from: data) {
            self.rewriteShortcut = shortcut
        } else {
            self.rewriteShortcut = ShortcutModel.defaultRewrite
        }

        self.interfaceLanguage = defaults.string(forKey: Keys.interfaceLanguage) ?? "system"
    }

    public var targetLanguage: LanguageModel {
        LanguageModel.supportedLanguages.first(where: { $0.code == targetLanguageCode }) ?? LanguageModel.defaultTarget
    }
}
