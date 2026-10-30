import Foundation
import XCTest
@testable import FamilyTracker

@MainActor
final class SOSIntentLifecycleTests: XCTestCase {
    func testLogoutCleanupFinishesBeforeAnotherAccountStarts() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try SOSPendingIntentStore(fileURL: directory.appendingPathComponent("intent.json"))
        let runner = SOSIntentRunner(store: store, send: { _, _ in throw SOSFailure.network },
                                     currentSessionGeneration: { 1 })
        let lifecycle = SOSIntentLifecycle(runner: runner)
        lifecycle.start(ownerID: "first", sessionGeneration: 1)
        await lifecycle.waitForPendingLifecycleWork()
        _ = try await runner.prepare(message: nil, location: nil)

        lifecycle.stop()
        lifecycle.start(ownerID: "second", sessionGeneration: 1)
        await lifecycle.waitForPendingLifecycleWork()
        XCTAssertEqual(lifecycle.state, .ready(nil))
        do {
            _ = try await runner.sendPending()
            XCTFail("A previous account's pending SOS survived cleanup")
        } catch SOSIntentRunnerError.noPending { }
    }
}
