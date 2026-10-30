import Foundation

protocol SOSIncidentRepository {
    func create(_ intent: SOSCreationIntent) async throws -> SOSCreated
    func list(status: SOSListFilter, limit: Int, cursor: String?) async throws -> SOSIncidentPage
    func detail(id: String, limit: Int, afterId: String?) async throws -> SOSDetail
    func respond(id: String) async throws -> SOSAssistanceResult
    func close(id: String, status: SOSClosure) async throws -> SOSClosed
}
