import Foundation

enum LocationSharingGateError: Error {
    case missingOwner
    case persistenceFailed
}

/// Owner-scoped local privacy state. Unknown server state is deliberately closed.
@MainActor
final class LocationSharingGate {
    private struct Record: Codable {
        let ownerID: String
        var pausePendingSync: Bool
        var pausedUntil: Date?
    }

    private static let storageKey = "com.familytracker.location_sharing_gate"
    private let defaults: UserDefaults
    private var record: Record?
    private var confirmedEnabled = false
    private var hasServerConfirmation = false
    private var checkFailed = false
    private(set) var revision = 0

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey) {
            record = try? JSONDecoder().decode(Record.self, from: data)
        }
    }

    var allowsSharing: Bool {
        hasServerConfirmation && confirmedEnabled && record?.pausePendingSync == false
    }

    var hasPendingPause: Bool { record?.pausePendingSync == true }
    var pendingPauseUntil: Date? { record?.pausePendingSync == true ? record?.pausedUntil : nil }
    var ownerID: String? { record?.ownerID }
    var status: LocationSharingAccessState {
        if hasPendingPause { return .pendingPause }
        if checkFailed { return .unavailable }
        if !hasServerConfirmation { return .checking }
        return confirmedEnabled ? .sharing : .paused
    }

    func activate(ownerID: String) {
        guard !ownerID.isEmpty else { return }
        revision += 1
        if record?.ownerID != ownerID {
            record = Record(ownerID: ownerID, pausePendingSync: false, pausedUntil: nil)
            try? persist()
        }
        hasServerConfirmation = false
        confirmedEnabled = false
        checkFailed = false
    }

    /// Called only after all location producers have stopped.
    func beginPause(until: Date?) throws {
        guard var record else { throw LocationSharingGateError.missingOwner }
        revision += 1
        confirmedEnabled = false
        record.pausePendingSync = true
        record.pausedUntil = until
        self.record = record
        try persist()
    }

    func confirm(_ state: LocationSharingState) {
        guard var record else { return }
        hasServerConfirmation = true
        confirmedEnabled = state.enabled
        checkFailed = false
        if record.pausePendingSync {
            guard !state.enabled, Self.coversRequestedPause(
                requestedUntil: record.pausedUntil, remoteUntil: state.pausedUntil
            ) else { return }
            record.pausePendingSync = false
            record.pausedUntil = state.pausedUntil
            self.record = record
            try? persist()
        }
    }

    func confirmResume(_ state: LocationSharingState) {
        guard state.enabled, var record else { return }
        revision += 1
        record.pausePendingSync = false
        record.pausedUntil = nil
        self.record = record
        confirmedEnabled = true
        hasServerConfirmation = true
        checkFailed = false
        try? persist()
    }

    func expirePendingPause(now: Date = Date()) {
        guard var record, record.pausePendingSync,
              let until = record.pausedUntil, until <= now else { return }
        record.pausePendingSync = false
        record.pausedUntil = nil
        self.record = record
        try? persist()
    }

    func suspendUntilServerCheck() {
        revision += 1
        hasServerConfirmation = false
        confirmedEnabled = false
        checkFailed = false
    }

    func markCheckFailed() {
        confirmedEnabled = false
        hasServerConfirmation = false
        checkFailed = true
    }

    private func persist() throws {
        guard let record else { throw LocationSharingGateError.missingOwner }
        let data = try JSONEncoder().encode(record)
        defaults.set(data, forKey: Self.storageKey)
        guard defaults.synchronize() else { throw LocationSharingGateError.persistenceFailed }
    }

    private static func coversRequestedPause(requestedUntil: Date?, remoteUntil: Date?) -> Bool {
        switch (requestedUntil, remoteUntil) {
        case (nil, nil), (_, nil): return true
        case (nil, _): return false
        case (let requested?, let remote?): return remote >= requested
        }
    }
}
