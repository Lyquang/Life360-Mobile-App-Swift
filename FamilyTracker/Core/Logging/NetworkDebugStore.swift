import Foundation
import Combine

#if DEBUG
struct NetworkDebugEntry: Identifiable {
    enum Kind {
        case request
        case response
        case error
        case socket
    }

    let id = UUID()
    let createdAt = Date()
    let kind: Kind
    let title: String
    let detail: String
    let statusCode: Int?
    let duration: TimeInterval?
}

@MainActor
final class NetworkDebugStore: ObservableObject {
    static let shared = NetworkDebugStore()

    @Published private(set) var entries: [NetworkDebugEntry] = []
    private let maxEntries = 200

    private init() {}

    func recordRequest(method: String, url: String, body: String?) -> UUID {
        let id = UUID()
        let detail = [
            body.map { "Body:\n\($0)" },
            nil
        ].compactMap { $0 }.joined(separator: "\n\n")

        append(NetworkDebugEntry(
            kind: .request,
            title: "\(method) \(url)",
            detail: detail,
            statusCode: nil,
            duration: nil
        ))
        return id
    }

    func recordResponse(
        requestId: UUID,
        method: String,
        url: String,
        statusCode: Int,
        body: String,
        duration: TimeInterval
    ) {
        append(NetworkDebugEntry(
            kind: .response,
            title: "\(statusCode) \(method) \(url)",
            detail: "Duration: \(Self.formatDuration(duration))\n\nResponse:\n\(body)",
            statusCode: statusCode,
            duration: duration
        ))
    }

    func recordError(
        requestId: UUID,
        method: String,
        url: String,
        message: String,
        duration: TimeInterval
    ) {
        append(NetworkDebugEntry(
            kind: .error,
            title: "ERROR \(method) \(url)",
            detail: "Duration: \(Self.formatDuration(duration))\n\n\(message)",
            statusCode: nil,
            duration: duration
        ))
    }

    func recordSocket(event: String, payload: Any) {
        append(NetworkDebugEntry(
            kind: .socket,
            title: "Socket: \(event)",
            detail: Self.prettyJSON(payload),
            statusCode: nil,
            duration: nil
        ))
    }

    func clear() {
        entries.removeAll()
    }

    nonisolated static func prettyJSON(_ value: Any) -> String {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return String(describing: value)
        }
        return string
    }

    nonisolated static func sanitizedBody(_ body: [String: Any]) -> String {
        var safeBody = body
        ["password", "token", "accessToken", "refreshToken"].forEach { key in
            if safeBody[key] != nil {
                safeBody[key] = "<redacted>"
            }
        }
        return prettyJSON(safeBody)
    }

    private func append(_ entry: NetworkDebugEntry) {
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries.removeLast(entries.count - maxEntries)
        }
    }

    private static func formatDuration(_ duration: TimeInterval) -> String {
        String(format: "%.0f ms", duration * 1000)
    }
}
#endif
