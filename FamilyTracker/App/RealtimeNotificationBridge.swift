import UIKit

/// Posts local notifications for realtime alerts when the app is not in the foreground
/// (the in-app banners cover the foreground case).
@MainActor
final class RealtimeNotificationBridge {
    private let observeSOS: ObserveSOSAlertsUseCase
    private let observeStayAlerts: ObserveStayAlertsUseCase
    private let push: PushNotificationService
    private var tasks: [Task<Void, Never>] = []

    init(observeSOS: ObserveSOSAlertsUseCase, observeStayAlerts: ObserveStayAlertsUseCase, push: PushNotificationService) {
        self.observeSOS = observeSOS
        self.observeStayAlerts = observeStayAlerts
        self.push = push
    }

    func start() {
        guard tasks.isEmpty else { return }
        let sosStream = observeSOS()
        let stayStream = observeStayAlerts()

        tasks.append(Task { [weak self] in
            for await alert in sosStream {
                self?.notify(title: "🚨 SOS từ \(alert.name)", body: alert.message, deeplink: .sos(userId: alert.userId))
            }
        })
        tasks.append(Task { [weak self] in
            for await alert in stayStream {
                self?.notify(title: "⏱ \(alert.name)", body: alert.message, deeplink: .member(userId: alert.userId))
            }
        })
    }

    func stop() {
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
    }

    private func notify(title: String, body: String, deeplink: NotificationDeeplink) {
        guard UIApplication.shared.applicationState != .active else { return }
        push.scheduleLocal(title: title, body: body, deeplink: deeplink)
    }
}
