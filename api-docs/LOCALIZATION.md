# Localization Rules: Vietnamese and English

## App Language

- Supported languages are Vietnamese (`vi`) and English (`en`); Vietnamese is the default.
- The language picker is available before sign-in and in Profile/Settings. Selection is persisted on-device and updates app-owned localized strings immediately.
- `FamilyTrackerApp` injects the selected locale into SwiftUI. Non-View code reads the shared selected language through `L10n`.

## Required API And Key Format

Use `L10n.tr` for new app-owned user-facing strings. Keys follow `<area>.<type>.<name>`, for example:

```swift
case .permissionDenied:
    return L10n.tr("voice.error.permission_denied")
```

Add every new key to both `FamilyTracker/Resources/vi.lproj/Localizable.strings` and `FamilyTracker/Resources/en.lproj/Localizable.strings` in the same change. `L10n.tr` returns a verbatim `String`; pass that result directly to SwiftUI, for example `Text(L10n.tr("auth.title.login"))`. Do not localize it a second time.

`L10n.tr` supports positional format arguments and uses the selected app locale. `L10n.plural` resolves `.one`/`.other` forms for counts. `L10n.message` is reserved for dynamic errors/content that may be user- or server-authored; it localizes only known app-owned strings and preserves unknown content. Do not add new `L10n.text`, `L10n.format`, sentence-key, or SwiftUI `LocalizedStringKey` call-sites. Keep compatibility APIs only until their remaining users can be removed safely.

## Rules For Copy

- Do not add display literals to `Text`, `Button`, `Label`, navigation titles, alerts, confirmation dialogs, placeholders, menus, accessibility labels/hints/values, or notifications. Resolve app-owned copy through `L10n.tr` first.
- Do not call `NSLocalizedString` or `String(localized:)` directly for app-owned copy.
- Use positional placeholders (`%1$@`, `%2$lld`) for variable values. Never concatenate translated sentence fragments. `L10n.plural` supports `.one`/`.other` keys (English singular/plural; Vietnamese may use the same form for both); use it for new counts and cover 0, 1, and multiple values in tests.
- Date, time, number, distance, speed, and battery formatting must follow the selected app language. Do not use implicit `Locale.current` for user-facing formatting.
- Map stable error codes/cases to localized copy. Do not show raw backend `message` text for unknown errors; use a translated generic message. Preserve diagnostic detail only in redacted diagnostics.
- Every feature spec/execution plan that adds UI includes a `Localization` section: new key, Vietnamese draft, English draft, and longest copy to check for clipping. New translations require human review.
- Run `bash scripts/test_localization.sh` for every UI/localization change. New languages should be resource additions under a new `.lproj`; feature code must not need language-specific branches.

## Content Exclusions

Do not translate user-authored content: user/member names, circle/place names, addresses, chat messages, captions, and custom SOS text. Also exclude the `FamilyTracker` brand, technical protocol/JSON identifiers, logs/Pulse/diagnostics, and Debug-only tooling. Avoid rendering coordinates in user-facing error/notification text.

System-owned permission dialogs, Photos picker, and other native OS UI follow the OS language, not the in-app picker. `InfoPlist.strings` supplies purpose descriptions for each OS-supported localization but cannot be switched by the in-app language control. Pulse UI localization is controlled by Pulse.

## Current Verification

```bash
bash scripts/test_localization.sh
bash scripts/test_networking.sh
```

`test_localization.sh` validates preference persistence, selected-language lookup, format placeholders, plural behavior, current error/duration behavior, resource parity and source usage. Its scanner fails CI on untranslated UI literals, missing resource keys, empty or duplicate entries, direct localization API bypasses, and placeholder mismatch. Narrow exceptions belong in `scripts/localization-allowlist.txt` with a specific reason. This is not a substitute for checking authenticated screens in both languages.

Optional language-picker UI test (requires XcodeGen, a booted Simulator, the app installed and logged out):

```bash
SIMULATOR_ID=<simulator-udid> bash scripts/test_localization_ui.sh
```
