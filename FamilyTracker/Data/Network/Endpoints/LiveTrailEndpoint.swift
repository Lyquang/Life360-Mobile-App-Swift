import Foundation

enum LiveTrailEndpoint {
    static func snapshot(userId: String, date: String, limit: Int = 200) -> Endpoint {
        Endpoint(path: "/history/\(userId)/journey/trail", query: [
            URLQueryItem(name: "date", value: date),
            URLQueryItem(name: "limit", value: String(limit))
        ])
    }

    static func catchUp(userId: String, date: String, afterSeq: Int,
                        revision: Int, limit: Int = 200) -> Endpoint {
        var endpoint = snapshot(userId: userId, date: date, limit: limit)
        endpoint.query.append(URLQueryItem(name: "afterSeq", value: String(afterSeq)))
        endpoint.query.append(URLQueryItem(name: "revision", value: String(revision)))
        return endpoint
    }
}
