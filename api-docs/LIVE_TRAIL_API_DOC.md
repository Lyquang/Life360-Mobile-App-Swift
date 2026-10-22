# Live Trail REST + Socket.IO API - Mobile Contract

Trạng thái hiện tại: persistence, REST snapshot/catch-up, Socket.IO watch/delta và privacy/member-removal hooks đã có. Production giữ `LIVE_TRAIL_ENABLED=false` cho đến khi hoàn tất MongoDB/Socket.IO load gates.

## 1. Endpoint

```http
GET /api/v1/history/{userId}/journey/trail
Authorization: Bearer <accessToken>
```

Requester chỉ được đọc chính mình hoặc một user có chung Circle.

| Query | Bắt buộc | Quy tắc |
| --- | --- | --- |
| `date` | Không | `YYYY-MM-DD` theo timezone server; mặc định ngày hiện tại |
| `afterSeq` | Không | Integer >= 0; lấy insertion events có `seq` lớn hơn cursor |
| `revision` | Có khi dùng `afterSeq` | Integer >= 1; phải khớp revision hiện tại |
| `limit` | Không | Mặc định 200, tối đa 500 |

Snapshot đầu tiên:

```http
GET /api/v1/history/USER_ID/journey/trail?date=2026-10-18&limit=200
```

Trang tiếp theo/catch-up:

```http
GET /api/v1/history/USER_ID/journey/trail?date=2026-10-18&afterSeq=200&revision=4&limit=200
```

## 2. Response thành công

```json
{
  "success": true,
  "trailId": "671234567890abcdef012345",
  "userId": "661234567890abcdef012345",
  "date": "2026-10-18",
  "timeZone": "Asia/Ho_Chi_Minh",
  "revision": 4,
  "lastSeq": 203,
  "points": [
    {
      "seq": 201,
      "latitude": 10.762622,
      "longitude": 106.660172,
      "recordedAt": "2026-10-18T05:03:20.000Z",
      "accuracy": 8,
      "motionState": "walking",
      "pointId": "ca05768a-9774-4e29-832e-70048a95901e"
    }
  ],
  "gaps": [
    {
      "fromSeq": 201,
      "toSeq": 199,
      "seconds": 240,
      "meters": 530.4
    }
  ],
  "matched": [],
  "hasMore": false,
  "nextAfterSeq": null
}
```

## 3. Ordering và cursor

- `seq` là insertion cursor tăng đơn điệu, không phải thứ tự đường đi.
- Mỗi REST page trả `points` theo `seq` tăng dần.
- Sau khi tải đủ pages, mobile dựng path bằng cách sort `(recordedAt, seq)`.
- Late point có thể có `seq` lớn nhưng `recordedAt` nằm giữa các point cũ.
- Không kiểm tra mất event bằng `seq == previousSeq + 1`; future migration/transaction retry có thể tạo lỗ. Dùng `afterSeq` và `revision`.
- `nextAfterSeq` chỉ có giá trị khi `hasMore=true`. Khi `hasMore=false`, cursor local mới nhất là `points.last?.seq ?? afterSeq`.

## 4. Gap semantics

- Gap dùng boundary ổn định `fromSeq/toSeq`, không dùng array index.
- Gap được tính theo path order `(recordedAt, seq)`, nên `fromSeq` có thể lớn hơn `toSeq` sau late insertion.
- Interval vượt `gapThresholdSeconds` chỉ là route gap khi hai đầu xa hơn stay radius.
- Khoảng im lặng tại cùng khu vực không được trả như gap để mobile không vẽ stay thành đường đứt.
- T1b trả gap set của toàn trail trên mỗi page. Mobile nên merge/dedupe bằng `(fromSeq,toSeq)`.
- `matched` cũng là tập match của toàn revision hiện tại và được trả lại trên mỗi page. Mobile upsert/dedupe bằng `segmentId`; không append mù theo page.

## 5. Revision conflict

Nếu server nhận late point, revision tăng. Request dùng revision cũ trả:

```http
HTTP/1.1 409 Conflict
```

```json
{
  "success": false,
  "code": "TRAIL_REVISION_CHANGED",
  "message": "Trail revision changed. Reload the snapshot before applying more points.",
  "data": {
    "trailId": "671234567890abcdef012345",
    "currentRevision": 5,
    "lastSeq": 206
  }
}
```

Mobile phải xóa geometry/cache của revision cũ và tải lại từ trang đầu. Không tiếp tục áp response catch-up cũ.

## 6. HTTP errors

| HTTP | Code | Xử lý mobile |
| --- | --- | --- |
| 400 | `VALIDATION_ERROR` | Sửa query; `afterSeq` bắt buộc có `revision` |
| 401 | `UNAUTHORIZED` | Dùng refresh flow single-flight rồi retry một lần |
| 403 | `FORBIDDEN` | Dừng xem trail; user không còn quyền Circle |
| 404 | `NOT_FOUND` | Ngày đó chưa có trail; hiển thị trạng thái rỗng |
| 409 | `TRAIL_REVISION_CHANGED` | Xóa snapshot local và tải lại từ đầu |
| 429 | `RATE_LIMITED` | Tôn trọng `Retry-After`, backoff có jitter |
| 503 | `SERVICE_UNAVAILABLE` | Feature đang tắt; fallback sang journey/history hiện có |

## 7. Swift models

```swift
struct LiveTrailResponse: Decodable, Sendable {
    let success: Bool
    let trailId: String
    let userId: String
    let date: String
    let timeZone: String
    let revision: Int
    let lastSeq: Int
    let points: [LiveTrailPoint]
    let gaps: [LiveTrailGap]
    let matched: [LiveTrailMatch]
    let hasMore: Bool
    let nextAfterSeq: Int?
}

struct LiveTrailPoint: Decodable, Identifiable, Sendable {
    var id: Int { seq }
    let seq: Int
    let latitude: Double
    let longitude: Double
    let recordedAt: Date
    let accuracy: Double?
    let motionState: String?
    let pointId: UUID?
}

struct LiveTrailGap: Decodable, Hashable, Sendable {
    let fromSeq: Int
    let toSeq: Int
    let seconds: Double
    let meters: Double
}

struct LiveTrailMatch: Decodable, Sendable {
    let segmentId: String
    let fromSeq: Int
    let toSeq: Int
    let status: LiveTrailMatchStatus
    let geometry: LiveTrailMatchGeometry?
    let matcher: LiveTrailMatcher
    let confidence: Double?
    let sourceRevision: String
    let generatedAt: Date
}

enum LiveTrailMatchStatus: String, Decodable, Sendable {
    case provisional
    case final
    case unmatched
}

struct LiveTrailMatchGeometry: Decodable, Sendable {
    let encoding: String // "polyline6"
    let data: String
}

struct LiveTrailMatcher: Decodable, Sendable {
    let provider: String
    let version: String
}
```

## 8. Mobile loading algorithm

1. Gọi trang đầu không có `afterSeq`; lưu `trailId` và `revision`.
2. Trong khi `hasMore=true`, gọi tiếp với `afterSeq=nextAfterSeq` và cùng revision.
3. Nếu nhận 409, hủy vòng tải hiện tại, xóa snapshot revision cũ và quay lại bước 1.
4. Merge point theo `seq`, merge gap theo `(fromSeq,toSeq)`.
5. Sort point `(recordedAt,seq)` trước khi dựng polyline.
6. Không nối đường liền qua cặp seq có trong `gaps`.
7. Sau khi có snapshot, đăng ký `journey:watch`; áp delta chỉ khi revision và `afterSeq` khớp local state.

## 9. Socket watch

Kết nối Socket.IO bằng access token như các event hiện có và chờ `session:ready`. Sau đó emit:

```json
{
  "event": "journey:watch",
  "payload": {
    "userId": "661234567890abcdef012345",
    "date": "2026-10-18"
  }
}
```

Ack thành công chỉ trả metadata; mobile vẫn lấy point bằng REST:

```json
{
  "ok": true,
  "trailId": "671234567890abcdef012345",
  "userId": "661234567890abcdef012345",
  "date": "2026-10-18",
  "revision": 4,
  "lastSeq": 203
}
```

Ack lỗi:

```json
{
  "ok": false,
  "status": 403,
  "code": "FORBIDDEN",
  "message": "You can only watch live trails of yourself or members of your groups."
}
```

Một socket được watch tối đa 5 trail. `watch` và `unwatch` dùng chung giới hạn mặc định 30 action/phút/socket.

Hủy watch:

```json
{
  "event": "journey:unwatch",
  "payload": {
    "userId": "661234567890abcdef012345",
    "date": "2026-10-18"
  },
  "ack": { "ok": true, "removed": true }
}
```

## 10. Server events

### `journey:trail_delta`

```json
{
  "userId": "661234567890abcdef012345",
  "trailId": "671234567890abcdef012345",
  "revision": 4,
  "afterSeq": 203,
  "fromSeq": 205,
  "toSeq": 207,
  "points": [
    {
      "seq": 205,
      "latitude": 10.762622,
      "longitude": 106.660172,
      "recordedAt": "2026-10-18T05:04:00.000Z",
      "accuracy": 8,
      "motionState": "walking",
      "pointId": "ca05768a-9774-4e29-832e-70048a95901e"
    }
  ],
  "matchedUpdates": [
    {
      "segmentId": "ryImN8kQnHDy0R7gN5Zt5fba",
      "fromSeq": 201,
      "toSeq": 205,
      "status": "provisional",
      "geometry": { "encoding": "polyline6", "data": "<encoded>" },
      "matcher": { "provider": "fake", "version": "fake-v1" },
      "confidence": 0.99,
      "sourceRevision": "sha256-base64url",
      "generatedAt": "2026-10-19T03:00:00.000Z"
    }
  ]
}
```

`afterSeq=203` là cursor ngay trước delta dù `fromSeq` có thể là 205. Không yêu cầu seq liền kề. Chỉ apply khi `revision` bằng local revision và `afterSeq` bằng local insertion cursor; nếu không, gọi REST catch-up hoặc reload.

Server gom tối đa 2 giây và giới hạn mặc định 50 point/64 KB mỗi delta. Matcher chạy bất đồng bộ: kết quả có thể được gộp vào delta đang chờ, hoặc đến trong một delta có `points=[]` và `afterSeq` bằng cursor hiện tại. Mobile upsert match bằng `segmentId`; `provisional` có thể được thay thế, `final` là ổn định trong cùng revision, `unmatched` phải tiếp tục vẽ raw points. Nếu một geometry đơn lẻ vượt byte cap, server không gửi payload quá cỡ mà phát `journey:trail_reset`; mobile tải lại REST snapshot.

T3 chưa cấu hình provider đường bộ thật. Production mặc định matcher tắt/Noop; `fake` chỉ xuất hiện trong test hoặc staging có chủ đích và bị server từ chối khi `NODE_ENV=production`.

### `journey:trail_reset`

```json
{
  "userId": "661234567890abcdef012345",
  "trailId": "671234567890abcdef012345",
  "revision": 5
}
```

Late realtime point hoặc offline batch làm canonical ordering có thể đổi. Mobile phải bỏ snapshot revision cũ và tải lại REST từ đầu. Khi live trail bật, late point và offline batch không được phát thành current `location_update` hay delta cũ.

### `journey:trail_closed`

```json
{
  "userId": "661234567890abcdef012345",
  "trailId": "671234567890abcdef012345",
  "reason": "permission_revoked"
}
```

Reason hiện có:

| Reason | Ý nghĩa |
| --- | --- |
| `permission_revoked` | Lease kiểm tra thấy requester không còn chung Circle |
| `sharing_paused` | Target đã tạm dừng chia sẻ vị trí toàn tài khoản |
| `trail_expired` | Trail bị xóa/hết retention hoặc identity không còn khớp |

Privacy và Circle membership mutations đóng watch ngay; lease 60 giây vẫn là fallback nếu realtime hook lỗi.

## 11. Mobile recovery algorithm

1. Tải đầy đủ REST snapshot và giữ `revision`, insertion cursor cuối cùng.
2. Emit `journey:watch`; nếu ack metadata mới hơn snapshot, gọi REST catch-up.
3. Với delta đúng revision + `afterSeq`, merge theo `seq`, cập nhật cursor rồi sort path theo `(recordedAt, seq)`.
4. Delta không nối được cursor: không đoán point bị mất; gọi REST với local `afterSeq` và revision.
5. Nhận reset hoặc HTTP 409: xóa revision cũ và tải snapshot từ trang đầu.
6. Nhận closed: ngừng watch và dừng hiển thị dữ liệu live của target.
7. Reconnect Socket.IO: chờ `session:ready`, catch-up REST trước rồi watch lại; watch registry không tồn tại qua disconnect.

## 12. Trạng thái rollout

- Privacy pause và Circle leave/remove hooks đã có. Production vẫn giữ `LIVE_TRAIL_ENABLED=false` và `LIVE_TRAIL_MATCHER_ENABLED=false` cho đến khi MongoDB/Socket.IO load gates được xác nhận.
- `LIVE_TRAIL_MATCHER_PROVIDER=fake` chỉ dành cho test/staging và bị từ chối trong `NODE_ENV=production`.
- Khi feature được duyệt, bật raw live trail trên staging trước; matcher vẫn tắt để đánh giá đường GPS thật trên thiết bị.
- Trước production phải xác nhận MongoDB deployment hỗ trợ transaction/replica set, index đã tạo, quota đủ và đo tải qua MongoDB + Socket.IO thật.
- Rollback raw trail bằng `LIVE_TRAIL_ENABLED=false`. Luồng `location_update`, batch offline và history hiện tại vẫn hoạt động vì projection/publisher fail-soft.
