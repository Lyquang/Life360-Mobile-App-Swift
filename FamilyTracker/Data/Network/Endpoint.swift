import Foundation

enum HTTPMethod: String {
    case GET, POST, PUT, PATCH, DELETE
}

struct Endpoint {
    var path: String
    var method: HTTPMethod = .GET
    var query: [URLQueryItem] = []
    var body: [String: Any]? = nil
    var requiresAuth = true
    var headers: [String: String] = ["Accept": "application/json", "Content-Type": "application/json"]
    var payload: (any Encodable)? = nil

    func encodedBody() throws -> Data? {
        do {
            if let payload { return try JSONEncoder().encode(payload) }
            if let body {
                guard JSONSerialization.isValidJSONObject(body) else {
                    throw APIError.encodingError("Invalid JSON body")
                }
                return try JSONSerialization.data(withJSONObject: body)
            }
            return nil
        } catch {
            throw APIError.encodingError(error.localizedDescription)
        }
    }
}

enum APIError: LocalizedError {
    case invalidURL
    case decodingError(String)
    case serverError(String)
    case unauthorized
    case networkError(String)
    case unknown
    case encodingError(String)
    case http(status: Int, code: String?, message: String?, errors: [APIFieldErrorDTO])

    var errorDescription: String? { domainError.errorDescription }

    var domainError: DomainError {
        switch self {
        case .invalidURL:              return .server("URL không hợp lệ")
        case .decodingError(let m):    return .decoding(m)
        case .serverError(let m):      return .server(m)
        case .unauthorized:            return .unauthorized
        case .networkError(let m):     return .network(m)
        case .unknown:                 return .unknown
        case .encodingError:           return .validation("Dữ liệu gửi đi không hợp lệ.")
        case .http(let status, let code, let message, let errors):
            if code == "VALIDATION_ERROR" || status == 400 {
                return .validation(errors.isEmpty ? (message ?? "Dữ liệu không hợp lệ.") : errors.map(\.message).joined(separator: "\n"))
            }
            switch status {
            case 401: return .server(message ?? "Thông tin đăng nhập không hợp lệ.")
            case 403: return .server("Bạn không có quyền truy cập dữ liệu này.")
            case 404: return .server("Không tìm thấy dữ liệu yêu cầu.")
            case 409: return .server(message ?? "Dữ liệu đã tồn tại.")
            case 429: return .server("Quá nhiều yêu cầu. Vui lòng thử lại sau.")
            case 503: return .server("Tính năng tạm thời chưa khả dụng. Vui lòng thử lại sau.")
            default: return .server(message ?? "Không thể kết nối dịch vụ. Vui lòng thử lại.")
            }
        }
    }
}

/// Repository boundary: transport errors never leak past Data.
func withDomainErrors<T>(_ operation: () async throws -> T) async throws -> T {
    do {
        return try await operation()
    } catch let error as APIError {
        throw error.domainError
    }
}
