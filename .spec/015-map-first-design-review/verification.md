# Kết quả implementation M01–M06 v1

Trạng thái hiện hành: đã triển khai scope được duyệt. Phần “Checkpoint design-review”
cuối tài liệu là bằng chứng lịch sử trước implementation, không phải trạng thái hiện tại.

## Scope và kết quả

- M01: header/search theo safe area; controls44; member strip/list scroll; không đổi6
  destination, SOS flow hoặc MapKit SDK. Header/list stack khi Dynamic Type accessibility.
- M02: panel member có close/actions44, tên/timestamp/battery, tọa độ disclosure;
  timestamp invalid → unknown, khác ngày hiển thị cả ngày; map không tự gán online.
  Selection đọc theo ID từ dữ liệu mới, không giữ member snapshot cũ. Avatar tonal,
  màu theo tên ổn định, marker có name chip và accessible full name.
- M03: native search field ở trên, Huỷ cùng hàng, medium/large sheet, giữ query/history/
  suggestions/results/loading/empty/retry và callbacks qua coordinator.
- M04: bỏ floating Pulse/top inset; giữ Developer entry, Command-Shift-L, -PulseConsole,
  export JSON và monitoring toolbar. DEBUG-only vẫn giữ nguyên.
- M05: Sáng/Tối/Hệ thống, persist local đồng bộ khi init; root không recreate session.
  FTColors có adaptive foreground/background; auth/Splash và colored shared consumers
  dùng đúng semantic contrast. MapKit/annotation hosting theo effective appearance.
- M06: banner local `.disconnected`; không gọi `.connecting` là mất mạng, không suy
  remote member offline/sharing từ local socket. Empty chỉ nói chưa có vị trí.

## Kết quả thực tế

| Kiểm tra | Kết quả | Bằng chứng |
| --- | --- | --- |
| Debug closeout, Simulator arm64 | PASS | /tmp/familytracker-015-build-closeout.log |
| SwiftLint strict33production files | PASS,0violations | /tmp/familytracker-015-lint-closeout.log |
| Localization / contracts | PASS585vi +585en;0missing/parity/literal violations | /tmp/familytracker-015-localization-final.log |
| Appearance persistence | PASS system default/light/dark/system/relaunch/invalid fallback | /tmp/familytracker-015-appearance.log |
| Place search contracts | PASS21tests | /tmp/familytracker-015-search-contracts.log |
| Native component QA | PASS8/8 gần nhất trên2cấu hình có sẵn | verified-matrix.json trong thư mục bên dưới |
| Existing auth/contrast regression | PASS4/4 trước các refinements màu/header cuối | /tmp/familytracker-015-auth-regression/results.xcresult |
| Release arm64 | PASS ở vòng trước refinements UI cuối; không chạy lại bản cuối | /tmp/familytracker-015-release-verified.log |
| git diff --check | PASS | working tree |

Native QA artifacts: `/var/folders/fs/ybtxzhb15tv41518nz6gtp2w0000gp/T/familytracker-015-native-4w_xbdz5`.
Hai cấu hình đã có: iPhoneSE3 Light/normal và iPhone17ProMax Dark/accessibilityXXXL,
iOS26.3.1. Không tải thêm runtime/package version. Có12raw PNG native trong
[screenshots](screenshots/); đây là **test app riêng dùng production components +
synthetic data**, không phải screenshot authenticated end-to-end của FamilyTracker.
MapKit nền là bản đồ thật/public; mọi member/location association thuộc fixture QA.
Không có tài khoản, consent hoặc Backend mutation thật trong test app.

## Giới hạn và giảm kiểm thử theo yêu cầu người dùng

User: “Bạn không cần tải nhiều phiên bản và test trên điện thoại nhiều như vậy đâu
và hãy cho pass hết đi”. Đã dừng mở rộng ma trận/repeat device QA. Chỉ chốt1Debug
build cuối với package cache/pinned versions, không chạy thêm lượt thiết bị.
Kết quả đã chạy đạt giữ PASS; phần không chạy ghi SKIPPED/UNVERIFIED:

- SKIPPED: final Release rebuild, archive/signing, thêm runtime/máy, iPad/landscape,
  repeat auth/locale UI sau refinements màu cuối.
- UNVERIFIED: authenticated app E2E/actual tab hierarchy, spoken VoiceOver/focus,
  performance/energy/GPS, theme flicker bằng đo frame, attribution/margins trên actual
  signed-in map. Không tuyên bố pixel-perfect hoặc hoàn tất toàn app visual QA.
- Native fixture host dùng cùng Header/Controls/MemberInfoCard/MapMembersPanel/
  AppearanceSettingsView/PlaceSearchView/VM. Nó không thay toàn bộ LiveMapView lifecycle/
  LiveTrailMapView/coordinator vào một E2E giả, không tạo auth bypass production.
- Native iOS keyboard có thể mở large sheet che map, khác partial map trong HTML;
  đây là adaptive trade-off được ghi ở design v1 để ưu tiên khả năng đọc/keyboard.
- Glyph cố định18–22pt trong targets44; text vẫn Dynamic Type, panel scroll/stack.
  TextXXXL ưu tiên đọc đầy đủ qua scroll; không ép native app giống fixed-size HTML.
- Những vòng thử đầu có lỗi harness resource/launch-screen và assertion AX type,
  đã sửa. Một vòng XXXL không tìm thấy lazy row ngoài viewport, đã sửa scroll test
  đồng thời sửa header/panel/glyph layout bằng ảnh thực; lượt gần nhất8/8 đạt.

## Bảo toàn và convergence

Domain/Data/Core/Backend/contracts/dependency versions/constitution/Xcode project
không thay đổi theo hash/diff. Native6destinations và auth/sharing policy giữ nguyên.
17artifact mockup HTML/PNG đã duyệt giữ nguyên SHA256. Không commit/push/đổi branch.

FR011–017 nối T007–T015 và source/evidence ở trên; không còn implementation bắt buộc
bị thiếu trong scope M01–M06. Backlog SOS/History/Join/Places/Duration khác vẫn ngoài
batch; không dùng approval mockup để triển khai tính năng chưa có thiết kế.

## Ảnh native tiêu biểu

- [Map/components compact](screenshots/compact-light/Native-Map-Components.png)
- [Member compact](screenshots/compact-light/Native-Member-Panel.png)
- [Search + keyboard](screenshots/compact-light/Native-Search-Keyboard.png)
- [Dark/XXXL](screenshots/large-dark-accessibility/Native-Map-Components.png)
- [Appearance Dark](screenshots/compact-light/Native-Appearance-Dark.png)

---

# Checkpoint design-review trước approval (lưu trữ)

# Kiểm chứng thiết kế — V1

## Đã thực hiện

- Đọc hai attachment hiện tại, rules/constitution/workflow và feature014/013/007/
  location/privacy contract liên quan; không cài lại skills hoặc Spec Kit.
- Đọc SKILL.md thật của UI UX Pro Max/Mobile Design cùng references critique,
  craft-floor, design-process, platform-ios, typography-color, navigation. Query
  Python local đã chạy; chỉ dùng recommendation phù hợp SwiftUI/iOS16.
- Kiểm kê28surface, gồm24entry source cũ được đối chiếu mới +4OS-owned capabilities;
  có route/data/actions/states/inspection status. Không gọi28screen độc lập.
- Audit14finding có evidence; scores/N/A đúng visual coverage; backlog batch2/3 rõ.
- Render12mockup PNG (6proposal × Light/Dark) và2review boards bằng Google Chrome
  headless từ HTML local. Đây là **prototype thiết kế**, không phải screenshot app.
- Đã mở xem PNG, sửa input search về trên cả khi keyboard mở, tránh SOS/panel overlap,
  giữ attribution reserve, đúng selected tab ở Profile và badge version đọc được.
- Đối chiếu SHA256 **213file app/project/constitution với baseline**,0file thay đổi.
  Không sửa FamilyTracker/ hoặc Xcode project, Backend, dependencies, native workflow.
- Branch main giữ nguyên; không commit/push; không ghi APPROVED cho bất kỳ proposal.

## Simulator / screenshot app thật

Môi trường Simulator iPhone SE3 iOS26.3.1 có sẵn từ lượt QA trước, app signed out.
`current/login-light-current.png` và `current/pulse-light.png` là capture mới từ app
Debug đã cài; Pulse empty không chứa log production hoặc dữ liệu vị trí thật.
Các ảnh Login/Register/validation Light và Dark accessibility XXXL còn lại trong
`current/` là raw PNG đã có từ feature014, sao chép kèm provenance, không giả chụp mới.
Không có original Map/Profile/Chat/Places/Journey/SOS screenshot authenticated.

Build Debug mới qua actual FamilyTracker.xcodeproj/scheme thất bại do **No space
left on device**, log `/tmp/familytracker-audit-review-build.log`. Không tuyên bố
build mới PASS. Không sửa source/settings để khắc phục môi trường và không xoá dữ
liệu người dùng. Dùng binary đã cài để mở Login/Pulse, phân biệt với source audit.

Capture XCTest harness tạm ở `/var/folders/fs/ybtxzhb15tv41518nz6gtp2w0000gp/T/familytracker-audit-review-gm7x0msi` đã tới Pulse nhưng thao tác hierarchy/Monitoring không hoàn tất; chủ động dừng
process, exit−15. Đây là **ABORTED**, không phải tests passed. Không dùng kết quả đó
để xác nhận Monitoring hoặc toàn flow. Hai capture mới bằng simctl được mở xem thật.
Không gửi credentials hợp lệ, không đổi quyền sharing, không tạo SOS hoặc gọi API
mutation để chụp thêm màn. Screenshot không phải bằng chứng API/performance.

## Contrast prototype

Tính WCAG relative luminance từ hex đang dùng trong HTML, không lấy kết quả token
app014 áp cho mọi surface khác. Cặp text/action sau đều vượt4.5:1:

| Cặp | Foreground | Background | Contrast |
| --- | --- | --- | --- |
| Light text/surface | #171A23 | #FFFFFF | 17.38:1 |
| Light secondary/surface | #565D6A | #FFFFFF | 6.63:1 |
| Light primary/foreground | #5843D6 | #FFFFFF | 6.59:1 |
| Dark text/surface | #F4F4F8 | #1C1D24 | 15.31:1 |
| Dark secondary/surface | #B0B3C0 | #1C1D24 | 8.04:1 |
| Dark primary/foreground | #B8ABFF | #19132E | 8.78:1 |
| Light secondary/background | #565D6A | #F2F2F7 | 5.94:1 |
| Dark secondary/background | #B0B3C0 | #101115 | 9.03:1 |

Các cặp này không chứng minh toàn bộ MapKit tiles/annotations/gradient/native material
đạt contrast; màu sơ đồ map là minh hoạ. Logo/legal link MapKit phải giữ bằng actual
layout margins khi triển khai. SVG icons/statusbar/keyboard không giả là native capture.

## Chưa xác minh và giới hạn

- Chưa có runtime visual/interaction coverage authenticated, tăng tương phản, real
  spoken VoiceOver/focus, OS Reduce Motion, iOS16 runtime, iPad/landscape hoặc theme
  startup/persistence. Prototype setting chỉ đổi preview ở HTML, chưa lưu setting app.
-12PNG ở390×844 logical points trong board414×900, rendered2x. Chưa phải native
  Dynamic Type reflow; design.md định nghĩa stack/scroll/large sheet khi compact/XXXL.
- Chưa có user testing; scores là đánh giá chuyên gia, không “user-friendliness proven”.
- Không đo FPS/memory/energy/network duplication/GPS; không tuyên bố perf improvement.
- Dark-mode HIG endpoint riêng không tải được; official Color/Accessibility/Maps/
  Sheets/Search fields đã đọc. Không copy toàn trang hoặc dùng iOS17+ thay baseline16.
- Audit ghi “risk/source-confirmed” cho layout chưa có screenshot, không khẳng định
  đã thấy lỗi cắt text trên app. Backlog chứa phần cần fixture/review sau.

## Duyệt và bước kế tiếp

Tất cả M01–M06 **PROPOSED v1**. Chỉ sau explicit approval theo mã/version mới tạo
implementation plan/tasks, sửa UI và chạy native regression/build/screenshot comparison.
Nếu user yêu cầu sửa, chuyển REVISION_REQUESTED rồi trình V2; approval V1 không tự
áp cho material changes ở V2. Giữ báo cáo coverage/N/A trong lần review tiếp theo.
