import Foundation

/// Persists realtime emits made while offline and replays them on reconnect.
/// Items sharing a `coalesceKey` keep only the newest (e.g. location: only the latest position matters).
final class OfflineQueue {
    private struct Item: Codable {
        let id: UUID
        let event: String
        let payload: Data
        let coalesceKey: String?
        let createdAt: Date
    }

    private let fileURL: URL?
    private let maxItems: Int
    private let maxAge: TimeInterval
    private let lock = NSLock()
    private var items: [Item] = []

    init(fileName: String = "offline_queue.json", maxItems: Int = 200, maxAge: TimeInterval = 24 * 3600) {
        self.maxItems = maxItems
        self.maxAge = maxAge
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        if let directory {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        fileURL = directory?.appendingPathComponent(fileName)
        load()
    }

    var count: Int {
        lock.lock(); defer { lock.unlock() }
        return items.count
    }

    func enqueue(event: String, payload: [String: Any], coalesceKey: String? = nil) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        lock.lock()
        if let coalesceKey {
            items.removeAll { $0.coalesceKey == coalesceKey }
        }
        items.append(Item(id: UUID(), event: event, payload: data, coalesceKey: coalesceKey, createdAt: Date()))
        if items.count > maxItems {
            items.removeFirst(items.count - maxItems)
        }
        persistLocked()
        lock.unlock()
    }

    /// Removes and returns all pending, non-expired items in FIFO order.
    func drain() -> [(event: String, payload: [String: Any])] {
        lock.lock()
        let cutoff = Date().addingTimeInterval(-maxAge)
        let pending = items.filter { $0.createdAt >= cutoff }
        items.removeAll()
        persistLocked()
        lock.unlock()

        return pending.compactMap { item in
            guard let payload = (try? JSONSerialization.jsonObject(with: item.payload)) as? [String: Any] else { return nil }
            return (item.event, payload)
        }
    }

    private func load() {
        guard let fileURL, let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Item].self, from: data) else { return }
        items = decoded
    }

    private func persistLocked() {
        guard let fileURL, let data = try? JSONEncoder().encode(items) else { return }
        // Location data is sensitive; still writable while locked after first unlock (background updates).
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
