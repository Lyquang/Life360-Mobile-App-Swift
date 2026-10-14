import Foundation

final class LocationBatchRepositoryImpl: LocationBatchRepository {
    static let maxPoints = 100
    static let maxBodyBytes = 100 * 1024

    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func upload(_ points: [BufferedLocationPoint]) async throws -> LocationBatchResult {
        guard (1...Self.maxPoints).contains(points.count) else { throw LocationBatchError.invalidBatch }
        let endpoint = LocationEndpoint.batch(LocationBatchRequestDTO(points: points.map(LocationBatchPointDTO.init)))
        do {
            guard let body = try endpoint.encodedBody(), body.count < Self.maxBodyBytes else {
                throw LocationBatchError.payloadTooLarge
            }
            let response = try await api.sendWithMetadata(endpoint, as: APIResponseDTO<LocationBatchResultDTO>.self)
            return try response.value.unwrap(fallbackMessage: "Không thể đồng bộ lịch sử vị trí.").toDomain()
        } catch let error as APIError {
            switch error {
            case .rateLimited(let retryAfter): throw LocationBatchError.rateLimited(retryAfter: retryAfter)
            case .http(let status, let code, _, _):
                if status == 413 { throw LocationBatchError.payloadTooLarge }
                if code == "BATCH_LIMIT_EXCEEDED" || status == 400 { throw LocationBatchError.invalidBatch }
                if status == 401 { throw LocationBatchError.unauthorized }
                if status >= 500 { throw LocationBatchError.transient }
                throw LocationBatchError.other(error.domainError)
            case .unauthorized: throw LocationBatchError.unauthorized
            case .networkError: throw LocationBatchError.transient
            default: throw LocationBatchError.other(error.domainError)
            }
        } catch let error as LocationBatchError {
            throw error
        }
    }
}
