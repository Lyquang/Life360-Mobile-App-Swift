import Foundation

enum DiagnosticRedactor {
    static func url(_ url: URL) -> URL {
        guard var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        parts.user = nil
        parts.password = nil
        parts.fragment = nil
        parts.queryItems = parts.queryItems?.map {
            URLQueryItem(name: $0.name, value: ["page", "limit"].contains($0.name) ? $0.value : "REDACTED")
        }
        return parts.url ?? url
    }

    static func headers(_ headers: [String: String]) -> [String: String] {
        let allowed = Set(["accept", "content-type", "content-length", "cache-control", "retry-after"])
        return headers.reduce(into: [:]) { result, entry in
            result[entry.key] = allowed.contains(entry.key.lowercased()) ? entry.value : "[REDACTED]"
        }
    }

    static func json(_ value: Any) -> Any {
        if let object = value as? [String: Any] {
            return object.reduce(into: [String: Any]()) { result, entry in
                let key = entry.key.lowercased().filter { $0.isLetter || $0.isNumber }
                let sensitive = ["password", "token", "secret", "authorization", "cookie", "signature", "apikey"].contains { key.contains($0) }
                let personal = ["email", "name", "sendername", "content", "message", "latitude", "longitude",
                                "coordinates", "avatar", "avatarurl", "uploadurl", "fileurl", "attachmenturl", "url"]
                result[entry.key] = sensitive || personal.contains(key) ? "[REDACTED]" : json(entry.value)
            }
        }
        if let array = value as? [Any] { return Array(array.prefix(100)).map(json) }
        return value
    }

    static func body(_ data: Data?) -> Data? {
        guard let data, !data.isEmpty else { return nil }
        guard data.count <= 256_000 else { return Data("[Body omitted: size limit]".utf8) }
        do {
            let object = try JSONSerialization.jsonObject(with: data)
            return try JSONSerialization.data(withJSONObject: json(object), options: [.sortedKeys])
        } catch { return Data("[Non-JSON body omitted]".utf8) }
    }

    static func request(_ request: URLRequest) -> URLRequest {
        var copy = request
        copy.url = request.url.map(url)
        copy.allHTTPHeaderFields = headers(request.allHTTPHeaderFields ?? [:])
        copy.httpBodyStream = nil
        copy.httpBody = body(request.httpBody)
        return copy
    }
}
