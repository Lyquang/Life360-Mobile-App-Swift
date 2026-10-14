import Foundation

enum LocationSyncOutcome: Equatable {
    case completed(accepted: Int, duplicates: Int, permanentlyRejected: Int, unknownRejected: Int)
    case deferred(until: Date)
}

/// Synchronizes one buffer snapshot per run. Lifecycle triggers are wired in P7E.
actor LocationSyncCoordinator {
    typealias Now = @Sendable () -> Date
    typealias Sleep = @Sendable (TimeInterval) async throws -> Void
    typealias RandomUnit = @Sendable () -> Double

    private struct RetryGate: Codable {
        let ownerID: String
        let notBefore: Date
    }

    private let buffer: LocationBuffer
    private let repository: LocationBatchRepository
    private let gateURL: URL
    private let now: Now
    private let sleep: Sleep
    private let randomUnit: RandomUnit
    private var inFlight: Task<LocationSyncOutcome, Error>?
    private var inFlightID: UUID?
    private var inFlightOwnerID: String?
    private var gate: RetryGate?
    private(set) var joinedRunCount = 0

    init(buffer: LocationBuffer, repository: LocationBatchRepository,
         gateURL: URL? = nil,
         now: @escaping Now = { Date() },
         sleep: @escaping Sleep = { seconds in
             try await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
         },
         randomUnit: @escaping RandomUnit = { Double.random(in: 0...1) }) throws {
        self.buffer = buffer
        self.repository = repository
        self.now = now
        self.sleep = sleep
        self.randomUnit = randomUnit
        if let gateURL {
            self.gateURL = gateURL
        } else {
            guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                throw CocoaError(.fileNoSuchFile)
            }
            self.gateURL = support.appendingPathComponent("LocationBuffer", isDirectory: true)
                .appendingPathComponent("retry-gate.json")
        }
        let directory = self.gateURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Self.excludeFromBackup(directory)
        if let data = try? Data(contentsOf: self.gateURL) {
            gate = try? BackendJSONCoding.makeDecoder().decode(RetryGate.self, from: data)
        }
    }

    func synchronize(ownerID: String) async throws -> LocationSyncOutcome {
        guard !ownerID.isEmpty else { throw LocationBatchError.invalidBatch }
        if let inFlight {
            guard inFlightOwnerID == ownerID else { throw CancellationError() }
            joinedRunCount += 1
            return try await inFlight.value
        }
        if gate?.ownerID != ownerID { try setGate(nil) }
        if let gate, gate.notBefore > now() { return .deferred(until: gate.notBefore) }
        let flightID = UUID()
        let flight = Task { [self] in try await run(ownerID: ownerID) }
        inFlight = flight
        inFlightID = flightID
        inFlightOwnerID = ownerID
        do {
            let result = try await flight.value
            if inFlightID == flightID { clearFlight() }
            return result
        } catch {
            if inFlightID == flightID { clearFlight() }
            throw error
        }
    }

    func cancel() {
        inFlight?.cancel()
        clearFlight()
    }

    func clear() throws {
        cancel()
        try setGate(nil)
    }

    private func clearFlight() {
        inFlight = nil
        inFlightID = nil
        inFlightOwnerID = nil
    }

    private func run(ownerID: String) async throws -> LocationSyncOutcome {
        var pending = try await buffer.points(ownerID: ownerID, now: now())
        var accepted = 0
        var duplicates = 0
        var permanentlyRejected = 0
        var unknownRejected = 0

        while !pending.isEmpty {
            try Task.checkCancellation()
            var batch = try makeBatch(from: pending)
            var attempts = 0
            while true {
                try Task.checkCancellation()
                attempts += 1
                do {
                    let result = try await repository.upload(batch)
                    try Task.checkCancellation()
                    let batchIDs = Set(batch.map(\.pointId))
                    let acceptedIDs = Set(result.accepted).intersection(batchIDs)
                    let duplicateIDs = Set(result.duplicates).intersection(batchIDs).subtracting(acceptedIDs)
                    var toRemove = acceptedIDs.union(duplicateIDs)
                    var handledRejections = Set<UUID>()
                    accepted += acceptedIDs.count
                    duplicates += duplicateIDs.count

                    for rejection in result.rejected {
                        let pointID = rejection.pointId ?? batch[safe: rejection.index]?.pointId
                        guard let pointID, batchIDs.contains(pointID), !toRemove.contains(pointID),
                              handledRejections.insert(pointID).inserted else { continue }
                        if Self.permanentCodes.contains(rejection.code) {
                            toRemove.insert(pointID)
                            permanentlyRejected += 1
                        } else {
                            _ = try await buffer.recordUnknownRejection(pointID: pointID,
                                                                        ownerID: ownerID, now: now())
                            unknownRejected += 1
                        }
                    }
                    try Task.checkCancellation()
                    try await buffer.remove(pointIDs: toRemove, ownerID: ownerID, now: now())
                    pending.removeFirst(batch.count)
                    break
                } catch LocationBatchError.payloadTooLarge {
                    guard batch.count > 1 else { throw LocationBatchError.payloadTooLarge }
                    batch = Array(batch.prefix(batch.count / 2))
                    attempts = 0
                } catch LocationBatchError.rateLimited(let retryAfter) {
                    let delay = Self.retryDelay(retryAfter, now: now())
                    if let delay, delay > 60 {
                        let until = now().addingTimeInterval(delay)
                        try setGate(RetryGate(ownerID: ownerID, notBefore: until))
                        return .deferred(until: until)
                    }
                    guard attempts < 5 else { throw LocationBatchError.rateLimited(retryAfter: retryAfter) }
                    try await sleep(delay ?? backoff(after: attempts))
                } catch LocationBatchError.transient {
                    guard attempts < 5 else { throw LocationBatchError.transient }
                    try await sleep(backoff(after: attempts))
                }
            }
        }
        return .completed(accepted: accepted, duplicates: duplicates,
                          permanentlyRejected: permanentlyRejected, unknownRejected: unknownRejected)
    }

    private func makeBatch(from points: [BufferedLocationPoint]) throws -> [BufferedLocationPoint] {
        var batch: [BufferedLocationPoint] = []
        for point in points.prefix(LocationBatchRepositoryImpl.maxPoints) {
            let candidate = batch + [point]
            let endpoint = LocationEndpoint.batch(LocationBatchRequestDTO(points: candidate.map(LocationBatchPointDTO.init)))
            guard let size = try endpoint.encodedBody()?.count,
                  size < LocationBatchRepositoryImpl.maxBodyBytes else { break }
            batch = candidate
        }
        guard !batch.isEmpty else { throw LocationBatchError.payloadTooLarge }
        return batch
    }

    private func backoff(after attempt: Int) -> TimeInterval {
        let base = min(30, 2 * pow(2, Double(attempt - 1)))
        return base * (1 + min(1, max(0, randomUnit())) * 0.25)
    }

    private static func retryDelay(_ value: String?, now: Date) -> TimeInterval? {
        guard let value else { return nil }
        if let seconds = TimeInterval(value), seconds.isFinite { return max(0, seconds) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        return formatter.date(from: value).map { max(0, $0.timeIntervalSince(now)) }
    }

    private func setGate(_ newValue: RetryGate?) throws {
        if let newValue {
            let data = try BackendJSONCoding.makeEncoder().encode(newValue)
            try data.write(to: gateURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            try Self.excludeFromBackup(gateURL)
        } else if FileManager.default.fileExists(atPath: gateURL.path) {
            try FileManager.default.removeItem(at: gateURL)
        }
        gate = newValue
    }

    private static func excludeFromBackup(_ url: URL) throws {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutable = url
        try mutable.setResourceValues(values)
    }

    private static let permanentCodes: Set<String> = [
        "RECORDED_AT_TOO_OLD", "RECORDED_AT_IN_FUTURE", "INVALID_POINT_ID",
        "INVALID_LATITUDE", "INVALID_LONGITUDE", "INVALID_RECORDED_AT",
        "INVALID_ACCURACY", "INVALID_BATTERY_LEVEL", "INVALID_POINT"
    ]
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
