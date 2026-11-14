import SwiftUI

@MainActor
final class MapCoordinator: NavigationCoordinator {
    enum Route: Hashable {
        case memberJourney(userId: String, name: String)
    }

    @Published var path = NavigationPath()

    @Published var searchPresented = false
    @Published private(set) var selectedPlace: PlaceSearchResult?
    let placeSearch: PlaceSearchViewModel
    let currentUser: User
    let viewModel: LiveMapViewModel
    var onRequestSOS: (() -> Void)?

    private let container: AppContainer

    init(container: AppContainer, currentUser: User) {
        self.container = container
        self.currentUser = currentUser
        placeSearch = container.makePlaceSearchViewModel(accountID: currentUser.id)
        viewModel = LiveMapViewModel(
            currentUserId: currentUser.id,
            observeMemberLocations: container.observeMemberLocations,
            observeConnection: container.observeConnectionState,
            observeDeviceLocation: container.observeDeviceLocation,
            getCurrentLocation: container.getCurrentLocation,
            fetchLiveTrail: container.fetchLiveTrail,
            realtime: container.realtime
        )
    }

    func openSearch(in region: PlaceSearchRegion) {
        placeSearch.open(in: region)
        guard placeSearch.isActive else { return }
        searchPresented = true
    }

    func closeSearch() {
        placeSearch.stop()
        searchPresented = false
    }

    func selectSearchResult(_ result: PlaceSearchResult) {
        guard placeSearch.accept(result) else { return }
        selectedPlace = result
        viewModel.focus(on: result.point)
        searchPresented = false
    }

    func clearSelectedPlace() { selectedPlace = nil }

    func stop() {
        searchPresented = false
        selectedPlace = nil
        placeSearch.endSession()
    }

    func showJourney(of member: MemberLocation) {
        push(.memberJourney(userId: member.id, name: member.name))
    }

    func requestSOS() {
        onRequestSOS?()
    }

    func focus(on point: GeoPoint) {
        viewModel.focus(on: point)
    }

    func focus(onMember userId: String) {
        closeSearch()
        clearSelectedPlace()
        popToRoot()
        if let member = viewModel.memberLocations.first(where: { $0.id == userId }) {
            viewModel.centerOnMember(member)
        }
    }

    func followSOSMember(_ userID: String, fallback: GeoPoint?, recordedAt: Date?) {
        closeSearch()
        clearSelectedPlace()
        popToRoot()
        viewModel.followSOSMember(userID, fallback: fallback, recordedAt: recordedAt)
    }

    func makeJourneyViewModel(userId: String, name: String) -> JourneyViewModel {
        JourneyViewModel(userId: userId, memberName: name,
                         fetchDayJourney: container.fetchDayJourney,
                         fetchLiveTrail: container.fetchLiveTrail,
                         reverseGeocode: container.reverseGeocode)
    }
}

struct MapCoordinatorView: View {
    @ObservedObject var coordinator: MapCoordinator

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            LiveMapView(viewModel: coordinator.viewModel, coordinator: coordinator)
                .sheet(isPresented: $coordinator.searchPresented, onDismiss: coordinator.closeSearch) {
                    NavigationStack {
                        PlaceSearchView(viewModel: coordinator.placeSearch,
                                        onClose: coordinator.closeSearch,
                                        onSelect: coordinator.selectSearchResult)
                    }
                }
                .navigationDestination(for: MapCoordinator.Route.self) { route in
                    switch route {
                    case let .memberJourney(userId, name):
                        JourneyView(viewModel: coordinator.makeJourneyViewModel(userId: userId, name: name))
                    }
                }
        }
    }
}
