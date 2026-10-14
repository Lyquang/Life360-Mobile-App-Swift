# P7 - Persistent offline location buffer and batch recovery

Status: P7A-P7C implemented as unused storage/transport/synchronization components; P7D onward remain planned.

## Verified contract and current state

The source contract exists at `../Backend/api-docs/LOCATION_UPDATE_API_DOC.md` (not under Mobile's `api-docs/`). P5 and P6 are documented: realtime accepts optional `recordedAt`/`accuracy`; `POST /api/v1/locations/batch` accepts 1...100 points and a body below 100 KB; `(userId, pointId)` is idempotent; mixed results return `accepted`, `duplicates`, and permanent `rejected` entries. A 401 must use shared refresh, and 429 must honor `Retry-After`.

P1/P2/P4 are present. `LocationFix` retains timestamp and accuracy, and `ShareLocationUseCase` applies the send policy before calling `LiveLocationRepository`. However, that repository currently accepts only `GeoPoint`, so timestamp and accuracy are discarded before transport. Realtime payload still contains only latitude, longitude, and battery.

The prompt's “RAM-only” statement is partly outdated. `OfflineQueue` already writes an atomic JSON array in Application Support with `completeFileProtectionUntilFirstUserAuthentication`, a 200-item/24-hour bound, and reloads it after launch. Its location item is still coalesced under `location`, so only the newest point survives. It does not exclude the file from iCloud backup; one decode error loses the whole queue; `drain()` deletes before successful delivery; and location replay is sent over unacknowledged Socket.IO.

Socket `.connected` currently flushes before authenticated `session:ready`, and there is no explicit ready flag. There is no `NWPathMonitor` or foreground synchronization hook. `URLSessionAPIClient` already performs single-flight refresh and one retry after 401, but its public result omits HTTP headers, so a batch client cannot read `Retry-After`. Keychain stores the current user ID privately. Logout/session expiry share cleanup paths, but there is no separate location synchronization task to cancel.

## Storage decision

### Recommended: bounded atomic JSON Lines file

Use a `LocationBuffer` actor and one owner-scoped JSONL file in Application Support. The actor rewrites the bounded snapshot atomically after each mutation; each line is one independently decodable `BufferedPoint`. On load, invalid lines are skipped and counted while valid lines survive. Set `.completeFileProtectionUntilFirstUserAuthentication`; exclude the containing directory from backup and reapply exclusion to the file after each atomic replacement. Test the exclusion after repeated writes. No coordinate, URL, token, or raw file content is logged.

For a few hundred records this is simpler and easier to test than Core Data while still giving partial-corruption recovery. The trade-off is an O(n) rewrite per accepted policy point; with P4 throttling and a 500-point cap, the cost is bounded and off the main actor.

Alternatives considered:

| Option | Benefit | Cost / reason not preferred |
| --- | --- | --- |
| Atomic JSON array | Smallest implementation | One corrupt byte can make every point undecodable; poor partial recovery |
| Core Data | Transactions, queries, migration support | Considerably more schema/container/migration machinery for one bounded append queue |

## Recommended policy decisions

- Capacity: **500 points**, maximum age **24 hours**, backend batch size **100**, additionally split by encoded size below 100 KB. Reject an incoming fix whose timestamp equals the most recently buffered fix; a heartbeat reusing one GPS observation must not create another point. Test this.
- Thinning: when an append would exceed 500, thin to **400**. Keep the first point and newest 100 points; uniformly sample the older middle into 299 slots using deterministic integer positions. This 100-point headroom avoids thinning on every append. Prune expired points first. Test stable order, both endpoints, deterministic results and distribution over repeated thinning cycles.
- Rejected points: remove documented permanent validation failures from the active buffer and increment aggregate counts. For an undocumented `code`, retain the point with a durable rejection-attempt counter; remove after **three** such responses and count the outcome. No coordinates in metrics or dead-letter logs.
- Realtime ordering: after `session:ready`, obtain/send a **fresh fix** through Socket.IO first for immediate family-map freshness, then synchronize buffered historical points through REST. Never replay old points through socket and never submit that fresh realtime point in the same batch.
- UI: no sync indicator in P7. Keep diagnostics Debug-only and aggregate-only.
- Retry: one synchronizer actor provides single-flight execution. Retry transient network/5xx failures with exponential delays 2, 4, 8, 16, 30 seconds plus 0...25% jitter, capped at five attempts per trigger. A later lifecycle/network trigger may start a new run. For 429, a `Retry-After` longer than about 60 seconds ends this run and persists a `notBefore` time; shorter waits may sleep within the attempt budget. APIClient handles one shared-refresh retry for 401; a second 401 stops the run.

## Proposed architecture

```text
ShareLocationUseCase (already filtered by P4)
  -> LiveLocationRepository.sendLocation(LocationFix, battery)
     -> socket ready: emit fresh realtime payload with recordedAt/accuracy
     -> socket unavailable/not ready: LocationBuffer.append(ownerId, BufferedPoint)

LocationSyncCoordinator actor (single-flight)
  triggers: session:ready | foreground | NWPath satisfied
  -> request/send fresh fix via socket
  -> LocationBuffer.batch(ownerId, <=100 and <100 KB)
  -> LocationBatchRepository -> APIClient -> POST /locations/batch
  -> remove accepted + duplicates + known permanent rejected by pointId only
  -> retain untouched/transient failures
```

The generic SOS/chat `OfflineQueue` remains in place. Location entries are removed from it so SOS behavior is not changed. `SocketRealtimeRepository` must distinguish transport connection from authenticated session readiness.

Account isolation uses the Keychain user ID as the buffer owner. Stored rows carry `ownerId`, and reads/syncs require an exact owner match. Login calls `activate(ownerID:)`: changing owner permanently deletes old rows before any send; stale tasks for the previous owner cannot append, read or delete new rows. Explicit logout and password-change sign-out cancel synchronization and clear the buffer. On lost location permission, stop adding points; retain existing points until TTL cleanup. Involuntary session expiry is an open decision below.

`LocationBuffer.remove(pointIDs:ownerID:)` matches stable IDs from the server response, never request array indexes. An append during an in-flight batch therefore survives the acknowledgement of older points. `NWPathMonitor` triggers are debounced and skipped when the buffer is empty. Consider a trigger when iOS wakes the app for a background location event, subject to available background execution time.

## Risks and rollback

- A fresh one-shot fix requires a narrow addition to the location abstraction; if Core Location cannot produce one promptly, batch sync may proceed while realtime waits for the next normal accepted fix. It must not substitute an old buffered point into both channels.
- Reading `Retry-After` requires response metadata from networking. Keep this additive so existing repositories and error mapping are unchanged.
- Frequent atomic rewrites cost I/O, bounded by P4 and 500 records. Instruments and P2 counters should verify this on a device.
- A socket emit just before disconnect can be lost because `update_location` has no acknowledgement. P7 only guarantees persistence for points routed into the buffer while the session is unavailable; closing this narrow gap needs an ack/idempotency contract later.
- Rollback can disable P7 composition and restore current socket coalescing without changing P4 policy or backend contracts. The owner-scoped file can then be cleared safely.

## Execution plan (split required)

The complete task exceeds eight files, so implement it as five independently buildable approvals/commits.

### P7A - Durable buffer

Files: create `Domain/Entities/BufferedLocationPoint.swift`, `Data/Local/LocationBuffer/LocationBuffer.swift`, `FamilyTrackerTests/LocationBufferTests.swift`, and a P7 spec; update progress after verification. Implement owner isolation, JSONL atomic persistence, protection/backup flags, corruption recovery, 24-hour pruning and 500→400 thinning. Add pointId-based removal and a durable counter for unknown rejection codes, ready for P7C. Test duplicate timestamp, persistence across instances, backup exclusion after repeated writes, corruption, deterministic repeated thinning, ordering, concurrent append/removal and owner mismatch. No runtime integration yet.

### P7B - Batch API contract

Files: create `LocationBatchDTOs.swift`, a Domain batch repository protocol, a Data repository implementation and API metadata tests; update `Endpoints.swift` and `APIClient.swift`. Add the endpoint and additive response metadata sufficient for `Retry-After`; existing callers keep using `send` unchanged. Encode `recordedAt` with the existing ISO-8601 utility. Test request keys, 100-point/body limits, partial response, shared-refresh 401 and 429 header exposure.

### P7C - Single-flight synchronization engine

Files: create `LocationSyncCoordinator.swift` and its tests; update the buffer only if batch-safe reservation APIs are required. Implement single-flight, chronological batches, encoded-size splitting, partial-result removal by pointId, bounded backoff/jitter, 429 delay, persistent long-delay `notBefore`, cancellation and no infinite rejected retries. Use injected clock/sleeper/randomness for deterministic tests. No lifecycle or socket integration yet.

### P7D1 - Authenticated readiness flag

Files: update `SocketRealtimeRepository.swift` and focused tests. Add a session-ready flag, set only by `session:ready` and clear on disconnect/reconnect. Observe it without changing current send/queue behavior.

### P7D2 - Preserve fixes and route offline points

Files: update `RealtimeRepositories.swift`, `LiveMapUseCases.swift`, `SocketRealtimeRepository.swift`, location service/repository abstractions, `AppContainer.swift`, and focused location tests. Preserve `LocationFix` through the repository boundary; emit `recordedAt`/valid accuracy; buffer accepted P4 outputs while unavailable/not ready; remove location from generic coalescing. On ready, request a fresh fix for socket delivery and trigger historical sync without replaying old points as new. SOS/chat queue stays unchanged.

### P7E - Lifecycle, account isolation, cleanup and diagnostics

Files: expose current Keychain user ID, add one `NWPathMonitor` wrapper, update `AppDelegate` foreground callback, `AppContainer` cleanup/trigger wiring, auth cleanup paths, `LocationDiagnostics`, and focused tests. Trigger sync on foreground and debounced path satisfaction only when buffered points exist; consider background-location wake as an additional trigger. Enforce exact owner matching and cancel/clear on logout or account change. Permission loss stops future appends and leaves existing rows for TTL cleanup. Apply the chosen expiry-session rule after the decision below. Add aggregate buffered/accepted/duplicate/rejected/retry counters without coordinates. No UI.

Each phase: unsigned Debug/Release Simulator build, networking/localization scripts, SwiftLint, `git diff --check`, and `xcodebuild test` only if `FamilyTrackerTests` is present. Do not edit `project.pbxproj`.

## Cần tôi quyết định

Involuntary session expiry needs one decision before P7E: **(1) delete immediately**, minimizing retention but losing unsent route history if reauthentication succeeds; or **(2) retain for the same owner for up to 24 hours**, preserving history but keeping sensitive location on disk longer. Recommendation: (2), with strict owner matching and TTL, while explicit logout deletes immediately. P7A can proceed independently.

## P7A result (2026-10-14)

- Added `BufferedLocationPoint` with stable UUID, GPS timestamp, coordinates, nonnegative accuracy, optional battery and a durable unknown-rejection attempt count.
- Added `LocationBuffer` actor. It stores independently decodable JSONL rows in an owner-scoped Application Support directory. Writes are atomic with file protection; both directory and replacement file are excluded from backup. On read, damaged rows are skipped and the file is repaired. Owner activation deletes previous owner's rows; stale owner operations cannot mutate the new owner's buffer.
- The buffer rejects duplicate latest timestamps and duplicate UUIDs, prunes after 24 hours, and thins 500→400 while retaining the first and newest 100 points. Removal matches point IDs only. Unknown rejection attempts remove a point on the third response.
- XCTest source covers persistence, corruption, repeated backup exclusion, duplicate heartbeat timestamps, thinning, concurrent append/ID removal, owner isolation and TTL. The Xcode project currently has only the `FamilyTracker` app target, so XCTest could not execute without adding a target; `project.pbxproj` was left unchanged.
- Unsigned Debug/Release Simulator builds, networking/localization contract scripts, targeted SwiftLint and Swift parsing passed. The buffer is not yet wired into live location sharing; P7D2 is the runtime integration phase.

## P7B result (2026-10-14)

- Added `POST /locations/batch`, DTOs that encode only contract fields, a batch repository boundary and a Data implementation. It rejects empty or >100-point batches and bodies of 100 KB or more before a network call; successful partial responses retain accepted, duplicate and rejected IDs/codes.
- Added `APIClient.sendWithMetadata` without changing the existing `send` API behavior. Both paths share Bearer attachment and 401 refresh/retry. The batch path preserves the 429 `Retry-After` header for P7C to interpret.
- Networking contract harness verifies encoding, endpoint, accepted IDs and `Retry-After`. XCTest source additionally covers partial rejection, request limits and 401 refresh. The test target remains absent from `project.pbxproj`, so XCTest has not executed. No P7C sync or P7D runtime routing is active.

## P7C result (2026-10-14)

- Added a single-flight `LocationSyncCoordinator` actor. Each run processes one chronological buffer snapshot in batches constrained by 100 points and encoded body size. It removes only exact acknowledged/known-permanent IDs, counts unknown rejections once per response and leaves newly appended points for another run.
- Added bounded transient retry with injected clock/sleeper/randomness, 413 split handling and `Retry-After` parsing. A delay above 60 seconds persists an owner-scoped not-before gate instead of sleeping; cancellation stops post-response buffer mutation.
- Added focused XCTest source. P7C remains unwired: P7D1 tracks authenticated socket readiness, P7D2 routes fixes into the buffer, and P7E adds lifecycle/network triggers and cleanup.
