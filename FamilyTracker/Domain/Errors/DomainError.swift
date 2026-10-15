import Foundation

enum DomainError: Error, Equatable {
    case validation(String)
    case unauthorized
    case forbidden
    case network(String)
    case server(String)
    case decoding(String)
    case unknown

}
