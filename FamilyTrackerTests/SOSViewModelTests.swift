import XCTest
@testable import FamilyTracker

@MainActor
private final class SOSViewModelLocationStub: SOSLocationProviding {
    var calls = 0
    func currentLocation() async throws -> SOSLocation {
        calls += 1
        return SOSLocation(latitude: 10, longitude: 106, recordedAt: Date())
    }
    func cancel() {}
}

private actor SOSViewModelRepositoryStub: SOSIncidentRepository {
    private(set) var sent: [SOSCreationIntent] = []
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
    func requests() -> [SOSCreationIntent] { sent }
}

@MainActor
final class SOSViewModelTests: XCTestCase {
    func testOlderAndInvalidSOSPositionsAreRejected() {
        let baseline = Date(timeIntervalSince1970: 1_000)
        XCTAssertNil(SOSFollowTimestampPolicy.accepts("1970-01-01T00:16:39Z", after: baseline))
        XCTAssertNil(SOSFollowTimestampPolicy.accepts("invalid", after: baseline))
        XCTAssertNotNil(SOSFollowTimestampPolicy.accepts("1970-01-01T00:16:41.000Z", after: baseline))
    }

    func testDoubleTapWithoutLocationCreatesOneSOSWithoutAccessingGPS() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try SOSPendingIntentStore(fileURL: directory.appendingPathComponent("intent.json"))
        let repository = SOSViewModelRepositoryStub()
        let runner = SOSIntentRunner(store: store, send: { intent, generation in
            try await repository.create(intent, expectedSessionGeneration: generation)
        }, currentSessionGeneration: { 1 })
        let lifecycle = SOSIntentLifecycle(runner: runner)
        lifecycle.start(ownerID: "owner", sessionGeneration: 1)
        await lifecycle.waitForPendingLifecycleWork()
        let session = SOSSessionController(repository: repository)
        session.startSession()
        let location = SOSViewModelLocationStub()
        let model = SOSViewModel(session: session, lifecycle: lifecycle, location: location,
                                 repository: repository, identity: { LocationSessionIdentity(ownerID: "owner", generation: 1) })
        model.send(includeLocation: false)
        model.send(includeLocation: false)
        for _ in 0..<10_000 {
            if !model.busy { break }
            await Task.yield()
        }
        let requests = await repository.requests()
        XCTAssertFalse(model.busy)
        XCTAssertEqual(location.calls, 0)
        XCTAssertEqual(requests.count, 1)
        XCTAssertNil(requests.first?.location)
    }
}
