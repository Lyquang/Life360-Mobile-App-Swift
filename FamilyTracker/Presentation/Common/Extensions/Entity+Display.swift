import SwiftUI

enum DisplayFormat {
    static func time(_ date: Date?) -> String {
        L10n.time(date)
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
        case .restaurant:    return L10n.tr("places.category.restaurant")
        case .entertainment: return L10n.tr("places.category.entertainment")
        case .cafe:          return L10n.tr("places.category.cafe")
        case .shopping:      return L10n.tr("places.category.shopping")
        case .other:         return L10n.tr("places.category.other")
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
