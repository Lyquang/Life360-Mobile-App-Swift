import Foundation

enum MobileMetricCounter: String, Codable, Sendable, CaseIterable {
    case fixReceived, fixAccepted, fixDropped, locationEmit, heartbeatAttempt
    case socketConnect, socketDisconnect, offlinePoint, batchPoint
    case request, requestFailure, mediaUpload
}

enum MobileEndpointGroup: String, Codable, Sendable, CaseIterable {
    case auth, groups, chat, history, trail, places, locationBatch, other
}

enum MobileNetworkKind: String, Codable, Sendable, CaseIterable {
    case wifi, cellular, other, offline, unknown
}

enum MobileMetricEvent: Sendable {
    case increment(MobileMetricCounter)
    case latency(MobileEndpointGroup, milliseconds: Int)
    case bytes(MobileNetworkKind, sent: Int, received: Int)
}

protocol MobileMetricsRecording: Sendable {
    func record(_ event: MobileMetricEvent) async
}
