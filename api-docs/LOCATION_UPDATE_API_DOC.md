# Realtime Location Update API - Mobile Contract

Tài liệu này là hợp đồng tích hợp sự kiện vị trí realtime giữa FamilyTracker Mobile và Backend.

## 1. Tổng quan

Mobile gửi GPS fix qua Socket.IO event `update_location`. Backend kiểm tra dữ liệu, cập nhật cache/vị trí gần nhất, lưu lịch sử theo throttle và phát `location_update` cho các thành viên. Đây không phải REST endpoint và hiện không có acknowledgement callback.

## 2. Client gửi `update_location`

```json
{
  "latitude": 10.7769,
  "longitude": 106.7009,
  "batteryLevel": 80,
  "recordedAt": "2026-10-13T08:30:15.123Z",
  "accuracy": 8.5,
  "pointId": "08f68d38-6665-4f0f-8f48-bfa7cc449dc8",
  "motionState": "walking"
}
```

| Field | Kiểu | Bắt buộc | Quy tắc |
| --- | --- | --- | --- |
| `latitude` | Number | Có | `-90...90` |
| `longitude` | Number | Có | `-180...180` |
| `batteryLevel` | Number | Không | Backend clamp về `0...100` |
| `recordedAt` | String | Không | ISO-8601 có timezone, là thời điểm thiết bị đo GPS fix |
| `accuracy` | Number | Không | Mét, phải `>= 0` |
| `pointId` | UUID String | Không | Dùng cùng UUID nếu GPS fix này được retry qua batch |
| `motionState` | String | Không | `stationary`, `walking`, `running`, `cycling`, `automotive`, `unknown` |

Client cũ có thể tiếp tục chỉ gửi `latitude`, `longitude` và `batteryLevel`. Khi thiếu `recordedAt`, Backend dùng giờ nhận của server như trước đây.

### Quy tắc `recordedAt`

Backend chấp nhận:

```text
serverNow - 24 giờ <= recordedAt <= serverNow + 60 giây
```

- ISO-8601 sai định dạng: payload bị từ chối.
- Đúng ISO-8601 nhưng quá 24 giờ hoặc ở tương lai quá 60 giây: Backend không từ chối điểm; thời gian bị thay bằng giờ server.
- Backend ghi log/counter cho timestamp ngoài khoảng nhưng không log tọa độ.

### Quy tắc `accuracy` trên iOS

Sử dụng `CLLocation.horizontalAccuracy` khi giá trị không âm:

```swift
let accuracy: Double? = location.horizontalAccuracy >= 0
    ? location.horizontalAccuracy
    : nil
```

Không gửi `accuracy` nếu Core Location trả số âm. Số âm hoặc sai kiểu làm toàn bộ payload bị từ chối.

## 3. Server phát `location_update`

```json
{
  "userId": "66f123456789abcdef012345",
  "name": "Alice",
  "latitude": 10.7769,
  "longitude": 106.7009,
  "batteryLevel": 80,
  "timestamp": "2026-10-13T08:30:15.123Z",
  "recordedAt": "2026-10-13T08:30:15.123Z",
  "accuracy": 8.5,
  "motionState": "walking",
  "durationAtLocation": 12,
  "durationSince": "2026-10-13T08:18:00.000Z",
  "durationFormatted": "12 phút"
}
```

| Field | Kiểu | Bắt buộc | Ý nghĩa |
| --- | --- | --- | --- |
| `userId` | String | Có | ID người gửi |
| `name` | String | Có | Tên hiển thị |
| `latitude` | Number | Có | Vĩ độ |
| `longitude` | Number | Có | Kinh độ |
| `batteryLevel` | Number/null | Có | Pin thiết bị hoặc giá trị gần nhất |
| `timestamp` | String | Có | Alias tương thích của `recordedAt` |
| `recordedAt` | String | Có | Thời điểm GPS fix có hiệu lực |
| `accuracy` | Number | Không | Độ chính xác ngang, mét |
| `motionState` | String | Không | Trạng thái chuyển động do client cung cấp |
| `durationAtLocation` | Integer | Có | Số phút tại khu vực hiện tại |
| `durationSince` | String | Có | Mốc duration tracker của server |
| `durationFormatted` | String | Có | Chuỗi thời lượng hiển thị |

Mobile mới nên dùng `recordedAt`. `timestamp` được giữ lại để không làm vỡ client cũ và hiện có cùng giá trị.

## 4. Lưu trữ và thứ tự dữ liệu

- Redis `location:last:<userId>` lưu `recordedAt` và `accuracy` nếu có.
- `LocationHistory.timestamp` dùng thời gian GPS hợp lệ, giúp lịch sử sắp xếp theo thời điểm đo thay vì thời điểm đồng bộ.
- `User.lastKnownLocation` chỉ cập nhật nếu `recordedAt` mới hơn `updatedAt` đang lưu. Điểm offline đến muộn vẫn có thể vào history nhưng không ghi đè marker mới nhất.
- `durationTracker`, stay-alert và throttle runtime vẫn dùng giờ server. `accuracy` chưa ảnh hưởng duration hoặc ngưỡng lưu history.
- Khi `LOCATION_HISTORY_DENSE_ENABLED=false`, history giữ quy tắc cũ: 50 mét **hoặc** 30 giây.
- Khi bật dense history, server lưu khi đạt đồng thời khoảng thời gian và khoảng cách cấu hình, khi đổi `motionState`, hoặc khi đến heartbeat đứng yên. Mặc định rollout là 15 giây, 25 mét và heartbeat 300 giây.
- Cùng một fix được chống trùng bằng `(userId, recordedAt, latitude, longitude)`; `pointId` tăng độ ổn định khi retry xuyên realtime/batch.

## 5. Payload lỗi

Backend phát event `error` về socket gửi:

```json
{
  "message": "Invalid location payload.",
  "errors": [
    {
      "field": "accuracy",
      "message": "Too small: expected number to be >=0"
    }
  ]
}
```

Các lỗi thường gặp: latitude/longitude ngoài phạm vi, `recordedAt` không phải ISO-8601 có timezone, hoặc `accuracy` âm/sai kiểu.

## 6. Swift DTO tham khảo

```swift
struct LocationUpdatePayload: Encodable, Sendable {
    let latitude: Double
    let longitude: Double
    let batteryLevel: Double?
    let recordedAt: String?
    let accuracy: Double?
    let pointId: UUID?
    let motionState: String?
}

struct RealtimeLocationUpdate: Decodable, Sendable {
    let userId: String
    let name: String
    let latitude: Double
    let longitude: Double
    let batteryLevel: Double?
    let timestamp: String
    let recordedAt: String
    let accuracy: Double?
    let motionState: String?
    let durationAtLocation: Int
    let durationSince: String
    let durationFormatted: String
}
```

Khi đệm offline, phải giữ nguyên `recordedAt` của `CLLocation.timestamp`; không tạo timestamp mới tại thời điểm retry.

## 7. Đồng bộ nhiều điểm offline qua REST

### Endpoint

```http
POST /api/v1/locations/batch
Authorization: Bearer <accessToken>
Content-Type: application/json
```

Endpoint chỉ phục hồi lịch sử và cập nhật last-known location theo thời gian. Backend **không phát** `location_update`, không gọi duration tracker và không tạo stay alert từ batch.

### Request

```json
{
  "points": [
    {
      "pointId": "08f68d38-6665-4f0f-8f48-bfa7cc449dc8",
      "latitude": 10.7769,
      "longitude": 106.7009,
      "recordedAt": "2026-10-14T08:30:15.123Z",
      "accuracy": 8.5,
      "batteryLevel": 80,
      "motionState": "walking"
    }
  ]
}
```

| Field | Kiểu | Bắt buộc | Quy tắc |
| --- | --- | --- | --- |
| `points` | Array | Có | `1...100` phần tử |
| `pointId` | UUID String | Có | UUID bền vững do mobile sinh; giữ nguyên khi retry |
| `latitude` | Number | Có | `-90...90` |
| `longitude` | Number | Có | `-180...180` |
| `recordedAt` | ISO-8601 String | Có | Không cũ quá 24 giờ, không ở tương lai quá 60 giây |
| `accuracy` | Number | Không | Mét, phải `>= 0` |
| `batteryLevel` | Number | Không | Backend clamp về `0...100` |
| `motionState` | String | Không | Cùng enum với socket; hỗ trợ phát hiện chuyển trạng thái |

Không gửi `userId`. Backend luôn lấy user từ access token. Request body toàn hệ thống có giới hạn `100 KB`.

### Response thành công hoặc thành công một phần

```json
{
  "success": true,
  "data": {
    "accepted": ["08f68d38-6665-4f0f-8f48-bfa7cc449dc8"],
    "duplicates": ["906d98d3-07ea-4aa3-8194-84bca59466ce"],
    "rejected": [
      {
        "index": 2,
        "pointId": "449e5aca-746a-463d-a78a-5888958216c8",
        "code": "RECORDED_AT_TOO_OLD",
        "reason": "recordedAt exceeds the maximum allowed age."
      }
    ]
  }
}
```

- `accepted`: điểm vừa được lưu.
- `duplicates`: điểm đã tồn tại hoặc lặp trong cùng request; được xem là đã đồng bộ thành công.
- `rejected`: điểm sai dữ liệu hoặc ngoài khoảng thời gian cho phép. `index` là vị trí trong request.
- Mixed-validity batch vẫn trả HTTP `200` để các điểm tốt không bị mất.
- Mobile chỉ xóa ngay các `pointId` nằm trong `accepted` hoặc `duplicates`.
- Các code validation trong `rejected` là lỗi vĩnh viễn; mobile không retry vô hạn, nên loại bỏ hoặc đưa vào dead-letter/metric cục bộ.

### Mã lỗi request

| HTTP | Code | Mobile xử lý |
| --- | --- | --- |
| `400` | `VALIDATION_ERROR` | Sửa envelope; không retry nguyên trạng |
| `400` | `BATCH_LIMIT_EXCEEDED` | Chia thành lô tối đa 100 điểm |
| `401` | `UNAUTHORIZED` | Dùng refresh single-flight rồi retry một lần |
| `403` | `LOCATION_SHARING_PAUSED` | Dừng gửi realtime/batch và giữ trạng thái privacy off; không retry cho đến khi user bật lại |
| `413` | `PAYLOAD_TOO_LARGE` | Chia lô nhỏ hơn để body dưới 100 KB |
| `429` | `RATE_LIMITED` | Giữ queue và chờ số giây trong `Retry-After` |
| `500` | `INTERNAL_ERROR` | Giữ queue, retry với exponential backoff và jitter |

Rate limit mặc định là 30 batch/phút cho mỗi user đã xác thực.

### Thứ tự và idempotency

- Backend sắp xếp stable theo `recordedAt` trước khi ghi.
- Unique keys gồm `(userId, pointId)` và fingerprint `(userId, recordedAt, latitude, longitude)`, nên retry hoặc cùng fix đi qua socket rồi batch không tạo lịch sử trùng.
- Điểm đến muộn vẫn vào history nhưng không ghi đè `User.lastKnownLocation` hoặc Redis nếu đã có điểm mới hơn.
- Không áp dụng throttle realtime `50 m / 30 s` lên batch và hiện không thinning dữ liệu.

### Quan hệ với realtime sau reconnect

```text
Buffered historical points  -> POST /locations/batch
Fresh GPS fix after reconnect -> Socket update_location
```

Ưu tiên không gửi cùng buffered point qua cả REST batch và socket. Nếu xảy ra do retry/race, backend vẫn deduplicate cùng measured fix. Batch không broadcast; mobile nên lấy một GPS fix hiện tại và gửi qua socket sau `session:ready` để bản đồ người thân cập nhật ngay.

### Swift DTO tham khảo

```swift
struct BufferedLocationPoint: Codable, Sendable {
    let pointId: UUID
    let latitude: Double
    let longitude: Double
    let recordedAt: Date
    let accuracy: Double?
    let batteryLevel: Double?
    let motionState: String?
}

struct LocationBatchRequest: Encodable, Sendable {
    let points: [BufferedLocationPoint]
}

struct LocationBatchRejection: Decodable, Sendable {
    let index: Int
    let pointId: UUID?
    let code: String
    let reason: String
}

struct LocationBatchResult: Decodable, Sendable {
    let accepted: [UUID]
    let duplicates: [UUID]
    let rejected: [LocationBatchRejection]
}
```

Encoder phải dùng ISO-8601 cho `Date`. Khi server trả `429`, đọc header `Retry-After`; khi `401`, dùng chung refresh coordinator để tránh nhiều refresh chạy đồng thời.

Khi account pause location sharing, backend không lưu realtime hoặc batch points. Mobile phải dừng location transmission và xóa offline buffer theo quyết định privacy; không gửi lại các point đã thu trong thời gian pause sau khi bật lại. Xem `api-docs/PRIVACY_AND_CIRCLE_MEMBERSHIP_API_DOC.md`.
