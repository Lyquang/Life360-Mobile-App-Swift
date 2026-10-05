import Foundation

struct DigestDTO: Codable, Sendable {
    let id: String
    let groupId: String
    let groupName: String
    let intervalMinutes: Int
    let members: [DigestMemberDTO]
    let sentAt: String
}

struct DigestMemberDTO: Codable, Sendable {
    let userId: String
    let name: String
    let isOnline: Bool
    let lastSeenText: String
    let batteryLevel: Int?
    let latitude: Double?
    let longitude: Double?
    let locationUpdatedAt: String?
    let durationMinutes: Int
    let durationFormatted: String?
    let summary: String?
}

struct PaginationDTO: Codable, Sendable {
    let currentPage: Int
    let totalPages: Int
    let totalItems: Int
    let itemsPerPage: Int
    let hasNextPage: Bool
    let hasPrevPage: Bool
}

struct GroupSettingsDTO: Codable, Sendable {
    let notificationIntervalMinutes: Int
    let lastDigestSentAt: String?
}

struct DigestPageDTO: Codable, Sendable {
    let success: Bool
    let data: [DigestDTO]
    let pagination: PaginationDTO
    let groupSettings: GroupSettingsDTO
}

/// A successful response with data=null means no digest has been sent yet.
struct LatestDigestDTO: Codable, Sendable {
    let success: Bool
    let data: DigestDTO?
    let message: String?
    let groupSettings: GroupSettingsDTO
}
