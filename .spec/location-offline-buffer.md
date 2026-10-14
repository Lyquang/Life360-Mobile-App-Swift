# P7A - Durable offline location buffer

Status: approved with the 2026-10-14 amendments; implement buffer only. Full roadmap: `study/location/P7-offline-location-buffer.md`.

## Goal and contract

Persist multiple already accepted P4 `LocationFix` values until later P7 phases send them via `POST /api/v1/locations/batch`. Source contract: `../Backend/api-docs/LOCATION_UPDATE_API_DOC.md`.

Input: owner ID, fix timestamp/coordinate/accuracy, optional battery and a stable UUID. Output: owner-scoped ordered snapshot, append result, exact-ID removal, and bounded unknown-rejection attempt count. No socket/API call in P7A.

## Invariants

- Do not buffer a new point with the same `recordedAt` as the latest buffered point (heartbeat reuse). Do not overwrite an existing `pointId`.
- `activate(ownerID:)` deletes old rows on owner change. A stale task using the previous owner cannot read, append or remove the new owner's rows.
- JSONL rows are independently recoverable. Atomic rewrite, `completeUntilFirstUserAuthentication` file protection and backup exclusion on both directory and replacement file. Corrupt rows are skipped without crashing.
- Drop rows older than 24 hours. On exceeding 500 points, deterministically thin to 400: retain first, newest 100, and uniformly sampled older middle. Preserve chronological order.
- Remove synchronized points by `pointId`; a newer point appended during a batch survives removal. Unknown reject codes increment a durable per-point count and only remove after three responses; only aggregate counts may reach diagnostics.

## Edges and tests

Test duplicate timestamp, app relaunch, damaged JSONL line, backup exclusion after repeated atomic writes, file protection, owner switch, TTL, repeated deterministic thinning and pointId removal after concurrent append. No unfiltered location callbacks enter this buffer.

P7A changes Domain entity, Data actor, XCTest source, this spec, study and progress. No `project.pbxproj` edits. Verify Debug/Release unsigned Simulator builds, contract scripts, SwiftLint and XCTest only if the test target is available.
