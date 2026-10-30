# Contract: Message APIs (mobile ⇄ backend)

**Feature**: `001-message-notifications` | **Date**: 2026-08-04

> ⚠️ **Superseded.** This was the pre-build proposal. The shipped integration follows the delivered backend contract in [API_V2.md](../../../API_V2.md) (Devices, Inbox, ChannelMessages controllers; PascalCase `ApiResult<T>` envelope; `pageIndex`/`totalPages` paging; `storeCode` scoping). Treat `API_V2.md` as authoritative; this file is kept for history.

## Current amendment (2026-10-30): Channel-qualified read endpoint

This amendment records the current mobile contract for FR-015a and FR-022a and overrides the historical read proposal below. The referenced `API_V2.md` is not present in this checkout; keep this amendment with the feature's source of truth.

```http
POST /Inbox/{messageId}/read?channel=Inbox
POST /Inbox/{messageId}/read?channel=Push
```

| Field | Contract |
| ----- | -------- |
| Path | `messageId`: target message identifier |
| Query | `channel`: required, case-sensitive `Inbox` or `Push` (`MessageChannels` in mobile) |
| Request body | None |
| Success payload | Existing `MarkReadResponse`: `{ MarkedCount: number }`, inside the standard `{ message: { Data: ... } }` envelope |
| Auth | Existing authenticated API client and token-refresh interceptors |

- **Inbox**: sent on explicit **Mark as read**, and by the existing shared confirmation mutation. Keep the current query invalidations and backend-error toast.
- **Push**: sent when an authenticated pending notification tap is processed, including cold start and taps held until login. Do not send on notification receipt, Inbox row navigation, or ordinary detail opening.
- A push open is recorded independently from Inbox read confirmation. The backend must preserve Inbox read state for `channel=Push`, and expose separate interactions for the Admin Message Details view; backend/portal validation remains outstanding.
- Mobile does not await push reporting before navigating, update/invalidate Inbox read state, or queue local retries. Failures are recorded through Crashlytics without a user-facing toast.
- Existing Firebase `MESSAGE_NOTIFICATION_OPENED` analytics remains separate from this backend API call.
- Popup/banner acknowledgement endpoints are unchanged.

## Historical proposal (superseded)

This is the contract the **mobile app depends on**. The backend is an external dependency (see spec Dependencies); these endpoints are not built by this feature. Paths are proposals and MUST be confirmed with the backend team before implementation — the shapes below are the binding part.

## Conventions

- Base URL: `EXPO_PUBLIC_API_URL` (per environment).
- Auth: `Authorization: Bearer <accessToken>`, injected by the request interceptor in [configs/api.config.ts](../../configs/api.config.ts). `401` triggers the existing single-flight refresh queue.
- **Envelope**: every response body is wrapped as `{ "message": { "Data": <payload> } }`. `ApiClient` returns `response.data.message.Data`, so the `Payload` column below is what the service layer receives.
- All endpoint paths are added to [services/api/endpoint.ts](../../services/api/endpoint.ts) under a new `messages` group. `:param` placeholders are substituted at the call site, matching the existing convention.
- Every call is scoped server-side to the signed-in Storekeeper. The app never sends a store or user identifier for scoping (FR-035).

## Shared schemas

```ts
type DeliveryChannel = 'push' | 'inbox' | 'popup' | 'banner';

type MediaItem = {
  type: 'image' | 'video';
  url: string;
  thumbnailUrl: string | null;
};

type Message = {
  id: string;
  title: string;
  body: string;
  publishedAt: string; // ISO 8601
  endDate: string | null; // ISO 8601, null = no expiry
  channels: DeliveryChannel[];
  media: MediaItem | null;
  acknowledgeLabel: string | null;
  isRead: boolean;
  isAcknowledged: boolean;
};

type MessagePage = {
  items: Message[];
  page: number;
  pageSize: number;
  totalCount: number;
  hasMore: boolean;
};
```

---

## 1. List inbox messages

```
GET /messages?tab={all|expired}&page={number}&pageSize={number}
```

|              |                                                                                 |
| ------------ | ------------------------------------------------------------------------------- |
| Query        | `tab` (required), `page` (required, 1-based), `pageSize` (required, default 20) |
| Payload      | `MessagePage`                                                                   |
| Requirements | FR-001, FR-001a, FR-002, FR-003, FR-003a, FR-008                                |

**Backend responsibilities**

- Return **only** messages whose `channels` include `push` or `inbox` (Clarification 1, FR-001a). The app applies no channel filtering.
- `tab=all` → messages not past `endDate`. `tab=expired` → messages past `endDate`.
- Order `items` by `publishedAt` descending. The app groups by month but does not re-sort.
- `hasMore` must be authoritative; the app stops paging when it is `false`.

**Errors**: `4xx`/`5xx` surface the global error toast and leave already-loaded pages intact (FR-003b).

---

## 2. Get message detail

```
GET /messages/:messageId
```

|              |                                        |
| ------------ | -------------------------------------- |
| Payload      | `Message`                              |
| Requirements | FR-009, FR-010, FR-011, FR-014, FR-022 |

Used when the app arrives from a notification tap, a popup or a banner and has no cached list entry. When the message is already in the inbox cache the app renders it immediately and refreshes in the background.

**Errors**: `404` renders a "message no longer available" state rather than an error toast.

---

## 3. Unread count

```
GET /messages/unread-count
```

|              |                           |
| ------------ | ------------------------- |
| Payload      | `{ unreadCount: number }` |
| Requirements | FR-006, FR-023            |

Counts unread inbox-visible messages only. Refetched on app foreground and invalidated after every read/acknowledge mutation.

---

## 4. Report read

```
PATCH /messages/:messageId/read
```

|              |                                                                   |
| ------------ | ----------------------------------------------------------------- |
| Request body | none                                                              |
| Payload      | `Message` (updated) — or `null` if the backend prefers a bare ack |
| Requirements | FR-015, FR-019, FR-019a                                           |

Idempotent. Called once, the first time the detail view opens for an unread message. The app does not optimistically flip `isRead`.

---

## 5. Report acknowledge

```
PATCH /messages/:messageId/acknowledge
```

|              |                                          |
| ------------ | ---------------------------------------- |
| Request body | none                                     |
| Payload      | `Message` (updated)                      |
| Requirements | FR-017, FR-017a, FR-018, FR-019, FR-019a |

**Backend responsibilities**

- Must set **both** `isAcknowledged` and `isRead` to `true` (FR-017a), covering the case where the Storekeeper acknowledges from a popup without opening the detail view.
- Must be irreversible — there is no un-acknowledge endpoint.

**Errors**: fail fast. The app shows the standard error toast and returns the button to its un-acknowledged state (Clarification 4). No retry, no offline queue.

---

## 6. Active popups

```
GET /messages/popups
```

|              |                |
| ------------ | -------------- |
| Payload      | `Message[]`    |
| Requirements | FR-025, FR-027 |

Returns currently active messages whose `channels` include `popup`, ordered by `publishedAt` descending (newest first) — the order in which the app presents them one at a time (FR-027). The app additionally filters out ids in its local `dismissedIds` set before presenting (FR-026).

---

## 7. Active banners

```
GET /messages/banners
```

|              |                        |
| ------------ | ---------------------- |
| Payload      | `Message[]`            |
| Requirements | FR-029, FR-030, FR-031 |

Returns currently active messages whose `channels` include `banner`. An empty array means the Home screen renders with no banner area (FR-031).

---

## 8. Register push device

```
POST /messages/devices
```

```json
{ "token": "<fcm-token>", "platform": "ios" }
```

|              |                      |
| ------------ | -------------------- |
| `platform`   | `'ios' \| 'android'` |
| Payload      | `null`               |
| Requirements | FR-020               |

Called after login once notification permission is granted, and again on every `onTokenRefresh`.

---

## 9. De-register push device

```
DELETE /messages/devices/:token
```

|              |        |
| ------------ | ------ |
| Payload      | `null` |
| Requirements | FR-020 |

Called on logout **before** auth state is cleared. The app then calls `deleteToken()` locally regardless of whether this request succeeded, so the device cannot keep receiving the previous Storekeeper's notifications.

---

## Open items for the backend team

1. Confirm the final paths and whether the inbox tabs are one endpoint with a `tab` query or two endpoints.
2. ✅ **RESOLVED (2026-08-04)** — media URLs are **public** and do not require the bearer token. `expo-image` and `expo-video` sources are plain URIs with no `headers` object. T022 is unblocked.
3. Confirm the page size the backend recommends for SC-003 (first screen < 2 s). The app sends `pageSize=20` until told otherwise.
4. Confirm whether read/acknowledge return the updated `Message` or an empty payload.
