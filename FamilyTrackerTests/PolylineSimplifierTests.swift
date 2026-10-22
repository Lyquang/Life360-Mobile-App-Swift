import XCTest
@testable import FamilyTracker

final class PolylineSimplifierTests: XCTestCase {
    func testStraightLineKeepsOnlyEndpoints() {
        let points = (0...10).map { GeoPoint(latitude: 0, longitude: Double($0) * 0.001) }

        XCTAssertEqual(PolylineSimplifier.simplify(points, toleranceMeters: 10),
                       [points.first!, points.last!])
    }

    func testBendKeepsItsApexInOriginalOrder() {
        let points = [point(0, 0), point(0.001, 0.001), point(0, 0.002)]

        XCTAssertEqual(PolylineSimplifier.simplify(points, toleranceMeters: 20), points)
    }

    func testInvalidCoordinatesAndConsecutiveDuplicatesAreRemoved() {
        let points = [point(0, 0), point(0, 0), point(.nan, 0), point(91, 0),
                      point(0, 181), point(0, 0.001)]

        XCTAssertEqual(PolylineSimplifier.simplify(points, toleranceMeters: 0),
                       [point(0, 0), point(0, 0.001)])
    }

    func testEmptyAndSinglePointRemainStable() {
        XCTAssertTrue(PolylineSimplifier.simplify([], toleranceMeters: 10).isEmpty)
        XCTAssertEqual(PolylineSimplifier.simplify([point(10, 106)], toleranceMeters: 10),
                       [point(10, 106)])
    }

    func testAntimeridianCrossingUsesShortArc() {
        let points = [point(0, 179.8), point(0, -179.9), point(0, -179.6)]
        let bounds = RouteBounds(points: points)

        XCTAssertEqual(PolylineSimplifier.simplify(points, toleranceMeters: 1_000),
                       [points.first!, points.last!])
        XCTAssertEqual(bounds?.longitudeSpan ?? -1, 0.6, accuracy: 0.000_001)
        XCTAssertEqual(bounds?.center.longitude ?? 0, -179.9, accuracy: 0.000_001)
    }

    func testTenThousandPointSimplificationPerformance() {
        let points = (0..<10_000).map { index in
            point(10, 106 + Double(index) * 0.000_001)
        }
        measure {
            let result = PolylineSimplifier.simplify(points, toleranceMeters: 3)
            XCTAssertEqual(result.count, 2)
        }
    }

    private func point(_ latitude: Double, _ longitude: Double) -> GeoPoint {
        GeoPoint(latitude: latitude, longitude: longitude)
    }
}
