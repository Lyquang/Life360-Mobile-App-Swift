import Foundation

@MainActor
struct PlaceSearchUseCases {
    let repository: PlaceSearchRepository

    func suggestions(for query: String, in region: PlaceSearchRegion) async throws -> [PlaceSearchSuggestion] {
        try await repository.suggestions(for: PlaceSearchQuery.validated(query), in: region)
    }

    func search(query: String, in region: PlaceSearchRegion) async throws -> [PlaceSearchResult] {
        try await repository.search(query: PlaceSearchQuery.validated(query), in: region)
    }

    func resolve(_ suggestion: PlaceSearchSuggestion, in region: PlaceSearchRegion) async throws -> [PlaceSearchResult] {
        try await repository.resolve(suggestion, in: region)
    }

    func cancel() { repository.cancel() }
}

@MainActor
struct SearchHistoryUseCases {
    let repository: SearchHistoryRepository
    let accountID: String

    func recent() throws -> [RecentPlaceSearch] { try repository.recentSearches(for: accountID) }
    func record(_ query: String) throws {
        try repository.record(query: PlaceSearchQuery.validated(query), for: accountID)
    }
    func remove(_ id: String) throws { try repository.remove(id: id, for: accountID) }
    func clear() throws { try repository.clear(for: accountID) }
}
