import SwiftUI
import Combine

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var key: String {
        switch self {
        case .system: return "appearance.option.system"
        case .light: return "appearance.option.light"
        case .dark: return "appearance.option.dark"
        }
    }
    var descriptionKey: String {
        switch self {
        case .system: return "appearance.description.system"
        case .light: return "appearance.description.light"
        case .dark: return "appearance.description.dark"
        }
    }
    var symbol: String {
        switch self {
        case .system: return "iphone"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Device-local presentation preference; read before the first app frame.
@MainActor
final class AppearanceSettings: ObservableObject {
    static let preferenceKey = "app.appearance"
    @Published private(set) var selection: AppAppearance
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        selection = defaults.string(forKey: Self.preferenceKey).flatMap(AppAppearance.init(rawValue:)) ?? .system
    }

    func select(_ appearance: AppAppearance) {
        guard selection != appearance else { return }
        defaults.set(appearance.rawValue, forKey: Self.preferenceKey)
        selection = appearance
    }
}
