import Foundation

struct RoutePoint: Equatable, Sendable {
    let latitude: Double
    let longitude: Double
    let recordedAt: Date
    let accuracy: Double?

    var coordinate: GeoPoint { GeoPoint(latitude: latitude, longitude: longitude) }
}
