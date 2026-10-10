import SwiftUI
import Combine

@MainActor
final class MapCoordinator: NavigationCoordinator {
    enum Route: Hashable {
        case memberJourney(userId: String, name: String)
    }

    @Published var path = NavigationPath()

    let currentUser: User
    let viewModel: LiveMapViewModel
    var onRequestSOS: (() -> Void)?

    private let container: AppContainer
    private var pendingMemberId: String?
    private var memberSubscription: AnyCancellable?

    init(container: AppContainer, currentUser: User) {
        self.container = container
        self.currentUser = currentUser
        viewModel = LiveMapViewModel(
            currentUserId: currentUser.id,
            observeMemberLocations: container.observeMemberLocations,
            observeConnection: container.observeConnectionState,
            observeDeviceLocation: container.observeDeviceLocation,
            getCurrentLocation: container.getCurrentLocation
        )
        memberSubscription = viewModel.$memberLocations.sink { [weak self] members in
            guard let self, let id = self.pendingMemberId,
                  let member = members.first(where: { $0.id == id }) else { return }
            self.pendingMemberId = nil
            self.viewModel.centerOnMember(member)
        }
    }

    func showJourney(of member: MemberLocation) {
        push(.memberJourney(userId: member.id, name: member.name))
    }

    func requestSOS() {
        onRequestSOS?()
    }

    func focus(on point: GeoPoint) {
        pendingMemberId = nil
        viewModel.focus(on: point)
    }

    func focus(onMember userId: String) {
        popToRoot()
        pendingMemberId = userId
        if let member = viewModel.memberLocations.first(where: { $0.id == userId }) {
            pendingMemberId = nil
            viewModel.centerOnMember(member)
        }
    }

    func makeJourneyViewModel(userId: String, name: String) -> JourneyViewModel {
        JourneyViewModel(userId: userId, memberName: name,
                         fetchDayJourney: container.fetchDayJourney, reverseGeocode: container.reverseGeocode)
    }
}

struct MapCoordinatorView: View {
    @ObservedObject var coordinator: MapCoordinator

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            LiveMapView(viewModel: coordinator.viewModel, coordinator: coordinator)
                .navigationDestination(for: MapCoordinator.Route.self) { route in
                    switch route {
                    case let .memberJourney(userId, name):
                        JourneyView(viewModel: coordinator.makeJourneyViewModel(userId: userId, name: name))
                    }
                }
        }
    }
}
