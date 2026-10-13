# P2 Debug location diagnostics

Goal: measure a baseline without changing GPS acceptance, 50 m/30 s sharing, heartbeat timing, offline coalescing, or the `update_location` payload.

Inputs: motion changes, manager policy applications, rejected negative-accuracy fixes, heartbeat attempts with a known fix, actual location socket emits, offline location enqueue calls, and battery levels at session/transition boundaries. Outputs: in-memory counters and an aggregate Debug Pulse entry every 15 minutes while active, on backgrounding, and on stop.

State: one lock-protected session. `emitted` is grouped by `MotionActivity` at transport emit time, including offline replay; it is not server delivery. Battery deltas are only indicative, never a claim of causal energy savings. `reset` clears counters. Release methods are no-ops with no timer/observer.

Edge cases: repeated motion callbacks, unknown battery on Simulator, queued location coalescing, reconnect replay after motion state changed, app suspension before periodic log, and missing last fix on a heartbeat. Do not accept or log coordinates, tokens, user identifiers or raw socket payloads.
