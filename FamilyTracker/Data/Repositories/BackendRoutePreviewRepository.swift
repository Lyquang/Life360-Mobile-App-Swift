import Foundation

final class BackendRoutePreviewRepository: RoutePreviewRepository {
    private let api: APIClient

    init(api: APIClient) { self.api = api }

    func preview(origin: GeoPoint, destination: GeoPoint, mode: RouteTravelMode,
                 sessionGeneration: Int) async throws -> RoutePreview {
        let endpoint = Endpoint(path: "/routes/preview", method: .POST, body: [
            "origin": ["latitude": origin.latitude, "longitude": origin.longitude],
            "destination": ["latitude": destination.latitude, "longitude": destination.longitude],
            "travelMode": mode.rawValue
        ])
        do {
            let response = try await api.sendWithMetadata(endpoint, as: APIResponseDTO<RoutePreviewDTO>.self,
                                                          expectedSessionGeneration: sessionGeneration)
            let dto = try response.value.unwrap(fallbackMessage: "Không thể tải tuyến đường.")
            guard dto.travelMode == mode else { throw RoutePreviewFailure.invalidResponse }
            return try dto.toDomain()
        } catch APIError.rateLimited {
            throw RoutePreviewFailure.quota
        } catch APIError.http(_, let code, _, _) where code == "ROUTE_QUOTA_EXCEEDED" {
            throw RoutePreviewFailure.quota
        } catch APIError.unauthorized {
            throw RoutePreviewFailure.unauthorized
        } catch APIError.networkError {
            throw RoutePreviewFailure.offline
        } catch is APIError {
            throw RoutePreviewFailure.unavailable
        }
    }
}
