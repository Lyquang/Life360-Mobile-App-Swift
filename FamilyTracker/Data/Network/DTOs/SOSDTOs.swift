import Foundation

struct SOSCreateRequestDTO: Encodable {
    let clientRequestId: String
    let message: String?
    let latitude: Double?
    let longitude: Double?
    let recordedAt: String?

    init(_ intent: SOSCreationIntent) {
        clientRequestId = intent.clientRequestId.uuidString.lowercased()
        message = intent.message?.trimmingCharacters(in: .whitespacesAndNewlines)
        latitude = intent.location?.latitude
        longitude = intent.location?.longitude
        // Endpoint uses the default JSONEncoder: explicitly encode ISO instead of numeric Date.
        recordedAt = intent.location?.recordedAt.map(ISO8601.string(from:))
    }
}

struct SOSStatusRequestDTO: Encodable {
    let status: String
}

struct SOSLocationDTO: Decodable {
    let latitude: Double
    let longitude: Double
    let recordedAt: Date?

    func toDomain() throws -> SOSLocation {
        guard latitude.isFinite, longitude.isFinite,
              (-90...90).contains(latitude), (-180...180).contains(longitude) else {
            throw SOSFailure.invalidResponse
        }
        return SOSLocation(latitude: latitude, longitude: longitude, recordedAt: recordedAt)
    }
}

struct SOSIncidentDTO: Decodable {
    let id: String
    let ownerId: String
    let status: String
    let revision: Int
    let message: String
    let location: SOSLocationDTO?
    let groupIds: [String]
    let createdAt: Date
    let closedAt: Date?

    func toDomain() throws -> SOSIncident {
        guard revision >= 1 else { throw SOSFailure.invalidResponse }
        return SOSIncident(id: id, ownerId: ownerId, status: SOSStatus(rawValue: status) ?? .unknown,
                           revision: revision, message: message, location: try location?.toDomain(),
                           groupIds: groupIds, createdAt: createdAt, closedAt: closedAt)
    }
}

struct SOSSummaryDTO: Decodable {
    let id: String
    let ownerId: String
    let status: String
    let revision: Int
    let groupCount: Int
    let recipientCount: Int
    let createdAt: Date
    let closedAt: Date?

    func toDomain() throws -> SOSSummary {
        guard revision >= 1, groupCount >= 0, recipientCount >= 0 else { throw SOSFailure.invalidResponse }
        return SOSSummary(id: id, ownerId: ownerId, status: SOSStatus(rawValue: status) ?? .unknown,
                          revision: revision, groupCount: groupCount, recipientCount: recipientCount,
                          createdAt: createdAt, closedAt: closedAt)
    }
}

struct SOSResponderDTO: Decodable {
    let id: String
    let responderId: String
    let name: String?
    let avatar: String?
    let status: String
    let respondedAt: Date

    func toDomain() -> SOSResponder {
        SOSResponder(id: id, responderId: responderId, name: name, avatar: avatar,
                     status: status, respondedAt: respondedAt)
    }
}

struct SOSPageDTO: Decodable {
    let items: [SOSIncidentDTO]
    let hasMore: Bool
    let nextCursor: String?

    func toDomain() throws -> SOSIncidentPage {
        guard !hasMore || nextCursor.map(SOSEndpoint.isValidID) == true else { throw SOSFailure.invalidResponse }
        return SOSIncidentPage(items: try items.map { try $0.toDomain() }, hasMore: hasMore, nextCursor: nextCursor)
    }
}

struct SOSDetailDTO: Decodable {
    let incident: SOSIncidentDTO
    let responders: [SOSResponderDTO]
    let hasMore: Bool
    let nextAfterId: String?

    func toDomain() throws -> SOSDetail {
        guard !hasMore || nextAfterId.map(SOSEndpoint.isValidID) == true else { throw SOSFailure.invalidResponse }
        return SOSDetail(incident: try incident.toDomain(), responders: responders.map { $0.toDomain() },
                         hasMore: hasMore, nextAfterId: nextAfterId)
    }
}

struct SOSCreatedDTO: Decodable {
    let created: Bool
    let incident: SOSSummaryDTO
}

struct SOSClosedDTO: Decodable {
    let changed: Bool
    let incident: SOSSummaryDTO
}

struct SOSAssistanceResultDTO: Decodable {
    let created: Bool
    let sosId: String
    let revision: Int
    // The write response omits name/avatar. Optional decoding preserves that distinction.
    let response: SOSResponderDTO
}
