# Location Privacy And Circle Membership API - iOS Contract

## 1. Location sharing state

Privacy applies to the whole account, not one Circle. All endpoints require:

```http
Authorization: Bearer <accessToken>
```

### Read state

```http
GET /api/v1/privacy/location-sharing
```

```json
{
  "success": true,
  "data": {
    "enabled": false,
    "pausedUntil": "2026-10-19T12:00:00.000Z",
    "updatedAt": "2026-10-19T10:00:00.000Z"
  }
}
```

`enabled` is the effective state. After `pausedUntil`, the backend treats sharing as enabled automatically.

### Pause indefinitely

```http
PATCH /api/v1/privacy/location-sharing
Content-Type: application/json

{ "enabled": false }
```

`pausedUntil: null` has the same indefinite meaning.

### Pause temporarily

```json
{
  "enabled": false,
  "pausedUntil": "2026-10-19T12:00:00.000Z"
}
```

The timestamp must be in the future and at most seven days ahead.

### Resume

```json
{ "enabled": true }
```

Do not send a non-null `pausedUntil` with `enabled=true`.

While paused:

- `update_location` emits Socket `error` with code `LOCATION_SHARING_PAUSED` and stores nothing.
- `POST /locations/batch` returns HTTP 403 and stores nothing.
- Other Circle members receive HTTP 403 for history, journey and live-trail reads.
- Existing live-trail watches close immediately with reason `sharing_paused`.
- In-memory stay duration is reset, so resuming cannot emit a milestone accumulated across the privacy pause.
- New digest snapshots omit coordinates and duration.
- The account owner can still read their existing history.
- Explicit `sos_alert` is still delivered, including coordinates supplied in that SOS payload. It does not resume normal sharing.

## 2. Leave a Circle

```http
DELETE /api/v1/groups/{groupId}/members/me
```

```json
{
  "success": true,
  "message": "You left the Circle.",
  "data": {
    "groupId": "671234567890abcdef012345",
    "conversationId": "681234567890abcdef012345",
    "userId": "661234567890abcdef012345",
    "left": true
  }
}
```

Circle and group-chat memberships are removed atomically. An admin receives HTTP 409 until ownership transfer or Circle deletion is implemented.

## 3. Admin removes a member

```http
DELETE /api/v1/groups/{groupId}/members/{userId}
```

Only the Circle admin can call this endpoint. The admin cannot remove themselves.

## 4. Socket events

The removed user's connected devices receive:

```json
{
  "event": "group:membership_ended",
  "payload": {
    "groupId": "671234567890abcdef012345",
    "userId": "661234567890abcdef012345",
    "removedBy": "651234567890abcdef012345"
  }
}
```

Remaining Circle members receive `group:member_left` with the same payload. The removed user's sockets leave the Circle and group-chat rooms immediately.

Any live-trail watch that no longer has authorization receives:

```json
{
  "event": "journey:trail_closed",
  "payload": {
    "userId": "651234567890abcdef012345",
    "trailId": "691234567890abcdef012345",
    "reason": "permission_revoked"
  }
}
```

If the two users still share another Circle, the watch remains active.

## 5. Errors

| HTTP | Code | Meaning |
| --- | --- | --- |
| 400 | `VALIDATION_ERROR` | Invalid body, date or ID |
| 400 | `BAD_REQUEST` | Pause is expired or more than seven days ahead |
| 401 | `UNAUTHORIZED` | Access token missing, invalid or expired |
| 403 | `LOCATION_SHARING_PAUSED` | Target account currently hides location |
| 403 | `FORBIDDEN` | Not a member/admin or no shared Circle |
| 404 | `NOT_FOUND` | Circle, user or membership not found |
| 409 | `CONFLICT` | Attempt to leave/remove the Circle admin |

## 6. Swift models

```swift
struct LocationSharingState: Decodable, Sendable {
    let enabled: Bool
    let pausedUntil: Date?
    let updatedAt: Date?
}

struct SetLocationSharingRequest: Encodable, Sendable {
    let enabled: Bool
    let pausedUntil: Date?
}

struct CircleMembershipResult: Decodable, Sendable {
    let groupId: String
    let conversationId: String?
    let userId: String
    let left: Bool
}

struct CircleMembershipEvent: Decodable, Sendable {
    let groupId: String
    let userId: String
    let removedBy: String
}
```

On `group:membership_ended`, remove the Circle and its conversation from local stores, stop relevant screens/watchers, and navigate away if the removed conversation is open. On `sharing_paused`, stop background location transmission and clear queued location points so they are not uploaded after sharing resumes.

