import Foundation

enum AuthEndpoint {
    static func login(email: String, password: String) -> Endpoint {
        Endpoint(path: "/auth/login", method: .POST, requiresAuth: false,
                 payload: LoginRequestDTO(email: email, password: password))
    }

    static func register(name: String, email: String, password: String) -> Endpoint {
        Endpoint(path: "/auth/register", method: .POST,
                 requiresAuth: false, payload: RegisterRequestDTO(name: name, email: email, password: password))
    }

    static func googleLogin(idToken: String) -> Endpoint {
        Endpoint(path: "/auth/social-login", method: .POST, requiresAuth: false,
                 payload: SocialLoginRequestDTO(provider: "google", token: idToken))
    }

    static let me = Endpoint(path: "/auth/me")
}

enum GroupEndpoint {
    static let list = Endpoint(path: "/groups")

    static func create(name: String) -> Endpoint {
        Endpoint(path: "/groups", method: .POST, payload: CreateGroupRequestDTO(name: name))
    }

    static func join(inviteCode: String) -> Endpoint {
        Endpoint(path: "/groups/join", method: .POST, payload: JoinGroupRequestDTO(inviteCode: inviteCode))
    }

    static func members(groupId: String) -> Endpoint {
        Endpoint(path: "/groups/\(groupId)/members")
    }

    static func updateInterval(groupId: String, minutes: Int) -> Endpoint {
        Endpoint(path: "/groups/\(groupId)/notification-interval", method: .PATCH,
                 payload: NotificationIntervalRequestDTO(intervalMinutes: minutes))
    }
}

enum PlaceEndpoint {
    static func list(groupId: String) -> Endpoint {
        Endpoint(path: "/groups/\(groupId)/places")
    }

    static func add(groupId: String, name: String, category: String, latitude: Double, longitude: Double) -> Endpoint {
        Endpoint(path: "/groups/\(groupId)/places", method: .POST,
                 payload: CreatePlaceRequestDTO(name: name, category: category, latitude: latitude, longitude: longitude))
    }
}

enum HistoryEndpoint {
    static func today(userId: String) -> Endpoint {
        Endpoint(path: "/history/\(userId)")
    }

    static func journey(userId: String, date: String?) -> Endpoint {
        Endpoint(path: "/history/\(userId)/journey", query: date.map { [URLQueryItem(name: "date", value: $0)] } ?? [])
    }
}

enum ChatEndpoint {
    static let conversations = Endpoint(path: "/conversations")
    static let unreadSummary = Endpoint(path: "/conversations/unread-summary")

    static func detail(conversationId: String) -> Endpoint {
        Endpoint(path: "/conversations/\(conversationId)")
    }

    static func unread(conversationId: String) -> Endpoint {
        Endpoint(path: "/conversations/\(conversationId)/unread")
    }

    static func update(conversationId: String, request: UpdateConversationRequestDTO) -> Endpoint {
        Endpoint(path: "/conversations/\(conversationId)", method: .PATCH, payload: request)
    }

    static func messages(conversationId: String, limit: Int = 30, before: String?) -> Endpoint {
        var query = [URLQueryItem(name: "limit", value: String(limit))]
        if let before { query.append(URLQueryItem(name: "before", value: before)) }
        return Endpoint(path: "/conversations/\(conversationId)/messages", query: query)
    }

    static func send(conversationId: String, body: [String: Any]) -> Endpoint {
        Endpoint(path: "/conversations/\(conversationId)/messages", method: .POST, body: body)
    }

    static func send(conversationId: String, request: SendMessageRequestDTO) -> Endpoint {
        Endpoint(path: "/conversations/\(conversationId)/messages", method: .POST, payload: request)
    }

    static func markRead(conversationId: String, messageId: String?) -> Endpoint {
        Endpoint(path: "/conversations/\(conversationId)/read", method: .POST,
                 payload: MarkReadRequestDTO(messageId: messageId))
    }

    static func openDirect(userId: String) -> Endpoint {
        Endpoint(path: "/conversations/direct", method: .POST, payload: DirectConversationRequestDTO(userId: userId))
    }

    static func uploadTicket(conversationId: String, contentType: String, contentLength: Int) -> Endpoint {
        Endpoint(path: "/chat/upload-ticket", method: .POST,
                 payload: UploadTicketRequestDTO(conversationId: conversationId, contentType: contentType, contentLength: contentLength))
    }
}

enum DigestEndpoint {
    static func list(groupId: String, page: Int = 1, limit: Int = 20, from: String? = nil, to: String? = nil) -> Endpoint {
        var query = [URLQueryItem(name: "page", value: String(page)), URLQueryItem(name: "limit", value: String(limit))]
        if let from { query.append(URLQueryItem(name: "from", value: from)) }
        if let to { query.append(URLQueryItem(name: "to", value: to)) }
        return Endpoint(path: "/groups/\(groupId)/digests", query: query)
    }

    static func latest(groupId: String) -> Endpoint {
        Endpoint(path: "/groups/\(groupId)/digests/latest")
    }
}

enum HealthEndpoint {
    static let check = Endpoint(path: "/health", requiresAuth: false)
}
