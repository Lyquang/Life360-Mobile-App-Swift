import Foundation

struct BufferedLocationPoint: Codable, Equatable, Sendable {
    let pointId: UUID
    let latitude: Double
    let longitude: Double
    let recordedAt: Date
    let accuracy: Double?
    let batteryLevel: Double?
    private(set) var unknownRejectionAttempts: Int = 0

    init(pointId: UUID = UUID(), fix: LocationFix, batteryLevel: Int?) {
        self.pointId = pointId
        latitude = fix.latitude
        longitude = fix.longitude
        recordedAt = fix.timestamp
        accuracy = fix.horizontalAccuracy >= 0 ? fix.horizontalAccuracy : nil
        self.batteryLevel = batteryLevel.map(Double.init)
    }

    mutating func recordUnknownRejection() {
        unknownRejectionAttempts += 1
    }
}
