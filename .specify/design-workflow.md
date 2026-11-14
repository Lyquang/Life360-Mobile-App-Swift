# Design review cho FamilyTracker iOS

Đây là phần mở rộng của Spec Kit đang cài, không phải workflow thứ hai. Constitution,
interview, tasks và human approval hiện tại giữ nguyên. Không chạy specify init.

## Khi nào kích hoạt

Trước plan, phân loại UI Impact trong spec: NONE / SMALL / SUBSTANTIVE / MAJOR.
NONE (Backend/tooling không có UI) bỏ qua design research/visual QA. SMALL đọc nhanh
component bị ảnh hưởng và checklist liên quan. SUBSTANTIVE/MAJOR bắt buộc quy trình
bên dưới; MAJOR phải trình quyết định ở approval gate hiện có trước khi implement.
Các chỉ dẫn này áp dụng cả chat skills lẫn workflow engine vì plan command có cùng
preamble; không tạo lệnh speckit mới và không gọi thêm agent cho task không có UI.

## Trước plan

1. Đọc spec/clarifications và contract Backend liên quan; không đoán status vị trí.
2. Kiểm tra source, screen/route/sheet hiện có và FTDesignSystem/components. Định
   nghĩa mục tiêu, flow và UI states có thật, accessibility và localization vi/en.
3. Dùng `.agents/skills/ui-ux-pro-max/SKILL.md`: query ngắn, stack swiftui cho kỹ
   thuật; kiểm tra relevance của dataset. Không persist generic web recommendations.
4. Dùng `.agents/skills/mobile-design/SKILL.md` cho critique/interaction; đọc reference
   liên quan, giữ gesture hệ thống, safe area, modal exit và native control semantics.
5. Đối chiếu Apple HIG ở nguồn dưới. Khi xung đột: safety/privacy/accessibility và
   platform/product requirements đã duyệt ưu tiên hơn aesthetic preferences.
6. Ghi vào `plan.md` trong `Design Review` + `Reusability & Optimization Analysis`:
   requirement → flow/state → reused component/token → quyết định → source → QA.
   Chỉ tạo design.md trong cùng feature folder nếu UI-intensive; không tạo hierarchy
   design-system/ thứ hai. SMALL không cần thêm tài liệu.
7. Tasks/analyze đối chiếu spec/design/API/tests. Trình ở approval gate hiện có;
   design skills không duyệt navigation/branding/API/auth/location consent thay user.

## Sau implement

Refactor UI trong scope đã duyệt; chụp baseline và after nếu có thể. Dùng Simulator
riêng với tài khoản rỗng hoặc fixtures được ghi rõ, không chụp vị trí/tên gia đình thật.
Ghi build/revision, device/runtime/appearance/text size/locale/state và đường dẫn ảnh
vào verification.md. Kiểm tra small/large phone, light/dark, accessibility text,
keyboard, loading/empty/error và state liên quan. Mở xem ảnh thực tế, sửa clipping
trong scope. Không có Simulator/credentials/state fixture thì ghi Unverified, không
coi static source scan là visual QA. Study viết tiếng Việt, progress/task IDs dùng
cơ chế hiện có. Converge không đánh dấu yêu cầu bắt buộc complete khi chưa có bằng chứng.

## Checklist Apple HIG theo scope

- Typography: system text styles/Dynamic Type; nội dung chính wrap/scroll được.
- Touch: controls tối thiểu 44×44pt; không chồng hit area hoặc mất system back.
- Accessibility: tên/role/state, logical focus, decorative images ẩn; không chỉ màu.
- Contrast: đo composed foreground/background, cả light/dark/increased contrast.
- Safe area/keyboard: primary action không bị che; modal có close/cancel rõ ràng.
- Motion: tôn trọng Reduce Motion; không thêm animation/polling/cache vô cớ.
- Maps: đọc được attribution, giữ camera/context; không thêm GPS/network updates vì UI.
- Privacy: trạng thái sharing/freshness chỉ từ dữ liệu có thật; không đổi consent.
- Localization: vi/en, chuỗi dài, số/ngày theo locale; không dịch nội dung user.

## Nguồn và phạm vi cài đặt

- [UI UX Pro Max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill): installer
  npm `ui-ux-pro-max-cli@2.15.0`, đã chạy trong staging; package này không có --dry-run
  trong init --help. Chỉ promote skill ui-ux-pro-max được yêu cầu từ output Codex;
  bỏ qua các skill banner/slides/brand không liên quan, không xoá skill cũ.
- [Mobile Design](https://github.com/RubenGlez/mobile-design):
  `npx --yes skills@1.8.1 add RubenGlez/mobile-design --agent codex --skill mobile-design --yes --copy`.
  Project-local, không global; provenance ở skills-lock.json.
- [Apple HIG](https://developer.apple.com/design/human-interface-guidelines/),
  [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility),
  [Typography](https://developer.apple.com/design/human-interface-guidelines/typography),
  [Color](https://developer.apple.com/design/human-interface-guidelines/color),
  [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons),
  [Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets).
  HIG không phải package; chỉ tham chiếu và checklist, không copy toàn trang.

Giữ SF Symbols, system fonts, iOS 16 APIs; không mang CSS/ARIA/web layout trực tiếp
vào app. Python3 cho research script đã có, stdlib-only. Skills mới được Codex đọc
ở lượt/phiên kế tiếp; trong task hiện tại đọc trực tiếp SKILL.md và references.
