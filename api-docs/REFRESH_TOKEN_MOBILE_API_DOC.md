# Refresh Token Rotation - Mobile API Contract

## 1. Tong quan

FamilyTracker dung hai token:

- `accessToken`: JWT song ngan, mac dinh 15 phut. Gui trong `Authorization: Bearer` va Socket.IO handshake.
- `refreshToken`: opaque random string song 30 ngay. Chi luu trong Keychain va chi gui den cac endpoint auth.

Refresh token la single-use. Moi lan refresh thanh cong, mobile phai ghi de ca access token va refresh token cu trong mot thao tac Keychain.

Field `token` la alias deprecated cua `accessToken`, chi ton tai de mobile cu khong bi vo.

## 2. Login, Register va Google Login

Ba endpoint sau deu tra cung token contract:

```text
POST /api/v1/auth/register
POST /api/v1/auth/login
POST /api/v1/auth/social-login
```

`deviceName` la optional, toi da 100 ky tu:

```json
{
  "email": "alice@example.com",
  "password": "secret123",
  "deviceName": "Alice iPhone 16 Pro"
}
```

Response:

```json
{
  "success": true,
  "data": {
    "user": { "id": "...", "name": "Alice", "email": "alice@example.com" },
    "token": "<same-value-as-accessToken>",
    "accessToken": "<jwt>",
    "refreshToken": "<opaque-random-string>",
    "expiresIn": 900
  }
}
```

Luu `accessToken`, `refreshToken` va user vao Keychain/storage truoc khi chuyen sang main flow.

## 3. Rotate Refresh Token

```http
POST /api/v1/auth/refresh
Content-Type: application/json
```

Khong gui Bearer token; access token co the da het han.

Request:

```json
{
  "refreshToken": "<current-refresh-token>"
}
```

Response `200`:

```json
{
  "success": true,
  "message": "Token refreshed successfully.",
  "data": {
    "token": "<new-access-token>",
    "accessToken": "<new-access-token>",
    "refreshToken": "<new-refresh-token>",
    "expiresIn": 900
  }
}
```

Ngay khi nhan response, token cu khong con dung duoc. Ghi de cap token trong Keychain theo kieu atomic.

### Error contract

`401 INVALID_REFRESH_TOKEN`:

```json
{
  "success": false,
  "code": "INVALID_REFRESH_TOKEN",
  "message": "Refresh token is invalid or expired."
}
```

`401 REFRESH_TOKEN_REUSED`:

```json
{
  "success": false,
  "code": "REFRESH_TOKEN_REUSED",
  "message": "Refresh token is no longer valid. Please sign in again."
}
```

Khi gap mot trong hai code tren, xoa token, disconnect Socket.IO va dua user ve Login.

`429 RATE_LIMITED`: khong loop retry; ton trong `Retry-After` neu co.

## 4. Single-flight bat buoc

Khong duoc de hai request cung refresh mot token. Backend strict single-use se xem request thu hai la replay va revoke toan bo device family.

Tat ca API request gap 401 phai cho cung mot refresh task:

```swift
actor TokenRefreshCoordinator {
    private var inFlight: Task<AuthTokens, Error>?
    private let authAPI: AuthAPI
    private let keychain: KeychainStore

    func validTokensAfterUnauthorized() async throws -> AuthTokens {
        if let inFlight { return try await inFlight.value }

        let task = Task<AuthTokens, Error> {
            defer { Task { await self.clearInFlight() } }
            let current = try keychain.readTokens()
            let response = try await authAPI.refresh(refreshToken: current.refreshToken)
            try keychain.replaceTokensAtomically(response)
            return response
        }
        inFlight = task
        return try await task.value
    }

    private func clearInFlight() {
        inFlight = nil
    }
}
```

Interceptor flow:

1. API tra 401 do access token het han.
2. Goi `TokenRefreshCoordinator` mot lan.
3. Cac request 401 khac await cung task.
4. Refresh thanh cong: retry moi original request toi da mot lan voi access token moi.
5. Refresh that bai: logout. Khong retry `/auth/refresh` tu dong.

## 5. Logout

### Current device

```http
POST /api/v1/auth/logout
Authorization: Bearer <accessToken>
```

```json
{
  "refreshToken": "<current-refresh-token>"
}
```

Backend blacklist access token, revoke toan bo family cua refresh token va ngat Socket cua thiet bi. Mobile van phai xoa Keychain ke ca khi request logout that bai do mat mang.

### All devices

```http
POST /api/v1/auth/logout-all
Authorization: Bearer <accessToken>
```

Khong can body. Tat ca token families bi revoke va moi socket cua user bi ngat.

## 6. Change Password

```http
POST /api/v1/auth/change-password
Authorization: Bearer <accessToken>
Content-Type: application/json
```

```json
{
  "currentPassword": "secret123",
  "newPassword": "newSecret456"
}
```

Thanh cong se revoke moi session. Mobile xoa Keychain va chuyen ve Login.

## 7. Codable Models

```swift
struct AuthTokens: Codable, Sendable {
    let token: String
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
}

struct RefreshTokenRequest: Encodable {
    let refreshToken: String
}

struct APIEnvelope<T: Decodable>: Decodable {
    let success: Bool
    let message: String?
    let data: T
}

struct APIErrorEnvelope: Decodable, Error {
    let success: Bool
    let code: String
    let message: String
}
```

## 8. Socket.IO

Sau khi rotate:

1. Disconnect socket dang dung access token cu.
2. Cap nhat token trong Socket.IO config.
3. Connect lai voi:

```swift
["auth": ["token": tokens.accessToken]]
```

Khi nhan disconnect sau logout/reuse, khong auto-connect vo han. Kiem tra auth state/Keychain truoc khi reconnect.

## 9. Security Checklist

- Chi luu refresh token trong Keychain, khong luu UserDefaults.
- Khong log access token, refresh token hay request body auth.
- Khong decode refresh token; no la opaque string, khong phai JWT.
- Ghi de cap token cung luc, khong chi thay access token.
- Retry original API toi da mot lan sau refresh.
- Dung single-flight actor cho toan app, khong tao rieng theo tung repository.
