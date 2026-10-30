# Đặc tả tính năng: Đa ngôn ngữ Việt / Anh

**Phạm vi**: iOS FamilyTracker · **Trạng thái**: theo từng tài liệu gốc và `PROGRESS.md`; cần kiểm chứng trước khi báo hoàn thành.

## Ranh giới phạm vi

Cho phép đổi ngôn ngữ app giữa tiếng Việt và tiếng Anh, lưu lựa chọn và giữ nguyên phiên và điều hướng. Tài liệu này là chỉ mục tổng hợp; các spec gốc và quyết định theo giai đoạn được giữ nguyên bên dưới. Không coi đề xuất hoặc kết quả kiểm thử cũ là xác nhận production hiện tại.

## Kịch bản người dùng và kiểm thử

### Câu chuyện 1

Người dùng đổi ngôn ngữ ở màn đăng nhập hoặc cài đặt và thấy nội dung app cập nhật.

**Kiểm thử độc lập:** Chọn English/Tiếng Việt trên màn hỗ trợ và kiểm tra nhãn, lỗi và accessibility tương ứng.

### Câu chuyện 2

Lựa chọn được giữ khi mở lại app và không làm dừng chia sẻ vị trí.

**Kiểm thử độc lập:** Mở lại app, xác nhận lựa chọn được giữ và luồng hiện tại không bị reset.

### Trường hợp biên

- Thiếu key, lựa chọn không hợp lệ, placeholder và plural, sheet/hộp thoại theo ngôn ngữ hệ điều hành.

## Yêu cầu chức năng

- **FR-001**: Mọi chuỗi do app sở hữu, kể cả accessibility và lỗi, dùng L10n.tr với key tương ứng vi/en.
- **FR-002**: Tên, nội dung người dùng và hộp thoại hệ thống không tự dịch; định dạng dùng locale được chọn.

## Thực thể chính

- `AppLanguage`, language preferences và locale environment.

## Tiêu chí hoàn thành

- Phạm vi, điều kiện biên và các bất biến của spec chi tiết được đáp ứng; trạng thái không rõ phải được kiểm tra lại.
- Có kết quả kiểm thử phù hợp và ghi lại các giới hạn chưa xác minh; UI dùng vi/en khi áp dụng.

## Phụ thuộc và ngoài phạm vi

- Backend, quyền iOS và kiểm thử thiết bị thật theo từng spec chi tiết; không giả định hợp đồng chưa được xác nhận.
- Không thay đổi các chức năng khác chỉ vì cấu trúc tài liệu.

## Spec chi tiết đã bảo toàn

- [app-language.md](references/app-language.md)
