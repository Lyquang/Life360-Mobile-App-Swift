import Foundation

/// A device GPS observation; negative speed or course means unavailable.
struct LocationFix: Sendable, Equatable {
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    let horizontalAccuracy: Double
    let speed: Double
    let course: Double

    var point: GeoPoint { GeoPoint(latitude: latitude, longitude: longitude) }
}
