import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case vietnamese = "vi"
    case english = "en"

    var id: String { rawValue }
    var nativeName: String { self == .vietnamese ? "Tiếng Việt" : "English" }
    var locale: Locale { Locale(identifier: rawValue) }

    init(locale: Locale) {
        self = locale.language.languageCode?.identifier == "en" ? .english : .vietnamese
    }
}

protocol LanguagePreferencesRepository {
    var language: AppLanguage { get }
    func save(_ language: AppLanguage)
}
