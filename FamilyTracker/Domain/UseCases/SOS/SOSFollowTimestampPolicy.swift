import Foundation

/// Reject unparseable or older fixes before moving the SOS marker and camera.
enum SOSFollowTimestampPolicy {
    static func accepts(_ timestamp: String, after previous: Date?) -> Date? {
        guard let date = ISO8601.date(from: timestamp), previous.map({ date >= $0 }) ?? true else { return nil }
        return date
    }
}
