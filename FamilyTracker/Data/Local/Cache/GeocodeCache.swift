import Foundation

/// In-memory reverse-geocode cache keyed by ~11m grid cells.
final class GeocodeCache {
    private let lock = NSLock()
    private var storage: [String: String] = [:]

    func address(for point: GeoPoint) -> String? {
        lock.lock(); defer { lock.unlock() }
        return storage[key(point)]
    }

    func store(_ address: String, for point: GeoPoint) {
        lock.lock()
        storage[key(point)] = address
        lock.unlock()
    }

    private func key(_ point: GeoPoint) -> String {
        String(format: "%.4f,%.4f", point.latitude, point.longitude)
    }
}
