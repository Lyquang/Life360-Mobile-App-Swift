# Tìm địa điểm bằng MapKit và lịch sử cục bộ

Date: 2026-11-12 | Status: Implemented; build/automated checks pass, physical-device/UI QA remains.
Authority: user “Hãy hiện thực full chức năng đầu tiên đi”, superseding the earlier
design-only choice. Scope: native iOS search/history, not route planning/weather/push/geofences.

## User flow and acceptance

- AC01: LiveMap search opens a coordinator-owned sheet. Type to get Apple suggestions; submit text or select a suggestion to resolve results within the visible map region. Search works without new GPS permission.
- AC02: Select a result to dismiss search and show/focus a separate place pin/card on LiveMap. Existing Circle member pins, trail, SOS and location policy remain intact. No dummy routing/save action for unfinished features.
- AC03: Debounce/cancellation and generation guards prevent old suggestions/results from replacing newer input; loading/empty/network/throttled/retry states are localized and recoverable.
- AC04: Account-scoped on-device cache retains at most 20 submitted/selected user queries for 30 days, normalized dedup with most recent first, expiry on read, delete-one/all. Survives restart when the OS retains UserDefaults. No server/DB/sync, no stored Apple POI snapshot or search keystroke log.
- AC05: Logout/session end clears the active account's cache, cancels pending search and disables its model. Inactive old models cannot recreate history or expose a result to another session. Cache failure is visible without blocking search.
- AC06: Native adapter stays in Core/Data, Domain models/protocols are framework-free, UI state MainActor, navigation Coordinator-owned. iOS16 compatibility; no added dependencies.
- AC07: Text/nearby searches use Apple natural-language query and map region bias; no hardcoded country restriction or fabricated results. Live provider coverage and physical-device accessibility remain manual checks.

## Data/state

Pure PlaceSearchRegion, PlaceSearchSuggestion, PlaceSearchResult, RecentPlaceSearch;
typed PlaceSearchFailure. History contains only user-authored query and timestamps,
not raw MapKit names/addresses/coordinates. Cache namespace is a hashed account ID.
Query/selection tasks are per-model, canceled on close; session invalidation is terminal.

## Verification

Actual commands, results and remaining manual checks: [quickstart](quickstart.md).

Runnable standalone Swift tests with fake provider/clock/cache cover TTL, limit,
account isolation, corruption, cancel/obsolete callbacks, typed errors, selection,
no history on keystrokes, clear/retry/session end. Build unsigned Simulator app;
run localization scanner/contracts and networking regression. No live account or
backend mutation required. Do not claim live coverage from fake tests.

## Localization

All keys below are added to vi/en resources, L10n.tr only. Longest messages to check
for wrapping: search.error.unavailable/history/throttled; use Dynamic Type and VoiceOver.

| Key | vi | en |
|---|---|---|
| search.field.placeholder | Tìm địa điểm | Search places |
| search.title | Tìm địa điểm | Find a place |
| search.section.recent | Tìm kiếm gần đây | Recent searches |
| search.section.suggestions | Gợi ý | Suggestions |
| search.section.results | Kết quả | Results |
| search.action.clear_all | Xóa lịch sử | Clear history |
| search.action.delete | Xóa | Delete |
| search.action.retry | Thử lại | Retry |
| search.action.close | Đóng tìm kiếm | Close search |
| search.action.clear_place | Bỏ chọn địa điểm | Clear selected place |
| search.state.loading | Đang tìm kiếm… | Searching… |
| search.state.empty | Không tìm thấy địa điểm | No places found |
| search.state.hint | Nhập tên địa điểm hoặc tìm quán cà phê, nhà hàng quanh vùng bản đồ. | Enter a place name or search for cafés and restaurants in this map area. |
| search.error.unavailable | Chưa thể tìm địa điểm. Vui lòng thử lại. | Places are unavailable. Please try again. |
| search.error.throttled | Có quá nhiều yêu cầu tìm kiếm. Vui lòng thử lại sau. | Too many searches. Please try again shortly. |
| search.error.history | Chưa thể cập nhật lịch sử tìm kiếm trên thiết bị. | Search history could not be updated on this device. |
| search.error.query | Nhập từ 2 đến 200 ký tự để tìm kiếm. | Enter between 2 and 200 characters to search. |

## Dependencies/limits

Backend spec: `../Backend/specs/features/place-search/plan.md` relative to Mobile
repository root; backend search endpoints are unnecessary for this slice. Apple
throttling/availability are surfaced; no new GPS/background service starts.
Cached-query region is the current map when reused, not a stale coordinate snapshot.

Additional localized keys: search.action.clear_query (Xóa nội dung tìm kiếm / Clear search text), search.nearby.cafe (Quán cà phê / Cafés), search.nearby.restaurant (Nhà hàng / Restaurants).
