# P4 Location send policy

Goal: define and test a pure, framework-independent location send decision without changing runtime sharing behavior yet.

Inputs: `LocationFix`, optional last attempted send, optional pending point, injected `now`, Domain `MotionState`, and centralized per-state configuration. Output: `.send`, `.hold`, or `.drop`, each with an aggregate-safe reason.

Rules: first fix and motion transition send immediately. Otherwise enforce `minSendInterval`; meaningful points inside the interval replace pending. Dynamic distance is `clamp(speed * targetInterval, minDistance, maxDistance)` and movement requires distance at least `max(dynamicDistance, horizontalAccuracy)`. Negative speed is estimated from fix distance/time when timestamps increase. After the cap, movement, heartbeat age, or meaningful pending trailing edge can send.

P4A exposes current motion and an `AsyncStream<MotionState>` through `DeviceLocationRepository`, mapping Core `MotionActivity` in Data. P4B connects the policy to `ShareLocationUseCase`, schedules one cancellation-safe foreground trailing-edge task, reevaluates pending on the next background callback, and records aggregate Debug policy reasons. SOS and the socket payload remain unchanged.
