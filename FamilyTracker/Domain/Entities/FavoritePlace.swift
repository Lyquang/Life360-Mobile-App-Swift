import Foundation

enum PlaceCategory: String, CaseIterable, Identifiable {
    case restaurant
    case entertainment
    case cafe
    case shopping
    case other

    var id: String { rawValue }
}

struct FavoritePlace: Identifiable {
    let id: String
    let groupId: String?
    let name: String
    let category: PlaceCategory
    let latitude: Double?
    let longitude: Double?
    let addedBy: User?
    let createdAt: String?

    var point: GeoPoint? {
        guard let latitude, let longitude else { return nil }
        return GeoPoint(latitude: latitude, longitude: longitude)
    }
}
