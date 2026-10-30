import Foundation
import XCTest
@testable import FamilyTracker

final class SOSIntentRunnerTests: XCTestCase {
    func testRetriesPreserveIntentAndClearOnlyAfterSuccess() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try SOSPendingIntentStore(fileURL: directory.appendingPathComponent("pending.json"))
        let clock = RunnerClock()
        let sender = RunnerSender(failures: [.network, .server])
        let runner = SOSIntentRunner(store: store, send: { intent, generation in
            try await sender.send(intent, generation: generation)
        }, currentSessionGeneration: { 1 },
                                     now: { clock.now() }, jitter: { 0 }, sleep: { clock.advance($0) })
        _ = try await runner.startSession(ownerID: "owner-a", sessionGeneration: 1)
        let pending = try await runner.prepare(message: "Help", location: nil)
        let outcome = try await runner.sendPending()
        guard case .confirmed(_, let cleanup) = outcome else { return XCTFail("Expected confirmed SOS") }
        XCTAssertFalse(cleanup)
        let requests = await sender.requests
        let generations = await sender.generations
        XCTAssertEqual(requests, Array(repeating: pending.intent, count: 3))
        XCTAssertEqual(generations, [1, 1, 1])
        let restored = try await runner.startSession(ownerID: "owner-a", sessionGeneration: 1)
        XCTAssertNil(restored)
    }

    func testLongRateLimitPersistsAndDoesNotSendBeforeDeadline() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try SOSPendingIntentStore(fileURL: directory.appendingPathComponent("pending.json"))
        let clock = RunnerClock()
        let sender = RunnerSender(failures: [.rateLimited(retryAfter: "75")])
        let runner = SOSIntentRunner(store: store, send: { intent, generation in
            try await sender.send(intent, generation: generation)
        }, currentSessionGeneration: { 1 },
                                     now: { clock.now() }, jitter: { 0 }, sleep: { clock.advance($0) })
        _ = try await runner.startSession(ownerID: "owner-a", sessionGeneration: 1)
        let pending = try await runner.prepare(message: "Help", location: nil)
        guard case .waiting(let saved) = try await runner.sendPending() else { return XCTFail("Expected cooldown") }
        XCTAssertEqual(saved.notBefore, clock.now().addingTimeInterval(75))
        let restored = try await runner.startSession(ownerID: "owner-a", sessionGeneration: 1)
        XCTAssertEqual(restored?.intent, pending.intent)
        _ = try await runner.sendPending()
        let count = await sender.requests.count
        XCTAssertEqual(count, 1)
        clock.advance(75)
        guard case .confirmed = try await runner.sendPending() else { return XCTFail("Expected retry") }
    }
}

private final class RunnerClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value = Date(timeIntervalSince1970: 1_000)
    func now() -> Date { lock.lock(); defer { lock.unlock() }; return value }
    func advance(_ seconds: TimeInterval) { lock.lock(); value.addTimeInterval(seconds); lock.unlock() }
}

private actor RunnerSender {
    private(set) var requests: [SOSCreationIntent] = []
    private(set) var generations: [Int] = []
    private var failures: [SOSFailure]
    init(failures: [SOSFailure]) { self.failures = failures }
    func send(_ intent: SOSCreationIntent, generation: Int) throws -> SOSCreated {
        requests.append(intent)
        generations.append(generation)
        if !failures.isEmpty { throw failures.removeFirst() }
        return SOSCreated(created: true, incident: SOSSummary(
            id: "000000000000000000000001", ownerId: "000000000000000000000002", status: .active,
            revision: 1, groupCount: 1, recipientCount: 1, createdAt: Date(timeIntervalSince1970: 1_000), closedAt: nil))
    }
}
