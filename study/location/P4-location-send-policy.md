# P4 - Location send policy with a hard frequency cap

Status: P4A and approved P4B implemented. Runtime sharing now uses the policy below.

## Verified current state

- `ShareLocationUseCase` stores `(LocationFix, sentAt)` for the last **attempted** send. It sends the first point immediately; afterward it suppresses only when both distance is below 50 m and elapsed time is below 30 s. Therefore the actual rule is `distance >= 50 m OR elapsed >= 30 s`, with no minimum interval.
- The cancellation-safe heartbeat still wakes every 30 seconds and calls `handle(lastKnownFix)`. It reuses the latest fix; it does not force a new GPS reading.
- P1 carries timestamp, horizontal accuracy, speed and course into the use case. Motion does not: `MotionActivity` remains private inside `CLLocationService`, while `DeviceLocationRepository` exposes only fixes/coordinates.
- SOS bypasses sharing completely: `SendSOSUseCase -> SOSRepository.sendSOS`. It uses `lastKnownLocation` and never calls `ShareLocationUseCase` or the future policy, so SOS remains immediate without special policy code.
- P2 counts transport emits, heartbeat attempts, motion transitions, configuration changes, invalid-accuracy drops and offline enqueues. It does not yet count policy send/hold/drop reasons.
- There is no app-state provider in Domain. `UIApplication.shared.applicationState` is used elsewhere, but `ShareLocationUseCase` does not know foreground/background.

## Proposed pure model

Add a framework-independent `MotionState` and `LocationSendPolicy` in Domain. Core maps `MotionActivity` to `MotionState` at the Data repository boundary; Domain never imports CoreMotion/UIKit.

```swift
LocationSendPolicy.decide(
    fix: LocationFix,
    lastSent: SentLocation?,
    pending: PendingLocation?,
    now: Date,
    motionState: MotionState,
    config: LocationSendConfiguration
) -> Decision
```

`SentLocation` stores fix, send-attempt time and motion state. `PendingLocation` stores the latest held fix/state and the first hold time. `Decision` carries a reason: `.send(reason)`, `.hold(PendingLocation, reason)`, `.drop(reason)`. Reasons let P2 count policy outcomes without coordinates or identifiers.

Decision order:

1. No `lastSent`: `.send(.firstFix)` immediately.
2. Motion state differs from the state attached to `lastSent`: recommended `.send(.motionChanged)` immediately, bypassing the cap to satisfy the explicit scenario test.
3. Compute elapsed from injected `now - sentAt`. Before `minSendInterval`, a meaningfully moved point becomes/replaces pending; jitter inside the accuracy radius is dropped.
4. Determine speed: use `fix.speed` when nonnegative. Otherwise estimate `distance / positive fix-timestamp delta`; use zero when timestamps are non-increasing.
5. Dynamic threshold is `clamp(speed * targetInterval, minDist, maxDist)`. A point counts as moved only when `distance >= max(dynamicThreshold, fix.horizontalAccuracy)`.
6. After `minSendInterval`, send when moved, when `now - sentAt >= maxHeartbeatAge`, or when evaluating a previously meaningful pending point at its trailing edge. Otherwise drop jitter/not-due input; do not retain meaningless noise as pending.

Heartbeat interpretation: max heartbeat age may send the latest valid fix even if it is inside the accuracy radius. This preserves stationary heartbeat. The “stationary noise does not repeatedly send” test therefore means no movement-triggered duplicates inside the 30-second heartbeat window; one heartbeat per 30 seconds remains expected.

## Central configuration proposal

These are baseline hypotheses to validate with P2, not claimed optimal values:

| Motion state | `minSendInterval` | `targetInterval` | `minDist` | `maxDist` | `maxHeartbeatAge` |
| --- | ---: | ---: | ---: | ---: | ---: |
| stationary | 30 s | 30 s | 50 m | 50 m | 30 s |
| walking / running | 20 s | 20 s | 20 m | 75 m | 60 s |
| cycling | 15 s | 15 s | 30 m | 150 m | 45 s |
| automotive | 10 s | 10 s | 50 m | 250 m | 30 s |
| unknown | 20 s | 20 s | 25 m | 100 m | 60 s |

At 60 km/h, automotive threshold is about 167 m and the 10-second cap dominates, so normal movement emits at most six times/minute. At 5 km/h, walking threshold is about 28 m, reached in roughly 20 seconds, preserving useful slow-walk updates. Accuracy above those values raises the threshold as requested.

## Pending and app state

On `.hold`, retain only the newest meaningful fix. In foreground, cancel/replace one pending task and schedule the remaining time to `minSendInterval`; when it wakes, call the pure policy again with injected `now`. P3 cancellation rules apply to this task too. In background, do not rely on that timer: keep pending in memory and reevaluate it on the next location or heartbeat callback. A background hold that returns to foreground without a location callback will be reevaluated by the existing 30-second heartbeat; P4 will not add a new lifecycle/UI subsystem.

`AppContainer` injects a small `isForeground` closure (`UIApplication.shared.applicationState == .active`) into the use case. UIKit remains outside Domain policy. No persistence is added, so process termination can discard pending; this is consistent with the stated foreground-only trailing-edge scope and is distinct from the existing socket offline queue.

## Split execution plan

The full change touches roughly 10 files, exceeding the agreed per-prompt threshold. Implement it as two buildable commits after approval.

### P4A - Pure policy and motion plumbing

- Add `Domain/Policies/LocationSendPolicy.swift` containing `MotionState`, configuration, sent/pending types, decision/reasons and the pure function.
- Extend `LocationService`/`CLLocationService` with current motion and a motion callback; extend `DeviceLocationRepository` with current Domain motion and an `AsyncStream<MotionState>`. Map Core `MotionActivity` to Domain in `DeviceLocationRepositoryImpl`.
- Add policy table tests with a fake clock (`now` values): stationary jitter, 60 km/h cap, negative-speed estimation, first fix, state change, large accuracy, slow walking and pure pending/trailing decisions.
- Add/update P4 spec. Build and run available checks before P4B. No use-case behavior changes in P4A.

### P4B - Use-case integration, trailing edge and diagnostics

- Replace `ShareLocationUseCase.handle` OR logic with policy decisions; subscribe to motion state, maintain latest pending, and own one cancellation-safe foreground pending task. `stop()` cancels stream/heartbeat/pending tasks and clears all send state. Heartbeat remains 30 seconds.
- Inject foreground state in `AppContainer`; keep SOS untouched.
- Extend `LocationDiagnostics` with aggregate policy reason counters (`send`, `hold`, `drop`) and no coordinate data. Update its tests.
- Add integration tests for foreground trailing edge, background callback reevaluation, max rate, double start/stop, and unchanged socket payload. Update `PROGRESS.md` and architecture study.
- After each subphase: unsigned Debug/Release Simulator build, networking/localization scripts, SwiftLint, `git diff --check`, and XCTest if a target exists. Do not edit `project.pbxproj`.

## Risks and rollback

- State transitions can bypass the cap under the recommended interpretation, so noisy motion classification could burst sends. Hysteresis is explicitly deferred; P2 counters must expose this.
- Fix timestamp estimation can be invalid/out of order; nonpositive delta falls back to zero speed rather than infinity.
- Trailing tasks must use a generation/token check so an older cancelled pending task cannot send a newer session's point.
- `maxHeartbeatAge` is based on attempted send time, preserving current semantics; it is not an acknowledgement guarantee.
- Rollback P4B restores current `handle` while P4A pure policy/motion stream can remain unused without changing behavior.

## Cần tôi quyết định

1. Approve the table above. Recommendation: use it as the first measured hypothesis.
2. Approve background behavior: no timer guarantee; send pending on next fix/heartbeat callback.
3. Approve keeping stationary heartbeat at 30 seconds; moving states use the table's longer/independent `maxHeartbeatAge`.
4. Resolve one wording conflict: the formula says the minimum interval applies before all reasons, but the required scenario says motion-state change sends immediately. Recommendation: first fix, SOS and motion-state change bypass `minSendInterval`; document state change as the only non-SOS cap exception.
5. Approve splitting into P4A and P4B because the complete implementation exceeds eight files.

## P4A verification (2026-10-13)

- Added the pure policy/configuration and Domain `MotionState`; exposed current motion plus a motion stream through the location repository. `ShareLocationUseCase` still uses the old 50 m/30 s rule.
- Scenario test source covers stationary jitter/heartbeat, approximately 60 km/h automotive cap, trailing edge, negative-speed estimation, first fix/state transition, large accuracy and slow walking. Repository mapping from Core activity to Domain state is covered.
- Unsigned generic iOS Simulator Debug and Release builds, networking/localization scripts, Swift parsing and `git diff --check` passed.
- XCTest source could not execute: `xcodebuild test` exits 66 because the saved `FamilyTracker` scheme has no Test action. SwiftLint is unavailable (`swiftlint: command not found`). No `project.pbxproj` change was made.
- P4B items (runtime integration, pending task, foreground/background handling and P2 reason counters) remain untouched.

## P4B implementation and verification (2026-10-13)

- `ShareLocationUseCase` now evaluates fixes, heartbeats and motion transitions through `LocationSendPolicy`. It keeps only the latest meaningful pending fix and cancels location, motion, heartbeat and pending tasks on `stop()`.
- Foreground holds schedule one cancellation-safe trailing-edge task. Background holds do not rely on a timer and are reevaluated by the next fix or existing heartbeat callback. A generation check prevents stale cancelled tasks from sending in a later state.
- `AppContainer` injects app activity state, keeping UIKit out of Domain. SOS remains on its independent immediate repository path. Socket payload remains `latitude`, `longitude`, and `batteryLevel` only.
- Debug diagnostics aggregate `send.<reason>`, `hold.<reason>` and `drop.<reason>` counters without coordinates or tokens. Release remains no-op.
- Integration test source covers automotive rate cap, foreground trailing edge, background callback reevaluation, immediate motion transition, diagnostics reasons and unchanged socket payload.
- Debug unsigned Simulator build, networking/localization scripts, SwiftLint and `git diff --check` passed. SwiftLint reports 10 pre-existing warnings outside P4 files and no serious violations.
- XCTest could not run because the current project exposes only the `FamilyTracker` app target; `FamilyTrackerTests` is absent from `xcodebuild -list`. Per constraint, `project.pbxproj` was not modified.
