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
    let timeZone: String?
    let geometryPolicy: JourneyGeometryPolicyDTO?
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
    let observedMovingSeconds: Double?
    let observedStaySeconds: Double?
    let unobservedSeconds: Double?
    let firstSeenAt: String?
    let lastSeenAt: String?
}

struct PathCoordinateDTO: Codable, Sendable {
    let latitude: Double
    let longitude: Double
}

struct JourneyPointDTO: Codable, Sendable {
    let latitude: Double
    let longitude: Double
    let recordedAt: String?
    let timestamp: String?
    let accuracy: Double?
}

struct JourneyGapDTO: Codable, Sendable {
    let fromIndex: Int
    let toIndex: Int
    let seconds: Double
    let meters: Double
}

struct JourneyGeometryPolicyDTO: Codable, Sendable {
    let version: Int?
    let gapThresholdSeconds: Double?
    let gapIndexSpace: String?
    let toBoundary: String?
    let stayRadiusMeters: Double?
    let minStayMinutes: Double?
}

/// The journey array mixes "stay" and "moving" items; fields are optional per type.
struct JourneyItemDTO: Codable, Sendable {
    let type: String
    let segmentId: String?

    let latitude: Double?
    let longitude: Double?
    let arrivedAt: String?
    let leftAt: String?
    let pointCount: Int?
    let confidence: String?
    let containsDataGap: Bool?

    let fromLatitude: Double?
    let fromLongitude: Double?
    let toLatitude: Double?
    let toLongitude: Double?
    let startTime: String?
    let endTime: String?
    let path: [PathCoordinateDTO]?
    let points: [JourneyPointDTO]?
    let originalPointCount: Int?
    let distanceMeters: Double?
    let maxGapSeconds: Double?
    let gaps: [JourneyGapDTO]?
    let thinned: Bool?
    let observedMovingSeconds: Double?

    let durationMinutes: Int?
    let durationFormatted: String?
}

typealias LocationHistoryDTO = HistoryResponseDTO
