import Foundation
import Security

public enum KeychainHelper {
    public static let serviceName = "com.puhavik.LightL"
    private static let legacyServiceName = "com.user.LightL"
    public static let accountName = "GeminiApiKey"
    private static let useDataProtectionOrder = [true, false]

    private static let storageLock = NSLock()
    nonisolated(unsafe) public static var inMemoryStorage: [String: String]? = nil

    nonisolated(unsafe) public static var isRunningTests: Bool = {
        let name = ProcessInfo.processInfo.processName
        return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
            name.contains("testing-helper") ||
            name.hasSuffix("PackageTests") ||
            name == "xctest"
    }()

    public static func resetForTesting() {
        storageLock.withLock {
            inMemoryStorage = [:]
        }
    }

    private static func ensureStorage() {
        if isRunningTests {
            storageLock.withLock {
                if inMemoryStorage == nil {
                    inMemoryStorage = [:]
                }
            }
        }
    }

    @discardableResult
    public static func saveApiKey(_ key: String, account: String = accountName, service: String = serviceName) -> Bool {
        ensureStorage()
        let handledInMemory: Bool = storageLock.withLock {
            guard inMemoryStorage != nil else { return false }
            let storageKey = "\(service):\(account)"
            if key.isEmpty {
                inMemoryStorage?.removeValue(forKey: storageKey)
                if service == serviceName {
                    inMemoryStorage?.removeValue(forKey: account)
                }
            } else {
                inMemoryStorage?[storageKey] = key
                if service == serviceName {
                    inMemoryStorage?[account] = key
                }
            }
            return true
        }
        if handledInMemory { return true }

        guard let data = key.data(using: .utf8) else { return false }

        guard !key.isEmpty else {
            deleteApiKey(account: account, service: service)
            return true
        }

        for useDataProtection in Self.useDataProtectionOrder {
            var query: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account,
                kSecUseAuthenticationUI as CFString: kSecUseAuthenticationUIFail as CFString
            ]
            if useDataProtection {
                query[kSecUseDataProtectionKeychain as CFString] = kCFBooleanTrue as Any
            }

            let attributesToUpdate: [CFString: Any] = [
                kSecValueData: data,
                kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
            ]

            let updateStatus = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
            if updateStatus == errSecSuccess {
                return true
            } else if updateStatus == errSecMissingEntitlement {
                continue
            } else if updateStatus == errSecItemNotFound {
                var newQuery = query
                newQuery[kSecValueData] = data
                newQuery[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
                let addStatus = SecItemAdd(newQuery as CFDictionary, nil)
                if addStatus == errSecSuccess {
                    return true
                } else if addStatus == errSecMissingEntitlement {
                    continue
                } else {
                    print("[KeychainHelper] SecItemAdd failed with status: \(addStatus)")
                    continue
                }
            } else {
                print("[KeychainHelper] SecItemUpdate failed with status: \(updateStatus)")
                continue
            }
        }
        return false
    }

    public static func loadApiKey(account: String = accountName, service: String = serviceName) -> String? {
        if let key = fetchKey(account: account, service: service) {
            return key
        }
        if service == serviceName, let legacyKey = fetchKey(account: account, service: legacyServiceName) {
            // Remove the legacy item only after the new one is safely stored.
            if saveApiKey(legacyKey, account: account, service: serviceName) {
                deleteApiKey(account: account, service: legacyServiceName)
            }
            return legacyKey
        }
        return nil
    }

    private static func fetchKey(account: String, service: String) -> String? {
        ensureStorage()
        let memVal: String? = storageLock.withLock {
            guard let mem = inMemoryStorage else { return nil }
            return mem["\(service):\(account)"] ?? (service == serviceName ? mem[account] : nil)
        }
        if memVal != nil || isRunningTests {
            return memVal
        }

        for useDataProtection in Self.useDataProtectionOrder {
            var query: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account,
                kSecReturnData: true,
                kSecMatchLimit: kSecMatchLimitOne,
                kSecUseAuthenticationUI as CFString: kSecUseAuthenticationUIFail as CFString
            ]
            if useDataProtection {
                query[kSecUseDataProtectionKeychain as CFString] = kCFBooleanTrue as Any
            }

            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            if status == errSecSuccess, let data = item as? Data, let key = String(data: data, encoding: .utf8) {
                return key
            } else if status == errSecMissingEntitlement {
                continue
            }
        }
        return nil
    }

    public static func deleteApiKey(account: String = accountName, service: String = serviceName) {
        ensureStorage()
        let handledInMemory: Bool = storageLock.withLock {
            guard inMemoryStorage != nil else { return false }
            inMemoryStorage?.removeValue(forKey: "\(service):\(account)")
            if service == serviceName {
                inMemoryStorage?.removeValue(forKey: account)
            }
            return true
        }
        if handledInMemory { return }

        for useDataProtection in Self.useDataProtectionOrder {
            var query: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account,
                kSecUseAuthenticationUI as CFString: kSecUseAuthenticationUIFail as CFString
            ]
            if useDataProtection {
                query[kSecUseDataProtectionKeychain as CFString] = kCFBooleanTrue as Any
            }
            let status = SecItemDelete(query as CFDictionary)
            if status == errSecMissingEntitlement {
                continue
            }
        }
    }
}
