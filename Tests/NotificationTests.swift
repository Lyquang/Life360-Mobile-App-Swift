import Foundation

@MainActor
private final class NotificationMock: NotificationRepository {
    var preferences = NotificationPreferences()
    var permission: NotificationPermission = .notDetermined
    var requests = 0
    var fail = false
    func refreshPermission() async {}
    func requestPermission() async throws {
        requests += 1
        if fail { throw DomainError.unknown }
        permission = .authorized
    }
    func updatePreferences(_ preferences: NotificationPreferences) { self.preferences = preferences }
}

@main
enum NotificationTests {
    @MainActor
    static func main() async {
        let name = "Notifications.Tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = UserDefaultsNotificationPreferences(defaults: defaults)
        precondition(NotificationDeeplink(userInfo: ["kind": "conversation", "id": "c1"]) == .conversation(id: "c1"))
        precondition(NotificationDeeplink(userInfo: ["kind": "sos", "id": "u1"]) == .sos(userId: "u1"))
        precondition(NotificationDeeplink(userInfo: ["kind": "unknown", "id": "u1"]) == nil)
        precondition(NotificationDeeplink(userInfo: ["kind": "sos", "id": " \n"]) == nil)
        precondition(NotificationDeeplink(userInfo: ["kind": "sos", "id": 12]) == nil)
        precondition(NotificationDeeplink(userInfo: [:]) == nil)
        precondition(store.load(userId: "a") == NotificationPreferences())
        let muted = NotificationPreferences(enabled: false, messages: false, sos: true)
        store.save(muted, userId: "a")
        precondition(store.load(userId: "a") == muted)
        precondition(store.load(userId: "b").enabled)
        precondition(!muted.allows(.sos) && !muted.allows(.member))
        precondition(NotificationPreferences(enabled: true, messages: false, sos: true).allows(.sos))
        precondition(!NotificationPreferences(enabled: true, messages: false, sos: true).allows(.conversation))
        precondition(!NotificationPreferences(enabled: true, messages: true, sos: false).allows(.sos))
        var dedupe = NotificationDeduplicator()
        precondition(dedupe.insert("a"))
        precondition(!dedupe.insert("a"))
        for i in 0..<256 { precondition(dedupe.insert("\(i)")) }
        precondition(dedupe.insert("a"), "Bounded dedupe must evict old events")
        let mock = NotificationMock()
        let model = NotificationSettingsViewModel(repository: mock)
        model.set(\.messages, false)
        model.set(\.enabled, false)
        model.set(\.enabled, true)
        precondition(!mock.preferences.messages && mock.preferences.sos)
        mock.permission = .denied
        await model.refresh()
        precondition(model.permission == .denied)
        precondition(model.preferences.enabled, "OS denial does not erase intent")
        mock.permission = .notDetermined
        await model.requestPermission()
        precondition(model.permission == .authorized && !model.isRequesting)
        mock.fail = true
        await model.requestPermission()
        precondition(model.errorMessage != nil && !model.isRequesting)
        print("PASS: payload validation, account isolation, persistence, toggle policy, bounded dedupe, settings state and error recovery")
    }
}
