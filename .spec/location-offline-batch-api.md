# P7B - Offline location batch API

Status: approved and implemented. Contract: `../Backend/api-docs/LOCATION_UPDATE_API_DOC.md`.

## Goal

Expose authenticated `POST /api/v1/locations/batch` without connecting the buffer to runtime sharing yet. Input is 1...100 `BufferedLocationPoint` values; output is accepted IDs, duplicate IDs and rejected records. A request body must remain below 100 KB.

## Invariants

- Encode the original GPS fix time as ISO-8601 with milliseconds. Do not send owner ID or the buffer's retry counter.
- Existing `APIClient.send` callers retain their behavior. `sendWithMetadata` uses the same Bearer interceptor and single-flight 401 refresh path; it exposes `Retry-After` only as a batch-specific rate-limit error.
- Map API errors into `LocationBatchError` at the repository boundary. P7C owns retry timing and removal of accepted/duplicate IDs; P7B does not mutate the buffer.

## Edge cases and verification

Test empty/oversized count, encoded keys/date, partial success, 429 header, and 401 refresh/retry. Debug/Release unsigned Simulator builds, networking/localization scripts and SwiftLint are required. XCTest source is added but cannot run until the Xcode project has a configured `FamilyTrackerTests` target; do not edit `project.pbxproj` here.
