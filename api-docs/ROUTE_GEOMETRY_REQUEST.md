# Đề nghị hợp đồng Route Geometry cho backend

**Đề xuất, chưa triển khai.** Repo `../Backend` chỉ được đọc trong task iOS này. Ví dụ JSON hoàn toàn tổng hợp, không phải tọa độ/ID/tên thật. Mục tiêu: ứng dụng phân biệt đường có điểm GPS và đoạn **thiếu dữ liệu**, không trình bày đường chim bay như tuyến đã đi.

## Hiện trạng đã đối chiếu

- `GET /api/v1/history/:userId/journey?date=YYYY-MM-DD` đã có. `path` của mỗi moving segment gồm tọa độ những điểm **đã lưu**, nhưng không có timestamp/accuracy từng điểm (`../Backend/src/domain/journey.js:70-85`). `summary.totalPoints` là tổng điểm trong ngày, không phải số điểm riêng segment (`:145-154`).
- `GET /api/v1/history/:userId` chỉ lấy hôm nay, không phân trang (`../Backend/src/presentation/http/routes/historyRoutes.js:23`, `../Backend/src/application/history/historyUseCases.js:22-35`). Quyền xem: bản thân hoặc người cùng Circle; ngoài ra 403 (`historyUseCases.js:15-19`).
- Socket `update_location` **nhận optional** `recordedAt`, `accuracy`; broadcast trả `recordedAt` và accuracy nếu có (`../Backend/src/presentation/dto/location.schemas.js:10-16`, `../Backend/src/application/location/locationUseCases.js:113-129`). iOS hiện chưa gửi hai trường này; không thể khẳng định “luôn có” trước khi sửa iOS và xác nhận bản deploy.

## 1. Journey có geometry theo thời gian - BẮT BUỘC

`GET /api/v1/history/:userId/journey?date=YYYY-MM-DD` (Bearer). Ngày phải có **timezone IANA được công bố** (đề xuất `Asia/Ho_Chi_Minh` cho sản phẩm ở Việt Nam, cần chủ dự án chốt); trả `timeZone` trong response. Mốc thời gian ISO-8601 có offset, ưu tiên UTC `Z`; điểm tăng dần theo `recordedAt`, trùng thời gian thì tie-break theo ID/thứ tự lưu ổn định. Không bắt client tự gán thời gian giả.

```json
{
  "success": true,
  "date": "2026-01-02",
  "timeZone": "Asia/Ho_Chi_Minh",
  "userId": "synthetic-user",
  "summary": { "totalPoints": 3, "stayPointCount": 0, "movingSegmentCount": 1 },
  "journey": [{
    "type": "moving",
    "segmentId": "synthetic-segment-1",
    "startTime": "2026-01-02T00:00:00.000Z",
    "endTime": "2026-01-02T00:01:00.000Z",
    "pointCount": 3,
    "distanceMeters": 144.0,
    "points": [
      { "latitude": 0.0000, "longitude": 0.0000, "recordedAt": "2026-01-02T00:00:00.000Z", "accuracy": 12.0 },
      { "latitude": 0.0005, "longitude": 0.0003, "recordedAt": "2026-01-02T00:00:30.000Z", "accuracy": 10.0 },
      { "latitude": 0.0010, "longitude": 0.0008, "recordedAt": "2026-01-02T00:01:00.000Z", "accuracy": null }
    ]
  }]
}
```

`pointCount` = số điểm raw của segment **trước** làm thưa. Nếu `points` đã làm thưa, thêm `returnedPointCount` và `geometryQuality: "simplified"`; client không được coi nối qua điểm bị lược là liên tục quan sát. `distanceMeters` = tổng khoảng cách GPS hợp lệ từ điểm raw, **không** phải đường bộ hoặc `MKDirections`; không tính qua gap phi lý. Không tính được thì `null`, không dùng `0`. Stay item giữ `arrivedAt`, `leftAt`, `pointCount`, tọa độ đại diện; có thể thêm `segmentId` cho stay nếu cần.

**Giới hạn/density:** công bố trần response Journey (gợi ý 2.000 điểm, **chưa chốt**). Nếu vượt, trả `geometryStatus: "partial"`, `pointCount` raw và `points` đã làm thưa theo thời gian **và** độ cong; giữ đầu/cuối, góc và ranh giới gap. Raw endpoint mục 2 phải cho phép tải đầy đủ ngày dài. Đề nghị thêm `geometryRevision`/`asOf` để cache. Nếu không có điểm, trả `points: []` và `geometryStatus: "unavailable"`, không chỉ trả `from/to` rồi để client tự vẽ thẳng.

**Tương thích ngược:** giữ `path` cũ cho client đã phát hành trong thời gian chuyển tiếp, hoặc version API (`v2`) trước khi bỏ. `points` mới có timestamp là nguồn chuẩn. Không âm thầm thay `path` bằng geometry đã map-match. Contract test cả schema cũ/mới. `summary.movingSegmentCount` hiện chưa có trong backend (`../Backend/src/domain/journey.js:145-154`); thêm trường này cần test.

## 2. Raw history theo khoảng thời gian và cursor - BẮT BUỘC

`GET /api/v1/history/:userId?from=<ISO-8601>&to=<ISO-8601>&limit=500&cursor=<opaque>` (Bearer). `from` inclusive, `to` exclusive. Khi có `cursor`, giữ nguyên from/to/limit qua các trang. Gợi ý `limit` 1...500, mặc định 200; sort tăng dần và cursor ổn định theo `(recordedAt, id)` hoặc snapshot key. Trả cùng quyền xem như Journey; không vượt `limit` trong một trang. Không có query: giữ semantics “today” cũ trong giai đoạn chuyển tiếp.

```json
{
  "success": true,
  "data": [
    { "id": "synthetic-point-1", "latitude": 0.0, "longitude": 0.0,
      "recordedAt": "2026-01-02T00:00:00.000Z", "accuracy": 12.0 }
  ],
  "nextCursor": null,
  "hasMore": false
}
```

Chọn `recordedAt` làm tên mới; nếu giữ `timestamp` từ response cũ, trả cả hai trong thời gian chuyển tiếp và xác nhận chúng bằng nhau. Nếu hôm nay có thêm dữ liệu giữa các trang, cần quy tắc snapshot/`asOf` để không bỏ hoặc nhân đôi điểm. Mã lỗi đề nghị: 400 query sai, 401 token sai/hết hạn, 403 không cùng Circle, 404 user không tồn tại **nếu policy hiện hành dùng 404**, 429 quá tải, 503 storage tạm ngưng. Ngày không có điểm: 200 + `data: []`, không phải 404.

## 3. Lưu lịch sử dày hơn khi di chuyển - ĐỀ XUẤT

`shouldSaveHistory` hiện lưu khi >=30 giây **hoặc** >=50 m từ điểm lưu trước (`../Backend/src/application/location/locationUseCases.js:44-49`). iOS automotive min 10 giây nhưng mật độ thực phụ thuộc GPS/socket. Đề nghị thử **10-15 giây hoặc 25 m khi di chuyển**, có sàn theo accuracy và rate cap mỗi user; đứng yên giữ thưa. Nếu liên tục 10 giây: trần giản lược ~360 điểm/giờ/người; 15 giây: ~240 (chưa tính callback/loại điểm). Đo dung lượng Mongo/index, tải API, retention và pin trước rollout. Không tự đổi P4 client. Lưu GPS `recordedAt` thật và accuracy; nếu thiếu, nên đánh dấu `timeSource: "server"`, `accuracy: null` để client không coi là fix chính xác.

## 4. Geometry map-match - TÙY CHỌN, sau cổng F4

Có thể thêm `geometry: { "encoding": "polyline6", "data": "<synthetic-encoded>", "matched": true, "provider": "<provider>", "version": 1 }` cho segment. Sinh bất đồng bộ, cache theo revision; khi chưa có/thất bại trả `geometry: null` và **vẫn** trả `points` raw. Geometry matched là ước tính, có thể sai đường. Backend owner cần kiểm tra license/điều khoản hiện hành khi hiển thị trên Apple Maps, chi phí/Render, retention và riêng tư trước khi chọn OSRM/Valhalla/dịch vụ ngoài. Tài liệu này **không** phê duyệt nhà cung cấp nào.

## 5. Trạng thái chia sẻ và socket - TÙY CHỌN / XÁC NHẬN

- **Tùy chọn:** `sharingStatus: "on" | "off" | "unknown"` nếu chính sách quyền cho phép, để phân biệt tắt chia sẻ và ngày không có dữ liệu. Không tiết lộ trạng thái cho người không có quyền.
- **Cần xác nhận:** broadcast `location_update` có `recordedAt` và `accuracy` khi client gửi. Nếu client không gửi, backend không tự tuyên bố accuracy. Muốn F5 thì phải sửa iOS trong giai đoạn được duyệt. Socket hiện không có delivery ack; emit không chứng minh persisted.

## Kiểm thử hợp đồng và rollout

Contract tests: 0/1/N điểm, gap lớn, timestamp trùng/đảo, accuracy null, quá page limit, dữ liệu đổi giữa các trang, timezone/DST, 400/401/403/429, client cũ dùng `path`. Fixture **tổng hợp**; monitoring chỉ aggregate count và p50/p90 khoảng thời gian/khoảng cách, không log tọa độ/token/tên. Rollout backward-compatible: app cũ còn hoạt động; app mới không nối `from/to` khi thiếu geometry. Backend/product owner cần chốt timezone, trần điểm, pagination snapshot và retention trước triển khai.
