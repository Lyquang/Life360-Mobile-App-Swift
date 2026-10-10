import SwiftUI

struct LanguagePicker: View {
    @EnvironmentObject private var settings: LanguageSettingsViewModel

    var body: some View {
        Picker(selection: Binding(get: { settings.language }, set: settings.select)) {
            ForEach(AppLanguage.allCases) { language in
                Text(verbatim: language.nativeName).tag(language)
            }
        } label: {
            Label("Ngôn ngữ", systemImage: "globe")
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("settings.language")
    }
}

/// For app-owned String labels and errors. User names and chat remain ordinary Text.
struct AppLocalizedText: View {
    @Environment(\.locale) private var locale
    let value: String

    init(_ value: String) { self.value = value }

    var body: some View {
        Text(verbatim: L10n.message(value, language: AppLanguage(locale: locale)))
    }
}

struct LocalizedDurationText: View {
    @Environment(\.locale) private var locale
    let minutes: Int

    var body: some View {
        Text(verbatim: L10n.duration(minutes: minutes, language: AppLanguage(locale: locale)))
    }
}
