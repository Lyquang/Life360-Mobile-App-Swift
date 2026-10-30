import Foundation
import Combine

/// Owns presentation state; navigation remains in EmergencyCoordinator.
@MainActor
final class SOSViewModel: ObservableObject {
    @Published private(set) var busy = false
    @Published var errorMessage: String?
    @Published var showLocationFallback = false
    @Published private(set) var pending: SOSPendingIntent?

    let session: SOSSessionController
    private let lifecycle: SOSIntentLifecycle?
    private let location: SOSLocationProviding
    private let repository: SOSIncidentRepository
    private let identity: () -> LocationSessionIdentity?
    private var task: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    var onOpenIncident: ((String) -> Void)?

    init(session: SOSSessionController, lifecycle: SOSIntentLifecycle?, location: SOSLocationProviding,
         repository: SOSIncidentRepository, identity: @escaping () -> LocationSessionIdentity?) {
        self.session = session
        self.lifecycle = lifecycle
        self.location = location
        self.repository = repository
        self.identity = identity
        lifecycle?.$state.sink { [weak self] state in
            if case .ready(let pending) = state { self?.pending = pending }
        }.store(in: &cancellables)
    }

    func stop() {
        task?.cancel()
        task = nil
        location.cancel()
        busy = false
        pending = nil
        errorMessage = nil
        showLocationFallback = false
    }

    func suspend() {
        task?.cancel()
        location.cancel()
        if let lifecycle { Task { await lifecycle.runner.cancelPendingWork() } }
    }

    func send(includeLocation: Bool) {
        guard !busy else { return }
        guard let lifecycle, let expected = identity() else {
            errorMessage = L10n.tr("sos.new.error.unavailable")
            return
        }
        busy = true
        task = Task { [weak self] in
            guard let self else { return }
            defer { self.busy = false; self.task = nil }
            await lifecycle.waitForPendingLifecycleWork()
            guard !Task.isCancelled, self.identity() == expected else { return }
            guard self.session.mayPerformAction() else {
                self.errorMessage = L10n.tr("sos.new.error.wait"); return
            }
            guard case .ready(let restored) = lifecycle.state else {
                self.errorMessage = L10n.tr("sos.new.error.unavailable"); return
            }
            do {
                // Reuse an ambiguous request before ever collecting a new location.
                if restored == nil && self.pending == nil {
                    var point: SOSLocation?
                    if includeLocation {
                        do { point = try await self.location.currentLocation() }
                        catch is CancellationError { return }
                        catch { self.showLocationFallback = true; return }
                    }
                    guard !Task.isCancelled, self.identity() == expected else { return }
                    self.pending = try await lifecycle.runner.prepare(message: nil, location: point)
                    lifecycle.updatePending(self.pending)
                } else if self.pending == nil { self.pending = restored }
                guard !Task.isCancelled, self.identity() == expected else { return }
                let outcome = try await lifecycle.runner.sendPending()
                guard !Task.isCancelled, self.identity() == expected else { return }
                switch outcome {
                case .confirmed(let created, let cleanupRequired):
                    if !cleanupRequired { self.pending = nil; lifecycle.updatePending(nil) }
                    if cleanupRequired { self.errorMessage = L10n.tr("sos.new.error.cleanup") }
                    await self.session.refreshDetail(id: created.incident.id, minimumRevision: created.incident.revision)
                    guard !Task.isCancelled, self.identity() == expected else { return }
                    self.onOpenIncident?(created.incident.id)
                case .waiting(let pending):
                    self.pending = pending
                    lifecycle.updatePending(pending)
                    if let deadline = pending.notBefore { self.session.deferRequests(until: deadline) }
                    self.errorMessage = L10n.tr("sos.new.error.wait")
                case .failed(let failure, let pending):
                    self.pending = pending
                    lifecycle.updatePending(pending)
                    if case .rateLimited = failure { self.session.noteActionFailure(failure, incidentID: "") }
                    self.errorMessage = Self.message(for: failure)
                    if failure == .conflict { await self.session.reconcile() }
                }
            } catch is CancellationError { return }
            catch {
                guard self.identity() == expected else { return }
                self.errorMessage = L10n.tr("sos.new.error.uncertain")
            }
        }
    }

    func respond(to id: String) { perform(id: id, closure: nil) }
    func close(_ id: String, status: SOSClosure) { perform(id: id, closure: status) }

    private func perform(id: String, closure: SOSClosure?) {
        guard !busy else { return }
        guard session.mayPerformAction() else { errorMessage = L10n.tr("sos.new.error.wait"); return }
        guard let expected = identity(),
              let incident = session.details[id]?.incident, incident.status == .active,
              !session.awaitingRefresh.contains(id) else { return }
        guard (closure == nil && incident.ownerId != expected.ownerID)
                || (closure != nil && incident.ownerId == expected.ownerID) else { return }
        busy = true
        task = Task { [weak self] in
            guard let self else { return }
            defer { self.busy = false; self.task = nil }
            do {
                let revision: Int
                if let closure {
                    revision = try await self.repository.close(id: id, status: closure,
                                                               expectedSessionGeneration: expected.generation).incident.revision
                } else {
                    revision = try await self.repository.respond(id: id,
                                                                 expectedSessionGeneration: expected.generation).revision
                }
                guard !Task.isCancelled, self.identity() == expected else { return }
                await self.session.refreshDetail(id: id, minimumRevision: revision)
            } catch is CancellationError { return }
            catch let failure as SOSFailure {
                guard !Task.isCancelled, self.identity() == expected else { return }
                self.session.noteActionFailure(failure, incidentID: id)
                self.errorMessage = Self.message(for: failure)
                if failure == .conflict { await self.session.refreshDetail(id: id) }
            } catch {
                guard !Task.isCancelled, self.identity() == expected else { return }
                self.errorMessage = L10n.tr("sos.new.error.uncertain")
            }
        }
    }

    static func message(for error: SOSFailure) -> String {
        switch error {
        case .forbidden, .notFound: return L10n.tr("sos.new.error.access")
        case .rateLimited: return L10n.tr("sos.new.error.wait")
        case .unavailable: return L10n.tr("sos.new.error.unavailable")
        case .conflict: return L10n.tr("sos.new.error.conflict")
        case .invalidRequest, .payloadTooLarge: return L10n.tr("sos.new.error.invalid")
        default: return L10n.tr("sos.new.error.uncertain")
        }
    }
}
