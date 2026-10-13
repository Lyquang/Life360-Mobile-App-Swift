# P3 - Cancel heartbeat before it can emit after stop/logout

Status: implemented after approval. Scope: iOS 16, Combine, no backend, UI, payload or 30-second policy changes.

## Verified current state

- `ShareLocationUseCase.start()` is guarded by `isSharing`, so consecutive starts do not create a second heartbeat task.
- The heartbeat loop uses `try? await Task.sleep(...)`, then immediately reads `lastKnownFix` and calls `handle`. If `stop()` cancels the task while sleep is pending, cancellation is swallowed and one extra iteration can reach `handle`.
- `stop()` cancels both tasks, clears `lastSent`, sets `isSharing = false`, and stops the location repository. `LogoutUseCase` calls `shareLocation.stop()` in `defer`, so it runs for success, server failure and local logout paths. `ChangePasswordUseCase` also stops sharing. `AppCoordinator.sessionExpired()` calls `container.shareLocation.stop()` before returning to auth; `MainTabCoordinator.stop()` currently stops notification/emergency services but does not own location stop, which is safe because the shared logout/session paths stop it explicitly.
- `CLLocationService.locationManagerDidChangeAuthorization` invokes `onAuthorizationChange`, but no composition-root callback currently stops sharing when authorization becomes denied/restricted. `DeviceLocationRepositoryImpl` exposes authorization as a value but has no change stream.
- Existing `FamilyTrackerTests` source has no heartbeat lifecycle tests, and the saved Xcode project still has no `FamilyTrackerTests` target/test action. No `project.pbxproj` edit is allowed.

## Design

Use the smallest dependency seam: inject an async `Sleeper` closure into `ShareLocationUseCase`, defaulting to `Task.sleep(nanoseconds:)`. The test supplies a deterministic sleeper that suspends until released or throws `CancellationError`; this avoids introducing the broader `Clock` protocol into this one use case. The production interval remains exactly `minInterval` (30 seconds by default).

The heartbeat loop will:

1. Exit immediately if `Task.isCancelled` before sleeping.
2. `try await sleeper(interval)` and `return` on `CancellationError`/task cancellation.
3. Check `Task.isCancelled` again after sleep and before reading the fix or calling `handle`.

`stop()` remains synchronous and cancels the task before clearing state. `start()` remains idempotent. The existing stream task is also cancelled as today; no sending rule or heartbeat payload changes.

For authorization loss, after all `AppContainer` stored properties are initialized, connect `CLLocationService.onAuthorizationChange` to `shareLocation.stop()` for `.denied`, `.restricted` or other non-authorized statuses. Authorized statuses continue current behavior. This keeps the stop decision at the platform boundary and avoids changing Domain repository APIs. Logout remains covered by the existing `LogoutUseCase.defer`, `ChangePasswordUseCase`, and session-expiry call; add regression assertions around the shared use case rather than duplicate stops.

## Execution plan after approval

1. Add `FamilyTrackerTests/HeartbeatCancellationTests.swift` first. The tests will exercise the current implementation through the injected sleeper seam and are expected to fail before the loop fix: stop while sleeping, stop immediately after sleeper release, logout/use-case stop with no later emit, idempotent double start, and stop-then-start again. Preserve all existing tests.
2. Update `Domain/UseCases/LiveMap/LiveMapUseCases.swift` with the `Sleeper` typealias/default, cancellation checks and explicit cancellation exit. Keep constructor defaults compatible with existing call sites.
3. Update `App/DI/AppContainer.swift` to wire authorization loss to `shareLocation.stop()` after initialization. Verify the existing `LogoutUseCase` and `AppCoordinator.sessionExpired()` call paths remain the shared stop paths; do not add redundant lifecycle architecture.
4. Update `Core/Location/CLLocationService.swift` only if needed to make the existing authorization callback clearly deliver denied/restricted transitions; do not alter location policy. Add `.spec/location-heartbeat-cancellation.md` and update `PROGRESS.md` after verification.
5. Run unsigned Simulator Debug/Release builds, `scripts/test_networking.sh`, `scripts/test_localization.sh`, SwiftLint, `git diff --check`, and `xcodebuild test` only if the test target becomes available. Report the real result. Suggested commit: `fix(location): cancel heartbeat before sharing stop`.

Expected implementation scope is 6-7 files. If authorization wiring requires a new repository stream or more than roughly 8 files, stop and split that work before expanding scope.

## Test matrix

| Case | Expected result |
| --- | --- |
| `stop()` while sleeper is pending | sleeper cancellation/throw exits loop; no later `sendLocation` |
| `stop()` immediately after sleeper release | post-sleep cancellation guard wins; no heartbeat emit |
| logout path | existing `LogoutUseCase` stop prevents later emit even when request fails |
| `start()` twice | one heartbeat task; one eventual heartbeat at most |
| stop then start | new session can heartbeat normally; old task cannot emit |
| authorization denied/restricted | sharing stops and pending heartbeat cannot emit |

## Cần tôi quyết định

| Decision | Recommendation | Trade-off |
| --- | --- | --- |
| Dependency seam | Async `Sleeper` closure | Minimal, localized change and deterministic tests; less general than injecting Swift Concurrency `Clock`. |
| Cancellation reporting | No user-facing/debug event in P3 | Cancellation is expected control flow during stop/logout; avoids changing diagnostics and log volume. Tests prove no emit. |

Approval should confirm the closure seam and no additional cancellation log/event.

Approved: async closure seam and no cancellation log/event.

## Verification (2026-10-13)

- Test source was added before the loop fix. Against the previous `try?` loop, the pending-sleep and release-then-stop cases proceed to `handle` and fail the no-emit assertion. The saved project has no test target/Test action, so this RED state and the final GREEN suite could not be executed with XCTest; `xcodebuild test` exits 66 with “Scheme FamilyTracker is not currently configured for the test action.”
- Unsigned generic iOS Simulator Debug and Release builds: passed.
- `scripts/test_networking.sh`, `scripts/test_localization.sh`, Swift source parsing and `git diff --check`: passed.
- SwiftLint unavailable (`swiftlint: command not found`). No `project.pbxproj` change was made.
