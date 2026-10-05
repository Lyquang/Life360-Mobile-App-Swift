import Foundation

struct HistoryResponseDTO: Codable, Sendable {
    let success: Bool
    let count: Int?
    let date: String?
    let data: [HistoryPointDTO]?
    let message: String?
}

struct HistoryPointDTO: Codable, Sendable {
    let id: String?
    let latitude: Double
    let longitude: Double
    let timestamp: String
}

struct DayJourneyResponseDTO: Codable, Sendable {
    let success: Bool
    let date: String?
    let userId: String?
    let summary: DayJourneySummaryDTO?
    let journey: [JourneyItemDTO]?
    let message: String?
}

struct DayJourneySummaryDTO: Codable, Sendable {
    let totalPoints: Int?
    let stayPointCount: Int?
    let movingSegmentCount: Int?
    let totalStayMinutes: Int?
    let totalStayFormatted: String?
    let totalMovingMinutes: Int?
    let totalMovingFormatted: String?
    let firstSeenAt: String?
    let lastSeenAt: String?
}

struct PathCoordinateDTO: Codable, Sendable {
    let latitude: Double
    let longitude: Double
}

/// The journey array mixes "stay" and "moving" items; fields are optional per type.
struct JourneyItemDTO: Codable, Sendable {
    let type: String

    let latitude: Double?
    let longitude: Double?
    let arrivedAt: String?
    let leftAt: String?
    let pointCount: Int?

    let fromLatitude: Double?
    let fromLongitude: Double?
    let toLatitude: Double?
    let toLongitude: Double?
    let startTime: String?
    let endTime: String?
    let path: [PathCoordinateDTO]?
    let points: [HistoryPointDTO]?

    let durationMinutes: Int?
    let durationFormatted: String?
}

typealias LocationHistoryDTO = HistoryResponseDTO
