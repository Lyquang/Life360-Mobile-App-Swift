import CoreLocation
import XCTest
@testable import FamilyTracker

@MainActor
final class LocationFixTests: XCTestCase {
    func testExistingShareThresholds() {
        let device = DeviceLocationStub()
        let live = LiveLocationStub()
        let sut = ShareLocationUseCase(deviceLocation: device, liveLocation: live, deviceStatus: DeviceStatusStub())
        let origin = GeoPoint(latitude: 10, longitude: 106)
        let near = GeoPoint(latitude: 10.0001, longitude: 106)
        let far = GeoPoint(latitude: 10.0006, longitude: 106)
        let nearFar = GeoPoint(latitude: 10.0007, longitude: 106)
        let start = Date(timeIntervalSince1970: 1_000)

        // Deliberately stale fix timestamps must not replace the send-attempt clock.
        sut.handle(fix(origin, timestamp: start.addingTimeInterval(-100)), now: start)
        sut.handle(fix(near, timestamp: start.addingTimeInterval(-90)), now: start.addingTimeInterval(10))
        sut.handle(fix(far, timestamp: start.addingTimeInterval(-80)), now: start.addingTimeInterval(20))
        sut.handle(fix(nearFar, timestamp: start.addingTimeInterval(-70)), now: start.addingTimeInterval(51))

        XCTAssertEqual(live.sent, [origin, far, nearFar])
    }

    func testExistingSocketLocationPayload() {
        let socket = SocketStub()
        let repository = SocketRealtimeRepository(socket: socket, offlineQueue: OfflineQueue(fileName: "location-fix-tests-\(UUID()).json"))
        repository.sendLocation(GeoPoint(latitude: 10, longitude: 106), batteryLevel: 42)

        XCTAssertEqual(socket.event, "update_location")
        XCTAssertEqual(Set(socket.payload.keys), Set(["latitude", "longitude", "batteryLevel"]))
        XCTAssertEqual(socket.payload["latitude"] as? Double, 10)
        XCTAssertEqual(socket.payload["longitude"] as? Double, 106)
        XCTAssertEqual(socket.payload["batteryLevel"] as? Int, 42)
    }

    func testCLLocationMappingPreservesMetadataIncludingUnavailableSpeedAndCourse() {
        let timestamp = Date(timeIntervalSince1970: 1_234.5)
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 10.25, longitude: 106.75),
            altitude: 0,
            horizontalAccuracy: 8.5,
            verticalAccuracy: 4,
            course: -1,
            speed: -1,
            timestamp: timestamp
        )
        let fix = DeviceLocationRepositoryImpl.fix(location)

        XCTAssertEqual(fix.latitude, 10.25)
        XCTAssertEqual(fix.longitude, 106.75)
        XCTAssertEqual(fix.timestamp, timestamp)
        XCTAssertEqual(fix.horizontalAccuracy, 8.5)
        XCTAssertEqual(fix.speed, -1)
        XCTAssertEqual(fix.course, -1)
        XCTAssertEqual(fix.point, GeoPoint(latitude: 10.25, longitude: 106.75))
    }

    func testCLLocationMappingPreservesValidSpeedAndCourse() {
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 10, longitude: 106),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 4,
            course: 270,
            speed: 12.5,
            timestamp: Date(timeIntervalSince1970: 1_500)
        )
        let fix = DeviceLocationRepositoryImpl.fix(location)
        XCTAssertEqual(fix.speed, 12.5)
        XCTAssertEqual(fix.course, 270)
    }

    func testRepositoryPublishesFixAndCompatibleGeoPoint() async {
        let service = LocationServiceStub()
        let repository = DeviceLocationRepositoryImpl(service: service)
        var fixes = repository.observeFixes().makeAsyncIterator()
        var points = repository.observeLocations().makeAsyncIterator()
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 10, longitude: 106),
            altitude: 0,
            horizontalAccuracy: 7,
            verticalAccuracy: 4,
            course: 90,
            speed: 2,
            timestamp: Date(timeIntervalSince1970: 2_000)
        )

        service.emit(location)

        let fix = await fixes.next()
        let point = await points.next()
        XCTAssertEqual(fix, repository.lastKnownFix)
        XCTAssertEqual(fix?.point, point)
        XCTAssertEqual(repository.lastKnownLocation, fix?.point)
    }

    private func fix(_ point: GeoPoint, timestamp: Date) -> LocationFix {
        LocationFix(latitude: point.latitude, longitude: point.longitude, timestamp: timestamp,
                    horizontalAccuracy: 5, speed: -1, course: -1)
    }
}

private final class LocationServiceStub: LocationService {
    var authorizationStatus: CLAuthorizationStatus = .authorizedAlways
    var lastLocation: CLLocation?
    var onLocationUpdate: ((CLLocation) -> Void)?
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?
    func requestAuthorization() {}
    func start() {}
    func stop() {}
    func emit(_ location: CLLocation) {
        lastLocation = location
        onLocationUpdate?(location)
    }
}

private final class DeviceLocationStub: DeviceLocationRepository {
    var authorization: LocationAuthorization = .always
    var lastKnownLocation: GeoPoint?
    var lastKnownFix: LocationFix?
    func requestPermission() {}
    func startTracking() {}
    func stopTracking() {}
    func observeLocations() -> AsyncStream<GeoPoint> { AsyncStream { _ in } }
    func observeFixes() -> AsyncStream<LocationFix> { AsyncStream { _ in } }
}

private final class LiveLocationStub: LiveLocationRepository {
    var sent: [GeoPoint] = []
    func observeMemberLocations() -> AsyncStream<MemberLocation> { AsyncStream { _ in } }
    func observeStayAlerts() -> AsyncStream<LocationStayAlert> { AsyncStream { _ in } }
    func observePresence() -> AsyncStream<MemberPresence> { AsyncStream { _ in } }
    func sendLocation(_ point: GeoPoint, batteryLevel: Int?) { sent.append(point) }
}

@MainActor
private final class DeviceStatusStub: DeviceStatusRepository {
    var batteryLevel: Int? = 42
}

private final class SocketStub: SocketClient {
    var status: SocketConnectionStatus = .connected
    var event = ""
    var payload: [String: Any] = [:]
    func connect(token: String) {}
    func disconnect() {}
    func emit(_ event: String, _ payload: [String: Any]) {
        self.event = event
        self.payload = payload
    }
    func emitWithAck(_ event: String, _ payload: [String: Any], timeout: TimeInterval) async throws -> [String: Any] { [:] }
    func on(_ event: String, handler: @escaping ([String: Any]) -> Void) {}
    func onStatusChange(_ handler: @escaping (SocketConnectionStatus) -> Void) {}
}
