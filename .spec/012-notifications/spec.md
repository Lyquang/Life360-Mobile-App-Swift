# Đặc tả tính năng: Thông báo và điều hướng

**Phạm vi**: iOS FamilyTracker · **Trạng thái**: theo từng tài liệu gốc và `PROGRESS.md`; cần kiểm chứng trước khi báo hoàn thành.

## Ranh giới phạm vi

Xử lý quyền thông báo, thông báo nội bộ và điều hướng khi nhấn thông báo theo khả năng backend thực tế. Tài liệu này là chỉ mục tổng hợp; các spec gốc và quyết định theo giai đoạn được giữ nguyên bên dưới. Không coi đề xuất hoặc kết quả kiểm thử cũ là xác nhận production hiện tại.

## Kịch bản người dùng và kiểm thử

### Câu chuyện 1

Người dùng xem thông báo phù hợp và mở nội dung được hỗ trợ.

**Kiểm thử độc lập:** Kiểm tra quyền, nhận thông báo được hỗ trợ và route theo payload hợp lệ.

### Câu chuyện 2

Người dùng điều chỉnh quyền và cài đặt thông báo trong app và iOS Settings.

**Kiểm thử độc lập:** Từ chối quyền, mở cài đặt máy và xác minh app không tuyên bố đã bật thông báo.

### Trường hợp biên

- Từ chối quyền, app bị tắt, payload không hợp lệ và người dùng đổi tài khoản.

## Yêu cầu chức năng

- **FR-001**: Tôn trọng cài đặt và quyền hệ thống; điều hướng thông qua coordinator.
- **FR-002**: Không tuyên bố hỗ trợ APNs/FCM cho SOS khi backend chưa có khả năng đó.

## Thực thể chính

- Notification settings, device token, deeplink và trạng thái quyền.

## Tiêu chí hoàn thành

- Phạm vi, điều kiện biên và các bất biến của spec chi tiết được đáp ứng; trạng thái không rõ phải được kiểm tra lại.
- Có kết quả kiểm thử phù hợp và ghi lại các giới hạn chưa xác minh; UI dùng vi/en khi áp dụng.

## Phụ thuộc và ngoài phạm vi

- Backend, quyền iOS và kiểm thử thiết bị thật theo từng spec chi tiết; không giả định hợp đồng chưa được xác nhận.
- Không thay đổi các chức năng khác chỉ vì cấu trúc tài liệu.

## Nguồn tham khảo

Xem [research.md](research.md) và [plan.md](plan.md) để đối chiếu tài liệu gốc và tình trạng triển khai.

