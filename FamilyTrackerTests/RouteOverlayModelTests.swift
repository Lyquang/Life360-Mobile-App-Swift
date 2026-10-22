import XCTest
@testable import FamilyTracker

final class RouteOverlayModelTests: XCTestCase {
    func testBuildKeepsSegmentsSeparateAndPreservesJourneyOrder() {
        let first = moving(start: "08:00", path: [point(10, 106), point(10.01, 106.01)])
        let middle = stay(start: "08:20", point: point(10.01, 106.01))
        let last = moving(start: "09:00", path: [point(10.01, 106.01), point(10.02, 106.02)])
        let journey = DayJourney(date: nil, summary: nil, entries: [.moving(first), .stay(middle), .moving(last)])

        let model = RouteOverlayModel.build(from: journey, toleranceMeters: 5,
                                            selectedEntryID: "moving_09:00")

        XCTAssertEqual(model.segments.map(\.id), ["moving_08:00", "moving_09:00"])
        XCTAssertEqual(model.segments.map(\.points.count), [2, 2])
        XCTAssertEqual(model.stays.map(\.id), ["stay_08:20"])
        XCTAssertEqual(model.stays.first?.durationMinutes, 40)
        XCTAssertEqual(model.start, point(10, 106))
        XCTAssertEqual(model.end, point(10.02, 106.02))
        XCTAssertEqual(model.selectedEntryID, "moving_09:00")
        XCTAssertTrue(model.hasPath)
    }

    func testMissingPathDoesNotInventStraightRouteFromEndpoints() {
        let journey = DayJourney(date: nil, summary: nil,
                                 entries: [.moving(moving(start: "08:00", path: []))])

        let model = RouteOverlayModel.build(from: journey, toleranceMeters: 5)

        XCTAssertFalse(model.hasPath)
        XCTAssertTrue(model.segments.isEmpty)
        XCTAssertNil(model.bounds)
    }

    func testSingleStayProducesMarkerWithoutPolyline() {
        let place = point(10.77, 106.7)
        let journey = DayJourney(date: nil, summary: nil,
                                 entries: [.stay(stay(start: "08:00", point: place))])

        let model = RouteOverlayModel.build(from: journey, toleranceMeters: 5)

        XCTAssertEqual(model.start, place)
        XCTAssertEqual(model.end, place)
        XCTAssertEqual(model.stays.count, 1)
        XCTAssertFalse(model.hasPath)
        XCTAssertEqual(model.bounds?.center, place)
    }

    func testEmptyJourneyHasNoBoundsOrMarkers() {
        let model = RouteOverlayModel.build(
            from: DayJourney(date: nil, summary: nil, entries: []), toleranceMeters: 5
        )

        XCTAssertNil(model.start)
        XCTAssertNil(model.end)
        XCTAssertNil(model.bounds)
    }

    func testBoundsPaddingKeepsCenterAndMinimumSpan() {
        let bounds = RouteBounds(points: [point(10, 106)])!
        let padded = bounds.padded(by: 1.5)

        XCTAssertEqual(padded.center, point(10, 106))
        XCTAssertEqual(padded.latitudeSpan, 0.005, accuracy: 0.000_001)
        XCTAssertEqual(padded.longitudeSpan, 0.005, accuracy: 0.000_001)
    }

    private func point(_ latitude: Double, _ longitude: Double) -> GeoPoint {
        GeoPoint(latitude: latitude, longitude: longitude)
    }

    private func moving(start: String, path: [GeoPoint]) -> MovingSegment {
        MovingSegment(fromLatitude: 10, fromLongitude: 106,
                      toLatitude: 10.02, toLongitude: 106.02,
                      startTime: start, endTime: "09:30", durationMinutes: 30,
                      durationFormatted: "30 phút", path: path)
    }

    private func stay(start: String, point: GeoPoint) -> StayPoint {
        StayPoint(latitude: point.latitude, longitude: point.longitude,
                  arrivedAt: start, leftAt: "09:00", durationMinutes: 40,
                  durationFormatted: "40 phút", pointCount: 5)
    }
}
