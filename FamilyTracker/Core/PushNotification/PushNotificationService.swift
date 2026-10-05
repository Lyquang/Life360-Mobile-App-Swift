import UIKit
import UserNotifications

/// Where a tapped notification should take the user.
enum NotificationDeeplink: Equatable {
    case sos(userId: String)
    case member(userId: String)
    case conversation(id: String)

    init?(userInfo: [AnyHashable: Any]) {
        guard let kind = userInfo["kind"] as? String, let id = userInfo["id"] as? String else { return nil }
        switch kind {
        case "sos": self = .sos(userId: id)
        case "member": self = .member(userId: id)
        case "conversation": self = .conversation(id: id)
        default: return nil
        }
    }

    var userInfo: [String: String] {
        switch self {
        case .sos(let id): return ["kind": "sos", "id": id]
        case .member(let id): return ["kind": "member", "id": id]
        case .conversation(let id): return ["kind": "conversation", "id": id]
        }
    }
}

/// Local + remote notification plumbing. Remote push also needs the Push Notifications capability (aps-environment).
@MainActor
final class PushNotificationService: NSObject, ObservableObject {
    @Published private(set) var deviceToken: String?
    @Published var pendingDeeplink: NotificationDeeplink?

    private let center = UNUserNotificationCenter.current()

    func configure() {
        center.delegate = self
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        if granted {
            UIApplication.shared.registerForRemoteNotifications()
        }
        return granted
    }

    func didRegister(deviceToken data: Data) {
        deviceToken = data.map { String(format: "%02x", $0) }.joined()
    }

    func scheduleLocal(title: String, body: String, deeplink: NotificationDeeplink?, identifier: String = UUID().uuidString) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let deeplink { content.userInfo = deeplink.userInfo }
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil))
    }
}

extension PushNotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let deeplink = NotificationDeeplink(userInfo: response.notification.request.content.userInfo)
        Task { @MainActor in
            self.pendingDeeplink = deeplink
        }
        completionHandler()
    }
}
