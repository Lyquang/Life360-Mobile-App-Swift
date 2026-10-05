import Foundation

protocol RealtimeSessionRepository: AnyObject {
    var connectionState: RealtimeConnectionState { get }
    func connect(token: String)
    func disconnect()
    func observeConnectionState() -> AsyncStream<RealtimeConnectionState>
}

protocol LiveLocationRepository: AnyObject {
    func observeMemberLocations() -> AsyncStream<MemberLocation>
    func observeStayAlerts() -> AsyncStream<LocationStayAlert>
    func observePresence() -> AsyncStream<MemberPresence>
    func sendLocation(_ point: GeoPoint, batteryLevel: Int?)
}

protocol SOSRepository: AnyObject {
    func observeSOSAlerts() -> AsyncStream<SOSAlert>
    func sendSOS(message: String, location: GeoPoint?, batteryLevel: Int?)
}

protocol DeviceLocationRepository: AnyObject {
    var authorization: LocationAuthorization { get }
    var lastKnownLocation: GeoPoint? { get }
    func requestPermission()
    func startTracking()
    func stopTracking()
    func observeLocations() -> AsyncStream<GeoPoint>
}

@MainActor
protocol DeviceStatusRepository: AnyObject {
    var batteryLevel: Int? { get }
}

protocol GeocodingRepository {
    func address(for point: GeoPoint) async -> String?
}
