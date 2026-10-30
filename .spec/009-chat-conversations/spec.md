# Đặc tả tính năng: Trò chuyện và nhắn tin trực tiếp

**Phạm vi**: iOS FamilyTracker · **Trạng thái**: theo từng tài liệu gốc và `PROGRESS.md`; cần kiểm chứng trước khi báo hoàn thành.

## Ranh giới phạm vi

Cho phép người dùng xem cuộc trò chuyện, mở chat nhóm hoặc chat 1-1 và theo dõi tin chưa đọc. Tài liệu này là chỉ mục tổng hợp; các spec gốc và quyết định theo giai đoạn được giữ nguyên bên dưới. Không coi đề xuất hoặc kết quả kiểm thử cũ là xác nhận production hiện tại.

## Kịch bản người dùng và kiểm thử

### Câu chuyện 1

Người dùng mở chat trực tiếp từ danh sách thành viên, hoặc chọn cuộc trò chuyện trong tab Trò chuyện.

**Kiểm thử độc lập:** Mở direct chat từ thành viên, kiểm tra route, tiêu đề và trường hợp chưa có tin.

### Câu chuyện 2

Tin mới và số chưa đọc được cập nhật và đối soát khi vào tab.

**Kiểm thử độc lập:** Nhận tin mới và mở lại tab; đối chiếu conversation ID và unread summary.

### Trường hợp biên

- Mất mạng, đối tượng không còn quyền, socket reconnect và danh sách trống.

## Yêu cầu chức năng

- **FR-001**: Điều hướng qua coordinator; upsert cuộc trò chuyện theo ID và tránh yêu cầu trùng.
- **FR-002**: Tôn trọng API và socket hiện có, xử lý loading, rỗng, lỗi và hủy.

## Thực thể chính

- Conversation, ChatMessage, unread summary, UI loading/error.

## Tiêu chí hoàn thành

- Phạm vi, điều kiện biên và các bất biến của spec chi tiết được đáp ứng; trạng thái không rõ phải được kiểm tra lại.
- Có kết quả kiểm thử phù hợp và ghi lại các giới hạn chưa xác minh; UI dùng vi/en khi áp dụng.

## Phụ thuộc và ngoài phạm vi

- Backend, quyền iOS và kiểm thử thiết bị thật theo từng spec chi tiết; không giả định hợp đồng chưa được xác nhận.
- Không thay đổi các chức năng khác chỉ vì cấu trúc tài liệu.

## Nguồn tham khảo

Xem [research.md](research.md) và [plan.md](plan.md) để đối chiếu tài liệu gốc và tình trạng triển khai.

