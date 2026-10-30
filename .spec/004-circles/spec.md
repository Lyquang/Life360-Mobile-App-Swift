# Đặc tả tính năng: Circle và danh sách thành viên

**Phạm vi**: iOS FamilyTracker · **Trạng thái**: theo từng tài liệu gốc và `PROGRESS.md`; cần kiểm chứng trước khi báo hoàn thành.

## Ranh giới phạm vi

Tải danh sách nhóm và thành viên đáng tin cậy, hỗ trợ làm mới và xử lý lỗi. Tài liệu này là chỉ mục tổng hợp; các spec gốc và quyết định theo giai đoạn được giữ nguyên bên dưới. Không coi đề xuất hoặc kết quả kiểm thử cũ là xác nhận production hiện tại.

## Kịch bản người dùng và kiểm thử

### Câu chuyện 1

Người dùng xem nhóm và thành viên dù payload thành viên thiếu groupId.

**Kiểm thử độc lập:** Giả lập response 200 thiếu groupId và kiểm tra toàn bộ thành viên hiển thị.

### Câu chuyện 2

Người dùng kéo làm mới, chuyển tab hoặc thử lại mà không nhận lỗi hủy giả.

**Kiểm thử độc lập:** Chồng lần tải đầu và pull-to-refresh, hủy một caller rồi kiểm tra trạng thái và lỗi mạng thật.

### Trường hợp biên

- Response 200 thiếu groupId, tab chuyển trong lúc tải, lỗi giải mã, hủy và retry.

## Yêu cầu chức năng

- **FR-001**: Giữ tương thích DTO với groupId tùy chọn; không để kết quả cũ thay thành viên nhóm mới.
- **FR-002**: Các yêu cầu trùng nhau chia sẻ tác vụ phù hợp và lỗi mạng thật vẫn được hiển thị.

## Thực thể chính

- Circle, thành viên, trạng thái tải/lỗi và request generation.

## Tiêu chí hoàn thành

- Phạm vi, điều kiện biên và các bất biến của spec chi tiết được đáp ứng; trạng thái không rõ phải được kiểm tra lại.
- Có kết quả kiểm thử phù hợp và ghi lại các giới hạn chưa xác minh; UI dùng vi/en khi áp dụng.

## Phụ thuộc và ngoài phạm vi

- Backend, quyền iOS và kiểm thử thiết bị thật theo từng spec chi tiết; không giả định hợp đồng chưa được xác nhận.
- Không thay đổi các chức năng khác chỉ vì cấu trúc tài liệu.

## Spec chi tiết đã bảo toàn

- [circle-members-response.md](references/circle-members-response.md)
- [groups-request-cancellation.md](references/groups-request-cancellation.md)
