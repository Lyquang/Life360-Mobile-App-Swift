import SwiftUI

enum DisplayFormat {
    private static let hourMinute: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "vi_VN")
        return formatter
    }()

    static func time(_ date: Date?) -> String {
        guard let date else { return "--:--" }
        return hourMinute.string(from: date)
    }

    static func time(iso: String?) -> String {
        time(ISO8601.date(from: iso))
    }

    static func batteryIconName(for level: Int?) -> String {
        guard let level else { return "battery.100" }
        switch level {
        case 76...100: return "battery.100"
        case 51...75:  return "battery.75"
        case 26...50:  return "battery.50"
        case 11...25:  return "battery.25"
        default:       return "battery.0"
        }
    }

    /// Green < 1h, orange 1–4h, red > 4h.
    static func stayColor(minutes: Int) -> Color {
        switch minutes {
        case 0..<60:   return FTColors.accent
        case 60..<240: return FTColors.warning
        default:       return FTColors.danger
        }
    }
}

extension User {
    var batteryIconName: String { DisplayFormat.batteryIconName(for: batteryLevel) }
}

extension MemberLocation {
    var batteryIconName: String { DisplayFormat.batteryIconName(for: batteryLevel) }
}

extension LocationHistoryEntry {
    var formattedTime: String { date.map { DisplayFormat.time($0) } ?? timestamp }
}

extension StayPoint {
    var arrivalTime: String { DisplayFormat.time(arrivalDate) }
    var departureTime: String { DisplayFormat.time(departureDate) }
}

extension MovingSegment {
    var startTimeFormatted: String { DisplayFormat.time(startDate) }
}

extension PlaceCategory {
    var displayName: String {
        switch self {
        case .restaurant:    return "Nhà hàng"
        case .entertainment: return "Giải trí"
        case .cafe:          return "Cà phê"
        case .shopping:      return "Mua sắm"
        case .other:         return "Khác"
        }
    }

    var iconName: String {
        switch self {
        case .restaurant:    return "fork.knife"
        case .entertainment: return "gamecontroller.fill"
        case .cafe:          return "cup.and.saucer.fill"
        case .shopping:      return "bag.fill"
        case .other:         return "mappin.circle.fill"
        }
    }

    var color: Color {
        let hex: String
        switch self {
        case .restaurant:    hex = "#FF6B6B"
        case .entertainment: hex = "#A855F7"
        case .cafe:          hex = "#F59E0B"
        case .shopping:      hex = "#10B981"
        case .other:         hex = "#6B7280"
        }
        return Color(hex: hex) ?? FTColors.primary
    }
}
