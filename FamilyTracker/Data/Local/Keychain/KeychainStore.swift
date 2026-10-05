import Foundation
import Security

/// Minimal generic-password Keychain wrapper (device-only, unlocked access).
final class KeychainStore {
    func set(_ value: String, for key: String) {
        guard let data = value.data(using: .utf8) else { return }
        remove(key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    func string(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func remove(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

/// Stores the JWT + cached user info. Also feeds the token to APIClient.
final class KeychainSessionRepository: SessionRepository, AccessTokenProvider {
    private enum Key {
        static let token = "com.familytracker.jwt_token"
        static let userId = "com.familytracker.user_id"
        static let userName = "com.familytracker.user_name"
        static let userEmail = "com.familytracker.user_email"
    }

    private let keychain: KeychainStore

    init(keychain: KeychainStore = KeychainStore()) {
        self.keychain = keychain
    }

    var accessToken: String? { keychain.string(for: Key.token) }

    func save(_ session: AuthSession) {
        keychain.set(session.token, for: Key.token)
        keychain.set(session.user.id, for: Key.userId)
        keychain.set(session.user.name, for: Key.userName)
        keychain.set(session.user.email, for: Key.userEmail)
    }

    func clear() {
        [Key.token, Key.userId, Key.userName, Key.userEmail].forEach(keychain.remove)
    }

    func invalidate(token: String) {
        if keychain.string(for: Key.token) == token {
            keychain.remove(Key.token)
        }
    }
}
