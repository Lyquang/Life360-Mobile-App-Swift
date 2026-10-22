# Journey Route and Location History API - iOS Contract

Tài liệu này mô tả hai API đọc lịch sử vị trí dành cho iOS. Cả hai yêu cầu access JWT và chỉ cho phép xem chính mình hoặc thành viên có chung ít nhất một Circle.

## 1. Authentication

```http
Authorization: Bearer <accessToken>
Accept: application/json
```

| HTTP | Code | Ý nghĩa |
| --- | --- | --- |
| `400` | `VALIDATION_ERROR` / `BAD_REQUEST` | Query, cursor hoặc khoảng thời gian không hợp lệ |
| `401` | `UNAUTHORIZED` | Access token thiếu, sai hoặc hết hạn |
| `403` | `FORBIDDEN` | Không phải chính mình và không chung Circle |

## 2. Journey theo ngày

### Legacy mode

```http
GET /api/v1/history/{userId}/journey?date=2026-10-17
```

Không truyền `detail` sẽ giữ nguyên response cũ. Moving segment có `path` chỉ gồm tọa độ; không có gap metadata.

### Geometry mode cho mobile mới

```http
GET /api/v1/history/{userId}/journey?date=2026-10-17&detail=geometry
```

`date` là `YYYY-MM-DD`, mặc định hôm nay theo timezone server. `detail` chỉ chấp nhận `geometry`.

| Query | Bắt buộc | Quy tắc |
| --- | --- | --- |
| `date` | Không | Ngày lịch `YYYY-MM-DD` theo `timeZone` của response |
| `detail` | Có với contract mới | Giá trị duy nhất là `geometry` |
| `includePath` | Không | Boolean `true`/`false`, mặc định `true`; chỉ hợp lệ cùng `detail=geometry` |

Mobile mới nên gọi phiên bản gọn để không nhận hai bản sao tọa độ:

```http
GET /api/v1/history/{userId}/journey?date=2026-10-17&detail=geometry&includePath=false
```

```json
{
  "success": true,
  "date": "2026-10-17",
  "userId": "66f123456789abcdef012345",
  "timeZone": "Asia/Ho_Chi_Minh",
  "geometryPolicy": {
    "version": 2,
    "gapThresholdSeconds": 180,
    "gapIndexSpace": "points",
    "toBoundary": "inclusive",
    "stayRadiusMeters": 80,
    "minStayMinutes": 5
  },
  "summary": {
    "totalPoints": 4,
    "stayPointCount": 0,
    "totalStayMinutes": 0,
    "totalMovingMinutes": 6,
    "observedMovingSeconds": 90,
    "observedStaySeconds": 0,
    "unobservedSeconds": 300,
    "firstSeenAt": "2026-10-17T01:00:00.000Z",
    "lastSeenAt": "2026-10-17T01:06:00.000Z"
  },
  "journey": [
    {
      "type": "moving",
      "segmentId": "v1_9M3lYQ0nP5x7mZr4F2dA1B",
      "fromLatitude": 10.7,
      "fromLongitude": 106.6,
      "toLatitude": 10.703,
      "toLongitude": 106.603,
      "startTime": "2026-10-17T01:00:00.000Z",
      "endTime": "2026-10-17T01:06:00.000Z",
      "durationMinutes": 6,
      "durationFormatted": "6 phút",
      "path": [
        { "latitude": 10.7, "longitude": 106.6 },
        { "latitude": 10.701, "longitude": 106.601 },
        { "latitude": 10.702, "longitude": 106.602 },
        { "latitude": 10.703, "longitude": 106.603 }
      ],
      "points": [
        { "latitude": 10.7, "longitude": 106.6, "recordedAt": "2026-10-17T01:00:00.000Z", "accuracy": 5 },
        { "latitude": 10.701, "longitude": 106.601, "recordedAt": "2026-10-17T01:00:30.000Z", "accuracy": 5 },
        { "latitude": 10.702, "longitude": 106.602, "recordedAt": "2026-10-17T01:05:30.000Z", "accuracy": 6 },
        { "latitude": 10.703, "longitude": 106.603, "recordedAt": "2026-10-17T01:06:00.000Z", "accuracy": 6 }
      ],
      "pointCount": 4,
      "originalPointCount": 4,
      "distanceMeters": 468.2,
      "maxGapSeconds": 300,
      "gaps": [{ "fromIndex": 1, "toIndex": 2, "seconds": 300, "meters": 156.1 }],
      "thinned": false,
      "observedMovingSeconds": 90
    }
  ]
}
```

### Quy tắc vẽ trên iOS

- Vẽ đường liền giữa các cặp điểm không nằm trong `gaps`.
- Với mỗi gap, dùng `fromIndex` và `toIndex` để vẽ nét đứt hoặc không nối tùy UX.
- `points` đã tăng dần theo `recordedAt`; không nội suy hay tự tạo tọa độ bị thiếu.
- `distanceMeters` được tính trên điểm gốc trước thinning. Không cộng lại từ `points` nếu cần số liệu chính xác.
- `totalMovingMinutes` giữ semantics cũ, có thể chứa khoảng mất dữ liệu. Dùng `observedMovingSeconds` cho thời gian thực sự quan sát được.
- `segmentId` ổn định cho cùng segment và phù hợp làm identity trong SwiftUI.
- `path` và `points` có cùng chuỗi tọa độ khi `includePath` không được truyền hoặc bằng `true`. Mobile mới nên dùng `points` và gửi `includePath=false`.
- `gaps[].fromIndex/toIndex` luôn tham chiếu mảng `points` được trả, sau thinning. Nếu client gặp index ngoài mảng, bỏ riêng gap lỗi và không crash.
- Interval dài hơn `gapThresholdSeconds` chỉ là route gap khi hai biên xa hơn `stayRadiusMeters`. Nếu vẫn trong bán kính stay, backend giữ nó như một stay suy luận.
- `unobservedSeconds` gồm cả route gap và khoảng im lặng same-region; không đồng nghĩa toàn bộ thời gian đó là di chuyển.

### Stay segment

```json
{
  "type": "stay",
  "segmentId": "v1_M3lYQ0nP5x7mZr4F2dA1Bc",
  "latitude": 10.7,
  "longitude": 106.6,
  "arrivedAt": "2026-10-17T02:00:00.000Z",
  "leftAt": "2026-10-17T02:20:00.000Z",
  "durationMinutes": 20,
  "durationFormatted": "20 phút",
  "pointCount": 8,
  "confidence": "inferred",
  "containsDataGap": true,
  "maxGapSeconds": 300
}
```

`confidence=observed` khi mọi interval của stay không vượt threshold. `confidence=inferred` và `containsDataGap=true` nghĩa là stay bao gồm khoảng không quan sát tại cùng khu vực. `leftAt` là thời điểm của fix cuối vẫn nằm trong bán kính stay, không phải fix chuyển động đầu tiên. `durationMinutes` có thể bao gồm thời gian suy luận; dùng summary quality fields để trình bày độ tin cậy.

### Kích thước payload đã đo

Fixture deterministic gồm 100 GPS fixes được trả nguyên vẹn (`pointCount=100`), đo bằng UTF-8 của cùng một JSON response:

| Chế độ | Kích thước |
| --- | ---: |
| Mặc định, có `path` và `points` | 16,705 bytes |
| `includePath=false`, chỉ có `points` | 11,515 bytes |
| Tiết kiệm | 5,190 bytes, tương đương 31.07% |

Đây là số đo regression fixture, không phải cam kết kích thước cho mọi hành trình. Mức giảm thực tế phụ thuộc số segment, số điểm sau thinning và metadata.

## 3. Raw history theo khoảng thời gian

### Legacy today mode

```http
GET /api/v1/history/{userId}
```

Không có query mới thì response giữ nguyên:

```json
{ "success": true, "count": 1, "date": "2026-10-17", "data": [] }
```

### Range mode

```http
GET /api/v1/history/{userId}?from=2026-10-16T17:00:00.000Z&to=2026-10-17T16:59:59.999Z&limit=500
```

| Query | Bắt buộc | Quy tắc |
| --- | --- | --- |
| `from` | Một trong `from`/`to` | ISO-8601 có timezone, inclusive |
| `to` | Một trong `from`/`to` | ISO-8601 có timezone, inclusive |
| `limit` | Không | Mặc định 500, tối đa 1000 |
| `cursor` | Không | Chuỗi opaque từ `nextCursor`; không parse hoặc chỉnh sửa |

Nếu thiếu một đầu, backend suy ra một cửa sổ tối đa 7 ngày. Nếu có cả hai, khoảng phải lớn hơn 0 và không quá 7 ngày.

```json
{
  "success": true,
  "count": 2,
  "data": [
    {
      "id": "66f123456789abcdef012346",
      "latitude": 10.7,
      "longitude": 106.6,
      "timestamp": "2026-10-17T01:00:00.000Z",
      "recordedAt": "2026-10-17T01:00:00.000Z",
      "accuracy": 5,
      "pointId": "08f68d38-6665-4f0f-8f48-bfa7cc449dc8"
    }
  ],
  "nextCursor": "eyJ2IjoxLCJ0IjoiLi4uIiwiaWQiOiIuLi4ifQ",
  "range": {
    "from": "2026-10-16T17:00:00.000Z",
    "to": "2026-10-17T16:59:59.999Z"
  }
}
```

Gọi trang kế tiếp với cùng `from`, `to`, `limit` và `cursor=nextCursor`. Dừng khi `nextCursor` là `null`. Cursor dùng `(timestamp, _id)`, nên nhiều điểm có cùng timestamp vẫn không bị trùng hoặc bỏ sót.

## 4. Swift models

```swift
struct JourneyResponse: Decodable, Sendable {
    let success: Bool
    let date: String
    let userId: String
    let timeZone: String?
    let geometryPolicy: GeometryPolicy?
    let summary: JourneySummary
    let journey: [JourneyItem]
}

struct JourneySummary: Decodable, Sendable {
    let totalPoints: Int
    let stayPointCount: Int
    let totalStayMinutes: Int
    let totalMovingMinutes: Int
    let observedMovingSeconds: Double?
    let observedStaySeconds: Double?
    let unobservedSeconds: Double?
    let firstSeenAt: Date?
    let lastSeenAt: Date?
}

struct GeometryPolicy: Decodable, Sendable {
    let version: Int
    let gapThresholdSeconds: Double
    let gapIndexSpace: String
    let toBoundary: String
    let stayRadiusMeters: Double
    let minStayMinutes: Double
}

struct JourneyRoutePoint: Decodable, Sendable {
    let latitude: Double
    let longitude: Double
    let recordedAt: Date
    let accuracy: Double?
}

struct JourneyGap: Decodable, Sendable {
    let fromIndex: Int
    let toIndex: Int
    let seconds: Double
    let meters: Double
}

struct RawHistoryPage: Decodable, Sendable {
    let success: Bool
    let count: Int
    let data: [RawHistoryPoint]
    let nextCursor: String?
    let range: HistoryRange
}

struct RawHistoryPoint: Decodable, Identifiable, Sendable {
    let id: String
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    let recordedAt: Date?
    let accuracy: Double?
    let pointId: UUID?
}

struct HistoryRange: Decodable, Sendable {
    let from: Date
    let to: Date
}
```

Vì `journey` chứa union `stay`/`moving`, triển khai `JourneyItem` bằng custom `Decodable`: decode `type` trước, sau đó decode `StaySegment` hoặc `MovingSegment`. Các field geometry và `MovingSegment.path` nên optional để cùng model đọc được legacy, geometry mặc định và `includePath=false`. Với raw history, map `recordedAt ?? timestamp` thành một domain property duy nhất.

## 5. Deployment compatibility

1. Deploy backend và đảm bảo MongoDB có index `{ userId: 1, timestamp: 1, _id: 1 }`.
2. Smoke test endpoint legacy trước.
3. Bật `LOCATION_HISTORY_DENSE_ENABLED=true` khi đã theo dõi storage/error ổn định.
4. Mobile mới chuyển journey sang `detail=geometry&includePath=false`; mobile cũ không cần cập nhật ngay.
5. Nếu cần rollback mật độ ghi, đặt flag về `false`; endpoint đọc vẫn tương thích.
