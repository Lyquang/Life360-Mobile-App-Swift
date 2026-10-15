import Foundation
import Security

enum KeychainStoreError: Error {
    case operationFailed(OSStatus)
    case invalidData
}

protocol KeychainStorage: AnyObject {
    func set(_ value: Data, for key: String) throws
    func data(for key: String) -> Data?
    func string(for key: String) -> String?
    @discardableResult func remove(_ key: String) -> OSStatus
}

/// Generic-password Keychain wrapper. Updates never delete the old value first.
final class KeychainStore: KeychainStorage {
    func set(_ value: Data, for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        let attributes: [String: Any] = [kSecValueData as String: value]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = value
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(add as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainStoreError.operationFailed(addStatus) }
        } else if status != errSecSuccess {
            throw KeychainStoreError.operationFailed(status)
        }
    }

    func data(for key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return data
    }

    func string(for key: String) -> String? { data(for: key).flatMap { String(data: $0, encoding: .utf8) } }

    @discardableResult func remove(_ key: String) -> OSStatus {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        return SecItemDelete(query as CFDictionary)
    }
}

/// Stores the JWT + cached user info. Also feeds the token to APIClient.
final class KeychainSessionRepository: SessionRepository, TokenPairStore {
    var onSessionSaved: (@Sendable () -> Void)?
    private enum Key {
        static let token = "com.familytracker.jwt_token"
        static let pair = "com.familytracker.auth_tokens"
        static let userId = "com.familytracker.user_id"
        static let userName = "com.familytracker.user_name"
        static let userEmail = "com.familytracker.user_email"
    }

    private let keychain: KeychainStorage
    private let lock = NSRecursiveLock()
    private var generation = 0

    init(keychain: KeychainStorage = KeychainStore()) {
        self.keychain = keychain
    }

    var tokens: AuthTokens? {
        lock.lock(); defer { lock.unlock() }
        guard let data = keychain.data(for: Key.pair) else { return nil }
        return try? JSONDecoder().decode(AuthTokens.self, from: data)
    }

    var accessToken: String? {
        lock.lock(); defer { lock.unlock() }
        return tokens?.accessToken ?? keychain.string(for: Key.token)
    }

    var sessionGeneration: Int {
        lock.lock(); defer { lock.unlock() }
        return generation
    }

    var locationSessionIdentity: LocationSessionIdentity? {
        lock.lock(); defer { lock.unlock() }
        guard accessToken != nil, let ownerID = keychain.string(for: Key.userId), !ownerID.isEmpty else { return nil }
        return LocationSessionIdentity(ownerID: ownerID, generation: generation)
    }

    var tokenSnapshot: (token: String?, generation: Int) {
        lock.lock(); defer { lock.unlock() }
        return (accessToken, generation)
    }

    func save(_ session: AuthSession) throws {
        lock.lock(); defer { lock.unlock() }
        try replaceTokens(session.tokens)
        try keychain.set(Data(session.user.id.utf8), for: Key.userId)
        try keychain.set(Data(session.user.name.utf8), for: Key.userName)
        try keychain.set(Data(session.user.email.utf8), for: Key.userEmail)
        generation += 1
        onSessionSaved?()
    }

    func replaceTokens(_ newTokens: AuthTokens) throws {
        lock.lock(); defer { lock.unlock() }
        let encoded = try JSONEncoder().encode(newTokens)
        try keychain.set(encoded, for: Key.pair)
        keychain.remove(Key.token)
    }

    func replaceTokens(_ newTokens: AuthTokens, ifGeneration expected: Int) throws {
        lock.lock(); defer { lock.unlock() }
        guard generation == expected else { throw RefreshFailure.cancelled }
        try replaceTokens(newTokens)
    }

    func clear() {
        lock.lock(); defer { lock.unlock() }
        generation += 1
        [Key.pair, Key.token, Key.userId, Key.userName, Key.userEmail].forEach { keychain.remove($0) }
    }

    @discardableResult
    func clear(ifGeneration expected: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard generation == expected else { return false }
        clear()
        return true
    }

    func invalidate(token: String) {
        lock.lock(); defer { lock.unlock() }
        if accessToken == token {
            clear()
        }
    }
}
