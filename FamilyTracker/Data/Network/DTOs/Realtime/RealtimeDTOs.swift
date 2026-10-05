import Foundation

/// Socket payloads arrive as `[String: Any]`; decode them through JSONDecoder for type safety.
enum JSONPayload {
    static func decode<T: Decodable>(_ type: T.Type, from payload: [String: Any]) -> T? {
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

struct LocationUpdateDTO: Decodable {
    let userId: String
    let name: String
    let latitude: Double
    let longitude: Double
    let timestamp: String
    let batteryLevel: Double?
    let durationAtLocation: Double?
    let durationSince: String?
    let durationFormatted: String?
}

struct SOSAlertDTO: Decodable {
    let userId: String
    let name: String
    let message: String
    let latitude: Double?
    let longitude: Double?
    let groupId: String?
    let groupName: String?
    let timestamp: String
}

struct StayAlertDTO: Decodable {
    let userId: String
    let name: String
    let latitude: Double?
    let longitude: Double?
    let durationMinutes: Double
    let durationFormatted: String
    let durationSince: String?
    let groupId: String?
    let groupName: String?
    let message: String
    let timestamp: String
}

struct PresenceDTO: Decodable {
    let userId: String
    let isOnline: Bool?
}

struct TypingDTO: Decodable {
    let conversationId: String
    let userId: String
    let name: String?
    let isTyping: Bool
}
