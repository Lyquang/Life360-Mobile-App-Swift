# Ghi chú kỹ thuật: design workflow và native UI quality

## Một workflow, các trách nhiệm khác nhau

Spec Kit tiếp tục quản lý yêu cầu, interview, plan/tasks/analyze, approval và tiến độ.
UI UX Pro Max cung cấp research có kiểm tra relevance; Mobile Design ưu tiên native
interaction/critique; Apple HIG là nguồn platform. Không skill nào được tự thay consent,
API, branding hoặc navigation đã duyệt. `.specify/design-workflow.md` định nghĩa UI
Impact; preamble của plan kích hoạt review đúng lúc cho cả chat và workflow engine.
Không thêm command orchestrator hoặc ghi đè constitution. Source preset và bản CLI
cài được tách rõ; native append/prepend giữ nội dung upstream khi materialize skills.

## Vì sao system text styles

FTFont trước đây dùng `.system(size:)`: số pt cố định không thực hiện lời hứa Dynamic
Type trong chú thích. `.system(.body, design: .rounded)` giữ font identity nhưng để
hệ thống tính kích thước theo preference. Các text role khác cũng tương ứng style
native. Body lớn không đồng nghĩa icon phải phóng không giới hạn: glyph trang trí
18pt và eye18pt nằm trong control44pt để không đè lên nội dung. Label vẫn scale đầy đủ.

[FTDesignSystem](../../FamilyTracker/Presentation/Common/DesignSystem/FTDesignSystem.swift)
chứa FTControl.minimumTarget, fieldHint, authBackground và CardModifier. Thêm tham số
cornerRadius có default giữ tất cả `.ftCard()` consumers tương thích, rồi auth dùng
cùng modifier với radius xl. Không tạo generic form framework hay theme library mới.

## Binding, accessibility và locale

[FTTextField](../../FamilyTracker/Presentation/Common/Components/FTTextField.swift)
giữ @Binding của parent. SecureField/TextField dùng chung binding khi toggle nên
không mất password. Native labels được đặt trên input, title/icon trùng được ẩn khỏi
accessibility tree. Eye có localized next action và state, không đưa password vào
accessibilityValue của button. Trạng thái disabled/loading vẫn do caller quản lý.

Field hint dùng semantic label với opacity có đo contrast trên surface/card light
và dark; đây là kiểm tra token cụ thể, không chứng minh contrast của mọi screen.
Reduce Motion bỏ scale/spring trong shared button và animation field/Google; không
khẳng định mọi animation legacy trong app đã được kiểm tra.

Test UI cũ phát hiện chuỗi auth không đổi ngay khi chọn ngôn ngữ. Thay vì ép `.id`
để recreate màn và mất focus/state, dùng AppLocalizedText hiện có và environment
locale cho native input/Google labels. Preferences/session/Domain không thay đổi.
Test giữ nguyên email đã nhập và kiểm tra ngôn ngữ qua relaunch để chứng minh.

## Auth surfaces và control semantics

[Login](../../FamilyTracker/Presentation/Scenes/Auth/Login/LoginView.swift) và
[Register](../../FamilyTracker/Presentation/Scenes/Auth/Register/RegisterView.swift)
đổi từ custom blur card sang surface semantic opaque; label/surface giờ cùng appearance
context. Divider dùng separator token, terms dùng semantic secondary text. Auth gradient
được gom lại với đúng palette cũ, không đổi brand. Login account prompt dùng AnyLayout
để stack khi accessibility text lớn, không lặp UI hoặc thay onRegister callback.

[GoogleSignInButton](../../FamilyTracker/Presentation/Common/Components/GoogleSignInButton.swift)
giữ callback/logo/nền hiện có. Runtime QA phát hiện thiếu hai key label cũ; thay bằng
namespaced vi/en keys. Shared spinner dùng đúng foreground thay vì white trong mọi style.
Feedback retry/CTA có44pt, toast cho phép wrap. Không thêm cache hoặc network request.

Batch B thêm accessible name/44pt cho composer chat, copy invite, thêm place và History
back. Chỉ presentation modifiers; không đổi draft, gửi media/voice, clipboard value,
selected group hoặc dismiss callback. Các màn authenticated chưa có ảnh/interaction
QA; không được suy luận đã đạt toàn bộ accessibility từ source.

## Cách QA bắt lỗi mà build không bắt

Build/SwiftLint/localization đều có thể pass khi UI vẫn lỗi ở cỡ chữ rất lớn. Ảnh đầu
cho thấy glyph eye/icon phóng quá lớn; sửa font glyph, bound/clip single-line input,
rồi chụp lại. Test bổ sung kiểm tra field frame không chồng eye control. Single-line
password có thể rút gọn/horizontal scroll nội dung dài; binding/value và native semantics
vẫn đầy đủ, label phía trên không bị cắt. Không giảm cỡ chữ người dùng để làm ảnh đẹp.

Native XCTest harness riêng trong Tests/DesignUI dùng app thật đã cài trên Simulator
QA, không thêm auth bypass hoặc test route trong production. Empty submit dừng ở
validation local; không submit credentials hợp lệ. Ảnh raw export từ xcresult, dữ
liệu nhập đều synthetic, không dùng tài khoản hay tọa độ gia đình thật.

## Giới hạn và trade-offs

Xem verification.md cho kết quả và flags build thật. Whole-app source audit không
phải visual QA của toàn bộ màn. VoiceOver speech/focus thủ công, iOS16 runtime,
iPad/landscape, authenticated states, real-device energy và performance còn cần QA.
Chưa đo rendering/network/memory nên không tuyên bố cải thiện hiệu năng. Giữ một
bản nguồn design decisions trong feature, không tạo thêm design-system hierarchy.

### Phân biệt key và thông báo đã dịch

Lượt QA cuối phát hiện `AppLocalizedText(error)` tra cứu lại một thông báo đã được
ViewModel dịch, nên có thể hiện fallback thiếu bản dịch. Login/Register dùng
`Text(verbatim: error)` cho thông báo đã dịch; các nhãn cố định mới dùng
`AppLocalizedText`. Không thay mapping lỗi hoặc logic xác thực. Test đăng nhập
trống kiểm tra chính nội dung lỗi, tránh chỉ kiểm tra có một dòng text bất kỳ.
