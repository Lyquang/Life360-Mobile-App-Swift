---
description: 'Task list for Message Management — Mobile Experience'
---

# Tasks: Message Management — Mobile Experience

**Input**: Design documents from `/specs/001-message-notifications/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/)

**Tests**: REQUIRED (constitution v2.0.0, Principle IX). The feature originally shipped without tests under the earlier constitution; Phase 8 adds them. `yarn test:coverage` (≥ 98 %) and `yarn lint` are the automated gates, and [quickstart.md](quickstart.md) covers the on-device checks.

**Organization**: Tasks are grouped by user story so each story can be implemented, validated and shipped as an independent increment.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on incomplete work)
- **[Story]**: `US1`–`US4`, mapping to the user stories in [spec.md](spec.md)

## Path Conventions

Single Expo Router mobile project at the repository root: `app/`, `components/`, `services/`, `stores/`, `hooks/`, `types/`, `locales/`, `utils/`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Install dependencies and apply the native configuration this feature requires.

- [x] T001 Install the three new dependencies with `npx expo install @react-native-firebase/messaging@23.4.0 expo-video@~3.0.15 expo-screen-orientation@~9.0.8` and confirm the resulting versions in package.json
- [x] T002 Check whether `node_modules/@react-native-firebase/messaging/app.plugin.js` exists and, only if it does, add `'@react-native-firebase/messaging'` to the `plugins` array in app.config.ts
- [x] T003 Add iOS push configuration to app.config.ts: `ios.entitlements: { 'aps-environment': 'production' }` and `ios.infoPlist.UIBackgroundModes: ['remote-notification']`
- [x] T004 Change `orientation` from `'portrait'` to `'default'` in app.config.ts (paired with the root portrait lock in T014 — see research.md R8)
- [x] T005 [P] Add `EXPO_PUBLIC_USE_MESSAGE_MOCKS=true` to .env.dev only; do not add it to .env.acc or .env.prod
- [x] T060 Confirm the three `firebase/{dev,acc,prod}/` asset sets each carry the messaging-enabled config, and that `IOS_BUILD_NUMBER` / `ANDROID_VERSION_CODE` handling in app.config.ts stays aligned across environments after the native changes in T002–T004 (Constitution V)

**Checkpoint**: Dependencies installed and native config staged. A prebuild is required before the first device run (see quickstart.md) but is NOT part of these tasks.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared types, endpoints, service and query layers that every user story depends on. These all live in single shared files, so they are done once here rather than per story.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [x] T006 [P] Define `Message`, `MediaItem`, `DeliveryChannel`, `MessagePage` and `UnreadCount` per data-model.md in types/message.type.ts
- [x] T007 [P] Add `MESSAGES`, `MESSAGE_DETAIL`, `MESSAGE_MEDIA_IMAGE` and `MESSAGE_MEDIA_VIDEO` entries to the `ROUTES` object in utils/constant.ts
- [x] T008 [P] Add `MESSAGE_OPENED`, `MESSAGE_MEDIA_PLAYED`, `MESSAGE_ACKNOWLEDGED`, `MESSAGE_NOTIFICATION_OPENED`, `MESSAGE_POPUP_DISMISSED` and `MESSAGE_BANNER_TAPPED` to `AnalyticsEvents` in services/analytics/events.ts
- [x] T009 [P] Add the `messages` endpoint group with the nine paths from contracts/messages-api.md to services/api/endpoint.ts
- [x] T010 Create the TEMPORARY fixtures in services/mocks/messages.mock.ts covering paginated All/Expired pages, a message with an image, a message with a video, a message with an acknowledgement label, popups and banners — with a header comment marking it for deletion per research.md R19 (depends on T006)
- [x] T011 Implement all nine service functions using `ApiClient<Req, Res>` with the `EXPO_PUBLIC_USE_MESSAGE_MOCKS` short-circuit in services/messages.service.ts (depends on T006, T009, T010)
- [x] T012 Re-export the message services from services/index.ts (depends on T011)
- [x] T013 Create the query key factory plus `useInboxMessages` (`useInfiniteQuery`), `useMessageDetail`, `useUnreadCount`, `useReadMessage` and `useAcknowledgeMessage` (`retry: 0`, no optimistic update) in services/queries/messages.query.ts (depends on T011)
- [x] T014 Lock the app to portrait at startup with `ScreenOrientation.lockAsync(PORTRAIT_UP)` in app/\_layout.tsx (depends on T004)
- [x] T015 Seed the shared `messages` i18n namespace (common labels, error and offline strings) in locales/es.json and locales/en.json, Spanish authored first

**Checkpoint**: Data layer complete and mock-backed. User stories can now begin.

---

## Phase 3: User Story 1 - Read messages in the Inbox (Priority: P1) 🎯 MVP

**Goal**: A Storekeeper opens the Inbox from the Home header bell, browses paginated month-grouped messages across All and Expired tabs, opens a message detail with its image or video, and acknowledges when the sender configured it.

**Independent Test**: With a seeded backend, open the Inbox from Home and verify: messages appear unread and grouped by month, scrolling loads more, pull-to-refresh reloads, an empty tab shows the empty state, opening a message leaves it unread, the list's **Mark as read** action reports `channel=Inbox` and decrements the badge after confirmation, the image opens full screen, the video plays and expands to landscape full screen, expired messages are readable under Expired without a read action, and no delete action exists anywhere.

### Implementation for User Story 1

- [x] T016 [P] [US1] Create the per-tab empty state in components/messages/MessageEmptyState.tsx
- [x] T017 [P] [US1] Create the read/unread list row with title, preview and date in components/messages/MessageListItem.tsx
- [x] T018 [P] [US1] Create the All/Expired tab switcher in components/messages/MessageTabs.tsx
- [x] T019 [US1] Create the paginated, month-grouped list with `onEndReached` paging, `RefreshControl` pull-to-refresh, a page loading state and a non-destructive retry on page failure in components/messages/MessageList.tsx (depends on T013, T016, T017)
- [x] T020 [US1] Create the message stack navigator in app/messages/\_layout.tsx (depends on T007)
- [x] T021 [US1] Create the Inbox screen composing the tabs and list in app/messages/index.tsx (depends on T018, T019, T020)
- [x] T022 [P] [US1] Create the single-media renderer — `expo-image` for images, `expo-video` `useVideoPlayer` + `VideoView nativeControls` for video — with a non-blocking failure state that keeps the message text readable in components/messages/MessageMedia.tsx. Media URLs are public (contract open item 2, resolved) so sources are plain URIs with no `headers`
- [x] T023 [P] [US1] Create the acknowledgement action rendered only when `acknowledgeLabel` is present, disabled once `isAcknowledged`, failing fast with the global error toast and no optimistic state in components/messages/MessageAcknowledgeButton.tsx (depends on T013)
- [x] T024 [US1] Create the message detail screen showing title, body, publication date and media in app/messages/[messageId].tsx. **Amended**: detail opening does not report an Inbox read and the detail has no acknowledgement button; read confirmation is explicit on the list (R13, FR-015, FR-016).
- [x] T025 [US1] Create the full-screen image viewer with pinch-zoom and pan built from `react-native-gesture-handler` and `react-native-reanimated` in app/messages/media-image.tsx (depends on T020)
- [x] T026 [US1] Create the full-screen video screen that unlocks to `ALL` on mount and re-locks to `PORTRAIT_UP` on unmount in app/messages/media-video.tsx (depends on T014, T020)
- [x] T027 [US1] Create the bell entry point with an unread badge driven by `useUnreadCount` in components/home/MessageBellButton.tsx (depends on T013)
- [x] T028 [US1] Mount the bell in the Home header and navigate to the Inbox in app/(tabs)/index.tsx (depends on T021, T027)
- [x] T029 [US1] Refetch the unread count on `AppState` `'active'` alongside the existing notification refetch in app/\_layout.tsx (depends on T013)
- [x] T030 [US1] Log `MESSAGE_OPENED` in app/messages/[messageId].tsx, `MESSAGE_MEDIA_PLAYED` in components/messages/MessageMedia.tsx and `MESSAGE_ACKNOWLEDGED` in components/messages/MessageAcknowledgeButton.tsx (depends on T008, T024)
- [x] T031 [US1] Add the Inbox, detail, media and acknowledgement strings to locales/es.json and locales/en.json

**Checkpoint**: The Inbox is fully functional and shippable on its own — this is the MVP.

---

## Phase 4: User Story 2 - Receive a push notification and jump to the message (Priority: P2)

**Goal**: A published push message reaches the device, and tapping it opens the corresponding message detail from any app state, routing through login first when the session is invalid.

**Independent Test**: On a physical iOS device and an Android device, send a Firebase console test message carrying `type=message` and a `messageId` that exists. Verify: a system notification appears when backgrounded or quit and tapping it lands on the right detail; a foreground message shows an in-app toast with no system banner and updates the bell badge; denying permission still delivers to the Inbox; and after logout the device receives nothing for that account.

### Implementation for User Story 2

- [x] T032 [US2] Create the messaging service with a module-scope `setBackgroundMessageHandler`, plus `getToken`, `onTokenRefresh` and `deleteToken` helpers in services/messaging.service.ts
- [x] T033 [US2] Add the permission request — iOS `requestPermission`, Android 13+ `PermissionsAndroid.PERMISSIONS.POST_NOTIFICATIONS` — invoked after login rather than at cold start, in services/messaging.service.ts (depends on T032)
- [x] T034 [US2] Register the FCM token with the backend after login and de-register it before auth state is cleared on logout, then `deleteToken()` regardless of the request outcome, in services/auth.service.ts and stores/auth.store.ts (depends on T011, T032)
- [x] T035 [US2] Create the tap-routing hook handling `getInitialNotification` and `onNotificationOpenedApp`, holding the pending `messageId` until `isAuthenticated` is true and the router is ready, in hooks/useMessageNotificationRouting.ts (depends on T007, T032)
- [x] T036 [US2] Import services/messaging.service.ts for its module-scope side effect and mount `useMessageNotificationRouting` in app/\_layout.tsx (depends on T035)
- [x] T037 [US2] Handle foreground messages with `onMessage` — show an `AppToast` and invalidate the inbox and unread-count queries — in app/\_layout.tsx (depends on T013, T036)
- [x] T038 [US2] Log `MESSAGE_NOTIFICATION_OPENED` when a notification tap resolves to a message detail in hooks/useMessageNotificationRouting.ts (depends on T008, T035)
- [x] T039 [US2] Add the permission rationale and foreground notification strings to locales/es.json and locales/en.json

**Checkpoint**: Push delivery and routing work end to end on top of the Inbox from US1.

---

## Phase 5: User Story 3 - See a popup on app open (Priority: P3)

**Goal**: Popup-configured messages appear as a modal over Home when Home becomes active after launch or foreground resume, are dismissible, never reappear once dismissed, and never appear on any other screen.

**Independent Test**: With an active popup message, cold start the app and verify the modal appears over Home; dismiss it, background and foreground the app, and verify it does not return; confirm popup acknowledgement uses its own endpoint and does not send an Inbox read confirmation; navigate to Electronic Orders or Account, background and foreground, and verify no popup appears.

### Implementation for User Story 3

- [x] T040 [P] [US3] Create the persisted dismissed-ids store with Zustand + `immer` + `persist` to AsyncStorage in stores/message-popup.store.ts
- [x] T041 [P] [US3] Add `usePopupMessages` to services/queries/messages.query.ts (depends on T011)
- [x] T042 [US3] Create the popup host presenting eligible popups one at a time ordered by publication date descending, never stacked, using React Native `<Modal>`, filtering out ids already in the dismissal store, in components/home/MessagePopupHost.tsx (depends on T040, T041, T022, T023)
- [x] T043 [US3] Mount the popup host inside Home and trigger it **only** on first Home activation after app launch and on an `AppState` transition to `'active'` — a plain tab-switch focus back to Home MUST NOT re-trigger it (FR-025) — in app/(tabs)/index.tsx (depends on T042)
- [x] T044 [US3] Wire acknowledgement from the popup so it records the acknowledge event, closes the popup and adds the id to the dismissal store in components/home/MessagePopupHost.tsx (depends on T042)
- [x] T045 [US3] Clear the dismissed-ids store on logout in stores/auth.store.ts (depends on T040)
- [x] T046 [US3] Log `MESSAGE_POPUP_DISMISSED` on dismissal in components/home/MessagePopupHost.tsx (depends on T008, T042)
- [x] T047 [US3] Add the popup strings to locales/es.json and locales/en.json

**Checkpoint**: Popups work on Home only, without affecting the Inbox or push flows.

---

## Phase 6: User Story 4 - Browse the Home banner carousel (Priority: P4)

**Goal**: Banner-configured messages render on Home as a single static banner or a swipeable carousel with a position indicator, and tapping one opens its detail.

**Independent Test**: With one active banner message verify a single static banner and no indicator; with two or more verify a swipeable carousel with a position indicator and that tapping opens the right message; with none verify Home renders with no banner area and no gap.

### Implementation for User Story 4

- [x] T048 [P] [US4] Add `useBannerMessages` to services/queries/messages.query.ts (depends on T011)
- [x] T049 [US4] Create the banner surface — a single static banner for one message, a `pagingEnabled` horizontal `FlatList` with dot indicators for several — with tap navigation to the message detail, in components/home/MessageBannerCarousel.tsx (depends on T007, T048)
- [x] T050 [US4] Mount the banner on Home, rendering no banner area when the list is empty, in app/(tabs)/index.tsx (depends on T049)
- [x] T051 [US4] Log `MESSAGE_BANNER_TAPPED` on banner tap in components/home/MessageBannerCarousel.tsx (depends on T008, T049)
- [x] T052 [US4] Add the banner strings to locales/es.json and locales/en.json

**Checkpoint**: All four delivery channels are implemented.

---

## Phase 7: Polish & Cross-Cutting Concerns

- [x] T053 [P] Implement graceful offline behaviour in components/messages/MessageList.tsx, app/messages/[messageId].tsx, components/home/MessagePopupHost.tsx and components/home/MessageBannerCarousel.tsx — previously loaded content stays readable and stale or unavailable data is clearly communicated (FR-034). **Verification is deferred to T059**: under the mock flag no network call occurs, so the interceptors and the global error toast cannot be exercised
- [x] T054 [P] Clear all message query cache entries on logout alongside the existing auth teardown in stores/auth.store.ts (FR-035)
- [x] T055 [P] Confirm `useScreenTracking` in hooks/useScreenTracking.ts records app/messages/index.tsx, app/messages/[messageId].tsx, app/messages/media-image.tsx and app/messages/media-video.tsx
- [ ] T056 Orientation regression check: confirm Home, Electronic Orders, Account, Login, MFA, the webviews and the commission receipt screens all remain portrait-locked, and only app/messages/media-video.tsx rotates
- [x] T057 Run `yarn lint` and resolve every reported issue
- [ ] T058 Execute the validation scenarios in quickstart.md on a physical iOS device and an Android device, including the SC-001 / SC-003 / SC-007 performance measurements under the reference conditions defined in spec.md
- [x] T059 **BACKEND CUTOVER — DONE.** Real endpoints wired per `API_V2.md` (Devices, Inbox, ChannelMessages) in services/api/endpoint.ts; types/message.type.ts aligned to the PascalCase `ApiResult<T>` payloads and `pageIndex`/`totalPages` paging; deleted services/mocks/messages.mock.ts; removed the `USE_MOCKS` ternaries from services/messages.service.ts; removed `EXPO_PUBLIC_USE_MESSAGE_MOCKS` from .env.dev; `grep -rn "USE_MESSAGE_MOCKS\|messages.mock" .` returns nothing outside `specs/`; `yarn lint` clean. **Still pending: on-device re-validation (T058) against the live API and the offline/airplane-mode check once BE deploys.**

---

## Phase 8: Automated Tests (constitution Principle IX)

**Purpose**: Bring the feature under the Jest suite. It had no tests, and its native imports broke 7 existing suites (coverage fell from ~99 % to ~70 %).

- [x] T061 Add Jest mocks for `@react-native-firebase/messaging`, `expo-video` (player stub that records listeners), `expo-blur` and `expo-screen-orientation` in test/setup.ts
- [x] T062 Add the `makeMessage()` fixture and the `settleQueries()` helper to test/render.tsx
- [x] T063 Update stale existing tests: utils/constant.test.ts (Inbox + message routes), services/analytics/analyticsService.test.ts (`MESSAGE_*` events), test/integration/app/(tabs)/\_layout.test.tsx (4th Inbox tab)
- [x] T064 Extend test/integration/app/\_layout.test.tsx: mock the messaging service (no network), portrait lock, device-token registration and foreground-push toast + cache refresh
- [x] T065 Extend test/integration/app/(tabs)/index.test.tsx: mock services/messages.service (no network), bell count + navigation, banners, popup activation (FR-025), and re-arming on foreground
- [x] T066 Extend services/auth.service.test.ts: logout drops the FCM token, clears message queries and dismissed popups (FR-020, FR-035)
- [x] T067 [P] Unit tests for services/messages.service.ts: DTO mapping, tab/paging/storeCode params, media ordering, `MessageUnavailableError` Data/Details, acks and device registration
- [x] T068 [P] Unit tests for services/messaging.service.ts: payload matching (`inbox_message`, legacy `message`, deep link), iOS/Android permission paths, token register/unregister/refresh, tap and cold-start ids
- [x] T069 [P] Unit tests for services/queries/messages.query.ts, stores/message-popup.store.ts and hooks/useMessageNotificationRouting.ts (incl. the StrictMode guard and holding a tap until login, FR-022)
- [x] T070 [P] Component tests for components/messages/\* (Tabs, EmptyState, VideoPlayButton, Media, ListItem, List, AcknowledgeButton)
- [x] T071 [P] Component tests for components/home/MessageBellButton.tsx, MessageBannerCarousel.tsx and MessagePopupHost.tsx
- [x] T072 [P] Screen tests in test/integration/app/: (tabs)/inbox, messages/messageId (incl. not-available state and signed-URL refresh), messages/media-image (zoom/pan gestures), messages/media-video and messages/\_layout
- [x] T073 Run `yarn test:coverage` and `yarn lint`: 101 suites / 831 tests green, no act() warnings or network calls; coverage 99.64 % statements, 98.52 % branches, 99.84 % functions, 99.63 % lines

**Checkpoint**: Every message-feature file is at 100 % coverage except one unreachable defensive branch in MessageBannerCarousel.tsx, documented in docs/testing.md.

---

## Phase 9: Separate Push Opens from Inbox Read Confirmations (2026-10-30)

- [x] T074 [US1] Add `MessageChannels.Inbox` / `.Push` and require `channel` in `reportMessageRead`; send it as a query parameter on `POST /Inbox/{messageId}/read` in types/message.type.ts and services/messages.service.ts (depends on T006, T011).
- [x] T075 [US1] Bind `Inbox` in both existing read/confirmation mutation hooks, preserving invalidation and error behaviour; leave popup/banner acknowledgement endpoints unchanged in services/queries/messages.query.ts (depends on T074).
- [x] T076 [US2] Report `Push` from the authenticated pending-tap flow for cold starts/background taps/deferred login; keep navigation non-blocking, do not invalidate Inbox state, and record failures through Crashlytics in hooks/useMessageNotificationRouting.ts (depends on T035, T074).
- [x] T077 [US1] [US2] Add/update service, mutation, routing, component and Inbox screen tests for both channels, no read on detail opening, deferred login, no reporting on ordinary launch, and reporting failure without blocked navigation (depends on T075, T076).
- [x] T078 Synchronise spec, plan, data model, research, contracts and quickstart with the channel-separated behaviour. Automated validation: 101 suites / 851 tests passed; coverage 99.60% statements, 98.54% branches, 99.84% functions, 99.63% lines. Changed-file lint passed; project lint has 5 pre-existing warnings; TypeScript still fails on existing toast/crypto types. Jest required manual termination after completing tests (depends on T077).
- [ ] T079 [US1] [US2] Validate on physical iOS and Android against the live API: correct channel query, Inbox read state unchanged by push opens, and separate events visible in Admin Message Details. Include failure and deferred-login scenarios in quickstart.md; backend/portal work remains external (depends on T078 and backend deployment).

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Setup — BLOCKS all user stories
- **User Stories (Phases 3–6)**: All depend on Foundational
  - US1 is independent
  - US2 depends on US1 for its landing destination (the message detail route)
  - US3 depends on US1 for the media and acknowledgement components
  - US4 depends on US1 for the message detail route
- **Polish (Phase 7)**: Depends on the desired user stories being complete. T059 additionally depends on the backend shipping, and carries the verification of T053.

### Story-Level Dependencies

| Story    | Can start after            | Reuses                                     |
| -------- | -------------------------- | ------------------------------------------ |
| US1 (P1) | Phase 2                    | —                                          |
| US2 (P2) | T024 (detail route exists) | Detail screen, unread count                |
| US3 (P3) | T022, T023                 | `MessageMedia`, `MessageAcknowledgeButton` |
| US4 (P4) | T024                       | Detail route                               |

US2, US3 and US4 do not depend on each other and can be built in parallel by different developers once US1 is done.

### Shared-File Contention

These files are touched by several phases and must not be edited concurrently:

- `app.config.ts` — T002, T003, T004, T060
- `app/_layout.tsx` — T014, T029, T036, T037
- `app/(tabs)/index.tsx` — T028, T043, T050
- `services/queries/messages.query.ts` — T013, T041, T048
- `stores/auth.store.ts` — T034, T045, T054
- `locales/es.json` / `locales/en.json` — T015, T031, T039, T047, T052

### Parallel Opportunities

- **Phase 2**: T006, T007, T008 and T009 are fully parallel
- **US1**: T016, T017, T018 in parallel; then T022 and T023 in parallel
- **US3**: T040 and T041 in parallel
- **Phase 7**: T053, T054 and T055 in parallel
- Once US1 is complete, US2 / US3 / US4 can proceed in parallel across developers

---

## Implementation Strategy

### MVP scope

**Phases 1 + 2 + 3 (T001–T031 plus T060)** — dependencies, native config, the data layer and the full Inbox experience. This alone gives Storekeepers a working message centre with media, read tracking and acknowledgement, and is independently shippable.

### Incremental delivery

1. **Increment 1 (MVP)** — T001–T031, T060: Inbox, detail, media, acknowledge
2. **Increment 2** — T032–T039: push notifications and tap routing
3. **Increment 3** — T040–T047: Home popups
4. **Increment 4** — T048–T052: Home banner carousel
5. **Hardening** — T053–T058, then T059 when the backend is ready

Each increment ends at a checkpoint where the app is stable and demonstrable.

### Notes

- Every user-visible string added in any phase must land in **both** `locales/es.json` and `locales/en.json`, Spanish first.
- Do not add manual `useMemo` or `useCallback` — React Compiler is enabled.
- Do not run `yarn prebuild` or any iOS/Android build as part of these tasks; a prebuild is only needed before the first device run described in quickstart.md.
- All network calls go through `ApiClient`. Do not create a second Axios instance or bypass the interceptors in configs/api.config.ts.
