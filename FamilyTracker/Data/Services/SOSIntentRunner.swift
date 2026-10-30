import Foundation

enum SOSIntentRunnerError: Error, Equatable, Sendable {
    case noSession, noPending, busy, sessionChanged, attemptLimitReached
}

enum SOSIntentOutcome: Equatable, Sendable {
    case confirmed(SOSCreated, pendingCleanupRequired: Bool)
    case waiting(SOSPendingIntent)
    case failed(SOSFailure, SOSPendingIntent)
}

/// Runs one foreground create operation at a time; the UI must explicitly resume after relaunch.
actor SOSIntentRunner {
    typealias Sender = @Sendable (SOSCreationIntent, Int) async throws -> SOSCreated
    typealias Sleeper = @Sendable (TimeInterval) async throws -> Void

    private let store: SOSPendingIntentStore
    private let send: Sender
    private let currentSessionGeneration: @Sendable () -> Int
    private let now: @Sendable () -> Date
    private let jitter: @Sendable () -> Double
    private let sleep: Sleeper
    private var session: SOSPendingSession?
    private var sessionGeneration: Int?
    private var generation = UUID()
    private var flight: Task<SOSIntentOutcome, Error>?
    private var flightID: UUID?
    private var preparing = false

    init(store: SOSPendingIntentStore, send: @escaping Sender,
         currentSessionGeneration: @escaping @Sendable () -> Int,
         now: @escaping @Sendable () -> Date = { Date() },
         jitter: @escaping @Sendable () -> Double = { Double.random(in: 0...1) },
         sleep: @escaping Sleeper = { delay in
             try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
         }) {
        self.store = store
        self.send = send
        self.currentSessionGeneration = currentSessionGeneration
        self.now = now
        self.jitter = jitter
        self.sleep = sleep
    }

    /// Activation never sends automatically; it only restores the prior pending intent.
    func startSession(ownerID: String, sessionGeneration: Int) async throws -> SOSPendingIntent? {
        guard currentSessionGeneration() == sessionGeneration else { throw SOSIntentRunnerError.sessionChanged }
        cancelFlight()
        generation = UUID()
        let expected = generation
        session = nil
        self.sessionGeneration = nil
        let activated = try await store.activate(ownerID: ownerID)
        guard generation == expected, currentSessionGeneration() == sessionGeneration else {
            try? await store.endSession(activated)
            throw SOSIntentRunnerError.sessionChanged
        }
        session = activated
        self.sessionGeneration = sessionGeneration
        // Cancelling screen startup must not erase an ambiguous SOS from disk.
        try Task.checkCancellation()
        let pending = try await store.current(session: activated)
        try ensureCurrent(expected, session: activated)
        return pending
    }

    func prepare(message: String?, location: SOSLocation?) async throws -> SOSPendingIntent {
        guard let session, sessionGeneration != nil else { throw SOSIntentRunnerError.noSession }
        guard flight == nil, !preparing else { throw SOSIntentRunnerError.busy }
        preparing = true
        defer { preparing = false }
        let expected = generation
        let intent = SOSCreationIntent(clientRequestId: UUID(), message: message, location: location)
        let pending = try await store.prepare(session: session, intent: intent)
        try ensureCurrent(expected, session: session)
        return pending
    }

    /// Concurrent callers await the same operation; no second POST is created.
    func sendPending() async throws -> SOSIntentOutcome {
        guard let session, let sessionGeneration else { throw SOSIntentRunnerError.noSession }
        guard !preparing else { throw SOSIntentRunnerError.busy }
        if let flight { return try await flight.value }
        let expected = generation
        let id = UUID()
        let task = Task { try await self.performSend(session: session, generation: expected,
                                                      sessionGeneration: sessionGeneration) }
        flight = task
        flightID = id
        do {
            let result = try await task.value
            if flightID == id { flight = nil; flightID = nil }
            return result
        } catch {
            if flightID == id { flight = nil; flightID = nil }
            throw error
        }
    }

    /// Call when the owning screen/session stops: no retry continues in the background.
    func cancelPendingWork() { flight?.cancel() }

    func endSession() async throws {
        cancelFlight()
        generation = UUID()
        let old = session
        session = nil
        sessionGeneration = nil
        guard let old else { return }
        try await store.endSession(old)
    }

    private func performSend(session: SOSPendingSession, generation expected: UUID,
                             sessionGeneration: Int) async throws -> SOSIntentOutcome {
        guard var pending = try await store.current(session: session) else { throw SOSIntentRunnerError.noPending }
        try ensureCurrent(expected, session: session)
        if let deadline = pending.notBefore, deadline > now() { return .waiting(pending) }
        var attempts = 0
        while attempts < SOSRetryPolicy.maximumAttempts {
            try ensureCurrent(expected, session: session)
            guard pending.attemptCount < Int.max else { throw SOSIntentRunnerError.attemptLimitReached }
            attempts += 1
            let totalAttempts = pending.attemptCount + 1
            // Persist uncertainty first: the process can die after the server commits.
            let saved = try await store.update(session: session, requestID: pending.intent.clientRequestId,
                                               state: .uncertain, attemptCount: totalAttempts, notBefore: nil)
            guard saved else { throw SOSIntentRunnerError.noPending }
            pending.state = .uncertain
            pending.attemptCount = totalAttempts
            pending.notBefore = nil
            try ensureCurrent(expected, session: session)
            let result: SOSCreated
            do {
                result = try await send(pending.intent, sessionGeneration)
            } catch let error as SOSFailure {
                try ensureCurrent(expected, session: session)
                let decision = SOSRetryPolicy.decide(failure: error, attempts: attempts, now: now(), jitter: jitter())
                let deadline: Date?
                switch decision {
                case .retry(_, let notBefore): deadline = notBefore
                case .deferUntil(let notBefore): deadline = notBefore
                case .stop(let notBefore): deadline = notBefore
                }
                let updated = try await store.update(session: session, requestID: pending.intent.clientRequestId,
                                                     state: .uncertain, attemptCount: totalAttempts, notBefore: deadline)
                guard updated else { throw SOSIntentRunnerError.noPending }
                pending.notBefore = deadline
                try ensureCurrent(expected, session: session)
                switch decision {
                case .retry(let delay, _):
                    try await sleep(delay)
                    try ensureCurrent(expected, session: session)
                    if let deadline, deadline > now() { return .waiting(pending) }
                case .deferUntil:
                    return .waiting(pending)
                case .stop:
                    return .failed(error, pending)
                }
                continue
            }
            try ensureCurrent(expected, session: session)
            do {
                let removed = try await store.clear(session: session, requestID: pending.intent.clientRequestId)
                try ensureCurrent(expected, session: session)
                return .confirmed(result, pendingCleanupRequired: !removed)
            } catch is CancellationError {
                throw CancellationError()
            } catch SOSIntentRunnerError.sessionChanged {
                throw SOSIntentRunnerError.sessionChanged
            } catch SOSPendingStoreError.inactiveSession {
                throw SOSIntentRunnerError.sessionChanged
            } catch {
                // The server committed even if local cleanup failed; replay still uses the same UUID.
                try ensureCurrent(expected, session: session)
                return .confirmed(result, pendingCleanupRequired: true)
            }
        }
        throw SOSIntentRunnerError.attemptLimitReached
    }

    private func ensureCurrent(_ expected: UUID, session expectedSession: SOSPendingSession) throws {
        try Task.checkCancellation()
        guard generation == expected, session == expectedSession, let sessionGeneration,
              currentSessionGeneration() == sessionGeneration else { throw SOSIntentRunnerError.sessionChanged }
    }

    private func cancelFlight() {
        flight?.cancel()
        flight = nil
        flightID = nil
    }
}
