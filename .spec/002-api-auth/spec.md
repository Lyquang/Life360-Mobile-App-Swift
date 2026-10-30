# Đặc tả tính năng: API và xác thực

**Phạm vi**: iOS FamilyTracker · **Trạng thái**: theo từng tài liệu gốc và `PROGRESS.md`; cần kiểm chứng trước khi báo hoàn thành.

## Ranh giới phạm vi

Kết nối API bằng transport dùng chung, bảo vệ phiên đăng nhập và xử lý refresh token an toàn. Tài liệu này là chỉ mục tổng hợp; các spec gốc và quyết định theo giai đoạn được giữ nguyên bên dưới. Không coi đề xuất hoặc kết quả kiểm thử cũ là xác nhận production hiện tại.

## Kịch bản người dùng và kiểm thử

### Câu chuyện 1

Người dùng đăng nhập và gọi API có xác thực qua Bearer token từ Keychain.

**Kiểm thử độc lập:** Request cần xác thực nhận Bearer từ Keychain; request công khai không yêu cầu token.

### Câu chuyện 2

Khi access token hết hạn, các request đồng thời dùng chung một lần refresh; lỗi hoặc logout không làm phiên cũ ghi đè phiên mới.

**Kiểm thử độc lập:** Nhiều request đồng thời nhận 401 chờ chung refresh; logout trong lúc refresh không khôi phục phiên cũ.

### Trường hợp biên

- 401 đồng thời, timeout không rõ kết quả, 429, Keychain lỗi và logout trong lúc refresh.

## Yêu cầu chức năng

- **FR-001**: View không gọi APIClient hoặc URLSession trực tiếp; repository ánh xạ lỗi về Domain.
- **FR-002**: Refresh token rotation dùng single-flight, lưu cặp token an toàn và giới hạn retry; socket phải dùng token hiện tại.

## Thực thể chính

- `AuthTokens`, token generation và trạng thái phiên.
- Endpoint/DTO và lỗi mạng được ánh xạ qua repository.

## Tiêu chí hoàn thành

- Phạm vi, điều kiện biên và các bất biến của spec chi tiết được đáp ứng; trạng thái không rõ phải được kiểm tra lại.
- Có kết quả kiểm thử phù hợp và ghi lại các giới hạn chưa xác minh; UI dùng vi/en khi áp dụng.

## Phụ thuộc và ngoài phạm vi

- Backend, quyền iOS và kiểm thử thiết bị thật theo từng spec chi tiết; không giả định hợp đồng chưa được xác nhận.
- Không thay đổi các chức năng khác chỉ vì cấu trúc tài liệu.

## Spec chi tiết đã bảo toàn

- [api-integration.md](references/api-integration.md)
- [refresh-token-rotation.md](references/refresh-token-rotation.md)
