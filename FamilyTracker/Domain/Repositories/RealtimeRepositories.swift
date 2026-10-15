import Foundation

protocol RealtimeSessionRepository: AnyObject {
    var connectionState: RealtimeConnectionState { get }
    func connect(token: String)
    @MainActor func disconnect()
    func observeConnectionState() -> AsyncStream<RealtimeConnectionState>
}

protocol LiveLocationRepository: AnyObject {
    func observeMemberLocations() -> AsyncStream<MemberLocation>
    func observeStayAlerts() -> AsyncStream<LocationStayAlert>
    func observePresence() -> AsyncStream<MemberPresence>
    var isSessionReady: Bool { get }
    func observeSessionReadiness() -> AsyncStream<Bool>
    @MainActor func sendLocation(_ fix: LocationFix, batteryLevel: Int?)
}

extension LiveLocationRepository {
    var isSessionReady: Bool { false }
    func observeSessionReadiness() -> AsyncStream<Bool> { AsyncStream { $0.finish() } }
}

protocol SOSRepository: AnyObject {
    func observeSOSAlerts() -> AsyncStream<SOSAlert>
    func sendSOS(message: String, location: GeoPoint?, batteryLevel: Int?)
}

protocol DeviceLocationRepository: AnyObject {
    var authorization: LocationAuthorization { get }
    var lastKnownLocation: GeoPoint? { get }
    var lastKnownFix: LocationFix? { get }
    var currentMotionState: MotionState { get }
    func requestPermission()
    func startTracking()
    func stopTracking()
    func requestFreshLocation()
    func observeLocations() -> AsyncStream<GeoPoint>
    func observeFixes() -> AsyncStream<LocationFix>
    func observeMotionStates() -> AsyncStream<MotionState>
}

extension DeviceLocationRepository {
    func requestFreshLocation() {}
}

@MainActor
protocol DeviceStatusRepository: AnyObject {
    var batteryLevel: Int? { get }
}

protocol GeocodingRepository {
    func address(for point: GeoPoint) async -> String?
}
