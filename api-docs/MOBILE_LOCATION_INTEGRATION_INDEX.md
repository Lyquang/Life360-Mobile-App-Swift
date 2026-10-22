# Mobile Location Integration - Documentation Index

Tài liệu này là điểm bắt đầu cho iOS khi tích hợp toàn bộ chuỗi Location của FamilyTracker: gửi vị trí, đồng bộ offline, đọc hành trình, theo dõi Live Trail, tạm ẩn vị trí và rời/xóa thành viên khỏi Circle.

## 1. Thứ tự đọc đề xuất

1. [`LOCATION_UPDATE_API_DOC.md`](./LOCATION_UPDATE_API_DOC.md): gửi GPS realtime bằng Socket.IO, nhận vị trí thành viên và đồng bộ các điểm offline bằng REST batch.
2. [`JOURNEY_ROUTE_API_DOC.md`](./JOURNEY_ROUTE_API_DOC.md): đọc lịch sử, journey theo ngày, moving/stay segments, gap và pagination.
3. [`LIVE_TRAIL_API_DOC.md`](./LIVE_TRAIL_API_DOC.md): tải snapshot Live Trail, đăng ký watch, áp delta, xử lý revision/reset/closed.
4. [`PRIVACY_AND_CIRCLE_MEMBERSHIP_API_DOC.md`](./PRIVACY_AND_CIRCLE_MEMBERSHIP_API_DOC.md): pause/resume chia sẻ vị trí, rời Circle, admin xóa thành viên và dọn state phía mobile.

## 2. Contract map

| Nghiệp vụ | Transport | Method/Event | Path hoặc event | Contract chuẩn |
| --- | --- | --- | --- | --- |
| Gửi vị trí hiện tại | Socket.IO client -> server | Event | `update_location` | `LOCATION_UPDATE_API_DOC.md` |
| Nhận vị trí thành viên | Socket.IO server -> client | Event | `location_update` | `LOCATION_UPDATE_API_DOC.md` |
| Đồng bộ vị trí offline | REST | `POST` | `/api/v1/locations/batch` | `LOCATION_UPDATE_API_DOC.md` |
| Đọc lịch sử hôm nay/range | REST | `GET` | `/api/v1/history/{userId}` | `JOURNEY_ROUTE_API_DOC.md` |
| Đọc journey theo ngày | REST | `GET` | `/api/v1/history/{userId}/journey` | `JOURNEY_ROUTE_API_DOC.md` |
| Tải Live Trail snapshot/catch-up | REST | `GET` | `/api/v1/history/{userId}/journey/trail` | `LIVE_TRAIL_API_DOC.md` |
| Bắt đầu/dừng xem Live Trail | Socket.IO client -> server | Event | `journey:watch`, `journey:unwatch` | `LIVE_TRAIL_API_DOC.md` |
| Nhận thay đổi Live Trail | Socket.IO server -> client | Event | `journey:trail_delta` | `LIVE_TRAIL_API_DOC.md` |
| Reload hoặc đóng Live Trail | Socket.IO server -> client | Event | `journey:trail_reset`, `journey:trail_closed` | `LIVE_TRAIL_API_DOC.md` |
| Đọc trạng thái chia sẻ | REST | `GET` | `/api/v1/privacy/location-sharing` | `PRIVACY_AND_CIRCLE_MEMBERSHIP_API_DOC.md` |
| Pause/resume chia sẻ | REST | `PATCH` | `/api/v1/privacy/location-sharing` | `PRIVACY_AND_CIRCLE_MEMBERSHIP_API_DOC.md` |
| Tự rời Circle | REST | `DELETE` | `/api/v1/groups/{groupId}/members/me` | `PRIVACY_AND_CIRCLE_MEMBERSHIP_API_DOC.md` |
| Admin xóa thành viên | REST | `DELETE` | `/api/v1/groups/{groupId}/members/{userId}` | `PRIVACY_AND_CIRCLE_MEMBERSHIP_API_DOC.md` |
| Nhận thay đổi membership | Socket.IO server -> client | Event | `group:membership_ended`, `group:member_left` | `PRIVACY_AND_CIRCLE_MEMBERSHIP_API_DOC.md` |

Tất cả REST endpoint yêu cầu:

```http
Authorization: Bearer <accessToken>
Accept: application/json
```

Socket.IO truyền access token trong handshake theo contract realtime chung của dự án.

## 3. Luồng mobile end-to-end

### Gửi vị trí

1. Sau `session:ready`, gửi GPS fix mới bằng `update_location`.
2. Khi socket mất kết nối, lưu các fix đã qua policy vào bộ đệm bền vững.
3. Khi có mạng lại, gửi điểm cũ qua `POST /api/v1/locations/batch` và gửi fix mới nhất qua socket.
4. Chỉ xóa điểm offline khi server trả `pointId` trong `accepted` hoặc `duplicates`.

### Xem hành trình trực tiếp

1. Gọi REST Live Trail không có `afterSeq` để lấy snapshot.
2. Tải hết trang theo `nextAfterSeq` và cùng `revision`.
3. Emit `journey:watch`.
4. Chỉ áp `journey:trail_delta` khi `revision` và `afterSeq` nối đúng cursor local.
5. Khi nhận `journey:trail_reset` hoặc HTTP `409 TRAIL_REVISION_CHANGED`, xóa snapshot cũ và tải lại từ đầu.
6. Khi nhận `journey:trail_closed`, dừng watch và đóng/fallback màn hình theo `reason`.

### Privacy và Circle membership

1. Khi pause sharing thành công, dừng gửi GPS và xóa location buffer để điểm cũ không được upload sau khi resume.
2. `sos_alert` vẫn là luồng khẩn cấp độc lập và không tự bật lại location sharing.
3. Khi nhận `group:membership_ended`, xóa Circle và group conversation khỏi local stores, dừng watcher liên quan và rời màn hình nếu đang mở.
4. Khi nhận `group:member_left`, cập nhật danh sách thành viên Circle.

## 4. Quy tắc recovery quan trọng

| Trường hợp | Mobile xử lý |
| --- | --- |
| HTTP `401` | Chạy refresh token single-flight và retry request một lần |
| HTTP `403 LOCATION_SHARING_PAUSED` | Dừng realtime/batch cho đến khi người dùng resume |
| HTTP `403 FORBIDDEN` | Dừng đọc user/trail; quyền Circle không còn hợp lệ |
| HTTP `409 TRAIL_REVISION_CHANGED` | Xóa Live Trail revision cũ và tải snapshot mới |
| HTTP `429` | Tôn trọng `Retry-After`, retry với backoff và jitter |
| HTTP `503` từ Live Trail | Feature đang tắt; fallback sang Journey/History |
| Socket disconnect | Giữ điểm hợp lệ trong offline buffer và reconnect có backoff |
| `journey:trail_closed` | Dừng watch ngay; không tự đăng ký lại khi chưa khôi phục quyền |

## 5. Tài liệu kiến trúc bổ trợ

Các file dưới đây giải thích quyết định kỹ thuật; mobile nên dùng bốn file trong mục 1 làm API contract canonical:

- [`../Study/CORE_FLOWS_MOBILE.md`](../Study/CORE_FLOWS_MOBILE.md)
- [`../Study/OFFLINE_LOCATION_BATCH_SYNC.md`](../Study/OFFLINE_LOCATION_BATCH_SYNC.md)
- [`../Study/live-trail-backend.md`](../Study/live-trail-backend.md)
- [`../Study/LIVE_TRAIL_PRIVACY_AND_CIRCLE_EXIT.md`](../Study/LIVE_TRAIL_PRIVACY_AND_CIRCLE_EXIT.md)
- [`../Study/route-geometry-mobile-contract-followup.md`](../Study/route-geometry-mobile-contract-followup.md)

## 6. Rollout note

Live Trail hiện được bảo vệ bởi feature flag. Mobile phải hỗ trợ HTTP `503 SERVICE_UNAVAILABLE` và fallback sang Journey/History cho đến khi production bật `LIVE_TRAIL_ENABLED=true`. Road map matching thật chưa được bật; mobile luôn phải có khả năng vẽ raw GPS points.
