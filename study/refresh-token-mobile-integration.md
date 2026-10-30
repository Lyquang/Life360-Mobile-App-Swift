# Refresh Token Rotation - iOS Integration Study

Status: Approved and implemented in app code; XCTest target and device checks pending
Date: 2026-10-12
Source of truth: `api-docs/REFRESH_TOKEN_MOBILE_API_DOC.md`. The older Google OAuth2 document is useful for the Google ID-token flow but predates the new `expiresIn` contract.

## Objective and architecture

Keep a signed-in iOS 16 user connected when the 15-minute access JWT expires, while respecting the backend's strict, single-use 30-day refresh token. Use the existing Combine/MVVM-C code and one refresh coordinator shared by the app. The REST media-ticket request participates in refresh; the signed Cloudflare R2 PUT never does.

```text
Login/Register/Google ViewModel -> Auth UseCase -> AuthRepository -> APIClient
                                                  -> Keychain session (one token-pair item)
Protected API -> APIClient -> shared TokenRefreshCoordinator -> refresh transport
                                    |                   -> Keychain atomic update
                                    +-> one retry       -> Socket reconnect
Terminal session failure -> session lifecycle -> AppCoordinator -> Login
```

## Verified current state

- `URLSessionAPIClient` reads the access JWT from `AccessTokenProvider` for each protected request. On 401 (or an `UNAUTHORIZED` envelope) it can call an optional `AccessTokenRefreshing`, await an actor, then retry the original endpoint once. `AppContainer` does **not** pass a refresher, so the production app currently invalidates the sent JWT on 401. The actor currently returns only a `String`, does not write Keychain itself, and its `inFlight` lifetime depends on the initial caller awaiting the task. The API catch block converts every refresh failure into `APIError.unauthorized` and invalidates the sent token. It does not compare the sent JWT to a newer stored JWT before refresh.
- `KeychainStore.set` removes and re-adds each value without inspecting Security status. `KeychainSessionRepository` stores the JWT under `com.familytracker.jwt_token` and user ID/name/email in separate items. There is no stored refresh token or expiry. Its `invalidate(token:)` checks the JWT value, which protects a later login from deletion in one narrow race. The existing item uses `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` (despite the wrapper comment saying unlocked access).
- `AuthDataDTO` has optional `token`, `accessToken`, `refreshToken`, but no `expiresIn`. `AuthDataDTO.toDomain()` prefers deprecated `token` over `accessToken` and returns `AuthSession(user, token)` only. Login/register/Google use cases save that access JWT and connect the socket immediately. `SocialLoginRequestDTO.token` correctly carries the **Google ID token**; the response `token` is a different, deprecated backend JWT alias. No auth request sends `deviceName`.
- `SocketIOClientAdapter.connect(token:)` builds a `SocketManager` containing `.extraHeaders(Authorization)` and `.connectParams(token)`, then calls `connect(withPayload: [token])`. It reconnects with `.reconnects(true)` and keeps the original token in that manager. There is no session-aware reconnect or refresh callback. `SocketRealtimeRepository` forwards `connect(token:)`; it drains its in-memory offline queue after connection.
- `AppCoordinator.logout()` calls `AppContainer.logout()` synchronously, stops the main coordinator and shows Auth. `LogoutUseCase` stops location sharing, disconnects realtime and clears local Keychain. There is no backend logout, logout-all or change-password call. `ProfileView` has only a Logout action; no logout-all or password screen exists.
- `PulseDiagnostics.logHTTP` copies HTTP requests and responses into Pulse after `DiagnosticRedactor` redacts sensitive **JSON keys** and headers. Thus token fields are masked, but auth request/response bodies are still persisted in Debug and may contain other account data. `APIClient.logRequest` passes no body, but `logHTTP` receives the actual body. Release uses `NoopNetworkLogger`. Search found no production `print` or `os_log` of token values; current socket error payloads also pass through the redactor.
- Checked-in `FamilyTracker.xcodeproj/project.pbxproj` currently declares only the app `PBXNativeTarget`, and its shared scheme has an empty `TestAction`. `FamilyTrackerTests/DirectMessageFlowTests.swift` exists, but the saved project does **not** yet contain a discoverable `FamilyTrackerTests` target. This conflicts with the task's statement that the XCTest target exists; the planned tests can be written there, but `xcodebuild test` cannot execute until the owner saves/attaches that target. Do not edit `project.pbxproj` to create it.

## Contract-to-code gap analysis

| Contract | Existing code | Required change |
| --- | --- | --- |
| Auth success: `user`, `accessToken`, `refreshToken`, `expiresIn`, deprecated `token` | DTO has first three tokens but no `expiresIn`; mapper chooses `token` first | Decode `expiresIn`, prefer `accessToken`, calculate absolute expiry on receipt, require refresh token for new sessions; retain legacy alias decoding only for compatibility |
| Optional `deviceName` <= 100 characters on login/register/social-login only | None of the three request DTOs has it | Add nonpersonal model/iOS-version label in all three; omit from refresh |
| `POST /auth/refresh` with `{refreshToken}` and no Bearer | Endpoint/DTO/transport absent | Add auth endpoint plus dedicated transport that cannot enter auth interceptor |
| Refresh 200 replaces both tokens | One JWT item; `set` deletes then adds, ignores OSStatus | One Codable token-pair Keychain item, `SecItemUpdate` with `SecItemAdd` fallback, status checked; no mixed-generation pair |
| Expired legacy session still works until 401 | Old JWT item exists; no migration | Read new pair first, then old JWT as access-only. On legacy 401 show session-expired message and clear via common cleanup |
| Strict single-flight across app | Actor exists but not injected by composition root, returns String only | One shared actor; stale-token check; deterministic `inFlight` clearance after await; do not cancel shared refresh because one waiter cancels |
| 401 retry at most once | Existing retry cap exists | Keep cap; distinguish refresh errors from retry 401 and exclude public/auth endpoints |
| `INVALID_REFRESH_TOKEN` / `REFRESH_TOKEN_REUSED` | No typed handling | Clear session once, disconnect socket, notify root coordinator once |
| 429 with optional `Retry-After` | HTTP response header not preserved as retry metadata | Parse seconds/date, default 60 seconds plus jitter, store cooldown; no forced logout or automatic retry loop |
| Offline/DNS errors, timeout/lost connection, 5xx | All refresh errors collapse to unauthorized | Typed classification; preserve pair for recoverable errors; ambiguous policy awaits decision |
| Background atomicity | No iOS background task | Wrap refresh request and Keychain write in `beginBackgroundTask`/`endBackgroundTask`, handle expiration, no background proactive refresh |
| Logout current/all, change password | Local-only logout; no endpoints | Add request/response DTOs, repository operations, common session cleanup. Password change has no UI entry |
| Socket reads latest JWT at each connection | `SocketManager` caches token, auto-reconnect enabled | Token provider checked for each connect/reconnect; rebuild manager after rotation, stop reconnect on logout/terminal auth; avoid refresh/reconnect loop |
| Auth-body privacy | Pulse stores redacted JSON bodies | Omit entire auth request/response bodies and Authorization header before Pulse persistence/export; maintain Release no-op |
| Media 401 | `MediaUploadService` maps unauthorized to `refreshUnavailable` | Ticket request uses shared refresh; keep signed R2 PUT independent |

## Proposed design and trade-offs

### Token record and migration

Model `AuthTokens` as `Codable`/`Sendable`: `accessToken`, `refreshToken`, `expiresIn`, `accessTokenExpiresAt`. Compute the absolute expiry immediately on receipt. The persisted record stores both tokens and expiry together in one JSON Keychain item. User cache may remain separate, but failure to save tokens must abort authentication before coordinator routing; after a successful rotation followed by a failed Keychain write, force session cleanup and Login. Update the single item with `SecItemUpdate`, falling back to `SecItemAdd` only for `errSecItemNotFound`; check every OSStatus. Never delete the old item before a successful replacement. Keep `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, which matches the existing item and permits location wakeups after first unlock while avoiding migration to a more restrictive availability class. A device reboot before first unlock cannot access tokens; that is expected.

Legacy read: prefer the new JSON pair item; if absent, read `com.familytracker.jwt_token` as access-only. Do not fabricate a refresh token or derive expiry from that JWT. Remove the legacy item after a successful new login or complete cleanup. On a legacy-session 401, show the session-expired message and require login. Keep optional decode of the deprecated response `token` for old fixtures, but new authentication must use `accessToken` and require a real `refreshToken`/`expiresIn`; do not silently create a new access-only session.

### Shared refresh and response classification

Inject exactly one `TokenRefreshCoordinator` and one refresh transport from `AppContainer`. The actor compares the JWT sent on the 401 request with the current Keychain JWT. If different, it returns the newer access JWT for one retry. Otherwise it joins an existing in-flight task or creates one. The actor awaits the task, stores its outcome, then clears `inFlight` synchronously in its own isolated continuation guarded by a task/generation ID. It does not schedule a second `Task` merely to clear state. Multiple waiters never call `/refresh` with the same token. Cancellation of one HTTP request must not cancel the shared rotation needed by others. Explicit logout invalidates the session generation so a late refresh result cannot resurrect it.

The refresh transport bypasses the normal interceptor and sends no Bearer/deviceName. On success, atomically save the pair before any caller retries. Retry the original protected request once. An additional 401 stops; whether it means a revoked current session must be adjudicated once by the shared session lifecycle, without loops. Parse refresh errors by HTTP status, backend `code`, and `Retry-After`; never turn network/5xx/429 into logout. Certain pre-send `URLError` codes leave tokens intact. For timeout or connection loss, two reasonable policies remain: keep the pair and let a later refresh reveal reuse (better continuity but may eventually revoke the family), or sign out immediately (avoids a possible replay but forces login after a harmless timeout). The backend has no grace window or idempotency key, so neither choice can guarantee both uninterrupted login and family safety.

Do not refresh proactively by default; 401-triggered refresh limits token rotation and battery/network work. If approved later, only refresh while foreground and through the same actor. For 429, a per-session cooldown avoids repeated requests: honor `Retry-After` when present, otherwise 60 seconds plus bounded jitter. Present a recoverable message and preserve credentials.

### Session lifecycle, socket and privacy

Use one cleanup path for explicit logout and terminal session expiry. It stops location/realtime tasks, disables socket reconnect, clears Keychain and sensitive in-memory queue/cache, then publishes one root-level session-expired event where appropriate. `AppCoordinator` owns the transition to Login and localized alert. A Combine subscription uses `Set<AnyCancellable>` and `[weak self]`. Logout and logout-all make their backend request using the current access token with refresh interception disabled, then always clean locally in `defer`, including on 401/network failure. If the access JWT already expired, the backend family remains valid for up to 30 days; there is no safe mobile-only fix without a backend logout-by-refresh-token endpoint. Change-password only gets service/use-case integration until a UI choice is approved.

For realtime, rebuild the `SocketManager` with the latest Keychain access JWT on connect and after rotation. The Swift SDK serializes `connect(withPayload: ["token": jwt])` as the server's `handshake.auth.token`; no nested `auth` key is needed. Disable/tear down reconnect on logout or terminal session failure. A token-expired socket disconnect may ask the **same** actor for one refresh, then reconnect once; do not create an unbounded disconnect-refresh cycle. Do not proactively refresh while backgrounded. The R2 PUT continues to use only ticket-signed headers and URL.

`DiagnosticRedactor`/`PulseDiagnostics` should treat `/auth/*` as sensitive at the endpoint level: keep method/path/status/timing and safe response headers, but write neither request nor response body and no Authorization header. Protect Debug exports too. Do not persist a Google ID token, access token, refresh token, signed upload URL, or raw server auth error body in logs. Review any newly added error logging to ensure it cannot reintroduce those values.

## Backend confirmations

1. Refresh is strict single-use with no grace window. Reusing a rotated token returns `REFRESH_TOKEN_REUSED` and revokes the entire family, including the newly issued token. Backend has recorded the lost-response risk; 10-30-second idempotency-key support is future work.
2. Google uses `POST /api/v1/auth/social-login` with `provider: google`, `token: <Google ID token>`, and optional `deviceName` <= 100 characters.
3. `/auth/logout` requires a valid access JWT before considering the refresh token. Expired JWT returns 401 `UNAUTHORIZED`; local cleanup is still mandatory, while server revocation may fail.
4. Refresh rate limit defaults to 60 requests per 15 minutes per IP, configurable on Render. `Retry-After` in seconds appears only on 429.
5. `/auth/refresh` does not accept `deviceName`; rotation preserves it and updates user agent/IP.

Backend follow-ups outside this mobile task: verify Render `trust proxy` and CGNAT effects on IP-based rate limits; consider a family/token-hash limit; allow logout by refresh token; add short-lived idempotency keys for refresh. Do not change backend here.

## Execution Plan (approval required before Swift edits)

### G1 - Models, secure storage and diagnostics

Files: add `.spec/002-api-auth/references/refresh-token-rotation.md`; update `Domain/Entities/User.swift` or add a focused `AuthTokens.swift`, `Data/Network/DTOs/CoreDTOs.swift`, `Data/Network/DTOs/RequestDTOs.swift`, `Data/Network/Mappers/CoreMappers.swift`, `Data/Local/Keychain/KeychainStore.swift`, `Core/Logging/DiagnosticRedactor.swift`, and `Core/Logging/PulseDiagnostics.swift`. Add tests under `FamilyTrackerTests/` without creating a target. Completion: decoded auth pair and absolute expiry, atomic Keychain replacement with checked OSStatus, legacy access-only read, no auth bodies in Pulse. Test DTO fixtures, migration, simulated Keychain failure and redaction; build, lint and relevant contract suites.

### G2 - Single-flight and API interception

Files: `Data/Network/Endpoints/Endpoints.swift`, `Data/Network/TokenRefreshCoordinator.swift`, `Data/Network/APIClient.swift`, `Data/Network/Endpoint.swift`, dedicated refresh transport under `Data/Network/`, and `App/DI/AppContainer.swift`. Completion: one shared actor, stale-token retry, one refresh for concurrent 401s, original request retried once, explicit auth endpoint exclusions, typed 429/network/5xx outcomes and cooldown. URLProtocol/XCTest covers parallel requests, a completed refresh race, second 401, both terminal codes, 429 with/without header, listed URLError classes, 5xx, no Bearer/deviceName on refresh, and no Bearer on R2 PUT. Build/lint/contracts at stage end.

### G3 - Login, register, Google and migration lifecycle

Files: `Data/Repositories/RESTRepositories.swift`, auth request DTOs/endpoints, `Domain/Repositories/AuthRepository.swift`, `Domain/UseCases/Auth/AuthUseCases.swift`, `Data/Network/Mappers/CoreMappers.swift`, `App/DI/AppContainer.swift`. Completion: new login paths save the pair before navigation/socket connect; device name is <= 100 characters and contains no personal name; Google ID token is named distinctly; legacy session restores until 401. Test all three payloads, partial/failed Keychain save, expiry calculation and legacy fallback. Build/lint/contracts.

### G4 - Logout, logout-all and root UX

Files: auth endpoints/request DTOs/repository/use cases, `App/DI/AppContainer.swift`, `Presentation/Coordinators/AppCoordinator.swift`, `Presentation/Scenes/Profile/ProfileViewModel.swift`, `Presentation/Scenes/Profile/ProfileView.swift` only if approved, and both `Localizable.strings`. Completion: local cleanup always runs after logout failure; logout has no refresh loop; terminal refresh events route once to Login with localized message; queued work and sensitive caches are cleared. Change-password gets only API/use-case support unless UI is approved. Test logout/logout-all 401/offline and one-time expiry event. Build/lint/localization/contracts.

### G5 - Socket lifecycle, background boundary and verification

Files: `Core/Realtime/SocketIOClientAdapter.swift`, `Core/Realtime/SocketClient.swift`, `Data/Repositories/SocketRealtimeRepository.swift`, shared refresh service/background-task wrapper, `App/DI/AppContainer.swift`, `PROGRESS.md`, and `study/refresh-token-interview-notes.md`. Completion: refresh and Keychain write protected by a balanced iOS background task, socket reconnects with the current JWT and stops on logout/reuse, media ticket uses the shared refresh. Test socket reconnect/stop and background-task cleanup; run networking/localization scripts, SwiftLint, unsigned Simulator build and `xcodebuild test` once the target is saved in the project. Manual checks: concurrent API calls after 15 minutes, two-device logout-all, refresh during network loss, background resume, password change from another device and logout with an expired access JWT. Report each stage before advancing.

## Risks and required decisions

| Decision | Proposed choice | Trade-off / alternative |
| --- | --- | --- |
| Ambiguous refresh timeout or connection loss | Keep pair, surface recoverable error, never auto-retry | Later use of old token may trigger `REUSED` and revoke family; immediate Login avoids that replay but signs out on harmless timeouts |
| Proactive refresh | Disabled; react to 401 | Foreground pre-refresh at < 60 seconds may reduce visible latency but adds rotations and background/clock complexity |
| Logout-all UI | Add a compact confirmed action to existing Profile settings | Service-only is less UI work but leaves the endpoint undiscoverable |
| Change-password UI | Service/use case only for now | There is no existing screen; new UI is a separate user-facing feature |
| Keychain accessibility | Keep `AfterFirstUnlockThisDeviceOnly` | Matches existing background-location behavior; `WhenUnlockedThisDeviceOnly` would fail while locked |
| `deviceName` | Generic `iPhone/iPad + model identifier + iOS version`, truncate to 100 | More useful for session lists than `iPhone`; avoids personal device names. `UIDevice.name` is generic on iOS 16 without entitlement |
| Deprecated `token` response field | Decode optionally; never prefer it over `accessToken` | Preserves older fixtures; stricter rejection simplifies model but may break old responses |
| Logout with expired access JWT | Make one logout call, then local cleanup regardless of result | Refresh-then-logout can revoke server state but rotates credentials only to discard them and risks replay; backend logout-by-refresh is the durable fix |
| XCTest target mismatch | Owner saves/attaches existing `FamilyTrackerTests` target; no project edit by agent | Source files exist but `xcodebuild test` cannot discover them in the current saved project |

Approved decisions: preserve the token pair on an ambiguous network failure; refresh only
after 401; add logout-all to Profile; keep `AfterFirstUnlockThisDeviceOnly`; use a
nonpersonal device label; decode but do not use the deprecated response alias; perform
local cleanup after an expired-JWT logout. App code and standalone contract tests are
implemented. `xcodebuild test` remains blocked by the unsaved/absent XCTest target in
the checked-in project; device and live-backend scenarios are not yet verified.
