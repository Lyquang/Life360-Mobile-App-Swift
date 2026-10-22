import Foundation
import XCTest
@testable import FamilyTracker

final class LocationSharingContractTests: XCTestCase {
    func testEndpointsUseBearerAndEncodePauseModes() throws {
        XCTAssertEqual(LocationSharingEndpoint.fetch.path, "/privacy/location-sharing")
        XCTAssertEqual(LocationSharingEndpoint.fetch.method, .GET)
        XCTAssertTrue(LocationSharingEndpoint.fetch.requiresAuth)

        let indefinite = LocationSharingEndpoint.update(.pause(until: nil))
        XCTAssertEqual(indefinite.method, .PATCH)
        XCTAssertTrue(indefinite.requiresAuth)
        XCTAssertEqual(try body(indefinite)["enabled"] as? Bool, false)
        XCTAssertNil(try body(indefinite)["pausedUntil"])

        let until = try XCTUnwrap(ISO8601.date(from: "2026-10-19T12:00:00.123Z"))
        let timed = LocationSharingEndpoint.update(.pause(until: until))
        XCTAssertEqual(try body(timed)["enabled"] as? Bool, false)
        XCTAssertEqual(try body(timed)["pausedUntil"] as? String, "2026-10-19T12:00:00.123Z")

        let resume = LocationSharingEndpoint.update(.resume)
        XCTAssertEqual(try body(resume)["enabled"] as? Bool, true)
        XCTAssertNil(try body(resume)["pausedUntil"])
    }

    func testStateDecodesFractionalSecondDates() throws {
        let payload = Data("""
        {"success":true,"data":{"enabled":false,
         "pausedUntil":"2026-10-19T12:00:00.123Z",
         "updatedAt":"2026-10-19T10:00:00.456Z"}}
        """.utf8)
        let state = try BackendJSONCoding.makeDecoder()
            .decode(APIResponseDTO<LocationSharingStateDTO>.self, from: payload)
            .unwrap(fallbackMessage: "Missing state")
            .toDomain()
        XCTAssertFalse(state.enabled)
        XCTAssertEqual(state.pausedUntil?.timeIntervalSince1970,
                       ISO8601.date(from: "2026-10-19T12:00:00.123Z")?.timeIntervalSince1970)
        XCTAssertNotNil(state.updatedAt)
    }

    func testPaused403IsDistinctAndOther403KeepsOldBehavior() async {
        let paused = LocationSharingRepositoryImpl(api: PrivacyFailingAPIClient(
            error: .http(status: 403, code: "LOCATION_SHARING_PAUSED", message: nil, errors: [])))
        do {
            _ = try await paused.fetch()
            XCTFail("Expected paused")
        } catch LocationSharingFailure.paused {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let forbidden = LocationSharingRepositoryImpl(api: PrivacyFailingAPIClient(
            error: .http(status: 403, code: "FORBIDDEN", message: nil, errors: [])))
        do {
            _ = try await forbidden.fetch()
            XCTFail("Expected forbidden")
        } catch DomainError.forbidden {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertEqual(APIError.http(status: 403, code: "FORBIDDEN", message: nil, errors: []).domainError,
                       .forbidden)
    }

    private func body(_ endpoint: Endpoint) throws -> [String: Any] {
        let data = try XCTUnwrap(endpoint.encodedBody())
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

private final class PrivacyFailingAPIClient: APIClient {
    let error: APIError

    init(error: APIError) { self.error = error }

    func send<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T { throw error }

    func sendWithMetadata<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> APIResult<T> {
        throw error
    }
}
