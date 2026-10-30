import Foundation
import Combine

/// Serializes session startup and cleanup so an old logout cannot erase a new session.
@MainActor
final class SOSIntentLifecycle: ObservableObject {
    enum State: Equatable {
        case inactive, starting, ready(SOSPendingIntent?), failed
    }

    @Published private(set) var state: State = .inactive
    let runner: SOSIntentRunner
    private var operation: Task<Void, Never>?
    private var sessionID = UUID()
    private var cleanupFailed = false

    init(runner: SOSIntentRunner) { self.runner = runner }

    func start(ownerID: String, sessionGeneration: Int) {
        let previous = operation
        let id = UUID()
        sessionID = id
        state = .starting
        let runner = runner
        operation = Task { [weak self] in
            await previous?.value
            guard let self, self.sessionID == id else { return }
            guard !self.cleanupFailed else { self.state = .failed; return }
            do {
                let pending = try await runner.startSession(ownerID: ownerID, sessionGeneration: sessionGeneration)
                guard self.sessionID == id else { return }
                self.state = .ready(pending)
            } catch {
                guard self.sessionID == id else { return }
                self.state = .failed
            }
        }
    }

    func stop() {
        let previous = operation
        let id = UUID()
        sessionID = id
        state = .inactive
        let runner = runner
        let cancellation = Task { await runner.cancelPendingWork() }
        operation = Task { [weak self] in
            await cancellation.value
            await previous?.value
            do {
                try await runner.endSession()
                self?.cleanupFailed = false
            }
            catch {
                guard let self else { return }
                self.cleanupFailed = true
                if self.sessionID == id { self.state = .failed }
            }
        }
    }

    func waitForPendingLifecycleWork() async { await operation?.value }

    func updatePending(_ pending: SOSPendingIntent?) {
        guard case .ready = state else { return }
        state = .ready(pending)
    }
}
