# Đặc tả tính năng: Vị trí, tối ưu năng lượng và đồng bộ offline

**Phạm vi**: iOS FamilyTracker · **Trạng thái**: theo từng tài liệu gốc và `PROGRESS.md`; cần kiểm chứng trước khi báo hoàn thành.

## Ranh giới phạm vi

Chia sẻ vị trí theo chính sách, bảo vệ quyền riêng tư và lưu các điểm đã chấp nhận khi offline. Tài liệu này là chỉ mục tổng hợp; các spec gốc và quyết định theo giai đoạn được giữ nguyên bên dưới. Không coi đề xuất hoặc kết quả kiểm thử cũ là xác nhận production hiện tại.

## Kịch bản người dùng và kiểm thử

### Câu chuyện 1

Thành viên xem vị trí và vệt trong Circle khi quyền và kết nối cho phép.

**Kiểm thử độc lập:** Nhận location_update của thành viên được phép, kiểm tra marker và timestamp; không giả định socket emit là server ack.

### Câu chuyện 2

Thiết bị mất mạng có thể lưu các điểm hợp lệ và đồng bộ lịch sử khi kết nối trở lại.

**Kiểm thử độc lập:** Tắt mạng, thêm các fix đã qua policy, mở lại app và kiểm tra đồng bộ theo pointId khi mạng trở lại.

### Câu chuyện 3

Ngừng chia sẻ, logout hoặc mất quyền không được tiếp tục phát vị trí.

**Kiểm thử độc lập:** Dừng hoặc logout trong lúc heartbeat đang ngủ và xác nhận không emit sau khi dừng.

### Trường hợp biên

- Thiết bị bị kill, GPS nhiễu, đồng bộ một phần, 401/429, mất quyền, logout và thay đổi tài khoản.

## Yêu cầu chức năng

- **FR-001**: Giữ timestamp, accuracy, speed và course của LocationFix; áp dụng LocationSendPolicy và heartbeat theo phiên bản đã triển khai.
- **FR-002**: Offline buffer tách theo chủ sở hữu; chỉ xóa điểm theo pointId sau xác nhận hợp lệ; không log tọa độ.
- **FR-003**: Tôn trọng quyền chia sẻ và session:ready; không phát lại điểm lịch sử như vị trí realtime.

## Thực thể chính

- `LocationFix`, `GeoPoint`, `BufferedLocationPoint`, motion state và trạng thái socket.
- LocationBuffer và LocationSyncCoordinator quản lý điểm chờ và batch.

## Tiêu chí hoàn thành

- Phạm vi, điều kiện biên và các bất biến của spec chi tiết được đáp ứng; trạng thái không rõ phải được kiểm tra lại.
- Có kết quả kiểm thử phù hợp và ghi lại các giới hạn chưa xác minh; UI dùng vi/en khi áp dụng.

## Phụ thuộc và ngoài phạm vi

- Backend, quyền iOS và kiểm thử thiết bị thật theo từng spec chi tiết; không giả định hợp đồng chưa được xác nhận.
- Không thay đổi các chức năng khác chỉ vì cấu trúc tài liệu.

## Spec chi tiết đã bảo toàn

- [location-fix.md](references/location-fix.md)
- [location-diagnostics.md](references/location-diagnostics.md)
- [location-heartbeat-cancellation.md](references/location-heartbeat-cancellation.md)
- [location-send-policy.md](references/location-send-policy.md)
- [location-offline-buffer.md](references/location-offline-buffer.md)
- [location-offline-batch-api.md](references/location-offline-batch-api.md)
- [location-offline-sync.md](references/location-offline-sync.md)
- [location-offline-routing.md](references/location-offline-routing.md)
