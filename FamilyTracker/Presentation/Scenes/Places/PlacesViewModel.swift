import Foundation
import MapKit

@MainActor
final class PlacesViewModel: ObservableObject {
    @Published private(set) var groups: [FamilyGroup] = []
    @Published private(set) var selectedGroupId: String?
    @Published private(set) var places: [FavoritePlace] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isAdding = false
    @Published var errorMessage: String?
    @Published var loadErrorMessage: String?
    @Published var successMessage: String?
    @Published private(set) var selectedPlace: FavoritePlace?
    @Published var mapRegion: MKCoordinateRegion = .defaultCity

    private let fetchMyCircles: FetchMyCirclesUseCase
    private let fetchPlaces: FetchPlacesUseCase
    private let addPlace: AddPlaceUseCase
    private let getCurrentLocation: GetCurrentLocationUseCase

    init(
        fetchMyCircles: FetchMyCirclesUseCase,
        fetchPlaces: FetchPlacesUseCase,
        addPlace: AddPlaceUseCase,
        getCurrentLocation: GetCurrentLocationUseCase
    ) {
        self.fetchMyCircles = fetchMyCircles
        self.fetchPlaces = fetchPlaces
        self.addPlace = addPlace
        self.getCurrentLocation = getCurrentLocation
    }

    var currentLocation: GeoPoint? { getCurrentLocation() }

    func loadGroups() async {
        do {
            groups = try await fetchMyCircles()
            if selectedGroupId == nil, let first = groups.first {
                await selectGroup(first.id)
            }
        } catch {
            loadErrorMessage = error.localizedDescription
        }
    }

    func selectGroup(_ groupId: String) async {
        selectedGroupId = groupId
        await reloadPlaces()
    }

    func reloadPlaces() async {
        guard let groupId = selectedGroupId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            places = try await fetchPlaces(circleId: groupId)
        } catch {
            loadErrorMessage = error.localizedDescription
        }
    }

    /// Returns true on success so the sheet can dismiss itself.
    func add(name: String, category: PlaceCategory, location: GeoPoint) async -> Bool {
        guard let groupId = selectedGroupId else { return false }
        isAdding = true
        errorMessage = nil
        defer { isAdding = false }
        do {
            let place = try await addPlace(circleId: groupId, name: name, category: category, location: location)
            places.insert(place, at: 0)
            successMessage = "Đã thêm '\(place.name)' vào danh sách yêu thích!"
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func places(for category: PlaceCategory?) -> [FavoritePlace] {
        guard let category else { return places }
        return places.filter { $0.category == category }
    }

    func focus(on place: FavoritePlace) {
        guard let coordinate = place.coordinate else { return }
        selectedPlace = place
        mapRegion = MKCoordinateRegion(center: coordinate, delta: 0.01)
    }
}
