# Đặc tả tính năng: Pulse và chẩn đoán

**Phạm vi**: iOS FamilyTracker · **Trạng thái**: theo từng tài liệu gốc và `PROGRESS.md`; cần kiểm chứng trước khi báo hoàn thành.

## Ranh giới phạm vi

Cung cấp công cụ debug mạng và log cho quá trình phát triển, bảo vệ dữ liệu nhạy cảm. Tài liệu này là chỉ mục tổng hợp; các spec gốc và quyết định theo giai đoạn được giữ nguyên bên dưới. Không coi đề xuất hoặc kết quả kiểm thử cũ là xác nhận production hiện tại.

## Kịch bản người dùng và kiểm thử

### Câu chuyện 1

Lập trình viên mở Pulse trong bản Debug và xem lỗi mạng hoặc socket đã được làm sạch.

**Kiểm thử độc lập:** Bản Debug mở được Pulse và log thử đã che token, tọa độ và URL có chữ ký.

### Câu chuyện 2

Có thể xuất báo cáo để tự phân tích mà không gửi tự động tới dịch vụ AI.

**Kiểm thử độc lập:** Xuất dữ liệu đã làm sạch bằng thao tác chủ động; không phát sinh request AI tự động.

### Trường hợp biên

- Offline, JSON không hợp lệ, binary, xuất hủy và dữ liệu nhạy cảm.

## Yêu cầu chức năng

- **FR-001**: Không ghi token, tọa độ, nội dung chat hoặc URL có chữ ký vào log; Release không bật console debug.
- **FR-002**: Tôn trọng phân tách Core/Data và DebugCoordinator; không hứa tự động thu mọi lỗi hệ thống.

## Thực thể chính

- Logger boundary, DiagnosticRedactor, trạng thái debug/export.

## Tiêu chí hoàn thành

- Phạm vi, điều kiện biên và các bất biến của spec chi tiết được đáp ứng; trạng thái không rõ phải được kiểm tra lại.
- Có kết quả kiểm thử phù hợp và ghi lại các giới hạn chưa xác minh; UI dùng vi/en khi áp dụng.

## Phụ thuộc và ngoài phạm vi

- Backend, quyền iOS và kiểm thử thiết bị thật theo từng spec chi tiết; không giả định hợp đồng chưa được xác nhận.
- Không thay đổi các chức năng khác chỉ vì cấu trúc tài liệu.

## Spec chi tiết đã bảo toàn

- [pulse-debugger.md](references/pulse-debugger.md)
