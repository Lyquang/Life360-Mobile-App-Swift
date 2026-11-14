# Hiến chương FamilyTracker iOS

## Core Principles

### I. Clean Code và kiến trúc hiện có

Ưu tiên correctness, maintainability, readability, reusability, performance phù hợp,
simplicity và testability. Tên có nghĩa, control flow đơn giản, trách nhiệm gắn kết;
không tối ưu để ít dòng nhất. Giữ MVVM-C + Clean Architecture: View hiển thị/binding,
ViewModel quản lý state trên MainActor, Coordinator điều hướng, Domain độc lập UI,
Data/Core hiện thực repository và dịch vụ. Không tự đổi kiến trúc vì quy tắc mới;
vi phạm cũ là phát hiện cần đánh giá trong phạm vi, không phải quyền refactor toàn app.

### II. DRY, KISS, YAGNI và tái sử dụng UI

Tìm trong `Presentation/Common`, `Presentation/Components` và các scene liên quan
trước khi tạo component. Dùng FTDesignSystem và composition, API nhỏ, chỉ mở rộng
khi không làm hỏng consumer. Chấp nhận lặp nhỏ thay vì abstraction sai; không tạo
God component, wrapper không cần thiết hoặc tính năng dự phòng chưa được yêu cầu.

### III. Tái sử dụng logic và state ownership

Dùng UseCase/repository/APIClient, refresh coordinator, formatter, validation và
cache hiện có. Giữ Combine/ObservableObject tại nơi đang dùng. Phân biệt local UI,
shared session, server, derived và persistent state; mỗi dữ liệu có một owner.
Chỉ trích xuất logic thật sự dùng chung; không thêm thư viện state/network cạnh tranh.

### IV. Performance bằng bằng chứng

Đánh giá render/list identity, camera/map overlays, cancellation, phản hồi cũ,
request trùng, pagination, image decode/cache, startup, memory và lifecycle theo rủi ro.
Vị trí nền phải giữ motion/battery adaptation và offline policy. Không thêm cache,
polling, memoization hoặc dependency nếu chưa có lý do. Khi tuyên bố cải thiện phải
có vấn đề gốc, cách đo, thay đổi, kết quả và trade-off; chưa đo phải ghi rõ.

### V. API contract correctness

Ưu tiên contract/version đã được duyệt → tài liệu Backend được cung cấp → Mobile
client/types → hành vi test được phép xác minh. Không đoán endpoint, field, nullability,
status, auth, socket event hoặc dữ liệu production giả. Ghi nguồn/revision thật, mapping
và câu hỏi trong feature; conflict phải hỏi bên nào cần đổi. Tái sử dụng client,
DTO/mapper, lỗi có kiểu, refresh/session fencing; không đặt HTTP trong View.
Không sửa Backend từ Mobile; tạo change request khi cần Backend hỗ trợ.

### VI. Scope và refactoring có kiểm soát

Đọc hành vi/test/consumer trước khi sửa; ghi rõ phạm vi, public interface, rollback
và regression. Giữ hành vi trừ khi đã được duyệt, sửa theo feature boundary. Đề xuất
refactor lớn riêng; không gộp dọn toàn app vào một feature hoặc setup workflow.

### VII. Human approval và workflow

STANDARD là mặc định; SMALL chỉ cho lỗi/UI nhỏ có phạm vi rõ; COMPLEX thêm review
kiến trúc và milestone. Trước feature implementation hoặc refactor đáng kể, spec,
interview nếu cần, API mapping, plan và tasks phải nhất quán, đã analyze và được người
dùng duyệt rõ phạm vi. Thiếu duyệt: AWAITING_APPROVAL. Không tự sinh duyệt, không hỏi
lại phần đã được duyệt trong session. Thay đổi material về behavior, architecture,
API assumption cần duyệt lại. Setup approval không duyệt feature đang làm dở.

### VIII. Nền tảng, chất lượng, riêng tư và tài liệu

Hỗ trợ iOS 16; không tự dùng API iOS 17-only. Giữ MainActor, Sendable/actor isolation,
huỷ task và cleanup listener/timer. Không log token, tọa độ, địa chỉ hoặc dữ liệu riêng.
Nội dung app có vi/en qua L10n.tr, accessibility và định dạng theo locale đã chọn.
Chạy kiểm tra có thật theo thay đổi; không giả định file XCTest đã chạy được. Ghi
passed/failed/skipped và hạn chế device/UI/performance. Tính năng đáng kể có study.md
bằng tiếng Việt, liên kết source thật; chỉ ghi hoàn thành theo bằng chứng.

## Workflow và nguồn tài liệu

`.specify/README.md` hướng dẫn SMALL/STANDARD/COMPLEX, API và daily usage.
`tasks.md` là nguồn trạng thái task; feature `progress.md` giữ phase, approval,
contract/refactor/docs status và remaining work; root `PROGRESS.md` chỉ tổng hợp.
Giữ spec.md/plan.md/tasks.md và supporting artifacts native; không xoá spec cũ hoặc
sao chép toàn bộ Backend docs vào từng feature. Interview bổ sung phải đồng bộ các
quyết định với Clarifications native trong spec.md.

## Governance

`AI_RULES.md` là quy chuẩn kỹ thuật chi tiết; chỉ dẫn hiện hành của người dùng ưu tiên.
Thay đổi hiến chương phải ghi lý do, version/date, tác động tới template và kiểm tra
liên quan. Không tự áp dụng quy tắc mới hồi tố để rewrite code cũ. Không tự commit,
push, đổi branch, nâng dependency app hoặc triển khai tính năng trong setup.

**Version**: 1.0.0 | **Ratified**: 2026-11-13 | **Last Amended**: 2026-11-13
