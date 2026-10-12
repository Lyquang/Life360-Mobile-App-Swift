# P1 - Carry the complete GPS fix (plan)

Status: implemented after approval. Scope: iOS 16, Combine, no backend/UI/socket-contract changes.

## Verified current state

- `CLLocationService.locationManager(_:didUpdateLocations:)` takes only the last `CLLocation` and rejects `horizontalAccuracy < 0`; it keeps the full object in `lastLocation` and calls `onLocationUpdate` with it.
- `DeviceLocationRepositoryImpl` immediately converts that object to `GeoPoint`, publishing `AsyncStream<GeoPoint>` and exposing `lastKnownLocation: GeoPoint?`. Timestamp, accuracy, speed and course are lost at this boundary.
- `ShareLocationUseCase` consumes the `GeoPoint` stream and heartbeat reads `lastKnownLocation`. `lastSent` currently stores a point **plus the time it attempted to send**. Send condition: first point, then `distance >= 50 m OR elapsed >= 30 s`; heartbeat tries the last point every 30 s.
- `SocketRealtimeRepository.sendLocation` accepts `GeoPoint` and emits exactly `latitude`, `longitude`, optionally `batteryLevel` as `update_location`. Map's `ObserveDeviceLocationUseCase`/`GetCurrentLocationUseCase` and `SendSOSUseCase` also depend on the existing `GeoPoint` API.
- `FamilyTrackerTests/*.swift` exists on disk, but the checked-in `project.pbxproj` declares only the app target and the shared scheme has an empty Test action. `xcodebuild test` cannot currently execute XCTest. This plan will not modify the project file.

## Design and alternatives

**Approved model:** `Domain/Entities/LocationFix.swift`, immutable `struct LocationFix: Sendable, Equatable` with `latitude`, `longitude`, `timestamp: Date`, `horizontalAccuracy`, `speed` and `course` (`Double`; preserve negative unavailable values), and computed `point: GeoPoint`. Use primitive coordinates so `GeoPoint` need not be changed merely to satisfy `Sendable`. Mapping from `CLLocation` stays in Data; no CoreLocation import in Domain.

Add `lastKnownFix: LocationFix?` and `observeFixes() -> AsyncStream<LocationFix>` to `DeviceLocationRepository`, while preserving `lastKnownLocation: GeoPoint?` and `observeLocations() -> AsyncStream<GeoPoint>` as compatibility projections for Map/SOS. The Data adapter maps each accepted callback **once**, publishes both streams, and projects the same most recent `CLLocation` for both properties. Do not change `CLLocationService` acceptance, GPS configuration, Map/SOS signatures or `LiveLocationRepository.sendLocation`.

`ShareLocationUseCase` switches to `observeFixes()` and `lastKnownFix` for heartbeat. Its `lastSent` becomes `(fix: LocationFix, sentAt: Date)`: compare `fix.point` to the previous point and `now` to `sentAt`, **not** to `fix.timestamp`. It still calls `sendLocation(fix.point, batteryLevel:)`. Thus metadata is preserved for later P2+ work but unused in P1 decisions and socket payload.

Considered but rejected for P1: replacing all `GeoPoint` APIs (breaks Map/SOS), storing `CLLocation` in Domain (framework dependency), using fix timestamp for 30-second throttle (changes behavior), and adding metadata to Socket.IO payload (changes backend contract). No extra filter, heartbeat fix, or UI work.

## Execution plan after approval

1. **Baseline XCTest first:** add `FamilyTrackerTests/LocationFixTests.swift` with the current `ShareLocationUseCase.handle(GeoPoint, now:)` sequence: first send; <50 m/<30 s suppressed; >=50 m before 30 s sent; <50 m after 30 s sent. Also assert `update_location` keys/values through a fake connected `SocketClient`. Run XCTest if a test target becomes available; otherwise parse the test and explicitly report it unexecuted.
2. Add Domain model and the **additive** repository fix API. Convert `CLLocation` in `DeviceLocationRepositoryImpl`; verify valid and negative `speed`, original `timestamp`, `horizontalAccuracy`, and `LocationFix.point` in XCTest. Keep old projected GeoPoint stream/property.
3. Route only `ShareLocationUseCase` through fixes; adapt the baseline test to fix input with deliberately different GPS timestamp and `now`, asserting identical send decisions/payload. Do not touch Map, SOS, socket or backend implementations.
4. Verify unsigned Simulator build, `scripts/test_networking.sh`, `scripts/test_localization.sh`, SwiftLint, `git diff --check`; attempt `xcodebuild test` only if the target/scheme exists and report the actual outcome. Update `PROGRESS.md`. Suggested single commit: `refactor(location): carry GPS fix metadata without changing emissions`.

Files after approval (8 total including this plan): new `FamilyTracker/Domain/Entities/LocationFix.swift`, new `FamilyTrackerTests/LocationFixTests.swift`, new `.spec/location-fix.md`; edit `FamilyTracker/Domain/Repositories/RealtimeRepositories.swift`, `FamilyTracker/Data/Repositories/DeviceRepositories.swift`, `FamilyTracker/Domain/UseCases/LiveMap/LiveMapUseCases.swift`, `PROGRESS.md`. No `project.pbxproj` edit.

## Risks and rollback

- Two streams can diverge if mapping is performed twice; publish both from one mapped fix and test both projections.
- `LocationFix.timestamp` must not replace `lastSent.sentAt`, or delayed/cached fixes would change 50 m/30 s behavior.
- Adding required protocol members can break external test mocks; update only affected XCTest mocks if compilation reveals them, then pause if file count exceeds the agreed scope.
- Rollback: remove additive fix API/model/adapter, restore `ShareLocationUseCase` to the existing GeoPoint stream, retain the baseline test as a regression record. No persisted schema or socket payload migration is involved.

## Cần tôi quyết định

| Choice | Recommendation | Trade-off |
| --- | --- | --- |
| Name/path | `FamilyTracker/Domain/Entities/LocationFix.swift` | Consistent with Domain entities; a different name would require only type/file substitutions in P1. |
| `course` | Include in P1 (user-approved) | Preserves heading for future navigation without changing emission behavior. |
| Timestamp | `Date` from `CLLocation.timestamp` | Preserves absolute fix time and is `Sendable`; `TimeInterval` is easier for numeric calculations but loses the semantic distinction unless named/anchored carefully. |

Approved: use the recommended path and `Date`, and include `course` for future navigation.

## Verification (2026-10-13)

- Unsigned generic iOS Simulator build: passed with a writable temporary DerivedData/package directory.
- `scripts/test_networking.sh`, `scripts/test_localization.sh`, `swiftc -frontend -parse` on changed Swift files, and `git diff --check`: passed.
- XCTest source added but not executed: `FamilyTrackerTests` is absent from the saved Xcode target/scheme; `project.pbxproj` was left untouched.
- SwiftLint unavailable (`swiftlint: command not found`).
