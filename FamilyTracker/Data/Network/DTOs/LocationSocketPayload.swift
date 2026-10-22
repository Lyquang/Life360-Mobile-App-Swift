import Foundation

enum LocationSocketPayload {
    static func make(fix: LocationFix, batteryLevel: Int?) -> [String: Any] {
        var payload: [String: Any] = [
            "latitude": fix.latitude,
            "longitude": fix.longitude,
            "recordedAt": ISO8601.string(from: fix.timestamp)
        ]
        if fix.horizontalAccuracy.isFinite, fix.horizontalAccuracy >= 0 {
            payload["accuracy"] = fix.horizontalAccuracy
        }
        if let batteryLevel { payload["batteryLevel"] = batteryLevel }
        return payload
    }
}
