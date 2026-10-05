import Foundation

// MARK: - Location History (REST)
struct LocationHistoryEntry: Identifiable {
    let id: String
    let latitude: Double
    let longitude: Double
    let timestamp: String

    var point: GeoPoint { GeoPoint(latitude: latitude, longitude: longitude) }
    var date: Date? { ISO8601.date(from: timestamp) }
}

struct LocationHistory {
    let date: String?
    let entries: [LocationHistoryEntry]
}

// MARK: - Realtime member location (Socket)
struct MemberLocation: Identifiable, Equatable {
    let id: String           // userId
    let name: String
    let latitude: Double
    let longitude: Double
    let batteryLevel: Int?
    let timestamp: String

    /// Minutes the member has stayed at this location.
    let durationAtLocation: Int?
    let durationSince: String?
    let durationFormatted: String?

    var point: GeoPoint { GeoPoint(latitude: latitude, longitude: longitude) }
    var initials: String { name.initials }

    /// Stationary for at least 5 minutes.
    var isStaying: Bool { (durationAtLocation ?? 0) >= 5 }

    static func == (lhs: MemberLocation, rhs: MemberLocation) -> Bool {
        lhs.id == rhs.id
    }
}

struct MemberPresence {
    let userId: String
    let isOnline: Bool
}

enum RealtimeConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
}

enum LocationAuthorization: Equatable {
    case notDetermined
    case denied
    case whenInUse
    case always
}
