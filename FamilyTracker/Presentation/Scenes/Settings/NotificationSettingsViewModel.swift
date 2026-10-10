import Foundation
import Combine

@MainActor
final class NotificationSettingsViewModel: ObservableObject {
    @Published private(set) var preferences: NotificationPreferences
    @Published private(set) var permission: NotificationPermission = .notDetermined
    @Published private(set) var isRequesting = false
    @Published var errorMessage: String?
    private let repository: NotificationRepository

    init(repository: NotificationRepository) {
        self.repository = repository
        preferences = repository.preferences
    }

    func refresh() async {
        await repository.refreshPermission()
        permission = repository.permission
        preferences = repository.preferences
    }

    func set(_ key: WritableKeyPath<NotificationPreferences, Bool>, _ value: Bool) {
        preferences[keyPath: key] = value
        repository.updatePreferences(preferences)
    }

    func requestPermission() async {
        guard !isRequesting else { return }
        isRequesting = true
        defer { isRequesting = false }
        do { try await repository.requestPermission() }
        catch { errorMessage = error.localizedDescription }
        await refresh()
    }
}
