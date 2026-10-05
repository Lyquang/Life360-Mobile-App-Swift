// MARK: - FamilyTrackerApp.swift
// Entry point. Wiring lives in AppContainer (DI) and navigation in AppCoordinator (MVVM-C).

import SwiftUI

@main
struct FamilyTrackerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appCoordinator = AppCoordinator(container: CompositionRoot.container)

    var body: some Scene {
        WindowGroup {
            AppCoordinatorView(coordinator: appCoordinator)
                #if DEBUG
                .modifier(DebugOverlay())
                #endif
        }
    }
}
