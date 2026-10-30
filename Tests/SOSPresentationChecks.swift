import Foundation

// The networking harness does not compile LocationDeliveryService.
struct LocationSessionIdentity: Equatable, Sendable { let ownerID: String; let generation: Int }
private enum SOSPresentationCheckError: Error { case failed }

@MainActor
private final class StubSOSLocation: SOSLocationProviding {
    var calls = 0
    func currentLocation() async throws -> SOSLocation {
        calls += 1
        return SOSLocation(latitude: 10, longitude: 106, recordedAt: Date())
    }
    func cancel() {}
}

private actor SOSPresentationRepository: SOSIncidentRepository {
    var sent: [SOSCreationIntent] = []
    var responseCount = 0
    var closeCount = 0
    let incident = SOSIncident(id: "000000000000000000000001", ownerId: "owner", status: .active,
                               revision: 1, message: "", location: nil, groupIds: [], createdAt: Date(), closedAt: nil)
    func create(_ intent: SOSCreationIntent, expectedSessionGeneration: Int) async throws -> SOSCreated {
        sent.append(intent)
        return SOSCreated(created: true, incident: SOSSummary(id: incident.id, ownerId: incident.ownerId,
            status: .active, revision: 1, groupCount: 1, recipientCount: 1, createdAt: incident.createdAt, closedAt: nil))
    }
    func list(status: SOSListFilter, limit: Int, cursor: String?) async throws -> SOSIncidentPage {
        SOSIncidentPage(items: [incident], hasMore: false, nextCursor: nil)
    }
    func detail(id: String, limit: Int, afterId: String?) async throws -> SOSDetail {
        SOSDetail(incident: incident, responders: [], hasMore: false, nextAfterId: nil)
    }
    func respond(id: String, expectedSessionGeneration: Int) async throws -> SOSAssistanceResult {
        responseCount += 1
        return SOSAssistanceResult(created: true, sosId: id, revision: 1,
            response: SOSResponder(id: "response", responderId: "helper", name: nil, avatar: nil,
                                    status: "coming", respondedAt: Date()))
    }
    func close(id: String, status: SOSClosure, expectedSessionGeneration: Int) async throws -> SOSClosed {
        closeCount += 1
        return SOSClosed(changed: true, incident: SOSSummary(id: id, ownerId: "owner", status: .resolved,
            revision: 1, groupCount: 1, recipientCount: 1, createdAt: Date(), closedAt: Date()))
    }
    func count() -> Int { sent.count }
    func firstLocation() -> SOSLocation? { sent.first?.location }
    func actionCounts() -> (Int, Int) { (responseCount, closeCount) }
}

enum SOSPresentationChecks {
    @MainActor
    static func run() async throws {
        let baseline = Date(timeIntervalSince1970: 1_000)
        guard SOSFollowTimestampPolicy.accepts("1970-01-01T00:16:39Z", after: baseline) == nil,
              SOSFollowTimestampPolicy.accepts("invalid", after: baseline) == nil,
              SOSFollowTimestampPolicy.accepts("1970-01-01T00:16:41.000Z", after: baseline) != nil else {
            throw SOSPresentationCheckError.failed
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try SOSPendingIntentStore(fileURL: directory.appendingPathComponent("intent.json"))
        let repository = SOSPresentationRepository()
        let runner = SOSIntentRunner(store: store, send: { intent, generation in
            try await repository.create(intent, expectedSessionGeneration: generation)
        }, currentSessionGeneration: { 1 })
        let lifecycle = SOSIntentLifecycle(runner: runner)
        lifecycle.start(ownerID: "owner", sessionGeneration: 1)
        await lifecycle.waitForPendingLifecycleWork()
        let session = SOSSessionController(repository: repository)
        session.startSession()
        let location = StubSOSLocation()
        let viewModel = SOSViewModel(session: session, lifecycle: lifecycle, location: location,
                                     repository: repository, identity: { LocationSessionIdentity(ownerID: "owner", generation: 1) })
        var opened: String?
        viewModel.onOpenIncident = { opened = $0 }
        viewModel.send(includeLocation: false)
        viewModel.send(includeLocation: false)
        for _ in 0..<10_000 {
            if !viewModel.busy { break }
            await Task.yield()
        }
        guard !viewModel.busy, location.calls == 0, await repository.count() == 1,
              await repository.firstLocation() == nil, opened == "000000000000000000000001" else {
            throw SOSPresentationCheckError.failed
        }
        let id = "000000000000000000000001"
        viewModel.respond(to: id) // Owner cannot respond to their own SOS.
        let helper = SOSViewModel(session: session, lifecycle: lifecycle, location: location,
                                  repository: repository,
                                  identity: { LocationSessionIdentity(ownerID: "helper", generation: 1) })
        helper.close(id, status: .resolved) // Only the owner can close it.
        let forbiddenCounts = await repository.actionCounts()
        guard forbiddenCounts.0 == 0, forbiddenCounts.1 == 0 else { throw SOSPresentationCheckError.failed }
        helper.respond(to: id)
        helper.respond(to: id)
        for _ in 0..<10_000 {
            if !helper.busy { break }
            await Task.yield()
        }
        let completedCounts = await repository.actionCounts()
        guard !helper.busy, completedCounts.0 == 1, completedCounts.1 == 0 else { throw SOSPresentationCheckError.failed }
        lifecycle.stop()
        await lifecycle.waitForPendingLifecycleWork()
    }
}
