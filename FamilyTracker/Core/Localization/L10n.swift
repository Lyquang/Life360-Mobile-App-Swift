import Foundation

enum L10n {
    private static let lock = NSLock()
    private static var selectedLanguage: AppLanguage = .vietnamese

    // Non-View consumers (for example local notifications) use the same preference.
    static var language: AppLanguage {
        get { lock.lock(); defer { lock.unlock() }; return selectedLanguage }
        set { lock.lock(); selectedLanguage = newValue; lock.unlock() }
    }

    static func text(_ key: String, language: AppLanguage? = nil, bundle: Bundle = .main) -> String {
        let selected = language ?? self.language
        guard let path = bundle.path(forResource: selected.rawValue, ofType: "lproj"),
              let localized = Bundle(path: path) else { return key }
        return localized.localizedString(forKey: key, value: key, table: "Localizable")
    }

    static func format(_ key: String, _ arguments: CVarArg..., language: AppLanguage? = nil) -> String {
        let selected = language ?? self.language
        return String(format: text(key, language: selected), locale: selected.locale, arguments: arguments)
    }

    static func duration(minutes: Int, language: AppLanguage? = nil) -> String {
        let selected = language ?? self.language
        let value = max(0, minutes)
        if value < 60 { return format("%lld phút", value, language: selected) }
        if value % 60 == 0 { return format("%lld giờ", value / 60, language: selected) }
        return format("%lld giờ %lld phút", value / 60, value % 60, language: selected)
    }

    // Only app-owned error prefixes are normalized; unknown server text stays verbatim.
    static func message(_ value: String, language: AppLanguage? = nil) -> String {
        if value.hasPrefix("Lỗi mạng:") { return text("Không thể kết nối mạng. Vui lòng thử lại.", language: language) }
        if value.hasPrefix("Lỗi parse dữ liệu:") { return text("Không thể đọc dữ liệu từ máy chủ.", language: language) }
        return value.components(separatedBy: "\n").map { text($0, language: language) }.joined(separator: "\n")
    }
}
