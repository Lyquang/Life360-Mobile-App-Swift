# P7C - Offline location batch synchronizer

Status: approved and implemented as an unwired service. Contract: `../Backend/api-docs/LOCATION_UPDATE_API_DOC.md`; roadmap: `study/location/P7-offline-location-buffer.md`.

## Goal and inputs

`LocationSyncCoordinator.synchronize(ownerID:)` reads one owner-scoped buffer snapshot, sends chronological batches of at most 100 points and less than 100 KB, then returns aggregate accepted/duplicate/rejected counts or a deferred-until time. P7C does not attach socket, foreground or network-path triggers.

## Invariants

- One active run per owner. Concurrent callers share its result. Cancellation is checked after each network response and before buffer mutation; no completed old-owner task may delete a new owner's points.
- Remove only acknowledged accepted/duplicate IDs and documented permanent reject IDs. Resolve a missing rejected ID from its valid batch index, never remove by index. Unknown reject codes increment a durable per-point count and are retried only on a later run; P7A deletes on attempt three. Duplicate reject entries count once.
- Timeout/5xx retries are bounded to five attempts per batch with 2/4/8/16/30-second capped exponential backoff plus injected 0–25% jitter. A 413 splits the batch; one oversized point fails without a loop.
- Parse `Retry-After` seconds or HTTP date. A delay over 60 seconds is persisted as an owner-scoped `notBefore` gate and ends the run; short delays use the injected sleeper. A second 401 is terminal because P7B already uses one shared token-refresh retry.
- No coordinates, tokens, raw server reasons or per-point IDs are logged.

## Verification

XCTest source covers partial success, 413 splitting, transient backoff, persisted long 429, concurrent callers, cancellation and append-during-upload. Unsigned Debug/Release Simulator builds, networking/localization scripts, SwiftLint and `git diff --check` are required. The project still lacks a configured `FamilyTrackerTests` target, so XCTest cannot execute without a separate target setup; do not modify `project.pbxproj` in P7C.
