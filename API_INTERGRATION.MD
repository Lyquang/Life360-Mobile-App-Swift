# Family Tracker Backend API & iOS Integration Guide

Tài liệu này dành cho iOS Swift Developer tích hợp app với Family Tracker Backend mà không cần đọc source backend.

## Table Of Contents

- [1. Overview & Setup](#1-overview--setup)
- [2. REST API Conventions](#2-rest-api-conventions)
- [3. Auth APIs](#3-auth-apis)
- [4. Groups / Circles APIs](#4-groups--circles-apis)
- [5. Places APIs](#5-places-apis)
- [6. Digest APIs](#6-digest-apis)
- [7. Chat & Conversations APIs](#7-chat--conversations-apis)
- [8. Location History & Journey APIs](#8-location-history--journey-apis)
- [9. Socket.io Realtime Contract](#9-socketio-realtime-contract)
- [10. Special Integration Flows](#10-special-integration-flows)
- [11. Swift Codable Models](#11-swift-codable-models)
- [12. Error Handling Checklist](#12-error-handling-checklist)

## 1. Overview & Setup

### Base URLs

| Environment | REST Base URL | Socket.io URL |
| --- | --- | --- |
| Local Dev | `http://localhost:3000/api/v1` | `http://localhost:3000` |
| Production | `https://life360-backend-latest.onrender.com/api/v1` | `https://life360-backend-latest.onrender.com` |

Health checks:

```http
GET /api/health
GET /api/v1/health
```

Swagger UI:

```txt
https://life360-backend-latest.onrender.com/api-docs
```

### Authentication

Protected REST APIs require:

```http
Authorization: Bearer <token>
```

Use `data.token` or `data.accessToken` from Login/Register/Social Login. Currently `token` and `accessToken` have the same value for backward compatibility.

Socket.io authentication sends the same JWT in the handshake:

```swift
["auth": ["token": accessToken]]
```

### Standard Response Format

Success:

```json
{
  "success": true,
  "message": "Optional message",
  "data": {}
}
```

List success often includes `count`:

```json
{
  "success": true,
  "count": 2,
  "data": []
}
```

Error:

```json
{
  "success": false,
  "code": "VALIDATION_ERROR",
  "message": "Validation failed.",
  "errors": [
    { "field": "body.email", "message": "Please provide a valid email." }
  ]
}
```

Common error codes:

| HTTP | `code` | Meaning |
| --- | --- | --- |
| 400 | `BAD_REQUEST` / `VALIDATION_ERROR` | Invalid body, params, query, malformed JSON |
| 401 | `UNAUTHORIZED` | Missing/invalid/expired token, invalid Google ID token |
| 403 | `FORBIDDEN` | User is authenticated but not allowed |
| 404 | `NOT_FOUND` | Resource not found |
| 409 | `CONFLICT` | Duplicate email |
| 429 | `RATE_LIMITED` | Too many auth attempts |
| 503 | `SERVICE_UNAVAILABLE` | Google OAuth or media storage not configured |

## 2. REST API Conventions

Headers for JSON requests:

```http
Content-Type: application/json
Accept: application/json
Authorization: Bearer <token>   // protected endpoints only
```

IDs are Mongo ObjectId strings:

```txt
24 hex chars, for example: 66f123456789abcdef012345
```

Coordinates:

- `latitude`: `-90...90`
- `longitude`: `-180...180`
- Backend stores GeoJSON internally as `[longitude, latitude]`, but API payloads use `latitude` and `longitude`.

Dates:

- Date-time values are ISO 8601 strings.
- Journey query date uses `YYYY-MM-DD`.
- Server timezone is configured as `Asia/Ho_Chi_Minh`.

## 3. Auth APIs

### Register

```http
POST /auth/register
Auth: No
```

Body:

| Field | Type | Required | Rules |
| --- | --- | --- | --- |
| `name` | String | Yes | Trimmed, 2...50 chars |
| `email` | String | Yes | Valid email, normalized lowercase |
| `password` | String | Yes | 6...128 chars |

Request:

```json
{
  "name": "Alice",
  "email": "alice@example.com",
  "password": "secret123"
}
```

Response `201`:

```json
{
  "success": true,
  "message": "User registered successfully.",
  "data": {
    "user": {
      "name": "Alice",
      "email": "alice@example.com",
      "avatar": "",
      "batteryLevel": 100,
      "isOnline": false,
      "lastSeenAt": null,
      "lastKnownLocation": {
        "type": "Point",
        "coordinates": null,
        "updatedAt": null,
        "durationMinutes": 0
      },
      "createdAt": "2026-10-01T08:00:00.000Z",
      "updatedAt": "2026-10-01T08:00:00.000Z",
      "id": "66f123456789abcdef012345"
    },
    "token": "<jwt>",
    "accessToken": "<jwt>",
    "refreshToken": "<refresh-jwt>"
  }
}
```

Common errors: `400`, `409`, `429`.

### Login

```http
POST /auth/login
Auth: No
```

Body:

| Field | Type | Required |
| --- | --- | --- |
| `email` | String | Yes |
| `password` | String | Yes |

Request:

```json
{
  "email": "alice@example.com",
  "password": "secret123"
}
```

Response `200`:

```json
{
  "success": true,
  "message": "Login successful.",
  "data": {
    "user": { "id": "66f123456789abcdef012345", "name": "Alice", "email": "alice@example.com", "isOnline": true },
    "token": "<jwt>",
    "accessToken": "<jwt>",
    "refreshToken": "<refresh-jwt>"
  }
}
```

Common errors: `400`, `401`, `429`.

### Social Login - Google

```http
POST /auth/social-login
Auth: No
```

iOS must use Google Sign-In and send the **Google ID token**, not an access token.

Body:

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `provider` | String | Yes | Currently use `"google"` |
| `token` | String | Yes | Google ID token from iOS client |

Request:

```json
{
  "provider": "google",
  "token": "<google-id-token>"
}
```

Response `200`:

```json
{
  "success": true,
  "message": "Social login successful.",
  "data": {
    "user": {
      "id": "66f123456789abcdef012345",
      "name": "QUANG LY",
      "email": "quang@example.com",
      "avatar": "https://lh3.googleusercontent.com/a/...",
      "isOnline": true
    },
    "token": "<jwt>",
    "accessToken": "<jwt>",
    "refreshToken": "<refresh-jwt>"
  }
}
```

Common errors:

- `400 VALIDATION_ERROR`: invalid provider/body.
- `401 UNAUTHORIZED`: invalid/expired Google ID token or `aud` mismatch.
- `503 SERVICE_UNAVAILABLE`: server missing `GOOGLE_CLIENT_ID`.

iOS Google Sign-In note:

- Backend verifies token audience against `GOOGLE_CLIENT_ID` configured on the server.
- The iOS app must request an ID token whose audience matches that backend Web OAuth Client ID.

### Get Me

```http
GET /auth/me
Auth: Yes
```

Response `200`:

```json
{
  "success": true,
  "data": {
    "id": "66f123456789abcdef012345",
    "name": "Alice",
    "email": "alice@example.com",
    "avatar": "",
    "batteryLevel": 100,
    "isOnline": true,
    "lastSeenAt": "2026-10-01T08:00:00.000Z"
  }
}
```

Common errors: `401`.

## 4. Groups / Circles APIs

### Create Circle

```http
POST /groups
Auth: Yes
```

Body:

| Field | Type | Required | Rules |
| --- | --- | --- | --- |
| `name` | String | Yes | 2...50 chars |

Request:

```json
{ "name": "Family" }
```

Response `201`:

```json
{
  "success": true,
  "message": "Group created successfully.",
  "data": {
    "name": "Family",
    "inviteCode": "123456",
    "members": ["66f123456789abcdef012345"],
    "admin": {
      "id": "66f123456789abcdef012345",
      "name": "Alice",
      "email": "alice@example.com"
    },
    "notificationIntervalMinutes": 60,
    "lastDigestSentAt": null,
    "createdAt": "2026-10-01T08:00:00.000Z",
    "updatedAt": "2026-10-01T08:00:00.000Z",
    "id": "66f222222222222222222222",
    "conversationId": "66f333333333333333333333"
  }
}
```

Common errors: `400`, `401`.

### List My Circles

```http
GET /groups
Auth: Yes
```

Response `200`:

```json
{
  "success": true,
  "count": 1,
  "data": [
    {
      "id": "66f222222222222222222222",
      "name": "Family",
      "inviteCode": "123456",
      "members": ["66f123456789abcdef012345"],
      "admin": "66f123456789abcdef012345",
      "notificationIntervalMinutes": 60,
      "lastDigestSentAt": null,
      "conversationId": "66f333333333333333333333"
    }
  ]
}
```

Common errors: `401`.

### Join Circle By Invite Code

```http
POST /groups/join
Auth: Yes
```

Body:

| Field | Type | Required | Rules |
| --- | --- | --- | --- |
| `inviteCode` | String | Yes | Exactly 6 digits |

Request:

```json
{ "inviteCode": "123456" }
```

Response `200`:

```json
{
  "success": true,
  "message": "Successfully joined the group.",
  "data": {
    "id": "66f222222222222222222222",
    "name": "Family",
    "inviteCode": "123456",
    "conversationId": "66f333333333333333333333",
    "members": [
      { "id": "66f123456789abcdef012345", "name": "Alice" },
      { "id": "66f444444444444444444444", "name": "Bob" }
    ]
  }
}
```

Common errors:

- `400`: invalid invite code format or already a member.
- `404`: invite code not found.
- `401`: unauthorized.

### Circle Members

```http
GET /groups/{groupId}/members
Auth: Yes
```

Path:

| Param | Type | Required |
| --- | --- | --- |
| `groupId` | ObjectId String | Yes |

Response `200`:

```json
{
  "success": true,
  "data": {
    "groupId": "66f222222222222222222222",
    "groupName": "Family",
    "inviteCode": "123456",
    "conversationId": "66f333333333333333333333",
    "memberCount": 2,
    "members": [
      {
        "id": "66f123456789abcdef012345",
        "name": "Alice",
        "email": "alice@example.com",
        "avatar": "",
        "batteryLevel": 80,
        "isOnline": true,
        "lastSeenAt": null,
        "lastKnownLocation": {
          "type": "Point",
          "coordinates": [106.7009, 10.7769],
          "updatedAt": "2026-10-01T08:05:00.000Z",
          "durationMinutes": 12
        }
      }
    ]
  }
}
```

Common errors: `400`, `401`, `403`, `404`.

### Update Digest Notification Interval

```http
PATCH /groups/{groupId}/notification-interval
Auth: Yes
```

Body:

| Field | Type | Required | Rules |
| --- | --- | --- | --- |
| `intervalMinutes` | Int | Yes | `0...1440`; `0` disables digest |

Request:

```json
{ "intervalMinutes": 60 }
```

Response `200`:

```json
{
  "success": true,
  "message": "Đã cài đặt gửi thông báo mỗi 60 phút.",
  "data": {
    "groupId": "66f222222222222222222222",
    "notificationIntervalMinutes": 60
  }
}
```

Common errors: `400`, `401`, `403`, `404`.

## 5. Places APIs

### Add Favorite Place

```http
POST /groups/{groupId}/places
Auth: Yes
```

Body:

| Field | Type | Required | Rules |
| --- | --- | --- | --- |
| `name` | String | Yes | 1...100 chars |
| `category` | String | Yes | `restaurant`, `entertainment`, `cafe`, `shopping`, `other` |
| `latitude` | Double | Yes | `-90...90` |
| `longitude` | Double | Yes | `-180...180` |

Request:

```json
{
  "name": "Pho 24",
  "category": "restaurant",
  "latitude": 10.7769,
  "longitude": 106.7009
}
```

Response `201`:

```json
{
  "success": true,
  "message": "Favorite place added successfully.",
  "data": {
    "id": "66f555555555555555555555",
    "groupId": "66f222222222222222222222",
    "name": "Pho 24",
    "category": "restaurant",
    "location": {
      "type": "Point",
      "coordinates": [106.7009, 10.7769]
    },
    "addedBy": {
      "id": "66f123456789abcdef012345",
      "name": "Alice"
    },
    "latitude": 10.7769,
    "longitude": 106.7009,
    "createdAt": "2026-10-01T08:00:00.000Z",
    "updatedAt": "2026-10-01T08:00:00.000Z"
  }
}
```

Common errors: `400`, `401`, `403`, `404`.

### List Favorite Places

```http
GET /groups/{groupId}/places
Auth: Yes
```

Response `200`:

```json
{
  "success": true,
  "count": 1,
  "data": [
    {
      "id": "66f555555555555555555555",
      "name": "Pho 24",
      "category": "restaurant",
      "latitude": 10.7769,
      "longitude": 106.7009,
      "addedBy": { "id": "66f123456789abcdef012345", "name": "Alice" }
    }
  ]
}
```

Common errors: `401`, `403`, `404`.

## 6. Digest APIs

### List Circle Digests

```http
GET /groups/{groupId}/digests?page=1&limit=20&from=2026-10-01T00:00:00.000Z&to=2026-10-02T00:00:00.000Z
Auth: Yes
```

Query:

| Field | Type | Required | Default | Rules |
| --- | --- | --- | --- | --- |
| `page` | Int | No | `1` | `>= 1` |
| `limit` | Int | No | `20` | `1...100` |
| `from` | ISO Date String | No | - | Optional lower bound |
| `to` | ISO Date String | No | - | Optional upper bound |

Response `200`:

```json
{
  "success": true,
  "data": [
    {
      "id": "66f666666666666666666666",
      "groupId": "66f222222222222222222222",
      "groupName": "Family",
      "intervalMinutes": 60,
      "members": [
        {
          "userId": "66f123456789abcdef012345",
          "name": "Alice",
          "isOnline": true,
          "lastSeenText": "Đang online",
          "batteryLevel": 80,
          "latitude": 10.7769,
          "longitude": 106.7009,
          "locationUpdatedAt": "2026-10-01T08:00:00.000Z",
          "durationMinutes": 12,
          "durationFormatted": "12 phút",
          "summary": "Alice ở đây 12 phút và đang online"
        }
      ],
      "sentAt": "2026-10-01T08:00:00.000Z"
    }
  ],
  "pagination": {
    "currentPage": 1,
    "totalPages": 1,
    "totalItems": 1,
    "itemsPerPage": 20,
    "hasNextPage": false,
    "hasPrevPage": false
  },
  "groupSettings": {
    "notificationIntervalMinutes": 60,
    "lastDigestSentAt": "2026-10-01T08:00:00.000Z"
  }
}
```

Common errors: `400`, `401`, `403`, `404`.

### Latest Circle Digest

```http
GET /groups/{groupId}/digests/latest
Auth: Yes
```

Response `200` with digest:

```json
{
  "success": true,
  "data": {
    "id": "66f666666666666666666666",
    "groupId": "66f222222222222222222222",
    "groupName": "Family",
    "intervalMinutes": 60,
    "members": [],
    "sentAt": "2026-10-01T08:00:00.000Z"
  },
  "groupSettings": {
    "notificationIntervalMinutes": 60,
    "lastDigestSentAt": "2026-10-01T08:00:00.000Z"
  }
}
```

Response `200` without digest:

```json
{
  "success": true,
  "data": null,
  "message": "Chưa có digest nào được gửi cho nhóm này.",
  "groupSettings": {
    "notificationIntervalMinutes": 60,
    "lastDigestSentAt": null
  }
}
```

Common errors: `401`, `403`, `404`.

## 7. Chat & Conversations APIs

### List Conversations

```http
GET /conversations
Auth: Yes
```

Response `200`:

```json
{
  "success": true,
  "count": 1,
  "data": [
    {
      "id": "66f333333333333333333333",
      "type": "group",
      "groupId": "66f222222222222222222222",
      "name": "Family",
      "avatarUrl": null,
      "members": [
        {
          "id": "66f123456789abcdef012345",
          "name": "Alice",
          "avatar": null,
          "isOnline": true,
          "lastSeenAt": null
        }
      ],
      "lastMessage": null,
      "lastMessageAt": null,
      "unreadCount": 0,
      "lastReadMessageId": null,
      "createdAt": "2026-10-01T08:00:00.000Z",
      "updatedAt": "2026-10-01T08:00:00.000Z"
    }
  ]
}
```

Direct conversation display:

- `type = "direct"`
- `name` and `avatarUrl` are derived from the other user.

Common errors: `401`.

### Get Conversation Detail

```http
GET /conversations/{conversationId}
Auth: Yes
```

Response `200`:

```json
{
  "success": true,
  "data": {
    "id": "66f333333333333333333333",
    "type": "group",
    "groupId": "66f222222222222222222222",
    "name": "Family",
    "avatarUrl": null,
    "members": [],
    "lastMessage": null,
    "lastMessageAt": null,
    "unreadCount": 0,
    "lastReadMessageId": null,
    "createdAt": "2026-10-01T08:00:00.000Z",
    "updatedAt": "2026-10-01T08:00:00.000Z"
  }
}
```

Common errors: `400`, `401`, `403`, `404`.

### Open Direct 1-1 Conversation

```http
POST /conversations/direct
Auth: Yes
```

Body:

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `userId` | ObjectId String | Yes | Other member must share at least one circle with current user |

Request:

```json
{ "userId": "66f444444444444444444444" }
```

Response `200`:

```json
{
  "success": true,
  "data": {
    "id": "66f777777777777777777777",
    "type": "direct",
    "groupId": null,
    "name": "Bob",
    "avatarUrl": null,
    "members": [],
    "unreadCount": 0
  }
}
```

Common errors:

- `400`: invalid `userId` or opening chat with yourself.
- `403`: no shared circle.
- `401`: unauthorized.

### Update Group Conversation Metadata

```http
PATCH /conversations/{conversationId}
Auth: Yes
```

Only group conversations are editable.

Body:

| Field | Type | Required | Rules |
| --- | --- | --- | --- |
| `name` | String | No | 1...100 chars |
| `avatarUrl` | HTTPS URL or `null` | No | `null` clears avatar |

At least one of `name` or `avatarUrl` is required.

Request:

```json
{
  "name": "Family Chat",
  "avatarUrl": "https://cdn.example.com/family.png"
}
```

Response `200`:

```json
{
  "success": true,
  "message": "Conversation updated.",
  "data": {
    "id": "66f333333333333333333333",
    "type": "group",
    "name": "Family Chat",
    "avatarUrl": "https://cdn.example.com/family.png"
  }
}
```

Realtime side effect:

```txt
chat:conversation_updated
```

Common errors: `400`, `401`, `403`, `404`.

### List Messages

```http
GET /conversations/{conversationId}/messages?limit=30&before=<messageId>
Auth: Yes
```

Query:

| Field | Type | Required | Default | Rules |
| --- | --- | --- | --- | --- |
| `limit` | Int | No | `30` | `1...100` |
| `before` | ObjectId String | No | - | Cursor for older page |

Pagination behavior:

- Response `data` is ordered oldest to newest.
- First page: omit `before`.
- If `hasMore == true`, call again with `before = nextBefore`.

Response `200`:

```json
{
  "success": true,
  "count": 2,
  "hasMore": true,
  "nextBefore": "66f888888888888888888888",
  "data": [
    {
      "id": "66f888888888888888888888",
      "conversationId": "66f333333333333333333333",
      "senderId": "66f123456789abcdef012345",
      "senderName": "Alice",
      "type": "text",
      "content": "Hello!",
      "attachment": null,
      "createdAt": "2026-10-01T08:10:00.000Z"
    }
  ]
}
```

Common errors: `400`, `401`, `403`.

### Send Message Via REST

```http
POST /conversations/{conversationId}/messages
Auth: Yes
```

Text body:

```json
{
  "type": "text",
  "content": "Hello!"
}
```

Image body:

```json
{
  "type": "image",
  "attachmentUrl": "https://cdn.example.com/chat/...",
  "content": "Optional caption",
  "metadata": {
    "width": 1200,
    "height": 900,
    "blurhash": "LEHV6nWB2yk8pyo0adR*.7kCMdnj",
    "mimeType": "image/jpeg",
    "size": 204800
  }
}
```

Image messages should normally be sent after creating an upload ticket and uploading the image bytes.

Response `201`:

```json
{
  "success": true,
  "data": {
    "id": "66f888888888888888888888",
    "conversationId": "66f333333333333333333333",
    "senderId": "66f123456789abcdef012345",
    "senderName": "Alice",
    "type": "text",
    "content": "Hello!",
    "attachment": null,
    "createdAt": "2026-10-01T08:10:00.000Z"
  }
}
```

Realtime side effect:

```txt
chat:new_message
```

Common errors: `400`, `401`, `403`, `503` for image if media storage is not configured.

### Mark Conversation As Read

```http
POST /conversations/{conversationId}/read
Auth: Yes
```

Body:

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `messageId` | ObjectId String | No | Omit to mark latest message as read |

Request:

```json
{ "messageId": "66f888888888888888888888" }
```

Response `200`:

```json
{
  "success": true,
  "data": {
    "conversationId": "66f333333333333333333333",
    "lastReadMessageId": "66f888888888888888888888",
    "unreadCount": 0,
    "advanced": true
  }
}
```

Realtime side effect if pointer advanced:

```txt
chat:read_receipt
```

Common errors: `400`, `401`, `403`, `404`.

### Get Conversation Unread Count

```http
GET /conversations/{conversationId}/unread
Auth: Yes
```

Response `200`:

```json
{
  "success": true,
  "data": {
    "conversationId": "66f333333333333333333333",
    "unreadCount": 3,
    "lastReadMessageId": "66f888888888888888888888"
  }
}
```

Common errors: `400`, `401`, `403`.

### Unread Summary

```http
GET /conversations/unread-summary
Auth: Yes
```

Response `200`:

```json
{
  "success": true,
  "data": {
    "totalUnread": 5,
    "conversations": [
      {
        "conversationId": "66f333333333333333333333",
        "unreadCount": 3,
        "lastReadMessageId": "66f888888888888888888888"
      }
    ]
  }
}
```

Common errors: `401`.

### Create Upload Ticket For Chat Image

```http
POST /chat/upload-ticket
Auth: Yes
```

Body:

| Field | Type | Required | Rules |
| --- | --- | --- | --- |
| `conversationId` | ObjectId String | Yes | User must be conversation member |
| `contentType` | String | Yes | `image/jpeg`, `image/png`, `image/webp`, `image/heic`, `image/heif`, `image/gif` |
| `contentLength` | Int | Yes | Bytes, max configured by server |

Request:

```json
{
  "conversationId": "66f333333333333333333333",
  "contentType": "image/jpeg",
  "contentLength": 204800
}
```

Response `201`:

```json
{
  "success": true,
  "data": {
    "uploadUrl": "https://storage.example.com/presigned-put-url",
    "method": "PUT",
    "headers": {
      "Content-Type": "image/jpeg",
      "Content-Length": "204800"
    },
    "key": "chat/66f333333333333333333333/66f123456789abcdef012345/uuid.jpg",
    "fileUrl": "https://cdn.example.com/chat/66f333333333333333333333/66f123456789abcdef012345/uuid.jpg",
    "expiresIn": 300,
    "expiresAt": "2026-10-01T08:15:00.000Z"
  }
}
```

Common errors: `400`, `401`, `403`, `503`.

## 8. Location History & Journey APIs

### Today Location Points

```http
GET /history/{userId}
Auth: Yes
```

Access rule:

- User can view self.
- User can view another member only if they share at least one circle.

Response `200`:

```json
{
  "success": true,
  "count": 2,
  "date": "2026-10-01",
  "data": [
    {
      "id": "66f999999999999999999999",
      "latitude": 10.7769,
      "longitude": 106.7009,
      "timestamp": "2026-10-01T08:00:00.000Z"
    }
  ]
}
```

Common errors: `400`, `401`, `403`.

### Day Journey

```http
GET /history/{userId}/journey?date=2026-10-01
Auth: Yes
```

Query:

| Field | Type | Required | Default |
| --- | --- | --- | --- |
| `date` | String | No | Today |

Response `200`:

```json
{
  "success": true,
  "date": "2026-10-01",
  "userId": "66f123456789abcdef012345",
  "summary": {
    "totalPoints": 24,
    "stayPointCount": 2,
    "movingSegmentCount": 3
  },
  "journey": [
    {
      "type": "stay",
      "startTime": "2026-10-01T08:00:00.000Z",
      "endTime": "2026-10-01T08:30:00.000Z",
      "durationMinutes": 30,
      "latitude": 10.7769,
      "longitude": 106.7009,
      "points": []
    },
    {
      "type": "moving",
      "startTime": "2026-10-01T08:30:00.000Z",
      "endTime": "2026-10-01T09:00:00.000Z",
      "points": [
        { "latitude": 10.7769, "longitude": 106.7009, "timestamp": "2026-10-01T08:31:00.000Z" }
      ]
    }
  ]
}
```

Journey algorithm:

- Stay point: points within ~80m for at least 5 minutes.
- Moving segment: points between stay points.

Common errors: `400`, `401`, `403`.

## 9. Socket.io Realtime Contract

### Connection Flow

Install iOS Socket.io client, for example `Socket.IO-Client-Swift`.

Connect to Socket Gateway URL, not `/api/v1`:

```swift
let manager = SocketManager(
    socketURL: URL(string: "https://life360-backend-latest.onrender.com")!,
    config: [
        .log(false),
        .compress,
        .forceWebsockets(true),
        .connectParams([:]),
        .extraHeaders([:]),
        .reconnects(true)
    ]
)

let socket = manager.defaultSocket
socket.auth = ["token": accessToken]
socket.connect()
```

Wait for:

```txt
session:ready
```

Do not assume all rooms are joined before this event.

`session:ready` payload:

```json
{
  "groupIds": ["66f222222222222222222222"],
  "conversationIds": ["66f333333333333333333333"]
}
```

### Client To Server Events

#### `update_location`

Payload:

```json
{
  "latitude": 10.7769,
  "longitude": 106.7009,
  "batteryLevel": 80
}
```

Rules:

- `latitude`: `-90...90`
- `longitude`: `-180...180`
- `batteryLevel` optional, clamped by backend to `0...100`

Behavior:

- Updates last known location.
- Saves history only if moved at least 50m or at least 30s since previous saved point.
- Broadcasts `location_update` to circle members.
- May broadcast `location_stay_alert`.

Invalid payload response:

```txt
error
```

#### `sos_alert`

Payload:

```json
{
  "message": "Help me!",
  "latitude": 10.7769,
  "longitude": 106.7009,
  "batteryLevel": 70
}
```

All fields are optional except coordinates must be valid if present. Backend broadcasts `sos_alert` to all circles and sends `sos_confirmed` to the sender.

#### `chat:send_message`

Text payload:

```json
{
  "conversationId": "66f333333333333333333333",
  "type": "text",
  "content": "Hello!"
}
```

Image payload:

```json
{
  "conversationId": "66f333333333333333333333",
  "type": "image",
  "attachmentUrl": "https://cdn.example.com/chat/...",
  "content": "Optional caption",
  "metadata": {
    "width": 1200,
    "height": 900,
    "blurhash": "LEHV6nWB2yk8pyo0adR*.7kCMdnj",
    "mimeType": "image/jpeg",
    "size": 204800
  }
}
```

Ack success:

```json
{
  "success": true,
  "data": {
    "id": "66f888888888888888888888",
    "conversationId": "66f333333333333333333333",
    "senderId": "66f123456789abcdef012345",
    "senderName": "Alice",
    "type": "text",
    "content": "Hello!",
    "attachment": null,
    "createdAt": "2026-10-01T08:10:00.000Z"
  }
}
```

Ack error:

```json
{
  "success": false,
  "status": 403,
  "code": "FORBIDDEN",
  "message": "You are not a member of this conversation."
}
```

Rate limit:

- `20` messages per `10` seconds per socket connection.

#### `chat:mark_read`

Payload:

```json
{
  "conversationId": "66f333333333333333333333",
  "messageId": "66f888888888888888888888"
}
```

Omit `messageId` to mark the latest message as read.

Ack:

```json
{
  "success": true,
  "data": {
    "conversationId": "66f333333333333333333333",
    "lastReadMessageId": "66f888888888888888888888",
    "unreadCount": 0,
    "advanced": true
  }
}
```

#### `chat:typing`

Payload:

```json
{
  "conversationId": "66f333333333333333333333",
  "isTyping": true
}
```

No ack. Broadcasts to other conversation members.

### Server To Client Events

#### `location_update`

```json
{
  "userId": "66f123456789abcdef012345",
  "name": "Alice",
  "latitude": 10.7769,
  "longitude": 106.7009,
  "batteryLevel": 80,
  "timestamp": "2026-10-01T08:00:00.000Z",
  "durationAtLocation": 12,
  "durationSince": "2026-10-01T07:48:00.000Z",
  "durationFormatted": "12 phút"
}
```

#### `location_stay_alert`

```json
{
  "type": "STAY_ALERT",
  "userId": "66f123456789abcdef012345",
  "name": "Alice",
  "latitude": 10.7769,
  "longitude": 106.7009,
  "durationMinutes": 30,
  "durationFormatted": "30 phút",
  "durationSince": "2026-10-01T07:30:00.000Z",
  "groupId": "66f222222222222222222222",
  "groupName": "Family",
  "message": "Alice đang ở một nơi được 30 phút rồi!",
  "timestamp": "2026-10-01T08:00:00.000Z"
}
```

#### `sos_alert`

```json
{
  "type": "SOS",
  "userId": "66f123456789abcdef012345",
  "name": "Alice",
  "message": "Help me!",
  "latitude": 10.7769,
  "longitude": 106.7009,
  "batteryLevel": 70,
  "groupId": "66f222222222222222222222",
  "groupName": "Family",
  "timestamp": "2026-10-01T08:00:00.000Z"
}
```

#### `sos_confirmed`

```json
{
  "message": "SOS alert sent to your groups.",
  "groupCount": 2
}
```

#### `member_online`

```json
{
  "userId": "66f123456789abcdef012345",
  "name": "Alice",
  "isOnline": true,
  "timestamp": "2026-10-01T08:00:00.000Z"
}
```

#### `member_offline`

```json
{
  "userId": "66f123456789abcdef012345",
  "name": "Alice",
  "isOnline": false,
  "lastSeenAt": "2026-10-01T08:00:00.000Z",
  "timestamp": "2026-10-01T08:00:00.000Z"
}
```

#### `group_digest`

```json
{
  "type": "GROUP_DIGEST",
  "groupId": "66f222222222222222222222",
  "groupName": "Family",
  "intervalMinutes": 60,
  "members": [],
  "timestamp": "2026-10-01T08:00:00.000Z"
}
```

#### `chat:new_message`

```json
{
  "id": "66f888888888888888888888",
  "conversationId": "66f333333333333333333333",
  "senderId": "66f123456789abcdef012345",
  "senderName": "Alice",
  "type": "text",
  "content": "Hello!",
  "attachment": null,
  "createdAt": "2026-10-01T08:10:00.000Z"
}
```

#### `chat:read_receipt`

```json
{
  "conversationId": "66f333333333333333333333",
  "userId": "66f123456789abcdef012345",
  "lastReadMessageId": "66f888888888888888888888",
  "readAt": "2026-10-01T08:11:00.000Z"
}
```

#### `chat:typing`

```json
{
  "conversationId": "66f333333333333333333333",
  "userId": "66f123456789abcdef012345",
  "name": "Alice",
  "isTyping": true
}
```

#### `chat:conversation_updated`

```json
{
  "conversationId": "66f333333333333333333333",
  "name": "Family Chat",
  "avatarUrl": "https://cdn.example.com/family.png",
  "updatedBy": "66f123456789abcdef012345",
  "updatedAt": "2026-10-01T08:12:00.000Z"
}
```

#### `chat:error`

Only emitted when client did not provide an ack callback:

```json
{
  "event": "chat:send_message",
  "success": false,
  "status": 403,
  "code": "FORBIDDEN",
  "message": "You are not a member of this conversation."
}
```

#### `error`

For invalid location/SOS payloads:

```json
{
  "message": "Invalid location payload.",
  "errors": []
}
```

## 10. Special Integration Flows

### Chat Image Upload Flow

Step 1: Request upload ticket.

```http
POST /chat/upload-ticket
Authorization: Bearer <token>
Content-Type: application/json
```

```json
{
  "conversationId": "66f333333333333333333333",
  "contentType": "image/jpeg",
  "contentLength": 204800
}
```

Step 2: Upload bytes directly to object storage.

Use `data.uploadUrl`, method `PUT`, and exactly the returned `data.headers`.

Swift sketch:

```swift
var request = URLRequest(url: URL(string: ticket.uploadUrl)!)
request.httpMethod = "PUT"
for (key, value) in ticket.headers {
    request.setValue(value, forHTTPHeaderField: key)
}
request.httpBody = imageData

let (_, response) = try await URLSession.shared.data(for: request)
guard (response as? HTTPURLResponse)?.statusCode.map({ 200..<300 ~= $0 }) == true else {
    throw UploadError.failed
}
```

Step 3: Send chat message.

```json
{
  "conversationId": "66f333333333333333333333",
  "type": "image",
  "attachmentUrl": "<ticket.fileUrl>",
  "content": "Optional caption",
  "metadata": {
    "width": 1200,
    "height": 900,
    "blurhash": "LEHV6nWB2yk8pyo0adR*.7kCMdnj",
    "mimeType": "image/jpeg",
    "size": 204800
  }
}
```

Important:

- `attachmentUrl` must be the `fileUrl` returned by upload ticket.
- Backend rejects URLs not issued to the same user and conversation.
- `blurhash`, `width`, and `height` are required for image message metadata.

### Background Location Update Flow

Recommended iOS behavior:

1. Request background location permission from iOS.
2. Connect Socket.io with JWT.
3. Wait for `session:ready`.
4. Send `update_location` only when:
   - moved `>= 50m`, or
   - `>= 30s` since last sent update.
5. Include battery level if available.

Payload:

```json
{
  "latitude": 10.7769,
  "longitude": 106.7009,
  "batteryLevel": 80
}
```

Backend also applies the same throttle for persisted history:

- Save to DB if moved `>= 50m`, or
- `>= 30s` since previous saved point.

UI suggestion:

- Use realtime `location_update` for live map marker movement.
- Use REST `/history/{userId}` and `/history/{userId}/journey` for historical screens.

### Google Login Flow On iOS

1. Configure Google Sign-In in iOS app.
2. Request an ID token for the backend Web Client ID.
3. Call:

```http
POST /auth/social-login
```

```json
{
  "provider": "google",
  "token": "<google-id-token>"
}
```

4. Store `data.token` / `data.accessToken` in Keychain.
5. Use token for REST `Authorization` and Socket.io auth.

## 11. Swift Codable Models

These models are intentionally tolerant. Many fields are optional because endpoints return different populated forms.

```swift
import Foundation

struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let message: String?
    let data: T?
    let count: Int?
    let code: String?
    let errors: [APIFieldError]?
}

struct APIFieldError: Codable {
    let field: String?
    let message: String
}

struct AuthPayload: Codable {
    let user: User
    let token: String
    let accessToken: String?
    let refreshToken: String?
}

struct User: Codable, Identifiable {
    let id: String
    let name: String
    let email: String?
    let avatar: String?
    let batteryLevel: Int?
    let isOnline: Bool?
    let lastSeenAt: Date?
    let lastKnownLocation: LastKnownLocation?
    let createdAt: Date?
    let updatedAt: Date?
}

struct LastKnownLocation: Codable {
    let type: String?
    let coordinates: [Double]?
    let updatedAt: Date?
    let durationMinutes: Int?

    var longitude: Double? { coordinates?.first }
    var latitude: Double? { coordinates?.dropFirst().first }
}

struct Group: Codable, Identifiable {
    let id: String
    let name: String
    let inviteCode: String?
    let members: [String]?
    let admin: UserOrId?
    let notificationIntervalMinutes: Int?
    let lastDigestSentAt: Date?
    let conversationId: String?
    let createdAt: Date?
    let updatedAt: Date?
}

enum UserOrId: Codable {
    case id(String)
    case user(User)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let user = try? container.decode(User.self) {
            self = .user(user)
        } else {
            self = .id(try container.decode(String.self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .id(let id): try container.encode(id)
        case .user(let user): try container.encode(user)
        }
    }
}

struct GroupMemberList: Codable {
    let groupId: String
    let groupName: String
    let inviteCode: String
    let conversationId: String?
    let memberCount: Int
    let members: [GroupMember]
}

struct GroupMember: Codable, Identifiable {
    let id: String
    let name: String
    let email: String?
    let avatar: String?
    let batteryLevel: Int?
    let isOnline: Bool?
    let lastSeenAt: Date?
    let lastKnownLocation: LastKnownLocation?
}

struct Place: Codable, Identifiable {
    let id: String
    let groupId: String?
    let name: String
    let category: String
    let latitude: Double?
    let longitude: Double?
    let addedBy: User?
    let createdAt: Date?
    let updatedAt: Date?
}

struct Conversation: Codable, Identifiable {
    let id: String
    let type: ConversationType
    let groupId: String?
    let name: String?
    let avatarUrl: String?
    let members: [ConversationMember]
    let lastMessage: ChatMessage?
    let lastMessageAt: Date?
    let unreadCount: Int
    let lastReadMessageId: String?
    let createdAt: Date?
    let updatedAt: Date?
}

enum ConversationType: String, Codable {
    case group
    case direct
}

struct ConversationMember: Codable, Identifiable {
    let id: String
    let name: String
    let avatar: String?
    let isOnline: Bool
    let lastSeenAt: Date?
}

struct ChatMessage: Codable, Identifiable {
    let id: String
    let conversationId: String
    let senderId: String
    let senderName: String?
    let type: ChatMessageType
    let content: String
    let attachment: ChatAttachment?
    let createdAt: Date
}

enum ChatMessageType: String, Codable {
    case text
    case image
}

struct ChatAttachment: Codable {
    let url: String
    let mimeType: String?
    let size: Int?
    let width: Int
    let height: Int
    let blurhash: String
}

struct MessagePage: Codable {
    let success: Bool
    let count: Int
    let hasMore: Bool
    let nextBefore: String?
    let data: [ChatMessage]
}

struct UploadTicket: Codable {
    let uploadUrl: String
    let method: String
    let headers: [String: String]
    let key: String
    let fileUrl: String
    let expiresIn: Int
    let expiresAt: Date
}

struct MarkReadResult: Codable {
    let conversationId: String
    let lastReadMessageId: String?
    let unreadCount: Int
    let advanced: Bool
}

struct UnreadSummary: Codable {
    let totalUnread: Int
    let conversations: [ConversationUnread]
}

struct ConversationUnread: Codable {
    let conversationId: String
    let unreadCount: Int
    let lastReadMessageId: String?
}

struct LocationPoint: Codable, Identifiable {
    let id: String?
    let latitude: Double
    let longitude: Double
    let timestamp: Date
}

struct HistoryResponse: Codable {
    let success: Bool
    let count: Int
    let date: String
    let data: [LocationPoint]
}

struct JourneyResponse: Codable {
    let success: Bool
    let date: String
    let userId: String
    let summary: JourneySummary
    let journey: [JourneyItem]
}

struct JourneySummary: Codable {
    let totalPoints: Int
    let stayPointCount: Int?
    let movingSegmentCount: Int?
}

struct JourneyItem: Codable {
    let type: String
    let startTime: Date?
    let endTime: Date?
    let durationMinutes: Int?
    let latitude: Double?
    let longitude: Double?
    let points: [LocationPoint]?
}

struct Digest: Codable, Identifiable {
    let id: String
    let groupId: String
    let groupName: String
    let intervalMinutes: Int
    let members: [DigestMember]
    let sentAt: Date
}

struct DigestMember: Codable {
    let userId: String
    let name: String
    let isOnline: Bool
    let lastSeenText: String
    let batteryLevel: Int?
    let latitude: Double?
    let longitude: Double?
    let locationUpdatedAt: Date?
    let durationMinutes: Int
    let durationFormatted: String?
    let summary: String?
}

struct Pagination: Codable {
    let currentPage: Int
    let totalPages: Int
    let totalItems: Int
    let itemsPerPage: Int
    let hasNextPage: Bool
    let hasPrevPage: Bool
}

struct GroupSettings: Codable {
    let notificationIntervalMinutes: Int
    let lastDigestSentAt: Date?
}
```

Recommended `JSONDecoder`:

```swift
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601
```

If ISO 8601 parsing fails for fractional seconds in older iOS targets, use a custom `ISO8601DateFormatter` with `.withInternetDateTime` and `.withFractionalSeconds`.

## 12. Error Handling Checklist

For every REST call:

1. Decode success response when status is `200...299`.
2. Decode error response when status is outside `200...299`.
3. If `code == "UNAUTHORIZED"`, clear token and return user to login.
4. If `code == "VALIDATION_ERROR"`, show field-level messages from `errors`.
5. If `status == 403`, show permission/access denied.
6. If `status == 503`, show feature unavailable:
   - Google OAuth not configured, or
   - Media storage not configured.

For Socket.io:

1. Connect only after token exists.
2. Wait for `session:ready`.
3. Use ack callbacks for `chat:send_message` and `chat:mark_read`.
4. Listen to `connect_error` and retry/login when auth fails.
5. On app foreground, refresh REST state with:
   - `GET /groups`
   - `GET /conversations`
   - `GET /conversations/unread-summary`

