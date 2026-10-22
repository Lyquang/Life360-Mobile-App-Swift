import Foundation

protocol LocationSharingRepository {
    func fetch() async throws -> LocationSharingState
    func update(_ change: LocationSharingChange) async throws -> LocationSharingState
}
