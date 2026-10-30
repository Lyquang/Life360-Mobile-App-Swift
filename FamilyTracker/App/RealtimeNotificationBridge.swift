import UIKit

/// Posts local notifications for realtime alerts when the app is not in the foreground
/// (the in-app banners cover the foreground case).
@MainActor
final class RealtimeNotificationBridge {
    private let observeStayAlerts: ObserveStayAlertsUseCase
    private let push: PushNotificationService
    private var tasks: [Task<Void, Never>] = []

    init(observeStayAlerts: ObserveStayAlertsUseCase, push: PushNotificationService) {
        self.observeStayAlerts = observeStayAlerts
        self.push = push
    }

    func start() {
        guard tasks.isEmpty else { return }
        let stayStream = observeStayAlerts()
        tasks.append(Task { [weak self] in
            for await alert in stayStream {
                self?.notify(title: alert.name,
                             body: L10n.tr("notification.stay.body", L10n.duration(minutes: alert.durationMinutes)),
                             deeplink: .member(userId: alert.userId))
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
