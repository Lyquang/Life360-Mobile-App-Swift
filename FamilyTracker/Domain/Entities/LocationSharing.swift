import Foundation

struct LocationSharingState: Equatable, Sendable {
    let enabled: Bool
    let pausedUntil: Date?
    let updatedAt: Date?
}

enum LocationSharingChange: Sendable {
    case pause(until: Date?)
    case resume
}

enum LocationSharingFailure: Error {
    case paused
}

enum LocationSharingAccessState: Equatable {
    case checking
    case sharing
    case paused
    case pendingPause
    case unavailable
}
