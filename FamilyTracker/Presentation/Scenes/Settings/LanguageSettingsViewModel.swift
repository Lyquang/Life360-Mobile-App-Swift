import Foundation
import Combine

@MainActor
final class LanguageSettingsViewModel: ObservableObject {
    @Published private(set) var language: AppLanguage
    private let preferences: LanguagePreferencesRepository

    init(preferences: LanguagePreferencesRepository) {
        self.preferences = preferences
        language = preferences.language
        L10n.language = language
    }

    func select(_ language: AppLanguage) {
        guard language != self.language else { return }
        preferences.save(language)
        L10n.language = language
        self.language = language
    }
}
