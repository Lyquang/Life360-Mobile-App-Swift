import Foundation

final class SOSIncidentRepositoryImpl: SOSIncidentRepository {
    private let api: APIClient

    init(api: APIClient) { self.api = api }

    func create(_ intent: SOSCreationIntent, expectedSessionGeneration: Int) async throws -> SOSCreated {
        let dto: SOSCreatedDTO = try await request(SOSEndpoint.create(intent), statuses: [200, 201],
                                                  expectedSessionGeneration: expectedSessionGeneration)
        return SOSCreated(created: dto.created, incident: try dto.incident.toDomain())
    }

    func list(status: SOSListFilter = .active, limit: Int = 50, cursor: String? = nil) async throws -> SOSIncidentPage {
        let dto: SOSPageDTO = try await request(SOSEndpoint.list(status: status, limit: limit, cursor: cursor))
        return try dto.toDomain()
    }

    func detail(id: String, limit: Int = 50, afterId: String? = nil) async throws -> SOSDetail {
        let dto: SOSDetailDTO = try await request(SOSEndpoint.detail(id: id, limit: limit, afterId: afterId))
        guard dto.incident.id == id.lowercased() else { throw SOSFailure.invalidResponse }
        return try dto.toDomain()
    }

    func respond(id: String, expectedSessionGeneration: Int) async throws -> SOSAssistanceResult {
        let dto: SOSAssistanceResultDTO = try await request(SOSEndpoint.respond(id: id), statuses: [200, 201],
                                                            expectedSessionGeneration: expectedSessionGeneration)
        guard dto.revision >= 1, dto.sosId == id.lowercased() else { throw SOSFailure.invalidResponse }
        return SOSAssistanceResult(created: dto.created, sosId: dto.sosId,
                                   revision: dto.revision, response: dto.response.toDomain())
    }

    func close(id: String, status: SOSClosure, expectedSessionGeneration: Int) async throws -> SOSClosed {
        let dto: SOSClosedDTO = try await request(SOSEndpoint.close(id: id, status: status),
                                                  expectedSessionGeneration: expectedSessionGeneration)
        guard dto.incident.id == id.lowercased() else { throw SOSFailure.invalidResponse }
        return SOSClosed(changed: dto.changed, incident: try dto.incident.toDomain())
    }

    private func request<T: Decodable>(_ endpoint: Endpoint, statuses: Set<Int> = [200],
                                       expectedSessionGeneration: Int? = nil) async throws -> T {
        do {
            let result: APIResult<APIResponseDTO<T>>
            if let expectedSessionGeneration {
                result = try await api.sendWithMetadata(endpoint, as: APIResponseDTO<T>.self,
                                                        expectedSessionGeneration: expectedSessionGeneration)
            } else {
                result = try await api.sendWithMetadata(endpoint, as: APIResponseDTO<T>.self)
            }
            guard statuses.contains(result.statusCode), result.value.success, let value = result.value.data else {
                throw SOSFailure.invalidResponse
            }
            return value
        } catch let error as APIError {
            switch error {
            case .unauthorized: throw SOSFailure.unauthorized
            case .rateLimited(let retryAfter): throw SOSFailure.rateLimited(retryAfter: retryAfter)
            case .networkError: throw SOSFailure.network
            case .decodingError: throw SOSFailure.invalidResponse
            case .encodingError, .invalidURL: throw SOSFailure.invalidRequest
            case .serverError: throw SOSFailure.server
            case .unknown: throw SOSFailure.unexpected
            case .http(let status, _, _, _):
                switch status {
                case 400: throw SOSFailure.invalidRequest
                case 401: throw SOSFailure.unauthorized
                case 403: throw SOSFailure.forbidden
                case 404: throw SOSFailure.notFound
                case 409: throw SOSFailure.conflict
                case 413: throw SOSFailure.payloadTooLarge
                case 429: throw SOSFailure.rateLimited(retryAfter: nil)
                case 503: throw SOSFailure.unavailable
                case 500...599: throw SOSFailure.server
                default: throw SOSFailure.unexpected
                }
            }
        }
    }
}
