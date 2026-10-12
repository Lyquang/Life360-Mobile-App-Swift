import Foundation

private struct CheckFailure: Error { let message: String }

private func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw CheckFailure(message: message) }
}

private final class TokenStub: AccessTokenProvider {
    var accessToken: String? = "keychain-token"
    var invalidated: [String] = []
    func invalidate(token: String) {
        invalidated.append(token)
        if accessToken == token { accessToken = nil }
    }
}

private final class ProtocolStub: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            guard let handler = Self.handler else { throw CheckFailure(message: "Missing handler") }
            let (status, data) = try handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

private actor RefreshStub: AccessTokenRefreshing {
    private(set) var calls = 0
    func refreshAccessToken() async throws -> String {
        calls += 1
        try await Task.sleep(nanoseconds: 50_000_000)
        return "refreshed-token"
    }
}

private final class RefreshingTokenStub: AccessTokenProvider, AccessTokenRefreshing {
    var accessToken: String? = "expired"
    var invalidated: [String] = []
    var refreshCalls = 0
    func invalidate(token: String) { invalidated.append(token); if accessToken == token { accessToken = nil } }
    func refreshAccessToken() async throws -> String {
        refreshCalls += 1; accessToken = "fresh"; return "fresh"
    }
}

@main
enum NetworkingContractTests {
    static func main() async throws {
        try documentedResponses()
        try requests()
        try mediaContracts()
        try redaction()
        try check(AppEnvironment.current.apiBaseURL.absoluteString == "https://life360-backend-6v9n.onrender.com/api/v1", "Deployed REST host")
        try check(AppEnvironment.current.socketURL.absoluteString == "https://life360-backend-6v9n.onrender.com", "Deployed Socket.IO host")
        try await transport()
        try await mediaTransport()
        try await singleFlightRefresh()
        print("PASS: REST contracts, auth refresh, media ticket/PUT retry, decoding and errors")
    }

    static func mediaContracts() throws {
        try check(MediaUploadPolicy.mimeType(for: .image) == "image/jpeg", "Image MIME")
        try check(MediaUploadPolicy.fileExtension(for: .image) == "jpg", "Image extension")
        try check(MediaUploadPolicy.mimeType(for: .voice) == "audio/mp4", "Voice MIME")
        try check(MediaUploadPolicy.fileExtension(for: .voice) == "m4a", "Voice extension")
        try check(MediaUploadPolicy.maxImageBytes == 10 * 1024 * 1024, "Image limit")
        try check(MediaUploadPolicy.maxVoiceBytes == 25 * 1024 * 1024, "Voice limit")
        try check(MediaUploadPolicy.maxVoiceDuration == 900, "Voice duration")

        let endpoint = ChatEndpoint.mediaTicket(conversationId: "conversation", kind: .voice, fileSize: 123456)
        try check(endpoint.path == "/chat/media/presigned-url", "Media ticket path")
        let body = try JSONSerialization.jsonObject(with: endpoint.encodedBody()!) as! [String: Any]
        try check(body["mimeType"] as? String == "audio/mp4" && body["extension"] as? String == "m4a", "Voice ticket body")
        try check(body["fileSize"] as? Int == 123456, "Compressed file size")

        let decoder = BackendJSONCoding.makeDecoder()
        let image = try decoder.decode(ChatMessageDTO.self, from: Data(#"{"id":"i","conversationId":"c","senderId":"u","type":"image","content":"Hi","attachment":{"url":"https://cdn.test/i.jpg","mimeType":"image/jpeg","size":42,"width":1170,"height":2532,"blurhash":"LEHV6nWB2yk8pyo0adR*.7kCMdnj"},"createdAt":"2026-10-12T08:16:00.123Z"}"#.utf8))
        try check(image.attachment?.blurhash?.count == 28 && image.createdAt.timeIntervalSince1970 > 0, "Image and millisecond date decode")
        let voice = try decoder.decode(ChatMessageDTO.self, from: Data(#"{"id":"v","conversationId":"c","senderId":"u","type":"voice","content":"","attachment":null,"mediaUrl":"https://cdn.test/v.m4a","duration":12.4,"fileSize":123456,"mimeType":"audio/mp4","createdAt":"2026-10-12T08:16:00.000Z"}"#.utf8))
        try check(voice.attachment == nil && voice.mediaUrl?.hasSuffix(".m4a") == true && voice.duration == 12.4, "Voice decode")
    }

    static func singleFlightRefresh() async throws {
        let coordinator = TokenRefreshCoordinator()
        let refresher = RefreshStub()
        async let first = coordinator.refresh(using: refresher)
        async let second = coordinator.refresh(using: refresher)
        let values = try await [first, second]
        try check(values == ["refreshed-token", "refreshed-token"], "Refresh result")
        let calls = await refresher.calls
        try check(calls == 1, "Refresh was not single-flight")
    }

    static func mediaTransport() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ProtocolStub.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel(); ProtocolStub.handler = nil }
        let token = RefreshingTokenStub()
        let client = URLSessionAPIClient(baseURL: URL(string: "https://api.test/api/v1")!, session: session,
                                         tokenProvider: token, logger: NoopNetworkLogger(), tokenRefresher: token)
        let service = MediaUploadService(api: client, session: session)
        var ticketCalls = 0, putCalls = 0
        ProtocolStub.handler = { request in
            if request.url?.host == "api.test" {
                if request.value(forHTTPHeaderField: "Authorization") == "Bearer expired" {
                    return (401, Data(#"{"success":false,"code":"UNAUTHORIZED"}"#.utf8))
                }
                ticketCalls += 1
                let index = ticketCalls
                let json = #"{"success":true,"data":{"uploadUrl":"https://r2.test/upload?X-Amz-Signature=secret"#
                    + String(index) + #"","method":"PUT","headers":{"Content-Type":"image/jpeg","Content-Length":"4"},"key":"key"#
                    + String(index) + #"","publicUrl":"https://cdn.test/file"# + String(index)
                    + #".jpg","expiresIn":300,"expiresAt":"2099-10-12T08:15:00.000Z"}}"#
                return (201, Data(json.utf8))
            }
            putCalls += 1
            try check(request.httpMethod == "PUT", "R2 method")
            try check(request.value(forHTTPHeaderField: "Authorization") == nil, "Bearer leaked to R2")
            try check(request.value(forHTTPHeaderField: "Content-Type") == "image/jpeg", "Signed MIME changed")
            return (putCalls == 1 ? 403 : 204, Data())
        }
        let ticket = try await service.uploadWithFreshTicket(Data([1, 2, 3, 4]), conversationId: "c", kind: .image)
        try check(token.refreshCalls == 1 && token.accessToken == "fresh", "Ticket 401 refresh retry")
        try check(ticketCalls == 2 && putCalls == 2, "PUT 403 did not obtain a fresh ticket")
        try check(ticket.publicURL.absoluteString == "https://cdn.test/file2.jpg", "Retry reused stale public URL")
    }

    static func documentedResponses() throws {
        let document = try String(contentsOfFile: "study/API_INTERGRATION.MD", encoding: .utf8)
        let rest = String(document.components(separatedBy: "## 9. Socket.io")[0])
        let regex = try NSRegularExpression(pattern: "```json\\s*([\\s\\S]*?)\\s*```")
        var count = 0
        for match in regex.matches(in: rest, range: NSRange(rest.startIndex..., in: rest)) {
            let range = Range(match.range(at: 1), in: rest)!
            let data = Data(rest[range].utf8)
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard object?["success"] as? Bool == true else { continue }
            let prefix = rest[..<range.lowerBound]
            let heading = prefix.components(separatedBy: "\n").last(where: { $0.hasPrefix("### ") }) ?? ""
            let decoder = BackendJSONCoding.makeDecoder()
            func decode<T: Codable>(_ type: T.Type) throws {
                let result = try decoder.decode(type, from: data)
                _ = try decoder.decode(type, from: BackendJSONCoding.makeEncoder().encode(result))
            }
            switch heading {
            case "### Register", "### Login", "### Social Login - Google": try decode(APIResponse<AuthDataDTO>.self)
            case "### Get Me": try decode(APIResponse<UserDTO>.self)
            case "### Create Circle", "### Join Circle By Invite Code": try decode(APIResponse<GroupDTO>.self)
            case "### List My Circles": try decode(APIResponse<[GroupDTO]>.self)
            case "### Circle Members": try decode(APIResponse<GroupMembersDTO>.self)
            case "### Update Digest Notification Interval": try decode(APIResponse<NotificationIntervalDTO>.self)
            case "### Add Favorite Place": try decode(APIResponse<PlaceDTO>.self)
            case "### List Favorite Places": try decode(APIResponse<[PlaceDTO]>.self)
            case "### List Circle Digests": try decode(DigestPageDTO.self)
            case "### Latest Circle Digest": try decode(LatestDigestDTO.self)
            case "### List Conversations": try decode(APIResponse<[ConversationDTO]>.self)
            case "### Get Conversation Detail", "### Open Direct 1-1 Conversation", "### Update Group Conversation Metadata":
                try decode(APIResponse<ConversationDTO>.self)
            case "### List Messages": try decode(MessagePageDTO.self)
            case "### Send Message Via REST": try decode(APIResponse<ChatMessageDTO>.self)
            case "### Mark Conversation As Read": try decode(APIResponse<MarkReadDTO>.self)
            case "### Get Conversation Unread Count": try decode(APIResponse<ConversationUnreadDTO>.self)
            case "### Unread Summary": try decode(APIResponse<UnreadSummaryDTO>.self)
            case "### Create Upload Ticket For Chat Image": try decode(APIResponse<UploadTicketDTO>.self)
            case "### Today Location Points": try decode(LocationHistoryDTO.self)
            case "### Day Journey":
                let journey = try decoder.decode(DayJourneyResponseDTO.self, from: data)
                try check(journey.summary?.movingSegmentCount == 3, "Journey moving count")
                try check(journey.journey?.last?.points?.count == 1, "Journey points")
                try decode(DayJourneyResponseDTO.self)
            default: continue // Generic envelope examples in the overview.
            }
            count += 1
        }
        try check(count == 26, "Expected 26 REST response examples, decoded \(count)")
        print("Decoded and round-tripped \(count) documented REST examples")
    }

    static func redaction() throws {
        var request = URLRequest(url: URL(string: "https://user:password@example.test/api?token=jwt&X-Amz-Signature=signature&limit=30#secret")!)
        request.setValue("Bearer secret", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(#"{"password":"secret","nested":{"accessToken":"jwt","email":"alice@example.test","latitude":10.77},"data":[{"content":"private chat","unreadCount":3}]}"#.utf8)
        let safe = DiagnosticRedactor.request(request)
        try check(safe.url?.user == nil && safe.url?.password == nil && safe.url?.fragment == nil, "URL credentials")
        try check(!(safe.url!.absoluteString.contains("jwt")) && !(safe.url!.absoluteString.contains("=signature")), "Query credentials")
        try check(safe.value(forHTTPHeaderField: "Authorization") == "[REDACTED]", "Authorization redaction")
        try check(safe.value(forHTTPHeaderField: "Content-Type") == "application/json", "Content type retained")
        let json = String(data: safe.httpBody!, encoding: .utf8)!
        for value in ["secret", "jwt", "alice@example.test", "10.77", "private chat"] {
            try check(!json.contains(value), "Sensitive body value survived")
        }
        try check(json.contains("unreadCount"), "Useful payload structure retained")
        try check(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret", "Redaction changed actual request")
        let html = DiagnosticRedactor.body(Data("<html>secret</html>".utf8))!
        try check(!String(data: html, encoding: .utf8)!.contains("secret"), "Unstructured body leakage")
        let large = DiagnosticRedactor.body(Data(repeating: 65, count: 256_001))!
        try check(large.count < 100, "Oversized body retained")
    }

    static func requests() throws {
        func body(_ endpoint: Endpoint) throws -> [String: Any] {
            try JSONSerialization.jsonObject(with: endpoint.encodedBody()!) as! [String: Any]
        }
        let join = try body(GroupEndpoint.join(inviteCode: "001234"))
        try check(join["inviteCode"] as? String == "001234", "Leading zero invite code")
        let social = try body(AuthEndpoint.googleLogin(idToken: "google-id-token"))
        try check(social["token"] as? String == "google-id-token" && social["provider"] as? String == "google", "Social payload")
        let clear = try body(ChatEndpoint.update(conversationId: "c", request: .init(avatar: .clear)))
        try check(clear["avatarUrl"] is NSNull, "Explicit null avatar")
        let unchanged = try body(ChatEndpoint.update(conversationId: "c", request: .init(name: "Family")))
        try check(unchanged["avatarUrl"] == nil, "Omitted avatar")
        let read = try body(ChatEndpoint.markRead(conversationId: "c", messageId: nil))
        try check(read.isEmpty, "Read latest must omit messageId")
        let firstPage = ChatEndpoint.messages(conversationId: "c", before: nil)
        try check(firstPage.query.map(\.name) == ["limit"], "Initial page omits cursor")
        let older = ChatEndpoint.messages(conversationId: "c", before: "oldest-id")
        try check(older.query.last?.value == "oldest-id", "Message ID cursor")
        let placeForbidden = APIError.http(
            status: 403,
            code: "FORBIDDEN",
            message: "Server-specific text",
            errors: []
        ).domainError
        try check(placeForbidden == .forbidden, "Non-chat 403 must remain typed as forbidden")
        try check(
            placeForbidden.localizedDescription == "Bạn không có quyền truy cập dữ liệu này.",
            "Non-chat 403 changed its user-facing message"
        )
        let digest = DigestEndpoint.list(groupId: "g", from: "2026-10-01T00:00:00+07:00", to: "2026-10-02T00:00:00Z")
        try check(digest.query.map(\.name) == ["page", "limit", "from", "to"], "Digest query")
        try check(HistoryEndpoint.today(userId: "u").query.isEmpty, "No undocumented history date")
        let endpoints: [(Endpoint, String, HTTPMethod)] = [
            (AuthEndpoint.login(email: "e", password: "p"), "/auth/login", .POST),
            (AuthEndpoint.register(name: "n", email: "e", password: "p"), "/auth/register", .POST),
            (AuthEndpoint.googleLogin(idToken: "t"), "/auth/social-login", .POST),
            (AuthEndpoint.me, "/auth/me", .GET),
            (GroupEndpoint.list, "/groups", .GET),
            (GroupEndpoint.create(name: "n"), "/groups", .POST),
            (GroupEndpoint.join(inviteCode: "123456"), "/groups/join", .POST),
            (GroupEndpoint.members(groupId: "g"), "/groups/g/members", .GET),
            (GroupEndpoint.updateInterval(groupId: "g", minutes: 0), "/groups/g/notification-interval", .PATCH),
            (PlaceEndpoint.list(groupId: "g"), "/groups/g/places", .GET),
            (PlaceEndpoint.add(groupId: "g", name: "n", category: "cafe", latitude: 10, longitude: 106), "/groups/g/places", .POST),
            (DigestEndpoint.list(groupId: "g"), "/groups/g/digests", .GET),
            (DigestEndpoint.latest(groupId: "g"), "/groups/g/digests/latest", .GET),
            (ChatEndpoint.conversations, "/conversations", .GET),
            (ChatEndpoint.detail(conversationId: "c"), "/conversations/c", .GET),
            (ChatEndpoint.openDirect(userId: "u"), "/conversations/direct", .POST),
            (ChatEndpoint.update(conversationId: "c", request: .init(name: "n")), "/conversations/c", .PATCH),
            (firstPage, "/conversations/c/messages", .GET),
            (ChatEndpoint.send(conversationId: "c", request: .init(type: "text", content: "Hi")), "/conversations/c/messages", .POST),
            (ChatEndpoint.markRead(conversationId: "c", messageId: nil), "/conversations/c/read", .POST),
            (ChatEndpoint.unread(conversationId: "c"), "/conversations/c/unread", .GET),
            (ChatEndpoint.unreadSummary, "/conversations/unread-summary", .GET),
            (ChatEndpoint.mediaTicket(conversationId: "c", kind: .image, fileSize: 42), "/chat/media/presigned-url", .POST),
            (HistoryEndpoint.today(userId: "u"), "/history/u", .GET),
            (HistoryEndpoint.journey(userId: "u", date: "2026-10-01"), "/history/u/journey", .GET),
            (HealthEndpoint.check, "/health", .GET)
        ]
        for (endpoint, path, method) in endpoints {
            try check(endpoint.path == path && endpoint.method == method, "Endpoint \(path)")
            let isPublic = ["/auth/login", "/auth/register", "/auth/social-login", "/health"].contains(path)
            try check(endpoint.requiresAuth != isPublic, "Auth policy \(path)")
            try check(endpoint.headers["Accept"] == "application/json", "Accept header")
            _ = try endpoint.encodedBody()
        }
        do {
            _ = try Endpoint(path: "/test", body: ["invalid": Double.nan]).encodedBody()
            throw CheckFailure(message: "Invalid body was silently encoded")
        } catch APIError.encodingError { }
    }

    static func transport() async throws {
        let token = TokenStub()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ProtocolStub.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel(); ProtocolStub.handler = nil }
        let client = URLSessionAPIClient(baseURL: URL(string: "https://example.test/api/v1")!, session: session,
                                         tokenProvider: token, logger: NoopNetworkLogger())
        let ok = Data(#"{"success":true,"data":{"id":"u","name":"Alice"}}"#.utf8)
        ProtocolStub.handler = { request in
            try check(request.url?.path == "/api/v1/auth/me", "Versioned base path")
            try check(request.value(forHTTPHeaderField: "Authorization") == "Bearer keychain-token", "Bearer interceptor")
            try check(request.value(forHTTPHeaderField: "Accept") == "application/json", "Accept")
            return (200, ok)
        }
        _ = try await client.send(AuthEndpoint.me, as: APIResponse<UserDTO>.self)
        ProtocolStub.handler = { request in
            try check(request.value(forHTTPHeaderField: "Authorization") == nil, "Public endpoint leaked token")
            return (401, Data(#"{"success":false,"code":"UNAUTHORIZED","message":"Bad login"}"#.utf8))
        }
        do {
            _ = try await client.send(AuthEndpoint.googleLogin(idToken: "invalid"), as: APIResponse<UserDTO>.self)
            throw CheckFailure(message: "Login 401 accepted")
        } catch APIError.http(let status, _, _, _) { try check(status == 401, "Login error status") }
        try check(token.accessToken != nil && token.invalidated.isEmpty, "Login failure invalidated existing session")
        for status in [400, 403, 404, 409, 429, 503] {
            ProtocolStub.handler = { _ in (status, Data(#"{"success":false,"code":"VALIDATION_ERROR","errors":[{"field":"body.email","message":"Invalid email"}]}"#.utf8)) }
            do {
                _ = try await client.send(AuthEndpoint.me, as: APIResponse<UserDTO>.self)
                throw CheckFailure(message: "HTTP error accepted")
            } catch APIError.http(let actual, let code, _, let errors) {
                try check(actual == status && code == "VALIDATION_ERROR" && errors.first?.field == "body.email", "Structured error lost")
            }
        }
        ProtocolStub.handler = { _ in (500, ok) }
        do {
            _ = try await client.send(AuthEndpoint.me, as: APIResponse<UserDTO>.self)
            throw CheckFailure(message: "Non-2xx success-shaped body accepted")
        } catch APIError.http { }
        ProtocolStub.handler = { _ in (200, Data(#"{"success":false,"message":"Rejected"}"#.utf8)) }
        do {
            _ = try await client.send(AuthEndpoint.me, as: APIResponse<UserDTO>.self)
            throw CheckFailure(message: "Failed envelope accepted")
        } catch APIError.http { }
        ProtocolStub.handler = { _ in (503, Data("<html>Unavailable</html>".utf8)) }
        do {
            _ = try await client.send(AuthEndpoint.me, as: APIResponse<UserDTO>.self)
            throw CheckFailure(message: "HTML error accepted")
        } catch APIError.http(let status, _, _, _) { try check(status == 503, "HTML status") }
        ProtocolStub.handler = { _ in (200, Data("invalid-json".utf8)) }
        do {
            _ = try await client.send(AuthEndpoint.me, as: APIResponse<UserDTO>.self)
            throw CheckFailure(message: "Malformed success accepted")
        } catch APIError.decodingError { }
        ProtocolStub.handler = { _ in throw URLError(.cancelled) }
        do {
            _ = try await client.send(AuthEndpoint.me, as: APIResponse<UserDTO>.self)
            throw CheckFailure(message: "Cancellation ignored")
        } catch is CancellationError { }
        ProtocolStub.handler = { _ in throw URLError(.notConnectedToInternet) }
        do {
            _ = try await withDomainErrors { try await client.send(AuthEndpoint.me, as: APIResponse<UserDTO>.self) }
            throw CheckFailure(message: "Offline ignored")
        } catch DomainError.network { }
        ProtocolStub.handler = { _ in
            token.accessToken = "new-login-token"
            return (401, Data(#"{"success":false}"#.utf8))
        }
        do {
            _ = try await client.send(AuthEndpoint.me, as: APIResponse<UserDTO>.self)
            throw CheckFailure(message: "Expired auth accepted")
        } catch APIError.unauthorized { }
        try check(token.accessToken == "new-login-token" && token.invalidated == ["keychain-token"], "New login invalidated")
        ProtocolStub.handler = { _ in (200, Data(#"{"success":false,"code":"UNAUTHORIZED"}"#.utf8)) }
        do {
            _ = try await client.send(AuthEndpoint.me, as: APIResponse<UserDTO>.self)
            throw CheckFailure(message: "Unauthorized envelope accepted")
        } catch APIError.unauthorized { }
        try check(token.accessToken == nil, "Unauthorized code did not clear sent token")
        ProtocolStub.handler = { _ in throw CheckFailure(message: "Missing token reached network") }
        do {
            _ = try await client.send(AuthEndpoint.me, as: APIResponse<UserDTO>.self)
            throw CheckFailure(message: "Missing token accepted")
        } catch APIError.unauthorized { }
    }
}
