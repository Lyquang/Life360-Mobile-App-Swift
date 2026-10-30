# Implementation Plan: Message Management — Mobile Experience

**Branch**: `001-message-notifications` | **Date**: 2026-08-04 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/001-message-notifications/spec.md`

**Jira**: [SSA0-962](https://heineken.atlassian.net/browse/SSA0-962) | **Design**: [Figma](https://www.figma.com/design/04ovSv51Qho6Ls31tFWdXx/SIX-SK-App---CMS-Portal?node-id=34-10868&m=dev)

## Summary

Give Storekeepers a message centre in the SIX mobile app. Messages authored in the web portal reach the app through four delivery channels: **push notification**, **in-app inbox**, **popup** and **home banner**. The app adds a bell entry point in the Home header leading to a paginated Inbox with All/Expired tabs, a message detail view that renders one optional image or video, and read/acknowledge reporting back to the backend.

Technical approach: `@react-native-firebase/messaging@23.4.0` reuses the app's existing Firebase project for push, sending notification+data payloads so the OS renders background/quit notifications for free while the foreground case is handled with the app's own `AppToast`. Message data is server state owned entirely by TanStack Query — `useInfiniteQuery` for the tabs (a new pattern for this codebase), `useMutation` with fail-fast semantics for read and acknowledge. Media uses `expo-video` for video and the already-installed `expo-image` for images; full-screen landscape video requires switching the app's native orientation to `default` and applying a root-level portrait lock via `expo-screen-orientation`. Popups are a React Native `<Modal>` mounted inside the Home screen, which makes "Home only" structurally true. Banners are a paging `FlatList`. Backend message APIs are an external dependency and are contracted, not built, here.

## Technical Context

### Channel-qualified interactions (2026-10-30)

- `MessageChannels` in `types/message.type.ts` defines the case-sensitive API values `Inbox` and `Push`, distinct from the lowercase delivery-channel labels.
- `reportMessageRead(messageId, channel)` requires an explicit channel and sends `POST /Inbox/{messageId}/read` with the query parameter `channel` and no request body.
- `useReadMessage` and the existing shared `useAcknowledgeMessage` mutation bind `MessageChannels.Inbox`; their current success invalidations and failure handling remain unchanged.
- `useMessageNotificationRouting` sends `MessageChannels.Push` when processing an authenticated pending notification tap, alongside the existing analytics event, without waiting before navigation. It calls the service directly because this root hook is mounted outside `QueryClientProvider`. Failures go to `CrashlyticsService.recordError`, not an unhandled rejection or user-facing toast.
- Push-open reporting does not invalidate message queries or mutate Inbox state. Popup/banner acknowledgement endpoints remain unchanged.
- Contract and device checks: [contracts/messages-api.md](contracts/messages-api.md#current-amendment-2026-10-30-channel-qualified-read-endpoint), [quickstart.md](quickstart.md#channel-separated-tracking-2026-10-30). Backend persistence and Admin reporting require live validation; they are outside the mobile implementation.

**Language/Version**: TypeScript `~5.9.2`, React `19.1.0`, React Native `0.81.5`, Expo SDK `~54.0.33` (New Architecture enabled, React Compiler enabled)

**Primary Dependencies**: Expo Router `~6.0.23`, TanStack React Query `^5.76.1`, Zustand `^5.0.4` + Immer, Axios `^1.9.0`, i18next `^25.5.2`, `@react-native-firebase/app|analytics|crashlytics` `23.4.0`, `expo-image ~3.0.11`, `react-native-reanimated ~4.1.1`, `react-native-gesture-handler ~2.28.0`, `dayjs`.
**New**: `@react-native-firebase/messaging@23.4.0`, `expo-video@~3.0.15`, `expo-screen-orientation@~9.0.8`.

**Storage**: Expo Secure Store (auth tokens — unchanged), AsyncStorage (dismissed popup ids only), React Query in-memory cache (all message data). No local database.

**Testing**: Jest (jest-expo preset + React Native Testing Library). Unit/component tests are colocated; screen tests live in `test/integration/app/…`. `yarn test:coverage` (≥ 98 %) and `yarn lint` are the automated gates; on-device validation follows [quickstart.md](quickstart.md).

**Target Platform**: iOS 15.1+ and Android 8+. A **physical iOS device** is required to validate push (ARM64 simulators cannot obtain an APNs token).

**Project Type**: Mobile app (single Expo Router project). Backend and web portal are out of scope.

**Performance Goals**: Measured on the reference conditions in spec.md (4G/LTE ~10 Mbps, ~100 ms RTT, mid-tier device, warm start) — inbox first screen within 2 s (SC-003), video playback starts within 3 s (SC-007), notification-to-read under 15 s end to end (SC-001), plus 60 fps list and carousel scrolling.

**Constraints**: Portrait-locked on every screen except the full-screen video route; reads degrade gracefully offline; writes fail fast with no offline queue (Clarification 4); no optimistic state for read/acknowledge (FR-019); React Compiler compatible — no manual `useMemo`/`useCallback` without a demonstrated need; all strings in `es.json` **and** `en.json`.

**Scale/Scope**: 4 new routes, ~10 new components, 2 new services, 1 new query-hooks module, 1 new Zustand store, 1 new types module, 6 new analytics events, ~40 new i18n keys, native config changes in `app.config.ts`.

## Constitution Check

_GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design._

Evaluated against `.specify/memory/constitution.md` v1.1.0.

| #   | Principle                                              | Assessment                                                                                                                                                                                                                                                                                                                                                                                                          | Status |
| --- | ------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| I   | Layered Architecture & Thin Routes                     | Routes in `app/messages/` only compose. Domain UI in `components/messages/`, network in `services/messages.service.ts` + `services/messaging.service.ts`, client state in `stores/message-popup.store.ts`, types in `types/message.type.ts`. Shared primitives (`BaseText`, `BaseButton`, `UntitledIcons`) reused; tokens from `utils/colors.ts`; fonts and routes from `utils/constant.ts`; `@/` alias throughout. | PASS   |
| II  | Typed API Access Through a Single Client               | Every call goes through `ApiClient<Req, Res>`. New paths added to `services/api/endpoint.ts` under a `messages` group. No new Axios instance, no bypassing `configs/api.config.ts` interceptors. The `{ message: { Data: T } }` envelope is unwrapped by `ApiClient` as today.                                                                                                                                      | PASS   |
| III | Disciplined State Management                           | All message data is React Query server state. Zustand holds only `dismissedIds` — genuine client state, not duplicated server data. `meta.allowGlobalErrorHandler` is left at its default `true` for the global toast; the message-detail 404 path opts out deliberately.                                                                                                                                           | PASS   |
| IV  | Internationalization by Default                        | A `messages` namespace added to both `locales/es.json` and `locales/en.json`, Spanish authored first. The only untranslatable strings are the OS-rendered push title/body, which the backend must localise — documented in [contracts/push-payload.md](contracts/push-payload.md).                                                                                                                                  | PASS   |
| V   | Secure Auth & Native Boundaries                        | Auth flow and the 401 refresh queue are untouched. Native changes are confined to `app.config.ts` (entitlements, background modes, orientation, plugins) so CNG still regenerates `ios/` and `android/`. FCM token de-registered and deleted on logout. Per-environment Firebase assets already exist for dev/acc/prod.                                                                                             | PASS   |
| VI  | Analytics, Design Consistency & Compiler Compatibility | Six new typed names added to `AnalyticsEvents`; new routes are covered by the existing `useScreenTracking`. UI follows the Figma frames using existing tokens. No manual memoization is planned.                                                                                                                                                                                                                    | PASS   |
| VII | Knowledge Graph First                                  | `graphify-out/GRAPH_REPORT.md` and the codebase were surveyed before planning; existing patterns (`electronic-orders.service.ts`, `queries/queryClient.ts`, `new-electrotric-orders.store.ts`, `BaseBottomSheet`) were used as the templates for the new modules.                                                                                                                                                   | PASS   |
| —   | Quality Gates                                          | `yarn lint` and `yarn test:coverage` are the gates. Tests ship with the feature (Principle IX, added in constitution v2.0.0 — see tasks.md Phase 8). No native prebuild or platform build will be run as part of implementation.                                                                                                                                                                                    | PASS   |
| —   | Scope Discipline                                       | Plan covers only the mobile slice of SSA0-962. Portal, backend, reporting and audit log remain out of scope per the spec's Scope Boundary.                                                                                                                                                                                                                                                                          | PASS   |

**Initial gate**: PASS, with one item routed to Complexity Tracking (app-wide orientation change).

**Post-design re-check**: PASS. Phase 1 introduced no additional violations — no new dependency beyond the three recorded in Technical Context, no parallel HTTP client, and no server data in Zustand.

## Project Structure

### Documentation (this feature)

```text
specs/001-message-notifications/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── checklists/
│   └── requirements.md  # Spec quality checklist (16/16)
├── contracts/           # Phase 1 output
│   ├── messages-api.md  # Backend REST contract the app depends on
│   └── push-payload.md  # FCM payload contract
└── tasks.md             # Phase 2 output (/speckit.tasks — NOT created by /speckit.plan)
```

### Source Code (repository root)

New and modified files, following the existing Expo Router layout:

```text
app/
├── _layout.tsx                          # MODIFY: import messaging service, mount notification
│                                        #   routing hook, apply root portrait lock
├── (tabs)/
│   └── index.tsx                        # MODIFY: bell entry point, banner carousel, popup host
└── messages/
    ├── _layout.tsx                      # NEW: stack for the message routes
    ├── index.tsx                        # NEW: Inbox (All / Expired tabs)
    ├── [messageId].tsx                  # NEW: message detail
    ├── media-image.tsx                  # NEW: full-screen image viewer
    └── media-video.tsx                  # NEW: full-screen video (landscape-capable)

components/
├── home/
│   ├── MessageBellButton.tsx            # NEW: bell + unread badge in the Home header
│   ├── MessageBannerCarousel.tsx        # NEW: single banner / paging FlatList + dots
│   └── MessagePopupHost.tsx             # NEW: sequential <Modal> popups, Home-only
└── messages/
    ├── MessageTabs.tsx                  # NEW: All / Expired switcher
    ├── MessageList.tsx                  # NEW: paginated, month-grouped list
    ├── MessageListItem.tsx              # NEW: read/unread row, video poster + play button
    ├── MessageEmptyState.tsx            # NEW
    ├── MessageMedia.tsx                 # NEW: image or tap-to-play video, degrades to text on failure
    ├── VideoPlayButton.tsx              # NEW: frosted play button (expo-blur + assets/icons/play.svg)
    └── MessageAcknowledgeButton.tsx     # NEW: fail-fast acknowledge action

services/
├── messages.service.ts                  # NEW: ApiClient calls for the message endpoints
├── messaging.service.ts                 # NEW: FCM token lifecycle + handler registration
├── auth.service.ts                      # MODIFY: register FCM token after login, de-register on logout
├── index.ts                             # MODIFY: re-export the new services
├── api/
│   └── endpoint.ts                      # MODIFY: add the `messages` endpoint group
├── queries/
│   └── messages.query.ts                # NEW: useInfiniteQuery, useQuery, useMutation hooks
└── analytics/
    └── events.ts                        # MODIFY: six new typed event names

stores/
├── message-popup.store.ts               # NEW: persisted dismissed popup ids
└── auth.store.ts                        # MODIFY: clear message cache and dismissed ids on logout

hooks/
└── useMessageNotificationRouting.ts     # NEW: cold-start + background tap routing

types/
└── message.type.ts                      # NEW: Message, MediaItem, DeliveryChannel, MessagePage

locales/
├── es.json                              # MODIFY: `messages` namespace (authored first)
└── en.json                              # MODIFY: `messages` namespace

utils/
└── constant.ts                          # MODIFY: ROUTES entries for the new screens

app.config.ts                            # MODIFY: ios.entitlements, ios.infoPlist.UIBackgroundModes,
                                         #   orientation: 'default', messaging plugin entry
package.json                             # MODIFY: three new dependencies
```

**Structure Decision**: Single Expo Router mobile project — the existing repository layout. Message routes live under `app/messages/`, with the inbox reached from a dedicated **Inbox** bottom tab in `app/(tabs)/_layout.tsx` (four tabs) and a bell shortcut in the Home header — both are present in every rendered Figma frame. Domain components are split between `components/messages/` (inbox and detail surfaces) and `components/home/` (bell, banner, popup host), because the latter three are Home-screen concerns and mounting the popup host inside Home is what enforces FR-028 structurally.

## Mock Layer — Removed (backend cutover complete)

The temporary mock layer described here has been **removed** now that the real endpoints exist (`API_V2.md`: Devices, Inbox, ChannelMessages). `services/messages.service.ts` calls `ApiClient` directly; there is no mock file, flag or ternary. See [research.md](research.md) R19 for the completed cutover record.

## Complexity Tracking

| Violation                                                                                                                              | Why Needed                                                                                                                                                                                                                                                                      | Simpler Alternative Rejected Because                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| -------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| App-wide native orientation change (`orientation: 'portrait'` → `'default'` plus a root-level `expo-screen-orientation` portrait lock) | FR-012 requires full-screen video in landscape. On iOS, `UISupportedInterfaceOrientations` is a hard ceiling — a portrait-only app cannot rotate, and neither can the native player's full-screen presentation. `'default'` is the only way to make landscape reachable at all. | Keeping `orientation: 'portrait'` and calling `VideoView.enterFullscreen()` produces a portrait-only full screen, which fails FR-012. Adding landscape to `ios.infoPlist.UISupportedInterfaceOrientations` while leaving `orientation: 'portrait'` does not work — Expo's generated value wins. Mitigation: the root lock preserves today's behaviour everywhere else, and [quickstart.md](quickstart.md) carries an explicit orientation regression check across every pre-existing screen. |
| First use of `useInfiniteQuery` in this codebase                                                                                       | Clarification 5 requires paginated inbox loading with pull-to-refresh and no history cap.                                                                                                                                                                                       | Manual page accumulation in `useState` would reimplement the cache invalidation and refresh semantics TanStack Query already provides, and would fight the global error handling wired in `services/queries/queryClient.ts`. The convention established here becomes the local pattern.                                                                                                                                                                                                      |
