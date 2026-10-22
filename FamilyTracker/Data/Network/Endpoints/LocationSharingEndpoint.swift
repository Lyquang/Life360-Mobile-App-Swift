import Foundation

enum LocationSharingEndpoint {
    static let fetch = Endpoint(path: "/privacy/location-sharing")

    static func update(_ change: LocationSharingChange) -> Endpoint {
        Endpoint(path: "/privacy/location-sharing", method: .PATCH,
                 payload: SetLocationSharingRequestDTO(change))
    }
}
