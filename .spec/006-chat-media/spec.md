# Đặc tả tính năng: Chat media: ảnh và ghi âm

**Phạm vi**: iOS FamilyTracker · **Trạng thái**: theo từng tài liệu gốc và `PROGRESS.md`; cần kiểm chứng trước khi báo hoàn thành.

## Ranh giới phạm vi

Gửi, nhận và phát ảnh và voice note qua dịch vụ media và chat hiện có. Tài liệu này là chỉ mục tổng hợp; các spec gốc và quyết định theo giai đoạn được giữ nguyên bên dưới. Không coi đề xuất hoặc kết quả kiểm thử cũ là xác nhận production hiện tại.

## Kịch bản người dùng và kiểm thử

### Câu chuyện 1

Người dùng gửi ảnh JPEG hoặc voice note và xem trạng thái gửi.

**Kiểm thử độc lập:** Chọn ảnh/voice hợp lệ, xác minh thứ tự ticket → PUT → message và trạng thái UI.

### Câu chuyện 2

Khi mất ack, app đối soát lịch sử trước khi người dùng thử gửi lại.

**Kiểm thử độc lập:** Giả lập ack timeout, lấy lịch sử đối chiếu URL trước khi cho phép gửi lại.

### Trường hợp biên

- Mất mạng, ticket hết hạn, 401/403/503, ack timeout, giới hạn file và ngắt ghi âm.

## Yêu cầu chức năng

- **FR-001**: Lấy ticket có xác thực, PUT byte bằng header được cấp và chỉ gửi message sau PUT thành công; không gửi Bearer tới storage.
- **FR-002**: Tuân giới hạn và phân biệt lỗi trước PUT với ack không chắc chắn; không tự thêm clientMessageId chưa được backend hỗ trợ.

## Thực thể chính

- `ChatMessage`, attachment/voice metadata, trạng thái optimistic và media draft.

## Tiêu chí hoàn thành

- Phạm vi, điều kiện biên và các bất biến của spec chi tiết được đáp ứng; trạng thái không rõ phải được kiểm tra lại.
- Có kết quả kiểm thử phù hợp và ghi lại các giới hạn chưa xác minh; UI dùng vi/en khi áp dụng.

## Phụ thuộc và ngoài phạm vi

- Backend, quyền iOS và kiểm thử thiết bị thật theo từng spec chi tiết; không giả định hợp đồng chưa được xác nhận.
- Không thay đổi các chức năng khác chỉ vì cấu trúc tài liệu.

## Spec chi tiết đã bảo toàn

- [media-upload.md](references/media-upload.md)
