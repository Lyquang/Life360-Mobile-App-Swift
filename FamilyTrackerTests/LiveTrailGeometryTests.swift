import XCTest
@testable import FamilyTracker

final class LiveTrailGeometryTests: XCTestCase {
    func testGapSplitsRawTrailAndNeverDrawsStraightAcrossMissingFixes() throws {
        let trail = try LiveTrailAssembler(firstPage: snapshot(
            gaps: [LiveTrailGap(fromSeq: 2, toSeq: 3, seconds: 500, meters: 600)]))
        let drawing = TrailDrawing.build(from: trail)
        XCTAssertEqual(drawing.lines.count, 2)
        XCTAssertTrue(drawing.lines.allSatisfy { $0.style == .gps })
        XCTAssertEqual(drawing.lines.map { $0.points.count }, [2, 2])
    }

    func testOnlyRealValidPolyline6BecomesSolid() throws {
        let valid = match(provider: "road-provider", data: "_p~iF~ps|U_ulLnnqC")
        let fake = match(provider: "fake", data: "_p~iF~ps|U_ulLnnqC")
        let noGeometry = try LiveTrailAssembler(firstPage: snapshot(matches: [fake]))
        XCTAssertTrue(TrailDrawing.build(from: noGeometry).lines.allSatisfy { $0.style == .gps })

        let validTrail = try LiveTrailAssembler(firstPage: snapshot(matches: [valid]))
        XCTAssertTrue(TrailDrawing.build(from: validTrail).lines.contains { $0.style == .matched })

        let malformed = try LiveTrailAssembler(firstPage: snapshot(matches: [
            match(provider: "road-provider", data: "~~~~~~")
        ]))
        XCTAssertTrue(TrailDrawing.build(from: malformed).lines.allSatisfy { $0.style == .gps })
    }

    private func snapshot(gaps: [LiveTrailGap] = [],
                          matches: [LiveTrailMatch] = []) -> LiveTrailSnapshot {
        let points = (1...4).map { seq in
            LiveTrailPoint(seq: seq, coordinate: GeoPoint(latitude: 10 + Double(seq) * 0.001,
                                                           longitude: 106 + Double(seq) * 0.001),
                           recordedAt: Date(timeIntervalSince1970: Double(seq)),
                           accuracy: 8, motionState: "walking", pointId: nil)
        }
        return LiveTrailSnapshot(trailId: "trail", userId: "user", date: "2026-10-18",
                                 timeZone: "Asia/Ho_Chi_Minh", revision: 1, lastSeq: 4,
                                 points: points, gaps: gaps, matches: matches,
                                 hasMore: false, nextAfterSeq: nil)
    }

    private func match(provider: String, data: String) -> LiveTrailMatch {
        LiveTrailMatch(segmentId: "segment", fromSeq: 1, toSeq: 2, status: .final,
                       geometry: LiveTrailGeometry(encoding: "polyline6", data: data),
                       provider: provider, providerVersion: "1", confidence: 0.9,
                       sourceRevision: "revision", generatedAt: Date())
    }
}
