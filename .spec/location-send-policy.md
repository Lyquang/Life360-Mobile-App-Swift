# P4A Location send policy

Goal: define and test a pure, framework-independent location send decision without changing runtime sharing behavior yet.

Inputs: `LocationFix`, optional last attempted send, optional pending point, injected `now`, Domain `MotionState`, and centralized per-state configuration. Output: `.send`, `.hold`, or `.drop`, each with an aggregate-safe reason.

Rules: first fix and motion transition send immediately. Otherwise enforce `minSendInterval`; meaningful points inside the interval replace pending. Dynamic distance is `clamp(speed * targetInterval, minDistance, maxDistance)` and movement requires distance at least `max(dynamicDistance, horizontalAccuracy)`. Negative speed is estimated from fix distance/time when timestamps increase. After the cap, movement, heartbeat age, or meaningful pending trailing edge can send.

P4A also exposes current motion and an `AsyncStream<MotionState>` through `DeviceLocationRepository`, mapping Core `MotionActivity` in Data. It does not connect the policy to `ShareLocationUseCase`, schedule pending timers, alter P2 diagnostics, change SOS, change socket payloads, or change the existing 50 m/30 s behavior. Those items remain P4B and are not approved yet.
