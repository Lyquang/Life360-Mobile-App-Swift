# Phase 0 Research: Message Management — Mobile Experience

**Feature**: `001-message-notifications` | **Date**: 2026-08-04

All Technical Context unknowns are resolved below. No `NEEDS CLARIFICATION` markers remain.

Baseline verified from the repository: Expo `~54.0.33`, React Native `0.81.5`, React `19.1.0`, New Architecture enabled, React Compiler enabled, `@react-native-firebase/app|analytics|crashlytics` at `23.4.0`, `expo-image ~3.0.11`, TanStack Query `^5.76.1`, Zustand `^5.0.4`.

---

## R1. Push messaging library

**Decision**: Add `@react-native-firebase/messaging` pinned to the same minor as the other RNFirebase packages already installed (`23.4.0`). Install with `npx expo install @react-native-firebase/messaging@23.4.0`.

**Rationale**: The app already ships `@react-native-firebase/app`, `analytics` and `crashlytics` at `23.4.0`. RNFirebase requires all `@react-native-firebase/*` packages to share the same version because they resolve a common native Firebase BoM; mixing majors causes native link failures. Reusing the existing Firebase project also means the customer-provisioned APNs key and the per-environment `GoogleService-Info.plist` / `google-services.json` files under `firebase/{dev,acc,prod}/` work with no additional credential setup.

**Alternatives considered**:

- `expo-notifications` — would add a second notification stack alongside Firebase, duplicate the token lifecycle, and require an Expo push service or a custom FCM bridge. Rejected: the customer has already configured Firebase + APNs key.
- `@notifee/react-native` — only needed to _render_ rich local notifications while the app is in the foreground. FR-023 explicitly requires an in-app signal instead of a system banner in the foreground, so notifee adds no value. Rejected as unnecessary weight.

---

## R2. Message handler topology

**Decision**: The backend sends **notification + data** FCM messages. The app registers three handlers:

| App state         | Handler                                                                        | Responsibility                                                                                                           |
| ----------------- | ------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------ |
| Foreground        | `onMessage`                                                                    | No system banner (OS suppresses it). Show an in-app toast via `AppToast`, invalidate the inbox and unread-count queries. |
| Background / Quit | `setBackgroundMessageHandler`                                                  | OS renders the notification automatically. Handler only invalidates cached state; it performs no UI work.                |
| Tapped            | `onNotificationOpenedApp` (background) + `getInitialNotification` (cold start) | Route to the message detail.                                                                                             |

The background handler is registered at module scope in a dedicated `services/messaging.service.ts` imported from `app/_layout.tsx`, so it is installed before React mounts.

**Rationale**: This is the topology documented by RNFirebase. Using a `notification` payload means the OS renders background/quit notifications for free on both platforms — no notification channel management, no notifee, no local-notification scheduling. The `data` payload carries the routing information.

**Alternatives considered**:

- Data-only messages — would require `content-available` on iOS and `priority: high` on Android and the app itself would have to render every notification. Far more moving parts and unreliable delivery in low-power mode. Rejected.

**Constraint carried into the contract**: the FCM `data` payload must contain the message identifier (see `contracts/push-payload.md`).

---

## R3. Notification permission

**Decision**:

- iOS: `requestPermission(getMessaging())` from `@react-native-firebase/messaging`.
- Android 13+ (API 33): `PermissionsAndroid.request(PermissionsAndroid.PERMISSIONS.POST_NOTIFICATIONS)` from `react-native`. Android 12 and below need no runtime request.
- Requested **after successful authentication**, on first arrival at Home — not at cold start on the login screen.
- Denial is non-fatal: the app continues, and Inbox delivery is unaffected (FR-021).

**Rationale**: RNFirebase's `requestPermission` is a documented no-op on Android API ≤ 32 and does not cover the Android 13+ `POST_NOTIFICATIONS` runtime permission, so the platform API is required there. Deferring the prompt until after login means the OS dialog appears in a context where the value is explainable, which materially improves grant rates and satisfies FR-021's "user-facing explanation".

**Alternatives considered**:

- `react-native-permissions` — a whole additional native dependency to replace two lines of platform code. Rejected.
- Prompting at app launch — poor grant rate and the user has no context yet. Rejected.

---

## R4. iOS and Android native configuration

**Decision**: Amend `app.config.ts` only:

```ts
ios: {
  entitlements: { 'aps-environment': 'production' },
  infoPlist: { UIBackgroundModes: ['remote-notification'] },
},
```

and add `'@react-native-firebase/messaging'` to the `plugins` array **only if** `node_modules/@react-native-firebase/messaging/app.plugin.js` exists after install (RNFirebase documents that a plugin entry is required only for modules that ship a config plugin). Verify with:

```bash
ls node_modules/@react-native-firebase/messaging/app.plugin.js
```

No manual Xcode work is needed: `aps-environment` is the Push Notifications capability and `remote-notification` is the Background Modes sub-mode, both generated by prebuild. The Apple developer-portal key and the Firebase Cloud Messaging key are already provisioned by the customer.

`firebase.json` is left unchanged. Its default (absent `messaging_ios_foreground_presentation_options`) is exactly the behaviour FR-023 requires — no system banner while the app is foregrounded.

**Rationale**: Since Expo SDK 51 the notifications entitlement is no longer added automatically during prebuild, so it must be declared explicitly. Keeping everything in `app.config.ts` preserves Continuous Native Generation; the `ios/` and `android/` directories stay regenerable.

**Alternatives considered**:

- Editing `ios/SKSIX/SKSIX.entitlements` and `Info.plist` directly — would be erased by the next `expo prebuild --clean` (the repo has `prebuild`, `prebuild-acc`, `prebuild-prod` scripts). Rejected.

**Watch item**: RNFirebase documents `expo-build-properties.ios.forceStaticLinking` for Expo 54+. The project currently sets `buildReactNativeFromSource: true`, which bypasses the prebuilt-core path that `forceStaticLinking` exists to fix, and the app builds today with `app`/`analytics`/`crashlytics`. Add `forceStaticLinking: ['RNFBApp', 'RNFBAnalytics', 'RNFBCrashlytics', 'RNFBMessaging']` **only if** the iOS build fails after adding messaging. Do not add it pre-emptively.

---

## R5. Device token lifecycle

**Decision**: A `services/messaging.service.ts` owns the token:

1. After login succeeds and permission is granted, call `getToken()` and register it with the backend.
2. Subscribe to `onTokenRefresh` and re-register on rotation.
3. On logout, call the backend de-register endpoint **before** clearing auth, then `deleteToken()`.

**Rationale**: FR-020 requires that a device stops receiving a Storekeeper's notifications after logout, and FR-035 requires message content to be cleared on logout. Deleting the FCM token guarantees the previous account cannot be reached on that device even if the backend de-registration call fails.

**Alternatives considered**:

- FCM topic subscription per store — topics are explicitly documented as unsuitable for user-specific messaging and are not private. Rejected.

---

## R6. Notification tap routing

**Decision**: Routing is centralised in a `useMessageNotificationRouting` hook mounted in `app/_layout.tsx`:

- `getInitialNotification()` handles the cold-start case.
- `onNotificationOpenedApp` handles the background case.
- A payload is treated as an inbox message when `data.type` is `inbox_message` (or the legacy `message`), or when `data.deepLink` contains `inbox/message/`. The id is taken from `data.messageId`, falling back to the id embedded in `data.deepLink`.
- The target message id is stashed in a small in-memory pending-route holder. The hook navigates with `router.push({ pathname: ROUTES.MESSAGES.routes.DETAIL.path, params: { messageId } })` **only once `isAuthenticated` is true and the router is ready**, satisfying FR-022's "route through login first if the session is not valid".
- **2026-10-30 amendment**: When processing that authenticated pending tap, also send `POST /Inbox/{messageId}/read?channel=Push`. Do not wait for the request before navigating, change local Inbox read state, or invalidate message queries. Record failures through Crashlytics without a toast or local retry queue (FR-022a). Receipt handlers do not report push opens.

**Rationale**: The root layout already gates navigation with `<Stack.Protected guard={isAuthenticated}>`. Pushing a protected route before auth resolves would be dropped silently. Holding the pending id until the guard opens is the minimal correct approach and mirrors how the existing offline/force-update redirects are sequenced.

**Alternatives considered**:

- `expo-linking` URL deep links — the app already uses the `sixskapp` scheme for `services/deeplinks.service.ts` (a different, content-driven feature). Overloading it would blur two unrelated concerns and require URL parsing where a single id suffices. Rejected.

---

## R7. Video playback

**Decision** (amended): `expo-video` at `~3.0.15` (the version pinned by Expo SDK 54's `bundledNativeModules.json`). The message detail, popup and inbox list all show the video's **first frame as a poster** with a frosted circular play button (`VideoPlayButton`, built from `expo-blur` + `assets/icons/play.svg` — no new dependency). Playback is **tap-to-play**: `<VideoView>` runs with `nativeControls={false}` until the play button is tapped, then switches to `nativeControls` (play/pause/seek, and native full screen in the detail). In the inbox list the poster is decorative — tapping the row opens the detail. **No `expo-video` config plugin entry is added.**

**Rationale**: The config plugin only exists to enable background playback and Picture-in-Picture. FR-011/FR-012 require neither, so omitting the plugin avoids adding `UIBackgroundModes: ['audio']` and Android foreground-service permissions that the app does not need. Tap-to-play matches the Figma poster + play-button treatment and avoids autoplay; `nativeControls` then provides play/pause/seek for free once started.

**Superseded decision**: The original plan showed `<VideoView nativeControls />` immediately with no poster or play affordance.

**Alternatives considered**:

- `react-native-video` — a second video stack not aligned with the Expo SDK, requiring independent native version management. Rejected.
- `expo-av` — deprecated and removed in favour of `expo-video`. Rejected.

---

## R8. Full-screen video in landscape

**Decision** (amended): Full screen uses **expo-video's native full-screen control** (`<VideoView allowsFullscreen />`), which handles landscape rotation itself. The custom expand button and the dedicated landscape route were removed after the custom route showed orientation flicker; the PO signed off on native full screen for now. `expo-screen-orientation@~9.0.8` is still added and the app is still portrait-locked at the root (`ScreenOrientation.lockAsync(PORTRAIT_UP)` in `app/_layout.tsx`) with `app.config.ts` `orientation: 'default'`, so native full screen can rotate while every other screen stays portrait.

Full screen is disabled inside the popup modal (`allowsFullscreen={false}`) because native full screen over a React Native `<Modal>` tore the overlay down.

**Superseded decision**: A dedicated Expo Router screen (`app/messages/media-video.tsx`) that unlocked to landscape on mount and re-locked to portrait on unmount. The file remains in the repo but is no longer navigated to; keep it until the PO confirms native full screen is the permanent choice, then delete it.

**Rationale**: On iOS a portrait-only app cannot rotate, so `orientation: 'default'` plus the root lock is still required to make landscape reachable at all. Delegating the presentation to `AVPlayerViewController`'s native full screen removed the flicker the custom route introduced.

**Risk**: This is an app-wide native orientation change. It is listed in the plan's Complexity Tracking with an explicit regression check (every existing screen must remain portrait-locked). Watch item: if native full screen ever fails to rotate under the root portrait lock, revisit the dedicated route.

---

## R9. Full-screen image viewer

**Decision**: A dedicated Expo Router screen using `expo-image` (already a dependency) with pinch-to-zoom and pan built from `react-native-gesture-handler` (`~2.28.0`) and `react-native-reanimated` (`~4.1.1`), both already installed.

**Rationale**: FR-010 requires only "open full screen and dismiss". The Figma `Inbox - All - Image Full` frame shows a plain full-bleed image with a close affordance. Zero new dependencies.

**Alternatives considered**:

- `react-native-image-viewing` / `react-native-awesome-gallery` — unmaintained or heavyweight for a single-image, non-gallery use case. Rejected.

---

## R10. Home banner carousel

**Decision**: A horizontal `FlatList` with `pagingEnabled`, `showsHorizontalScrollIndicator={false}` and a dot indicator driven by `onViewableItemsChanged`. No new dependency.

**Rationale**: FR-029 requires a swipeable carousel with a position indicator and a single static banner when only one message is active — both trivially expressible with `FlatList`. The Figma `Home Banner - Single Banner` and `Home Banner - Multiple Banners` frames confirm there is no auto-play, no looping and no parallax.

**Alternatives considered**:

- `react-native-reanimated-carousel` — a substantial dependency for behaviour a paging `FlatList` already provides. Rejected.

---

## R11. Popup presentation and dismissal memory

**Decision**: React Native's built-in `<Modal>`, rendered by a `MessagePopup` component mounted **inside the Home screen** (`app/(tabs)/index.tsx`), shown on first Home activation after app launch and on an `AppState` transition to `'active'`. A plain tab-switch focus back to Home must not re-trigger it, so `useFocusEffect` alone is not a sufficient trigger. Dismissed/acknowledged message ids are kept in a new `useMessagePopupStore` (Zustand + `immer` + `persist` to AsyncStorage), cleared on logout.

**Rationale**: Clarification 3 scoped popups to Home only, so mounting inside the Home screen makes FR-028 structurally true rather than something enforced by a route denylist. `BaseBottomSheet` is the wrong primitive — the Figma `Popup` frame is a centred modal card over Home, not a sheet. Persisting only a set of ids is client state, not duplicated server data, so it stays compliant with Constitution III.

**Alternatives considered**:

- Reporting the popup as read on display so the backend stops returning it — would fire a read event without the detail view being opened, contradicting FR-015. Rejected.
- Mounting the popup in `app/_layout.tsx` — would require route-aware suppression logic to keep it off other screens. Rejected as strictly more complex.

---

## R12. Inbox pagination

**Decision**: `useInfiniteQuery` from TanStack Query (already installed), one query per tab, keyed `['messages', 'inbox', tab]`. `FlatList` with `onEndReached` → `fetchNextPage()`, and `RefreshControl` → `refetch()`. Month grouping is derived from the accumulated pages with `dayjs` (already installed) and rendered via `SectionList`-style `sections` or a flattened list with sticky headers.

**Rationale**: Clarification 5 requires paginated loading with pull-to-refresh and no history cap. `useInfiniteQuery` provides page accumulation, `hasNextPage`, `isFetchingNextPage` and cache invalidation with no bespoke state. This is the app's first infinite query, so the page-param convention established here becomes the local pattern.

**Alternatives considered**:

- Manual `useState` page accumulation — reimplements cache invalidation and refresh semantics that Query already handles, and would fight the global error toast wiring in `services/queries/queryClient.ts`. Rejected.

---

## R13. Read and acknowledge mutations

**Decision** (amended after backend/design alignment):

- **Inbox read is explicit, never on open.** A message is marked read **only** when the Storekeeper taps the **"Mark as read"** button on the list row (the read affordance in Figma). Opening a message leaves it **unread**. There is no auto-read-on-open and no separate "Acknowledge" button on the detail screen — the Figma detail frame has no button. Read calls `POST /Inbox/{id}/read?channel=Inbox`; on success invalidate the inbox, detail and unread-count queries.
- **Push opens are separate (2026-10-30).** The same endpoint accepts `channel=Push` for notification taps, not read confirmation. `reportMessageRead(messageId, channel)` requires `MessageChannels.Inbox` or `MessageChannels.Push`; both existing read/acknowledge query hooks explicitly bind `Inbox`. No new endpoint, request body, delivery-channel filtering, or change to popup/banner acknowledgement is needed.
- **Pop-ups and banners are acknowledged server-side.** Dismissing a pop-up calls `POST /messages/popups/{id}/ack`; the banner "OK, understood!" CTA calls `POST /messages/home-banners/{id}/ack`. Acknowledged channel messages are not returned again by the server.
- **Banner: wait, then remove.** The banner is removed only after the server confirms the acknowledgement. While the request is pending the CTA shows a spinner and every banner CTA ignores taps. A failure keeps the banner in the carousel and shows the global error toast with the backend's message, so the Storekeeper can retry (FR-029a).
- **Pop-up: close first, then acknowledge.** The pop-up closes immediately and the acknowledgement is sent in the background. Its dismiss button is its only exit, so waiting on the server would trap the Storekeeper behind a failing request. A failed acknowledgement shows the global error toast after the pop-up has closed (FR-026). The dismissal is kept in `useMessagePopupStore`, so a failed acknowledgement does not reopen the pop-up in this installation; it can reappear after a logout or reinstall, because the server never recorded it. `MessagePopupHost` mounts its own `AppToast`: `AppToast.show` uses the most recently mounted host, and a React Native `Modal` renders above the root one, so without it the toast would be hidden behind the next pop-up.
- **No optimistic update, no `retry`, no offline queue** — `retry: 0`, so an un-recorded read or banner acknowledgement never shows as done (FR-019). The pop-up is the one deliberate exception, for the reason above.
- **A failed Mark as read is not silent.** It uses the standard global error toast, which shows the backend's message (e.g. a `423` for a message that's no longer available), and the row stays unread so it can be retried (FR-019a). An earlier `allowGlobalErrorHandler: false` opt-out, left over from auto-read-on-open, was removed.
- **Expired messages render as read.** The backend rejects actions on expired messages, so a row with `IsExpired: true` shows no unread background, no accent bar and no Mark as read button, regardless of `IsRead` (FR-004). The flag comes from the server, not the device clock.

**Rationale**: The read trigger and the absence of a detail button were read from the rendered Figma frames (Constitution VIII), and the read-on-button-only rule was confirmed with the product owner. `API_V2.md` provides no server-driven acknowledge label and no inbox "acknowledge" endpoint distinct from read, so the app owns the button label (i18n) and treats the list "Mark as read" as the single read trigger. Channel-message acknowledgement moved from local-only dismissal to the real ack endpoints so dismissed pop-ups/banners stay gone across launches.

**Superseded decision**: The initial plan auto-marked a message read on open and gated a detail "Acknowledge" button on a server-supplied `acknowledgeLabel`. Neither matches the design or the API and both were removed.

**Alternatives considered**:

- Optimistic update with rollback — more code and a visible flicker for a behaviour the clarification explicitly rejected. Rejected.

---

## R14. Inbox entry point and unread count

**Decision** (amended after design review): The inbox is reached from **two** entry points that both appear in Figma — a dedicated **fourth bottom tab** (`Inbox`, `inbox-01` glyph) in `app/(tabs)/_layout.tsx`, and the bell icon with a numeric badge in the Home header. The count comes from a dedicated lightweight `useQuery(['messages', 'unreadCount'])`, refetched on app foreground, and is scoped to the active store (`storeCode` from `useActiveStoreStore`).

**Rationale**: Every Figma frame's bottom navigation shows four `Nav Item` instances at fixed positions — this is the real design, not a design-system default. The original decision (bell only, three-tab bar) was made from frame names/metadata rather than the rendered pixels and was corrected once the frames were screenshotted (Constitution VIII). The bell is kept as a secondary shortcut because it is also present in the Home frame. Keeping the count in React Query honours Constitution III.

**Superseded decision**: The initial plan added no tab and kept `app/(tabs)/_layout.tsx` a three-tab bar, reasoning the inbox was reached from the bell alone. This was wrong — see the corrected decision above.

**Alternatives considered**:

- Bell only, no tab — contradicted the four `Nav Item`s rendered in every frame. Rejected after rendering the designs.
- Deriving the count from the first inbox page — would be wrong as soon as unread messages exist beyond page one. Rejected.

---

## R15. State ownership

**Decision**:

| State                                                                                    | Owner                                              | Persistence          |
| ---------------------------------------------------------------------------------------- | -------------------------------------------------- | -------------------- |
| Inbox pages (All / Expired), message detail, unread count, active popups, active banners | TanStack React Query                               | Query cache (memory) |
| Dismissed popup ids                                                                      | `useMessagePopupStore` (Zustand + immer + persist) | AsyncStorage         |
| FCM token, pending notification route                                                    | `services/messaging.service.ts` module scope       | None                 |

**Rationale**: Constitution III forbids duplicating server data into Zustand. Only genuinely client-side state (which popups this user has dismissed) is persisted.

---

## R16. Internationalisation

**Decision**: A single new top-level `messages` namespace added to **both** `locales/es.json` and `locales/en.json`, nested 2–3 levels deep to match the existing `mfa.securityQuestions.text` convention. Spanish is authored first.

**Rationale**: Constitution IV. Matching the existing nesting depth keeps `i18n.t('messages.inbox.emptyTitle')` consistent with the rest of the file.

---

## R17. Analytics

**Decision**: Extend `AnalyticsEvents` in `services/analytics/events.ts` with `MESSAGE_OPENED`, `MESSAGE_MEDIA_PLAYED`, `MESSAGE_ACKNOWLEDGED`, `MESSAGE_NOTIFICATION_OPENED`, `MESSAGE_POPUP_DISMISSED`, `MESSAGE_BANNER_TAPPED`. Log through `AnalyticsService.logEvent`. New navigable routes are picked up automatically by `useScreenTracking`.

**Rationale**: Constitution VI requires typed event names and the established screen-tracking pattern. FR-033 enumerates exactly these six interactions.

---

## R18. Testing

**Decision** (amended by constitution v2.0.0): The feature is covered by the Jest suite (jest-expo + React Native Testing Library). Services and native modules are mocked at the boundary; stores, i18n and React Query run for real. `yarn test:coverage` (≥ 98 %) and `yarn lint` are the automated gates, and the manual scenarios in `quickstart.md` cover what needs a device (push delivery, performance, orientation).

**Rationale**: Constitution Principle IX requires every feature to ship with tests. The FCM, `expo-video`, `expo-blur` and `expo-screen-orientation` modules have no JS fallback under Jest, so they're mocked in `test/setup.ts`; without those mocks every suite importing the feature transitively crashed.

**Superseded decision**: The original plan shipped with no automated tests because the earlier constitution said tests were not required and must not be added unless requested.

---

## R19. Building before the backend exists — COMPLETED (mock layer removed)

**Status**: The temporary mock layer has been **removed** now that the real endpoints exist (`API_V2.md`: Devices, Inbox, ChannelMessages controllers). `services/messages.service.ts` calls `ApiClient<Req, Res>` directly against the live routes; there is no mock file, flag or ternary. The record below is kept for history.

**Original decision**: While the backend did not exist, each service function short-circuited to a fixture in `services/mocks/messages.mock.ts` behind `process.env.EXPO_PUBLIC_USE_MESSAGE_MOCKS === 'true'` (declared in `.env.dev` only). The mock boundary sat at the lowest layer that still returned domain types, so the query hooks, components and screens above it were exercised for real and the swap was a deletion, not a rewrite.

**Cutover performed** (all items complete):

- [x] Confirmed the real paths with the backend team and corrected `services/api/endpoint.ts` (`/Inbox`, `/Devices`, `/messages/popups`, `/messages/home-banners`)
- [x] Aligned `types/message.type.ts` with the real **PascalCase** response fields and `pageIndex`/`totalPages` paging
- [x] Deleted `services/mocks/messages.mock.ts`
- [x] Removed the `USE_MOCKS` constant and every ternary from `services/messages.service.ts`
- [x] Removed `EXPO_PUBLIC_USE_MESSAGE_MOCKS` from `.env.dev`
- [x] Verified no references remain outside `specs/`
- [ ] Re-validate the scenarios in [quickstart.md](quickstart.md) against the live API once BE deploys (pending)

**Push mocking**: FCM is not mocked. The push `data` payload carries `type: "message"` and `messageId: "<uuid>"`; test notifications are sent from the Firebase console.

---

## R20. Message-not-available detail state

**Decision**: When `GET /Inbox/{messageId}` fails because the message is unavailable — `404` (not a delivery for this keeper / removed) or `423` (locked for the recipient) — the detail screen shows a not-available state: the `assets/images/inbox/not-found.png` illustration plus the **backend's** two strings, `Data` as the bold line and `Details` below (matching Figma `1645:15014`). The app renders them verbatim and does not localise or substitute its own copy. `useMessageDetail` sets `retry: false` so the state appears immediately.

**Rationale**: The backend owns the user-facing copy (and its localisation), so the app must not duplicate it. `ApiClient` collapses errors to a single string and drops `Details`, so `fetchMessageDetail` issues the request through `axiosInstance` (same interceptors) to read both `Data` and `Details` from the error body, and throws a minimal `MessageUnavailableError` carrying them.

**Alternatives considered**:

- Localised in-app copy — rejected; the backend returns both strings and owns their wording per status.
- Enhancing `ApiClient` globally to carry `Details` on every error — larger blast radius than the single screen that needs it. Rejected.

---

## Resolved Technical Context summary

| Item                 | Value                                                                                                                                                                         |
| -------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Language/Version     | TypeScript `~5.9.2`, React `19.1.0`, React Native `0.81.5`, Expo `~54.0.33`                                                                                                   |
| New dependencies     | `@react-native-firebase/messaging@23.4.0`, `expo-video@~3.0.15`, `expo-screen-orientation@~9.0.8`                                                                             |
| Storage              | Expo Secure Store (auth, unchanged), AsyncStorage (dismissed popup ids), React Query cache                                                                                    |
| Testing              | Jest (jest-expo + RNTL); `yarn test:coverage` ≥ 98 % and `yarn lint` are the gates (R18)                                                                                      |
| Backend availability | Live — `API_V2.md` (Devices, Inbox, ChannelMessages). Mock layer removed (R19). PascalCase `ApiResult<T>` envelope, `storeCode`-scoped, signed media URLs with expiry refresh |
| Target Platform      | iOS 15.1+ / Android 8+, physical device required for push validation                                                                                                          |
| Project Type         | Expo Router mobile app (single project)                                                                                                                                       |
| Performance Goals    | On the reference conditions in spec.md: inbox first page < 2 s (SC-003), video start < 3 s (SC-007), notification-to-read < 15 s (SC-001), 60 fps carousel and list scrolling |
| Constraints          | Portrait-locked except the full-screen video route; offline-tolerant reads; no offline write queue; React Compiler compatible                                                 |
| Scale/Scope          | ~9 new screens/surfaces, 1 new service, 1 new store, 2 new query hooks + 2 mutations                                                                                          |
