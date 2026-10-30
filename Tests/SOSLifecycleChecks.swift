import Foundation

private enum LifecycleCheckError: Error { case failed }

enum SOSLifecycleChecks {
    @MainActor
    static func run() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try SOSPendingIntentStore(fileURL: directory.appendingPathComponent("intent.json"))
        let runner = SOSIntentRunner(store: store, send: { _, _ in throw SOSFailure.network },
                                     currentSessionGeneration: { 1 })
        let lifecycle = SOSIntentLifecycle(runner: runner)
        lifecycle.start(ownerID: "first", sessionGeneration: 1)
        await lifecycle.waitForPendingLifecycleWork()
        guard case .ready(nil) = lifecycle.state else { throw LifecycleCheckError.failed }
        _ = try await runner.prepare(message: nil, location: nil)

        // Cleanup must finish before a different account can restore anything.
        lifecycle.stop()
        lifecycle.start(ownerID: "second", sessionGeneration: 1)
        await lifecycle.waitForPendingLifecycleWork()
        guard case .ready(nil) = lifecycle.state else { throw LifecycleCheckError.failed }
        do { _ = try await runner.sendPending(); throw LifecycleCheckError.failed }
        catch SOSIntentRunnerError.noPending {}

        _ = try await runner.prepare(message: nil, location: nil)
        lifecycle.stop()
        await lifecycle.waitForPendingLifecycleWork()
        guard lifecycle.state == .inactive else { throw LifecycleCheckError.failed }
        let next = try await runner.startSession(ownerID: "second", sessionGeneration: 1)
        guard next == nil else { throw LifecycleCheckError.failed }
        try await runner.endSession()
    }
}
