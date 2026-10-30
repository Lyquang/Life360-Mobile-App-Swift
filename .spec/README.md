# Đặc tả tính năng FamilyTracker

Thư mục này tổ chức tài liệu theo mô hình của `001-message-notifications`. Nội dung trong `001-message-notifications/` là **mẫu từ dự án khác**, không phải yêu cầu hay hợp đồng của FamilyTracker; giữ nguyên để tham khảo cấu trúc, không sao chép các thông tin nghiệp vụ hoặc liên kết của dự án đó.

## Danh mục tính năng

| Nhóm | Đặc tả | Tài liệu gốc |
| --- | --- | --- |
| API và xác thực | [002-api-auth/spec.md](002-api-auth/spec.md) | Endpoint và refresh token |
| Ngôn ngữ | [003-app-language/spec.md](003-app-language/spec.md) | Tiếng Việt / tiếng Anh |
| Circle | [004-circles/spec.md](004-circles/spec.md) | Thành viên và hủy yêu cầu |
| Vị trí | [005-location/spec.md](005-location/spec.md) | P1–P4, P7A–P7D |
| Media chat | [006-chat-media/spec.md](006-chat-media/spec.md) | Ảnh và voice R2 |
| Công cụ debug | [007-debugger/spec.md](007-debugger/spec.md) | Pulse |
| SOS | [008-sos-assistance/spec.md](008-sos-assistance/spec.md) | SOS và hỗ trợ |
| Chat | [009-chat-conversations/spec.md](009-chat-conversations/spec.md) | Chat nhóm, 1-1 và tin chưa đọc |
| Bản đồ và hành trình | [010-live-trail-journey/spec.md](010-live-trail-journey/spec.md) | Vệt realtime và lịch sử |
| Giám sát | [011-mobile-monitoring/spec.md](011-mobile-monitoring/spec.md) | Pin, mạng và hiệu năng |
| Thông báo | [012-notifications/spec.md](012-notifications/spec.md) | Quyền, thông báo và điều hướng |

Mỗi nhóm dùng `spec.md` làm điểm vào, `plan.md` cho kiến trúc, `tasks.md` cho checklist, `research.md` cho nguồn, `data-model.md` cho trạng thái, `quickstart.md` cho kiểm thử và `checklists/requirements.md` để rà soát. `contracts/` liên kết tới tài liệu backend hiện có khi phù hợp. Nội dung cũ được giữ nguyên trong `references/`; kết quả và quyết định cũ có thể đã bị thay thế, cần đối chiếu `PROGRESS.md`, code và hợp đồng hiện tại.

Các ô chưa đánh dấu trong `tasks.md` là **checklist cho lần xác minh tiếp theo**, không phải khẳng định tính năng chưa được triển khai. Không đánh dấu hoàn thành nếu chưa có bằng chứng kiểm thử tương ứng.

## Tạo hoặc cập nhật đặc tả

Helper Bash và cấu hình tóm tắt kiến trúc nằm tại [../.specify/README.md](../.specify/README.md); không mặc định CLI hoặc agent Spec Kit đã được cài.

1. Tìm nhóm liên quan ở bảng trên; đọc `spec.md` và chỉ mở spec chi tiết cần thiết trong `references/`.
2. Với tính năng mới, tạo `.spec/<số-thứ-tự>-<tên-kebab-case>/`; không dùng lại số đã có. Dùng các mẫu trong `templates/` và điền nội dung phù hợp, không sao chép dữ liệu từ `001-message-notifications/`.
3. Ghi phạm vi, trạng thái, story, tiêu chí nghiệm thu, hợp đồng, edge case và các giả định chưa xác nhận. Với tính năng cần duyệt, không coi một spec draft là phê duyệt.
4. Cập nhật `plan.md`, `tasks.md`, các nguồn liên quan và `PROGRESS.md` theo công việc thực tế. `contracts/` chỉ chứa hoặc trỏ đến hợp đồng có nguồn, đánh dấu rõ đề xuất chưa được backend xác nhận.
5. Ưu tiên đọc tài liệu theo tính năng và `rg`/AST trước khi mở rộng phạm vi code để tiết kiệm context.
