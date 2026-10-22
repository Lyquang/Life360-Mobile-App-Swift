import Foundation
import XCTest
@testable import FamilyTracker

final class LiveTrailContractTests: XCTestCase {
    func testSnapshotEndpointAndCatchUpKeepCursorPairedWithRevision() {
        let first = LiveTrailEndpoint.snapshot(userId: "user-1", date: "2026-10-18")
        XCTAssertEqual(first.path, "/history/user-1/journey/trail")
        XCTAssertTrue(first.requiresAuth)
        XCTAssertEqual(first.method, .GET)
        XCTAssertEqual(Dictionary(uniqueKeysWithValues: first.query.map { ($0.name, $0.value ?? "") }),
                       ["date": "2026-10-18", "limit": "200"])

        let next = LiveTrailEndpoint.catchUp(userId: "user-1", date: "2026-10-18",
                                             afterSeq: 205, revision: 4, limit: 500)
        XCTAssertEqual(Dictionary(uniqueKeysWithValues: next.query.map { ($0.name, $0.value ?? "") }),
                       ["date": "2026-10-18", "limit": "500", "afterSeq": "205", "revision": "4"])
    }

    func testDocumentedSnapshotKeepsMillisAndUnknownMatchStatus() throws {
        let response = try BackendJSONCoding.makeDecoder().decode(LiveTrailResponseDTO.self, from: Data("""
        {
          "success": true, "trailId": "trail-1", "userId": "user-1",
          "date": "2026-10-18", "timeZone": "Asia/Ho_Chi_Minh",
          "revision": 4, "lastSeq": 205,
          "points": [{"seq": 205, "latitude": 10.0, "longitude": 106.0,
                      "recordedAt": "2026-10-18T05:03:20.123Z", "accuracy": 8,
                      "motionState": "walking", "pointId": "ca05768a-9774-4e29-832e-70048a95901e"}],
          "gaps": [{"fromSeq": 205, "toSeq": 201, "seconds": 240, "meters": 530.4}],
          "matched": [{"segmentId": "segment-1", "fromSeq": 201, "toSeq": 205,
                       "status": "future_status", "geometry": null,
                       "matcher": {"provider": "noop", "version": "v1"},
                       "confidence": null, "sourceRevision": "revision-1",
                       "generatedAt": "2026-10-18T05:04:00.456Z"}],
          "hasMore": true, "nextAfterSeq": 205
        }
        """.utf8))
        let trail = response.toDomain()
        XCTAssertEqual(trail.points[0].recordedAt.timeIntervalSince1970,
                       1_792_299_800.123, accuracy: 0.001)
        XCTAssertEqual(trail.points[0].pointId?.uuidString.lowercased(),
                       "ca05768a-9774-4e29-832e-70048a95901e")
        XCTAssertEqual(trail.gaps[0].fromSeq, 205)
        XCTAssertEqual(trail.gaps[0].toSeq, 201)
        XCTAssertEqual(trail.matches[0].status, .unknown("future_status"))
        XCTAssertNil(trail.matches[0].geometry)
        XCTAssertEqual(trail.nextAfterSeq, 205)
    }

    func testRepositoryMapsFeatureAndRevisionErrors() async {
        let cases: [(APIError, String)] = [
            (.http(status: 404, code: "NOT_FOUND", message: nil, errors: []), "notFound"),
            (.http(status: 409, code: "TRAIL_REVISION_CHANGED", message: nil, errors: []), "revisionChanged"),
            (.http(status: 503, code: "SERVICE_UNAVAILABLE", message: nil, errors: []), "unavailable")
        ]
        for (apiError, expected) in cases {
            let repository = LiveTrailRepositoryImpl(api: FailingLiveTrailAPIClient(error: apiError))
            do {
                _ = try await repository.snapshot(userId: "user-1", date: "2026-10-18")
                XCTFail("Expected \(expected)")
            } catch LiveTrailLoadError.notFound {
                XCTAssertEqual(expected, "notFound")
            } catch LiveTrailLoadError.revisionChanged {
                XCTAssertEqual(expected, "revisionChanged")
            } catch LiveTrailLoadError.unavailable {
                XCTAssertEqual(expected, "unavailable")
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testRateLimitPreservesRetryAfter() async {
        let repository = LiveTrailRepositoryImpl(api: FailingLiveTrailAPIClient(
            error: .rateLimited(retryAfter: "120")))
        do {
            _ = try await repository.snapshot(userId: "user-1", date: "2026-10-18")
            XCTFail("Expected rate limit")
        } catch LiveTrailLoadError.rateLimited(let retryAfter) {
            XCTAssertEqual(retryAfter, "120")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private final class FailingLiveTrailAPIClient: APIClient {
    let error: APIError

    init(error: APIError) { self.error = error }

    func send<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T {
        throw error
    }

    func sendWithMetadata<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> APIResult<T> {
        throw error
    }
}
