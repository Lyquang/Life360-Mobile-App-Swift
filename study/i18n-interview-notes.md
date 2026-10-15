# iOS Localization Interview Notes

## Architecture

- `L10n.tr` resolves stable namespaced keys in the selected app language, supports positional format arguments, and uses a non-user-facing fallback when a translation is absent. Lookup checks key existence with a sentinel, so a valid Vietnamese translation may equal its source text.
- `DomainError` and `MediaUploadError` stay plain Domain errors. `LocalizedErrors.swift` in Core/Localization adds `LocalizedError` presentation at the app boundary; unknown server messages map to safe localized categories instead of leaking raw response text.
- Dynamic user content (names, addresses, chat text and custom SOS content) is not translated. `L10n.message` preserves unknown content but translates recognized app-owned text; typed error paths do not use it for arbitrary server messages.
- Count copy uses `L10n.plural` and `.one`/`.other` keys. English selects singular only for one; Vietnamese uses the same grammatical template for both forms. This is intentionally a small supported rule set, not a general ICU plural engine.

## Formatting And Notifications

- Time display uses the selected app locale. ISO-8601 parsing and transport values remain locale-neutral protocol data.
- Local SOS/stay notification templates are translated on device. Member names and SOS message bodies remain source content; fully localizing server-composed alert text requires a backend contract based on typed message codes and parameters.
- `InfoPlist.strings` permission copy follows the operating-system language and cannot follow the in-app picker independently.

## Verification And Trade-Offs

- `bash scripts/test_localization.sh` checks preference lifecycle, lookups, fallback, formats, plural behavior, error copy and locale resource parity. Its source scanner is a CI gate for missing keys, untranslated SwiftUI literals, duplicate/empty resources, placeholder mismatch and direct localization bypasses.
- Nine specific allowlist rules cover product branding, language-neutral numeric badges/placeholders and debug/decorative content. New exceptions must be narrow and justified.
- The resource tables retain compatibility sentence keys while call-sites migrate to `L10n.tr`; moving every legacy key to namespaces would increase churn without changing runtime behavior. New keys must be namespaced.
- Full UI screenshot review for long translated copy, VoiceOver and accessibility Dynamic Type remains a manual release check. The repository does not currently expose a dedicated XCTest target for localization; the shell harness runs as part of CI.

## Interview Summary

“I centralized app-owned copy behind a typed-by-convention `L10n.tr` API, kept Domain errors independent of localization, and mapped them at the presentation boundary. Dynamic user content stays verbatim; API failures map from stable status/code to safe localized messages. CI checks translation parity and source usage, while a small plural helper handles the app's count forms without adding a dependency. The trade-off is retaining legacy sentence keys and requiring manual UI review for layout and OS-owned prompts.”
