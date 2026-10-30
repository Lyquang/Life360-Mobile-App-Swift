# Checklist chất lượng: Giám sát pin, mạng và hiệu năng

## Nội dung

- [ ] Mục tiêu, phạm vi và bên chịu trách nhiệm được mô tả rõ.
- [ ] Story có tiêu chí kiểm thử và trường hợp biên cụ thể.
- [ ] Phân biệt hành vi đã xác nhận, đề xuất và việc chưa kiểm chứng.

## Kiến trúc và quyền riêng tư

- [ ] View không gọi trực tiếp mạng/dữ liệu; Coordinator quản lý điều hướng.
- [ ] Chuỗi mới có vi/en; không log thông tin nhạy cảm.
- [ ] Xác định hợp đồng backend và giới hạn OS khi liên quan.

## Nghiệm thu

- [ ] Ghi kết quả test thực tế và giới hạn chưa kiểm chứng.
- [ ] Cập nhật spec, tài liệu liên quan và `PROGRESS.md`.
