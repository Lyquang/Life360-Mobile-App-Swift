import Foundation

struct LocationSessionIdentity: Equatable, Sendable {
    let ownerID: String
    let generation: Int
}

/// Serializes disk mutations while allowing realtime fixes during a REST batch upload.
@MainActor
final class LocationDeliveryService {
    private let buffer: LocationBuffer?
    private let synchronizer: LocationSyncCoordinator?
    private let session: () -> LocationSessionIdentity?
    private let readySessionID: () -> UUID?
    private let emit: (LocationFix, Int?) -> Bool
    private let diagnostics: LocationDiagnostics?
    private let recorder: MobileMetricsRecording?
    private let logger: NetworkLogger
    private var active = false
    private var generation = 0
    private var pending: Task<Void, Never>?
    private var syncTask: Task<Void, Never>?
    private var syncID: UUID?
    private var syncRequestedAgain = false
    private var preparedIdentity: LocationSessionIdentity?

    init(buffer: LocationBuffer?, synchronizer: LocationSyncCoordinator?,
         session: @escaping () -> LocationSessionIdentity?, readySessionID: @escaping () -> UUID?,
         emit: @escaping (LocationFix, Int?) -> Bool, diagnostics: LocationDiagnostics? = nil,
         logger: NetworkLogger = NoopNetworkLogger(), recorder: MobileMetricsRecording? = nil) {
        self.buffer = buffer
        self.synchronizer = synchronizer
        self.session = session
        self.readySessionID = readySessionID
        self.emit = emit
        self.diagnostics = diagnostics
        self.logger = logger
        self.recorder = recorder
    }

    func setSharing(_ value: Bool) {
        active = value
        if value { prepareSession() }
        if !value { stopWork(clearBuffer: false) }
    }

    func prepareSession() {
        guard let identity = session(), identity != preparedIdentity else { return }
        preparedIdentity = identity
        stopWork(clearBuffer: false)
        let previous = pending
        pending = Task { [weak self] in
            await previous?.value
            guard let self, self.session() == identity else { return }
            do {
                try await self.buffer?.activate(ownerID: identity.ownerID)
                // Access also prunes expired points on reauthentication.
                _ = try await self.buffer?.points(ownerID: identity.ownerID)
                if let buffer = self.buffer {
                    await self.recordBufferSummary(buffer, ownerID: identity.ownerID)
                }
            } catch { self.report("buffer_activation_failed") }
        }
    }

    func endSession(clearBuffer: Bool) {
        active = false
        preparedIdentity = nil
        stopWork(clearBuffer: clearBuffer)
    }

    func accept(_ fix: LocationFix, batteryLevel: Int?) {
        guard active, let identity = session() else { return }
        prepareSession()
        let expectedGeneration = generation
        let readyWhenAccepted = readySessionID()
        let previous = pending
        pending = Task { [weak self] in
            await previous?.value
            guard let self, self.isCurrent(identity, generation: expectedGeneration) else { return }
            let signpost = PerformanceSignposts.begin(.deliverLocationFix)
            defer { PerformanceSignposts.end(.deliverLocationFix, signpost) }
            do {
                try await self.buffer?.activate(ownerID: identity.ownerID)
                guard self.isCurrent(identity, generation: expectedGeneration) else { return }
                if let readyWhenAccepted, self.readySessionID() == readyWhenAccepted,
                   self.emit(fix, batteryLevel) { return }
                guard let buffer = self.buffer else {
                    self.report("storage_unavailable")
                    return
                }
                if try await buffer.append(BufferedLocationPoint(fix: fix, batteryLevel: batteryLevel),
                                           ownerID: identity.ownerID) {
                    self.diagnostics?.recordOfflineEnqueue()
                    await self.recordBufferSummary(buffer, ownerID: identity.ownerID)
                }
            } catch { self.report("buffer_write_failed") }
        }
    }

    func requestHistorySync() {
        guard active, let identity = session() else { return }
        let expectedGeneration = generation
        let previous = pending
        pending = Task { [weak self] in
            await previous?.value
            guard let self, self.isCurrent(identity, generation: expectedGeneration), self.readySessionID() != nil,
                  let buffer = self.buffer, let synchronizer = self.synchronizer else { return }
            if self.syncTask != nil {
                self.syncRequestedAgain = true
                return
            }
            do {
                try await buffer.activate(ownerID: identity.ownerID)
                let points = try await buffer.points(ownerID: identity.ownerID)
                await self.recordBufferSummary(buffer, ownerID: identity.ownerID)
                guard !points.isEmpty, self.isCurrent(identity, generation: expectedGeneration) else { return }
                let id = UUID()
                self.syncID = id
                self.syncTask = Task { [weak self] in
                    do {
                        try Task.checkCancellation()
                        let outcome = try await synchronizer.synchronize(ownerID: identity.ownerID)
                        if let self, self.isCurrent(identity, generation: expectedGeneration) {
                            switch outcome {
                            case .completed(let accepted, let duplicates, let permanent, let unknown):
                                self.recordMetrics([
                                    .count(.batchPoint, by: accepted),
                                    .count(.batchDuplicate, by: duplicates),
                                    .count(.batchRejectedPermanent, by: permanent),
                                    .count(.batchRejectedUnknown, by: unknown)
                                ])
                                await self.recordBufferSummary(buffer, ownerID: identity.ownerID)
                            case .deferred:
                                self.recordMetrics([.increment(.batchDeferred)])
                            }
                        }
                    } catch is CancellationError {
                        // Session cleanup cancels the shared synchronizer explicitly.
                    } catch {
                        self?.recordMetrics([.increment(.batchFailure)])
                        self?.report("batch_sync_failed")
                    }
                    if let self, self.syncID == id {
                        self.syncTask = nil
                        self.syncID = nil
                        let again = self.syncRequestedAgain
                        self.syncRequestedAgain = false
                        if again { self.requestHistorySync() }
                    }
                }
            } catch { self.report("buffer_read_failed") }
        }
    }

    /// A deterministic barrier for tests and callers that need durable cleanup completion.
    func waitForPendingWrites() async { await pending?.value }

    func waitForSynchronization() async {
        while true {
            await pending?.value
            guard let task = syncTask else { return }
            await task.value
        }
    }

    private func stopWork(clearBuffer: Bool) {
        generation += 1
        syncTask?.cancel()
        syncTask = nil
        syncID = nil
        syncRequestedAgain = false
        let previous = pending
        pending = Task { [weak self] in
            await previous?.value
            guard let self else { return }
            await self.synchronizer?.cancel()
            if clearBuffer {
                do { try await self.synchronizer?.clear() }
                catch { self.report("retry_gate_cleanup_failed") }
                do { try await self.buffer?.clear() }
                catch { self.report("buffer_cleanup_failed") }
                self.recordMetrics([.bufferSnapshot(depth: 0, oldestAgeSeconds: nil)])
            }
        }
    }

    private func recordBufferSummary(_ buffer: LocationBuffer, ownerID: String) async {
        guard recorder != nil else { return }
        let summary = await buffer.metricsSummary(ownerID: ownerID)
        recordMetrics([.bufferSnapshot(depth: summary.depth, oldestAgeSeconds: summary.oldestAgeSeconds)])
    }

    private func recordMetrics(_ events: [MobileMetricEvent]) {
        guard let recorder else { return }
        Task { for event in events { await recorder.record(event) } }
    }

    private func isCurrent(_ identity: LocationSessionIdentity, generation: Int) -> Bool {
        !Task.isCancelled && active && self.generation == generation && session() == identity
    }

    private func report(_ category: String) {
        logger.logSocket(event: "location_delivery", payload: DiagnosticRedactor.json(["category": category]))
    }
}
