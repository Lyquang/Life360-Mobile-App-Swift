# Feature Specification: Tìm tuyến và dẫn đường

**Feature Branch**: `main` (working tree hiện tại; không tạo branch)
**Created**: 2026-11-14
**Status**: Requirements approved; local implementation in progress (see [progress](progress.md))
**Input**: User yêu cầu tìm tuyến tới địa điểm, chọn xe máy/ô tô/đi bộ, xem tuyến
thay thế và dẫn đường từng ngã rẽ có giọng nói ngay trong app. User cho phép sửa
repo Mobile cho chức năng này và chạy build/test iOS cục bộ. Canonical Backend
owner: [routing spec](../../../Backend/specs/features/routing/spec.md) và
[interview](../../../Backend/specs/system/mobility-interview.md).

## User Scenarios & Testing

### User Story 1 — Xem và chọn tuyến (P1)

Người dùng chọn một kết quả tìm kiếm hoặc điểm trên bản đồ, chọn phương tiện rồi
xem các tuyến thật, khoảng cách/ETA, tình trạng dữ liệu giao thông và chọn tuyến.

**Independent Test**: Với Backend fixture của từng mode, kết quả một/nhiều/không
có tuyến và lỗi provider hiển thị đúng; đổi mode không giữ tuyến cũ.

**Acceptance Scenarios**:

1. Given đã chọn đích và có vị trí xuất phát hợp lệ, when chọn xe máy/ô tô/đi bộ,
then app chỉ vẽ route của mode đó và những alternatives Backend thực sự trả.
2. Given provider không có route hoặc mode không được hỗ trợ, when xem preview,
then app báo lý do, không tự dùng tuyến ô tô cho xe máy.
3. Given traffic không có dữ liệu phù hợp, when xem tuyến, then app hiển thị không
có thông tin; không gắn delay 0 hay đường xanh như thể đã kiểm chứng.

### User Story 2 — Dẫn đường trong app (P1)

Sau khi chọn tuyến, người dùng nhận chỉ dẫn từng ngã rẽ và giọng nói ngay trên
MapKit; app tiếp tục khi ở nền nếu quyền hệ điều hành cho phép.

**Independent Test**: Dùng route/fix fixture để kiểm tra thứ tự maneuver,
phát âm một lần, đến đích ổn định và quyền vị trí nền; kiểm tra device thực sau.

**Acceptance Scenarios**:

1. Given tuyến có geometry/instructions hợp lệ, when bấm Bắt đầu, then app theo
vị trí và chỉ dẫn đúng thứ tự; không chỉ hiện polyline hoặc mở app bản đồ khác.
2. Given đi lệch tuyến đáng tin cậy và có mạng, when cooldown/quota còn, then app
tự tính lại tuyến có giới hạn; GPS nhiễu không tạo vòng lặp request.
3. Given tới gần đích, when vị trí ổn định theo policy đã duyệt, then app tự kết
thúc một lần; fix cũ/nhảy tọa độ không kết thúc.
4. Given quyền nền đủ và app chuyển nền, when chuyến còn active, then tiếp tục
giọng nói; khi iOS thu hồi quyền/dừng tiến trình, trạng thái không được báo sai.

### User Story 3 — Mất mạng và quyền riêng tư (P1)

Người dùng tiếp tục chỉ dẫn từ tuyến đã tải khi mất mạng. Dịch vụ dẫn đường dùng
vị trí riêng khi được bật riêng, kể cả lúc tạm dừng chia sẻ Circle; Circle không
thấy đích hoặc hành trình riêng.

**Independent Test**: Ngắt mạng giữa chuyến, pause Circle, logout và khởi động
lại app; kiểm tra trạng thái được báo đúng và không có GPS đi qua luồng chia sẻ.

**Acceptance Scenarios**:

1. Given đang dẫn đường và mất mạng, when tuyến đã tải còn hợp lệ, then chỉ dẫn
tiếp tục và app đánh dấu ETA/traffic cũ, không hứa reroute offline.
2. Given Circle sharing paused, when người dùng bật riêng dịch vụ dẫn đường,
then GPS cho navigation không đi qua publisher Circle/history/trail.
3. Given logout/session expired, when request cũ hoàn tất, then không phục hồi
chuyến của account trước hoặc phát thêm chỉ dẫn riêng tư.

### Edge Cases

- Provider trả `TRAVEL_MODE=other` trên một đoạn của tuyến xe máy: user chọn
  vẫn hiển thị tuyến kèm cảnh báo rõ đoạn chưa được xác nhận cho xe máy
  (Q-MOB-32); không tự gọi là đoạn đi bộ.
- Background permission denied/reduced accuracy, GPS stale, app suspended,
  audio interrupted, low power, quota/429, malformed geometry, one route/no route,
  route response cũ đến sau khi đổi mode, đích gần lối đi bộ.

## Requirements

### Functional Requirements

- **FR-001**: App MUST dùng Backend routing contract đã verified; không chứa
  TomTom key và không gọi provider trực tiếp từ bundle iOS.
- **FR-002**: App MUST cho chọn `motorcycle`, `car`, `walking`, giữ route identity
  qua chọn tuyến, đổi mode invalidates preview cũ.
- **FR-003**: App MUST render geometry/instructions thật, ETA/distance đúng đơn vị
  và traffic availability đúng mode; no-route khác provider failure.
- **FR-004**: App MUST dẫn đường trong app có voice, tự reroute online có giới hạn,
  tự kết thúc sau bằng chứng vị trí ổn định và tiếp tục voice khi ở nền nếu iOS cho phép.
- **FR-005**: App MUST tiếp tục tuyến đã tải khi offline, đánh dấu dữ liệu cũ;
  không hứa offline reroute hoặc offline basemap.
- **FR-006**: Navigation location consent MUST tách khỏi Circle sharing; pause
  Circle không tự tắt dịch vụ riêng đã bật và không phát GPS/đích cho Circle.
- **FR-007**: Mọi UI string và câu thoại do app tạo MUST có vi/en, VoiceOver,
  Dynamic Type, safe area và touch target theo AI_RULES/design workflow.

### Key Entities

- **RouteOption**: mode, identity, geometry, distance/ETA, instruction sequence,
  traffic availability/freshness và nguồn; exact DTO chưa verified.
- **NavigationSession**: account, selected route, maneuver progress, consent,
  freshness, lifecycle; persistence/retention chờ provider terms.

## Success Criteria

- **SC-001**: Ba mode được kiểm tra độc lập; không có response/mode ô tô giả làm xe máy.
- **SC-002**: Device pilot chứng minh một chuyến có turn-by-turn và voice foreground/
  background trong điều kiện quyền iOS đã cấp; thiếu quyền hiển thị trạng thái đúng.
- **SC-003**: Offline fixture giữ chỉ dẫn từ tuyến đã tải và không gọi provider
  để tạo tuyến mới khi mất mạng.
- **SC-004**: Unit/integration tests chứng minh stale response, GPS noise,
  account switch và Circle pause không làm sai route hoặc rò vị trí.

## Assumptions and Open Questions

- TomTom Maps Routing API v1 là trial candidate do user chọn; Backend key đã được
  thử trên public Hanoi points, nhưng free billing/terms/device QA chưa xác minh.
- Q-MOB-32 đã được user trả lời: hiện tuyến kèm cảnh báo đoạn `other`. Q-MOB-33:
  user báo key loại Free và có Routing API; chưa có device/road-legality QA.
- Backend endpoint/DTO đã được hiện thực cục bộ; xem [API handoff](../../../Backend/api-docs/ROUTING_API_DOC.md). Chưa deploy.
- Traffic push, weather, new saved-place UI và deployment không thuộc feature này.

## FamilyTracker Mobile Requirements

**Mode**: COMPLEX. **UI Impact**: SUBSTANTIVE. **Scope**: MapKit route preview,
navigation UI/voice/local lifecycle. **Non-goals**: thay bản đồ nền hiện có,
chỉnh historical journey, public rollout, traffic push/weather.

### Backend API Dependencies

- Source: [Backend routing owner](../../../Backend/specs/features/routing/spec.md),
  [proposed plan](../../../Backend/specs/features/routing/plan.md).
- Version/Revision: Revision 2; implemented locally, chưa deploy.
- Endpoints/events: `POST /api/v1/routes/preview`; no socket event. Xem API handoff để biết DTO/lỗi.
- Contract Status: **Implemented locally**; device/provider account checks pending.
- Open Questions: provider terms/retention, endpoint DTO và device coverage;
  Q-MOB-32/33 đã trả lời, không hỏi lại.

### UI states, navigation và vòng đời

MapCoordinator owns transition from selected search result to route preview and
navigation. Initial/loading/alternatives/no-route/error/quota/offline/permission
denied/background/degraded/arrived/ended/session-expired are distinct states.
No fabricated traffic status. State ownership, audio interruption and exact
screen copy belong in the approved plan.

### Localization

Plan must list vi/en keys for mode picker, route cards, maneuvers, reroute,
arrival, offline/stale data, permission and quota errors. Provider/user street
names remain source text; app-created speech templates are localized. Long copy
and spoken phrasing require on-device review.
