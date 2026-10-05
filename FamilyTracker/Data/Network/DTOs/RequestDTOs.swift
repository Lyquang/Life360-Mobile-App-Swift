import Foundation

struct LoginRequestDTO: Codable, Sendable {
    let email: String
    let password: String
}

struct RegisterRequestDTO: Codable, Sendable {
    let name: String
    let email: String
    let password: String
}

struct SocialLoginRequestDTO: Codable, Sendable {
    let provider: String
    let token: String
}

struct CreateGroupRequestDTO: Codable, Sendable { let name: String }
struct JoinGroupRequestDTO: Codable, Sendable { let inviteCode: String }
struct NotificationIntervalRequestDTO: Codable, Sendable { let intervalMinutes: Int }
struct DirectConversationRequestDTO: Codable, Sendable { let userId: String }
struct MarkReadRequestDTO: Codable, Sendable { let messageId: String? }

struct CreatePlaceRequestDTO: Codable, Sendable {
    let name: String
    let category: String
    let latitude: Double
    let longitude: Double
}

struct UploadTicketRequestDTO: Codable, Sendable {
    let conversationId: String
    let contentType: String
    let contentLength: Int
}

struct ImageMetadataDTO: Codable, Sendable {
    let width: Int
    let height: Int
    let blurhash: String
    let mimeType: String?
    let size: Int?
}

struct SendMessageRequestDTO: Codable, Sendable {
    let type: String
    let content: String?
    let attachmentUrl: String?
    let metadata: ImageMetadataDTO?
}

/// PATCH needs three states: omitted, explicitly cleared, or replaced.
struct UpdateConversationRequestDTO: Codable, Sendable {
    enum Avatar: Equatable, Sendable {
        case unchanged
        case clear
        case url(String)
    }

    let name: String?
    let avatar: Avatar

    init(name: String? = nil, avatar: Avatar = .unchanged) {
        self.name = name
        self.avatar = avatar
    }

    private enum CodingKeys: String, CodingKey { case name, avatarUrl }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decodeIfPresent(String.self, forKey: .name)
        if !values.contains(.avatarUrl) { avatar = .unchanged }
        else if try values.decodeNil(forKey: .avatarUrl) { avatar = .clear }
        else { avatar = .url(try values.decode(String.self, forKey: .avatarUrl)) }
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encodeIfPresent(name, forKey: .name)
        switch avatar {
        case .unchanged: break
        case .clear: try values.encodeNil(forKey: .avatarUrl)
        case .url(let url): try values.encode(url, forKey: .avatarUrl)
        }
    }
}
