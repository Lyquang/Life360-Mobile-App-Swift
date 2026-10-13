import XCTest
@testable import FamilyTracker

@MainActor
final class HeartbeatCancellationTests: XCTestCase {
    func testStopWhileHeartbeatSleepsPreventsLaterEmit() async {
        let gate = HeartbeatSleeperGate()
        let live = HeartbeatLiveLocationMock()
        let sut = makeUseCase(gate: gate, live: live)

        sut.start()
        await waitForSleeps(gate, count: 1)
        sut.stop()
        gate.resumeNext(throwing: CancellationError())
        await drainTasks()

        XCTAssertTrue(live.sent.isEmpty)
    }

    func testStopImmediatelyAfterSleepCompletesPreventsEmit() async {
        let gate = HeartbeatSleeperGate()
        let live = HeartbeatLiveLocationMock()
        let sut = makeUseCase(gate: gate, live: live)

        sut.start()
        await waitForSleeps(gate, count: 1)
        gate.resumeNext()
        sut.stop()
        await drainTasks()

        XCTAssertTrue(live.sent.isEmpty)
    }

    func testLogoutStopsPendingHeartbeatEvenWhenServerLogoutFails() async {
        let gate = HeartbeatSleeperGate()
        let live = HeartbeatLiveLocationMock()
        let shareLocation = makeUseCase(gate: gate, live: live)
        let session = HeartbeatSessionMock()
        let realtime = HeartbeatRealtimeMock()
        shareLocation.start()
        await waitForSleeps(gate, count: 1)

        let result = await LogoutUseCase(
            auth: HeartbeatAuthMock(shouldFailLogout: true),
            session: session,
            realtime: realtime,
            shareLocation: shareLocation
        )()
        gate.resumeNext(throwing: CancellationError())
        await drainTasks()

        XCTAssertFalse(result)
        XCTAssertFalse(shareLocation.isSharing)
        XCTAssertTrue(live.sent.isEmpty)
        XCTAssertEqual(session.clearCount, 1)
        XCTAssertEqual(realtime.disconnectCount, 1)
    }

    func testStartingTwiceCreatesOnlyOneHeartbeatTask() async {
        let gate = HeartbeatSleeperGate()
        let sut = makeUseCase(gate: gate, live: HeartbeatLiveLocationMock())

        sut.start()
        sut.start()
        await waitForSleeps(gate, count: 1)

        XCTAssertEqual(gate.callCount, 1)
        sut.stop()
        gate.resumeNext(throwing: CancellationError())
    }

    func testStopThenStartCreatesFreshHeartbeatWithoutOldTaskEmit() async {
        let gate = HeartbeatSleeperGate()
        let live = HeartbeatLiveLocationMock()
        let sut = makeUseCase(gate: gate, live: live)

        sut.start()
        await waitForSleeps(gate, count: 1)
        sut.stop()
        gate.resumeNext(throwing: CancellationError())

        sut.start()
        await waitForSleeps(gate, count: 2)
        gate.resumeNext()
        await drainTasks()

        XCTAssertEqual(live.sent.count, 1)
        sut.stop()
        gate.resumeNext(throwing: CancellationError())
    }

    private func makeUseCase(
        gate: HeartbeatSleeperGate,
        live: HeartbeatLiveLocationMock
    ) -> ShareLocationUseCase {
        let fix = LocationFix(
            latitude: 10,
            longitude: 106,
            timestamp: Date(),
            horizontalAccuracy: 5,
            speed: 0,
            course: -1
        )
        return ShareLocationUseCase(
            deviceLocation: HeartbeatDeviceLocationMock(lastKnownFix: fix),
            liveLocation: live,
            deviceStatus: HeartbeatDeviceStatusMock(),
            sleeper: { try await gate.sleep() }
        )
    }

    private func waitForSleeps(_ gate: HeartbeatSleeperGate, count: Int) async {
        for _ in 0..<100 where gate.callCount < count {
            await Task.yield()
        }
        XCTAssertGreaterThanOrEqual(gate.callCount, count)
    }

    private func drainTasks() async {
        for _ in 0..<5 { await Task.yield() }
    }
}

private final class HeartbeatSleeperGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [CheckedContinuation<Void, Error>] = []
    private var storedCallCount = 0

    var callCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedCallCount
    }

    func sleep() async throws {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            storedCallCount += 1
            continuations.append(continuation)
            lock.unlock()
        }
    }

    func resumeNext(throwing error: Error? = nil) {
        lock.lock()
        let continuation = continuations.isEmpty ? nil : continuations.removeFirst()
        lock.unlock()
        if let error { continuation?.resume(throwing: error) }
        else { continuation?.resume() }
    }
}

private final class HeartbeatDeviceLocationMock: DeviceLocationRepository {
    var authorization: LocationAuthorization = .always
    var lastKnownFix: LocationFix?
    var currentMotionState: MotionState = .unknown
    var lastKnownLocation: GeoPoint? { lastKnownFix?.point }
    private let fixes = AsyncStream<LocationFix> { _ in }

    init(lastKnownFix: LocationFix?) { self.lastKnownFix = lastKnownFix }
    func requestPermission() {}
    func startTracking() {}
    func stopTracking() {}
    func observeLocations() -> AsyncStream<GeoPoint> { AsyncStream { _ in } }
    func observeFixes() -> AsyncStream<LocationFix> { fixes }
    func observeMotionStates() -> AsyncStream<MotionState> { AsyncStream { _ in } }
}

private final class HeartbeatLiveLocationMock: LiveLocationRepository {
    var sent: [GeoPoint] = []
    func observeMemberLocations() -> AsyncStream<MemberLocation> { AsyncStream { _ in } }
    func observeStayAlerts() -> AsyncStream<LocationStayAlert> { AsyncStream { _ in } }
    func observePresence() -> AsyncStream<MemberPresence> { AsyncStream { _ in } }
    func sendLocation(_ point: GeoPoint, batteryLevel: Int?) { sent.append(point) }
}

@MainActor
private final class HeartbeatDeviceStatusMock: DeviceStatusRepository {
    var batteryLevel: Int? = 50
}

private struct HeartbeatAuthMock: AuthRepository {
    let shouldFailLogout: Bool
    func login(email: String, password: String) async throws -> AuthSession { throw DomainError.unauthorized }
    func register(name: String, email: String, password: String) async throws -> AuthSession {
        throw DomainError.unauthorized
    }
    func socialLogin(idToken: String) async throws -> AuthSession { throw DomainError.unauthorized }
    func fetchCurrentUser() async throws -> User { throw DomainError.unauthorized }
    func logout(refreshToken: String) async throws {
        if shouldFailLogout { throw DomainError.network("offline") }
    }
    func logoutAll() async throws {
        if shouldFailLogout { throw DomainError.network("offline") }
    }
    func changePassword(currentPassword: String, newPassword: String) async throws {}
}

private final class HeartbeatSessionMock: SessionRepository {
    var accessToken: String? { tokens?.accessToken }
    var tokens: AuthTokens? = AuthTokens(accessToken: "access", refreshToken: "refresh", expiresIn: 300)
    var clearCount = 0
    func save(_ session: AuthSession) throws { tokens = session.tokens }
    func clear() { clearCount += 1; tokens = nil }
}

private final class HeartbeatRealtimeMock: RealtimeSessionRepository {
    var connectionState: RealtimeConnectionState = .connected
    var disconnectCount = 0
    func connect(token: String) {}
    func disconnect() { disconnectCount += 1 }
    func observeConnectionState() -> AsyncStream<RealtimeConnectionState> { AsyncStream { _ in } }
}
