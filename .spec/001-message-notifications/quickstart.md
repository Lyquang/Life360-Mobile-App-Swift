# Quickstart: Validating Message Management on Mobile

**Feature**: `001-message-notifications` | **Date**: 2026-08-04

How to run and validate this feature. The automated gates are `yarn test:coverage` (Jest, ≥ 98 % coverage) and `yarn lint`; the manual scenarios below cover what needs a real device — push delivery, orientation and performance (see `.specify/memory/constitution.md` Principle IX and [docs/testing.md](../../docs/testing.md)).

---

## Prerequisites

| Requirement                                              | Why                                                                                                                                                                                                                      |
| -------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **A physical iOS device** (iOS 15.1+)                    | React Native Firebase skips APNs registration on ARM64 simulators, so no push token is issued there. Everything except push can be validated on a simulator.                                                             |
| An Android device or emulator with Google Play services  | FCM requires Play services. Android 13+ needed to exercise the `POST_NOTIFICATIONS` prompt.                                                                                                                              |
| Apple Developer account access                           | The provisioning profile must carry the Push Notifications capability. Already provisioned by the customer.                                                                                                              |
| Firebase console access to the target project            | To send test messages and confirm the APNs key upload.                                                                                                                                                                   |
| Backend message APIs reachable on the target environment | Live per [API_V2.md](../../API_V2.md) (Devices, Inbox, ChannelMessages) on `EXPO_PUBLIC_API_URL`. The mock layer has been removed (see [research.md](research.md) R19), so every scenario now runs against the real API. |

Background App Refresh must be ON and Low Power Mode OFF on the iOS device, otherwise background message handling will not fire.

---

## Setup

```bash
yarn install
```

Native configuration changed in this feature (push entitlements, background modes, orientation, new native modules), so a prebuild is required before the first run:

```bash
# dev environment
yarn prebuild

# acceptance
yarn prebuild-acc

# production
yarn prebuild-prod
```

> If a development build was already installed before `@react-native-firebase/messaging` was added, uninstall it first — the old binary has no messaging native module and will fail with `RNFBMessagingModule not found`.

Run on a device:

```bash
yarn ios          # or yarn ios-acc / yarn ios-prod
yarn android      # or yarn android-acc / yarn android-prod
```

Start the bundler without rebuilding:

```bash
yarn start        # yarn start-acc / yarn start-prod
```

---

## Quality gate

```bash
yarn lint
```

Must pass with no errors before the feature is considered done.

---

## Sending a test notification

1. Firebase console → **Engage → Messaging → Create your first campaign → Firebase Notification messages**.
2. Fill in the notification title and body.
3. **Send test message**, then paste the device FCM token. Log the token during development from `services/messaging.service.ts`.
4. Under **Additional options → Custom data**, add the two keys required by [contracts/push-payload.md](contracts/push-payload.md):
   - `type` = `message`
   - `messageId` = an id that exists in the target environment

A campaign without the custom data keys still delivers, but tapping it will not route to a message detail — that is expected, not a bug.

---

## Validation scenarios

Each scenario maps to a user story in [spec.md](spec.md). Entity fields are defined in [data-model.md](data-model.md).

### US1 — Read messages in the Inbox (P1)

| Step                                          | Expected                                                                                                               |
| --------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| Tap the bell icon in the Home header          | The Messages inbox opens on the **All** tab                                                                            |
| Observe the list                              | Messages grouped by month, newest first; unread items visually distinct                                                |
| Scroll to the bottom                          | The next page loads automatically; no history cap                                                                      |
| Pull down                                     | The list refreshes from page 1                                                                                         |
| Switch to **Expired**                         | Past-end-date messages listed, fully readable including media                                                          |
| Open a message with an image                  | Detail shows title, body, publication date and the image; tapping the image opens it full screen and it dismisses back |
| Open a message with a video                   | Video plays with play/pause/seek; full screen rotates to landscape and returns to portrait on exit                     |
| Return to the list without marking read       | The message remains unread; simply opening detail did not send an Inbox read confirmation |
| Tap **Mark as read** on an unread list row     | Sends `POST /Inbox/{messageId}/read?channel=Inbox`; after success the read action disappears and the badge refreshes |
| Look for a delete affordance                  | None exists anywhere                                                                                                   |
| Open a tab with no messages                   | A dedicated empty state is shown                                                                                       |

**Offline sub-checks**

- Enable airplane mode and open the inbox: previously loaded messages remain readable, and unavailable data is clearly communicated.
- Tap acknowledge while offline: an error appears, the button returns to un-acknowledged, and a retry when back online succeeds. Nothing is queued.

### US2 — Notification tap routing (P2)

| App state when the notification arrives | Expected                                                                                     |
| --------------------------------------- | -------------------------------------------------------------------------------------------- |
| **Foreground**                          | No system banner. An in-app toast appears and the bell badge count updates.                  |
| **Background**                          | System notification appears. Tapping it opens the correct message detail.                    |
| **Quit** (swiped away)                  | System notification appears. Tapping it cold-starts the app onto the correct message detail. |
| **Logged out**                          | Tapping routes to login first, then lands on the message detail after a successful sign-in.  |

Also verify: denying the notification permission prompt does not break the app, and messages still arrive in the Inbox.

Log out on device A, then send a notification for that Storekeeper — device A must not receive it.

### Channel-separated tracking (2026-10-30)

Use an unread message targeted to the signed-in Storekeeper. Inspect requests through the app's network tooling and have the backend/portal team check Admin Message Details.

| Action | Expected |
| ------ | -------- |
| Receive a notification without tapping it, including foreground receipt | No `POST /Inbox/{messageId}/read` request |
| Open detail from the Inbox row | No read request; Inbox read state stays unchanged |
| Tap **Mark as read** | One `channel=Inbox` request; existing read confirmation and badge behaviour preserved |
| Tap push while the app is backgrounded | One `channel=Push` request and detail navigation; Inbox stays unread |
| Tap push to cold-start the app | Same channel and read-state separation |
| Tap push while logged out | No report before authentication; after login one `channel=Push` request and detail navigation |
| Tap an old notification for an already-read message | Still reports `channel=Push`; Inbox remains read |
| Fail the push-open request | Navigation proceeds; failure is recorded in Crashlytics; no tracking-error toast or local retry |
| Later mark that same message read in Inbox | Sends `channel=Inbox` independently of the earlier push open |
| Check Admin Message Details | Push opens and Inbox read confirmations are stored/displayed separately by the backend and portal |

These device/backend/Admin checks are pending (T079); mocked automated tests do not establish that the deployed backend supports the query or preserves Inbox state.

### iOS Simulator: Inbox API and simulated notification taps

This is a supplementary manual workflow, not evidence that real Firebase/APNs delivery works. Inbox calls use the live backend; notification injection bypasses Firebase/APNs. These steps have not yet been executed for this amendment.

1. Run `yarn ios-acc` with an iOS Simulator selected, sign in, select the target store, and allow notifications. Use the native app, not Expo Go. Keep Metro running for cold-start tests.
2. Observe requests with the configured Rozenite network tooling when `WITH_ROZENITE=true`, or an approved local network inspector. Keep tokens and message content private.
3. Use a valid, active, unread message returned by the acc Inbox API. Obtain its exact `MessageId` from the response.
4. Open its detail from Inbox and return: no read POST should occur. Tap **Mark as read**: verify `POST /Inbox/{messageId}/read?channel=Inbox`, the backend success response, and the refreshed row/badge.
5. Use another unread message for the push test. Save the following APNs-format JSON as a local `six-message-test.apns` file, replacing `REAL_MESSAGE_ID`:

```json
{
  "aps": {
    "alert": {
      "title": "Simulator message test",
      "body": "Tap to open the message"
    },
    "sound": "default"
  },
  "gcm.message_id": "simulator-push-test-001",
  "type": "inbox_message",
  "messageId": "REAL_MESSAGE_ID"
}
```

Custom fields are top-level APNs keys, not nested inside the FCM HTTP API's `data` object. The installed RNFirebase notification-response delegate checks `gcm.message_id` before forwarding a tap; its serializer exposes `type` and `messageId` in the JS message data. Use a fresh `gcm.message_id` for each injected notification.

6. Put the app in the background using the Simulator Home action, then run:

```bash
xcrun simctl push booted mx.heineken.sixskapp.acc ./six-message-test.apns
```

7. Receiving the notification alone must not send a read POST. Tap it in the Simulator: expect detail navigation and one `channel=Push` request, with no `channel=Inbox` request. Refresh Inbox: the message must still be unread. Then **Mark as read** must send its independent `channel=Inbox` request.
8. Repeat after terminating the app using the Simulator app switcher to exercise cold start. Tap the notification, not the app icon.
9. Repeat while logged out, using a message belonging to the account that will sign in: no report before login; after login expect one `channel=Push` report and detail navigation.

If a banner does not appear, check notification permission, the installed acc bundle identifier, the booted Simulator, and that the app is backgrounded. If a banner appears but tapping it does not reach the JS notification handler, this simulated route has not passed on that Xcode/iOS runtime; verify on a physical device rather than substituting an ordinary deep link (which does not exercise push tracking). An FCM/APNs token-registration failure on Simulator alone does not establish an Inbox API failure.

Inspect the actual HTTP response and refreshed Inbox state; a visible notification or successful `simctl` command alone is not a pass. Backend/Admin separation and real device delivery remain part of T079.

### US3 — Popup on app open (P3)

| Step                                                                       | Expected                                                                       |
| -------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| Publish a popup-channel message, then cold start the app                   | The popup appears as a modal over Home                                         |
| Background the app and return                                              | An eligible, not-yet-dismissed popup appears again on Home                     |
| Dismiss the popup, background and return                                   | It does not appear again                                                       |
| Dismiss the popup, then open the Inbox                                     | Popup acknowledgement uses its own endpoint; it does not send an Inbox read confirmation |
| Navigate to Electronic Orders or Account and background/foreground the app | No popup appears on those screens                                              |
| Have two eligible popups                                                   | They appear one after the other in a stable order                              |

### US4 — Home banner carousel (P4)

| Step                               | Expected                                                   |
| ---------------------------------- | ---------------------------------------------------------- |
| One active banner message          | A single static banner on Home, no position indicator      |
| Two or more active banner messages | A swipeable carousel with a position indicator             |
| Tap a banner                       | The corresponding message detail opens                     |
| No active banner messages          | Home renders normally with no banner area and no empty gap |

### Cross-cutting

| Check                                                           | Expected                                                                                                                                                                                               |
| --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Switch device language to English and back to Spanish           | Every string added by this feature is translated in both; Spanish is the default                                                                                                                       |
| Verify Firebase Analytics DebugView                             | `message_opened`, `message_media_played`, `message_acknowledged`, `message_notification_opened`, `message_popup_dismissed`, `message_banner_tapped` are recorded                                       |
| Verify screen tracking                                          | The inbox, message detail, full-screen image and full-screen video screens appear as screen views                                                                                                      |
| **Orientation regression**                                      | Every pre-existing screen (Home, Electronic Orders, Account, Login, MFA, webviews, commission receipt) stays locked to portrait when the device is rotated. Only the full-screen video screen rotates. |
| Log out                                                         | Message content, the unread badge and the dismissed-popup set are all cleared                                                                                                                          |
| Start an electronic order while a popup or notification arrives | The flow is never interrupted or blocked (SC-008)                                                                                                                                                      |

### Performance measurement

Run these on the reference conditions defined in [spec.md](spec.md) Success Criteria — 4G/LTE (~10 Mbps, ~100 ms RTT), a mid-tier Android or iPhone 11-class device, warm app start, an inbox page of 20 messages and a video near the ~1 minute / 30 MB bound. Measure three times and take the median.

| Criterion | How to measure                                                                              | Target |
| --------- | ------------------------------------------------------------------------------------------- | ------ |
| SC-003    | Time from tapping the Home bell to the first message row being visible                      | < 2 s  |
| SC-007    | Time from tapping play to the first video frame (`onFirstFrameRender`)                      | < 3 s  |
| SC-001    | Time from tapping the system notification to the message body and media being fully visible | < 15 s |

SC-002, SC-004, SC-005 and SC-006 are post-launch outcome metrics measured through backend delivery statistics, portal reporting and user research. They are not verified on device.

---

## Troubleshooting

| Symptom                                       | Cause / fix                                                                                                                                                                                               |
| --------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `RNFBMessagingModule not found`               | Stale development build. Uninstall the app, `yarn prebuild`, rebuild.                                                                                                                                     |
| No APNs token on iOS                          | Running on a simulator. Use a physical device.                                                                                                                                                            |
| Background handler never fires on iOS         | Background App Refresh disabled or Low Power Mode on.                                                                                                                                                     |
| Notification arrives but tapping does nothing | The `data.messageId` key is missing from the payload.                                                                                                                                                     |
| iOS build fails after adding messaging        | Add `forceStaticLinking: ['RNFBApp', 'RNFBAnalytics', 'RNFBCrashlytics', 'RNFBMessaging']` under `expo-build-properties.ios` in [app.config.ts](../../app.config.ts) — see [research.md](research.md) R4. |
| Every screen suddenly rotates                 | The root portrait lock is missing or ran after the first render. See [research.md](research.md) R8.                                                                                                       |
