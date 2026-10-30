# Đặc tả tính năng: SOS và hỗ trợ khẩn cấp

**Phạm vi**: iOS FamilyTracker · **Trạng thái**: theo từng tài liệu gốc và `PROGRESS.md`; cần kiểm chứng trước khi báo hoàn thành.

## Ranh giới phạm vi

Tạo SOS, tiếp nhận hỗ trợ và phục hồi trạng thái sự cố theo REST và sự kiện realtime. Tài liệu này là chỉ mục tổng hợp; các spec gốc và quyết định theo giai đoạn được giữ nguyên bên dưới. Không coi đề xuất hoặc kết quả kiểm thử cũ là xác nhận production hiện tại.

## Kịch bản người dùng và kiểm thử

### Câu chuyện 1

Người gửi chủ động tạo SOS, chọn gửi kèm vị trí một lần hoặc không kèm vị trí.

**Kiểm thử độc lập:** Chọn một trong hai cách gửi và kiểm tra REST payload chỉ chứa tọa độ nếu người dùng đã đồng ý.

### Câu chuyện 2

Thành viên nhận cảnh báo, xem chi tiết, xác nhận hỗ trợ; chủ SOS xem người hỗ trợ và đóng SOS.

**Kiểm thử độc lập:** Mock tạo SOS, phản hồi và đóng; xác minh danh sách responders và không tự gửi chat SOS.

### Câu chuyện 3

Người hỗ trợ có thể theo dõi luồng vị trí sẵn có khi quyền chia sẻ cho phép.

**Kiểm thử độc lập:** Với quyền và kết nối hợp lệ, mở người gửi trên bản đồ và kiểm tra timestamp các cập nhật; thử tạm dừng hoặc mất mạng.

### Trường hợp biên

- Timeout và 401/403/404/409/429/503, SOS đóng, location permission, logout và event tới muộn.

## Yêu cầu chức năng

- **FR-001**: Tạo và cập nhật SOS qua REST; backend tự tạo tin chat; tái sử dụng clientRequestId khi kết quả chưa xác nhận.
- **FR-002**: Khôi phục qua REST, dedupe event/message, ngăn revision cũ và xóa dữ liệu theo phiên.
- **FR-003**: Không tự động bật chia sẻ liên tục khi chưa có hợp đồng backend cho quyền SOS tạm thời.

## Thực thể chính

- `SOSIncident`, `SOSDetail`, `SOSResponder`, pending intent và session state.

## Tiêu chí hoàn thành

- Phạm vi, điều kiện biên và các bất biến của spec chi tiết được đáp ứng; trạng thái không rõ phải được kiểm tra lại.
- Có kết quả kiểm thử phù hợp và ghi lại các giới hạn chưa xác minh; UI dùng vi/en khi áp dụng.

## Phụ thuộc và ngoài phạm vi

- Backend, quyền iOS và kiểm thử thiết bị thật theo từng spec chi tiết; không giả định hợp đồng chưa được xác nhận.
- Không thay đổi các chức năng khác chỉ vì cấu trúc tài liệu.

## Spec chi tiết đã bảo toàn

- [sos-assistance.md](references/sos-assistance.md)
