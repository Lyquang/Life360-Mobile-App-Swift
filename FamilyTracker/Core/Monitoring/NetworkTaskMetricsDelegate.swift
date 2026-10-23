import Foundation

/// Only fixed route groups enter telemetry; path components may contain private IDs.
enum RESTMetricGroup {
    static func classify(_ path: String) -> MobileEndpointGroup {
        let parts = path.split(separator: "/")
        guard let root = parts.first else { return .other }
        if root == "history", parts.contains("trail") { return .trail }
        if root == "groups", parts.contains("places") { return .places }
        switch root {
        case "auth": return .auth
        case "groups": return .groups
        case "conversations", "chat": return .chat
        case "history": return .history
        case "trail", "trails": return .trail
        case "places": return .places
        case "locations" where parts.dropFirst().first == "batch": return .locationBatch
        default: return .other
        }
    }
}

/// URLSession owns this delegate until task metrics arrive; it never retains a request or URL.
final class NetworkTaskMetricsDelegate: NSObject, URLSessionTaskDelegate {
    private let recorder: MobileMetricsRecording

    init(recorder: MobileMetricsRecording) {
        self.recorder = recorder
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didFinishCollecting metrics: URLSessionTaskMetrics) {
        for transaction in metrics.transactionMetrics where transaction.resourceFetchType == .networkLoad {
            let sent = Self.safeTotal(transaction.countOfRequestHeaderBytesSent,
                                      transaction.countOfRequestBodyBytesSent)
            let received = Self.safeTotal(transaction.countOfResponseHeaderBytesReceived,
                                          transaction.countOfResponseBodyBytesReceived)
            guard sent > 0 || received > 0 else { continue }
            let network: MobileNetworkKind = transaction.isCellular ? .cellular : .other
            Task { [recorder] in await recorder.record(.bytes(network, sent: sent, received: received)) }
        }
    }

    // URLSession reports Int64, while the bounded collector stores Int counters.
    static func safeTotal(_ first: Int64, _ second: Int64) -> Int {
        guard first >= 0, second >= 0 else { return 0 }
        let (sum, overflow) = first.addingReportingOverflow(second)
        return overflow || sum > Int.max ? Int.max : Int(sum)
    }
}
