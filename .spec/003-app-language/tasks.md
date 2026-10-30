# Công việc: Đa ngôn ngữ Việt / Anh

Đây là checklist xác minh, không phải lịch sử hoàn thành. Xem `PROGRESS.md` và spec chi tiết để xác định trạng thái từng giai đoạn.

## Giai đoạn 1: Đối chiếu

- [ ] Đối chiếu [spec.md](spec.md), các spec chi tiết và hợp đồng backend liên quan với code hiện tại.
- [ ] Xác định phạm vi, phụ thuộc, trạng thái và các quyết định còn mở trước khi sửa code.

## Giai đoạn 2: Thực hiện và kiểm thử

- [ ] Thực hiện thay đổi được duyệt theo MVVM-C/Clean Architecture, không sửa các phần ngoài phạm vi.
- [ ] Kiểm tra trường hợp biên và hồi quy theo các spec chi tiết; bổ sung kiểm thử có ý nghĩa nếu cần.
- [ ] Kiểm tra vi/en nếu có chuỗi giao diện.

## Giai đoạn 3: Nghiệm thu

- [ ] Chạy các kiểm tra phù hợp trong [quickstart.md](quickstart.md); ghi rõ bài không chạy được.
- [ ] Kiểm thử thiết bị/backend khi yêu cầu và cập nhật `PROGRESS.md` cùng spec khi có thay đổi.
