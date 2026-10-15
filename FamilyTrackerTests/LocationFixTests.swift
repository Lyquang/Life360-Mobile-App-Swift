import CoreLocation
import XCTest
@testable import FamilyTracker

@MainActor
final class LocationFixTests: XCTestCase {
    private let sendPolicy = LocationSendPolicy()

    func testShareUseCaseAppliesDynamicPolicyInsteadOfLegacyOrRule() {
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

        XCTAssertEqual(live.sent, [origin, far])
    }

    func testShareUseCaseCapsAutomotiveSendsAtTenSeconds() {
        let device = DeviceLocationStub()
        device.currentMotionState = .automotive
        let live = LiveLocationStub()
        let sut = ShareLocationUseCase(
            deviceLocation: device,
            liveLocation: live,
            deviceStatus: DeviceStatusStub(),
            sleeper: { _ in throw CancellationError() }
        )
        let start = Date(timeIntervalSince1970: 8_000)

        sut.start()
        sut.handle(policyFix(metersNorth: 0, speed: 16.67, accuracy: 5, timestamp: start), now: start)
        for second in 1...9 {
            let date = start.addingTimeInterval(TimeInterval(second))
            sut.handle(policyFix(metersNorth: Double(second) * 17, speed: 16.67,
                                 accuracy: 5, timestamp: date), now: date)
        }
        let capped = start.addingTimeInterval(10)
        sut.handle(policyFix(metersNorth: 170, speed: 16.67, accuracy: 5, timestamp: capped), now: capped)

        XCTAssertEqual(live.sent.count, 2)
        sut.stop()
    }

    func testBackgroundPendingWaitsForNextCallbackThenSends() {
        let device = DeviceLocationStub()
        device.currentMotionState = .walking
        let live = LiveLocationStub()
        let sut = ShareLocationUseCase(
            deviceLocation: device,
            liveLocation: live,
            deviceStatus: DeviceStatusStub(),
            sleeper: { _ in throw CancellationError() },
            isForeground: { false }
        )
        let start = Date(timeIntervalSince1970: 9_000)
        let origin = policyFix(metersNorth: 0, speed: 1.5, accuracy: 5, timestamp: start)
        let final = policyFix(metersNorth: 35, speed: 1.5, accuracy: 5,
                              timestamp: start.addingTimeInterval(5))

        sut.start()
        sut.handle(origin, now: start)
        sut.handle(final, now: start.addingTimeInterval(5))
        XCTAssertEqual(live.sent.count, 1)
        sut.handle(final, now: start.addingTimeInterval(20))

        XCTAssertEqual(live.sent, [origin.point, final.point])
        sut.stop()
    }

    func testForegroundPendingUsesTrailingEdgeTimer() async {
        let device = DeviceLocationStub()
        device.currentMotionState = .walking
        let live = LiveLocationStub()
        let gate = PendingSleeperGate()
        let start = Date(timeIntervalSince1970: 10_000)
        var currentNow = start
        let sut = ShareLocationUseCase(
            deviceLocation: device,
            liveLocation: live,
            deviceStatus: DeviceStatusStub(),
            sleeper: { nanoseconds in
                if nanoseconds >= 30_000_000_000 { throw CancellationError() }
                try await gate.sleep()
            },
            now: { currentNow },
            isForeground: { true }
        )
        let origin = policyFix(metersNorth: 0, speed: 1.5, accuracy: 5, timestamp: start)
        let final = policyFix(metersNorth: 35, speed: 1.5, accuracy: 5,
                              timestamp: start.addingTimeInterval(5))

        sut.start()
        sut.handle(origin, now: start)
        sut.handle(final, now: start.addingTimeInterval(5))
        await gate.waitUntilSleeping()
        currentNow = start.addingTimeInterval(20)
        gate.resume()
        for _ in 0..<10 { await Task.yield() }

        XCTAssertEqual(live.sent, [origin.point, final.point])
        sut.stop()
    }

    func testMotionChangeSendsLatestFixImmediately() async {
        let device = DeviceLocationStub()
        device.currentMotionState = .stationary
        let live = LiveLocationStub()
        let sut = ShareLocationUseCase(
            deviceLocation: device,
            liveLocation: live,
            deviceStatus: DeviceStatusStub(),
            sleeper: { _ in throw CancellationError() }
        )
        let start = Date()
        let origin = policyFix(metersNorth: 0, speed: 0, accuracy: 5, timestamp: start)
        let next = policyFix(metersNorth: 1, speed: 1.5, accuracy: 5,
                             timestamp: start.addingTimeInterval(1))

        sut.start()
        sut.handle(origin, now: start)
        device.lastKnownFix = next
        device.emitMotion(.walking)
        for _ in 0..<10 { await Task.yield() }

        XCTAssertEqual(live.sent, [origin.point, next.point])
        sut.stop()
    }

    func testExistingSocketLocationPayload() {
        let socket = SocketStub()
        let repository = SocketRealtimeRepository(socket: socket, offlineQueue: OfflineQueue(fileName: "location-fix-tests-\(UUID()).json"))
        socket.receiveReady()
        let fix = policyFix(metersNorth: 0, speed: 0, accuracy: 5, timestamp: Date())
        repository.sendLocation(fix, batteryLevel: 42)

        XCTAssertEqual(socket.event, "update_location")
        XCTAssertEqual(Set(socket.payload.keys), Set(["latitude", "longitude", "batteryLevel", "recordedAt", "accuracy"]))
        XCTAssertEqual(socket.payload["latitude"] as? Double, fix.latitude)
        XCTAssertEqual(socket.payload["longitude"] as? Double, fix.longitude)
        XCTAssertEqual(socket.payload["recordedAt"] as? String, ISO8601.string(from: fix.timestamp))
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

    func testRepositoryMapsCoreMotionActivityToDomainState() async {
        let service = LocationServiceStub()
        let repository = DeviceLocationRepositoryImpl(service: service)
        var states = repository.observeMotionStates().makeAsyncIterator()

        service.emitMotion(.automotive)

        let state = await states.next()
        XCTAssertEqual(state, .automotive)
        XCTAssertEqual(repository.currentMotionState, .automotive)
    }

    func testStationaryJitterDropsUntilExistingThirtySecondHeartbeat() {
        let start = Date(timeIntervalSince1970: 1_000)
        let origin = policyFix(metersNorth: 0, speed: 0, accuracy: 5, timestamp: start)
        let sent = LocationSendPolicy.SentLocation(fix: origin, sentAt: start, motionState: .stationary)
        let jitter = policyFix(metersNorth: 10, speed: 0, accuracy: 15,
                               timestamp: start.addingTimeInterval(10))

        XCTAssertEqual(
            sendPolicy.decide(fix: jitter, lastSent: sent, pending: nil,
                              now: start.addingTimeInterval(10), motionState: .stationary),
            .drop(.withinAccuracyOrDistanceThreshold)
        )
        XCTAssertEqual(
            sendPolicy.decide(fix: jitter, lastSent: sent, pending: nil,
                              now: start.addingTimeInterval(30), motionState: .stationary),
            .send(jitter, .heartbeatDue)
        )
    }

    func testAutomotiveAtSixtyKPHNeverExceedsTenSecondCap() {
        let start = Date(timeIntervalSince1970: 2_000)
        var last = LocationSendPolicy.SentLocation(
            fix: policyFix(metersNorth: 0, speed: 16.67, accuracy: 5, timestamp: start),
            sentAt: start,
            motionState: .automotive
        )
        var pending: LocationSendPolicy.PendingLocation?
        var sendTimes: [Int] = []

        for second in 1...30 {
            let date = start.addingTimeInterval(TimeInterval(second))
            let fix = policyFix(metersNorth: 16.8 * Double(second),
                                speed: 16.67, accuracy: 5, timestamp: date)
            switch sendPolicy.decide(fix: fix, lastSent: last, pending: pending,
                                     now: date, motionState: .automotive) {
            case .send(let sentFix, _):
                sendTimes.append(second)
                last = .init(fix: sentFix, sentAt: date, motionState: .automotive)
                pending = nil
            case .hold(let held, _):
                pending = held
            case .drop:
                break
            }
        }

        XCTAssertEqual(sendTimes, [10, 20, 30])
    }

    func testPendingFinalPointSendsAtTrailingEdge() {
        let start = Date(timeIntervalSince1970: 3_000)
        let origin = policyFix(metersNorth: 0, speed: 0, accuracy: 5, timestamp: start)
        let sent = LocationSendPolicy.SentLocation(fix: origin, sentAt: start, motionState: .walking)
        let finalPoint = policyFix(metersNorth: 35, speed: 1.5, accuracy: 5,
                                   timestamp: start.addingTimeInterval(10))
        guard case .hold(let pending, .minimumInterval) = sendPolicy.decide(
            fix: finalPoint, lastSent: sent, pending: nil,
            now: start.addingTimeInterval(10), motionState: .walking
        ) else { return XCTFail("Expected a held final point") }
        let noise = policyFix(metersNorth: 2, speed: 0, accuracy: 5,
                              timestamp: start.addingTimeInterval(20))

        XCTAssertEqual(
            sendPolicy.decide(fix: noise, lastSent: sent, pending: pending,
                              now: start.addingTimeInterval(20), motionState: .walking),
            .send(finalPoint, .trailingEdge)
        )
    }

    func testNegativeSpeedUsesDistanceOverFixTime() {
        let start = Date(timeIntervalSince1970: 4_000)
        let origin = policyFix(metersNorth: 0, speed: -1, accuracy: 5, timestamp: start)
        let fix = policyFix(metersNorth: 35, speed: -1, accuracy: 5,
                            timestamp: start.addingTimeInterval(30))
        let sent = LocationSendPolicy.SentLocation(fix: origin, sentAt: start, motionState: .walking)

        XCTAssertEqual(
            sendPolicy.decide(fix: fix, lastSent: sent, pending: nil,
                              now: start.addingTimeInterval(30), motionState: .walking),
            .send(fix, .moved)
        )
    }

    func testFirstFixAndMotionChangeBypassMinimumInterval() {
        let start = Date(timeIntervalSince1970: 5_000)
        let origin = policyFix(metersNorth: 0, speed: 0, accuracy: 5, timestamp: start)
        XCTAssertEqual(
            sendPolicy.decide(fix: origin, lastSent: nil, pending: nil,
                              now: start, motionState: .stationary),
            .send(origin, .firstFix)
        )
        let sent = LocationSendPolicy.SentLocation(fix: origin, sentAt: start, motionState: .stationary)
        let next = policyFix(metersNorth: 1, speed: 1, accuracy: 5,
                             timestamp: start.addingTimeInterval(1))
        XCTAssertEqual(
            sendPolicy.decide(fix: next, lastSent: sent, pending: nil,
                              now: start.addingTimeInterval(1), motionState: .walking),
            .send(next, .motionChanged)
        )
    }

    func testLargeAccuracyRaisesMovementThreshold() {
        let start = Date(timeIntervalSince1970: 6_000)
        let origin = policyFix(metersNorth: 0, speed: 1, accuracy: 5, timestamp: start)
        let uncertain = policyFix(metersNorth: 40, speed: 1, accuracy: 60,
                                  timestamp: start.addingTimeInterval(20))
        let sent = LocationSendPolicy.SentLocation(fix: origin, sentAt: start, motionState: .walking)

        XCTAssertEqual(
            sendPolicy.decide(fix: uncertain, lastSent: sent, pending: nil,
                              now: start.addingTimeInterval(20), motionState: .walking),
            .drop(.withinAccuracyOrDistanceThreshold)
        )
    }

    func testSlowWalkingStillSendsAtTwentySeconds() {
        let start = Date(timeIntervalSince1970: 7_000)
        let origin = policyFix(metersNorth: 0, speed: 1.39, accuracy: 5, timestamp: start)
        let walked = policyFix(metersNorth: 29, speed: 1.39, accuracy: 5,
                               timestamp: start.addingTimeInterval(20))
        let sent = LocationSendPolicy.SentLocation(fix: origin, sentAt: start, motionState: .walking)

        XCTAssertEqual(
            sendPolicy.decide(fix: walked, lastSent: sent, pending: nil,
                              now: start.addingTimeInterval(20), motionState: .walking),
            .send(walked, .moved)
        )
    }

    private func fix(_ point: GeoPoint, timestamp: Date) -> LocationFix {
        LocationFix(latitude: point.latitude, longitude: point.longitude, timestamp: timestamp,
                    horizontalAccuracy: 5, speed: -1, course: -1)
    }

    private func policyFix(
        metersNorth: Double,
        speed: Double,
        accuracy: Double,
        timestamp: Date
    ) -> LocationFix {
        LocationFix(latitude: 10 + metersNorth / 111_195, longitude: 106,
                    timestamp: timestamp, horizontalAccuracy: accuracy,
                    speed: speed, course: -1)
    }
}

private final class LocationServiceStub: LocationService {
    var authorizationStatus: CLAuthorizationStatus = .authorizedAlways
    var lastLocation: CLLocation?
    var currentMotionActivity: MotionActivity = .unknown
    var onLocationUpdate: ((CLLocation) -> Void)?
    var onMotionChange: ((MotionActivity) -> Void)?
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?
    func requestAuthorization() {}
    func start() {}
    func stop() {}
    func emit(_ location: CLLocation) {
        lastLocation = location
        onLocationUpdate?(location)
    }
    func emitMotion(_ activity: MotionActivity) {
        currentMotionActivity = activity
        onMotionChange?(activity)
    }
}

private final class DeviceLocationStub: DeviceLocationRepository {
    var authorization: LocationAuthorization = .always
    var lastKnownLocation: GeoPoint?
    var lastKnownFix: LocationFix?
    var currentMotionState: MotionState = .unknown
    func requestPermission() {}
    func startTracking() {}
    func stopTracking() {}
    func observeLocations() -> AsyncStream<GeoPoint> { AsyncStream { _ in } }
    func observeFixes() -> AsyncStream<LocationFix> { AsyncStream { _ in } }
    private var motionContinuation: AsyncStream<MotionState>.Continuation?
    func observeMotionStates() -> AsyncStream<MotionState> {
        AsyncStream { motionContinuation = $0 }
    }
    func emitMotion(_ state: MotionState) {
        currentMotionState = state
        motionContinuation?.yield(state)
    }
}

private final class PendingSleeperGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?

    func sleep() async throws {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            self.continuation = continuation
            lock.unlock()
        }
    }

    func waitUntilSleeping() async {
        for _ in 0..<100 {
            if isSleeping { return }
            await Task.yield()
        }
    }

    private var isSleeping: Bool {
        lock.lock(); defer { lock.unlock() }
        return continuation != nil
    }

    func resume() {
        lock.lock()
        let continuation = continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume()
    }
}

private final class LiveLocationStub: LiveLocationRepository {
    var sent: [GeoPoint] = []
    func observeMemberLocations() -> AsyncStream<MemberLocation> { AsyncStream { _ in } }
    func observeStayAlerts() -> AsyncStream<LocationStayAlert> { AsyncStream { _ in } }
    func observePresence() -> AsyncStream<MemberPresence> { AsyncStream { _ in } }
    func sendLocation(_ fix: LocationFix, batteryLevel: Int?) { sent.append(fix.point) }
}

@MainActor
private final class DeviceStatusStub: DeviceStatusRepository {
    var batteryLevel: Int? = 42
}

private final class SocketStub: SocketClient {
    private var readyHandler: (([String: Any]) -> Void)?
    func receiveReady() { readyHandler?([:]) }
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
    func on(_ event: String, handler: @escaping ([String: Any]) -> Void) {
        if event == SocketEvent.sessionReady { readyHandler = handler }
    }
    func onStatusChange(_ handler: @escaping (SocketConnectionStatus) -> Void) {}
}
