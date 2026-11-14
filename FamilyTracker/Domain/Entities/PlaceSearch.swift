import Foundation

struct PlaceSearchRegion: Equatable, Sendable {
    let center: GeoPoint
    let latitudeDelta: Double
    let longitudeDelta: Double
}

struct PlaceSearchSuggestion: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let subtitle: String
}

struct PlaceSearchResult: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let address: String
    let point: GeoPoint
}

enum PlaceSearchFailure: Error, Equatable {
    case invalidQuery
    case unavailable
    case throttled
    case invalidSelection
    case historyUnavailable
}

enum PlaceSearchQuery {
    static func trimmed(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    static func validated(_ text: String) throws -> String {
        let query = trimmed(text)
        guard (2...200).contains(query.count) else { throw PlaceSearchFailure.invalidQuery }
        return query
    }

    static func key(_ text: String) -> String {
        trimmed(text).folding(options: [.caseInsensitive, .diacriticInsensitive],
                              locale: Locale(identifier: "en_US_POSIX"))
    }
}

struct RecentPlaceSearch: Codable, Identifiable, Equatable, Sendable {
    let query: String
    let lastUsedAt: Date
    var id: String { PlaceSearchQuery.key(query) }
}
