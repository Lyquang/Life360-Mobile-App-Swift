import Foundation

final class LiveTrailRepositoryImpl: LiveTrailRepository {
    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func snapshot(userId: String, date: String, limit: Int = 200) async throws -> LiveTrailSnapshot {
        try await load(LiveTrailEndpoint.snapshot(userId: userId, date: date, limit: limit))
    }

    func catchUp(userId: String, date: String, afterSeq: Int, revision: Int,
                 limit: Int = 200) async throws -> LiveTrailSnapshot {
        try await load(LiveTrailEndpoint.catchUp(userId: userId, date: date, afterSeq: afterSeq,
                                                 revision: revision, limit: limit))
    }

    private func load(_ endpoint: Endpoint) async throws -> LiveTrailSnapshot {
        do {
            let response = try await api.sendWithMetadata(endpoint, as: LiveTrailResponseDTO.self).value
            guard response.success else { throw APIError.serverError("Không thể tải vệt vị trí.") }
            return response.toDomain()
        } catch APIError.rateLimited(let retryAfter) {
            throw LiveTrailLoadError.rateLimited(retryAfter: retryAfter)
        } catch APIError.http(let status, let code, let message, let errors) {
            switch (status, code) {
            case (404, _): throw LiveTrailLoadError.notFound
            case (409, "TRAIL_REVISION_CHANGED"): throw LiveTrailLoadError.revisionChanged
            case (503, _): throw LiveTrailLoadError.unavailable
            case (429, _): throw LiveTrailLoadError.rateLimited(retryAfter: nil)
            default: throw APIError.http(status: status, code: code, message: message, errors: errors).domainError
            }
        } catch let error as APIError {
            throw error.domainError
        }
    }
}
