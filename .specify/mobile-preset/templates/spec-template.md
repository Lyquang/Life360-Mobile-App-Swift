## FamilyTracker Mobile Requirements

Điền theo feature thực tế; giữ nguyên các mục native phía trên. Feature nằm trong
`.spec/`, không phải `specs/`; sửa các placeholder đường dẫn trước khi kết thúc.

**Mode**: STANDARD / COMPLEX (SMALL không bắt buộc full spec).
**Scope / Non-goals**: [phạm vi và hành vi phải giữ nguyên].

### Backend API Dependencies

- Source: [đường dẫn api-docs/ hoặc tài liệu người dùng; N/A nếu không cần Backend]
- Version/Revision: [giá trị có nguồn; Unknown nếu chưa được cung cấp]
- Endpoints/events: [method + path/event có thật]
- Contract Status: Verified / Pending / Conflict / N/A
- Open Questions: [chi tiết thiếu, mức blocking và bên cần xác nhận]

### UI states, navigation và vòng đời

Ghi initial/loading/success/empty/error/offline/retry/permission-denied/session-expired
nếu áp dụng; lý do N/A cho phần không cần. Liên kết thiết kế đã được cung cấp,
Coordinator ownership, keyboard, screen sizes, VoiceOver và loading cancellation.

### Localization

| Key | Tiếng Việt | English | Trường hợp sử dụng |
| --- | --- | --- | --- |
| [key thật khi có UI] | [copy] | [copy] | [state/accessibility] |

Chuỗi dài nhất cần kiểm tra clipping: [chuỗi / N/A].

### Interview và acceptance

Ghi câu trả lời đã xác nhận trong Clarifications native; dùng interview.md khi cần
nhiều vòng, không hỏi lại câu đã có đáp án. Acceptance criteria phải truy vết tới
FR/user story, API và verification. Không coi spec draft là quyền implementation.
