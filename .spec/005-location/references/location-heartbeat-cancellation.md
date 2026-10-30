# P3 Heartbeat cancellation

Goal: a stopped sharing session must never emit a heartbeat after task cancellation, including cancellation while the interval sleeper is suspended.

Design: inject a small async `Sleeper` closure into `ShareLocationUseCase`, defaulting to `Task.sleep`. The loop checks cancellation before sleep, exits on `CancellationError`, checks again after sleep, then reads the last fix. Keep the 30-second default, old 50 m/30 s decision rule, old heartbeat coordinate payload and idempotent `start()`.

Lifecycle: logout already stops sharing in `LogoutUseCase.defer`; session expiry calls the shared use case stop and password change also stops it. Wire denied/restricted location authorization to the same stop after `AppContainer` initialization.

Tests: deterministic pending-sleep cancellation, release-then-stop race, logout, double-start, stop/restart and authorization loss. No backend or UI change.
