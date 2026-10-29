import Foundation

enum SOSEndpoint {
    static func create(_ intent: SOSCreationIntent) throws -> Endpoint {
        // Backend validates JS string length (UTF-16 units), including emoji surrogate pairs.
        guard (intent.message?.trimmingCharacters(in: .whitespacesAndNewlines).utf16.count ?? 0) <= 500 else {
            throw SOSFailure.invalidRequest
        }
        if let location = intent.location {
            guard location.latitude.isFinite, location.longitude.isFinite,
                  (-90...90).contains(location.latitude), (-180...180).contains(location.longitude),
                  location.recordedAt.map({ $0.timeIntervalSince1970.isFinite }) ?? true else {
                throw SOSFailure.invalidRequest
            }
        }
        return Endpoint(path: "/sos", method: .POST, payload: SOSCreateRequestDTO(intent))
    }

    static func list(status: SOSListFilter, limit: Int, cursor: String?) throws -> Endpoint {
        var query = try pagination(limit: limit, value: cursor, key: "cursor")
        query.append(URLQueryItem(name: "status", value: status.rawValue))
        return Endpoint(path: "/sos", query: query)
    }

    static func detail(id: String, limit: Int, afterId: String?) throws -> Endpoint {
        try validateID(id)
        return Endpoint(path: "/sos/\(id.lowercased())", query: try pagination(limit: limit, value: afterId, key: "afterId"))
    }

    static func respond(id: String) throws -> Endpoint {
        try validateID(id)
        return Endpoint(path: "/sos/\(id.lowercased())/responses", method: .POST, payload: SOSStatusRequestDTO(status: "coming"))
    }

    static func close(id: String, status: SOSClosure) throws -> Endpoint {
        try validateID(id)
        return Endpoint(path: "/sos/\(id.lowercased())", method: .PATCH, payload: SOSStatusRequestDTO(status: status.rawValue))
    }

    static func isValidID(_ value: String) -> Bool {
        value.utf8.count == 24 && value.utf8.allSatisfy {
            (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0)
        }
    }

    private static func validateID(_ id: String) throws {
        guard isValidID(id) else { throw SOSFailure.invalidRequest }
    }

    private static func pagination(limit: Int, value: String?, key: String) throws -> [URLQueryItem] {
        guard (1...100).contains(limit) else { throw SOSFailure.invalidRequest }
        var query = [URLQueryItem(name: "limit", value: String(limit))]
        if let value { try validateID(value); query.append(URLQueryItem(name: key, value: value)) }
        return query
    }
}
