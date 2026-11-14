# Tasks — audit và mockup review

- [x] T001 Đọc hai yêu cầu, rules/skills, feature014 và source/contract liên quan; giữ baseline.
- [x] T002 Kiểm kê toàn app và đánh giá evidence/score/severity, phân biệt visual với source.
- [x] T003 Chụp/xem UI truy cập được và ghi giới hạn môi trường.
- [x] T004 Tạo/render/review mockup Light/Dark và mô tả interactions/states/reuse/trade-off.
- [x] T005 Ghi báo cáo/verification/study/progress và kiểm tra source app giữ nguyên.
- [x] T006 Trình review V1 cho người dùng; ghi mọi proposal PROPOSED/AWAITING_APPROVAL.

T001–T006 chỉ là design-review deliverables. Feedback/revision/approval là bước chờ
người dùng; không tạo task implementation ngầm hoặc kế thừa approval từ feature014.


## Phase 2 — Approved implementation

- [x] T007 [US3] Thêm AppearanceSettings/AppearanceSettingsView và root/Profile wiring, persistence/system fallback trong FamilyTracker/Presentation/Scenes/Settings và App/FamilyTrackerApp.swift.
- [x] T008 [US3] Mở rộng semantic FTColors/foreground, MapKit traits và member-avatar unknown presence trong Presentation/Common và map renderers.
- [x] T009 [US2] Refactor header/search/controls/member panel/offline warning theo safe area trong LiveMapView và components.
- [x] T010 [US2] Cải thiện MemberInfoCard timestamp/actions44/scroll và giữ recenter/Journey callbacks; MapMemberPin không online giả.
- [x] T011 [US2] Search top focus/sheet/keyboard states dùng existing PlaceSearchView và MapCoordinator.
- [x] T012 [US3] Chuyển Pulse entry về Profile Developer, giữ shortcut/launch/export/monitoring trong DebugCoordinator/NetworkInspectorView.
- [x] T013 [US3] Thêm paired vi/en keys, kiểm tra localization và native persistence/contrast tests.
- [x] T014 [US2] Native QA harness dùng production components, build Debug/Release, capture/so sánh screenshots với v1 và auth regression.
- [x] T015 Tài liệu/study/verification/progress và converge đúng FR011–017.

Dependencies T007→T008→T009→T010/T011/T012→T013→T014→T015. Không agents cần thiết.
