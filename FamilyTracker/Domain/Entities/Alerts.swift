import Foundation

struct SOSAlert: Identifiable {
    let id = UUID()
    let userId: String
    let name: String
    let message: String
    let latitude: Double?
    let longitude: Double?
    let groupId: String?
    let groupName: String?
    let timestamp: String

    var point: GeoPoint? {
        guard let latitude, let longitude else { return nil }
        return GeoPoint(latitude: latitude, longitude: longitude)
    }
}

/// A member has stayed at one place long enough to hit a server milestone.
struct LocationStayAlert: Identifiable {
    let id = UUID()
    let userId: String
    let name: String
    let latitude: Double?
    let longitude: Double?
    let durationMinutes: Int
    let durationFormatted: String
    let durationSince: String?
    let groupId: String?
    let groupName: String?
    let message: String
    let timestamp: String

    var point: GeoPoint? {
        guard let latitude, let longitude else { return nil }
        return GeoPoint(latitude: latitude, longitude: longitude)
    }
}
