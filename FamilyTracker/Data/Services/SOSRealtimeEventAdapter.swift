import Foundation

enum SOSRealtimeEventKind: Equatable, Sendable { case alert, updated }

struct SOSRealtimeEvent: Sendable, Equatable {
    let eventID: String
    let sosID: String
    let revision: Int
    let kind: SOSRealtimeEventKind
    fileprivate let sessionID: UUID
}

/// Registers once; the session gate keeps old or unauthenticated events out of recovery.
final class SOSRealtimeEventAdapter {
    private struct Envelope: Decodable {
        let eventId: String
        let sosId: String
        let revision: Int
    }

    private let events = AsyncBroadcaster<SOSRealtimeEvent>()
    private let lock = NSLock()
    private var active = false
    private var sessionID = UUID()
    private var seen: Set<String> = []
    private var order: [String] = []
    private static let capacity = 512

    init(socket: SocketClient) {
        socket.on(SocketEvent.sosAlertReceive) { [weak self] payload in
            self?.receive(payload, kind: .alert)
        }
        socket.on(SocketEvent.sosUpdated) { [weak self] payload in
            self?.receive(payload, kind: .updated)
        }
    }

    func observe() -> AsyncStream<SOSRealtimeEvent> { events.stream() }

    func startSession() {
        lock.lock(); defer { lock.unlock() }
        guard !active else { return }
        active = true
        sessionID = UUID()
        seen.removeAll()
        order.removeAll()
    }

    func stopSession() {
        lock.lock(); defer { lock.unlock() }
        active = false
        seen.removeAll()
        order.removeAll()
    }

    func isCurrent(_ event: SOSRealtimeEvent) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return active && event.sessionID == sessionID
    }

    private func receive(_ payload: [String: Any], kind: SOSRealtimeEventKind) {
        guard let dto = JSONPayload.decode(Envelope.self, from: payload),
              SOSEndpoint.isValidID(dto.eventId), SOSEndpoint.isValidID(dto.sosId), dto.revision > 0 else { return }
        let eventID = dto.eventId.lowercased()
        lock.lock()
        guard active, seen.insert(eventID).inserted else { lock.unlock(); return }
        order.append(eventID)
        if order.count > Self.capacity { seen.remove(order.removeFirst()) }
        let currentSession = sessionID
        lock.unlock()
        events.send(SOSRealtimeEvent(eventID: eventID, sosID: dto.sosId.lowercased(),
                                     revision: dto.revision, kind: kind, sessionID: currentSession))
    }
}
