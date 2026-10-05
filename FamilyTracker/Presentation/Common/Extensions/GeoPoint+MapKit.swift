import MapKit

extension GeoPoint {
    init(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

extension MemberLocation {
    var coordinate: CLLocationCoordinate2D { point.coordinate }
}

extension LocationHistoryEntry {
    var coordinate: CLLocationCoordinate2D { point.coordinate }
}

extension StayPoint {
    var coordinate: CLLocationCoordinate2D { point.coordinate }
}

extension MovingSegment {
    var polylineCoordinates: [CLLocationCoordinate2D] { path.map(\.coordinate) }
}

extension FavoritePlace {
    var coordinate: CLLocationCoordinate2D? { point?.coordinate }
}

extension MKCoordinateRegion {
    /// Ho Chi Minh City.
    static let defaultCity = MKCoordinateRegion(center: GeoPoint(latitude: 10.7769, longitude: 106.7009).coordinate, delta: 0.05)

    init(center: CLLocationCoordinate2D, delta: CLLocationDegrees) {
        self.init(center: center, span: MKCoordinateSpan(latitudeDelta: delta, longitudeDelta: delta))
    }

    /// Smallest region containing all coordinates, padded.
    init?(fitting coordinates: [CLLocationCoordinate2D], padding: Double = 1.3, minimumDelta: Double = 0.005) {
        let lats = coordinates.map(\.latitude)
        let lngs = coordinates.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLng = lngs.min(), let maxLng = lngs.max() else { return nil }
        self.init(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLng + maxLng) / 2),
            span: MKCoordinateSpan(
                latitudeDelta: max((maxLat - minLat) * padding, minimumDelta),
                longitudeDelta: max((maxLng - minLng) * padding, minimumDelta)
            )
        )
    }
}
