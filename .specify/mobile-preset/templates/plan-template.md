## FamilyTracker Architecture & API Mapping

Dùng các thư mục thật FamilyTracker/{App,Presentation,Domain,Data,Core,Resources};
feature docs ở `.spec/`. Xoá các cấu trúc ví dụ không phù hợp phía trên. iOS 16,
Swift language mode 5, SwiftUI/Combine, MVVM-C và SPM là context hiện tại; đọc project
thực tế trước khi điền version. Không tạo Backend module trong repo Mobile.

| Source / revision | Method + path/event | Request/response, auth, status, errors | DTO/mapper/repository | UI consumer | Verification / status |
| --- | --- | --- | --- | --- | --- |
| [nguồn thật hoặc N/A] | [contract] | [nullable/optional, enum, date, pagination/upload nếu có] | [file] | [feature] | [test / Pending] |

Ghi path/query/header/body, success/error/validation, filtering/sorting, timeout,
retry, cancellation và versioning nếu áp dụng. Không sao chép nguyên API docs.

## Reusability & Optimization Analysis

- Existing components: [đã tìm ở đâu, dùng/extend component nào, consumer ảnh hưởng].
- Existing logic: [UseCase, APIClient, DTO/mapper, cache, formatter, validator].
- New abstractions: [lý do cần; simpler alternative; N/A khi không cần].
- Duplication removed within scope: [phần đã duyệt, không dọn ngoài scope].
- State ownership: [local UI/shared session/server/derived/persistent].
- Rendering/network/memory/startup/image/battery risks: [rủi ro có liên quan].
- Optimization evidence: [baseline, phép đo, kết quả dự kiến và trade-off; chưa đo thì ghi rõ].

## Approval & Verification Plan

Đối chiếu constitution, spec, interview nếu có, API và tasks trước implementation.
Liệt kê file tạo/sửa, navigation, refactor scope, rollback, rủi ro và test theo FR/story.
Chọn lệnh thực tế trong .specify/README.md; ghi giới hạn XCTest, Simulator/device và
benchmark. Feature progress giữ AWAITING_APPROVAL cho tới khi người dùng duyệt rõ
phạm vi/plan; thay đổi material phải quay lại duyệt. Không tự tạo trạng thái APPROVED.

## Design Review (conditional)

UI Impact và mức review: [NONE/SMALL/SUBSTANTIVE/MAJOR + lý do]. Với substantive UI:
requirement → flow/state → reused token/component → visual/native decision → HIG
reference → accessibility/localization → screenshot/interaction QA. Dùng cả hai
design skills theo .specify/design-workflow.md; giữ approval hiện có. NONE ghi N/A.
