// MARK: - FamilyTrackerApp.swift
// Entry point. Wiring lives in AppContainer (DI) and navigation in AppCoordinator (MVVM-C).

import SwiftUI

@main
struct FamilyTrackerApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appCoordinator = AppCoordinator(container: CompositionRoot.container)
    @StateObject private var languageSettings = CompositionRoot.container.languageSettings

    var body: some Scene {
        WindowGroup {
            AppCoordinatorView(coordinator: appCoordinator)
                #if DEBUG
                .modifier(DebugOverlay())
                #endif
                .environmentObject(languageSettings)
                .environment(\.locale, languageSettings.language.locale)
                .onChange(of: scenePhase) { phase in
                    guard phase == .active, appCoordinator.state == .authenticated else { return }
                    Task { await CompositionRoot.container.startLocationSharingIfAllowed() }
                }
        }
    }
}
