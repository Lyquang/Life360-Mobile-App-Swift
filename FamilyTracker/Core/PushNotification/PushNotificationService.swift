import UIKit
import UserNotifications


/// Local + remote notification plumbing. Remote push also needs the Push Notifications capability (aps-environment).
@MainActor
final class PushNotificationService: NSObject, ObservableObject, NotificationRepository {
    @Published private(set) var deviceToken: String?
    @Published private(set) var registrationFailed = false
    @Published var pendingDeeplink: NotificationDeeplink?
    private var pendingAccountId: String?
    private(set) var preferences = NotificationPreferences()
    private(set) var permission: NotificationPermission = .notDetermined
    private(set) var userId: String?
    var activeConversationId: String?
    private let store: NotificationPreferencesRepository
    private var deduplicator = NotificationDeduplicator()

    private let center = UNUserNotificationCenter.current()

    init(store: NotificationPreferencesRepository) {
        self.store = store
        super.init()
    }

    func activate(userId: String) {
        if let pendingAccountId, pendingAccountId != userId { pendingDeeplink = nil }
        pendingAccountId = nil
        self.userId = userId
        preferences = store.load(userId: userId)
    }

    func deactivate() {
        userId = nil
        activeConversationId = nil
        pendingDeeplink = nil
        pendingAccountId = nil
        deduplicator = NotificationDeduplicator()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        UIApplication.shared.applicationIconBadgeNumber = 0
    }

    func configure() {
        center.delegate = self
    }

    func refreshPermission() async {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized: permission = .authorized
        case .provisional, .ephemeral: permission = .provisional
        case .denied: permission = .denied
        default: permission = .notDetermined
        }
        if userId != nil, permission == .authorized || permission == .provisional {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func requestPermission() async throws {
        await refreshPermission()
        guard permission == .notDetermined else { return }
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshPermission()
        } catch {
            throw DomainError.server("Không thể xin quyền thông báo. Vui lòng thử lại.")
        }
    }

    func updatePreferences(_ preferences: NotificationPreferences) {
        guard let userId else { return }
        self.preferences = preferences
        store.save(preferences, userId: userId)
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        if !preferences.enabled || !preferences.messages {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }

    func didRegister(deviceToken data: Data) {
        deviceToken = data.map { String(format: "%02x", $0) }.joined()
        registrationFailed = false
        // No device registration API exists yet; this token is NOT server-synced.
    }

    func didFailRegistration() { registrationFailed = true }

    func scheduleLocal(title: String, body: String, deeplink: NotificationDeeplink,
                       identifier: String) async {
        guard let account = userId, preferences.allows(deeplink.kind) else { return }
        if case .conversation(let id) = deeplink,
           activeConversationId == id, UIApplication.shared.applicationState == .active { return }
        let settings = await center.notificationSettings()
        guard userId == account, preferences.allows(deeplink.kind),
              settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional,
              deduplicator.insert(identifier) else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = deeplink.userInfo
        content.userInfo["accountId"] = account
        content.userInfo["eventId"] = identifier
        content.threadIdentifier = "\(deeplink.kind.rawValue).\(deeplink.userInfo["id"] ?? "")"
        content.interruptionLevel = deeplink.kind == .sos ? .timeSensitive : .active
        let requestId = "\(account).\(identifier)"
        do {
            try await center.add(UNNotificationRequest(identifier: requestId, content: content, trigger: nil))
            if userId != account || !preferences.allows(deeplink.kind) {
                center.removePendingNotificationRequests(withIdentifiers: [requestId])
                center.removeDeliveredNotifications(withIdentifiers: [requestId])
            }
        } catch {
            NSLog("Local notification scheduling failed (%@)", String(describing: type(of: error)))
        }
    }
}

extension PushNotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        Task { @MainActor [weak self] in
            guard let self, let account = self.userId,
                  let link = NotificationDeeplink(userInfo: notification.request.content.userInfo),
                  self.preferences.allows(link.kind) else { completionHandler([]); return }
            if let recipient = notification.request.content.userInfo["accountId"] as? String,
               recipient != account { completionHandler([]); return }
            if case .conversation(let id) = link, self.activeConversationId == id {
                completionHandler([]); return
            }
            completionHandler([.banner, .sound, .list])
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let deeplink = NotificationDeeplink(userInfo: response.notification.request.content.userInfo)
        Task { @MainActor [weak self] in
            defer { completionHandler() }
            guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }
            let recipient = response.notification.request.content.userInfo["accountId"] as? String
            if let recipient, let current = self?.userId, recipient != current { return }
            self?.pendingAccountId = recipient
            self?.pendingDeeplink = deeplink
        }
    }
}
