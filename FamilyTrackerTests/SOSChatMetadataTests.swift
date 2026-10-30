import Foundation
import XCTest
@testable import FamilyTracker

final class SOSChatMetadataTests: XCTestCase {
    func testHistoryAndRealtimeRetainSOSMetadata() throws {
        let sosID = "000000000000000000000001"
        let payload: [String: Any] = ["id": "message-a", "conversationId": "circle-a", "senderId": "owner",
            "type": "text", "content": "Help", "createdAt": "2026-10-29T10:00:00.123Z",
            "eventId": "event-a", "sos": ["id": sosID, "kind": "alert"]]
        let socket = try XCTUnwrap(JSONPayload.decode(ChatMessageDTO.self, from: payload)).toDomain()
        XCTAssertEqual(socket.sos?.kind, .alert)
        XCTAssertEqual(socket.eventID, "event-a")
        let json = """
        {"success":true,"data":[{"id":"message-b","conversationId":"circle-b","senderId":"helper",
        "type":"text","content":"Coming","createdAt":"2026-10-29T10:01:00Z",
        "sos":{"id":"\(sosID)","kind":"assistance","responderId":"helper"}}]}
        """
        let page = try BackendJSONCoding.makeDecoder().decode(MessagePageDTO.self, from: Data(json.utf8))
        let message = try XCTUnwrap(page.data?.first).toDomain()
        XCTAssertEqual(message.sos?.id, sosID)
        XCTAssertEqual(message.sos?.kind, .assistance)
        XCTAssertEqual(message.sos?.responderId, "helper")
        XCTAssertNil(message.eventID)
    }

    func testBoundedMessageAndSessionEventDeduplication() {
        var ids = RecentChatIDs(capacity: 2)
        XCTAssertTrue(ids.insert("a"))
        XCTAssertTrue(ids.insert("b"))
        XCTAssertTrue(ids.insert("c"))
        XCTAssertFalse(ids.insert("b"))
        XCTAssertTrue(ids.insert("a"))
        var events = RecentChatEvents(capacity: 2)
        XCTAssertTrue(events.accept("event", generation: 1))
        XCTAssertFalse(events.accept("event", generation: 1))
        XCTAssertTrue(events.accept("event", generation: 2))
        XCTAssertTrue(events.accept(nil, generation: 2))
    }

    func testChatRepositoryDeduplicatesEventWithoutSendingAnotherMessage() async throws {
        let socket = SOSChatSocketStub()
        let session = SOSChatSessionStub()
        let repository = ChatRepositoryImpl(api: SOSChatAPIStub(), socket: socket,
                                            sessionGeneration: { session.generation })
        var iterator = repository.observeNewMessages().makeAsyncIterator()
        let sosID = "000000000000000000000001"
        let eventID = "000000000000000000000006"
        let first: [String: Any] = ["id": "message-a", "conversationId": "circle-a", "senderId": "owner",
            "type": "text", "content": "Help", "createdAt": "2026-10-29T10:00:00Z", "eventId": eventID,
            "sos": ["id": sosID, "kind": "alert"]]
        var second = first
        second["id"] = "message-b"
        second["conversationId"] = "circle-b"
        second["eventId"] = "000000000000000000000007"
        socket.deliver(first)
        socket.deliver(first)
        socket.deliver(second)
        let receivedFirst = await iterator.next()
        let receivedSecond = await iterator.next()
        XCTAssertEqual(receivedFirst?.id, "message-a")
        XCTAssertEqual(receivedSecond?.id, "message-b")
        XCTAssertEqual(receivedFirst?.sos?.id, receivedSecond?.sos?.id)
        XCTAssertEqual(socket.emittedCount, 0)

        session.generation += 1
        socket.deliver(first)
        let newSession = await iterator.next()
        XCTAssertEqual(newSession?.id, "message-a")
    }
}

private final class SOSChatSessionStub { var generation = 1 }

private final class SOSChatAPIStub: APIClient {
    func send<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T { throw APIError.unknown }
    func sendWithMetadata<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> APIResult<T> {
        throw APIError.unknown
    }
}

private final class SOSChatSocketStub: SocketClient {
    var status: SocketConnectionStatus = .connected
    private var handlers: [String: [([String: Any]) -> Void]] = [:]
    private(set) var emittedCount = 0
    func connect(token: String) {}
    func disconnect() {}
    func emit(_ event: String, _ payload: [String: Any]) { emittedCount += 1 }
    func emitWithAck(_ event: String, _ payload: [String: Any], timeout: TimeInterval) async throws -> [String: Any] {
        emittedCount += 1
        throw SocketClientError.disconnected
    }
    func on(_ event: String, handler: @escaping ([String: Any]) -> Void) { handlers[event, default: []].append(handler) }
    func onStatusChange(_ handler: @escaping (SocketConnectionStatus) -> Void) {}
    func deliver(_ payload: [String: Any]) { handlers[SocketEvent.chatNewMessage]?.forEach { $0(payload) } }
}
