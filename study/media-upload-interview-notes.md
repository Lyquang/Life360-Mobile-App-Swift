# Media Upload Interview Notes

## Architecture in one minute

FamilyTracker uploads chat media in three ordered steps: request a short-lived ticket
from the authenticated backend, PUT raw bytes directly to Cloudflare R2, then emit a
Socket.IO message with acknowledgement using the ticket's `publicUrl`. The ViewModel
owns optimistic state; `MediaUploadService` owns ticket and transport details; the
repository maps transport data into domain models. Views never call networking APIs.

## Why a pre-signed URL?

- Large binary data bypasses the application server, reducing backend bandwidth and
  memory pressure.
- The backend still controls authorization, conversation membership, MIME type,
  byte count, object key and a 300-second expiry.
- The signed URL is a temporary credential. It must never be logged or modified,
  and it is never used as the message URL.

Trade-off: upload becomes a distributed workflow. The object can exist before the
message is stored, so orphan cleanup belongs on the backend/storage lifecycle side.

## Why ticket, then PUT, then message?

The message may reference only a successfully uploaded object. Creating the chat
message first would expose broken media while an upload is incomplete or failed.
The client therefore emits `chat:send_message` only after R2 returns `2xx`.

## Why JPEG instead of HEIC?

`PhotosPicker` may return PNG, JPEG or HEIC. The app normalizes all images to JPEG
at quality 0.8, then lowers quality in bounded steps if necessary. JPEG is broadly
renderable by web/CDN consumers, has a stable `image/jpeg` + `jpg` contract, and
usually transfers fewer bytes than PNG. The trade-off is lossy compression and loss
of HEIC efficiency/features. `fileSize` is measured after final encoding.

BlurHash generation and resizing run outside the main actor. The UI decodes the
placeholder locally, preserves the server-provided width/height ratio and uses
`URLCache` for the final image.

## Optimistic UI and duplicate prevention

The UI immediately inserts a local row with `sending(progress)`. A successful socket
ack replaces it with the canonical server message. Pre-message failures are safe to
retry with a fresh ticket because no message exists yet.

An acknowledgement timeout is ambiguous: the server may have stored the message
while the ack was lost. The app does not automatically re-emit. It fetches recent
history and searches for the same sender plus exact `publicUrl`; realtime messages
from the current user use the same key to replace the optimistic row. Only when no
match exists does an explicit retry reuse that URL. This reduces duplicates but is
not a formal idempotency guarantee.

Recommended backend follow-up: accept and uniquely index `clientMessageId` per
sender/conversation. Mobile should switch reconciliation to this idempotency key
when the contract is available.

## Voice notes and AVAudioSession

Recording uses `AVAudioRecorder`, AAC in an `.m4a` container, with MIME
`audio/mp4`. The app activates `.playAndRecord` only while recording, reports elapsed
time, stops at 900 seconds, rejects files over 25 MB and removes temporary files after
send/cancel. An audio interruption cancels the recording and restores the session.

Playback uses one shared `AVPlayer` controller per chat screen. Starting another
voice message stops the previous player. A periodic time observer updates progress;
observers are removed and the audio session is deactivated on stop/deinit.

## Concurrency and memory safety

- Chat state is isolated to `@MainActor`.
- CPU-heavy image processing runs in `Task.detached`.
- Upload tasks are cancellable and retained by local message id.
- Socket, recorder, playback and task closures capture `self` weakly where their
  lifetime may outlive the owner.
- `TokenRefreshCoordinator` is an actor that lets concurrent 401 responses await one
  refresh task. Production currently has no refresh endpoint contract, so the app
  invalidates the expired session and asks the user to sign in again.

## Failure policy

| Failure | Client action |
| --- | --- |
| Validation / bad request | Do not repeat unchanged; compress again or show error |
| Ticket expired / R2 PUT failure | Obtain a fresh ticket and retry before socket send |
| 401 | One single-flight refresh attempt when provider exists; otherwise re-login |
| 403 | Mark failed, close composer, refresh conversation state |
| 503 | Show storage temporarily unavailable |
| Socket negative ack | Show server message and allow explicit retry |
| Socket timeout | Reconcile history by sender + public URL; never auto-resend |

## STAR answer

**Situation:** Media messages could be duplicated when Socket.IO stored a message
but its acknowledgement was lost on a weak mobile network.

**Task:** Provide responsive optimistic sending without violating the backend's
three-step upload contract or silently creating duplicates.

**Action:** I separated ticket, raw PUT and socket acknowledgement into service,
repository and ViewModel responsibilities. I persisted the issued public URL in the
optimistic row, classified pre-send versus ambiguous post-send failures, reconciled
recent history and deduplicated self-echo realtime events using sender plus URL.

**Result:** Safe transport failures can be retried automatically with a new ticket,
while ambiguous socket outcomes require evidence before re-emission. The remaining
edge case is documented for a backend `clientMessageId` idempotency enhancement.
