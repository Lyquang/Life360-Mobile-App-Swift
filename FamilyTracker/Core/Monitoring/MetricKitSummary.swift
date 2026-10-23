import Foundation
import MetricKit

/// Fixed keys only: MetricKit call stacks, metadata and raw JSON never reach disk.
enum MetricKitField: String, Codable, Sendable, CaseIterable {
    case cpuSeconds, foregroundSeconds, backgroundSeconds, backgroundLocationSeconds
    case locationBestSeconds, locationNavigationSeconds, locationTenMetersSeconds
    case locationHundredMetersSeconds, locationKilometerSeconds
    case wifiUploadBytes, wifiDownloadBytes, cellularUploadBytes, cellularDownloadBytes
    case peakMemoryBytes, logicalWriteBytes, averagePixelLuminance
    case scrollHitchRatio, launchSamples, hangSamples, poorCellularSignalShare
    case crashCount, hangDiagnosticCount, launchDiagnosticCount
    case cpuExceptionCount, diskWriteExceptionCount
}

struct MetricKitSummary: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable { case metrics, diagnostics }

    let kind: Kind
    let start: Date
    let end: Date
    let appVersion: String?
    let mixedVersions: Bool
    private(set) var values: [MetricKitField: Double] = [:]

    init?(kind: Kind, start: Date, end: Date, appVersion: String?, mixedVersions: Bool) {
        guard end > start, end.timeIntervalSince(start) <= 7 * 24 * 3_600 else { return nil }
        self.kind = kind
        self.start = start
        self.end = end
        self.mixedVersions = mixedVersions
        self.appVersion = mixedVersions ? nil : Self.safeVersion(appVersion)
    }

    mutating func set(_ field: MetricKitField, _ value: Double?) {
        guard let value, value.isFinite, value >= 0 else { return }
        values[field] = value
    }

    var isValid: Bool {
        end > start && end.timeIntervalSince(start).isFinite
            && end.timeIntervalSince(start) <= 7 * 24 * 3_600
            && values.values.allSatisfy { $0.isFinite && $0 >= 0 }
            && (appVersion == nil || Self.safeVersion(appVersion) == appVersion)
            && (!mixedVersions || appVersion == nil)
    }

    private static func safeVersion(_ version: String?) -> String? {
        guard let version, (1...32).contains(version.count),
              version.unicodeScalars.allSatisfy({ scalar in
                  CharacterSet(charactersIn: "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz.+-_")
                      .contains(scalar)
              }) else { return nil }
        return version
    }

    static func merging(_ existing: [MetricKitSummary], with incoming: [MetricKitSummary]) -> [MetricKitSummary] {
        var result = existing.filter(\.isValid)
        for summary in incoming where summary.isValid {
            result.removeAll {
                $0.kind == summary.kind && $0.start == summary.start && $0.end == summary.end
                    && $0.appVersion == summary.appVersion
            }
            result.append(summary)
        }
        return Array(result.sorted { $0.end < $1.end }.suffix(14))
    }
}

extension MetricKitSummary {
    init?(metricPayload payload: MXMetricPayload) {
        guard let summary = MetricKitSummary(kind: .metrics, start: payload.timeStampBegin,
                                             end: payload.timeStampEnd,
                                             appVersion: payload.latestApplicationVersion,
                                             mixedVersions: payload.includesMultipleApplicationVersions) else { return nil }
        self = summary
        set(.cpuSeconds, Self.seconds(payload.cpuMetrics?.cumulativeCPUTime))
        set(.foregroundSeconds, Self.seconds(payload.applicationTimeMetrics?.cumulativeForegroundTime))
        set(.backgroundSeconds, Self.seconds(payload.applicationTimeMetrics?.cumulativeBackgroundTime))
        set(.backgroundLocationSeconds,
            Self.seconds(payload.applicationTimeMetrics?.cumulativeBackgroundLocationTime))
        let location = payload.locationActivityMetrics
        set(.locationBestSeconds, Self.seconds(location?.cumulativeBestAccuracyTime))
        set(.locationNavigationSeconds, Self.seconds(location?.cumulativeBestAccuracyForNavigationTime))
        set(.locationTenMetersSeconds, Self.seconds(location?.cumulativeNearestTenMetersAccuracyTime))
        set(.locationHundredMetersSeconds, Self.seconds(location?.cumulativeHundredMetersAccuracyTime))
        set(.locationKilometerSeconds, Self.seconds(location?.cumulativeKilometerAccuracyTime))
        let network = payload.networkTransferMetrics
        set(.wifiUploadBytes, Self.bytes(network?.cumulativeWifiUpload))
        set(.wifiDownloadBytes, Self.bytes(network?.cumulativeWifiDownload))
        set(.cellularUploadBytes, Self.bytes(network?.cumulativeCellularUpload))
        set(.cellularDownloadBytes, Self.bytes(network?.cumulativeCellularDownload))
        set(.peakMemoryBytes, Self.bytes(payload.memoryMetrics?.peakMemoryUsage))
        set(.logicalWriteBytes, Self.bytes(payload.diskIOMetrics?.cumulativeLogicalWrites))
        set(.averagePixelLuminance,
            payload.displayMetrics?.averagePixelLuminance?.averageMeasurement
                .converted(to: MXUnitAveragePixelLuminance.apl).value)
        set(.scrollHitchRatio, payload.animationMetrics?.scrollHitchTimeRatio.value)
        set(.launchSamples, Self.durationSampleCount(payload.applicationLaunchMetrics?.histogrammedTimeToFirstDraw))
        set(.hangSamples,
            Self.durationSampleCount(payload.applicationResponsivenessMetrics?.histogrammedApplicationHangTime))
        set(.poorCellularSignalShare, Self.poorSignalShare(payload.cellularConditionMetrics))
    }

    init?(diagnosticPayload payload: MXDiagnosticPayload) {
        var allDiagnostics: [MXDiagnostic] = []
        allDiagnostics.append(contentsOf: payload.crashDiagnostics ?? [])
        allDiagnostics.append(contentsOf: payload.hangDiagnostics ?? [])
        allDiagnostics.append(contentsOf: payload.appLaunchDiagnostics ?? [])
        allDiagnostics.append(contentsOf: payload.cpuExceptionDiagnostics ?? [])
        allDiagnostics.append(contentsOf: payload.diskWriteExceptionDiagnostics ?? [])
        let versions = Set(allDiagnostics.map(\.applicationVersion))
        guard let summary = MetricKitSummary(kind: .diagnostics, start: payload.timeStampBegin,
                                             end: payload.timeStampEnd, appVersion: versions.first,
                                             mixedVersions: versions.count > 1) else { return nil }
        self = summary
        set(.crashCount, payload.crashDiagnostics.map { Double($0.count) })
        set(.hangDiagnosticCount, payload.hangDiagnostics.map { Double($0.count) })
        set(.launchDiagnosticCount, payload.appLaunchDiagnostics.map { Double($0.count) })
        set(.cpuExceptionCount, payload.cpuExceptionDiagnostics.map { Double($0.count) })
        set(.diskWriteExceptionCount, payload.diskWriteExceptionDiagnostics.map { Double($0.count) })
    }

    static func seconds(_ measurement: Measurement<UnitDuration>?) -> Double? {
        measurement?.converted(to: .seconds).value
    }

    static func bytes(_ measurement: Measurement<UnitInformationStorage>?) -> Double? {
        measurement?.converted(to: .bytes).value
    }

    private static func durationSampleCount(_ histogram: MXHistogram<UnitDuration>?) -> Double? {
        guard let histogram else { return nil }
        return histogram.bucketEnumerator.allObjects.compactMap {
            ($0 as? MXHistogramBucket<UnitDuration>)?.bucketCount
        }.reduce(0) { $0 + Double($1) }
    }

    private static func poorSignalShare(_ metric: MXCellularConditionMetric?) -> Double? {
        guard let metric else { return nil }
        let buckets = metric.histogrammedCellularConditionTime.bucketEnumerator.allObjects
            .compactMap { $0 as? MXHistogramBucket<MXUnitSignalBars> }
        let total = buckets.reduce(0) { $0 + Double($1.bucketCount) }
        guard total > 0 else { return nil }
        let poor = buckets.reduce(0) { sum, bucket in
            let upper = bucket.bucketEnd.converted(to: MXUnitSignalBars.bars).value
            return sum + (upper <= 2 ? Double(bucket.bucketCount) : 0)
        }
        return poor / total
    }
}

struct MetricKitSummaryStore {
    private let directory: URL
    private let maxBytes = 128 * 1_024

    init(directory: URL = FileManager.default.urls(for: .applicationSupportDirectory,
                                                   in: .userDomainMask)[0]
        .appendingPathComponent("MetricKitSummaries", isDirectory: true)) {
        self.directory = directory
    }

    func load() -> [MetricKitSummary] {
        guard let data = try? Data(contentsOf: fileURL), data.count <= maxBytes,
              let summaries = try? JSONDecoder().decode([MetricKitSummary].self, from: data)
        else { return [] }
        return Array(summaries.filter(\.isValid).sorted { $0.end < $1.end }.suffix(14))
    }

    func save(_ summaries: [MetricKitSummary]) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var directoryURL = directory
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try directoryURL.setResourceValues(values)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: directory.path)
            var retained = Array(summaries.filter(\.isValid).sorted { $0.end < $1.end }.suffix(14))
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            var data = try encoder.encode(retained)
            while data.count > maxBytes && !retained.isEmpty {
                retained.removeFirst()
                data = try encoder.encode(retained)
            }
            try data.write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: fileURL.path)
        } catch {
            // Monitoring must not interrupt app work.
        }
    }

    func clear() { try? FileManager.default.removeItem(at: directory) }

    private var fileURL: URL { directory.appendingPathComponent("summaries.json") }
}
