import Foundation

private enum SOSChatCheckError: Error { case failed(String) }

private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw SOSChatCheckError.failed(message) }
}

enum SOSChatChecks {
    static func run() throws {
        let sosID = "000000000000000000000001"
        let eventID = "000000000000000000000006"
        let socketPayload: [String: Any] = [
            "id": "message-a", "conversationId": "circle-a", "senderId": "owner",
            "type": "text", "content": "Help", "createdAt": "2026-10-29T10:00:00.123Z",
            "eventId": eventID, "sos": ["id": sosID, "kind": "alert"]
        ]
        guard let dto = JSONPayload.decode(ChatMessageDTO.self, from: socketPayload) else {
            throw SOSChatCheckError.failed("SOS socket message decode")
        }
        let message = dto.toDomain()
        try require(message.type == .text && message.sos?.id == sosID && message.sos?.kind == .alert,
                    "SOS alert metadata")
        try require(message.sos?.responderId == nil && message.eventID == eventID, "SOS event ID")

        let history = """
        {"success":true,"hasMore":false,"data":[{"id":"message-b","conversationId":"circle-b",
        "senderId":"helper","type":"text","content":"Coming","createdAt":"2026-10-29T10:01:00Z",
        "sos":{"id":"\(sosID)","kind":"assistance","responderId":"helper"}}]}
        """
        let page = try BackendJSONCoding.makeDecoder().decode(MessagePageDTO.self, from: Data(history.utf8))
        guard let reply = page.data?.first?.toDomain() else { throw SOSChatCheckError.failed("SOS history decode") }
        try require(reply.sos?.kind == .assistance && reply.sos?.responderId == "helper" && reply.eventID == nil,
                    "SOS assistance metadata")
        try require(reply.sos?.id == message.sos?.id && reply.id != message.id, "Distinct Circle messages")

        var normalPayload = socketPayload
        normalPayload["sos"] = nil
        normalPayload["eventId"] = nil
        guard let normal = JSONPayload.decode(ChatMessageDTO.self, from: normalPayload)?.toDomain() else {
            throw SOSChatCheckError.failed("Ordinary message decode")
        }
        try require(normal.sos == nil && normal.eventID == nil, "Ordinary chat must remain compatible")
        normalPayload["sos"] = ["id": sosID, "kind": "future-kind"]
        let future = JSONPayload.decode(ChatMessageDTO.self, from: normalPayload)?.toDomain()
        try require(future?.sos?.kind == .unknown && future?.content == "Help", "Unknown SOS kind fallback")

        var ids = RecentChatIDs(capacity: 2)
        try require(ids.insert("one") && ids.insert("two"), "Initial messages dropped")
        try require(!ids.insert("one"), "Duplicate message accepted")
        try require(ids.insert("three") && !ids.insert("two"), "Eviction cleared a recent message")
        try require(ids.insert("one"), "Oldest message not evicted")
        var events = RecentChatEvents(capacity: 2)
        try require(events.accept(eventID, generation: 1), "Initial event dropped")
        try require(!events.accept(eventID, generation: 1), "Duplicate event accepted")
        try require(events.accept(nil, generation: 1), "Legacy event without ID dropped")
        try require(events.accept(eventID, generation: 2), "Account change retained event IDs")
    }
}
