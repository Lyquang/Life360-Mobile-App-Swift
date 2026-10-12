import XCTest
import Security
@testable import FamilyTracker

final class RefreshTokenRotationTests: XCTestCase {
    func testLegacyTokenMigrationAndAtomicPairReplacement() throws {
        let keychain = InMemoryKeychain()
        keychain.items["com.familytracker.jwt_token"] = Data("legacy-access".utf8)
        let session = KeychainSessionRepository(keychain: keychain)

        XCTAssertEqual(session.accessToken, "legacy-access")
        XCTAssertNil(session.tokens)

        let tokens = AuthTokens(accessToken: "access-2", refreshToken: "opaque-2", expiresIn: 900)
        try session.replaceTokens(tokens)

        XCTAssertEqual(session.accessToken, "access-2")
        XCTAssertEqual(session.tokens?.refreshToken, "opaque-2")
        XCTAssertEqual(keychain.writes, ["com.familytracker.auth_tokens"])
        XCTAssertNil(keychain.items["com.familytracker.jwt_token"])
    }

    func testFailedPairWriteDoesNotCreateMixedGeneration() throws {
        let keychain = InMemoryKeychain()
        let session = KeychainSessionRepository(keychain: keychain)
        try session.replaceTokens(AuthTokens(accessToken: "old", refreshToken: "old-refresh", expiresIn: 900))
        keychain.failWrites = true

        XCTAssertThrowsError(try session.replaceTokens(
            AuthTokens(accessToken: "new", refreshToken: "new-refresh", expiresIn: 900)
        ))
        XCTAssertEqual(session.tokens?.accessToken, "old")
        XCTAssertEqual(session.tokens?.refreshToken, "old-refresh")
    }

    func testAuthPayloadPrefersAccessTokenAndRequiresRefreshPair() throws {
        let json = Data(#"{"success":true,"data":{"user":{"id":"u1","name":"Alice","email":"alice@example.test"},"token":"deprecated-alias","accessToken":"access","refreshToken":"opaque","expiresIn":900}}"#.utf8)
        let response = try BackendJSONCoding.makeDecoder().decode(APIResponseDTO<AuthDataDTO>.self, from: json)
        let session = try response.unwrap(fallbackMessage: "Missing auth response").toDomain()
        XCTAssertEqual(session.tokens.accessToken, "access")
        XCTAssertEqual(session.tokens.refreshToken, "opaque")
        XCTAssertGreaterThan(session.tokens.accessTokenExpiresAt, Date())
    }
}

private final class InMemoryKeychain: KeychainStorage {
    var items: [String: Data] = [:]
    var writes: [String] = []
    var failWrites = false

    func set(_ value: Data, for key: String) throws {
        if failWrites { throw KeychainStoreError.operationFailed(errSecNotAvailable) }
        items[key] = value
        writes.append(key)
    }

    func data(for key: String) -> Data? { items[key] }
    func string(for key: String) -> String? { items[key].flatMap { String(data: $0, encoding: .utf8) } }
    @discardableResult func remove(_ key: String) -> OSStatus {
        items[key] = nil
        return errSecSuccess
    }
}
