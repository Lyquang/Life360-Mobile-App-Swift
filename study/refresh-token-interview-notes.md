# Refresh Token Rotation - iOS Interview Notes

## The engineering problem

The access JWT expires after about 15 minutes; the refresh token is an opaque, single-use credential valid for about 30 days. A refresh response invalidates the previous refresh token immediately. If Map, Chat and Places each refresh independently after a simultaneous 401, the backend can classify the second use as replay and revoke the whole device family.

## Design choices and trade-offs

- **Single-flight actor:** `TokenRefreshCoordinator` owns one in-flight network task for the app. Every protected 401 waits for that result. It compares the access token sent by the failed request with the current Keychain token first: a stale 401 simply retries once with the new token. A session-generation number prevents an old account's request from borrowing a different account's token. A flight ID prevents late waiters from clearing a newer flight.
- **One atomic Keychain item:** both tokens and the absolute access expiry are encoded in one value and replaced with `SecItemUpdate` or initially added with `SecItemAdd`. There is no intermediate state with a new access token and old refresh token. `AfterFirstUnlockThisDeviceOnly` allows background location access after the first unlock and does not synchronize credentials to other devices. A legacy access-only item can be used until its first 401.
- **Failure policy:** `INVALID_REFRESH_TOKEN`/`REFRESH_TOKEN_REUSED` and failed Keychain persistence end the local session. 429 starts a cooldown; definite offline and 5xx preserve the token pair. Timeout/connection loss also preserve it without an automatic retry, because the request may have reached the backend. With strict single-use and no server idempotency key, a later retry might return `REUSED`; immediate logout would avoid that replay at the cost of signing out users after harmless timeouts.
- **Bounded retry:** only a protected backend REST request can invoke refresh, and its original request is retried once. `/auth/refresh` uses its own transport with no Bearer. Login, register and logout do not refresh themselves. The Cloudflare R2 PUT uses only its signed URL and returned headers.
- **Socket.IO:** the adapter reads the latest Keychain access JWT for each new connection and rebuilds the manager after rotation. In the Swift SDK, `connect(withPayload: ["token": jwt])` becomes the server's `handshake.auth.token`; wrapping it in another `auth` key would be incorrect. An auth failure asks the shared actor once for that token; terminal failure disables reconnect. Offline events are cleared when the session ends so they cannot be replayed under another account.
- **iOS background limit:** `beginBackgroundTask` covers network refresh and the Keychain replacement. It does not guarantee unlimited runtime; iOS may still expire the task. There is no proactive background refresh.
- **Logout:** the app attempts server revocation, then always clears local credentials and socket/location state. If the access JWT already expired, the backend rejects `/auth/logout` before it can revoke the refresh family; the Login screen reports that server revocation was unconfirmed. Logout-all is available in Profile. Password-change transport/use case exists, but there is no password-change screen.
- **Privacy:** Pulse retains method/path/status/timing for auth requests, with both auth bodies omitted and Authorization redacted. Release uses the no-op logger. Google ID token stays distinct from the backend access JWT and never goes to Keychain as the app session.

## Example STAR answer

**Situation:** Several feature requests could receive 401 together after a 15-minute JWT expired. The backend's refresh token is single-use.

**Task:** Restore all pending requests without reusing that refresh token or leaking tokens in diagnostics.

**Action:** I put refresh behind one actor, compared each failed request's JWT with the current Keychain value, stored the rotated pair in one Keychain item, and retried each request once. I kept 429/network errors recoverable, ended the session on terminal backend codes, and reconnected Socket.IO with the new JWT. I also omitted auth bodies from Pulse.

**Result:** Concurrent requests share one rotation and avoid replay-triggered family revocation. Contract tests cover single-flight, stale 401, terminal codes, cooldown, network classification, storage failure, media-ticket retry and auth-body redaction. Device-level and XCTest-target verification still require the project test target and live backend accounts.
