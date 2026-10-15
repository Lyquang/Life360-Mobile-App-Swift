import XCTest
@testable import FamilyTracker

@MainActor
final class LocationDeliveryTests: XCTestCase {
    func testReadyTriggerDuringBatchSchedulesOneFollowUpRun() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let buffer = try LocationBuffer(fileURL: folder.appendingPathComponent("points.jsonl"))
        let batch = WaitingDeliveryBatch()
        let sync = try LocationSyncCoordinator(buffer: buffer, repository: batch,
                                               gateURL: folder.appendingPathComponent("gate.json"))
        var readyID: UUID?
        let service = LocationDeliveryService(buffer: buffer, synchronizer: sync,
                                               session: { .init(ownerID: "a", generation: 1) },
                                               readySessionID: { readyID }, emit: { _, _ in true })
        service.setSharing(true)
        service.accept(fix(at: Date().addingTimeInterval(-10)), batteryLevel: 50)
        await service.waitForPendingWrites()
        readyID = UUID()
        service.requestHistorySync()
        await batch.waitUntilStarted()
        readyID = nil
        service.accept(fix(at: Date()), batteryLevel: 50)
        readyID = UUID()
        service.requestHistorySync()
        await service.waitForPendingWrites()
        await batch.resume()
        await service.waitForSynchronization()
        let calls = await batch.calls
        XCTAssertEqual(calls, 2)
        let remaining = try await buffer.points(ownerID: "a")
        XCTAssertTrue(remaining.isEmpty)
    }

    func testQueuedFixFromPreviousSocketSessionBecomesHistory() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let buffer = try LocationBuffer(fileURL: folder.appendingPathComponent("points.jsonl"))
        var readyID: UUID? = UUID()
        let service = LocationDeliveryService(buffer: buffer, synchronizer: nil,
                                               session: { .init(ownerID: "a", generation: 1) },
                                               readySessionID: { readyID },
                                               emit: { _, _ in XCTFail("Stale socket-session fix emitted"); return false })
        service.setSharing(true)
        let oldSessionFix = fix(at: Date())
        service.accept(oldSessionFix, batteryLevel: 50)
        readyID = UUID()
        await service.waitForPendingWrites()
        let stored = try await buffer.points(ownerID: "a")
        XCTAssertEqual(stored.map(\.recordedAt), [oldSessionFix.timestamp])
    }

    func testOfflineHeartbeatDeduplicatesAndFreshFixPrecedesHistoryBatch() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let buffer = try LocationBuffer(fileURL: folder.appendingPathComponent("points.jsonl"))
        let batch = DeliveryBatchRepository()
        let sync = try LocationSyncCoordinator(buffer: buffer, repository: batch,
                                               gateURL: folder.appendingPathComponent("gate.json"))
        var ready = false
        let readyID = UUID()
        var realtimeFixes: [LocationFix] = []
        let identity = LocationSessionIdentity(ownerID: "a", generation: 1)
        let service = LocationDeliveryService(buffer: buffer, synchronizer: sync, session: { identity },
                                               readySessionID: { ready ? readyID : nil }, emit: { fix, _ in
                                                   realtimeFixes.append(fix)
                                                   return true
                                               })
        service.setSharing(true)
        let offline = fix(at: Date().addingTimeInterval(-5))
        service.accept(offline, batteryLevel: 50)
        service.accept(offline, batteryLevel: 50)
        // An offline fix remains historical even if readiness changes before its disk write.
        ready = true
        await service.waitForPendingWrites()
        let stored = try await buffer.points(ownerID: "a")
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.recordedAt, offline.timestamp)
        XCTAssertTrue(realtimeFixes.isEmpty)

        let fresh = fix(at: Date())
        service.accept(fresh, batteryLevel: 50)
        service.requestHistorySync()
        await service.waitForSynchronization()
        XCTAssertEqual(realtimeFixes, [fresh])
        let uploaded = await batch.uploaded
        XCTAssertEqual(uploaded.flatMap { $0 }.map(\.recordedAt), [offline.timestamp])
        let remaining = try await buffer.points(ownerID: "a")
        XCTAssertTrue(remaining.isEmpty)
    }

    func testStopKeepsBufferedPointsAndAccountSwitchDeletesOldOwner() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let buffer = try LocationBuffer(fileURL: folder.appendingPathComponent("points.jsonl"))
        var identity: LocationSessionIdentity? = .init(ownerID: "a", generation: 1)
        let service = LocationDeliveryService(buffer: buffer, synchronizer: nil, session: { identity },
                                               readySessionID: { nil }, emit: { _, _ in XCTFail("Unexpected emit"); return false })
        service.setSharing(true)
        service.accept(fix(at: Date()), batteryLevel: 70)
        await service.waitForPendingWrites()
        service.setSharing(false)
        identity = nil
        await service.waitForPendingWrites()
        let retained = try await buffer.points(ownerID: "a")
        XCTAssertEqual(retained.count, 1)

        identity = .init(ownerID: "a", generation: 3)
        service.prepareSession()
        await service.waitForPendingWrites()
        let sameOwner = try await buffer.points(ownerID: "a")
        XCTAssertEqual(sameOwner, retained)

        identity = .init(ownerID: "b", generation: 4)
        service.prepareSession()
        await service.waitForPendingWrites()
        let newOwner = try await buffer.points(ownerID: "b")
        XCTAssertTrue(newOwner.isEmpty)
        service.setSharing(true)
        service.accept(fix(at: Date()), batteryLevel: 70)
        await service.waitForPendingWrites()
        service.endSession(clearBuffer: true)
        await service.waitForPendingWrites()
        let afterLogout = try await buffer.points(ownerID: "b")
        XCTAssertTrue(afterLogout.isEmpty)
    }

    func testQueuedPointCannotWriteAfterSharingStops() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let buffer = try LocationBuffer(fileURL: folder.appendingPathComponent("points.jsonl"))
        let service = LocationDeliveryService(buffer: buffer, synchronizer: nil,
                                               session: { .init(ownerID: "a", generation: 1) },
                                               readySessionID: { nil }, emit: { _, _ in false })
        service.setSharing(true)
        service.accept(fix(at: Date()), batteryLevel: 50)
        service.setSharing(false)
        await service.waitForPendingWrites()
        let points = try await buffer.points(ownerID: "a")
        XCTAssertTrue(points.isEmpty)
    }

    private func fix(at timestamp: Date) -> LocationFix {
        LocationFix(latitude: 10, longitude: 106, timestamp: timestamp, horizontalAccuracy: 8, speed: -1, course: -1)
    }
}

private actor DeliveryBatchRepository: LocationBatchRepository {
    private(set) var uploaded: [[BufferedLocationPoint]] = []
    func upload(_ points: [BufferedLocationPoint]) async throws -> LocationBatchResult {
        uploaded.append(points)
        return LocationBatchResult(accepted: points.map(\.pointId), duplicates: [], rejected: [])
    }
}

private actor WaitingDeliveryBatch: LocationBatchRepository {
    private var waiting: CheckedContinuation<Void, Never>?
    private var started: CheckedContinuation<Void, Never>?
    private(set) var calls = 0
    func upload(_ points: [BufferedLocationPoint]) async throws -> LocationBatchResult {
        calls += 1
        if calls == 1 {
            await withCheckedContinuation { continuation in
                waiting = continuation
                started?.resume()
                started = nil
            }
        }
        return LocationBatchResult(accepted: points.map(\.pointId), duplicates: [], rejected: [])
    }
    func waitUntilStarted() async {
        if calls > 0 { return }
        await withCheckedContinuation { started = $0 }
    }
    func resume() { waiting?.resume(); waiting = nil }
}
