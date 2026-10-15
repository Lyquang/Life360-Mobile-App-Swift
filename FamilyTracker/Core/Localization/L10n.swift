import Foundation

enum L10n {
    private static let lock = NSLock()
    private static var selectedLanguage: AppLanguage = .vietnamese
    private static let missingValue = "__FAMILYTRACKER_LOCALIZATION_MISSING_6D7A__"

    // Non-View consumers (for example local notifications) use the same preference.
    static var language: AppLanguage {
        get { lock.lock(); defer { lock.unlock() }; return selectedLanguage }
        set { lock.lock(); selectedLanguage = newValue; lock.unlock() }
    }

    static func text(_ key: String, language: AppLanguage? = nil, bundle: Bundle = .main) -> String {
        lookup(key, language: language, bundle: bundle) ?? key
    }

    static func tr(_ key: String, _ arguments: CVarArg..., language: AppLanguage? = nil) -> String {
        let selected = language ?? self.language
        let resolved = lookup(key, language: selected)
            ?? lookup("localization.missing_translation", language: selected)
            ?? key
        guard !arguments.isEmpty else { return resolved }
        return String(format: resolved, locale: selected.locale, arguments: arguments)
    }

    static func format(_ key: String, _ arguments: CVarArg..., language: AppLanguage? = nil) -> String {
        let selected = language ?? self.language
        return String(format: text(key, language: selected), locale: selected.locale, arguments: arguments)
    }

    static func duration(minutes: Int, language: AppLanguage? = nil) -> String {
        let selected = language ?? self.language
        let value = max(0, minutes)
        if value < 60 { return tr("%lld phút", value, language: selected) }
        if value % 60 == 0 { return tr("%lld giờ", value / 60, language: selected) }
        return tr("%lld giờ %lld phút", value / 60, value % 60, language: selected)
    }

    static func plural(_ key: String, count: Int, language: AppLanguage? = nil) -> String {
        let selected = language ?? self.language
        let form = selected == .english && count == 1 ? "one" : "other"
        return tr("\(key).\(form)", count, language: selected)
    }

    static func time(_ date: Date?, language: AppLanguage? = nil) -> String {
        guard let date else { return "--:--" }
        let formatter = DateFormatter()
        formatter.locale = (language ?? self.language).locale
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    // Only app-owned error prefixes are normalized; unknown server text stays verbatim.
    static func message(_ value: String, language: AppLanguage? = nil) -> String {
        if value.hasPrefix("Lỗi mạng:") { return tr("Không thể kết nối mạng. Vui lòng thử lại.", language: language) }
        if value.hasPrefix("Lỗi parse dữ liệu:") { return tr("Không thể đọc dữ liệu từ máy chủ.", language: language) }
        return value.components(separatedBy: "\n").map { line in
            lookup(line, language: language) == nil ? line : tr(line, language: language)
        }.joined(separator: "\n")
    }

    private static func lookup(_ key: String, language: AppLanguage?, bundle: Bundle = .main) -> String? {
        let selected = language ?? self.language
        guard let path = bundle.path(forResource: selected.rawValue, ofType: "lproj"),
              let localized = Bundle(path: path) else { return nil }
        let value = localized.localizedString(forKey: key, value: missingValue, table: "Localizable")
        return value == missingValue ? nil : value
    }
}
