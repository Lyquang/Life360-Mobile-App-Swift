import Foundation
import MapKit

/// One instance per search screen; platform objects never cross the Domain boundary.
@MainActor
final class MapKitPlaceSearchService {
    private var completionRequest: MapKitCompletionRequest?
    private var searchRequest: MapKitSearchRequest?
    private var completions: [String: MKLocalSearchCompletion] = [:]

    func suggestions(for query: String, in region: PlaceSearchRegion) async throws -> [PlaceSearchSuggestion] {
        cancel()
        completions.removeAll()
        let request = MapKitCompletionRequest(query: query, region: try mapRegion(region))
        completionRequest = request
        defer { if completionRequest === request { completionRequest = nil } }
        let items = try await request.values()
        try Task.checkCancellation()
        guard completionRequest === request else { throw CancellationError() }
        return items.prefix(10).map { item in
            let id = UUID().uuidString
            completions[id] = item
            return PlaceSearchSuggestion(id: id, title: item.title, subtitle: item.subtitle)
        }
    }

    func search(query: String, in region: PlaceSearchRegion) async throws -> [PlaceSearchResult] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = try mapRegion(region)
        request.resultTypes = [.address, .pointOfInterest]
        return try await perform(request, fallbackName: query)
    }

    func resolve(_ suggestion: PlaceSearchSuggestion, in region: PlaceSearchRegion) async throws -> [PlaceSearchResult] {
        guard let completion = completions[suggestion.id] else { throw PlaceSearchFailure.invalidSelection }
        let request = MKLocalSearch.Request(completion: completion)
        request.region = try mapRegion(region)
        return try await perform(request, fallbackName: suggestion.title)
    }

    func cancel() {
        completionRequest?.cancel()
        completionRequest = nil
        searchRequest?.cancel()
        searchRequest = nil
    }

    private func perform(_ request: MKLocalSearch.Request, fallbackName: String) async throws -> [PlaceSearchResult] {
        cancel()
        let operation = MapKitSearchRequest(request: request)
        searchRequest = operation
        defer { if searchRequest === operation { searchRequest = nil } }
        let response = try await operation.value()
        try Task.checkCancellation()
        guard searchRequest === operation else { throw CancellationError() }
        return response.mapItems.prefix(10).compactMap { item in
            let coordinate = item.placemark.coordinate
            guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
            return PlaceSearchResult(id: UUID().uuidString,
                                     name: item.name ?? fallbackName,
                                     address: item.placemark.title ?? "",
                                     point: GeoPoint(latitude: coordinate.latitude, longitude: coordinate.longitude))
        }
    }

    private func mapRegion(_ region: PlaceSearchRegion) throws -> MKCoordinateRegion {
        guard region.center.latitude.isFinite, region.center.longitude.isFinite,
              abs(region.center.latitude) <= 90, abs(region.center.longitude) <= 180,
              region.latitudeDelta.isFinite, region.longitudeDelta.isFinite,
              region.latitudeDelta > 0, region.longitudeDelta > 0 else { throw PlaceSearchFailure.unavailable }
        return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: region.center.latitude,
                                                                 longitude: region.center.longitude),
                                  span: MKCoordinateSpan(latitudeDelta: min(region.latitudeDelta, 180),
                                                         longitudeDelta: min(region.longitudeDelta, 360)))
    }
}

private func searchFailure(_ error: Error) -> Error {
    if error is CancellationError || (error as NSError).code == NSURLErrorCancelled { return CancellationError() }
    if let error = error as? MKError, error.code == .loadingThrottled { return PlaceSearchFailure.throttled }
    return PlaceSearchFailure.unavailable
}

@MainActor
private final class MapKitCompletionRequest: NSObject, MKLocalSearchCompleterDelegate {
    private let completer = MKLocalSearchCompleter()
    private let query: String
    private var continuation: CheckedContinuation<[MKLocalSearchCompletion], Error>?
    private var deadline: Task<Void, Never>?

    init(query: String, region: MKCoordinateRegion) {
        self.query = query
        super.init()
        completer.region = region
        completer.resultTypes = [.address, .pointOfInterest]
        completer.delegate = self
    }

    func values() async throws -> [MKLocalSearchCompletion] {
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                deadline = Task { [weak self] in
                    do { try await Task.sleep(nanoseconds: 10_000_000_000) } catch { return }
                    self?.finish(.failure(PlaceSearchFailure.unavailable))
                }
                completer.queryFragment = query
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.cancel() }
        }
    }

    func cancel() { finish(.failure(CancellationError())) }
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.finish(.success(self.completer.results))
        }
    }
    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        let failure = searchFailure(error)
        Task { @MainActor [weak self] in self?.finish(.failure(failure)) }
    }

    private func finish(_ result: Result<[MKLocalSearchCompletion], Error>) {
        guard let continuation else { return }
        self.continuation = nil
        deadline?.cancel()
        deadline = nil
        completer.delegate = nil
        completer.cancel()
        continuation.resume(with: result)
    }
}

@MainActor
private final class MapKitSearchRequest {
    private let search: MKLocalSearch
    private var continuation: CheckedContinuation<MKLocalSearch.Response, Error>?
    private var deadline: Task<Void, Never>?

    init(request: MKLocalSearch.Request) { search = MKLocalSearch(request: request) }

    func value() async throws -> MKLocalSearch.Response {
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                deadline = Task { [weak self] in
                    do { try await Task.sleep(nanoseconds: 15_000_000_000) } catch { return }
                    self?.finish(.failure(PlaceSearchFailure.unavailable))
                }
                search.start { [weak self] response, error in
                    Task { @MainActor [weak self] in
                        if let error { self?.finish(.failure(searchFailure(error))) }
                        else if let response { self?.finish(.success(response)) }
                        else { self?.finish(.failure(PlaceSearchFailure.unavailable)) }
                    }
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.cancel() }
        }
    }

    func cancel() { finish(.failure(CancellationError())) }

    private func finish(_ result: Result<MKLocalSearch.Response, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        deadline?.cancel()
        deadline = nil
        search.cancel()
        continuation.resume(with: result)
    }
}
