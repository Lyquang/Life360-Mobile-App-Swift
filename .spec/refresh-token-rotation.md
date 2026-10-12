# Feature Spec: Refresh Token Rotation

Status: Approved for implementation
Owner: AI Agent
Last Updated: 2026-10-12

## Objective

Keep authenticated iOS 16 sessions usable after access-JWT expiry with one single-use refresh request per token generation.

## Inputs / Outputs

Input: auth token pair, protected REST 401, Socket.IO auth failure, explicit logout.
Output: atomic rotated token pair and one REST retry, or a typed recoverable/terminal session outcome.

## Modeled State

- UI: signed in, refreshing, recoverable error, signed out with one expiry notice.
- Data: absolute access-token expiry; current pair or legacy access-only item; in-flight refresh generation and rate-limit cooldown.
- Realtime: disconnected, connecting, connected with current Keychain access token.

## Architecture Path

`View -> ViewModel -> UseCase -> AuthRepository/APIClient -> shared refresh actor -> Keychain/SocketClient -> AppCoordinator`

## Edge Cases and Verification

- Concurrent 401, stale 401 after successful rotation, retry 401, legacy JWT, Keychain write failure.
- Refresh 401 INVALID/REUSED, 429 Retry-After, definite offline, ambiguous timeout/lost connection, 5xx.
- Logout with expired JWT or offline, late refresh after logout, Socket.IO reconnect with fresh token.
- XCTest in existing target when saved in project; networking/localization contracts, SwiftLint, unsigned Simulator build.

Detailed audit, approved defaults and stage criteria: `study/refresh-token-mobile-integration.md`.
