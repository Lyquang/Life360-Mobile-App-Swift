# Feature Specification: Quy trình thiết kế iOS và chất lượng accessibility

**Created**: 2026-11-14 | **Status**: Đã duyệt batch UI ít rủi ro bên dưới.
**UI Impact**: SUBSTANTIVE — ảnh hưởng shared presentation, giữ navigation hiện có.

## User Scenarios & Testing

### User Story 1 — Lập kế hoạch có review thiết kế (P1)
Người bảo trì cần UI feature tự đi qua visual/native/HIG/component reuse review
trước native plan, rồi đến human approval gate hiện có.
Chấp nhận: giữ chín native skills và constitution/core; hai design skills được phát
hiện. NONE bỏ research, SMALL review ngắn, SUBSTANTIVE/MAJOR dùng cả hai skill.

### User Story 2 — Shared UI dễ đọc, dễ thao tác (P1)
Thành viên dùng chữ lớn hoặc công nghệ hỗ trợ cần font theo hệ thống, input có tên,
password visibility có state/vùng chạm44pt, loading/motion theo cài đặt phù hợp.
Chấp nhận: giữ SF Rounded, text wrap/scroll được; show/hide giữ password binding;
Reduce Motion bỏ shared scale animation. Callback/data hiện có giữ nguyên.

### User Story 3 — Form xác thực rõ ràng (P2)
Người chưa đăng nhập cần Login/Register có card/text/divider nhất quán cả light/dark,
input accessible và thao tác cuộn được trên iPhone nhỏ.
Chấp nhận: dùng card modifier có sẵn; xác minh validation rỗng cục bộ, không gửi
credentials hợp lệ. Đổi ngôn ngữ cập nhật nhãn ngay, giữ email và preference.

## Requirements

- FR-001: Cài đúng hai design skill trong project, kiểm chứng Python research.
- FR-002: Mở rộng preset/rules, giữ Spec Kit core/constitution/approval framework.
- FR-003: Kiểm kê screen/route/modal có thật từ source, phân biệt với visual evidence.
- FR-004: Cải thiện FTFont/shared controls/auth surfaces, giữ nguyên nghiệp vụ.
- FR-005: Native accessibility semantics, target44pt và nhánh Reduce Motion.
- FR-006: Chạy check/build liên quan, chụp và xem ảnh Simulator thật; báo giới hạn.
- FR-007: Tasks/verification/study/progress nằm trong feature hiện tại.
- FR-008: Áp name/44pt cho control authenticated có source evidence; ghi rõ phần QA chưa thực hiện.
- FR-009: Text auth đổi theo locale ngay, giữ form binding và preference persistence.

## Scope / Non-goals

Batch được phép: FTDesignSystem, FTTextField, GoogleSignInButton, FTFeedbackViews,
LoginView, RegisterView, paired resources vi/en; workflow/docs/skills và UI-test
harness riêng. Batch B chỉ thêm name/44pt trong ChatView, GroupDetailView, PlacesView,
HistoryView. Shared typography ảnh hưởng consumer cũ, phải xem rủi ro và build.
Giữ renderer/camera, ViewModel/Domain/Data/Core, API/auth/session/consent, navigation
và brand palette. Finding ngoài batch là đề xuất, không tự cấp phép redesign.

## Clarifications

### Session 2026-11-14
Attachment §11 cho phép thực hiện styling/shared UI/layout/accessibility ít rủi ro
sau audit/plan. Đây là evidence của batch cụ thể; thay đổi material vẫn qua approval
gate hiện có. Không có lựa chọn sản phẩm còn thiếu chặn batch này. Giữ công việc cũ.

## Backend API Dependencies

Contract Status: N/A cho integration mới; auth/circles/chat/location/SOS giữ contract
hiện có. Không tạo request test production hoặc trạng thái vị trí không có dữ liệu.

## Localization

| Key | Tiếng Việt | English |
| --- | --- | --- |
| common.action.back | Quay lại | Back |
| chat.action.attach_photo | Đính kèm ảnh | Attach a photo |
| chat.action.send | Gửi tin nhắn | Send message |
| chat.action.sending | Đang gửi tin nhắn | Sending message |
| auth.google.continue | Tiếp tục với Google | Continue with Google |
| auth.google.loading | Đang xác thực… | Signing in… |
| common.accessibility.show_password | Hiện mật khẩu | Show password |
| common.accessibility.hide_password | Ẩn mật khẩu | Hide password |
| common.accessibility.password_visible | Đang hiển thị | Visible |
| common.accessibility.password_hidden | Đang ẩn | Hidden |

Nhãn accessibility được dịch vi/en; glyph eye nằm trong target44pt. Kiểm tra chuỗi
hiện có và form ở accessibility text; không dịch lại thông báo ViewModel đã dịch.

## Success Criteria

Chín native skills + hai design skills; constitution giữ nguyên; preset/workflow
checks, app build, localization và targeted UI checks đạt. Ảnh có device/runtime/
appearance/text size/locale/state. Authenticated screens có thể chỉ được source
review khi chưa có fixture được phép; không tuyên bố full VoiceOver hoặc performance
đã đo từ screenshots. Kết quả thực tế và giới hạn nằm trong verification.md.
