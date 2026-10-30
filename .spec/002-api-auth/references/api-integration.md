# API Integration

Status: Phase 1 complete; phases 2 and 3 pending
Updated: 2026-10-02
Contract: `API_INTERGRATION.MD` (actual repository filename).

## Scope And Sequence

1. Endpoints, Codable request/response DTOs, authenticated transport and typed errors.
2. Repository-backed services and use cases registered in AppContainer.
3. Presentation state, pagination, upload and map/history integration.

This task implements phase 1 as requested. Keep networking in Data/Network,
KeychainSessionRepository as token provider, and DomainError as the domain boundary.
No duplicate Core/Networking or direct service dependencies in Views/ViewModels.

## REST Inventory

Paths are relative to /api/v1. All require Bearer auth except auth register,
login, social-login and health. JSON requests use Accept and Content-Type.

| Module | Method | Path | Query/body |
| --- | --- | --- | --- |
| Auth | POST | /auth/register | name, email, password |
| Auth | POST | /auth/login | email, password |
| Auth | POST | /auth/social-login | provider=google, token (ID token) |
| Auth | GET | /auth/me | - |
| Groups | POST | /groups | name |
| Groups | GET | /groups | - |
| Groups | POST | /groups/join | inviteCode: six digits, retain leading zeros |
| Groups | GET | /groups/{groupId}/members | - |
| Groups | PATCH | /groups/{groupId}/notification-interval | intervalMinutes: 0...1440 |
| Places | GET | /groups/{groupId}/places | - |
| Places | POST | /groups/{groupId}/places | name, category, latitude, longitude |
| Digests | GET | /groups/{groupId}/digests | page, limit, from?, to? |
| Digests | GET | /groups/{groupId}/digests/latest | - |
| Chat | GET | /conversations | - |
| Chat | GET | /conversations/{conversationId} | - |
| Chat | POST | /conversations/direct | userId |
| Chat | PATCH | /conversations/{conversationId} | name?, avatarUrl? (null clears) |
| Chat | GET | /conversations/{conversationId}/messages | limit: 1...100, before? |
| Chat | POST | /conversations/{conversationId}/messages | type, content?, attachmentUrl?, metadata? |
| Chat | POST | /conversations/{conversationId}/read | messageId? |
| Chat | GET | /conversations/{conversationId}/unread | - |
| Chat | GET | /conversations/unread-summary | - |
| Chat | POST | /chat/upload-ticket | conversationId, contentType, contentLength |
| History | GET | /history/{userId} | today only; no documented date query |
| History | GET | /history/{userId}/journey | date? YYYY-MM-DD, server Asia/Ho_Chi_Minh |
| Health | GET | /health | public /api/v1/health |

The alternative /api/health is outside the versioned base URL. Object-storage
PUT uses the ticket URL and returned headers through the existing ImageUploader,
without forwarding the backend Bearer token. No refresh endpoint is documented.

## Inputs, Outputs And State

Input: typed endpoint requests plus Keychain access token.
Output: Codable DTOs or APIError mapped to DomainError by repositories.
Transport state: request -> response -> HTTP/envelope validation -> decoding.
401 invalidates only the token used by that request, never a later login token.
Cancellation stays cancellation. A missing protected token fails before I/O.
ViewModel/navigation state is deferred to phase 3.

## Edge Cases

- Offline/timeout, non-JSON errors, 400/401/403/404/409/429/503, success=false.
- Field validation errors retain code, status and field messages.
- ID or populated-user relations, missing optional fields, null latest digest.
- Cursor pagination metadata lives at the response root, as does journey.
- Avatar patch distinguishes omission, null, and an explicit value.
- Date strings preserve fractional ISO timestamps for existing domain mappers.
- GPS denied/reduced accuracy does not block REST reads; platform behavior stays
  with location services and later presentation integration.

## Verification

- Decode documented JSON response examples and encode typed requests.
- Stub URLSession using URLProtocol: headers/auth, errors, cancellation, invalidation.
- Compile networking contract tests and attempt an unsigned simulator build.
- Record results and remaining phase 2/3 work in PROGRESS.md.

Results: `bash scripts/test_networking.sh` passes, including all 26 documented
REST response examples and stubbed URLSession transport checks. The unsigned
generic iOS Simulator Debug build also passes (Xcode 26.2). Live backend/account
flows are not tested in this phase.
