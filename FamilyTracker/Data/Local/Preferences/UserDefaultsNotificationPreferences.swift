import Foundation

final class UserDefaultsNotificationPreferences: NotificationPreferencesRepository {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load(userId: String) -> NotificationPreferences {
        guard let value = defaults.dictionary(forKey: "notifications.\(userId)") else { return .init() }
        return NotificationPreferences(enabled: value["enabled"] as? Bool ?? true,
                                       messages: value["messages"] as? Bool ?? true,
                                       sos: value["sos"] as? Bool ?? true)
    }

    func save(_ preferences: NotificationPreferences, userId: String) {
        defaults.set(["enabled": preferences.enabled, "messages": preferences.messages,
                      "sos": preferences.sos], forKey: "notifications.\(userId)")
    }
}
