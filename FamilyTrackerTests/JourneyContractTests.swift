import XCTest
@testable import FamilyTracker

final class JourneyContractTests: XCTestCase {
    func testDocumentedPointsAndTimesAreKept() throws {
        let response = try decode("""
        {
          "success": true, "date": "2026-10-01",
          "summary": {"totalPoints": 3, "stayPointCount": 1, "movingSegmentCount": 1},
          "journey": [
            {"type": "stay", "startTime": "2026-10-01T08:00:00.000Z",
             "endTime": "2026-10-01T08:30:00.000Z", "durationMinutes": 30,
             "latitude": 10.7769, "longitude": 106.7009, "points": []},
            {"type": "moving", "startTime": "2026-10-01T08:30:00.000Z",
             "endTime": "2026-10-01T09:00:00.000Z",
             "points": [
               {"latitude": 10.7769, "longitude": 106.7009,
                "timestamp": "2026-10-01T08:31:00.000Z"},
               {"latitude": 10.7800, "longitude": 106.7050,
                "timestamp": "2026-10-01T08:32:00.000Z"}
             ]}
          ]
        }
        """)

        let journey = response.toDomain()
        let entries = journey.entries
        XCTAssertEqual(entries.count, 2)
        guard case .stay(let stay) = entries[0],
              case .moving(let moving) = entries[1] else {
            return XCTFail("Expected stay followed by moving segment")
        }
        XCTAssertEqual(stay.durationMinutes, 30)
        XCTAssertEqual(stay.arrivedAt, "2026-10-01T08:00:00.000Z")
        XCTAssertEqual(moving.path.count, 2)
        XCTAssertEqual(moving.fromLatitude, 10.7769)
        XCTAssertEqual(moving.toLongitude, 106.7050)
        XCTAssertEqual(moving.durationMinutes, 30)
        XCTAssertEqual(journey.summary?.totalStayMinutes, 30)
        XCTAssertEqual(journey.summary?.totalMovingMinutes, 30)
        XCTAssertEqual(journey.summary?.firstSeenAt, "2026-10-01T08:00:00.000Z")
    }

    func testLegacyPathAndExplicitEndpointsStillDecode() throws {
        let response = try decode("""
        {"success": true, "journey": [
          {"type": "moving", "fromLatitude": 10.1, "fromLongitude": 106.1,
           "toLatitude": 10.2, "toLongitude": 106.2,
           "startTime": "2026-10-01T10:00:00Z", "endTime": "2026-10-01T10:10:00Z",
           "path": [{"latitude": 10.1, "longitude": 106.1},
                    {"latitude": 10.2, "longitude": 106.2}]}
        ]}
        """)
        guard case .moving(let moving) = try XCTUnwrap(response.toDomain().entries.first) else {
            return XCTFail("Expected moving segment")
        }
        XCTAssertEqual(moving.path.count, 2)
        XCTAssertEqual(moving.durationMinutes, 10)
    }

    func testEndpointsWithoutPathDoNotCreateFakeLine() throws {
        let response = try decode("""
        {"success": true, "journey": [
          {"type": "moving", "fromLatitude": 10.1, "fromLongitude": 106.1,
           "toLatitude": 10.2, "toLongitude": 106.2,
           "startTime": "2026-10-01T10:00:00Z", "endTime": "2026-10-01T10:10:00Z"}
        ]}
        """)
        let journey = response.toDomain()
        XCTAssertEqual(journey.entries.count, 1)
        XCTAssertFalse(RouteOverlayModel.build(from: journey, toleranceMeters: 5).hasPath)
    }

    private func decode(_ json: String) throws -> DayJourneyResponseDTO {
        try JSONDecoder().decode(DayJourneyResponseDTO.self, from: Data(json.utf8))
    }
}
