import Foundation

@MainActor
final class MapKitPlaceSearchRepository: PlaceSearchRepository {
    private let service: MapKitPlaceSearchService
    init(service: MapKitPlaceSearchService) { self.service = service }

    func suggestions(for query: String, in region: PlaceSearchRegion) async throws -> [PlaceSearchSuggestion] {
        try await service.suggestions(for: query, in: region)
    }
    func search(query: String, in region: PlaceSearchRegion) async throws -> [PlaceSearchResult] {
        try await service.search(query: query, in: region)
    }
    func resolve(_ suggestion: PlaceSearchSuggestion, in region: PlaceSearchRegion) async throws -> [PlaceSearchResult] {
        try await service.resolve(suggestion, in: region)
    }
    func cancel() { service.cancel() }
}
