# P2 - Debug location diagnostics and baseline protocol

Status: implemented after approval. No backend, UI, location policy or socket payload changes.

## Verified current state

- `CLLocationService` accepts only the last callback fix and drops it when `horizontalAccuracy < 0`. It has `MotionActivity` (`stationary`, `walking`, `running`, `cycling`, `automotive`, `unknown`), not a `MotionState` type. The motion callback can repeat the same state. `applyPolicy(force:)` applies manager settings after permission/start/power changes, not only after motion changes.
- `ShareLocationUseCase` sends on `>=50 m OR >=30 s` and runs a 30-second heartbeat task; no diagnostic counters or session battery snapshots exist. `SocketRealtimeRepository` sends `update_location` immediately when connected, otherwise coalesces it into `OfflineQueue`; replay occurs on reconnect/session-ready. `OfflineQueue` has no event-specific counters.
- `BatteryMonitor` exposes an optional integer percent; its thread-safe `BatterySnapshot` is already passed to `CLLocationService`. Simulator may return `nil`.
- `AppContainer` injects `PulseDiagnostics.shared` in Debug and `NoopNetworkLogger` in Release. `PulseDiagnostics.logSocket` runs `DiagnosticRedactor.body` before storage; that redactor masks `latitude`, `longitude`, token-like keys. Existing raw socket logs are separate from the proposed aggregate summary.
- `FamilyTrackerApp` has no `scenePhase` hook and `AppDelegate` has no background notification handler. The saved Xcode project still contains no `FamilyTrackerTests` target, although test source files exist.
- The older `study/REALTIME_LOCATION_AND_BATTERY_OPTIMIZATION.md` predates P1 and says fix metadata is discarded; update that statement in a later documentation-only task, not inside P2 instrumentation.

## Design and counter semantics

Add one Debug-only, synchronous, lock-protected `LocationDiagnostics` service, constructed once in `AppContainer` with the existing logger and `BatterySnapshot`; in Release its methods compile to no-ops. This avoids `Task` scheduling in GPS/socket hot paths. Never accept a coordinate, token, user ID or raw socket payload into the diagnostic API. Use the existing `MotionActivity` values as counter keys; `unknown` is a valid bucket.

| Counter | Event boundary / meaning |
| --- | --- |
| `emitted[state]` | Actual `SocketClient.emit(update_location, ...)`, including offline replay, classified by current motion state **at transport emit time**. It is not an ack/delivery count. |
| `heartbeatAttempts` | A heartbeat tick that found a last fix and called `handle`; it may be suppressed by the existing rule. Actual socket emits are counted separately. |
| `motionTransitions` | New activity differs from the previous activity, excluding the initial observation from `unknown` unless it truly changes state. Repeated callbacks do not increment. |
| `managerReconfigurations` | `applyPolicy` passes its guards and writes settings/start-stop calls; count forced applications even when values equal. |
| `dropped[invalidHorizontalAccuracy]` | Current `horizontalAccuracy < 0` rejection only. Do not invent filters for age, speed or >50 m accuracy. |
| `offlineQueueEnqueues` | Calls that enqueue `update_location` while disconnected; coalescing can make pending queue length lower. Replay increments `emitted` only when actually emitted. |

`startSession` resets counters, records start time and optional battery percent; `stopSession` records end percent and logs one final summary. Sample battery percent and elapsed time at every motion transition too: only single-state segments with valid non-charging endpoints can suggest per-state drain; mixed-state session start/end alone cannot assign battery use to a state. Percent is coarse, so report `unknown` when unavailable and never claim causal energy savings from one run. `reset` is explicit and tested. A 15-minute timer while the process is active and `UIApplication.didEnterBackgroundNotification` write a **single aggregate Pulse entry** via the existing logger (`logSocket` with a synthetic `location_diagnostics_summary` event). Summary contains counts, state names, session/segment durations and optional battery percentages/deltas only. No coordinates/token fields, and run the JSON through `DiagnosticRedactor` before logging. A background callback/timer is best-effort; iOS suspension/termination can skip a scheduled summary. No persistence, server upload or new UI.

Considered: a hidden screen (extra UI and state surface), actor records (async hop for every GPS/socket event), `os_signpost` (useful for Instruments timing but unnecessary for count baseline), and logging every fix (volume/privacy cost). Keep all out of P2.

## Execution plan after approval

Implementation slice (8 files, excluding this already-written plan):

1. Add `.spec/005-location/references/location-diagnostics.md` with event semantics; add `Core/Logging/LocationDiagnostics.swift` with lock-safe state, Debug compilation guard, summary formatter, 15-minute timer/background observer and no-op Release methods. Test the pure counter/reset/summary behavior first in `FamilyTrackerTests/LocationDiagnosticsTests.swift`, including fake logger, different motion buckets, duplicate motion callback, offline enqueue/replay and absence of coordinate/token strings. Use a disabled instance in Debug to exercise no-op behavior; also verify Release compilation. Do not alter `project.pbxproj`.
2. Add record calls only at existing event boundaries in `Core/Location/CLLocationService.swift`, `Domain/UseCases/LiveMap/LiveMapUseCases.swift` and `Data/Repositories/SocketRealtimeRepository.swift`. Include start/end battery and heartbeat attempt, without changing the existing send condition, location acceptance, socket payload or offline queue semantics.
3. Inject the one diagnostics instance through `App/DI/AppContainer.swift`; update `PROGRESS.md` after verification. No `AppDelegate`, `FamilyTrackerApp`, Pulse implementation or backend edits.
4. Verify unsigned Simulator build, `scripts/test_networking.sh`, `scripts/test_localization.sh`, SwiftLint and `git diff --check`. Run `xcodebuild test` only if a test target/scheme becomes available; otherwise report test source unexecuted. Suggest one commit: `chore(location): add debug-only baseline diagnostics`.

If implementation requires a ninth code file or a new UI/lifecycle dependency, stop and split a follow-up rather than widening this change.

## Device baseline protocol

Use the **same iPhone**, OS/app build, Circle account, permission mode, network type, Low Power Mode setting, screen state and approximate starting battery band for every run. Disconnect charging, note ambient temperature and whether the app is foreground/background. In Xcode Instruments, record **Energy Log** (and location/network activity if available). A Debug build with Pulse enabled can add overhead; use the same build for before/after comparison. Run at least one repeat per scenario, ideally alternating baseline/variant order. Never include raw route, coordinates, identifiers or tokens in shared reports.

| Scenario | Duration | Keep constant / annotate |
| --- | --- | --- |
| Seated, screen locked | 30-60 min | Same Wi-Fi/cellular, phone position, background permission, no charging. |
| Walking | 30 min | Similar pace/route and network; note pauses and motion-state time split. |
| Driving (passenger) | 30 min | Similar trip/network; do not interact with phone while driving. |

For each run, fill: scenario, build/commit, device/OS, start/end clock, observed duration in hours, start/end battery %, charging/Low Power Mode, time by motion state, `emitted` by state, `heartbeatAttempts`, `motionTransitions`, `managerReconfigurations`, invalid-accuracy drops, offline enqueues, network interruptions, Instruments Energy Log assessment and anomalies. Calculate `emits/hour = total emitted / observed hours` and `battery percentage-points/hour = (start % - end %) / observed hours`; mark unavailable/charging runs `N/A`. Do not call this measured energy in mWh or claim per-state battery drain when a segment lacks valid battery endpoints. Compare distributions and Energy Log rather than one isolated run.

| Run / build / device | Scenario / network / screen | Duration (h) | Battery start -> end (%) | Emits by motion / total per hour | Heartbeat / reconfig / drops / offline | Battery pp/hour | Energy Log / interruptions / notes |
| --- | --- | ---: | --- | --- | --- | ---: | --- |
| Fill after the real-device run |  |  |  |  |  |  |  |

## Risks, rollback and decisions

- Instrumentation must not log a full fix or modify the socket dictionary. Flush counts represent transport sends, not server delivery. Reconnect can attribute a buffered fix to the current state; summary labels must say this.
- Timer/background summaries are best-effort under suspension. Lock duration and logger work must be separated to avoid blocking CoreLocation callbacks. Release should allocate no timer/observer and retain no metrics.
- Rollback: remove the injected diagnostics and event calls; delete the Debug service/tests/spec. No persisted data or backend migration exists.

### Cần tôi quyết định

| Decision | Recommendation | Trade-off |
| --- | --- | --- |
| Output | Existing Pulse Debug log, no hidden screen | Easy export and no UI scope; aggregated log can still be absent if process is terminated. |
| Period | Every 15 minutes while active, plus background and stop | Enough resolution for 30-minute trials; more frequent logging adds noise. |
| `os_signpost` | No for P2 | Energy Log remains usable; signposts can be added later if timing correlation is needed. |
| Battery by state | Sample at transitions in addition to session endpoints | More useful segmentation; battery % remains too coarse for a causal per-state claim. |

Approved: Pulse Debug output, 15-minute active interval plus background/stop, no `os_signpost`, and battery samples at state transitions.

## Verification (2026-10-13)

- Unsigned generic iOS Simulator Debug and Release builds: passed. Release diagnostics compiles as no-op, without timer/observer/state fields.
- `scripts/test_networking.sh`, `scripts/test_localization.sh`, changed-test Swift parsing and `git diff --check`: passed.
- XCTest source added, but not executed: the checked-in Xcode project still has no `FamilyTrackerTests` target or test action. No `project.pbxproj` edit was made.
- SwiftLint unavailable (`swiftlint: command not found`). Real-device baseline and Instruments Energy Log remain manual, with no measured battery claim yet.
