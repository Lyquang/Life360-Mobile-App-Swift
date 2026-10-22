import XCTest
@testable import FamilyTracker

final class JourneyGeometryDTOTests: XCTestCase {
    func testGeometryEndpointRequestsOptInWithoutPrematurePathOptOut() {
        let endpoint = HistoryEndpoint.journey(userId: "synthetic-user", date: "2026-01-02")
        XCTAssertEqual(endpoint.path, "/history/synthetic-user/journey")
        XCTAssertEqual(endpoint.method.rawValue, "GET")
        XCTAssertEqual(endpoint.query.first(where: { $0.name == "detail" })?.value, "geometry")
        XCTAssertEqual(endpoint.query.first(where: { $0.name == "date" })?.value, "2026-01-02")
        XCTAssertFalse(endpoint.query.contains { $0.name == "includePath" })

        let today = HistoryEndpoint.journey(userId: "synthetic-user", date: nil)
        XCTAssertEqual(today.query.map(\.name), ["detail"])
    }

    func testB6aGeometryMetadataAndTimedPointsDecode() throws {
        let response = try decode("""
        {
          "success": true, "date": "2026-01-02", "timeZone": "Asia/Ho_Chi_Minh",
          "geometryPolicy": {
            "version": 2, "gapThresholdSeconds": 180, "gapIndexSpace": "points",
            "toBoundary": "inclusive", "stayRadiusMeters": 80, "minStayMinutes": 5
          },
          "summary": {"totalPoints": 3, "observedMovingSeconds": 60,
                      "firstSeenAt": "2026-01-02T00:00:00.123Z",
                      "lastSeenAt": "2026-01-02T00:05:00.456Z"},
          "journey": [{
            "type": "moving", "segmentId": "synthetic-segment",
            "startTime": "2026-01-02T00:00:00.123Z",
            "endTime": "2026-01-02T00:05:00.456Z",
            "pointCount": 3, "originalPointCount": 8, "distanceMeters": 144.0,
            "maxGapSeconds": 240, "thinned": true, "observedMovingSeconds": 60,
            "points": [
              {"latitude": 0.0, "longitude": 0.0,
               "recordedAt": "2026-01-02T00:00:00.123Z", "accuracy": 5},
              {"latitude": 0.001, "longitude": 0.001,
               "recordedAt": "2026-01-02T00:01:00.123Z"},
              {"latitude": 0.002, "longitude": 0.002,
               "recordedAt": "2026-01-02T00:05:00.456Z", "accuracy": 8}
            ],
            "gaps": [{"fromIndex": 1, "toIndex": 2, "seconds": 240, "meters": 100}]
          }]
        }
        """)

        XCTAssertEqual(response.timeZone, "Asia/Ho_Chi_Minh")
        XCTAssertEqual(response.geometryPolicy?.version, 2)
        XCTAssertEqual(response.geometryPolicy?.gapIndexSpace, "points")
        XCTAssertEqual(response.geometryPolicy?.toBoundary, "inclusive")
        XCTAssertEqual(response.summary?.observedMovingSeconds, 60)
        let moving = try XCTUnwrap(response.journey?.first)
        XCTAssertNil(moving.path)
        XCTAssertEqual(moving.pointCount, 3)
        XCTAssertEqual(moving.originalPointCount, 8)
        XCTAssertEqual(moving.distanceMeters, 144)
        XCTAssertEqual(moving.gaps?.first?.toIndex, 2)
        XCTAssertEqual(moving.points?.first?.recordedAt, "2026-01-02T00:00:00.123Z")
        XCTAssertEqual(moving.points?.last?.accuracy, 8)
        XCTAssertNotNil(ISO8601.date(from: moving.points?.first?.recordedAt))
        XCTAssertNotNil(ISO8601.date(from: response.summary?.lastSeenAt))
    }

    func testOptionalB6bFieldsAndUnknownPolicyVersionRemainDecodable() throws {
        let response = try decode("""
        {"success": true, "geometryPolicy": {"version": 99},
         "summary": {"observedStaySeconds": 60, "unobservedSeconds": 120},
         "journey": [{"type": "stay", "segmentId": "synthetic-stay",
           "latitude": 0.0, "longitude": 0.0,
           "arrivedAt": "2026-01-02T00:00:00.000Z",
           "leftAt": "2026-01-02T00:03:00.000Z",
           "confidence": "inferred", "containsDataGap": true, "maxGapSeconds": 120}]}
        """)
        XCTAssertEqual(response.geometryPolicy?.version, 99)
        XCTAssertNil(response.geometryPolicy?.gapThresholdSeconds)
        XCTAssertEqual(response.summary?.observedStaySeconds, 60)
        XCTAssertEqual(response.summary?.unobservedSeconds, 120)
        XCTAssertEqual(response.journey?.first?.confidence, "inferred")
        XCTAssertEqual(response.journey?.first?.containsDataGap, true)

        let legacy = try decode("""
        {"success": true, "journey": [{"type": "moving",
         "startTime": "2026-01-02T00:00:00Z", "endTime": "2026-01-02T00:01:00Z",
         "path": [{"latitude": 0.0, "longitude": 0.0}]}]}
        """)
        XCTAssertNil(legacy.geometryPolicy)
        XCTAssertNil(legacy.journey?.first?.points)
        XCTAssertEqual(legacy.journey?.first?.path?.count, 1)
    }

    private func decode(_ json: String) throws -> DayJourneyResponseDTO {
        try JSONDecoder().decode(DayJourneyResponseDTO.self, from: Data(json.utf8))
    }
}
