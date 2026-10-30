import Foundation

enum SOSLocationAuthorization {
    case notDetermined, authorized, denied, restricted, unavailable
}

struct SOSLocationSample {
    let latitude: Double
    let longitude: Double
    let horizontalAccuracy: Double
    let timestamp: Date
}

@MainActor
protocol SOSLocationDriver: AnyObject {
    var authorization: SOSLocationAuthorization { get }
    var onAuthorization: ((SOSLocationAuthorization) -> Void)? { get set }
    var onSample: ((SOSLocationSample) -> Void)? { get set }
    var onFailure: ((SOSLocationFailure) -> Void)? { get set }
    func requestAuthorization()
    func requestLocation()
    func stop()
}

enum SOSLocationFixPolicy {
    static func location(from sample: SOSLocationSample, requestedAt: Date, now: Date) -> SOSLocation? {
        guard sample.latitude.isFinite, sample.longitude.isFinite,
              (-90...90).contains(sample.latitude), (-180...180).contains(sample.longitude),
              sample.horizontalAccuracy.isFinite, sample.horizontalAccuracy >= 0,
              sample.timestamp.timeIntervalSinceReferenceDate.isFinite,
              requestedAt.timeIntervalSinceReferenceDate.isFinite, now.timeIntervalSinceReferenceDate.isFinite,
              sample.timestamp >= requestedAt, sample.timestamp <= now.addingTimeInterval(1) else { return nil }
        return SOSLocation(latitude: sample.latitude, longitude: sample.longitude, recordedAt: sample.timestamp)
    }
}

/// Owns only an explicit SOS one-shot, independent of the background tracking service.
@MainActor
final class SOSLocationService: SOSLocationProviding {
    typealias Sleeper = @Sendable (TimeInterval) async throws -> Void
    private static let timeout: TimeInterval = 8

    private final class Pending {
        let id: UUID
        let driver: SOSLocationDriver
        let continuation: CheckedContinuation<SOSLocation, Error>
        var permissionRequested = false
        var requestedAt: Date?
        var timeoutTask: Task<Void, Never>?

        init(id: UUID, driver: SOSLocationDriver, continuation: CheckedContinuation<SOSLocation, Error>) {
            self.id = id
            self.driver = driver
            self.continuation = continuation
        }
    }

    private let makeDriver: () -> SOSLocationDriver
    private let now: () -> Date
    private let sleep: Sleeper
    private var pending: Pending?

    init(makeDriver: @escaping () -> SOSLocationDriver,
         now: @escaping () -> Date = { Date() },
         sleep: @escaping Sleeper = { seconds in
             try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
         }) {
        self.makeDriver = makeDriver
        self.now = now
        self.sleep = sleep
    }

    func currentLocation() async throws -> SOSLocation {
        guard pending == nil else { throw SOSLocationFailure.busy }
        let id = UUID()
        let location: SOSLocation = try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<SOSLocation, Error>) in
                guard !Task.isCancelled else { continuation.resume(throwing: CancellationError()); return }
                let driver = makeDriver()
                let operation = Pending(id: id, driver: driver, continuation: continuation)
                pending = operation
                driver.onAuthorization = { [weak self] status in self?.authorizationChanged(status, id: id) }
                driver.onSample = { [weak self] sample in self?.received(sample, id: id) }
                driver.onFailure = { [weak self] error in self?.finish(.failure(error), id: id) }
                authorizationChanged(driver.authorization, id: id)
            }
        } onCancel: { [weak self] in
            Task { @MainActor [weak self] in self?.finish(.failure(CancellationError()), id: id) }
        }
        try Task.checkCancellation()
        return location
    }

    func cancel() {
        guard let id = pending?.id else { return }
        finish(.failure(CancellationError()), id: id)
    }

    private func authorizationChanged(_ status: SOSLocationAuthorization, id: UUID) {
        guard let operation = pending, operation.id == id else { return }
        switch status {
        case .notDetermined:
            if operation.requestedAt != nil {
                finish(.failure(SOSLocationFailure.unavailable), id: id)
                return
            }
            guard !operation.permissionRequested else { return }
            operation.permissionRequested = true
            operation.driver.requestAuthorization()
        case .authorized:
            guard operation.requestedAt == nil else { return }
            operation.requestedAt = now()
            // The timeout starts after permission, not while the system dialog is open.
            operation.timeoutTask = Task { [weak self, sleep] in
                do { try await sleep(Self.timeout) }
                catch {
                    guard !Task.isCancelled else { return }
                    self?.finish(.failure(SOSLocationFailure.unavailable), id: id)
                    return
                }
                guard !Task.isCancelled else { return }
                self?.finish(.failure(SOSLocationFailure.timedOut), id: id)
            }
            operation.driver.requestLocation()
        case .denied: finish(.failure(SOSLocationFailure.permissionDenied), id: id)
        case .restricted: finish(.failure(SOSLocationFailure.permissionRestricted), id: id)
        case .unavailable: finish(.failure(SOSLocationFailure.unavailable), id: id)
        }
    }

    private func received(_ sample: SOSLocationSample, id: UUID) {
        guard let operation = pending, operation.id == id, let requestedAt = operation.requestedAt else { return }
        guard let location = SOSLocationFixPolicy.location(from: sample, requestedAt: requestedAt, now: now()) else {
            finish(.failure(SOSLocationFailure.invalidFix), id: id)
            return
        }
        finish(.success(location), id: id)
    }

    private func finish(_ result: Result<SOSLocation, Error>, id: UUID) {
        guard let operation = pending, operation.id == id else { return }
        pending = nil
        operation.timeoutTask?.cancel()
        operation.driver.onAuthorization = nil
        operation.driver.onSample = nil
        operation.driver.onFailure = nil
        operation.driver.stop()
        operation.continuation.resume(with: result)
    }
}
