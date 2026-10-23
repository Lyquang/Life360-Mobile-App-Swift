import Foundation

struct MobileMetricWindow: Codable, Equatable, Sendable {
    let start: Date
    var counters: [MobileMetricCounter: Int] = [:]
    var latencyBuckets: [MobileEndpointGroup: [Int]] = [:]
    var sentBytes: [MobileNetworkKind: Int] = [:]
    var receivedBytes: [MobileNetworkKind: Int] = [:]
    var secondsByState: [MobileMetricState: Double] = [:]
    var horizontalAccuracyBuckets: [Int] = [0, 0, 0, 0, 0]
    var batteryStart: Int?
    var batteryEnd: Int?
    var bufferDepthLatest: Int?
    var bufferDepthPeak: Int?
    var bufferAgeBucketLatest: Int?
    var locationEmitsByMotion: [MobileMetricState: Int] = [:]
    var socketSentBytesByEvent: [MobileSocketMetricEvent: Int] = [:]
    var socketReceivedBytesByEvent: [MobileSocketMetricEvent: Int] = [:]
    var socketSentBytesByNetwork: [MobileNetworkKind: Int] = [:]
    var socketReceivedBytesByNetwork: [MobileNetworkKind: Int] = [:]
    var socketReadyLatencyBuckets: [Int] = [0, 0, 0, 0]

    // Missing keys are defaults so a new app version can read older aggregate-only windows.
    init(start: Date) { self.start = start }

    private enum CodingKeys: String, CodingKey {
        case start, counters, latencyBuckets, sentBytes, receivedBytes, secondsByState
        case horizontalAccuracyBuckets, batteryStart, batteryEnd
        case bufferDepthLatest, bufferDepthPeak, bufferAgeBucketLatest, locationEmitsByMotion
        case socketSentBytesByEvent, socketReceivedBytesByEvent
        case socketSentBytesByNetwork, socketReceivedBytesByNetwork, socketReadyLatencyBuckets
    }

    init(from decoder: Decoder) throws {
        let data = try decoder.container(keyedBy: CodingKeys.self)
        start = try data.decode(Date.self, forKey: .start)
        counters = try data.decodeIfPresent([MobileMetricCounter: Int].self, forKey: .counters) ?? [:]
        latencyBuckets = try data.decodeIfPresent([MobileEndpointGroup: [Int]].self, forKey: .latencyBuckets) ?? [:]
        sentBytes = try data.decodeIfPresent([MobileNetworkKind: Int].self, forKey: .sentBytes) ?? [:]
        receivedBytes = try data.decodeIfPresent([MobileNetworkKind: Int].self, forKey: .receivedBytes) ?? [:]
        secondsByState = try data.decodeIfPresent([MobileMetricState: Double].self, forKey: .secondsByState) ?? [:]
        horizontalAccuracyBuckets = try data.decodeIfPresent([Int].self, forKey: .horizontalAccuracyBuckets)
            ?? [0, 0, 0, 0, 0]
        batteryStart = try data.decodeIfPresent(Int.self, forKey: .batteryStart)
        batteryEnd = try data.decodeIfPresent(Int.self, forKey: .batteryEnd)
        bufferDepthLatest = try data.decodeIfPresent(Int.self, forKey: .bufferDepthLatest)
        bufferDepthPeak = try data.decodeIfPresent(Int.self, forKey: .bufferDepthPeak)
        bufferAgeBucketLatest = try data.decodeIfPresent(Int.self, forKey: .bufferAgeBucketLatest)
        locationEmitsByMotion = try data.decodeIfPresent([MobileMetricState: Int].self,
                                                       forKey: .locationEmitsByMotion) ?? [:]
        socketSentBytesByEvent = try data.decodeIfPresent([MobileSocketMetricEvent: Int].self,
                                                          forKey: .socketSentBytesByEvent) ?? [:]
        socketReceivedBytesByEvent = try data.decodeIfPresent([MobileSocketMetricEvent: Int].self,
                                                              forKey: .socketReceivedBytesByEvent) ?? [:]
        socketSentBytesByNetwork = try data.decodeIfPresent([MobileNetworkKind: Int].self,
                                                            forKey: .socketSentBytesByNetwork) ?? [:]
        socketReceivedBytesByNetwork = try data.decodeIfPresent([MobileNetworkKind: Int].self,
                                                                forKey: .socketReceivedBytesByNetwork) ?? [:]
        socketReadyLatencyBuckets = try data.decodeIfPresent([Int].self,
                                                             forKey: .socketReadyLatencyBuckets) ?? [0, 0, 0, 0]
    }
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
                && window.horizontalAccuracyBuckets.count == 5
                && window.horizontalAccuracyBuckets.allSatisfy { $0 >= 0 }
                && window.secondsByState.values.allSatisfy { $0.isFinite && $0 >= 0 }
                && (window.batteryStart.map { (0...100).contains($0) } ?? true)
                && (window.batteryEnd.map { (0...100).contains($0) } ?? true)
                && (window.bufferDepthLatest.map { $0 >= 0 } ?? true)
                && (window.bufferDepthPeak.map { $0 >= (window.bufferDepthLatest ?? 0) } ?? true)
                && (window.bufferAgeBucketLatest.map { (0...4).contains($0) } ?? true)
                && window.locationEmitsByMotion.allSatisfy { $0.key.group == .motion && $0.value >= 0 }
                && window.socketSentBytesByEvent.values.allSatisfy { $0 >= 0 }
                && window.socketReceivedBytesByEvent.values.allSatisfy { $0 >= 0 }
                && window.socketSentBytesByNetwork.values.allSatisfy { $0 >= 0 }
                && window.socketReceivedBytesByNetwork.values.allSatisfy { $0 >= 0 }
                && window.socketReadyLatencyBuckets.count == 4
                && window.socketReadyLatencyBuckets.allSatisfy { $0 >= 0 }
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
