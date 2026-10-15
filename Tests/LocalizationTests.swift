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
        check(L10n.tr("Đăng nhập") == "Log in", "L10n.tr lookup")
        check(L10n.tr("circles.error.not_yet_translated") == "This text is not available.", "Missing key fallback")
        check(L10n.tr("circles.error.not_yet_translated", language: .vietnamese) ==
              "Nội dung này hiện chưa có bản dịch.", "Vietnamese missing key fallback")
        check(L10n.tr("Nhắn tin cho %@", "Quang") == "Message Quang", "L10n.tr formatting")
        check(L10n.tr("Đăng nhập", language: .vietnamese) == "Đăng nhập",
              "A valid Vietnamese translation may equal its source key")
        check(L10n.tr("voice.error.permission_denied") == "Allow microphone access in Settings to send a voice message.",
              "English voice permission copy")
        check(L10n.tr("voice.error.permission_denied", language: .vietnamese) ==
              "Vui lòng cấp quyền micro trong Cài đặt để gửi tin nhắn thoại.", "Vietnamese voice permission copy")
        check(L10n.tr("voice.error.could_not_start") == "Could not start recording.", "English recorder error copy")
        check(L10n.tr("voice.error.invalid_recording") == "This recording is not valid.", "English invalid recording copy")
        check(L10n.tr("notification.sos.title", "Alex", language: .english) == "SOS from Alex",
              "Notification templates must translate while preserving member names")
        check(L10n.tr("Nhập mật khẩu", language: .english) == "Enter your password",
              "Form placeholders must use the selected language")
        let vietnameseLongName = "Nguyễn Hoàng Minh Anh Với Một Cái Tên Rất Dài"
        check(L10n.tr("journey.title.member", vietnameseLongName, language: .english)
              == "\(vietnameseLongName)'s journey", "Formatted copy must preserve long names and diacritics")
        check(L10n.text("Đăng nhập", language: .vietnamese) == "Đăng nhập", "Explicit locale")
        check(L10n.text("untranslated-name-100%") == "untranslated-name-100%", "Unknown text preserved")
        check(L10n.format("SOS từ %@", "A 100% %@") == "SOS from A 100% %@", "Safe formatting arguments")
        check(L10n.duration(minutes: 0) == "0 min", "Zero duration")
        check(L10n.duration(minutes: 1) == "1 min", "Single minute")
        check(L10n.duration(minutes: 60) == "1 h", "Hour duration")
        check(L10n.duration(minutes: 80) == "1 h 20 min", "Mixed duration")
        check(L10n.plural("members.count", count: 1, language: .english) == "1 member", "English singular")
        check(L10n.plural("members.count", count: 2, language: .english) == "2 members", "English plural")
        check(L10n.plural("members.count", count: 1, language: .vietnamese) == "1 thành viên", "Vietnamese count")
        let knownTime = Date(timeIntervalSince1970: 1_735_737_900)
        check(L10n.time(knownTime, language: .english) != L10n.time(knownTime, language: .vietnamese),
              "Time display must follow the selected app locale")
        check(L10n.message("Lỗi mạng: timeout") == "Unable to connect. Please try again.", "Network error")
        check(L10n.message("Lỗi parse dữ liệu: raw detail") == "Unable to read the server response.", "Decoding error")
        check(L10n.message("Email không hợp lệ.\nMật khẩu xác nhận không khớp.") ==
              "Please enter a valid email address.\nThe passwords do not match.", "Multiple validation errors")
        check(L10n.message("Custom server message 50%") == "Custom server message 50%", "Server text preserved")
        restored.select(.vietnamese)
        check(L10n.duration(minutes: 80) == "1 giờ 20 phút", "Vietnamese duration: \(L10n.duration(minutes: 80)); template: \(L10n.text("%lld giờ %lld phút", language: .vietnamese))")
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
            check(vi[key]?.isEmpty == false, "Empty Vietnamese value: \(key)")
            check(placeholders(translated) == placeholders(vi[key]!), "Translation format mismatch: \(key)")
            if !placeholders(key).isEmpty {
                check(placeholders(key) == placeholders(translated), "Legacy key format mismatch: \(key)")
            }
        }
        print("PASS: preference lifecycle, locale lookup, formatting, errors, durations and \(en.count) translations")
    }

    private static func dictionary(_ url: URL) throws -> [String: String] {
        let data = try Data(contentsOf: url)
        return try PropertyListSerialization.propertyList(from: data, format: nil) as! [String: String]
    }
}
