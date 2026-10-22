import Foundation
import XCTest
@testable import FamilyTracker

@MainActor
final class LocationSharingGateTests: XCTestCase {
    func testUnknownAndPendingStateStayClosedAcrossRelaunch() throws {
        let defaults = makeDefaults()
        let gate = LocationSharingGate(defaults: defaults)
        gate.activate(ownerID: "owner-a")
        XCTAssertFalse(gate.allowsSharing)
        XCTAssertEqual(gate.status, .checking)

        gate.confirm(LocationSharingState(enabled: true, pausedUntil: nil, updatedAt: nil))
        XCTAssertTrue(gate.allowsSharing)
        XCTAssertEqual(gate.status, .sharing)
        try gate.beginPause(until: nil)
        XCTAssertFalse(gate.allowsSharing)
        XCTAssertTrue(gate.hasPendingPause)
        XCTAssertEqual(gate.status, .pendingPause)

        let relaunched = LocationSharingGate(defaults: defaults)
        relaunched.activate(ownerID: "owner-a")
        XCTAssertFalse(relaunched.allowsSharing)
        XCTAssertTrue(relaunched.hasPendingPause)
        relaunched.confirm(LocationSharingState(enabled: true, pausedUntil: nil, updatedAt: nil))
        XCTAssertFalse(relaunched.allowsSharing)
        relaunched.confirm(LocationSharingState(enabled: false, pausedUntil: nil, updatedAt: nil))
        XCTAssertFalse(relaunched.hasPendingPause)
        XCTAssertFalse(relaunched.allowsSharing)
        XCTAssertEqual(relaunched.status, .paused)
    }

    func testAnotherOwnerNeverInheritsPendingPauseOrConfirmedAccess() throws {
        let defaults = makeDefaults()
        let gate = LocationSharingGate(defaults: defaults)
        gate.activate(ownerID: "owner-a")
        try gate.beginPause(until: nil)
        gate.activate(ownerID: "owner-b")
        XCTAssertFalse(gate.hasPendingPause)
        XCTAssertFalse(gate.allowsSharing)

        let relaunched = LocationSharingGate(defaults: defaults)
        relaunched.activate(ownerID: "owner-b")
        XCTAssertFalse(relaunched.hasPendingPause)
        XCTAssertFalse(relaunched.allowsSharing)
    }

    func testRevisionFencesStaleResponsesAndResumeNeedsServerConfirmation() throws {
        let gate = LocationSharingGate(defaults: makeDefaults())
        gate.activate(ownerID: "owner-a")
        let beforePause = gate.revision
        try gate.beginPause(until: nil)
        XCTAssertNotEqual(gate.revision, beforePause)
        gate.confirm(LocationSharingState(enabled: true, pausedUntil: nil, updatedAt: nil))
        XCTAssertFalse(gate.allowsSharing)

        let beforeResume = gate.revision
        gate.suspendUntilServerCheck()
        XCTAssertNotEqual(gate.revision, beforeResume)
        XCTAssertFalse(gate.allowsSharing)
        gate.confirmResume(LocationSharingState(enabled: false, pausedUntil: nil, updatedAt: nil))
        XCTAssertFalse(gate.allowsSharing)
        gate.confirmResume(LocationSharingState(enabled: true, pausedUntil: nil, updatedAt: nil))
        XCTAssertTrue(gate.allowsSharing)
    }

    func testExpiredTimedPauseDoesNotRetryInvalidTimestamp() throws {
        let gate = LocationSharingGate(defaults: makeDefaults())
        gate.activate(ownerID: "owner-a")
        try gate.beginPause(until: Date(timeIntervalSince1970: 100))
        gate.confirm(LocationSharingState(enabled: true, pausedUntil: nil, updatedAt: nil))
        gate.expirePendingPause(now: Date(timeIntervalSince1970: 101))
        XCTAssertFalse(gate.hasPendingPause)
        XCTAssertTrue(gate.allowsSharing)
    }

    func testShorterRemotePauseDoesNotClearPendingRequest() throws {
        let gate = LocationSharingGate(defaults: makeDefaults())
        gate.activate(ownerID: "owner-a")
        let requestedUntil = Date(timeIntervalSince1970: 200)
        try gate.beginPause(until: requestedUntil)
        gate.confirm(LocationSharingState(enabled: false,
                                          pausedUntil: Date(timeIntervalSince1970: 150), updatedAt: nil))
        XCTAssertTrue(gate.hasPendingPause)
        gate.confirm(LocationSharingState(enabled: false, pausedUntil: requestedUntil, updatedAt: nil))
        XCTAssertFalse(gate.hasPendingPause)

        try gate.beginPause(until: nil)
        gate.confirm(LocationSharingState(enabled: false, pausedUntil: requestedUntil, updatedAt: nil))
        XCTAssertTrue(gate.hasPendingPause)
        gate.confirm(LocationSharingState(enabled: false, pausedUntil: nil, updatedAt: nil))
        XCTAssertFalse(gate.hasPendingPause)
    }

    func testFailedServerCheckIsVisibleButCannotOpenSharing() {
        let gate = LocationSharingGate(defaults: makeDefaults())
        gate.activate(ownerID: "owner-a")
        gate.markCheckFailed()
        XCTAssertEqual(gate.status, .unavailable)
        XCTAssertFalse(gate.allowsSharing)
    }

    private func makeDefaults() -> UserDefaults {
        let name = "LocationSharingGateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}
