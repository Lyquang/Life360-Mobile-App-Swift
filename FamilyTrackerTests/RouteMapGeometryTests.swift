import MapKit
import XCTest
@testable import FamilyTracker

final class RouteMapGeometryTests: XCTestCase {
    func testVisibleRectContainsRouteAndSinglePointHasUsableArea() {
        let bounds = RouteBounds(points: [point(10.7, 106.6), point(10.8, 106.8)])!
        let rect = RouteMapGeometry.visibleRect(for: bounds)
        XCTAssertTrue(MKMapRectContainsPoint(rect, MKMapPoint(point(10.7, 106.6).coordinate)))
        XCTAssertTrue(MKMapRectContainsPoint(rect, MKMapPoint(point(10.8, 106.8).coordinate)))

        let single = RouteMapGeometry.visibleRect(for: RouteBounds(points: [point(10.7, 106.6)])!)
        XCTAssertGreaterThan(single.size.width, 0)
        XCTAssertGreaterThan(single.size.height, 0)
    }

    func testAntimeridianUsesShortSpan() {
        let bounds = RouteBounds(points: [point(10, 179.8), point(10, -179.8)])!
        let rect = RouteMapGeometry.visibleRect(for: bounds)
        XCTAssertLessThan(rect.size.width, MKMapSize.world.width / 50)
    }

    func testNearestSegmentRejectsAmbiguousCrossingAndDistantTap() {
        let paths: [(String, [CGPoint])] = [
            ("horizontal", [CGPoint(x: 0, y: 10), CGPoint(x: 100, y: 10)]),
            ("vertical", [CGPoint(x: 50, y: 0), CGPoint(x: 50, y: 100)])
        ]
        XCTAssertEqual(RouteMapGeometry.nearestSegment(to: CGPoint(x: 20, y: 12), paths: paths),
                       "horizontal")
        XCTAssertNil(RouteMapGeometry.nearestSegment(to: CGPoint(x: 50, y: 10), paths: paths))
        XCTAssertNil(RouteMapGeometry.nearestSegment(to: CGPoint(x: 200, y: 200), paths: paths))
    }

    func testDirectionMarkerTracksTravelDirection() {
        let moving = MovingSegment(
            fromLatitude: 10, fromLongitude: 106, toLatitude: 10, toLongitude: 106.01,
            startTime: "08:00", endTime: "08:10", durationMinutes: 10,
            durationFormatted: "10", path: [point(10, 106), point(10, 106.01)]
        )
        let model = RouteOverlayModel.build(
            from: DayJourney(date: nil, summary: nil, entries: [.moving(moving)]),
            toleranceMeters: 0
        )
        let markers = RouteMapMarker.specifications(for: model)
        XCTAssertEqual(markers.count, 3)
        XCTAssertEqual(markers.first(where: { $0.kind == .direction })?.directionSymbol,
                       "arrow.right")
    }

    func testShortSegmentDoesNotPlaceArrowOverEndpoints() {
        let moving = MovingSegment(
            fromLatitude: 10, fromLongitude: 106, toLatitude: 10, toLongitude: 106.0001,
            startTime: "08:00", endTime: "08:01", durationMinutes: 1,
            durationFormatted: "1", path: [point(10, 106), point(10, 106.0001)]
        )
        let model = RouteOverlayModel.build(
            from: DayJourney(date: nil, summary: nil, entries: [.moving(moving)]),
            toleranceMeters: 0
        )

        XCTAssertFalse(RouteMapMarker.specifications(for: model).contains { $0.kind == .direction })
    }

    private func point(_ latitude: Double, _ longitude: Double) -> GeoPoint {
        GeoPoint(latitude: latitude, longitude: longitude)
    }
}
