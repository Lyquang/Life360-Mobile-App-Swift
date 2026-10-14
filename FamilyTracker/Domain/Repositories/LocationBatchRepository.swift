import Foundation

struct LocationBatchResult: Equatable, Sendable {
    let accepted: [UUID]
    let duplicates: [UUID]
    let rejected: [LocationBatchRejection]
}

struct LocationBatchRejection: Equatable, Sendable {
    let index: Int
    let pointId: UUID?
    let code: String
    let reason: String
}

enum LocationBatchError: Error {
    case invalidBatch
    case payloadTooLarge
    case rateLimited(retryAfter: String?)
    case unauthorized
    case transient
    case other(DomainError)
}

protocol LocationBatchRepository {
    func upload(_ points: [BufferedLocationPoint]) async throws -> LocationBatchResult
}
