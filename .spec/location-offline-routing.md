# P7D - LocationFix routing and authenticated socket readiness

Approved scope: P7D1 then P7D2 from the P7 roadmap.

- D1: expose session readiness, set only by `session:ready`, reset on disconnect/connect. Validate independently before routing changes.
- D2: preserve `LocationFix` into the realtime repository. Route policy-approved offline points to the owner-scoped buffer; remove legacy location replay. Keep the realtime socket payload unchanged (`latitude`, `longitude`, `batteryLevel`); timestamp and accuracy are retained for durable batch history only.
- On ready while sharing, request a new Core Location observation and reject cached fixes for this reconnect boundary. Send that observation before historical batch sync. If no fresh observation arrives within 10 seconds, allow batch sync and continue waiting for a fresh observation. A suspended app may execute the timeout later.
- Stop/revoke/logout cancels pending work. Explicit logout clears stored points; account switching activates the new buffer owner. Approved expiry policy: retain for the same owner up to the existing 24-hour TTL, then prune on the next storage access. iOS suspension prevents guaranteeing a physical deletion exactly at the TTL deadline.
- No changes to P4 thresholds, SOS routing, UI, backend or project.pbxproj. DeviceLocation's coordinate-only interface remains available to map/history/SOS.

Implementation slices: D1 repository/readiness tests; D2 transport/domain/CoreLocation changes and fixture updates; D2 composition/delivery and integration tests. Each slice remains within roughly eight production files; test fixtures are updated with changed protocol requirements.

Verify connected-but-not-ready, disconnect and duplicate ready, unchanged realtime payload, offline deduplication, fresh-before-batch ordering, stale callbacks, cancellation and owner isolation. Run unsigned Simulator build, existing contract scripts, SwiftLint and XCTest when target exists.

Rollback: revert the P7D integration as one change; buffer files can be cleared through the existing storage APIs. Socket emits remain unacknowledged, so an emit immediately before disconnect can still be lost.

Fresh-fix acquisition uses a separate one-shot CLLocationManager with the currently applied accuracy, leaving the adaptive continuous/significant-change manager in place. See Apple's [requestLocation](https://developer.apple.com/documentation/corelocation/cllocationmanager/requestlocation()) and [startUpdatingLocation](https://developer.apple.com/documentation/corelocation/cllocationmanager/startupdatinglocation()) documentation. This is a reconnect-boundary send; subsequent updates still use P4's unchanged policy.

## Device checklist

1. Two devices in one Circle: disconnect A, walk, reconnect; A sends a new observation after session:ready, B updates, and only historical fixes appear in REST batch.
2. Repeat session:ready without disconnect: no second fresh-location request or duplicated sync trigger.
3. Keep GPS unavailable after reconnect: after 10 seconds of executable task time, batch may run; cached heartbeat is not emitted as the fresh fix.
4. Logout during pending write/upload: no later location emit; buffer is cleared. Reauthenticate same owner after expiry: surviving points remain eligible within TTL. Login another owner: prior rows are deleted.
5. Revoke location permission or stop sharing: cancel pending sends and sync, retain stored points for TTL cleanup. Repeat with device locked and Low Power Mode.
