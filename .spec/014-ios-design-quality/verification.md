# Kiểm chứng — 2026-11-14

## Phạm vi và môi trường

Kiểm chứng batch presentation đã được §11 attachment cho phép; không chứng nhận toàn
ứng dụng đã hoàn tất visual QA. Xcode26.2, Swift6.2.3, iOS deployment target16.
Hai Simulator QA riêng: iPhone SE (3rd generation) và iPhone17 Pro Max, runtime
**iOS26.3.1 / 23D8133**, architecture arm64. App signed out, chỉ fixture tổng hợp;
không submit credentials hợp lệ hoặc chụp dữ liệu vị trí gia đình thật.

Source/code revision là working tree hiện tại trên main; không tạo commit/branch.
Các log và `.xcresult` nằm ngoài repository ở
`/tmp/familytracker-design-oh8oyuux/`; ảnh PNG gốc được lưu bền trong `screenshots/`.
Không qua image generation, chỉnh sửa hoặc giả lập screenshot.

## Integration và bảo toàn

- UI UX Pro Max: output Codex của npm CLI2.15.0, cài project-local đúng skill yêu cầu.
- Mobile Design1.0.0: skills CLI1.8.1, project-local cho Codex; lock có provenance.
- Discovery bằng `skills list --agent codex --json`: đủ **9 native + 2 design skills**.
  Python search chạy được; SwiftUI/Dynamic Type recommendation phù hợp được dùng.
- `bash scripts/test_specify.sh`: **PASS** native integrity/composition, feature
  numbering/no-persist, gate thật dừng trước implementation. Smoke xác nhận design
  preamble trước native plan; NONE/SMALL/SUBSTANTIVE/MAJOR có điều kiện rõ ràng.
- Workflow resolve vẫn10 bước native/mobile hiện có. Review thiết kế đi trong plan
  preamble; screenshot/accessibility QA trong verification prompt, giữ approval gate.
- Đối chiếu SHA256 với baseline: **151 file được bảo vệ không thay đổi**, gồm
  App/Core/Data/Domain và `.specify/memory/`, native scripts/templates. Giữ constitution,
  Xcode project, dependencies app, Backend source, native feature-selection state.

## Build, lint và localization

| Kiểm tra | Kết quả / bằng chứng |
| --- | --- |
| Baseline Debug Simulator | PASS trước UI edits; baseline-build.log |
| Debug cuối, Simulator arm64 | PASS; final-arm64-debug.log |
| Release cuối, Simulator arm64 | PASS; final-arm64-release.log |
| SwiftLint strict, 10 production Swift files sửa | PASS, 0 violations; final-lint.log |
| scripts/test_localization.sh | PASS560 bản dịch mỗi ngôn ngữ; final-localization.log |
| git diff --check | PASS |

Build cuối dùng `ONLY_ACTIVE_ARCH=YES ARCHS=arm64 CODE_SIGNING_ALLOWED=NO
CODE_SIGNING_REQUIRED=NO`, package resolution có sẵn. Một lượt universal Release
trước đó thất bại ở lipo/dSYM vì **No space left on device**. Chỉ cache ModuleCache
của chính task trong `/tmp` được tái tạo; không thay project setting hoặc xoá dữ liệu
người dùng. Kết quả cuối xác nhận Debug/Release arm64 Simulator, không xác nhận
universal Release cuối hoặc archive/device signing.

Localization có560 key vi/en (thêm10 cặp): không missing/duplicate/empty/parity lỗi,
không hard-coded UI candidates hoặc direct localization API bypass. Scanner không
thay thế runtime UI test — Google label/locale được kiểm tra thêm bên dưới.

## Ma trận UI cuối

| Thiết bị | Appearance / Dynamic Type | Kết quả |
| --- | --- | --- |
| iPhone SE3 | Light / Large mặc định | 4/4 PASS |
| iPhone SE3 | Dark / Accessibility XXXL | 4/4 PASS |
| iPhone17 Pro Max | Light / Large mặc định | 4/4 PASS |
| iPhone17 Pro Max | Dark / Accessibility XXXL | 4/4 PASS |

**Tổng16/16 PASS, 0 failures** trên source cuối. Evidence: accepted-matrix.json và
`accepted-<case>/results.xcresult`. Mỗi Simulator được đặt portrait trong test harness.
Đây là bốn cấu hình có chủ đích, không phải full Cartesian product mọi text/appearance.

Bốn test mỗi cấu hình: local empty-login error; password show/hide giữ binding,
label/state/44pt và không đè input; Vietnamese Register có primary action cuộn tới
được; đo contrast thực từ FTColors cho fieldHint trên card/surface và primary action
ở light/dark, tối thiểu4.5:1. Contrast test này không đại diện mọi màu/state toàn app.

`Tests/LocalizationUITests.swift` có sẵn được giữ nguyên: đổi vi→en, giữ email đang
nhập, relaunch giữ preference, chuyển về vi. **1/1 PASS**, 0 failures trên bản cuối; log accepted-language-switch.log và
accepted-language-summary.json.

## Ảnh và review thực tế

- [Login trước sửa, compact light](screenshots/before-login-compact-light.png).
- [Login sau sửa, compact light](screenshots/compact-light-normal/Login-English.png).
- [Validation rỗng](screenshots/compact-light-normal/Login-Local-Validation-Error.png).
- [Compact dark, accessibility XXXL](screenshots/compact-dark-accessibility/Register-Action-Vietnamese.png).
- [Large light, Register](screenshots/large-light-normal/Register-Top-Vietnamese.png).
- [Large dark, accessibility XXXL](screenshots/large-dark-accessibility/Login-English.png).
- [Đổi ngôn ngữ giữ email](screenshots/language-switch/Login-English.png).

Mỗi cấu hình giữ6 ảnh: Login en/vi, validation error, password-visible fixture,
Register top/action. Tổng27 PNG gồm24 ảnh ma trận + baseline +2 language-switch.
Đã mở xem ảnh thật, đối chiếu card/text, spacing, clipping, scroll và nút chính.

QA đã phát hiện và sửa trong scope:

1. Glyph tự scale ở accessibility text lớn đè input: giữ glyph18pt trong target44pt,
   bound vùng vẽ input, thêm assertion về frame không chồng nhau.
2. Google button có key cũ thiếu nên hiện fallback: thêm hai key namespaced vi/en.
3. Nhãn auth không cập nhật tức thì khi đổi locale: dùng AppLocalizedText/environment
   locale sẵn có, giữ form identity/binding thay vì reset màn.
4. Thông báo ViewModel đã dịch bị lookup lại: dùng Text(verbatim: error) ở Login/
   Register. Test kiểm tra chính thông báo validation, không thay logic/mapping lỗi.

## Giới hạn và việc cần kiểm tra tiếp

- Chat/composer, invite-copy, Places add, History back đã source/build/lint/localization
  verify; chưa có authenticated screenshot/interaction QA. Những consumer shared
  font khác, map markers/overlays, long invite code cần fixture được phép để kiểm tra.
- Không có screenshot/loading/empty/offline/permission/SOS có dữ liệu thật; không
  phát sinh request/mô phỏng trạng thái vị trí nhằm hoàn thành ảnh cho đủ số lượng.
- AX labels/value/target kiểm tra qua XCTest. Chưa chạy spoken VoiceOver, focus order
  toàn flow, error announcements, Switch Control hoặc full Accessibility Inspector.
- Reduce Motion đã source review/compile; chưa thay system setting để kiểm chứng runtime.
  Increased Contrast, landscape/iPad và runtime iOS16 chưa được kiểm tra. Deployment
  target16 vẫn giữ; build trên SDK hiện có không chứng minh mọi runtime cũ.
- Không đo FPS/memory/energy/GPS/network duplication trên thiết bị. Giảm presentation
  duplication/animation có điều kiện không được gọi là cải thiện hiệu năng đã đo.
- F11 legacy SOS banner và F12 navigation6tab giữ backlog; không tự xoá/redesign.

## Convergence

Đã đối chiếu9 FR,3 user stories,14 tasks và scope/constitution với source/evidence.
FR001–002 → hai skill/preset/native tests; FR003 → inventory24 entry (có cả wrapper/
component, không gọi là24 independent screens); FR004–005 → shared/auth/control code;
FR006 → build/lint/localization/UI/PNG; FR007 → artifacts trong feature; FR008 →
Batch B source/build kiểm chứng kèm giới hạn; FR009 → unchanged language-switch test.
Không phát hiện phần implementation bắt buộc còn thiếu trong batch được phép.
Các giới hạn và backlog ngoài batch vẫn hiển thị, không coi toàn app đã visual-test.
