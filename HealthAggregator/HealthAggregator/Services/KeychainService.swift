import Foundation
import Security

enum KeychainService {
    enum Key: String {
        case whoopAccessToken  = "whoop_access_token"
        case whoopRefreshToken = "whoop_refresh_token"
        case whoopTokenExpiry  = "whoop_token_expiry"
    }

    static func save(_ value: String, for key: Key) {
        let data = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key.rawValue,
            kSecAttrService: "com.healthaggregator.app",
            kSecValueData: data,
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(_ key: Key) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key.rawValue,
            kSecAttrService: "com.healthaggregator.app",
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: Key) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key.rawValue,
            kSecAttrService: "com.healthaggregator.app",
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func deleteAll() {
        Key.allCases.forEach { delete($0) }
    }
}

extension KeychainService.Key: CaseIterable {}
