import Foundation

enum DomainError: LocalizedError, Equatable {
    case validation(String)
    case unauthorized
    case forbidden
    case network(String)
    case server(String)
    case decoding(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .validation(let message): return message
        case .unauthorized:            return "Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại."
        case .forbidden:               return "Bạn không có quyền truy cập dữ liệu này."
        case .network(let message):    return "Lỗi mạng: \(message)"
        case .server(let message):     return message
        case .decoding(let message):   return "Lỗi parse dữ liệu: \(message)"
        case .unknown:                 return "Lỗi không xác định"
        }
    }
}
