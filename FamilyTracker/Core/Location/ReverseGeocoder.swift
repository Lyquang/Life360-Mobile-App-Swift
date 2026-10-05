import CoreLocation

/// CLGeocoder wrapper serialised to Apple's ~1 request/second limit.
actor ReverseGeocoder {
    private let geocoder = CLGeocoder()
    private let minInterval: TimeInterval
    private var nextAllowedAt = Date.distantPast

    init(minInterval: TimeInterval = 1.1) {
        self.minInterval = minInterval
    }

    func address(latitude: Double, longitude: Double) async -> String? {
        let now = Date()
        let scheduledAt = max(now, nextAllowedAt)
        nextAllowedAt = scheduledAt.addingTimeInterval(minInterval)
        let wait = scheduledAt.timeIntervalSince(now)
        if wait > 0 {
            try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
        }

        let location = CLLocation(latitude: latitude, longitude: longitude)
        guard let placemark = try? await geocoder.reverseGeocodeLocation(location).first else { return nil }
        return Self.format(placemark)
    }

    private static func format(_ placemark: CLPlacemark) -> String {
        var parts: [String] = []
        if let name = placemark.name, !name.isEmpty { parts.append(name) }
        if let thoroughfare = placemark.thoroughfare { parts.append(thoroughfare) }
        if let subLocality = placemark.subLocality { parts.append(subLocality) }
        if let locality = placemark.locality { parts.append(locality) }

        var seen = Set<String>()
        return parts.filter { seen.insert($0).inserted }.prefix(3).joined(separator: ", ")
    }
}
