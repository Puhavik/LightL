import Foundation
import Security

public enum KeychainHelper {
    public static let serviceName = "com.puhavik.LightL"
    private static let legacyServiceName = "com.user.LightL"
    public static let accountName = "GeminiApiKey"

    public static func saveApiKey(_ key: String, account: String = accountName, service: String = serviceName) {
        guard let data = key.data(using: .utf8) else { return }

        guard !key.isEmpty else {
            deleteApiKey(account: account, service: service)
            return
        }

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]

        let attributesToUpdate: [CFString: Any] = [
            kSecValueData: data
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var newQuery = query
            newQuery[kSecValueData] = data
            newQuery[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(newQuery as CFDictionary, nil)
            if addStatus != errSecSuccess {
                print("[KeychainHelper] SecItemAdd failed with status: \(addStatus)")
            }
        } else if updateStatus != errSecSuccess {
            print("[KeychainHelper] SecItemUpdate failed with status: \(updateStatus)")
        }
    }

    public static func loadApiKey(account: String = accountName, service: String = serviceName) -> String? {
        if let key = fetchKey(account: account, service: service) {
            return key
        }
        if service == serviceName, let legacyKey = fetchKey(account: account, service: legacyServiceName) {
            saveApiKey(legacyKey, account: account, service: serviceName)
            return legacyKey
        }
        return nil
    }

    private static func fetchKey(account: String, service: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data, let key = String(data: data, encoding: .utf8) else {
            return nil
        }
        return key
    }

    public static func deleteApiKey(account: String = accountName, service: String = serviceName) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
