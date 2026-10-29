import Foundation

enum SOSStatus: String, Codable, Sendable {
    case active, resolved, cancelled, expired, unknown
}

enum SOSListFilter: String, Sendable {
    case active, resolved, cancelled, expired, all
}

enum SOSClosure: String, Codable, Sendable {
    case resolved, cancelled
}

struct SOSLocation: Codable, Equatable, Sendable {
    let latitude: Double
    let longitude: Double
    let recordedAt: Date?
}

/// One immutable intent; retries must reuse its UUID and measured location.
struct SOSCreationIntent: Codable, Equatable, Sendable {
    let clientRequestId: UUID
    let message: String?
    let location: SOSLocation?
}

struct SOSIncident: Equatable, Sendable, Identifiable {
    let id: String
    let ownerId: String
    let status: SOSStatus
    let revision: Int
    let message: String
    let location: SOSLocation?
    let groupIds: [String]
    let createdAt: Date
    let closedAt: Date?
}

/// Create/close responses omit detail fields; never substitute this for a full snapshot.
struct SOSSummary: Equatable, Sendable {
    let id: String
    let ownerId: String
    let status: SOSStatus
    let revision: Int
    let groupCount: Int
    let recipientCount: Int
    let createdAt: Date
    let closedAt: Date?
}

struct SOSResponder: Equatable, Sendable, Identifiable {
    let id: String
    let responderId: String
    let name: String?
    let avatar: String?
    let status: String
    let respondedAt: Date
}

struct SOSIncidentPage: Equatable, Sendable {
    let items: [SOSIncident]
    let hasMore: Bool
    let nextCursor: String?
}

struct SOSDetail: Equatable, Sendable {
    let incident: SOSIncident
    let responders: [SOSResponder]
    let hasMore: Bool
    let nextAfterId: String?
}

struct SOSCreated: Equatable, Sendable {
    let created: Bool
    let incident: SOSSummary
}

struct SOSClosed: Equatable, Sendable {
    let changed: Bool
    let incident: SOSSummary
}

struct SOSAssistanceResult: Equatable, Sendable {
    let created: Bool
    let sosId: String
    let revision: Int
    let response: SOSResponder
}

/// Transport details stay in Data; UI will map these stable cases to localized text.
enum SOSFailure: Error, Equatable, Sendable {
    case invalidRequest, unauthorized, forbidden, notFound, conflict, payloadTooLarge
    case rateLimited(retryAfter: String?)
    case unavailable, server, network, invalidResponse, unexpected
}
