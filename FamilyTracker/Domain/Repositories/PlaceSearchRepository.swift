import Foundation

@MainActor
protocol PlaceSearchRepository: AnyObject {
    func suggestions(for query: String, in region: PlaceSearchRegion) async throws -> [PlaceSearchSuggestion]
    func search(query: String, in region: PlaceSearchRegion) async throws -> [PlaceSearchResult]
    func resolve(_ suggestion: PlaceSearchSuggestion, in region: PlaceSearchRegion) async throws -> [PlaceSearchResult]
    func cancel()
}

@MainActor
protocol SearchHistoryRepository: AnyObject {
    func recentSearches(for accountID: String) throws -> [RecentPlaceSearch]
    func record(query: String, for accountID: String) throws
    func remove(id: String, for accountID: String) throws
    func clear(for accountID: String) throws
}
