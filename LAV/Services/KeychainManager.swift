import Foundation
import Security

final class KeychainManager {
    static let shared = KeychainManager()
    private init() {}

    func save(key: String, value: String) {
        delete(key: key)

        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Config.keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    func retrieve(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Config.keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Config.keychainService,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }

    // Convenience for session token
    var sessionToken: String? {
        get { retrieve(key: Config.sessionTokenKey) }
        set {
            if let value = newValue {
                save(key: Config.sessionTokenKey, value: value)
            } else {
                delete(key: Config.sessionTokenKey)
            }
        }
    }

    func clearAll() {
        delete(key: Config.sessionTokenKey)
    }
}
