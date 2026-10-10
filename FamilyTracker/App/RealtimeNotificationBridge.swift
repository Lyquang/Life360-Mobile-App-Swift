import UIKit

/// Posts local notifications for realtime alerts when the app is not in the foreground
/// (the in-app banners cover the foreground case).
@MainActor
final class RealtimeNotificationBridge {
    private let observeSOS: ObserveSOSAlertsUseCase
    private let observeStayAlerts: ObserveStayAlertsUseCase
    private let observeMessages: ObserveNewMessagesUseCase
    private let push: PushNotificationService
    private var tasks: [Task<Void, Never>] = []

    init(observeSOS: ObserveSOSAlertsUseCase, observeStayAlerts: ObserveStayAlertsUseCase,
         observeMessages: ObserveNewMessagesUseCase, push: PushNotificationService) {
        self.observeSOS = observeSOS
        self.observeStayAlerts = observeStayAlerts
        self.observeMessages = observeMessages
        self.push = push
    }

    func start() {
        guard tasks.isEmpty else { return }
        let sosStream = observeSOS()
        let stayStream = observeStayAlerts()

        tasks.append(Task { [weak self] in
            for await alert in sosStream {
                guard alert.userId != self?.push.userId else { continue }
                await self?.notify(title: L10n.format("SOS từ %@", alert.name), body: alert.message,
                                   deeplink: .sos(userId: alert.userId),
                                   identifier: "sos.\(alert.userId).\(alert.timestamp)")
            }
        })
        tasks.append(Task { [weak self] in
            for await alert in stayStream {
                await self?.notify(title: alert.name,
                             body: L10n.format("Đã ở đây %@", L10n.duration(minutes: alert.durationMinutes)),
                             deeplink: .member(userId: alert.userId),
                             identifier: "stay.\(alert.userId).\(alert.timestamp).\(alert.durationMinutes)")
            }
        })
        let messages = observeMessages()
        tasks.append(Task { [weak self] in
            for await message in messages {
                guard !Task.isCancelled, message.senderId != self?.push.userId else { continue }
                await self?.push.scheduleLocal(
                    title: message.senderName ?? L10n.text("Tin nhắn mới"),
                    body: message.type == .image ? L10n.text("Đã gửi một ảnh") : message.content,
                    deeplink: .conversation(id: message.conversationId), identifier: "chat.\(message.id)")
            }
        })
    }

    func stop() {
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
    }

    private func notify(title: String, body: String, deeplink: NotificationDeeplink, identifier: String) async {
        guard UIApplication.shared.applicationState != .active else { return }
        await push.scheduleLocal(title: title, body: body, deeplink: deeplink, identifier: identifier)
    }
}
