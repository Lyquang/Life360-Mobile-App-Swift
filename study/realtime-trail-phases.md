# Vệt di chuyển realtime bám đường - lộ trình triển khai

## Mục tiêu sản phẩm

- Khi đang chia sẻ vị trí, app tự vẽ vệt di chuyển của mình trên bản đồ; thành viên cùng Circle nhìn thấy vệt đó gần realtime.
- Chỉ vẽ nét liền khi backend trả geometry đã map-match hợp lệ. GPS thô được thể hiện bằng điểm và nét đứt với nhãn "Vệt GPS chưa khớp đường"; không nối điểm đầu/cuối thành đường chim bay.
- Journey chỉ là màn xem lại vệt này theo ngày, không xây thêm một hệ thống lộ trình độc lập.
- Không làm tính năng chỉ đường tới thành viên trong chuỗi phase này.

## Trạng thái và thứ tự

| Phase | Phạm vi | Trạng thái |
| --- | --- | --- |
| 1 - Hợp đồng Live Trail | Model Domain, DTO, REST snapshot/catch-up, lỗi có kiểu, test hợp đồng | Đã viết; Debug/Release build được; XCTest chưa chạy vì project chưa có test target |
| 2 - Cổng riêng tư | Pause fail-closed, lưu pendingSync theo tài khoản, chặn socket/batch trong lúc tạm dừng; SOS đi luồng riêng | Code đã nối: UI vi/en, startup check, retry theo reconnect/foreground. Chưa test hai máy/thiết bị thật; XCTest target chưa có |
| 3 - Đồng bộ realtime | REST snapshot nhiều trang, Socket watch/delta/reset/closed, catch-up và hủy watch khi mất quyền | Code đã nối; test cursor/gap/match-only trong harness; chưa xác minh hai máy thật |
| 4 - Bản đồ chính | Vệt của mình local-first và vệt thành viên từ server; GPS thô nét đứt, matched nét liền | Code đã nối trên MKMapView iOS 16, avatar và điểm đầu/cuối; chưa đo FPS/pin thiết bị thật |
| 5 - Journey | Xem lại snapshot Live Trail theo ngày bằng cùng renderer; bỏ cách diễn giải đường thẳng độc lập | Code dùng cùng TrailDrawing; khi trail 503 hiển thị không khả dụng, không giả đường chim bay; cần đối chiếu response triển khai |
| 6 - Chốt | Test hai thiết bị, offline/reconnect, quyền riêng tư, pin, VoiceOver và hiệu năng | Chưa làm; Xcode project vẫn không có Test action |

Các thay đổi Journey D1-D3/F1-F3 đang nằm trong worktree chưa commit. Không revert chúng theo suy đoán; khi phase 5 thay thế hành vi cũ, chỉ gỡ phần UI/logic thật sự dư và kiểm tra diff trước khi xóa. Không tự commit.

## Phụ thuộc backend và giới hạn thật

`api-docs/LIVE_TRAIL_API_DOC.md` là hợp đồng REST/Socket. Backend đã có adapter Mapbox Map Matching thật và test giả lập HTTP; mặc định deployment vẫn `LIVE_TRAIL_ENABLED=false` và `noop`. Vì vậy mobile có thể hoàn thiện raw trail/UI trung thực, nhưng **chưa thể hứa vệt bám đường bộ trên production** cho tới khi cấu hình token Mapbox, bật rollout và kiểm tra hai máy thật. Snapshot Live Trail hiện có retention mặc định 7 ngày; lưu lâu hơn cần thay đổi backend riêng.

Trạng thái `LIVE_TRAIL_ENABLED=false` và `LIVE_TRAIL_MATCHER_PROVIDER=noop` là mặc định **trong cấu hình repo Backend**, không chứng minh trạng thái deployment hiện tại. Parser backend chấp nhận `mapbox`; `fake` bị cấm ở production. Mobile chỉ vẽ nét đặc khi geometry `polyline6` hợp lệ từ provider khác `noop`/`fake`; một delta match-only không được dịch insertion cursor.

## Đối chiếu code đã nối

- `SocketRealtimeRepository`: watch sau `session:ready`, ack, delta/reset/closed, unwatch khi rời bản đồ hoặc đổi thành viên. Reconnect tải REST catch-up trước khi watch lại. 403 dừng watch và xóa vệt target.
- `LiveMapViewModel`: điểm đã qua chính sách gửi xuất hiện local-first như GPS thô, sau đó được đối soát với snapshot; chỉ một target được watch tại một thời điểm để không vượt giới hạn 5 watch/socket. Chọn thành viên để xem vệt tương ứng.
- `LiveTrailMapView`: `MKMapView` iOS 16, bản đồ thành viên dùng avatar, raw GPS nét đứt/nhãn, matched thật nét liền có viền; gap không nối. Journey dùng đúng renderer/snapshot này theo ngày.
- `DiagnosticRedactor`: che `points` và `geometry` (kể cả polyline6) trước Pulse. Socket gửi thêm `recordedAt` và `accuracy` hợp lệ; chưa gửi `pointId`/`motionState` vì cần ID bền vững xuyên socket/batch và nối motion state đúng nguồn.

## Nghiệm thu còn lại

1. Backend đã triển khai adapter Mapbox; cần đặt `MAPBOX_ACCESS_TOKEN` bí mật, bật cờ và xác minh quota/độ trễ/điều khoản hiển thị trên MapKit sau load gate. Không dùng `fake` để công bố bám đường.
2. Tạo/khôi phục target `FamilyTrackerTests` bằng Xcode (không sửa pbxproj thủ công), chạy XCTest. Harness `scripts/test_networking.sh` hiện có kiểm tra cursor, gap, match-only, redaction và payload socket.
3. Hai điện thoại cùng Circle: A đi bộ, B mở bản đồ chọn A; kiểm tra fix mới, matched update, mất mạng rồi reconnect, reset do offline batch, pause/quyền bị thu hồi, ngày mới và đổi thành viên.
4. Kiểm tra thiết bị thật về FPS/bộ nhớ, pin, Dark Mode, chữ lớn/VoiceOver; đo với ngày có nhiều nghìn điểm. Không coi build Simulator là bằng chứng cho các mục này.

### Cấu hình staging cho vệt bám đường

Trên Backend staging, đặt `LIVE_TRAIL_ENABLED=true`, `LIVE_TRAIL_MATCHER_ENABLED=true`, `LIVE_TRAIL_MATCHER_PROVIDER=mapbox`, `MAPBOX_ACCESS_TOKEN` trong secret manager và bắt đầu với `LIVE_TRAIL_MATCH_TIMEOUT_MS=5000`. Không đưa token vào Mobile hay log. Đo độ trễ từ fix GPS đến `matchedUpdates`: khi chưa đủ điểm hoặc Mapbox từ chối match, vệt GPS vẫn là nét đứt, không giả làm đường đã khớp. Kiểm tra quota/chi phí Mapbox và xác nhận điều khoản sử dụng geometry trên Apple MapKit trước khi công bố; việc gửi GPS cho Mapbox phải được phản ánh trong chính sách riêng tư.

Kịch bản nghiệm thu: hai máy cùng Circle, A chạy qua ngã rẽ và B xem realtime; so sánh nét đặc với đường đã chạy, không nối xuyên vùng mất GPS; tắt mạng rồi mở lại, snapshot/Journey cùng ngày phải trùng vệt đã ghi; pause chia sẻ trên A phải chặn fix mới ở B. Sau khi test, tắt cờ để rollback nếu độ trễ, pin hoặc chi phí không đạt.

## Cổng kiểm tra mỗi phase

Build Debug/Release trên iOS Simulator không ký; chạy `bash scripts/test_networking.sh`, `bash scripts/test_localization.sh`, SwiftLint, XCTest khi target khả dụng và `git diff --check`. Báo kết quả thực tế trước khi sang phase tiếp. Mỗi phase giới hạn khoảng 8 file và không tự commit.
