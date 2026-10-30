import Foundation

protocol SOSIncidentRepository {
    func create(_ intent: SOSCreationIntent, expectedSessionGeneration: Int) async throws -> SOSCreated
    func list(status: SOSListFilter, limit: Int, cursor: String?) async throws -> SOSIncidentPage
    func detail(id: String, limit: Int, afterId: String?) async throws -> SOSDetail
    func respond(id: String, expectedSessionGeneration: Int) async throws -> SOSAssistanceResult
    func close(id: String, status: SOSClosure, expectedSessionGeneration: Int) async throws -> SOSClosed
}

extension SOSIncidentRepository {
    /// Mock/alternate repositories must explicitly support the session-fenced operation.
    func create(_ intent: SOSCreationIntent, expectedSessionGeneration: Int) async throws -> SOSCreated {
        throw CancellationError()
    }
    func respond(id: String, expectedSessionGeneration: Int) async throws -> SOSAssistanceResult {
        throw CancellationError()
    }
    func close(id: String, status: SOSClosure, expectedSessionGeneration: Int) async throws -> SOSClosed {
        throw CancellationError()
    }
}
