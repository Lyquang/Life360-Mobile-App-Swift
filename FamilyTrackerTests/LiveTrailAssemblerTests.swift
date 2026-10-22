import Foundation
import XCTest
@testable import FamilyTracker

final class LiveTrailAssemblerTests: XCTestCase {
    func testLatePointSortsByRecordedAtAndGapUsesDirectedSeqBoundary() throws {
        var assembler = try LiveTrailAssembler(firstPage: page(
            points: [point(201, at: 20), point(203, at: 40)],
            gaps: [LiveTrailGap(fromSeq: 205, toSeq: 203, seconds: 240, meters: 530)],
            hasMore: true, nextAfterSeq: 203))
        try assembler.append(page(points: [point(205, at: 30)],
                                  gaps: [LiveTrailGap(fromSeq: 205, toSeq: 203, seconds: 240, meters: 530)],
                                  hasMore: false, nextAfterSeq: nil), requestedAfterSeq: 203)
        XCTAssertEqual(assembler.orderedPoints.map(\.seq), [201, 205, 203])
        XCTAssertEqual(assembler.rawRuns.map { $0.map(\.seq) }, [[201, 205], [203]])
        XCTAssertEqual(assembler.cursor, 205)
    }

    func testWrongRevisionAndCursorDoNotMutateSnapshot() throws {
        var assembler = try LiveTrailAssembler(firstPage: page(points: [point(1, at: 1)],
                                                              hasMore: false, nextAfterSeq: nil))
        var changed = page(points: [point(2, at: 2)], hasMore: false, nextAfterSeq: nil)
        changed = LiveTrailSnapshot(trailId: changed.trailId, userId: changed.userId,
                                    date: changed.date, timeZone: changed.timeZone, revision: 5,
                                    lastSeq: changed.lastSeq, points: changed.points, gaps: [], matches: [],
                                    hasMore: false, nextAfterSeq: nil)
        XCTAssertThrowsError(try assembler.append(changed, requestedAfterSeq: 1)) { error in
            XCTAssertEqual(error as? LiveTrailAssemblyError, .revisionChanged)
        }
        XCTAssertThrowsError(try assembler.append(page(points: [point(2, at: 2)],
                                                       hasMore: false, nextAfterSeq: nil),
                                                  requestedAfterSeq: 0)) { error in
            XCTAssertEqual(error as? LiveTrailAssemblyError, .unexpectedCursor)
        }
        XCTAssertEqual(assembler.orderedPoints.map(\.seq), [1])
    }

    func testEmptyMatchUpdateReplacesFullSnapshotSetWithoutInventingPoints() throws {
        let provisional = match("segment-1", status: .provisional)
        let final = match("segment-1", status: .final)
        var assembler = try LiveTrailAssembler(firstPage: page(points: [point(1, at: 1)],
                                                              matches: [provisional],
                                                              hasMore: false, nextAfterSeq: nil))
        try assembler.append(page(points: [], matches: [final], hasMore: false,
                                  nextAfterSeq: nil), requestedAfterSeq: 1)
        XCTAssertEqual(assembler.matches.count, 1)
        XCTAssertEqual(assembler.matches[0].status, .final)
        XCTAssertEqual(assembler.orderedPoints.map(\.seq), [1])
    }

    func testDeltaRequiresExactCursorAndUpsertsMatchWithoutChangingPointOrder() throws {
        var assembler = try LiveTrailAssembler(firstPage: page(
            points: [point(1, at: 10)], hasMore: false, nextAfterSeq: nil))
        let delta = LiveTrailDelta(userId: "user-1", trailId: "trail-1", revision: 4,
                                   afterSeq: 1, toSeq: 3, points: [point(3, at: 5)],
                                   matchedUpdates: [match("segment-1", status: .provisional)])
        try assembler.apply(delta)
        XCTAssertEqual(assembler.cursor, 3)
        XCTAssertEqual(assembler.orderedPoints.map(\.seq), [3, 1])
        XCTAssertEqual(assembler.matches.count, 1)
        XCTAssertThrowsError(try assembler.apply(delta)) { error in
            XCTAssertEqual(error as? LiveTrailAssemblyError, .unexpectedCursor)
        }
        XCTAssertEqual(assembler.orderedPoints.count, 2)
    }

    func testMatchOnlyDeltaDoesNotAdvanceInsertionCursor() throws {
        var assembler = try LiveTrailAssembler(firstPage: page(
            points: [point(1, at: 1), point(3, at: 3)], hasMore: false, nextAfterSeq: nil))
        let delta = LiveTrailDelta(userId: "user-1", trailId: "trail-1", revision: 4,
                                   afterSeq: 3, toSeq: 1, points: [],
                                   matchedUpdates: [match("segment-1", status: .final)])
        try assembler.apply(delta)
        XCTAssertEqual(assembler.cursor, 3)
        XCTAssertEqual(assembler.matches.count, 1)
    }

    private func point(_ seq: Int, at seconds: TimeInterval) -> LiveTrailPoint {
        LiveTrailPoint(seq: seq, coordinate: GeoPoint(latitude: 10, longitude: 106),
                       recordedAt: Date(timeIntervalSince1970: seconds), accuracy: 8,
                       motionState: "walking", pointId: UUID())
    }

    private func match(_ id: String, status: LiveTrailMatchStatus) -> LiveTrailMatch {
        LiveTrailMatch(segmentId: id, fromSeq: 1, toSeq: 2, status: status, geometry: nil,
                       provider: "noop", providerVersion: "v1", confidence: nil,
                       sourceRevision: "r1", generatedAt: Date(timeIntervalSince1970: 1))
    }

    private func page(points: [LiveTrailPoint], gaps: [LiveTrailGap] = [],
                      matches: [LiveTrailMatch] = [], hasMore: Bool,
                      nextAfterSeq: Int?) -> LiveTrailSnapshot {
        LiveTrailSnapshot(trailId: "trail-1", userId: "user-1", date: "2026-10-18",
                          timeZone: "Asia/Ho_Chi_Minh", revision: 4,
                          lastSeq: 205, points: points, gaps: gaps, matches: matches,
                          hasMore: hasMore, nextAfterSeq: nextAfterSeq)
    }
}
