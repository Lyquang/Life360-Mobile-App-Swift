import Foundation
import XCTest
@testable import FamilyTracker

final class LocationBatchRepositoryTests: XCTestCase {
    private let baseURL = URL(string: "https://example.test/api/v1")!

    func testRequestContractAndPartialResponse() async throws {
        let first = makePoint(0)
        let second = makePoint(1)
        let store = BatchTokenStore()
        var capturedBody: [String: Any]?
        BatchURLProtocol.handler = { request in
            capturedBody = try JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any]
            XCTAssertEqual(request.url?.path, "/api/v1/locations/batch")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer old-access")
            return (200, [:], Data("""
                {"success":true,"data":{"accepted":["\(first.pointId.uuidString)"],
                "duplicates":[],"rejected":[{"index":1,"pointId":"\(second.pointId.uuidString)",
                "code":"RECORDED_AT_TOO_OLD","reason":"too old"}]}}
                """.utf8))
        }
        defer { BatchURLProtocol.handler = nil }
        let repository = LocationBatchRepositoryImpl(api: makeClient(store: store))

        let result = try await repository.upload([first, second])
        XCTAssertEqual(result.accepted, [first.pointId])
        XCTAssertEqual(result.rejected.first?.pointId, second.pointId)
        let sent = try XCTUnwrap(capturedBody?["points"] as? [[String: Any]])
        XCTAssertEqual(sent.count, 2)
        XCTAssertEqual(sent[0]["pointId"] as? String, first.pointId.uuidString)
        XCTAssertEqual(sent[0]["recordedAt"] as? String, ISO8601.string(from: first.recordedAt))
        XCTAssertEqual(sent[0]["accuracy"] as? Double, 8)
        XCTAssertNil(sent[0]["unknownRejectionAttempts"])
        XCTAssertLessThan(try XCTUnwrap(LocationEndpoint.batch(
            LocationBatchRequestDTO(points: [LocationBatchPointDTO(first)])
        ).encodedBody()).count, LocationBatchRepositoryImpl.maxBodyBytes)
    }

    func testBatchCountLimitsRejectWithoutNetwork() async throws {
        let repository = LocationBatchRepositoryImpl(api: makeClient(store: BatchTokenStore()))
        do {
            _ = try await repository.upload([])
            XCTFail("Empty batch must fail")
        } catch LocationBatchError.invalidBatch {}
        do {
            _ = try await repository.upload((0...100).map(makePoint))
            XCTFail("101 points must fail")
        } catch LocationBatchError.invalidBatch {}
    }

    func testRateLimitExposesRetryAfterWithoutChangingOrdinarySend() async throws {
        BatchURLProtocol.handler = { _ in
            (429, ["Retry-After": "75"], Data(#"{"success":false,"code":"RATE_LIMITED"}"#.utf8))
        }
        defer { BatchURLProtocol.handler = nil }
        let client = makeClient(store: BatchTokenStore())
        do {
            _ = try await LocationBatchRepositoryImpl(api: client).upload([makePoint(0)])
            XCTFail("Rate limit must fail")
        } catch LocationBatchError.rateLimited(let value) {
            XCTAssertEqual(value, "75")
        }
        do {
            _ = try await client.send(GroupEndpoint.list, as: APIResponseDTO<[GroupDTO]>.self)
            XCTFail("Ordinary send must fail")
        } catch APIError.http(let status, _, _, _) {
            XCTAssertEqual(status, 429)
        }
    }

    func test401RefreshesOnceAndRetriesBatchWithNewToken() async throws {
        let store = BatchTokenStore()
        let transport = BatchRefreshTransport()
        let coordinator = TokenRefreshCoordinator(store: store, transport: transport)
        var observedTokens: [String?] = []
        BatchURLProtocol.handler = { request in
            let token = request.value(forHTTPHeaderField: "Authorization")
            observedTokens.append(token)
            if token == "Bearer old-access" {
                return (401, [:], Data(#"{"success":false,"code":"UNAUTHORIZED"}"#.utf8))
            }
            return (200, [:], Data(#"{"success":true,"data":{"accepted":[],"duplicates":[],"rejected":[]}}"#.utf8))
        }
        defer { BatchURLProtocol.handler = nil }
        let repository = LocationBatchRepositoryImpl(api: makeClient(store: store, refresh: coordinator))

        _ = try await repository.upload([makePoint(0)])
        XCTAssertEqual(observedTokens, ["Bearer old-access", "Bearer new-access"])
        XCTAssertEqual(transport.rotations, 1)
    }

    private func makePoint(_ index: Int) -> BufferedLocationPoint {
        let fix = LocationFix(latitude: 10 + Double(index) / 10000, longitude: 106,
                              timestamp: Date(timeIntervalSince1970: 1_000_000 + Double(index)),
                              horizontalAccuracy: 8, speed: 1, course: 0)
        return BufferedLocationPoint(fix: fix, batteryLevel: 80)
    }

    private func makeClient(store: BatchTokenStore, refresh: TokenRefreshCoordinator? = nil) -> URLSessionAPIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [BatchURLProtocol.self]
        return URLSessionAPIClient(baseURL: baseURL, session: URLSession(configuration: configuration),
                                   tokenProvider: store, logger: NoopNetworkLogger(), refreshCoordinator: refresh)
    }
}

private final class BatchURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, [String: String], Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let (status, headers, body) = try Self.handler!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil,
                                           headerFields: headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private final class BatchTokenStore: TokenPairStore {
    private(set) var tokens: AuthTokens? = AuthTokens(accessToken: "old-access", refreshToken: "old-refresh", expiresIn: 900)
    var accessToken: String? { tokens?.accessToken }
    var sessionGeneration = 0

    func replaceTokens(_ tokens: AuthTokens) throws { self.tokens = tokens }
    func replaceTokens(_ tokens: AuthTokens, ifGeneration expected: Int) throws {
        guard sessionGeneration == expected else { throw RefreshFailure.cancelled }
        self.tokens = tokens
    }
    func invalidate(token: String) { if accessToken == token { tokens = nil } }
    func clear() { tokens = nil; sessionGeneration += 1 }
}

private final class BatchRefreshTransport: RefreshTokenTransport {
    private(set) var rotations = 0
    func rotate(refreshToken: String) async throws -> AuthTokens {
        rotations += 1
        return AuthTokens(accessToken: "new-access", refreshToken: "new-refresh", expiresIn: 900)
    }
}
