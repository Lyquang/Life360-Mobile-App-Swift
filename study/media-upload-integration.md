# Media Upload Integration Study

Status: Plan-first research only
Date: 2026-10-12
Source of truth: `api-docs/CLOUDFLARE_R2_MEDIA_UPLOAD_API_DOC.md`

## 1. Scope and invariants

This study covers foreground image and voice-note uploads for FamilyTracker chat.
The required order is immutable:

```text
prepare media
  -> POST /chat/media/presigned-url with app Bearer token
  -> PUT exact bytes to the unmodified uploadUrl with signed headers and no Bearer
  -> emit chat:send_message with publicUrl and wait for Socket.IO ack
```

Step 3 must never run before a 2xx PUT. Image messages use `attachmentUrl`;
voice messages use `mediaUrl`. No `clientMessageId` is sent because the backend
does not accept it. Background upload, backend changes and new dependencies are
out of scope.

Central client limits will be 10 MiB for JPEG, 25 MiB for voice, 900 seconds for
voice duration, 2,000 characters for caption, BlurHash length 6...100, image
dimensions 1...20,000 and a nominal ticket lifetime of 300 seconds. The ticket's
actual `expiresAt` remains authoritative.

## 2. What already exists

### Networking and authentication

- `URLSessionAPIClient` builds versioned REST requests, injects a Keychain-backed
  Bearer token for authenticated endpoints, maps structured API errors, supports
  cancellation and avoids logging request bodies containing credentials.
- `KeychainSessionRepository` stores one access token and cached user fields with
  `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
- Auth responses decode `refreshToken`, but `AuthSession` discards it and Keychain
  does not persist it. There is no refresh endpoint/client or single-flight refresh.
  On authenticated 401, `APIClient` currently invalidates the access token immediately.
- `AppEnvironment` has one production REST/Socket pair. No local/dev environment
  selector is implemented.

### Image preparation and upload

- `PhotosPicker` loads raw `Data` and calls `ChatViewModel.sendPhoto`.
- `ImageProcessor` decodes UIImage, downsizes the longest edge to 1,600 pixels,
  encodes JPEG at quality 0.8, calculates final pixel dimensions and calls the
  existing `BlurHashEncoder` on a 32x32 sample.
- The default 4x3 BlurHash has 28 characters; the fallback has 28 characters, so
  both satisfy the documented 6...100 character length. The encoder performs a
  bounded amount of work, but the current synchronous call is reached from a
  `@MainActor` ViewModel and can block UI.
- `ImageUploader` already performs a raw URLSession PUT using the ticket method and
  headers, accepts any 2xx response and adds no Bearer token. Task cancellation can
  abort the async upload, but there is no progress stream or typed expiry/signature
  classification.

### Chat transport and presentation

- History is cursor-paginated through
  `GET /conversations/{id}/messages?limit=30&before=<messageId>`.
- Realtime `chat:new_message` and typing events are converted through Codable DTOs.
- Text and image messages are currently persisted by REST. `SocketClient` exposes
  fire-and-forget `emit` only; no ack API exists.
- The UI renders text and image bubbles. Images use `AsyncImage` with a spinner,
  without a BlurHash decoder, explicit URLCache policy, aspect-ratio sizing from
  metadata, fullscreen routing, progress, cancellation or retry.
- Message equality/deduplication uses server `id` only. There is no optimistic
  message model or delivery state.
- `ChatMessageType` supports only text/image. Voice fields and playback are absent.
- No `AudioRecorderService`, microphone permission description, recorder UI,
  AVAudioSession interruption handling or AVPlayer controller exists.

### Dates and logging

- Chat DTO timestamps are strings and map through `ISO8601.date`, which already
  accepts fractional and plain ISO-8601. Decoding failures silently fall back to
  `Date()`, which can hide malformed server data.
- `UploadTicketDTO.expiresAt` is a String. The new contract requires a Date and the
  new response key `publicUrl`.
- Pulse's HTTP path applies `DiagnosticRedactor`, which strips query values including
  R2 signatures and suppresses binary bodies. The legacy ticket response and signed
  path can still leak through less-specific debug logging if reused carelessly.

## 3. Contract-to-code gap analysis

| Contract | Current implementation | Gap / required action |
| --- | --- | --- |
| `POST /chat/media/presigned-url` | `/chat/upload-ticket` | Replace media flow with new endpoint; do not keep legacy path in active code |
| Request keys `conversationId`, `mediaType`, `extension`, `mimeType`, `fileSize` | `conversationId`, `contentType`, `contentLength` | Add exact Codable request; map Swift `fileExtension` to JSON `extension` |
| Ticket key `publicUrl` | DTO expects `fileUrl` | Add new ticket DTO with URL fields and `expiresAt: Date` |
| Exact method/headers/bytes, no Bearer on PUT | Raw PUT already mostly correct | Validate expiry and Content-Length, preserve URL, add progress/cancel and typed errors |
| Image always JPEG/jpg | Existing JPEG 0.8 but ticket is legacy | Keep processor; centralize MIME/extension; use final `data.count` |
| Image max 10 MiB | No client size guard | Progressive quality/dimension reduction, then fail before ticket if still too large |
| BlurHash 6...100, off main thread | Encoder exists and output is valid length | Execute image processing/BlurHash away from MainActor; validate output before request |
| Caption <= 2,000 | UI sends nil caption; no check | Allow current draft as optional caption or explicit caption state; validate before upload |
| Socket image payload + ack | Image is sent through REST | Add async Socket.IO ack transport and typed ack decoding |
| Voice AAC `.m4a`, `audio/mp4` | Entire flow absent | Add recorder, temp-file lifecycle, policy validation, ticket/PUT/socket path |
| Voice <=25 MiB and `0 < duration <= 900` | Absent | Auto-stop at 900 s and validate duration/file bytes before ticket |
| Voice `attachment: null`, top-level media fields | DTO/domain omit fields | Extend DTO, mapper and entity without confusing `attachmentUrl` and `mediaUrl` |
| History and realtime share model | Both use same DTO today | Extend one DTO and one strict backend date decoder for both paths |
| Fractional ISO-8601 | Mapper can parse, but DTO stores String and falls back to now | Decode Date explicitly and surface malformed timestamps as decoding errors |
| BlurHash placeholder and URLCache | Spinner + AsyncImage only | Add local BlurHash decoder/image loader with explicit URLCache and aspect ratio |
| AVPlayer, one voice at a time | Absent | Add one playback controller per chat screen, progress observer and session cleanup |
| Optimistic `sending/sent/failed/uncertain` | Only confirmed server messages shown | Add presentation row state separate from persisted domain message |
| Same-user realtime dedupe by public URL | Dedupe by message ID only | Reconcile image `attachment.url` or voice `mediaUrl` before appending |
| Ack timeout reconciliation | Absent | Fetch newest history and match sender + exact public URL before manual resend |
| 400/401/403/503 distinctions | Repository conversion loses status/code | Preserve a media-specific typed error before the generic DomainError boundary |
| 401 refresh/retry once | Access token invalidated; refresh token discarded | Introduce single-flight refresh seam; temporary production behavior is re-login |
| R2 403/signature/network retry | Generic image upload failure | Always request a fresh ticket and repeat PUT; never reuse signed URL |
| Upload progress/cancel | Absent | Add foreground URLSession task delegate/AsyncStream and cancel from ViewModel |
| Secret URL logging | Query is redacted in Pulse | Use redacted logger path only; never log token/full upload/public URL in Release |
| Environment-aware endpoints | Production only | Requires explicit decision before changing previous deployed-only behavior |

## 4. Proposed architecture

```text
ChatView
  -> @MainActor ChatViewModel (row state, intents, cancellation)
  -> SendImageMessageUseCase / SendVoiceMessageUseCase
  -> ChatRepository + MediaRepository protocols
  -> MediaUploadService (ticket + exact foreground PUT)
  -> APIClient / URLSession

SocketClient.emitWithAck
  -> ChatRepositoryImpl typed ack
  -> confirmed ChatMessage
  -> ViewModel replaces/reconciles optimistic row
```

The View never sees APIClient, URLSession, Keychain, AVAudioRecorder or AVPlayer.
Navigation for future fullscreen image viewing remains in ChatCoordinator.

### Domain and Data model

- Extend `ChatMessageType` with `voice`; extend `ChatAttachment` with `size` and
  `blurhash`; add `mediaUrl`, `duration`, `fileSize`, and top-level `mimeType` to
  `ChatMessage`.
- Keep server messages immutable. Add a presentation `ChatMessageRowModel` with a
  stable local UUID and `DeliveryState` (`sending(progress)`, `sent`, `failed`,
  `uncertain`) instead of contaminating the server entity with upload state.
- Add `MediaUploadPolicy` as the only source for MIME/extension/limits and pure
  validation. `MediaKind.image` maps to `image/jpeg` + `jpg`; voice maps to
  `audio/mp4` + `m4a`.
- Add exact presigned request/ticket DTOs and a shared backend JSONDecoder capable
  of ISO-8601 with and without fractional seconds. Invalid required dates fail
  decoding rather than becoming the current time.

### MediaUploadService

- Request a ticket through APIClient so Bearer injection and typed API envelopes
  remain centralized. Validate `expiresAt`, signed Content-Length and HTTPS in
  non-debug builds.
- Upload the exact bytes with a foreground URLSession upload task. Apply only ticket
  headers; never attach app authorization or edit the signed URL.
- Expose progress through an AsyncStream/callback owned by the upload task and make
  cancellation terminate that task. Redact signed/public URLs from diagnostics.
- Pre-step-3 failures can request one fresh ticket and re-upload when appropriate.
  Validation errors are not retried unchanged.

### Image pipeline

- Run decode, resize, JPEG encoding and BlurHash outside MainActor. Begin with the
  existing 1,600 px / quality 0.8 output. If over 10 MiB, reduce quality and, if
  needed, dimensions using a bounded deterministic sequence. Reject if still over
  limit; derive all metadata and `fileSize` from final bytes.
- Validate dimensions, BlurHash and caption before requesting a ticket.
- A custom cached image loader uses a configured URLCache. A small local BlurHash
  decoder generates the placeholder without adding a package. Bubble sizing uses
  server width/height with constrained stable dimensions.

### Voice recording and playback

- Create an AudioRecorderService around AVAudioRecorder using AAC in an `.m4a`
  temporary file. Activate `.playAndRecord`, handle microphone permission and
  interruption, publish elapsed time, stop at 900 seconds, and deactivate with
  `notifyOthersOnDeactivation`.
- Delete the temporary file after confirmed send or cancel. Retain it for explicit
  retry while failed/uncertain, then clean it when the row/chat lifecycle ends.
- Create one VoicePlaybackController per ChatViewModel. It owns one AVPlayer,
  switches playback between messages, publishes progress, removes time observers,
  responds to interruption/end, and releases the audio session cleanly.
- URLCache is explicit for images. Voice uses AVPlayer with no durable-cache claim.

### Optimistic send and no-idempotency mitigation

1. Insert a local row immediately and transition from processing to uploading.
2. After PUT succeeds, retain exact `publicUrl` and emit Socket.IO with a 10 s ack.
3. `success: true`: decode saved message and replace the row.
4. `success: false`: show the server message and mark failed (known not accepted).
5. Ack timeout/disconnect: mark uncertain; never automatically emit again.
6. On reconciliation/retry, fetch the newest history page and match exact
   `senderId + publicUrl` (`attachment.url` or `mediaUrl`). If found, replace as
   sent. If absent, a user-confirmed retry may emit the same public URL once.
7. Own `chat:new_message` events perform the same URL match before ID-based append.

This reduces duplicates but cannot prove exactly-once delivery. A separate backend
task should add `clientMessageId` with a unique index/idempotent response. Mobile
can then replace URL heuristics once the contract exists.

### Error policy

| Failure | State / action |
| --- | --- |
| 400 VALIDATION_ERROR/BAD_REQUEST | Fail locally; repair metadata or recompress; no unchanged retry |
| 401 ticket | Enter single-flight refresh; retry ticket once only after success |
| 403 ticket/message | Disable composer, refresh/close conversation through Coordinator |
| 503 ticket | Show temporary R2-unavailable state; retain draft for manual retry |
| expired ticket/R2 403/signature/network | Discard ticket, request a fresh ticket and PUT again |
| PUT 2xx empty body | Success; proceed to Socket step |
| socket `success: false` | Display server message and mark failed |
| socket timeout/disconnect | Mark uncertain; reconcile history before manual resend |
| cancellation | Cancel upload/processing; remove unsent row and temporary files |

`TokenRefreshCoordinator` will be an actor that coalesces concurrent refresh calls.
Because the current backend contract has no refresh endpoint and the app discards
refresh tokens, production cannot perform a real refresh yet. The temporary adapter
returns `refreshUnavailable`, clears the invalid session through the existing auth
flow and asks the user to sign in again; it must not loop or retry with the same
token. The actor and APIClient retry seam can be unit-tested with a successful mock,
then wired to Refresh Token Rotation when the backend publishes that contract.

## 5. Trade-offs and risks

- Socket ack gives definitive success/failure more often than REST plus a later
  broadcast, but timeout remains ambiguous without idempotency.
- URL matching is practical because issued public URLs are unique and backend-owned,
  yet a deliberate second send of the same uploaded object is indistinguishable.
- In-memory optimistic image bytes are simple and bounded by 10 MiB; voice uses a
  temp file to avoid holding up to 25 MiB in memory. App termination loses these
  foreground-only drafts, accepted by scope.
- Progressive JPEG recompression costs CPU. Bounded attempts off MainActor avoid UI
  stalls but can increase send latency on old devices.
- A custom BlurHash decoder adds local code/test surface but avoids a dependency and
  satisfies the placeholder requirement.
- URLCache improves image reuse but is evictable and not an offline media store.
- AVAudioSession is process-global, so recording/playback transitions must be owned
  centrally and tested against calls, Siri, route changes and other app audio.
- R2 uploads that succeed but never reach step 3 become orphaned objects. Server-side
  lifecycle cleanup is recommended separately.

## 6. Conflicts requiring approval

1. **Deployment/state model:** task context says iOS 17+ with `@Observable`; the
   checked-in project targets iOS 16 and all chat/auth state uses Combine
   `ObservableObject/@Published`. Recommendation: keep iOS 16 + Combine for this
   feature to avoid an unrelated app-wide migration. Alternative: approve a separate
   deployment/Observation migration before media work.
2. **Environment selection:** task asks for dev localhost and production config,
   while current `AppEnvironment.current` intentionally always selects deployed
   production and networking tests assert that decision. Recommendation: keep
   production as default and add an explicit build setting/launch override for local
   development, never silently route Debug to localhost. On a physical iPhone,
   localhost is the phone itself and requires a LAN Mac address/tunnel.
3. **Assumed recorder:** the task names an existing `AudioRecorderService`, but none
   exists in this repository. It must be created as part of phase 3.
4. **Refresh behavior:** the API doc requires single-flight refresh, but no refresh
   endpoint is documented and mobile does not retain `refreshToken`. Recommendation:
   add the concurrency seam now, use re-login temporarily, and wire real rotation in
   a separate task when the backend contract lands.

## 7. Execution plan and acceptance gates

### G1 - Contract models, strict decoding, ticket and PUT

Files to update/create:

- `Domain/Entities/Chat.swift`, new `Domain/Entities/MediaUpload.swift`
- `Data/Network/DTOs/ChatDTOs.swift`, `RequestDTOs.swift`
- `Data/Network/Mappers/ChatRealtimeMappers.swift`
- `Data/Network/Endpoints/Endpoints.swift`
- new `Data/Network/BackendJSONDecoder.swift`
- new `Core/Storage/MediaUploadService.swift`; retire active legacy ImageUploader path
- `Data/Repositories/ChatRepositoryImpl.swift`, repository protocols, `AppContainer`
- API/token-refresh seams and redaction only where required

Gate: exact request/ticket keys, Date decoding, raw PUT contract, central limits,
typed errors and cancellation build independently; text chat remains unchanged.
Tests: MIME-extension mapping, limits, image/voice fixtures, fractional dates,
URLProtocol ticket 201, Content-Length mismatch, PUT 2xx/403/network, mocked
401-refresh-single-flight-retry-once and unavailable-refresh re-login behavior.

### G2 - Image sending with Socket acknowledgement

Files to update/create:

- `Core/Storage/ImageProcessor.swift`, existing `BlurHashEncoder.swift`
- `Core/Realtime/SocketClient.swift`, `SocketIOClientAdapter.swift`, `SocketEvent.swift`
- chat repository/use case, `ChatViewModel.swift`, `ChatView.swift`, `ChatCoordinator.swift`

Gate: PNG/JPEG/HEIC input always becomes final JPEG/jpg; size/metadata validated;
processing is off MainActor; ticket -> PUT -> ack order enforced; caption <=2,000;
optimistic progress/cancel appears and confirmed ack replaces it.
Tests: final byte count, recompression limit, valid BlurHash, ack success/error/timeout,
no step 3 on failed PUT, no Bearer on R2 request.

### G3 - Voice recording and sending

Files to create/update:

- new `Core/Audio/AudioRecorderService.swift`
- microphone usage strings in Info.plist and vi/en InfoPlist localization
- voice domain input/use case and AppContainer wiring
- `ChatViewModel.swift`, composer controls and localized strings

Gate: AAC m4a/audio-mp4, visible timer, permission UX, interruption handling,
auto-stop at 900 seconds, 25 MiB check, correct voice payload, temp cleanup after
confirm/cancel and retention only for manual retry.
Tests: duration/size boundary policy, interruption state machine, payload keys,
ticket refresh after upload error. Manual recording requires physical device.

### G4 - Media rendering, playback and cache

Files to create/update:

- new image loader/BlurHash decoder and media bubble views under Chat/Components
- new `Core/Audio/VoicePlaybackController.swift`
- `ChatView.swift`, `ChatViewModel.swift`, `ChatCoordinator.swift`

Gate: same model renders history and realtime image/voice messages; image placeholder
and aspect ratio are stable; URLCache is used; one voice plays at a time with
play/pause/progress; player/session observers are released. Fullscreen navigation,
if included, is Coordinator-owned.

### G5 - Hardening, reconciliation and verification

Files to update/create:

- optimistic row/retry logic, media error mapping, repository reconciliation
- `Tests/MediaUploadContractTests.swift`, URLProtocol/socket/audio mocks and runner
- `.spec/006-chat-media/references/media-upload.md`, `PROGRESS.md`, localization resources
- final `study/media-upload-interview-notes.md`

Gate: own realtime URL dedupe, uncertain ack history lookup, user-controlled resend,
403 composer closure, task cancellation/deinit cleanup, no sensitive release logs,
Debug/Release builds and existing networking/localization/notification regressions pass.

Manual matrix: PNG/JPEG/HEIC, voice 5 s/60 s/near 900 s, weak network, disconnect
during each step, background during foreground upload, ticket expiry, two-device
realtime and playback, microphone denial/interruption and audio-route change.

## 8. Backend diagnostic sequence

When integration fails, compare the app against the doc's exact cURL/Postman flow:

1. POST `/api/v1/chat/media/presigned-url` with Bearer and exact final byte count.
2. PUT raw bytes to the complete `uploadUrl`, No Auth, exact returned headers.
3. For isolation only, POST the documented image/voice body to
   `/api/v1/conversations/{id}/messages`; production media sends use Socket.IO ack.

Do not paste real Bearer tokens or signed upload URLs into committed logs or study
notes. A 200/204 empty R2 body is success. A 403/signature error requires a new
ticket, not mutation or reuse of the old URL.
