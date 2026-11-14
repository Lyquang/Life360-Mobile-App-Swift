import Foundation
import SwiftUI

@main
struct AppearanceTests {
    @MainActor static func main() {
        let name = "FamilyTracker.AppearanceTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: name) else { fatalError("No isolated defaults") }
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppearanceSettings(defaults: defaults)
        precondition(settings.selection == .system && settings.selection.colorScheme == nil)
        settings.select(.dark)
        precondition(AppearanceSettings(defaults: defaults).selection == .dark)
        precondition(settings.selection.colorScheme == .dark)
        settings.select(.light)
        precondition(AppearanceSettings(defaults: defaults).selection.colorScheme == .light)
        settings.select(.system)
        precondition(AppearanceSettings(defaults: defaults).selection.colorScheme == nil)
        defaults.set("unknown-future-value", forKey: AppearanceSettings.preferenceKey)
        precondition(AppearanceSettings(defaults: defaults).selection == .system)
        print("PASS: system default, persisted light/dark/system, synchronous restore, invalid fallback")
    }
}
