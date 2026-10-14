import Foundation
import XCTest
@testable import FamilyTracker

final class LocationBufferTests: XCTestCase {
    private let owner = "owner-a"
    private let start = Date(timeIntervalSince1970: 1_000_000)

    func testHeartbeatWithSameFixTimestampIsNotBufferedTwice() async throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let buffer = try LocationBuffer(fileURL: file)
        let first = point(0)
        let heartbeat = point(0, latitude: 11)

        let inserted = try await buffer.append(first, ownerID: owner, now: start)
        let repeated = try await buffer.append(heartbeat, ownerID: owner, now: start)
        let retained = try await buffer.points(ownerID: owner, now: start)
        XCTAssertTrue(inserted)
        XCTAssertFalse(repeated)
        XCTAssertEqual(retained, [first])
    }

    func testSurvivesRelaunchAndSkipsOnlyCorruptJSONLine() async throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let first = point(0)
        let second = point(1)
        let original = try LocationBuffer(fileURL: file)
        try await original.activate(ownerID: owner)
        try await original.append(first, ownerID: owner, now: start.addingTimeInterval(1))
        try await original.append(second, ownerID: owner, now: start.addingTimeInterval(1))
        var damaged = try Data(contentsOf: file)
        damaged.append(Data("not-json\n".utf8))
        try damaged.write(to: file, options: .atomic)

        let restored = try LocationBuffer(fileURL: file)
        let recovered = await restored.recoveredCorruptRows
        let retained = try await restored.points(ownerID: owner, now: start.addingTimeInterval(1))
        XCTAssertEqual(recovered, 1)
        XCTAssertEqual(retained, [first, second])
        XCTAssertEqual(try Data(contentsOf: file).split(separator: 0x0A).count, 2)
    }

    func testBackupExclusionAndProtectionRemainAfterAtomicReplacements() async throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let buffer = try LocationBuffer(fileURL: file)
        try await buffer.activate(ownerID: owner)

        for index in 0..<4 {
            try await buffer.append(point(index), ownerID: owner, now: start.addingTimeInterval(4))
            let folderValues = try file.deletingLastPathComponent().resourceValues(forKeys: [.isExcludedFromBackupKey])
            let fileValues = try file.resourceValues(forKeys: [.isExcludedFromBackupKey])
            XCTAssertEqual(folderValues.isExcludedFromBackup, true)
            XCTAssertEqual(fileValues.isExcludedFromBackup, true)
            let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
            XCTAssertEqual(attributes[.protectionKey] as? FileProtectionType,
                           .completeUntilFirstUserAuthentication)
        }
    }

    func testThinningPreservesFirstAndNewestHundredAtFiveHundredThreshold() async throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let buffer = try LocationBuffer(fileURL: file)
        try await buffer.activate(ownerID: owner)

        for index in 0...500 {
            try await buffer.append(point(index), ownerID: owner, now: start.addingTimeInterval(500))
        }
        let retained = try await buffer.points(ownerID: owner, now: start.addingTimeInterval(500))
        XCTAssertEqual(retained.count, 400)
        XCTAssertEqual(retained.first?.pointId, point(0).pointId)
        XCTAssertEqual(retained.suffix(100).map(\.pointId), (401...500).map { point($0).pointId })
        XCTAssertEqual(retained.map(\.recordedAt), retained.map(\.recordedAt).sorted())
    }

    func testRepeatedThinningIsDeterministicAndEvenlyDistributed() async throws {
        let firstFile = temporaryFile()
        let secondFile = temporaryFile()
        defer {
            try? FileManager.default.removeItem(at: firstFile.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: secondFile.deletingLastPathComponent())
        }
        let first = try LocationBuffer(fileURL: firstFile, maxPoints: 50, trimmedPoints: 40, recentPoints: 10)
        let second = try LocationBuffer(fileURL: secondFile, maxPoints: 50, trimmedPoints: 40, recentPoints: 10)
        try await first.activate(ownerID: owner)
        try await second.activate(ownerID: owner)
        for index in 0..<304 {
            let item = point(index)
            try await first.append(item, ownerID: owner, now: start.addingTimeInterval(304))
            try await second.append(item, ownerID: owner, now: start.addingTimeInterval(304))
        }
        let firstResult = try await first.points(ownerID: owner, now: start.addingTimeInterval(304))
        let secondResult = try await second.points(ownerID: owner, now: start.addingTimeInterval(304))
        XCTAssertEqual(firstResult, secondResult)
        XCTAssertEqual(firstResult.count, 40)
        XCTAssertEqual(firstResult.first?.pointId, point(0).pointId)
        XCTAssertEqual(firstResult.suffix(10).map(\.pointId), (294..<304).map { point($0).pointId })
        let positions = firstResult.dropFirst().dropLast(10).map { Int($0.recordedAt.timeIntervalSince(start)) }
        XCTAssertEqual(positions, positions.sorted())
        for quartile in 1...3 {
            let sample = positions[positions.count * quartile / 4]
            XCTAssertLessThan(abs(sample - 294 * quartile / 4), 35)
        }
    }

    func testRemoveByPointIdDoesNotDeletePointAppendedDuringSync() async throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let buffer = try LocationBuffer(fileURL: file)
        try await buffer.activate(ownerID: owner)
        try await buffer.append(point(0), ownerID: owner, now: start.addingTimeInterval(2))
        try await buffer.append(point(1), ownerID: owner, now: start.addingTimeInterval(2))
        let inFlight = try await buffer.points(ownerID: owner, now: start.addingTimeInterval(2))
        try await buffer.append(point(2), ownerID: owner, now: start.addingTimeInterval(2))

        try await buffer.remove(pointIDs: Set(inFlight.map(\.pointId)), ownerID: owner,
                                now: start.addingTimeInterval(2))
        let remaining = try await buffer.points(ownerID: owner, now: start.addingTimeInterval(2))
        XCTAssertEqual(remaining, [point(2)])
    }

    func testAccountChangeDeletesOldPointsAndRejectsStaleTasks() async throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let buffer = try LocationBuffer(fileURL: file)
        try await buffer.activate(ownerID: owner)
        try await buffer.append(point(0), ownerID: owner, now: start)
        try await buffer.activate(ownerID: "owner-b")
        let afterSwitch = try await buffer.points(ownerID: "owner-b", now: start)
        XCTAssertTrue(afterSwitch.isEmpty)
        try await buffer.append(point(1), ownerID: "owner-b", now: start.addingTimeInterval(1))

        let oldOwnerView = try await buffer.points(ownerID: owner, now: start.addingTimeInterval(1))
        let staleAppend = try await buffer.append(point(2), ownerID: owner, now: start.addingTimeInterval(2))
        XCTAssertTrue(oldOwnerView.isEmpty)
        XCTAssertFalse(staleAppend)
        try await buffer.remove(pointIDs: [point(1).pointId], ownerID: owner, now: start.addingTimeInterval(2))
        let newOwnerView = try await buffer.points(ownerID: "owner-b", now: start.addingTimeInterval(2))
        XCTAssertEqual(newOwnerView, [point(1)])
        let reopened = try LocationBuffer(fileURL: file)
        let reopenedOldOwnerView = try await reopened.points(ownerID: owner, now: start.addingTimeInterval(2))
        XCTAssertTrue(reopenedOldOwnerView.isEmpty)
    }

    func testTTLAndUnknownRejectionAttemptsAreBoundedAndDurable() async throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let buffer = try LocationBuffer(fileURL: file)
        try await buffer.activate(ownerID: owner)
        let item = point(0)
        try await buffer.append(item, ownerID: owner, now: start)
        let firstRejected = try await buffer.recordUnknownRejection(pointID: item.pointId, ownerID: owner, now: start)
        XCTAssertFalse(firstRejected)
        let reopened = try LocationBuffer(fileURL: file)
        let restoredPoints = try await reopened.points(ownerID: owner, now: start)
        let restoredAttempts = restoredPoints.first?.unknownRejectionAttempts
        XCTAssertEqual(restoredAttempts, 1)
        let secondRejected = try await reopened.recordUnknownRejection(pointID: item.pointId, ownerID: owner, now: start)
        let thirdRejected = try await reopened.recordUnknownRejection(pointID: item.pointId, ownerID: owner, now: start)
        let afterRejection = try await reopened.points(ownerID: owner, now: start)
        XCTAssertFalse(secondRejected)
        XCTAssertTrue(thirdRejected)
        XCTAssertTrue(afterRejection.isEmpty)

        try await reopened.append(point(1), ownerID: owner, now: start.addingTimeInterval(1))
        let afterTTL = try await reopened.points(ownerID: owner, now: start.addingTimeInterval(24 * 3600 + 2))
        XCTAssertTrue(afterTTL.isEmpty)
    }

    private func temporaryFile() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("points.jsonl")
    }

    private func point(_ index: Int, latitude: Double? = nil) -> BufferedLocationPoint {
        let fix = LocationFix(latitude: latitude ?? 10 + Double(index) / 10_000, longitude: 106,
                              timestamp: start.addingTimeInterval(Double(index)),
                              horizontalAccuracy: 8, speed: 1, course: 0)
        return BufferedLocationPoint(pointId: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 1))!,
                                     fix: fix, batteryLevel: 80)
    }
}
