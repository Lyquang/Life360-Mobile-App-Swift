import Foundation

struct LocationSharingStateDTO: Decodable {
    let enabled: Bool
    let pausedUntil: Date?
    let updatedAt: Date?

    func toDomain() -> LocationSharingState {
        LocationSharingState(enabled: enabled, pausedUntil: pausedUntil, updatedAt: updatedAt)
    }
}

struct SetLocationSharingRequestDTO: Encodable {
    let enabled: Bool
    let pausedUntil: String?

    init(_ change: LocationSharingChange) {
        switch change {
        case .pause(let until):
            enabled = false
            pausedUntil = until.map(ISO8601.string(from:))
        case .resume:
            enabled = true
            pausedUntil = nil
        }
    }
}
