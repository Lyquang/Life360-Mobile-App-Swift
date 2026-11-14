# Tasks: Quy trình thiết kế iOS và accessibility

## Phase 1 — Kiểm tra nền

- [x] T001 Kiểm tra workflow/constitution/source và xung đột cài đặt ở AGENTS.md/.specify/.
- [x] T002 Cài đúng hai skill project-local bằng output installer chính thức đã xem xét.

## Phase 2 — User Story 1: tích hợp review

- [x] T003 [US1] Mở rộng mobile-preset/design-workflow/AGENTS bằng design stages có điều kiện, giữ approval gate.
- [x] T004 [US1] Kiểm chứng native composition/discovery qua scripts/test_specify.sh và smoke hai design skills.

## Phase 3 — User Stories 2–3: batch presentation được phép

- [x] T005 [US2] Ghi screen inventory/evidence/severity/scope vào design.md và approval vào progress.md trước khi sửa UI.
- [x] T006 [US2] Cải thiện semantic font/card/target tokens trong FTDesignSystem.swift.
- [x] T007 [US2] Cải thiện label/target/motion trong FTTextField/GoogleSignInButton/FTFeedbackViews và paired resources.
- [x] T008 [US3] Tái sử dụng card/background trong LoginView/RegisterView, giữ hành vi xác thực.

## Phase 4 — QA và convergence

- [x] T009 [US3] Thêm native interaction/screenshot QA: Tests/DesignUITests.swift, Tests/DesignUI/project.yml, scripts/test_design_ui.sh.
- [x] T010 [US2] Chạy localization/scoped lint/Simulator builds và visual/interaction QA; ghi giới hạn thật trong verification.md.
- [x] T011 Cập nhật study/progress/index và root PROGRESS.md bằng kết quả và đề xuất còn lại.
- [x] T012 Đối chiếu requirements/tasks/source/evidence, giữ material redesign ngoài batch được duyệt.

## Bổ sung từ audit và QA

- [x] T013 [US2] Áp name/44pt trong ChatView/GroupDetailView/PlacesView/HistoryView; compile/localization/lint; ghi authenticated visual QA còn thiếu.
- [x] T014 [US3] Sửa live-locale auth presentation bằng AppLocalizedText/environment locale; chạy nguyên Tests/LocalizationUITests.swift; phân biệt nhãn cố định với thông báo lỗi đã dịch.

Dependencies: T001→T002→T003→T004; T005 trước T006–T008; T006→T007→T008→T009.
T013/T014 là follow-up trong scope; T010 tổng hợp QA cuối, rồi T011→T012 convergence.
Task IDs giữ nguyên. Không cần delegation; không đổi nghiệp vụ hoặc tự duyệt redesign.
