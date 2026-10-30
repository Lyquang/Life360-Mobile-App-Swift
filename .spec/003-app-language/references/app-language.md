# Feature: Vietnamese / English App Language

Status: Implemented; authenticated-screen manual verification remains
Updated: 2026-10-05

## Objective

Switch the native iOS interface between Vietnamese and English without signing
out, restarting tracking or resetting navigation. Persist the explicit choice.

## Scope

- Language picker in Profile settings and on Login before authentication.
- Standard en/vi localization resources for screens, reusable controls, app-owned
  validation/errors and locally generated notification copy.
- Localized permission purpose strings; system-owned dialogs follow iOS language,
  not the in-app preference. User/server-authored names, chat and addresses remain
  verbatim. No automatic translation API or network requirement.
- Vietnamese default preserves existing behavior; invalid stored values fall back
  to Vietnamese. Explicit preference survives logout and relaunch.

## State And Architecture

- Domain: AppLanguage and LanguagePreferencesRepository contract.
- Data: UserDefaults implementation; language is non-sensitive device preference.
- Presentation: MainActor language settings model, injected from AppContainer;
  root locale environment changes without recreating coordinator/object identity.
- Standard SwiftUI LocalizedStringKey for UI-owned labels; explicit bundle lookup
  for non-View formatting and notifications. No Bundle swizzling / AppleLanguages
  overrides. Domain business errors remain independent of localization services.
- No API endpoint or socket/location lifecycle changes.

## Edge Cases

- Missing/invalid preference, language switching offline or while authenticated.
- Interpolated counts, durations, errors, placeholders and custom String labels.
- Language names always recognizable as Tiếng Việt / English.
- Unknown server text must not be accidentally interpreted as a format string.
- Permission dialogs, Photos/system sheets may use the OS-selected app language.

## Verification

- Resource key parity and format placeholders; resource plist validation.
- Unit-style tests: saved preference, invalid preference fallback, lookup and
  formatting, app-owned errors, durations, unknown text and percent characters.
- Networking regression script and unsigned iOS Simulator build.
- Simulator UI checks when available: switch on Login, persist on relaunch;
  Profile picker, tab labels, layout in both languages. Record any untested flows.

## Results (2026-10-05)

- Unsigned Debug iOS Simulator build passed.
- Localization tests passed: 231 matching translation keys, safe formatting,
  preference lifecycle, app-owned errors and durations. All four strings files
  passed plist validation; existing networking contract tests passed.
- Simulator Login UI test passed: typed email survives switching to English,
  English persists after relaunch, switching back to Vietnamese works. Screenshots
  inspected in both languages. No authentication request was submitted.
- Profile and authenticated feature flows require a test account for manual
  verification; physical-device permission dialogs have not been tested.
- Usage, resource conventions and repeatable test commands: `LOCALIZATION.md`.
