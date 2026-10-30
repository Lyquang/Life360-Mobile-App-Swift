import Foundation

enum SOSLocationFailure: Error, Equatable, Sendable {
    case permissionDenied, permissionRestricted, unavailable, timedOut, invalidFix, busy
}

/// Called only after the user explicitly chooses to include their current location.
@MainActor
protocol SOSLocationProviding: AnyObject {
    func currentLocation() async throws -> SOSLocation
    func cancel()
}
