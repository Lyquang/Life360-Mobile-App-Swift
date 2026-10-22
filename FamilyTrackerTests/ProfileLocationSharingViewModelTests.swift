import Foundation
import XCTest
@testable import FamilyTracker

@MainActor
final class ProfileLocationSharingViewModelTests: XCTestCase {
    func testOfflinePauseKeepsPendingStateVisible() async {
        var current: LocationSharingAccessState = .sharing
        let viewModel = makeViewModel(current: { current }, pause: {
            current = .pendingPause
            throw DomainError.network("offline")
        })

        viewModel.setLocationSharingEnabled(false)
        await waitForUpdate(viewModel)
        XCTAssertEqual(viewModel.locationSharingStatus, .pendingPause)
        XCTAssertNotNil(viewModel.locationSharingError)
    }

    func testResumeOnlyShowsOnAfterServerActionCompletes() async {
        var current: LocationSharingAccessState = .paused
        let viewModel = makeViewModel(current: { current }, resume: {
            current = .sharing
        })

        viewModel.setLocationSharingEnabled(true)
        await waitForUpdate(viewModel)
        XCTAssertEqual(viewModel.locationSharingStatus, .sharing)
        XCTAssertNil(viewModel.locationSharingError)
    }

    private func makeViewModel(
        current: @escaping @MainActor () -> LocationSharingAccessState,
        pause: @escaping @MainActor () async throws -> Void = {},
        resume: @escaping @MainActor () async throws -> Void = {}
    ) -> ProfileViewModel {
        ProfileViewModel(
            user: User(id: "owner-a", name: "Test User", email: "test@example.invalid"),
            backendHost: "example.invalid",
            observeConnection: ObserveConnectionStateUseCase(repository: PrivacyRealtimeStub()),
            onLogout: {}, onLogoutAll: {},
            currentLocationSharingStatus: current,
            refreshLocationSharing: { current() },
            pauseLocationSharing: pause,
            resumeLocationSharing: resume
        )
    }

    private func waitForUpdate(_ viewModel: ProfileViewModel) async {
        for _ in 0..<50 where viewModel.isChangingLocationSharing {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}

private final class PrivacyRealtimeStub: RealtimeSessionRepository {
    var connectionState: RealtimeConnectionState { .disconnected }
    func connect(token: String) {}
    @MainActor func disconnect() {}
    func observeConnectionState() -> AsyncStream<RealtimeConnectionState> {
        AsyncStream { continuation in continuation.finish() }
    }
}
