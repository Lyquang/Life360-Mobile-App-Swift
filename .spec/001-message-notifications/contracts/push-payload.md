# Contract: FCM Push Payload

**Feature**: `001-message-notifications` | **Date**: 2026-08-04

Defines the Firebase Cloud Messaging payload the backend must send so the mobile app can route to the correct message. Required by FR-022, FR-023 and FR-024.

## Required shape

The backend MUST send a **notification + data** message (not data-only):

```json
{
  "token": "<device-fcm-token>",
  "notification": {
    "title": "Nuevo mensaje",
    "body": "Promoción de temporada disponible"
  },
  "data": {
    "type": "inbox_message",
    "messageId": "<message-id>",
    "deepLink": "sixmx://inbox/message/<message-id>"
  },
  "android": { "priority": "high" },
  "apns": {
    "headers": { "apns-priority": "10" },
    "payload": { "aps": { "sound": "default" } }
  }
}
```

### `data` fields

| Key         | Type     | Required | Purpose                                                                                                                                                                                                                           |
| ----------- | -------- | -------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `type`      | `string` | yes      | Discriminator. Backend sends `"inbox_message"`; the app also accepts the legacy `"message"`. Payloads with any other `type` (and no inbox `deepLink`) are ignored, so the channel stays shareable with future notification kinds. |
| `messageId` | `string` | yes      | Matches `Message.id`. The app routes to the detail view with this value.                                                                                                                                                          |
| `deepLink`  | `string` | no       | `sixmx://inbox/message/<message-id>`. Used as a fallback source of the id when `messageId` is absent; its presence alone also marks the payload as an inbox message.                                                              |

> FCM requires every `data` value to be a string. Do not send numbers, booleans or nested objects.

### Why `notification` + `data` and not data-only

With a `notification` block present, the OS renders the notification itself while the app is backgrounded or quit — no notification channel management and no local-notification library is needed on the client. Data-only messages would require `content-available` on iOS and `priority: high` on Android and are silently dropped in low-power mode.

## Client handling matrix

| App state           | Handler                       | Behaviour                                                                                              |
| ------------------- | ----------------------------- | ------------------------------------------------------------------------------------------------------ |
| Foreground          | `onMessage`                   | OS shows nothing. App shows an in-app toast and invalidates the inbox + unread-count queries (FR-023). |
| Background          | `setBackgroundMessageHandler` | OS shows the notification. Handler only invalidates cached state — no UI work.                         |
| Quit                | `setBackgroundMessageHandler` | Same as background.                                                                                    |
| Tapped (background) | `onNotificationOpenedApp`     | Once authenticated, report `channel=Push` and route to message detail without awaiting the report. |
| Tapped (quit)       | `getInitialNotification`      | Same reporting and routing after authentication and router readiness. |

If the session is invalid when a notification is tapped, the app holds `messageId` and reports the push open and routes to the detail view only after login succeeds (FR-022, FR-022a).

The FCM payload is unchanged: the interaction channel is supplied by mobile as `POST /Inbox/{messageId}/read?channel=Push`, not added to the notification payload. Receiving a notification alone never sends this report. A push open is independent of Inbox read confirmation (`channel=Inbox`); it does not change local Inbox read state. Reporting failures go to Crashlytics without blocking navigation, showing a toast, or queuing retries. See [messages-api.md](messages-api.md#current-amendment-2026-10-30-channel-qualified-read-endpoint).

## Localisation

The `notification.title` and `notification.body` are rendered by the OS and cannot be translated on the device. The backend MUST send them in the Storekeeper's configured language. All other strings in this feature are localised in-app (FR-032).

## Constraints

- **iOS**: requires a physical device. React Native Firebase deliberately skips `registerForRemoteNotifications` on ARM64 simulators, so no APNs token is issued there.
- **iOS**: `setBackgroundMessageHandler` does not fire when Background App Refresh is disabled or the device is in Low Power Mode.
- **Android**: notification delegation via Google Play is disabled by React Native Firebase by default, which is required for the listeners to fire.
