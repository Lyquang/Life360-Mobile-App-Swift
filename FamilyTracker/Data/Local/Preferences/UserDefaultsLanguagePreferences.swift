import Foundation

final class UserDefaultsLanguagePreferences: LanguagePreferencesRepository {
    static let key = "app.language"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var language: AppLanguage {
        defaults.string(forKey: Self.key).flatMap(AppLanguage.init(rawValue:)) ?? .vietnamese
    }

    func save(_ language: AppLanguage) {
        defaults.set(language.rawValue, forKey: Self.key)
    }
}
