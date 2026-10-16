import Foundation

enum ChatHubFormat {
    static func preview(_ message: ChatMessage?, language: AppLanguage) -> String {
        guard let message else { return L10n.tr("chat.hub.preview.empty", language: language) }
        let body: String
        switch message.type {
        case .text:
            let content = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            body = content.isEmpty ? L10n.tr("chat.hub.preview.empty", language: language) : content
        case .image:
            body = L10n.tr("chat.hub.preview.image", language: language)
        case .voice:
            body = L10n.tr("chat.hub.preview.voice", language: language)
        }
        guard let sender = message.senderName, !sender.isEmpty else { return body }
        return "\(sender): \(body)"
    }

    static func timestamp(_ date: Date?, now: Date, language: AppLanguage, calendar: Calendar) -> String? {
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone

        if calendar.isDate(date, inSameDayAs: now) {
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return L10n.tr("chat.hub.date.yesterday", language: language)
        }
        if let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start,
           date >= weekStart && date <= now {
            formatter.setLocalizedDateFormatFromTemplate("EEEE")
            return formatter.string(from: date)
        }
        formatter.setLocalizedDateFormatFromTemplate("dMMMy")
        return formatter.string(from: date)
    }
}
