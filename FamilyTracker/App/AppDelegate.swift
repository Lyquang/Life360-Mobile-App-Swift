import UIKit

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    private var container: AppContainer { CompositionRoot.container }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        container.pushService.configure()
        // Relaunched by significant-location-change / region monitoring while terminated.
        if launchOptions?[.location] != nil {
            container.resumeBackgroundSharingIfPossible()
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        container.pushService.didRegister(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Expected until the Push Notifications capability is enabled for the app ID.
    }
}
