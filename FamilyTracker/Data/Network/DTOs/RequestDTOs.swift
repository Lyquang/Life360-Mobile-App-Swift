import Foundation

struct LoginRequestDTO: Codable, Sendable {
    let email: String
    let password: String
    let deviceName: String
}

struct RegisterRequestDTO: Codable, Sendable {
    let name: String
    let email: String
    let password: String
    let deviceName: String
}

struct SocialLoginRequestDTO: Codable, Sendable {
    let provider: String
    let token: String
    let deviceName: String
}

struct RefreshTokenRequestDTO: Codable, Sendable { let refreshToken: String }
struct LogoutRequestDTO: Codable, Sendable { let refreshToken: String }
struct ChangePasswordRequestDTO: Codable, Sendable {
    let currentPassword: String
    let newPassword: String
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

struct PresignedMediaRequestDTO: Codable, Sendable {
    let conversationId: String
    let mediaType: MediaKind
    let fileExtension: String
    let mimeType: String
    let fileSize: Int

    enum CodingKeys: String, CodingKey {
        case conversationId, mediaType, mimeType, fileSize
        case fileExtension = "extension"
    }
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
    let mediaUrl: String?
    let duration: Double?
    let fileSize: Int?
    let mimeType: String?

    init(type: String, content: String? = nil, attachmentUrl: String? = nil,
         metadata: ImageMetadataDTO? = nil, mediaUrl: String? = nil,
         duration: Double? = nil, fileSize: Int? = nil, mimeType: String? = nil) {
        self.type = type
        self.content = content
        self.attachmentUrl = attachmentUrl
        self.metadata = metadata
        self.mediaUrl = mediaUrl
        self.duration = duration
        self.fileSize = fileSize
        self.mimeType = mimeType
    }
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
