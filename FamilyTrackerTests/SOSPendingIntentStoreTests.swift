import Foundation
import XCTest
@testable import FamilyTracker

final class SOSPendingIntentStoreTests: XCTestCase {
    func testFrozenIntentAndRetryDeadlineSurviveRestart() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = directory.appendingPathComponent("intent.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = makeIntent("first")
        let store = try SOSPendingIntentStore(fileURL: url)
        let session = try await store.activate(ownerID: "owner-a")
        let saved = try await store.prepare(session: session, intent: first)
        let duplicate = try await store.prepare(session: session, intent: makeIntent("second"))
        XCTAssertEqual(saved.intent, first)
        XCTAssertEqual(duplicate.intent, first)
        let deadline = Date(timeIntervalSince1970: 10_075)
        let updated = try await store.update(session: session, requestID: first.clientRequestId,
                                             state: .uncertain, attemptCount: 1, notBefore: deadline)
        XCTAssertTrue(updated)
        let restarted = try SOSPendingIntentStore(fileURL: url)
        let restoredSession = try await restarted.activate(ownerID: "owner-a")
        let restored = try await restarted.current(session: restoredSession)
        XCTAssertEqual(restored?.intent, first)
        XCTAssertEqual(restored?.state, .uncertain)
        XCTAssertEqual(restored?.notBefore, deadline)
        let values = try directory.resourceValues(forKeys: [.isExcludedFromBackupKey])
        XCTAssertEqual(values.isExcludedFromBackup, true)
    }

    func testAccountSwitchAndStaleCallbackCannotDeleteNewPending() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = directory.appendingPathComponent("intent.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try SOSPendingIntentStore(fileURL: url)
        let firstSession = try await store.activate(ownerID: "owner-a")
        let first = makeIntent("first")
        _ = try await store.prepare(session: firstSession, intent: first)
        let secondSession = try await store.activate(ownerID: "owner-b")
        let empty = try await store.current(session: secondSession)
        XCTAssertNil(empty)
        let second = makeIntent("second")
        _ = try await store.prepare(session: secondSession, intent: second)
        do {
            _ = try await store.clear(session: firstSession, requestID: first.clientRequestId)
            XCTFail("An old session must not clear a new account")
        } catch SOSPendingStoreError.inactiveSession {}
        let current = try await store.current(session: secondSession)
        XCTAssertEqual(current?.intent, second)
        try await store.endSession(secondSession)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testCorruptFileBlocksNewIntentUntilExplicitCleanup() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = directory.appendingPathComponent("intent.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("broken".utf8).write(to: url)
        let store = try SOSPendingIntentStore(fileURL: url)
        do {
            _ = try await store.activate(ownerID: "owner-a")
            XCTFail("Corrupt data must not silently generate a replacement UUID")
        } catch SOSPendingStoreError.corruptData {}
        try await store.clearAll()
        let session = try await store.activate(ownerID: "owner-a")
        let pending = try await store.current(session: session)
        XCTAssertNil(pending)
    }

    func testRetryAfterAndBoundedAttempts() {
        let now = Date(timeIntervalSince1970: 10_000)
        XCTAssertEqual(SOSRetryPolicy.decide(failure: .rateLimited(retryAfter: "75"),
                                              attempts: 1, now: now, jitter: 0),
                       .deferUntil(now.addingTimeInterval(75)))
        XCTAssertEqual(SOSRetryPolicy.decide(failure: .rateLimited(retryAfter: "20"),
                                              attempts: 1, now: now, jitter: 1),
                       .retry(delay: 21, notBefore: now.addingTimeInterval(21)))
        XCTAssertEqual(SOSRetryPolicy.decide(failure: .network, attempts: 3, now: now, jitter: 0),
                       .stop(notBefore: now.addingTimeInterval(4)))
        XCTAssertEqual(SOSRetryPolicy.decide(failure: .unavailable, attempts: 1, now: now, jitter: 0),
                       .stop(notBefore: nil))
    }

    private func makeIntent(_ message: String) -> SOSCreationIntent {
        SOSCreationIntent(clientRequestId: UUID(), message: message, location: nil)
    }
}
