import XCTest
@testable import FamilyTracker

@MainActor
final class JourneyViewModelTests: XCTestCase {
    func testLoadAndSelectKeepsPreparedGeometry() async {
        let repository = JourneyRepositoryStub()
        repository.journey = makeJourney()
        let viewModel = makeViewModel(repository: repository)

        await viewModel.load()
        XCTAssertEqual(viewModel.routeModel.segments.count, 1)
        XCTAssertEqual(viewModel.totalMovingMinutes, 20)
        XCTAssertNil(viewModel.loadError)

        let original = viewModel.routeModel.segments[0].points
        let geometryID = viewModel.routeModel.geometryID
        XCTAssertEqual(geometryID, RouteOverlayModel.build(
            from: repository.journey, toleranceMeters: 8
        ).geometryID)
        let entry = viewModel.journeyEntries[0]
        viewModel.select(entry)
        XCTAssertEqual(viewModel.routeModel.selectedEntryID, entry.id)
        XCTAssertEqual(viewModel.routeModel.geometryID, geometryID)
        XCTAssertEqual(viewModel.cameraRequest.entryID, entry.id)
        XCTAssertEqual(viewModel.routeModel.segments[0].points, original)

        viewModel.recenter()
        XCTAssertNil(viewModel.routeModel.selectedEntryID)
        XCTAssertNil(viewModel.cameraRequest.entryID)
    }

    func testForbiddenDoesNotShowGenericError() async {
        let repository = JourneyRepositoryStub()
        repository.failure = DomainError.forbidden
        let viewModel = makeViewModel(repository: repository)

        await viewModel.load()

        XCTAssertEqual(viewModel.loadError, .forbidden)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertTrue(viewModel.journeyEntries.isEmpty)
    }

    func testSelectingUnknownMapEntryDoesNothing() async {
        let repository = JourneyRepositoryStub()
        repository.journey = makeJourney()
        let viewModel = makeViewModel(repository: repository)
        await viewModel.load()

        viewModel.selectEntry(id: "missing")

        XCTAssertNil(viewModel.selectedEntryID)
        XCTAssertNil(viewModel.cameraRequest.entryID)
    }

    func testChangingDayClearsOldRouteBeforeNewRequestCompletes() async {
        let repository = JourneyRepositoryStub()
        repository.journey = makeJourney()
        let viewModel = makeViewModel(repository: repository)
        await viewModel.load()
        XCTAssertTrue(viewModel.routeModel.hasPath)

        viewModel.goToPreviousDay()

        XCTAssertFalse(viewModel.routeModel.hasPath)
        XCTAssertTrue(viewModel.journeyEntries.isEmpty)
        viewModel.cancelPendingWork()
    }

    private func makeViewModel(repository: JourneyRepositoryStub) -> JourneyViewModel {
        JourneyViewModel(userId: "member", memberName: "An",
                         fetchDayJourney: FetchDayJourneyUseCase(repository: repository),
                         fetchLiveTrail: FetchLiveTrailUseCase(repository: JourneyTrailStub()),
                         reverseGeocode: ReverseGeocodeUseCase(repository: JourneyGeocoderStub()))
    }

    private func makeJourney() -> DayJourney {
        let path = [GeoPoint(latitude: 10, longitude: 106),
                    GeoPoint(latitude: 10.01, longitude: 106.01)]
        let moving = MovingSegment(
            fromLatitude: 10, fromLongitude: 106, toLatitude: 10.01, toLongitude: 106.01,
            startTime: "2026-10-01T08:00:00Z", endTime: "2026-10-01T08:20:00Z",
            durationMinutes: 20, durationFormatted: "20", path: path
        )
        return DayJourney(date: "2026-10-01", summary: nil, entries: [.moving(moving)])
    }
}

private struct JourneyTrailStub: LiveTrailRepository {
    func snapshot(userId: String, date: String, limit: Int) async throws -> LiveTrailSnapshot {
        throw LiveTrailLoadError.unavailable
    }

    func catchUp(userId: String, date: String, afterSeq: Int,
                 revision: Int, limit: Int) async throws -> LiveTrailSnapshot {
        throw LiveTrailLoadError.unavailable
    }
}

private final class JourneyRepositoryStub: HistoryRepository {
    var journey = DayJourney(date: nil, summary: nil, entries: [])
    var failure: Error?

    func fetchTodayHistory(userId: String) async throws -> LocationHistory {
        LocationHistory(date: nil, entries: [])
    }

    func fetchDayJourney(userId: String, date: String?) async throws -> DayJourney {
        if let failure { throw failure }
        return journey
    }
}

private struct JourneyGeocoderStub: GeocodingRepository {
    func address(for point: GeoPoint) async -> String? { nil }
}
