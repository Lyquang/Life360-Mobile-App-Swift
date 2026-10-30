import Foundation

private enum LocationCheckError: Error { case failed(String) }

private func expectLocation(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw LocationCheckError.failed(message) }
}

@MainActor
private final class MockSOSLocationDriver: SOSLocationDriver {
    var authorization: SOSLocationAuthorization
    var onAuthorization: ((SOSLocationAuthorization) -> Void)?
    var onSample: ((SOSLocationSample) -> Void)?
    var onFailure: ((SOSLocationFailure) -> Void)?
    var authorizationRequests = 0
    var locationRequests = 0
    var stops = 0

    init(_ authorization: SOSLocationAuthorization) { self.authorization = authorization }
    func requestAuthorization() { authorizationRequests += 1 }
    func requestLocation() { locationRequests += 1 }
    func stop() { stops += 1 }
}

enum SOSLocationChecks {
    @MainActor
    static func run() async throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let driver = MockSOSLocationDriver(.notDetermined)
        let service = SOSLocationService(makeDriver: { driver }, now: { now }, sleep: longSleep)
        let task = Task { try await service.currentLocation() }
        try await waitFor { driver.authorizationRequests == 1 }
        try expectLocation(driver.locationRequests == 0, "GPS started before permission")
        driver.onAuthorization?(.notDetermined)
        try expectLocation(driver.authorizationRequests == 1, "Permission requested twice")
        driver.onAuthorization?(.authorized)
        try expectLocation(driver.locationRequests == 1, "One-shot request missing")
        driver.onSample?(sample(timestamp: now))
        let location = try await task.value
        try expectLocation(location.recordedAt == now && driver.stops == 1, "Measured fix or cleanup lost")

        let denied = MockSOSLocationDriver(.denied)
        let deniedService = SOSLocationService(makeDriver: { denied }, now: { now }, sleep: longSleep)
        do { _ = try await deniedService.currentLocation(); throw LocationCheckError.failed("Denied GPS succeeded") }
        catch SOSLocationFailure.permissionDenied {}
        try expectLocation(denied.locationRequests == 0 && denied.stops == 1, "Denied GPS started")

        let stale = MockSOSLocationDriver(.authorized)
        let staleService = SOSLocationService(makeDriver: { stale }, now: { now }, sleep: longSleep)
        let staleTask = Task { try await staleService.currentLocation() }
        try await waitFor { stale.locationRequests == 1 }
        stale.onSample?(sample(timestamp: now.addingTimeInterval(-1)))
        do { _ = try await staleTask.value; throw LocationCheckError.failed("Stale fix accepted") }
        catch SOSLocationFailure.invalidFix {}

        let timeout = MockSOSLocationDriver(.authorized)
        let timeoutService = SOSLocationService(makeDriver: { timeout }, now: { now }, sleep: { seconds in
            try expectLocation(seconds == 8, "Wrong SOS location timeout")
        })
        do { _ = try await timeoutService.currentLocation(); throw LocationCheckError.failed("Timeout succeeded") }
        catch SOSLocationFailure.timedOut {}
        try expectLocation(timeout.stops == 1, "Timed-out manager not stopped")

        let first = MockSOSLocationDriver(.authorized)
        let second = MockSOSLocationDriver(.authorized)
        var drivers = [first, second]
        let cancellable = SOSLocationService(makeDriver: { drivers.removeFirst() }, now: { now }, sleep: longSleep)
        let firstTask = Task { try await cancellable.currentLocation() }
        try await waitFor { first.locationRequests == 1 }
        let oldCallback = first.onSample
        do { _ = try await cancellable.currentLocation(); throw LocationCheckError.failed("Concurrent GPS accepted") }
        catch SOSLocationFailure.busy {}
        firstTask.cancel()
        do { _ = try await firstTask.value; throw LocationCheckError.failed("Cancelled GPS succeeded") }
        catch is CancellationError {}
        try expectLocation(first.stops == 1, "Cancelled manager not stopped")
        let secondTask = Task { try await cancellable.currentLocation() }
        try await waitFor { second.locationRequests == 1 }
        oldCallback?(sample(timestamp: now))
        second.onSample?(sample(timestamp: now))
        _ = try await secondTask.value
        try expectLocation(second.stops == 1, "Late callback affected new operation")
    }

    private static func sample(timestamp: Date) -> SOSLocationSample {
        SOSLocationSample(latitude: 10, longitude: 106, horizontalAccuracy: 20, timestamp: timestamp)
    }

    private static let longSleep: SOSLocationService.Sleeper = { _ in
        try await Task.sleep(nanoseconds: 60_000_000_000)
    }

    @MainActor
    private static func waitFor(_ predicate: () -> Bool) async throws {
        for _ in 0..<1_000 {
            if predicate() { return }
            await Task.yield()
        }
        throw LocationCheckError.failed("SOS location operation did not start")
    }
}
