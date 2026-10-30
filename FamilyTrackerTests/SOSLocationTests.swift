import Foundation
import XCTest
@testable import FamilyTracker

@MainActor
final class SOSLocationTests: XCTestCase {
    func testExplicitPermissionThenFreshFixKeepsMeasuredTimestamp() async throws {
        let date = Date(timeIntervalSince1970: 1_000)
        let driver = SOSLocationDriverStub(.notDetermined)
        let service = SOSLocationService(makeDriver: { driver }, now: { date }, sleep: longSleep)
        let task = Task { try await service.currentLocation() }
        try await waitFor { driver.permissionRequests == 1 }
        XCTAssertEqual(driver.locationRequests, 0)
        driver.onAuthorization?(.notDetermined)
        XCTAssertEqual(driver.permissionRequests, 1)
        driver.onAuthorization?(.authorized)
        XCTAssertEqual(driver.locationRequests, 1)
        driver.onSample?(SOSLocationSample(latitude: 10, longitude: 106, horizontalAccuracy: 15, timestamp: date))
        let result = try await task.value
        XCTAssertEqual(result.recordedAt, date)
        XCTAssertEqual(driver.stops, 1)
    }

    func testStaleFixIsRejectedWithoutFallbackToCache() async throws {
        let date = Date(timeIntervalSince1970: 1_000)
        let driver = SOSLocationDriverStub(.authorized)
        let service = SOSLocationService(makeDriver: { driver }, now: { date }, sleep: longSleep)
        let task = Task { try await service.currentLocation() }
        try await waitFor { driver.locationRequests == 1 }
        driver.onSample?(SOSLocationSample(latitude: 10, longitude: 106, horizontalAccuracy: 15,
                                            timestamp: date.addingTimeInterval(-1)))
        do { _ = try await task.value; XCTFail("A cached fix must not be sent") }
        catch SOSLocationFailure.invalidFix {}
        XCTAssertEqual(driver.stops, 1)
    }

    func testDeniedAndTimeoutStopTheDedicatedManager() async throws {
        let denied = SOSLocationDriverStub(.denied)
        let service = SOSLocationService(makeDriver: { denied }, sleep: longSleep)
        do { _ = try await service.currentLocation(); XCTFail("Denied permission must fail") }
        catch SOSLocationFailure.permissionDenied {}
        XCTAssertEqual(denied.locationRequests, 0)
        XCTAssertEqual(denied.stops, 1)

        let timeout = SOSLocationDriverStub(.authorized)
        let timeoutService = SOSLocationService(makeDriver: { timeout }, sleep: { _ in })
        do { _ = try await timeoutService.currentLocation(); XCTFail("Timeout must fail") }
        catch SOSLocationFailure.timedOut {}
        XCTAssertEqual(timeout.stops, 1)
    }

    func testCancellationStopsManagerAndConcurrentRequestIsRejected() async throws {
        let driver = SOSLocationDriverStub(.authorized)
        let service = SOSLocationService(makeDriver: { driver }, sleep: longSleep)
        let task = Task { try await service.currentLocation() }
        try await waitFor { driver.locationRequests == 1 }
        do { _ = try await service.currentLocation(); XCTFail("Concurrent location must fail") }
        catch SOSLocationFailure.busy {}
        task.cancel()
        do { _ = try await task.value; XCTFail("Cancelled request must fail") }
        catch is CancellationError {}
        XCTAssertEqual(driver.stops, 1)
    }

    private var longSleep: SOSLocationService.Sleeper {
        { _ in try await Task.sleep(nanoseconds: 60_000_000_000) }
    }

    private func waitFor(_ predicate: () -> Bool) async throws {
        for _ in 0..<1_000 {
            if predicate() { return }
            await Task.yield()
        }
        throw SOSLocationFailure.unavailable
    }
}

@MainActor
private final class SOSLocationDriverStub: SOSLocationDriver {
    var authorization: SOSLocationAuthorization
    var onAuthorization: ((SOSLocationAuthorization) -> Void)?
    var onSample: ((SOSLocationSample) -> Void)?
    var onFailure: ((SOSLocationFailure) -> Void)?
    var permissionRequests = 0
    var locationRequests = 0
    var stops = 0
    init(_ authorization: SOSLocationAuthorization) { self.authorization = authorization }
    func requestAuthorization() { permissionRequests += 1 }
    func requestLocation() { locationRequests += 1 }
    func stop() { stops += 1 }
}
