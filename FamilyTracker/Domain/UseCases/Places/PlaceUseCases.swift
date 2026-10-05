import Foundation

struct FetchPlacesUseCase {
    let repository: PlaceRepository

    func callAsFunction(circleId: String) async throws -> [FavoritePlace] {
        try await repository.fetchPlaces(circleId: circleId)
    }
}

struct AddPlaceUseCase {
    let repository: PlaceRepository

    func callAsFunction(circleId: String, name: String, category: PlaceCategory, location: GeoPoint) async throws -> FavoritePlace {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { throw DomainError.validation("Vui lòng nhập tên địa điểm.") }
        guard (-90...90).contains(location.latitude), (-180...180).contains(location.longitude) else {
            throw DomainError.validation("Tọa độ không hợp lệ.")
        }
        return try await repository.addPlace(circleId: circleId, name: trimmed, category: category, location: location)
    }
}
