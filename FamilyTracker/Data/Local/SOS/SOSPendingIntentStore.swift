import Foundation

enum SOSPendingStoreError: Error, Equatable {
    case invalidOwner, invalidIntent, corruptData, tooLarge, inactiveSession
}

struct SOSPendingSession: Equatable, Sendable {
    fileprivate let ownerID: String
    fileprivate let generation: UUID
}

/// Serializes access to one durable pending intent; no network operation lives here.
actor SOSPendingIntentStore {
    private let fileURL: URL
    private let fileManager: FileManager
    private static let maxBytes = 16 * 1_024
    private var activeSession: SOSPendingSession?

    init(fileURL: URL? = nil, fileManager: FileManager = .default) throws {
        self.fileManager = fileManager
        if let fileURL { self.fileURL = fileURL }
        else {
            guard let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                throw CocoaError(.fileNoSuchFile)
            }
            self.fileURL = root.appendingPathComponent("SOSPendingIntent", isDirectory: true)
                .appendingPathComponent("intent.json")
        }
    }

    /// Only session activation may remove data belonging to a previous account.
    func activate(ownerID: String) throws -> SOSPendingSession {
        guard !ownerID.isEmpty else { throw SOSPendingStoreError.invalidOwner }
        activeSession = nil
        if let previous = try load(), previous.ownerID != ownerID { try removeFile() }
        let session = SOSPendingSession(ownerID: ownerID, generation: UUID())
        activeSession = session
        return session
    }

    /// Returns the original record when the same owner already has a pending intent.
    func prepare(session: SOSPendingSession, intent: SOSCreationIntent) throws -> SOSPendingIntent {
        try requireActive(session)
        try validate(ownerID: session.ownerID, intent: intent)
        if let pending = try current(session: session) { return pending }
        let pending = SOSPendingIntent(ownerID: session.ownerID, intent: intent, state: .ready,
                                       attemptCount: 0, notBefore: nil)
        try persist(pending)
        return pending
    }

    func current(session: SOSPendingSession) throws -> SOSPendingIntent? {
        try requireActive(session)
        guard let pending = try load() else { return nil }
        guard pending.ownerID == session.ownerID else { throw SOSPendingStoreError.inactiveSession }
        return pending
    }

    /// Compare the UUID before writing so a late result cannot modify a newer intent.
    @discardableResult
    func update(session: SOSPendingSession, requestID: UUID, state: SOSPendingState,
                attemptCount: Int, notBefore: Date?) throws -> Bool {
        guard attemptCount >= 0, notBefore.map({ $0.timeIntervalSinceReferenceDate.isFinite }) ?? true else {
            throw SOSPendingStoreError.invalidIntent
        }
        guard var pending = try current(session: session), pending.intent.clientRequestId == requestID else {
            return false
        }
        guard attemptCount >= pending.attemptCount else { throw SOSPendingStoreError.invalidIntent }
        pending.state = state
        pending.attemptCount = attemptCount
        pending.notBefore = notBefore
        try persist(pending)
        return true
    }

    /// Clear only the intended record; stale callbacks cannot remove a newer request.
    @discardableResult
    func clear(session: SOSPendingSession, requestID: UUID) throws -> Bool {
        guard let pending = try current(session: session), pending.intent.clientRequestId == requestID else {
            return false
        }
        try removeFile()
        return true
    }

    /// Invalidate the session even if deleting the file fails.
    func endSession(_ session: SOSPendingSession) throws {
        try requireActive(session)
        defer { activeSession = nil }
        try removeFile()
    }

    /// Explicit recovery can clear a damaged file that cannot be decoded.
    func clearAll() throws {
        activeSession = nil
        try removeFile()
    }

    private func requireActive(_ session: SOSPendingSession) throws {
        guard activeSession == session else { throw SOSPendingStoreError.inactiveSession }
    }

    private func load() throws -> SOSPendingIntent? {
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
        guard let size = attributes[.size] as? NSNumber, size.intValue <= Self.maxBytes else {
            throw SOSPendingStoreError.tooLarge
        }
        let data = try Data(contentsOf: fileURL)
        let pending: SOSPendingIntent
        do { pending = try JSONDecoder().decode(SOSPendingIntent.self, from: data) }
        catch { throw SOSPendingStoreError.corruptData }
        do { try validate(ownerID: pending.ownerID, intent: pending.intent) }
        catch { throw SOSPendingStoreError.corruptData }
        guard pending.attemptCount >= 0,
              pending.notBefore.map({ $0.timeIntervalSinceReferenceDate.isFinite }) ?? true else {
            throw SOSPendingStoreError.corruptData
        }
        return pending
    }

    private func persist(_ pending: SOSPendingIntent) throws {
        let data = try JSONEncoder().encode(pending)
        guard data.count <= Self.maxBytes else { throw SOSPendingStoreError.tooLarge }
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        var excludedDirectory = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try excludedDirectory.setResourceValues(values)
        try fileManager.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                                      ofItemAtPath: directory.path)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        try fileManager.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                                      ofItemAtPath: fileURL.path)
    }

    private func removeFile() throws {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try fileManager.removeItem(at: fileURL)
    }

    private func validate(ownerID: String, intent: SOSCreationIntent) throws {
        guard !ownerID.isEmpty else { throw SOSPendingStoreError.invalidOwner }
        guard (intent.message?.trimmingCharacters(in: .whitespacesAndNewlines).utf16.count ?? 0) <= 500 else {
            throw SOSPendingStoreError.invalidIntent
        }
        if let point = intent.location {
            guard point.latitude.isFinite, point.longitude.isFinite,
                  (-90...90).contains(point.latitude), (-180...180).contains(point.longitude),
                  point.recordedAt.map({ $0.timeIntervalSinceReferenceDate.isFinite }) ?? true else {
                throw SOSPendingStoreError.invalidIntent
            }
        }
    }
}
