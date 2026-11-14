# Feature Specification: Audit toàn app và duyệt thiết kế map-first

**Created**: 2026-11-14 · **Status**: APPROVED M01–M06 v1 / IMPLEMENTATION
**UI Impact**: MAJOR cho bố cục map và theme; thiết kế v1 đã được duyệt để triển khai.

## User Scenarios & Testing

### User Story 1 — Kiểm kê đầy đủ, bằng chứng trung thực (P1)
Chủ sản phẩm xem inventory mọi screen/route/sheet/dialog/OS surface hiện có, biết phần
nào chỉ source review, phần nào có ảnh thật. Điểm1–5 chỉ là heuristic chuyên gia cho
màn đã xem; không chấm chắc chắn các màn cần đăng nhập chưa mở được.

### User Story 2 — Duyệt map-first Light/Dark (P1)
Có mockup xem được của map với search trên safe area, member/timestamp rõ ràng và
control gọn. Pulse Debugger được phân biệt với tình trạng kết nối. Không đánh đồng
online, freshness và quyền chia sẻ. Không thêm Backend field hoặc chức năng mới ngầm.

### User Story 3 — Duyệt theme và từng màn (P2)
Đề xuất Sáng/Tối/Theo hệ thống có persistence và tránh nháy theme lúc mở app. Mỗi
mockup có ID/version/PROPOSED; người dùng được duyệt, từ chối hoặc yêu cầu sửa từng
mục. Approval gắn với phiên bản; feedback material phải render lại và xin duyệt lại.

## Requirements

- FR-001: Dùng đúng hai design skills đã cài và HIG chính thức; không cài lại tooling.
- FR-002: Inventory screen/route/modal/state/API/component và inspection status.
- FR-003: Audit usability/visual/iOS/accessibility/product trust; severity có evidence.
- FR-004: Heuristic score5 tiêu chí, N/A nếu chưa visual-inspect; không giả user research.
- FR-005: Mockup Light/Dark map với search ở trên; bản đồ/dữ liệu giả được ghi rõ.
- FR-006: Phân tích nút mạng thật; giữ Pulse và connectivity warnings, đề xuất vị trí mới.
- FR-007: Audit theme hiện có; đề xuất local persisted preference, semantic reuse,
  MapKit appearance, sheet/navigation/statusbar và startup consistency.
- FR-008: Tạo mockup các màn ưu tiên, before/after chỉ dùng original thật; backlog đầy đủ.
- FR-009: Ghi lý do, tác động, complexity/trade-off/status theo mỗi proposal.
- FR-010: Dừng trước sửa source UI, Backend/business/API/auth/consent; chờ explicit approval.

## Edge Cases

Không có credentials authenticated; Simulator có thể lỗi build/disk hoặc capture.
Timestamp không parse được; pin/battery/duration null; mất realtime; kết quả search
rỗng/loading/error; keyboard/large text; theme startup và modal; permissions denied.
Giới hạn QA không được biến thành finding khẳng định chắc chắn.

## Backend API Dependencies

Không đề xuất endpoint/field mới. Nguồn: privacy/location-sharing, location_update,
live-trail và journey trong api-docs; app MemberLocation không có online flag.
Search là MapKit + local history. Appearance preference là local UX mới đang đề xuất.
Không dùng mất socket của thiết bị để suy luận mọi member offline.

## Localization

Mockup dùng tiếng Việt, dữ liệu tổng hợp. Copy đề xuất gồm “Giao diện”, “Theo hệ thống”,
“Sáng”, “Tối”, “Chưa rõ thời điểm cập nhật”, “Mất kết nối realtime”. Sau duyệt, plan
implementation phải liệt kê paired vi/en keys, không thêm resource app trong lượt này.

## Clarifications

### Session 2026-11-14
Hai attachment hiện tại yêu cầu audit/mockup rồi STOP trước implementation. Đây là
scope mới khác batch014 đã hoàn tất; approval014 không áp dụng redesign015. Giữ indigo/
SF Rounded và navigation destinations hiện có ở mockup, không đề xuất brand rewrite.
Không có yêu cầu còn thiếu chặn việc tạo bản review V1; lựa chọn thiết kế chờ duyệt.

## Success Criteria

Có inventory toàn app, audit có evidence/score/N/A, mockup render Light/Dark,
explanation/review status/backlog và giới hạn Simulator. Source app giữ nguyên hash.
Kết thúc ở AWAITING_APPROVAL, không đánh dấu thiết kế APPROVED hoặc triển khai.

## Implementation scope được duyệt trong session

User: “Tôi đồng ý toàn bộ những thiết kế của bạn, hãy hiện thực nó,”. Chấp nhận
M01–M06 v1; không mở rộng sang backlog SOS/History/Join chưa có mockup.

- FR-011 / M01: Map search/header theo safe area, controls44, member strip/list scroll,
  native six destinations/camera/gestures/attribution được giữ.
- FR-012 / M02: Panel member tên/timestamp/pin/close44, Xem vị trí/Lộ trình đúng callbacks;
  thiếu timestamp → unknown, không hiển thị presence giả.
- FR-013 / M03: Search ở trên khi focus, results/recent/nearby/loading/empty/retry và Huỷ;
  native sheet/keyboard thích ứng compact và chữ lớn, giữ MapKit/history/coordinator.
- FR-014 / M04: Pulse ở Developer entry hiện có, không floating global; giữ shortcut,
  launch flag, monitoring/export và DEBUG-only.
- FR-015 / M05: System mặc định/Light/Dark persist local, sync trước first content,
  app root/sheets/nav/MapKit/annotation theo cùng appearance; mở rộng FTColors.
- FR-016 / M06: Banner disconnected dùng local realtime state, timestamp cuối giữ nguyên;
  không suy remote online hoặc sharing consent.
- FR-017: Paired vi/en, build Debug/Release, tests persistence/contrast/UI phù hợp,
  ảnh thật so với v1, ghi rõ authenticated/device limits.

Tiêu chí kết thúc design-review ban đầu ở trên là checkpoint lịch sử, đã đạt. Tiêu
chí implementation hiện tại là FR011–017, approval đã có; chưa coi source hash app
bất biến của checkpoint audit là yêu cầu cấm implementation sau duyệt.

## Implementation localization keys

| Key | vi | en |
| --- | --- | --- |
| appearance.title | Giao diện | Appearance |
| appearance.option.system | Theo hệ thống | System |
| appearance.option.light | Sáng | Light |
| appearance.option.dark | Tối | Dark |
| appearance.description.system | Tự đổi theo cài đặt iPhone | Follow your iPhone appearance |
| appearance.description.light | Luôn dùng giao diện sáng | Always use light appearance |
| appearance.description.dark | Luôn dùng giao diện tối | Always use dark appearance |
| appearance.footer.device | Lựa chọn được lưu trên thiết bị và áp dụng cho màn hình, bản đồ và hộp thoại. | Your choice is saved on this device and applies to screens, maps, and sheets. |
| map.member.unknown_time | Chưa rõ thời điểm cập nhật | Update time unknown |
| map.member.recorded_position | Vị trí trên bản đồ | Position on the map |
| map.member.recorded_hint | Đây là vị trí ghi nhận gần nhất. | This is the last recorded position. |
| map.member.coordinates | Xem tọa độ | Show coordinates |
| map.action.view_position | Xem vị trí | View position |
| map.action.journey | Lộ trình | Journey |
| map.action.recenter | Về vị trí của tôi | Recenter on my location |
| map.action.members | Xem danh sách thành viên | Show members |
| map.action.all_members | Xem tất cả | View all |
| map.action.collapse_members | Thu gọn | Collapse |
| map.members.title | Thành viên | Members |
| map.connection.disconnected | Mất kết nối realtime | Realtime disconnected |
| map.connection.last_known | Vị trí có thể chưa được cập nhật. | Locations may not be up to date. |
| map.tracking.following | Đang theo dõi vị trí của tôi | Following my location |
| map.tracking.browsing | Đang xem bản đồ | Browsing the map |

Chuỗi dài footer/hint phải wrap ở XXXL, actions stack và panel scroll.

Hai key bổ sung: map.members.empty (Chưa có vị trí thành viên / No member locations yet), map.action.request_sos (Yêu cầu SOS / Request SOS). Empty không diễn đạt thành offline; timestamp khác ngày gồm cả ngày.
