import Foundation

enum MobileMetricCounter: String, Codable, Sendable, CaseIterable {
    case fixReceived, fixAccepted, fixDropped, locationEmit, heartbeatAttempt
    case socketConnect, socketDisconnect, offlinePoint, batchPoint
    case request, requestFailure, mediaUpload
    case locationReconfiguration, locationPermissionChange, locationPause
    case sharingPause, batchDuplicate, batchRejectedPermanent, batchRejectedUnknown
    case batchDeferred, batchFailure
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
        }
    }
}

enum MobileMetricStateGroup: Hashable, Sendable {
    case app, battery, power, thermal, motion, accuracy, permission, precisionPermission
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
    case state(MobileMetricState)
    case batteryLevel(Int)
    case horizontalAccuracy(Double)
    case count(MobileMetricCounter, by: Int)
    case bufferSnapshot(depth: Int, oldestAgeSeconds: TimeInterval?)
    case locationEmit(motion: MobileMetricState)
}

protocol MobileMetricsRecording: Sendable {
    func record(_ event: MobileMetricEvent) async
}
