import Foundation

struct MobileMetricWindow: Codable, Equatable, Sendable {
    let start: Date
    var counters: [MobileMetricCounter: Int] = [:]
    var latencyBuckets: [MobileEndpointGroup: [Int]] = [:]
    var sentBytes: [MobileNetworkKind: Int] = [:]
    var receivedBytes: [MobileNetworkKind: Int] = [:]
}

struct MobileMetricsStore {
    private let directory: URL
    private let fileManager: FileManager
    private let maxBytes = 256 * 1_024

    init(directory: URL, fileManager: FileManager = .default) {
        self.directory = directory
        self.fileManager = fileManager
    }

    static var appStore: MobileMetricsStore {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return MobileMetricsStore(directory: root.appendingPathComponent("MobileMetrics", isDirectory: true))
    }

    func load() -> [MobileMetricWindow] {
        guard let data = try? Data(contentsOf: fileURL), data.count <= maxBytes,
              let windows = try? JSONDecoder().decode([MobileMetricWindow].self, from: data)
        else { return [] }
        return Array(windows.filter { window in
            window.latencyBuckets.values.allSatisfy { buckets in
                buckets.count == 4 && buckets.allSatisfy { $0 >= 0 }
            } && window.counters.values.allSatisfy { $0 >= 0 }
                && window.sentBytes.values.allSatisfy { $0 >= 0 }
                && window.receivedBytes.values.allSatisfy { $0 >= 0 }
        }.suffix(96))
    }

    func save(_ windows: [MobileMetricWindow]) {
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var directoryURL = directory
            try directoryURL.setResourceValues(values)
            try fileManager.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: directory.path
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            var retained = Array(windows.suffix(96))
            var data = try encoder.encode(retained)
            while data.count > maxBytes && !retained.isEmpty {
                retained.removeFirst()
                data = try encoder.encode(retained)
            }
            try data.write(to: fileURL, options: .atomic)
            try fileManager.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: fileURL.path
            )
        } catch {
            // Diagnostics must never interrupt app work.
        }
    }

    func clear() {
        try? fileManager.removeItem(at: directory)
    }

    private var fileURL: URL { directory.appendingPathComponent("windows.json") }
}
