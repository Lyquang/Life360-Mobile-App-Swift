import Foundation

protocol NotificationPreferencesRepository {
    func load(userId: String) -> NotificationPreferences
    func save(_ preferences: NotificationPreferences, userId: String)
}

@MainActor
protocol NotificationRepository: AnyObject {
    var preferences: NotificationPreferences { get }
    var permission: NotificationPermission { get }
    func refreshPermission() async
    func requestPermission() async throws
    func updatePreferences(_ preferences: NotificationPreferences)
}
