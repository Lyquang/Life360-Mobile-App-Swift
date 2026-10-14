import Foundation

/// A bounded, owner-scoped snapshot. Each JSONL row can be recovered independently.
actor LocationBuffer {
    private struct Row: Codable, Equatable {
        let ownerID: String
        let sequence: UInt64
        var point: BufferedLocationPoint
    }

    private let fileURL: URL
    private let maxPoints: Int
    private let trimmedPoints: Int
    private let recentPoints: Int
    private let maxAge: TimeInterval
    private var rows: [Row]
    private var activeOwnerID: String?
    private var nextSequence: UInt64
    private var needsRepair: Bool
    private(set) var recoveredCorruptRows: Int

    init(
        fileURL: URL? = nil,
        maxPoints: Int = 500,
        trimmedPoints: Int = 400,
        recentPoints: Int = 100,
        maxAge: TimeInterval = 24 * 60 * 60
    ) throws {
        precondition(maxPoints > trimmedPoints && trimmedPoints > recentPoints + 1)
        precondition(maxAge > 0)
        if let fileURL {
            self.fileURL = fileURL
        } else {
            guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                throw CocoaError(.fileNoSuchFile)
            }
            self.fileURL = support.appendingPathComponent("LocationBuffer", isDirectory: true)
                .appendingPathComponent("points.jsonl")
        }
        self.maxPoints = maxPoints
        self.trimmedPoints = trimmedPoints
        self.recentPoints = recentPoints
        self.maxAge = maxAge

        let directory = self.fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Self.excludeFromBackup(directory)
        let loaded = try Self.load(from: self.fileURL)
        rows = loaded.rows
        activeOwnerID = loaded.rows.first?.ownerID
        recoveredCorruptRows = loaded.corruptRows
        needsRepair = loaded.corruptRows > 0
        nextSequence = (loaded.rows.map(\.sequence).max() ?? 0) + 1
        if FileManager.default.fileExists(atPath: self.fileURL.path) {
            try Self.protectAndExclude(self.fileURL)
        }
    }

    func activate(ownerID: String) throws {
        guard !ownerID.isEmpty, activeOwnerID != ownerID else { return }
        if !rows.isEmpty || needsRepair { try persist([]) }
        rows = []
        activeOwnerID = ownerID
        needsRepair = false
        nextSequence = 1
    }

    @discardableResult
    func append(_ point: BufferedLocationPoint, ownerID: String, now: Date = Date()) throws -> Bool {
        guard !ownerID.isEmpty, Self.isValid(point, now: now, maxAge: maxAge) else { return false }
        guard activeOwnerID == nil || activeOwnerID == ownerID else { return false }
        var candidate = currentRows(for: ownerID, now: now)
        if candidate.contains(where: { $0.point.pointId == point.pointId }) { return false }
        if candidate.last?.point.recordedAt == point.recordedAt { return false }
        candidate.append(Row(ownerID: ownerID, sequence: nextSequence, point: point))
        candidate.sort(by: Self.chronologicalOrder)
        if candidate.count > maxPoints {
            candidate = thin(candidate)
        }
        try persist(candidate)
        rows = candidate
        activeOwnerID = ownerID
        needsRepair = false
        nextSequence += 1
        return true
    }

    func points(ownerID: String, now: Date = Date()) throws -> [BufferedLocationPoint] {
        guard !ownerID.isEmpty, activeOwnerID == nil || activeOwnerID == ownerID else { return [] }
        let candidate = currentRows(for: ownerID, now: now)
        if candidate != rows || needsRepair {
            try persist(candidate)
            rows = candidate
            needsRepair = false
        }
        return candidate.map(\.point)
    }

    func remove(pointIDs: Set<UUID>, ownerID: String, now: Date = Date()) throws {
        guard !ownerID.isEmpty, activeOwnerID == ownerID else { return }
        let candidate = currentRows(for: ownerID, now: now).filter { !pointIDs.contains($0.point.pointId) }
        if candidate != rows || needsRepair {
            try persist(candidate)
            rows = candidate
            needsRepair = false
        }
    }

    /// Returns true when an undocumented rejection reached its bounded retry limit.
    @discardableResult
    func recordUnknownRejection(pointID: UUID, ownerID: String, now: Date = Date()) throws -> Bool {
        guard !ownerID.isEmpty, activeOwnerID == ownerID else { return false }
        var candidate = currentRows(for: ownerID, now: now)
        guard let index = candidate.firstIndex(where: { $0.point.pointId == pointID }) else { return false }
        candidate[index].point.recordUnknownRejection()
        let discarded = candidate[index].point.unknownRejectionAttempts >= 3
        if discarded { candidate.remove(at: index) }
        try persist(candidate)
        rows = candidate
        needsRepair = false
        return discarded
    }

    func clear() throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        rows = []
        activeOwnerID = nil
        needsRepair = false
        nextSequence = 1
    }

    private func currentRows(for ownerID: String, now: Date) -> [Row] {
        guard !ownerID.isEmpty else { return [] }
        return rows.filter { $0.ownerID == ownerID && Self.isValid($0.point, now: now, maxAge: maxAge) }
    }

    private func thin(_ candidate: [Row]) -> [Row] {
        let older = Array(candidate.dropFirst().dropLast(recentPoints))
        let olderSlots = trimmedPoints - recentPoints - 1
        guard older.count > olderSlots else { return candidate }
        let first = candidate[0]
        let last = candidate.suffix(recentPoints)
        let firstSequence = older[0].sequence
        let sequenceSpan = older[older.count - 1].sequence - firstSequence
        var selected: [Row] = []
        var start = 0
        for slot in 0..<olderSlots {
            let target = firstSequence + sequenceSpan * UInt64(slot) / UInt64(olderSlots - 1)
            let finalIndex = older.count - (olderSlots - slot)
            var best = start
            while best < finalIndex {
                let next = best + 1
                let currentGap = Self.distance(older[best].sequence, target)
                let nextGap = Self.distance(older[next].sequence, target)
                if nextGap >= currentGap { break }
                best = next
            }
            selected.append(older[best])
            start = best + 1
        }
        return [first] + selected + last
    }

    private func persist(_ candidate: [Row]) throws {
        let encoder = BackendJSONCoding.makeEncoder()
        var data = Data()
        for row in candidate {
            data.append(try encoder.encode(row))
            data.append(0x0A)
        }
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        try Self.protectAndExclude(fileURL)
    }

    private static func load(from fileURL: URL) throws -> (rows: [Row], corruptRows: Int) {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return ([], 0) }
        let data = try Data(contentsOf: fileURL)
        let decoder = BackendJSONCoding.makeDecoder()
        var valid: [Row] = []
        var corrupt = 0
        for line in data.split(separator: 0x0A) {
            guard let row = try? decoder.decode(Row.self, from: Data(line)),
                  !row.ownerID.isEmpty else {
                corrupt += 1
                continue
            }
            valid.append(row)
        }
        let owner = valid.first?.ownerID
        let beforeOwnerFilter = valid.count
        valid = valid.filter { $0.ownerID == owner }
        corrupt += beforeOwnerFilter - valid.count
        valid.sort(by: chronologicalOrder)
        return (valid, corrupt)
    }

    private static func isValid(_ point: BufferedLocationPoint, now: Date, maxAge: TimeInterval) -> Bool {
        guard point.latitude.isFinite, (-90...90).contains(point.latitude),
              point.longitude.isFinite, (-180...180).contains(point.longitude),
              point.accuracy.map({ $0.isFinite && $0 >= 0 }) ?? true,
              point.batteryLevel.map({ $0.isFinite }) ?? true else { return false }
        let age = now.timeIntervalSince(point.recordedAt)
        return age <= maxAge && age >= -60
    }

    private static func chronologicalOrder(_ lhs: Row, _ rhs: Row) -> Bool {
        if lhs.point.recordedAt != rhs.point.recordedAt { return lhs.point.recordedAt < rhs.point.recordedAt }
        return lhs.sequence < rhs.sequence
    }

    private static func distance(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
        lhs > rhs ? lhs - rhs : rhs - lhs
    }

    private static func excludeFromBackup(_ url: URL) throws {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = url
        try mutableURL.setResourceValues(values)
    }

    private static func protectAndExclude(_ url: URL) throws {
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
        try excludeFromBackup(url)
    }
}
