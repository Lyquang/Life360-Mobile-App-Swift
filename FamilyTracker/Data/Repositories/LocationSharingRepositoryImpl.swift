import Foundation

final class LocationSharingRepositoryImpl: LocationSharingRepository {
    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func fetch() async throws -> LocationSharingState {
        try await request(LocationSharingEndpoint.fetch)
    }

    func update(_ change: LocationSharingChange) async throws -> LocationSharingState {
        try await request(LocationSharingEndpoint.update(change))
    }

    private func request(_ endpoint: Endpoint) async throws -> LocationSharingState {
        do {
            return try await api.send(endpoint, as: APIResponseDTO<LocationSharingStateDTO>.self)
                .unwrap(fallbackMessage: "Không thể tải trạng thái chia sẻ vị trí.")
                .toDomain()
        } catch APIError.http(let status, let code, _, _) where status == 403 && code == "LOCATION_SHARING_PAUSED" {
            throw LocationSharingFailure.paused
        } catch let error as APIError {
            throw error.domainError
        }
    }
}
