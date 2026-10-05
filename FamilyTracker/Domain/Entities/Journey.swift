import Foundation

/// A place where the user stayed for at least 5 minutes.
struct StayPoint: Identifiable {
    var id: String { arrivedAt }

    let latitude: Double
    let longitude: Double
    let arrivedAt: String
    let leftAt: String
    let durationMinutes: Int
    let durationFormatted: String
    let pointCount: Int

    var point: GeoPoint { GeoPoint(latitude: latitude, longitude: longitude) }
    var arrivalDate: Date? { ISO8601.date(from: arrivedAt) }
    var departureDate: Date? { ISO8601.date(from: leftAt) }
}

/// Movement between two stay points.
struct MovingSegment: Identifiable {
    var id: String { startTime }

    let fromLatitude: Double
    let fromLongitude: Double
    let toLatitude: Double
    let toLongitude: Double
    let startTime: String
    let endTime: String
    let durationMinutes: Int
    let durationFormatted: String
    let path: [GeoPoint]

    var startDate: Date? { ISO8601.date(from: startTime) }
    var endDate: Date? { ISO8601.date(from: endTime) }
}

enum JourneyEntry: Identifiable {
    case stay(StayPoint)
    case moving(MovingSegment)

    var id: String {
        switch self {
        case .stay(let sp): return "stay_\(sp.id)"
        case .moving(let ms): return "moving_\(ms.id)"
        }
    }

    var points: [GeoPoint] {
        switch self {
        case .stay(let sp): return [sp.point]
        case .moving(let ms): return ms.path
        }
    }
}

struct DayJourneySummary {
    let totalPoints: Int
    let stayPointCount: Int
    let totalStayMinutes: Int
    let totalStayFormatted: String
    let totalMovingMinutes: Int
    let totalMovingFormatted: String
    let firstSeenAt: String?
    let lastSeenAt: String?
}

struct DayJourney {
    let date: String?
    let summary: DayJourneySummary?
    let entries: [JourneyEntry]
}
