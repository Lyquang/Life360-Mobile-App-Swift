import Foundation
import XCTest
@testable import FamilyTracker

final class LocationSyncCoordinatorTests: XCTestCase {
    private let owner = "owner-a"
    private let start = Date(timeIntervalSince1970: 1_000_000)

    func testPartialResultRemovesOnlyKnownIDsAndCountsUnknownRejection() async throws {
        let fixture = try await makeFixture()
        defer { fixture.remove() }
        let points = (0..<4).map(makePoint)
        for point in points { try await fixture.buffer.append(point, ownerID: owner, now: start) }
        let result = LocationBatchResult(
            accepted: [points[0].pointId], duplicates: [points[1].pointId],
            rejected: [
                LocationBatchRejection(index: 2, pointId: points[2].pointId,
                                       code: "RECORDED_AT_TOO_OLD", reason: "too old"),
                LocationBatchRejection(index: 3, pointId: points[3].pointId,
                                       code: "UNDOCUMENTED", reason: "unknown")
            ]
        )
        let repository = ScriptedBatchRepository([.success(result)])
        let coordinator = try makeCoordinator(fixture: fixture, repository: repository)

        let outcome = try await coordinator.synchronize(ownerID: owner)
        XCTAssertEqual(outcome, .completed(accepted: 1, duplicates: 1,
                                           permanentlyRejected: 1, unknownRejected: 1))
        let remaining = try await fixture.buffer.points(ownerID: owner, now: start)
        XCTAssertEqual(remaining.map(\.pointId), [points[3].pointId])
        XCTAssertEqual(remaining.first?.unknownRejectionAttempts, 1)
    }

    func test413SplitsBatchAndTransientRetriesWithDeterministicBackoff() async throws {
        let fixture = try await makeFixture()
        defer { fixture.remove() }
        for point in (0..<4).map(makePoint) { try await fixture.buffer.append(point, ownerID: owner, now: start) }
        let repository = ScriptedBatchRepository([.failure(.payloadTooLarge), .failure(.transient)])
        let sleeper = SleepRecorder()
        let coordinator = try makeCoordinator(fixture: fixture, repository: repository,
                                               sleep: { seconds in await sleeper.record(seconds) })

        let outcome = try await coordinator.synchronize(ownerID: owner)
        XCTAssertEqual(outcome, .completed(accepted: 4, duplicates: 0,
                                           permanentlyRejected: 0, unknownRejected: 0))
        let sizes = await repository.batchSizes
        XCTAssertEqual(sizes, [4, 2, 2, 2])
        let delays = await sleeper.durations
        XCTAssertEqual(delays, [2])
        let remaining = try await fixture.buffer.points(ownerID: owner, now: start)
        XCTAssertTrue(remaining.isEmpty)
    }

    func testLongRetryAfterPersistsAcrossCoordinatorInstances() async throws {
        let fixture = try await makeFixture()
        defer { fixture.remove() }
        try await fixture.buffer.append(makePoint(0), ownerID: owner, now: start)
        let repository = ScriptedBatchRepository([.failure(.rateLimited(retryAfter: "120"))])
        let first = try makeCoordinator(fixture: fixture, repository: repository)
        let until = start.addingTimeInterval(120)
        let firstResult = try await first.synchronize(ownerID: owner)
        XCTAssertEqual(firstResult, .deferred(until: until))

        let second = try makeCoordinator(fixture: fixture, repository: repository)
        let secondResult = try await second.synchronize(ownerID: owner)
        XCTAssertEqual(secondResult, .deferred(until: until))
        let callCount = await repository.batchSizes.count
        XCTAssertEqual(callCount, 1)
        let exclusion = try fixture.gateURL.resourceValues(forKeys: [.isExcludedFromBackupKey])
        XCTAssertEqual(exclusion.isExcludedFromBackup, true)
    }

    func testSingleFlightSharesOneUploadAndCancellationKeepsPoint() async throws {
        let fixture = try await makeFixture()
        defer { fixture.remove() }
        try await fixture.buffer.append(makePoint(0), ownerID: owner, now: start)
        let repository = SuspendedBatchRepository()
        let coordinator = try makeCoordinator(fixture: fixture, repository: repository)

        let first = Task { try await coordinator.synchronize(ownerID: owner) }
        await repository.waitUntilStarted()
        let second = Task { try await coordinator.synchronize(ownerID: owner) }
        while await coordinator.joinedRunCount == 0 { await Task.yield() }
        await repository.complete()
        let firstOutcome = try await first.value
        let secondOutcome = try await second.value
        XCTAssertEqual(firstOutcome, secondOutcome)
        let calls = await repository.calls
        XCTAssertEqual(calls, 1)

        try await fixture.buffer.append(makePoint(1), ownerID: owner, now: start)
        let waiting = SuspendedBatchRepository()
        let cancelCoordinator = try makeCoordinator(fixture: fixture, repository: waiting)
        let task = Task { try await cancelCoordinator.synchronize(ownerID: owner) }
        await waiting.waitUntilStarted()
        await cancelCoordinator.cancel()
        await waiting.complete()
        do {
            _ = try await task.value
            XCTFail("Cancelled sync should not remove an in-flight point")
        } catch is CancellationError {}
        let remaining = try await fixture.buffer.points(ownerID: owner, now: start)
        XCTAssertEqual(remaining.map(\.pointId), [makePoint(1).pointId])
    }

    func testPointAppendedDuringUploadSurvivesOldBatchAcknowledgement() async throws {
        let fixture = try await makeFixture()
        defer { fixture.remove() }
        try await fixture.buffer.append(makePoint(0), ownerID: owner, now: start)
        let repository = SuspendedBatchRepository()
        let coordinator = try makeCoordinator(fixture: fixture, repository: repository)
        let task = Task { try await coordinator.synchronize(ownerID: owner) }
        await repository.waitUntilStarted()
        try await fixture.buffer.append(makePoint(1), ownerID: owner, now: start)
        await repository.complete()
        _ = try await task.value

        let remaining = try await fixture.buffer.points(ownerID: owner, now: start)
        XCTAssertEqual(remaining.map(\.pointId), [makePoint(1).pointId])
    }

    private func makeFixture() async throws -> Fixture {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,
                                                                                    isDirectory: true)
        let buffer = try LocationBuffer(fileURL: folder.appendingPathComponent("points.jsonl"))
        try await buffer.activate(ownerID: owner)
        return Fixture(folder: folder, buffer: buffer)
    }

    private func makeCoordinator(fixture: Fixture, repository: LocationBatchRepository,
                                 sleep: @escaping LocationSyncCoordinator.Sleep = { _ in }) throws -> LocationSyncCoordinator {
        try LocationSyncCoordinator(buffer: fixture.buffer, repository: repository, gateURL: fixture.gateURL,
                                    now: { Date(timeIntervalSince1970: 1_000_000) },
                                    sleep: sleep, randomUnit: { 0 })
    }

    private func makePoint(_ index: Int) -> BufferedLocationPoint {
        let fix = LocationFix(latitude: 10 + Double(index) / 10_000, longitude: 106,
                              timestamp: start.addingTimeInterval(Double(index)),
                              horizontalAccuracy: 8, speed: 1, course: 0)
        return BufferedLocationPoint(pointId: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 1))!,
                                     fix: fix, batteryLevel: 80)
    }
}

private struct Fixture {
    let folder: URL
    let buffer: LocationBuffer
    var gateURL: URL { folder.appendingPathComponent("retry-gate.json") }
    func remove() { try? FileManager.default.removeItem(at: folder) }
}

private actor ScriptedBatchRepository: LocationBatchRepository {
    private var results: [Result<LocationBatchResult, LocationBatchError>]
    private(set) var batchSizes: [Int] = []

    init(_ results: [Result<LocationBatchResult, LocationBatchError>]) { self.results = results }

    func upload(_ points: [BufferedLocationPoint]) async throws -> LocationBatchResult {
        batchSizes.append(points.count)
        if !results.isEmpty { return try results.removeFirst().get() }
        return LocationBatchResult(accepted: points.map(\.pointId), duplicates: [], rejected: [])
    }
}

private actor SuspendedBatchRepository: LocationBatchRepository {
    private var continuation: CheckedContinuation<LocationBatchResult, Error>?
    private var started: CheckedContinuation<Void, Never>?
    private var pendingIDs: [UUID] = []
    private(set) var calls = 0

    func upload(_ points: [BufferedLocationPoint]) async throws -> LocationBatchResult {
        calls += 1
        pendingIDs = points.map(\.pointId)
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            started?.resume()
            started = nil
        }
    }

    func waitUntilStarted() async {
        if calls > 0 { return }
        await withCheckedContinuation { started = $0 }
    }

    func complete() {
        continuation?.resume(returning: LocationBatchResult(accepted: pendingIDs, duplicates: [], rejected: []))
        continuation = nil
    }
}

private actor SleepRecorder {
    private(set) var durations: [TimeInterval] = []
    func record(_ duration: TimeInterval) { durations.append(duration) }
}
