import SwiftUI

@MainActor
final class PlacesCoordinator: ObservableObject {
    @Published var isShowingAddPlace = false

    let viewModel: PlacesViewModel

    init(container: AppContainer) {
        viewModel = PlacesViewModel(
            fetchMyCircles: container.fetchMyCircles,
            fetchPlaces: container.fetchPlaces,
            addPlace: container.addPlace,
            getCurrentLocation: container.getCurrentLocation
        )
    }

    func showAddPlace() {
        guard viewModel.selectedGroupId != nil else { return }
        viewModel.errorMessage = nil
        isShowingAddPlace = true
    }

    func dismissAddPlace() {
        isShowingAddPlace = false
    }
}

struct PlacesCoordinatorView: View {
    @ObservedObject var coordinator: PlacesCoordinator

    var body: some View {
        NavigationStack {
            PlacesView(viewModel: coordinator.viewModel, onAddPlace: coordinator.showAddPlace)
        }
        .sheet(isPresented: $coordinator.isShowingAddPlace) {
            AddPlaceSheet(viewModel: coordinator.viewModel, onClose: coordinator.dismissAddPlace)
        }
    }
}
