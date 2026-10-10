import Foundation

enum NotificationKind: String, Codable { case conversation, sos, member }

struct NotificationPreferences: Codable, Equatable {
    var enabled = true
    var messages = true
    var sos = true
    func allows(_ kind: NotificationKind) -> Bool {
        enabled && (kind == .conversation ? messages : kind == .sos ? sos : true)
    }
}

enum NotificationPermission: Equatable { case notDetermined, denied, authorized, provisional }

struct NotificationDeduplicator {
    private var identifiers: [String] = []
    mutating func insert(_ identifier: String) -> Bool {
        guard !identifiers.contains(identifier) else { return false }
        identifiers.append(identifier)
        if identifiers.count > 256 { identifiers.removeFirst() }
        return true
    }
}
