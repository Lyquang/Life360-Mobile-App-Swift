# Notifications & App Icon Setup

## Implemented in the iOS app

- Profile -> Settings -> Notifications, in Vietnamese and English.
- Master, chat and SOS preferences persisted per account on this device.
- Explicit authorization request; denied/provisional states and iPhone Settings link.
- Socket-driven chat local notifications, excluding own messages and the visible
  conversation; SOS/stay local alerts when the app is not active but still running.
- Bounded event deduplication; logout clears pending/delivered notifications.
- APNs token callback and failure state, Debug/Release entitlement configuration.
- Chat/member taps check server membership before coordinator navigation. Pending
  map focus waits for a member's realtime location when the cache is empty.

Local notifications are not a substitute for remote push. Socket events cannot
reliably execute while iOS suspends or terminates the app. Delivery is not an
emergency-service guarantee. Foreground SOS still uses the existing in-app banner;
there is no fullscreen takeover, alarm loop or Critical Alert implementation.
Badge permission is requested, but unread-count reconciliation is not implemented.
Current preferences govern system/local alerts, not the existing in-app SOS banner.

## Backend integration still required

The inspected backend has no APNs provider or device-token/preferences endpoints.
The app deliberately does not call invented endpoints. A received APNs token is
not proof of backend registration; Settings explicitly reports remote push unavailable.

Agree a versioned contract for these operations before shipping remote push:

| Operation | Required behavior |
| --- | --- |
| Register installation | Authenticated, idempotent binding of installation/token to account, bundle ID, APNs environment and language |
| Update preferences | Store master/chat/SOS per installation; return confirmed state/version |
| Remove binding | Remove account association on logout and revoke invalid tokens |
| Publish event | Resolve current Circle/conversation membership, exclude sender, enforce preferences, compute unread badge, send APNs alert |

Queue failed preference updates with retry and distinguish locally saved from
server-confirmed state. Local toggles cannot suppress a server alert already sent
while the app is suspended. Handle token rotation, multiple devices and APNs 410.
Keep APNs `.p8`, Key ID and Team ID in server secrets, never in mobile assets/git.
Once APNs delivery is enabled, disable the matching socket-to-local fallback;
in-process deduplication cannot prevent duplicate banners already displayed by iOS.

### Proposed compatible payload (not a deployed endpoint)

```json
{
  "aps": {
    "alert": { "title": "FamilyTracker", "body": "You have a new message" },
    "sound": "default",
    "badge": 3,
    "thread-id": "conversation-123"
  },
  "kind": "conversation",
  "id": "conversation-123",
  "accountId": "recipient-user-id",
  "eventId": "unique-message-id"
}
```

`kind` supports `conversation`, `sos`, `member`; for the latter two `id` is the
member ID. The recipient must still have access at tap time. The current SOS
route waits for live location, not a historical incident coordinate. A future
incident contract should include an authorized event lookup and timestamp so
old notifications do not masquerade as current emergencies.

## Xcode and Apple configuration

1. Use an Apple Developer team/provisioning profile supporting Push Notifications.
   Select your own Team and Bundle Identifier; this repository's team is not yours.
2. Target -> Signing & Capabilities -> Push Notifications. Verify the signed app
   contains `aps-environment`, not just an entry in the project editor.
3. Enable Time Sensitive Notifications for SOS. This does not bypass silent mode
   or guarantee Focus interruption; the user can disable it. Critical Alerts need
   separate Apple approval and user authorization; no Critical entitlement is added.
4. Background Modes -> Remote notifications is already declared in Info.plist.
   It enables background-update handling, not unlimited execution or guaranteed
   silent-push delivery. Preserve the existing location background mode.
5. `FamilyTracker.entitlements` uses `APNS_ENVIRONMENT`: development for Debug,
   production for Release. Verify archive/export provisioning matches APNs endpoint.
   Keep changes consistent in `project.yml` and the checked-in Xcode project.
6. A free/personal signing profile may reject these entitlements. For local-only
   testing use Simulator or a dedicated local-only configuration without APNs
   entitlements; do not treat that build as a remote-push test.

Apple references: [APNs registration](https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns),
[background updates](https://developer.apple.com/documentation/usernotifications/pushing-background-updates-to-your-app),
[Critical Alerts](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.usernotifications.critical-alerts).

## App Icon

The catalog is configured but artwork has not been supplied; the icon is still
an empty slot, not a completed visual asset.

1. Prepare an opaque, square 1024 x 1024 PNG. Do not pre-round its corners.
2. Open `FamilyTracker/Resources/Assets.xcassets/AppIcon.appiconset` in Xcode.
3. Choose iOS Single Size and drop the PNG into the universal 1024 slot. Xcode
   records the filename in `Contents.json` and generates required sizes.
4. Confirm target App Icons Source is `AppIcon` (already configured).
5. Build/install and inspect Home Screen, Settings and notification icon; validate
   an Archive before distribution. Supply separate appearance variants only if desired.

See [Apple's asset-catalog icon guide](https://developer.apple.com/documentation/xcode/configuring-your-app-icon).

## Verification

```bash
bash scripts/test_notifications.sh
bash scripts/test_localization.sh
bash scripts/test_networking.sh
```

Before claiming production readiness, test on two physical devices/accounts:
permission allowed/denied, both languages, switches/relaunch/logout, own-message
suppression, open-chat suppression, duplicate events, revoked membership, cold
start/deep link, locked/background delivery, Focus, Time Sensitive off and unread
badge reconciliation. Simulator payload injection tests routing, not APNs transport.
