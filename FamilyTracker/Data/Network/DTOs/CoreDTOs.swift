import Foundation

struct APIResponseDTO<T: Decodable>: Decodable {
    let success: Bool
    let message: String?
    let data: T?
    let count: Int?
    let code: String?
    let errors: [APIFieldErrorDTO]?

    func unwrap(fallbackMessage: String) throws -> T {
        guard success else {
            throw APIError.http(status: 200, code: code, message: message ?? fallbackMessage, errors: errors ?? [])
        }
        guard let data else { throw APIError.decodingError(fallbackMessage) }
        return data
    }
}

extension APIResponseDTO: Encodable where T: Encodable {}
extension APIResponseDTO: Sendable where T: Sendable {}
typealias APIResponse<T: Codable> = APIResponseDTO<T>

struct APIFieldErrorDTO: Codable, Equatable, Sendable {
    let field: String?
    let message: String
}

struct APIErrorResponseDTO: Codable, Sendable {
    let success: Bool?
    let code: String?
    let message: String?
    let errors: [APIFieldErrorDTO]?
}

struct UserDTO: Codable, Sendable {
    let id: String
    let name: String
    let email: String?
    let avatar: String?
    let batteryLevel: Double?
    let isOnline: Bool?
    let lastSeenAt: String?
    let lastKnownLocation: LastKnownLocationDTO?
    let createdAt: String?
    let updatedAt: String?
}

/// Populated relation or bare ObjectId string, depending on the endpoint.
enum UserOrIdDTO: Codable, Sendable {
    case user(UserDTO)
    case id(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let id = try? container.decode(String.self) { self = .id(id) }
        else { self = .user(try container.decode(UserDTO.self)) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .user(let user): try container.encode(user)
        case .id(let id): try container.encode(id)
        }
    }

    var user: UserDTO? {
        if case .user(let user) = self { return user }
        return nil
    }
}

struct AuthDataDTO: Codable, Sendable {
    let user: UserDTO
    let token: String?
    let accessToken: String?
    let refreshToken: String?
}

struct GroupDTO: Codable, Sendable {
    let id: String
    let name: String
    let inviteCode: String?
    let admin: UserOrIdDTO?
    let members: [UserOrIdDTO]?
    let conversationId: String?
    let notificationIntervalMinutes: Int?
    let lastDigestSentAt: String?
    let createdAt: String?
    let updatedAt: String?
}

struct GroupMembersDTO: Codable, Sendable {
    let groupId: String
    let groupName: String
    let inviteCode: String?
    let conversationId: String?
    let memberCount: Int?
    let members: [UserDTO]
}

struct PlaceDTO: Codable, Sendable {
    let id: String
    let groupId: String?
    let name: String
    let category: String
    let latitude: Double?
    let longitude: Double?
    let addedBy: UserOrIdDTO?
    let createdAt: String?
    let updatedAt: String?
    let location: LastKnownLocationDTO?
}

struct LastKnownLocationDTO: Codable, Sendable {
    let type: String?
    let coordinates: [Double]?
    let updatedAt: String?
    let durationMinutes: Int?

    var longitude: Double? { coordinates?.count == 2 ? coordinates?[0] : nil }
    var latitude: Double? { coordinates?.count == 2 ? coordinates?[1] : nil }
}

struct NotificationIntervalDTO: Codable, Sendable {
    let groupId: String
    let notificationIntervalMinutes: Int
}
