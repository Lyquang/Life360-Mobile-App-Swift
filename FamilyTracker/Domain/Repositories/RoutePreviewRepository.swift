protocol RoutePreviewRepository {
    func preview(origin: GeoPoint, destination: GeoPoint, mode: RouteTravelMode,
                 sessionGeneration: Int) async throws -> RoutePreview
}
