import Foundation
import Combine

/// Session-scoped REST recovery. The coordinator owns its lifetime and navigation.
@MainActor
final class SOSSessionController: ObservableObject {
    @Published private(set) var incidents: [String: SOSIncident] = [:]
    @Published private(set) var details: [String: SOSDetail] = [:]
    @Published private(set) var lastError: SOSFailure?
    private(set) var detailErrors: [String: SOSFailure] = [:]
    @Published private(set) var isReconciling = false
    @Published private(set) var refreshing: Set<String> = []
    @Published private(set) var loadingResponders: Set<String> = []
    /// UI must disable incident actions until a fresh authorized detail has arrived.
    @Published private(set) var awaitingRefresh: Set<String> = []

    private let repository: SOSIncidentRepository
    private let now: () -> Date
    private var generation: UUID?
    private var clock: UInt64 = 0
    private var changedAt: [String: UInt64] = [:]
    private var requiredRevision: [String: Int] = [:]
    private var needsAnotherFetch: Set<String> = []
    private var seenResponderCursors: [String: Set<String>] = [:]
    private var cooldownUntil: Date?
    private var reconcileTask: Task<Void, Never>?
    private var detailTasks: [String: Task<Void, Never>] = [:]
    private var responderTasks: [String: Task<Void, Never>] = [:]
    private var responderTaskIDs: [String: UUID] = [:]

    init(repository: SOSIncidentRepository, now: @escaping () -> Date = { Date() }) {
        self.repository = repository
        self.now = now
    }

    func startSession() {
        stop()
        generation = UUID()
    }

    /// Cancellation and the generation fence prevent a late response restoring private data.
    func stop() {
        generation = nil
        reconcileTask?.cancel()
        detailTasks.values.forEach { $0.cancel() }
        responderTasks.values.forEach { $0.cancel() }
        reconcileTask = nil
        detailTasks.removeAll()
        responderTasks.removeAll()
        responderTaskIDs.removeAll()
        incidents.removeAll()
        details.removeAll()
        changedAt.removeAll()
        requiredRevision.removeAll()
        needsAnotherFetch.removeAll()
        seenResponderCursors.removeAll()
        refreshing.removeAll()
        loadingResponders.removeAll()
        awaitingRefresh.removeAll()
        cooldownUntil = nil
        lastError = nil
        detailErrors.removeAll()
        isReconciling = false
        clock = 0
    }

    /// Recover every active list page, then recheck incidents already cached for closure/revocation.
    func reconcile() async {
        guard let generation, mayRequest() else { return }
        if let task = reconcileTask { await task.value; return }
        let task = Task { [weak self] in
            guard let self else { return }
            await self.performReconcile(generation: generation)
        }
        reconcileTask = task
        await task.value
        if self.generation == generation { reconcileTask = nil }
    }

    /// An update is an invalidation, not an authoritative responder list.
    func refreshDetail(id: String, minimumRevision: Int = 0) async {
        guard let generation, minimumRevision >= 0 else { return }
        requiredRevision[id] = max(requiredRevision[id] ?? 0, minimumRevision)
        if minimumRevision > (details[id]?.incident.revision ?? 0) { awaitingRefresh.insert(id) }
        guard mayRequest() else { return }
        if let task = detailTasks[id] {
            needsAnotherFetch.insert(id)
            await task.value
            return
        }
        responderTasks[id]?.cancel()
        responderTasks[id] = nil
        responderTaskIDs[id] = nil
        loadingResponders.remove(id)
        markChanged(id)
        refreshing.insert(id)
        let task = Task { [weak self] in
            guard let self else { return }
            await self.performDetail(id: id, generation: generation)
        }
        detailTasks[id] = task
        await task.value
        if self.generation == generation {
            detailTasks[id] = nil
            refreshing.remove(id)
            // A caller can arrive after the worker returns but before this cleanup.
            if needsAnotherFetch.remove(id) != nil {
                await refreshDetail(id: id, minimumRevision: requiredRevision[id] ?? 0)
            }
        }
    }

    func loadMoreResponders(id: String) async {
        guard let generation, mayRequest(), detailTasks[id] == nil,
              let detail = details[id], detail.hasMore, let cursor = detail.nextAfterId else { return }
        if let task = responderTasks[id] { await task.value; return }
        guard !seenResponderCursors[id, default: []].contains(cursor) else {
            lastError = .invalidResponse
            return
        }
        let version = changedAt[id] ?? 0
        let taskID = UUID()
        loadingResponders.insert(id)
        let task = Task { [weak self] in
            guard let self else { return }
            await self.performResponders(id: id, cursor: cursor, previous: detail,
                                         version: version, generation: generation)
        }
        responderTasks[id] = task
        responderTaskIDs[id] = taskID
        await task.value
        if self.generation == generation, responderTaskIDs[id] == taskID {
            responderTasks[id] = nil
            responderTaskIDs[id] = nil
            loadingResponders.remove(id)
        }
    }

    private func performReconcile(generation expected: UUID) async {
        isReconciling = true
        defer { if generation == expected { isReconciling = false } }
        let knownIDs = Set(incidents.keys)
        let startClock = clock
        var cursor: String?
        var seenCursors: Set<String> = []
        var gathered: [String: SOSIncident] = [:]
        do {
            repeat {
                let page = try await repository.list(status: .active, limit: 100, cursor: cursor)
                guard current(expected) else { return }
                for incident in page.items {
                    if let previous = gathered[incident.id], previous.revision > incident.revision { continue }
                    gathered[incident.id] = incident
                }
                if page.hasMore {
                    guard seenCursors.count < 1_000, let next = page.nextCursor,
                          seenCursors.insert(next).inserted else {
                        throw SOSFailure.invalidResponse
                    }
                    cursor = next
                } else { cursor = nil }
            } while cursor != nil
            for incident in gathered.values { applyList(incident, startedAt: startClock) }
            lastError = nil
            // One request at a time bounds rate/CPU and keeps failed partial scans conservative.
            for id in knownIDs.sorted() {
                guard current(expected), mayRequest() else { return }
                await refreshDetail(id: id)
            }
        } catch is CancellationError {
            return
        } catch let error as SOSFailure {
            guard current(expected) else { return }
            record(error)
        } catch {
            guard current(expected) else { return }
            lastError = .unexpected
        }
    }

    private func performDetail(id: String, generation expected: UUID) async {
        // At most one follow-up covers an event or competing write while GET was in flight.
        for _ in 0..<2 {
            needsAnotherFetch.remove(id)
            let startClock = clock
            do {
                let detail = try await repository.detail(id: id, limit: 50, afterId: nil)
                guard current(expected) else { return }
                let floor = max(requiredRevision[id] ?? 0, incidents[id]?.revision ?? 0)
                let changedDuringRead = (changedAt[id] ?? 0) > startClock
                if detail.incident.revision >= floor && !changedDuringRead {
                    incidents[id] = detail.incident
                    details[id] = detail
                    awaitingRefresh.remove(id)
                    detailErrors[id] = nil
                    seenResponderCursors[id] = []
                    markChanged(id)
                    lastError = nil
                } else { needsAnotherFetch.insert(id) }
                if !needsAnotherFetch.contains(id) { return }
            } catch is CancellationError {
                return
            } catch let error as SOSFailure {
                guard current(expected) else { return }
                detailErrors[id] = error
                if error == .forbidden || error == .notFound {
                    removeIncident(id)
                }
                record(error)
                return
            } catch {
                guard current(expected) else { return }
                detailErrors[id] = .unexpected
                lastError = .unexpected
                return
            }
        }
        // A lagging replica/event cannot roll back a newer snapshot.
        if current(expected) {
            needsAnotherFetch.remove(id)
            lastError = .invalidResponse
        }
    }

    private func performResponders(id: String, cursor: String, previous: SOSDetail,
                                   version: UInt64, generation expected: UUID) async {
        do {
            let page = try await repository.detail(id: id, limit: 50, afterId: cursor)
            guard current(expected), (changedAt[id] ?? 0) == version else { return }
            guard page.incident.revision == previous.incident.revision,
                  page.incident.status == previous.incident.status,
                  page.incident.ownerId == previous.incident.ownerId,
                  page.incident.groupIds == previous.incident.groupIds else {
                responderTasks[id] = nil
                responderTaskIDs[id] = nil
                loadingResponders.remove(id)
                await refreshDetail(id: id, minimumRevision: page.incident.revision)
                return
            }
            if page.hasMore {
                guard let next = page.nextAfterId, next != cursor,
                      !seenResponderCursors[id, default: []].contains(next) else {
                    throw SOSFailure.invalidResponse
                }
            }
            var merged = previous.responders
            for responder in page.responders {
                if let index = merged.firstIndex(where: { $0.id == responder.id || $0.responderId == responder.responderId }) {
                    merged[index] = responder
                } else { merged.append(responder) }
            }
            seenResponderCursors[id, default: []].insert(cursor)
            details[id] = SOSDetail(incident: page.incident, responders: merged,
                                    hasMore: page.hasMore, nextAfterId: page.nextAfterId)
            incidents[id] = page.incident
            markChanged(id)
            lastError = nil
        } catch is CancellationError {
            return
        } catch let error as SOSFailure {
            guard current(expected) else { return }
            if error == .forbidden || error == .notFound {
                removeIncident(id)
            } else if (changedAt[id] ?? 0) != version { return }
            record(error)
        } catch {
            guard current(expected), (changedAt[id] ?? 0) == version else { return }
            lastError = .unexpected
        }
    }

    private func applyList(_ incident: SOSIncident, startedAt: UInt64) {
        let old = incidents[incident.id]
        guard incident.revision >= (requiredRevision[incident.id] ?? 0) else { return }
        if (changedAt[incident.id] ?? 0) > startedAt {
            guard let old, incident.revision > old.revision else { return }
        }
        guard incident.revision >= (old?.revision ?? 0) else { return }
        if let detail = details[incident.id],
           detail.incident.revision != incident.revision || detail.incident.status != incident.status
            || detail.incident.ownerId != incident.ownerId || detail.incident.groupIds != incident.groupIds {
            details[incident.id] = nil
            seenResponderCursors[incident.id] = nil
        }
        if details[incident.id] == nil { awaitingRefresh.insert(incident.id) }
        incidents[incident.id] = incident
        markChanged(incident.id)
    }

    private func removeIncident(_ id: String) {
        incidents[id] = nil
        details[id] = nil
        requiredRevision[id] = nil
        needsAnotherFetch.remove(id)
        awaitingRefresh.remove(id)
        seenResponderCursors[id] = nil
        markChanged(id)
    }

    private func markChanged(_ id: String) {
        clock &+= 1
        changedAt[id] = clock
    }

    private func current(_ expected: UUID) -> Bool { generation == expected && !Task.isCancelled }

    private func mayRequest() -> Bool {
        guard let cooldownUntil, cooldownUntil > now() else { return true }
        return false
    }

    /// REST reads and incident actions share the server's per-account rate limit.
    func mayPerformAction() -> Bool { generation != nil && mayRequest() }

    func deferRequests(until deadline: Date) {
        if deadline > (cooldownUntil ?? .distantPast) { cooldownUntil = deadline }
    }

    func noteActionFailure(_ error: SOSFailure, incidentID: String) {
        if !incidentID.isEmpty { detailErrors[incidentID] = error }
        if error == .forbidden || error == .notFound { removeIncident(incidentID) }
        record(error)
    }

    private func record(_ error: SOSFailure) {
        lastError = error
        guard case .rateLimited(let retryAfter) = error else { return }
        switch SOSRetryPolicy.decide(failure: error, attempts: 1, now: now(), jitter: 0) {
        case .retry(_, let deadline), .deferUntil(let deadline): cooldownUntil = deadline
        case .stop(let deadline): cooldownUntil = deadline
        }
        lastError = .rateLimited(retryAfter: retryAfter)
    }
}
