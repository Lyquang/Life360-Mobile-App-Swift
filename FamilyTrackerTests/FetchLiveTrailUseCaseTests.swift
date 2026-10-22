import Foundation
import XCTest
@testable import FamilyTracker

final class FetchLiveTrailUseCaseTests: XCTestCase {
    func testLoadsAllPagesWithPairedRevisionCursor() async throws {
        let repository = TrailRepositoryStub(pages: [
            snapshot(revision: 4, seq: 1, hasMore: true),
            snapshot(revision: 4, seq: 3, hasMore: false)
        ])
        let trail = try await FetchLiveTrailUseCase(repository: repository)(
            userId: "user-1", date: "2026-10-18")
        XCTAssertEqual(trail.orderedPoints.map(\.seq), [1, 3])
        XCTAssertEqual(repository.requestedCursors, [1])
        XCTAssertEqual(repository.requestedRevisions, [4])
    }

    func testRevisionConflictRestartsOnceFromFirstPage() async throws {
        let repository = TrailRepositoryStub(pages: [
            snapshot(revision: 4, seq: 1, hasMore: true),
            snapshot(revision: 5, seq: 2, hasMore: false)
        ], conflictOnFirstCatchUp: true)
        let trail = try await FetchLiveTrailUseCase(repository: repository)(
            userId: "user-1", date: "2026-10-18")
        XCTAssertEqual(trail.revision, 5)
        XCTAssertEqual(repository.snapshotCalls, 2)
    }

    func testPageLimitStopsUnboundedPagination() async {
        let repository = TrailRepositoryStub(pages: [snapshot(revision: 4, seq: 1, hasMore: true)])
        do {
            _ = try await FetchLiveTrailUseCase(repository: repository, maxPages: 1)(
                userId: "user-1", date: "2026-10-18")
            XCTFail("Expected page limit")
        } catch FetchLiveTrailError.pageLimitExceeded {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func snapshot(revision: Int, seq: Int, hasMore: Bool) -> LiveTrailSnapshot {
        LiveTrailSnapshot(
            trailId: "trail-1", userId: "user-1", date: "2026-10-18",
            timeZone: "Asia/Ho_Chi_Minh", revision: revision, lastSeq: seq,
            points: [LiveTrailPoint(seq: seq, coordinate: GeoPoint(latitude: 10, longitude: 106),
                                    recordedAt: Date(timeIntervalSince1970: Double(seq)),
                                    accuracy: 8, motionState: "walking", pointId: nil)],
            gaps: [], matches: [], hasMore: hasMore, nextAfterSeq: hasMore ? seq : nil
        )
    }
}

private final class TrailRepositoryStub: LiveTrailRepository {
    var pages: [LiveTrailSnapshot]
    var conflictOnFirstCatchUp: Bool
    var snapshotCalls = 0
    var requestedCursors: [Int] = []
    var requestedRevisions: [Int] = []

    init(pages: [LiveTrailSnapshot], conflictOnFirstCatchUp: Bool = false) {
        self.pages = pages
        self.conflictOnFirstCatchUp = conflictOnFirstCatchUp
    }

    func snapshot(userId: String, date: String, limit: Int) async throws -> LiveTrailSnapshot {
        snapshotCalls += 1
        return pages[min(snapshotCalls - 1, pages.count - 1)]
    }

    func catchUp(userId: String, date: String, afterSeq: Int, revision: Int,
                 limit: Int) async throws -> LiveTrailSnapshot {
        requestedCursors.append(afterSeq)
        requestedRevisions.append(revision)
        if conflictOnFirstCatchUp {
            conflictOnFirstCatchUp = false
            throw LiveTrailLoadError.revisionChanged
        }
        return pages[pages.count - 1]
    }
}
