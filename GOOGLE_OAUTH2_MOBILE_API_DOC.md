# Google OAuth2 Mobile Login API Documentation

Tài liệu này mô tả riêng API đăng nhập Google OAuth2 để test trên Mobile app và Swagger/Postman.

## 1. Mục tiêu luồng đăng nhập

Mobile app không gửi password lên backend. Mobile app đăng nhập với Google trước, nhận **Google ID Token**, sau đó gửi ID Token về backend:

```txt
Mobile App
  -> Google Sign-In
  -> nhận idToken
  -> POST /api/v1/auth/social-login
  -> backend verify idToken với Google
  -> backend tạo/login user
  -> backend trả JWT của app
```

Quan trọng:

- Gửi **ID Token**, không gửi Access Token.
- `idToken.aud` phải khớp với `GOOGLE_CLIENT_ID` trên backend.
- ID Token thường hết hạn nhanh, nên mỗi lần test nên lấy token mới.

## 2. Base URL

| Environment | Base URL |
| --- | --- |
| Local | `http://localhost:3000/api/v1` |
| Production Render | `https://life360-backend-latest.onrender.com/api/v1` |

Swagger Production:

```txt
https://life360-backend-latest.onrender.com/api-docs
```

## 3. Backend Environment Required

Render service cần có env:

```env
GOOGLE_CLIENT_ID=<WEB_APPLICATION_CLIENT_ID>.apps.googleusercontent.com
```

Ví dụ:

```env
GOOGLE_CLIENT_ID=144558699513-xxxx.apps.googleusercontent.com
```

Sau khi thêm/sửa env trên Render:

```txt
Render Dashboard -> Environment -> Save Changes -> Manual Deploy
```

Nếu thiếu env này, API trả:

```json
{
  "success": false,
  "code": "SERVICE_UNAVAILABLE",
  "message": "Google OAuth is not configured."
}
```

## 4. Google Cloud Setup

Trong Google Cloud Console:

```txt
Google Auth Platform / APIs & Services -> Clients / Credentials
```

Cần có OAuth Client loại:

```txt
Web application
```

Client ID của Web application chính là giá trị dùng cho backend `GOOGLE_CLIENT_ID`.

### Android App

Nếu test bằng Android native, tạo thêm OAuth Client loại:

```txt
Android
```

Android client cần:

- Package name
- SHA-1 certificate fingerprint

Mobile app vẫn cần request ID token cho backend server client ID, tức Web Client ID.

### iOS App

Nếu test bằng iOS native, tạo thêm OAuth Client loại:

```txt
iOS
```

iOS client cần:

- Bundle ID, lấy trong Xcode:

```txt
Xcode -> Target -> Signing & Capabilities -> Bundle Identifier
```

Ví dụ:

```txt
com.yourcompany.life360
```

Mobile app vẫn cần lấy ID token có audience là Web Client ID backend.

## 5. API Contract

### Social Login

```http
POST /auth/social-login
```

Production full URL:

```txt
https://life360-backend-latest.onrender.com/api/v1/auth/social-login
```

Auth:

```txt
No Bearer token required
```

Headers:

| Header | Value |
| --- | --- |
| `Content-Type` | `application/json` |
| `Accept` | `application/json` |

Body:

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `provider` | String | Yes | Use `"google"` |
| `token` | String | Yes | Google ID Token from mobile client |

Request example:

```json
{
  "provider": "google",
  "token": "eyJhbGciOiJSUzI1NiIsImtpZCI6..."
}
```

`provider` enum currently accepts:

```txt
google | apple | facebook
```

But only `google` has an implemented provider adapter right now.

## 6. Success Response

HTTP `200`:

```json
{
  "success": true,
  "message": "Social login successful.",
  "data": {
    "user": {
      "name": "QUANG LY",
      "email": "quang@example.com",
      "avatar": "https://lh3.googleusercontent.com/a/...",
      "batteryLevel": 100,
      "isOnline": true,
      "lastSeenAt": null,
      "lastKnownLocation": {
        "type": "Point",
        "coordinates": null,
        "updatedAt": null,
        "durationMinutes": 0
      },
      "createdAt": "2026-10-10T08:00:00.000Z",
      "updatedAt": "2026-10-10T08:00:00.000Z",
      "id": "670000000000000000000001"
    },
    "token": "<app-jwt-access-token>",
    "accessToken": "<app-jwt-access-token>",
    "refreshToken": "<app-jwt-refresh-token>"
  }
}
```

Store this in mobile secure storage:

- iOS: Keychain
- Android: EncryptedSharedPreferences / Keystore-backed storage

Use `data.token` or `data.accessToken` for protected APIs:

```http
Authorization: Bearer <app-jwt-access-token>
```

## 7. Error Responses

### Missing Backend GOOGLE_CLIENT_ID

HTTP `503`:

```json
{
  "success": false,
  "code": "SERVICE_UNAVAILABLE",
  "message": "Google OAuth is not configured."
}
```

Fix:

- Add `GOOGLE_CLIENT_ID` on Render.
- Save changes.
- Redeploy service.

### Invalid Or Expired Google ID Token

HTTP `401`:

```json
{
  "success": false,
  "code": "UNAUTHORIZED",
  "message": "Invalid Google ID token."
}
```

Common causes:

- Sent `access_token` instead of `id_token`.
- ID token expired.
- `aud` in token does not match backend `GOOGLE_CLIENT_ID`.
- Token was copied with missing characters or extra whitespace.
- Render was not redeployed after env change.

### Email Not Verified

HTTP `401`:

```json
{
  "success": false,
  "code": "UNAUTHORIZED",
  "message": "Google account email is not verified."
}
```

### Validation Error

HTTP `400`:

```json
{
  "success": false,
  "code": "VALIDATION_ERROR",
  "message": "Validation failed.",
  "errors": [
    {
      "field": "body.provider",
      "message": "Invalid option: expected one of \"google\"|\"apple\"|\"facebook\""
    }
  ]
}
```

## 8. cURL Test

```bash
curl -X POST https://life360-backend-latest.onrender.com/api/v1/auth/social-login \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{
    "provider": "google",
    "token": "PASTE_GOOGLE_ID_TOKEN_HERE"
  }'
```

Expected:

- `200` if token is a valid Google ID token.
- `401` if token invalid/expired/audience mismatch.
- `503` if Render missing `GOOGLE_CLIENT_ID`.

## 9. Swagger Test

Open:

```txt
https://life360-backend-latest.onrender.com/api-docs
```

Find:

```txt
POST /api/v1/auth/social-login
```

Click:

```txt
Try it out
```

Body:

```json
{
  "provider": "google",
  "token": "PASTE_GOOGLE_ID_TOKEN_HERE"
}
```

Click:

```txt
Execute
```

## 10. Getting A Test ID Token Without Mobile App

Use OAuth 2.0 Playground only for quick manual testing.

### Google Cloud Redirect URI

In your Web application OAuth client, add:

```txt
https://developers.google.com/oauthplayground/
```

Note the trailing slash `/`.

### OAuth Playground Steps

1. Open:

```txt
https://developers.google.com/oauthplayground
```

2. Click Settings.
3. Enable:

```txt
Use your own OAuth credentials
```

4. Enter:

```txt
OAuth Client ID: <Web application Client ID>
OAuth Client secret: <Web application Client secret>
```

5. Scope must be exactly:

```txt
openid email profile
```

Do not enter words like `redirect`, `URIs`, or `Authorized` into the scope field.

6. Click `Authorize APIs`.
7. Login with Google.
8. Click `Exchange authorization code for tokens`.
9. Copy:

```txt
id_token
```

10. Send it to `/auth/social-login`.

## 11. Mobile Integration Notes

### iOS Conceptual Flow

1. Configure Google Sign-In SDK.
2. Configure app Bundle ID in Google Cloud iOS OAuth client.
3. Sign in with Google.
4. Read `idToken`.
5. Send `idToken` to backend.
6. Store backend JWT from response.

Pseudo Swift:

```swift
struct SocialLoginRequest: Encodable {
    let provider: String
    let token: String
}

struct APIResponse<T: Decodable>: Decodable {
    let success: Bool
    let message: String?
    let data: T?
    let code: String?
    let errors: [APIFieldError]?
}

struct APIFieldError: Decodable {
    let field: String?
    let message: String
}

struct AuthPayload: Decodable {
    let user: User
    let token: String
    let accessToken: String?
    let refreshToken: String?
}

struct User: Decodable {
    let id: String
    let name: String
    let email: String?
    let avatar: String?
    let isOnline: Bool?
}

func socialLoginWithGoogle(idToken: String) async throws -> AuthPayload {
    let url = URL(string: "https://life360-backend-latest.onrender.com/api/v1/auth/social-login")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.httpBody = try JSONEncoder().encode(
        SocialLoginRequest(provider: "google", token: idToken)
    )

    let (data, response) = try await URLSession.shared.data(for: request)
    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
    let decoded = try JSONDecoder().decode(APIResponse<AuthPayload>.self, from: data)

    guard (200..<300).contains(status), decoded.success, let payload = decoded.data else {
        throw NSError(
            domain: "SocialLogin",
            code: status,
            userInfo: [NSLocalizedDescriptionKey: decoded.message ?? "Login failed"]
        )
    }

    return payload
}
```

### Android Conceptual Flow

1. Configure Google Sign-In / Credential Manager.
2. Configure package name and SHA-1 in Google Cloud Android OAuth client.
3. Request ID token using backend Web Client ID.
4. Send ID token to backend:

```json
{
  "provider": "google",
  "token": "<id-token>"
}
```

5. Store `data.token` / `data.accessToken`.

## 12. Debug Checklist

If login fails:

### API returns 503

Check Render:

```txt
GOOGLE_CLIENT_ID exists?
No quotes?
No trailing spaces?
Service redeployed after env update?
```

### API returns 401

Decode the ID token payload and check:

```json
{
  "iss": "https://accounts.google.com",
  "aud": "<must equal backend GOOGLE_CLIENT_ID>",
  "email_verified": true,
  "exp": 1790000000
}
```

Checklist:

- `aud` equals `GOOGLE_CLIENT_ID`.
- Token is not expired.
- Token is `id_token`, not `access_token`.
- Token was generated by the same Google Cloud project/client setup.

### OAuth Playground says invalid scope

Use only:

```txt
openid email profile
```

### OAuth Playground redirect error

Authorized redirect URI must be:

```txt
https://developers.google.com/oauthplayground/
```

## 13. Backend Behavior Summary

On successful Google login:

1. Backend verifies Google ID token.
2. Backend extracts:

```json
{
  "provider": "google",
  "providerId": "Google sub",
  "email": "user@example.com",
  "name": "User Name",
  "avatarUrl": "https://lh3.googleusercontent.com/..."
}
```

3. Backend finds existing social account by `(provider, providerId)`.
4. If not found, backend finds user by email.
5. If user does not exist, backend creates a new user.
6. Backend links the Google account in `user_social_accounts`.
7. Backend updates profile name/avatar and marks user online.
8. Backend returns app JWT tokens.

