import Foundation

enum MobileMetricCounter: String, Codable, Sendable, CaseIterable {
    case fixReceived, fixAccepted, fixDropped, locationEmit, heartbeatAttempt
    case socketConnect, socketDisconnect, offlinePoint, batchPoint
    case request, requestFailure, mediaUpload, mediaUploadFailure
    case mediaCacheHit, mediaCacheMiss, mediaDownloadFailure
    case locationReconfiguration, locationPermissionChange, locationPause
    case sharingPause, batchDuplicate, batchRejectedPermanent, batchRejectedUnknown
    case batchDeferred, batchFailure
    case socketReconnect
}

enum MobileMetricState: String, Codable, Sendable, CaseIterable {
    case foreground, background
    case charging, unplugged, batteryUnknown
    case normalPower, lowPower
    case thermalNominal, thermalFair, thermalSerious, thermalCritical
    case motionOff, motionStationary, motionWalking, motionRunning, motionCycling, motionAutomotive, motionUnknown
    case accuracyOff, accuracySignificant, accuracyNavigation, accuracyTenMeters
    case accuracyHundredMeters, accuracyKilometer, accuracyOther
    case permissionAlways, permissionWhenInUse, permissionDenied, permissionRestricted, permissionUndetermined
    case permissionFullAccuracy, permissionReducedAccuracy
    case networkWifi, networkCellular, networkOther, networkOffline, networkUnknown

    var group: MobileMetricStateGroup {
        switch self {
        case .foreground, .background: return .app
        case .charging, .unplugged, .batteryUnknown: return .battery
        case .normalPower, .lowPower: return .power
        case .thermalNominal, .thermalFair, .thermalSerious, .thermalCritical: return .thermal
        case .motionOff, .motionStationary, .motionWalking, .motionRunning, .motionCycling,
             .motionAutomotive, .motionUnknown: return .motion
        case .accuracyOff, .accuracySignificant, .accuracyNavigation, .accuracyTenMeters,
             .accuracyHundredMeters, .accuracyKilometer, .accuracyOther: return .accuracy
        case .permissionAlways, .permissionWhenInUse, .permissionDenied, .permissionRestricted,
             .permissionUndetermined: return .permission
        case .permissionFullAccuracy, .permissionReducedAccuracy: return .precisionPermission
        case .networkWifi, .networkCellular, .networkOther, .networkOffline, .networkUnknown: return .network
        }
    }
}

enum MobileMetricStateGroup: Hashable, Sendable {
    case app, battery, power, thermal, motion, accuracy, permission, precisionPermission, network
}

enum MobileEndpointGroup: String, Codable, Sendable, CaseIterable {
    case auth, groups, chat, history, trail, places, locationBatch, other
}

enum MobileNetworkKind: String, Codable, Sendable, CaseIterable {
    case wifi, cellular, other, offline, unknown
}

enum MobileMediaMetricKind: String, Codable, Sendable, CaseIterable {
    case imageUpload, voiceUpload, imageDownload
}

/// A fixed event vocabulary keeps user-generated event names out of persisted metrics.
enum MobileSocketMetricEvent: String, Codable, Sendable, CaseIterable {
    case updateLocation = "update_location"
    case sosAlert = "sos_alert"
    case chatTyping = "chat:typing"
    case chatSendMessage = "chat:send_message"
    case journeyWatch = "journey:watch"
    case journeyUnwatch = "journey:unwatch"
    case sessionReady = "session:ready"
    case locationUpdate = "location_update"
    case sosConfirmed = "sos_confirmed"
    case memberOnline = "member_online"
    case memberOffline = "member_offline"
    case locationStayAlert = "location_stay_alert"
    case chatNewMessage = "chat:new_message"
    case chatReadReceipt = "chat:read_receipt"
    case chatConversationUpdated = "chat:conversation_updated"
    case journeyTrailDelta = "journey:trail_delta"
    case journeyTrailReset = "journey:trail_reset"
    case journeyTrailClosed = "journey:trail_closed"
}

enum SocketMetricsPolicy {
    static func event(_ name: String) -> MobileSocketMetricEvent? {
        MobileSocketMetricEvent(rawValue: name)
    }

    /// JSON size excludes Socket.IO/WebSocket/TLS framing, compression and ping-pong traffic.
    static func estimatedPayloadBytes(_ payload: [String: Any]) -> Int? {
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload) else { return nil }
        return data.count
    }
}

enum MobileMetricEvent: Sendable {
    case increment(MobileMetricCounter)
    case latency(MobileEndpointGroup, milliseconds: Int)
    case bytes(MobileNetworkKind, sent: Int, received: Int)
    case state(MobileMetricState)
    case batteryLevel(Int)
    case horizontalAccuracy(Double)
    case count(MobileMetricCounter, by: Int)
    case bufferSnapshot(depth: Int, oldestAgeSeconds: TimeInterval?)
    case locationEmit(motion: MobileMetricState)
    case socketPayload(MobileSocketMetricEvent, network: MobileNetworkKind, sent: Int, received: Int)
    case socketReady(milliseconds: Int)
    case mediaTransfer(MobileMediaMetricKind, network: MobileNetworkKind, sent: Int, received: Int)
}

protocol MobileMetricsRecording: Sendable {
    func record(_ event: MobileMetricEvent) async
}
