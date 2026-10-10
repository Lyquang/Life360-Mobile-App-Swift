import Foundation

private func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
}

@main
enum LocalizationTests {
    @MainActor
    static func main() throws {
        let suite = "FamilyTracker.LocalizationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = UserDefaultsLanguagePreferences(defaults: defaults)
        check(preferences.language == .vietnamese, "Default language")
        defaults.set("unsupported", forKey: UserDefaultsLanguagePreferences.key)
        check(preferences.language == .vietnamese, "Invalid preference fallback")

        let model = LanguageSettingsViewModel(preferences: preferences)
        model.select(.english)
        check(model.language == .english && L10n.language == .english, "Immediate change")
        check(UserDefaultsLanguagePreferences(defaults: defaults).language == .english, "Persist selection")
        let restored = LanguageSettingsViewModel(preferences: preferences)
        check(restored.language == .english, "Restore on relaunch")
        check(L10n.text("Đăng nhập") == "Log in", "English lookup")
        check(L10n.text("Đăng nhập", language: .vietnamese) == "Đăng nhập", "Explicit locale")
        check(L10n.text("untranslated-name-100%") == "untranslated-name-100%", "Unknown text preserved")
        check(L10n.format("SOS từ %@", "A 100% %@") == "SOS from A 100% %@", "Safe formatting arguments")
        check(L10n.duration(minutes: 0) == "0 min", "Zero duration")
        check(L10n.duration(minutes: 1) == "1 min", "Single minute")
        check(L10n.duration(minutes: 60) == "1 h", "Hour duration")
        check(L10n.duration(minutes: 80) == "1 h 20 min", "Mixed duration")
        check(L10n.message("Lỗi mạng: timeout") == "Unable to connect. Please try again.", "Network error")
        check(L10n.message("Lỗi parse dữ liệu: raw detail") == "Unable to read the server response.", "Decoding error")
        check(L10n.message("Email không hợp lệ.\nMật khẩu xác nhận không khớp.") ==
              "Please enter a valid email address.\nThe passwords do not match.", "Multiple validation errors")
        check(L10n.message("Custom server message 50%") == "Custom server message 50%", "Server text preserved")
        restored.select(.vietnamese)
        check(L10n.duration(minutes: 80) == "1 giờ 20 phút", "Vietnamese duration")
        check(AppLanguage(locale: Locale(identifier: "en_US")) == .english, "Region locale")

        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("FamilyTracker/Resources")
        let en = try dictionary(root.appendingPathComponent("en.lproj/Localizable.strings"))
        let vi = try dictionary(root.appendingPathComponent("vi.lproj/Localizable.strings"))
        check(Set(en.keys) == Set(vi.keys), "Translation key parity")
        let formatPattern = try NSRegularExpression(pattern: "%((?:[0-9]+\\$)?(?:lld|ld|d|@))")
        func placeholders(_ text: String) -> [String] {
            formatPattern.matches(in: text, range: NSRange(text.startIndex..., in: text)).map {
                String(text[Range($0.range, in: text)!])
            }.sorted()
        }
        for (key, translated) in en {
            check(!translated.isEmpty, "Empty English value: \(key)")
            check(placeholders(key) == placeholders(translated), "Format mismatch: \(key)")
            check(vi[key]?.isEmpty == false, "Empty Vietnamese value: \(key)")
            check(placeholders(key) == placeholders(vi[key]!), "Vietnamese format mismatch: \(key)")
        }
        print("PASS: preference lifecycle, locale lookup, formatting, errors, durations and \(en.count) translations")
    }

    private static func dictionary(_ url: URL) throws -> [String: String] {
        let data = try Data(contentsOf: url)
        return try PropertyListSerialization.propertyList(from: data, format: nil) as! [String: String]
    }
}
