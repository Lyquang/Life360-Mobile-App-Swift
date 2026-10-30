# Feature: R2 image and voice chat media

Status: Approved 2026-10-12
Owner: AI Agent

## Objective

Upload foreground JPEG and AAC voice notes through an authenticated media ticket,
an exact raw R2 PUT, then an acknowledged Socket.IO message. Render history and
realtime media with optimistic state, safe retry and URL-based reconciliation.

## Scope

In: central 10 MiB image / 25 MiB voice / 900 s / 300 s policies; JPEG 0.8
baseline; off-main BlurHash; foreground progress/cancel; recorder interruption and
temp cleanup; URLCache image loading; one AVPlayer; typed errors; ack uncertainty;
same-sender exact-public-URL dedupe; local environment override; tests/docs.

Out: backend changes, `clientMessageId`, background URLSession, durable voice cache,
guaranteed exactly-once delivery and real refresh rotation before its API exists.

## Architecture

```text
ChatView -> @MainActor ChatViewModel -> media/chat use cases
 -> repository protocols -> MediaUploadService / SocketClient / APIClient
```

Views do not access URLSession, Keychain or AVFoundation. Coordinator owns media
navigation and handles forbidden-conversation closure. Production remains default;
local endpoints require explicit `FAMILYTRACKER_USE_LOCAL_BACKEND=1` and use the
configured local host. Existing iOS 16 + Combine state conventions remain.

## Modeled state

Server ChatMessage supports text/image/voice. Presentation wraps it in a stable
row with sending(progress), sent, failed(message), or uncertain state. A media
draft retains final bytes/temp file and the issued public URL only as long as retry
or reconciliation needs it.

## Error and retry rules

- 400 validation/bad request: no unchanged retry.
- 401: single-flight refresh seam; production adapter currently reports unavailable,
  invalidates session and asks for login. Retry once only after a future real refresh.
- 403: disable composer and ask Coordinator to leave/refresh conversation.
- 503: retain draft, report temporary storage unavailability.
- Ticket expiry/R2 403/network: discard ticket and request one fresh ticket.
- Ack false: failed with server message. Ack timeout: uncertain, never auto-resend;
  fetch recent history and match sender + exact attachment/media URL first.

## Verification

Pure tests for mapping/limits/dates/models/dedupe; URLProtocol ticket/PUT/auth
retry; socket ack outcomes; audio state policy. Debug and Release simulator builds;
existing networking/localization/notification regressions. Manual device matrix is
recorded in `study/media-upload-integration.md`; no live mutation is required for
automated tests.
