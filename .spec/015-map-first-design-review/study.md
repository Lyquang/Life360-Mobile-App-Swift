# Ghi chú review UI/UX

Điểm khác giữa audit source và visual QA: source cho biết flow/condition/callback,
nhưng không chứng minh text wrap, gesture, safe area thực tế hoặc trải nghiệm dùng.
Vì vậy Map/Chat/Profile chưa được chấm điểm từ trí nhớ hoặc từ mockup tự tạo.

[DebugOverlay](../../FamilyTracker/Presentation/Coordinators/DebugCoordinator.swift)
chèn nút top bằng safeAreaInset và mở Pulse. Nó được gắn ở app root trong #if DEBUG;
đây là diagnostics entry, khác với isConnected trong LiveMapViewModel. Chuyển entry
vào Developer settings không được làm biến mất warning realtime khi có vấn đề.

[LiveMapView](../../FamilyTracker/Presentation/Scenes/LiveMap/Map/LiveMapView.swift)
đã đặt search trong header; các số55/175/225 giải thích vì sao cần review bố cục theo
safe area thay vì khẳng định search nằm đáy. Mockup focused search cũng cần giữ input
ở trên, không chỉ entry trước khi bấm. Bàn phím/XXXL có thể cần large sheet để đọc rõ.

[MemberInfoCard](../../FamilyTracker/Presentation/Scenes/LiveMap/Components/MemberInfoCard.swift)
hiện truyền online true và fallback “vừa cập nhật”. Timestamp có nghĩa là lần ghi nhận
vị trí, không phải presence hoặc sharing consent. Model hiện có không cho phép tự
sáng tạo trạng thái online. “Chưa rõ thời điểm” trung thực hơn khi parse thất bại.

Theme proposal mở rộng FTColors/root composition hiện có, không tạo thư viện theme
thứ hai. Preference phải được đọc trước frame đầu để tránh flash; thay theme không
được recreate session/coordinator hoặc gây GPS/network startup lại. Đây là requirement
cần kiểm chứng sau duyệt, không phải kết quả performance hoặc persistence đã thực hiện.

Mockup HTML giúp review hierarchy/copy/theme nhanh với dữ liệu giả và render PNG
thật từ trình duyệt. Nó không chứng minh native iOS controls/Dynamic Type/VoiceOver.
Gallery/PNG đều ghi PROPOSED; source app giữ nguyên. HIG/maps/color và design skills
hướng dẫn quyết định; Spec Kit vẫn là nơi quản lý approval, plan/tasks và implementation.


## Implementation sau approval — những điểm kỹ thuật

[AppearanceSettings](../../FamilyTracker/Presentation/Scenes/Settings/AppearanceSettings.swift)
đọc raw preference đồng bộ ở init; system trả ColorScheme nil. Root giữ @StateObject
và áp preferredColorScheme, không thay `.id` hoặc recreate coordinator nên không gây
restart session/GPS do chọn theme. Đây là cấu trúc tránh flash, chưa phải số đo flicker.

[LiveMapView](../../FamilyTracker/Presentation/Scenes/LiveMap/Map/LiveMapView.swift)
đặt safeAreaInset ngoài GeometryReader: geometry dùng cho panel là phần còn lại sau
header. Vì vậy chữ lớn/banner không bị tính nhầm vào diện tích map/controls. Panel
height được đo cho MapKit attribution margins; thay layout margin không tự điều khiển
camera. Recenter/member select/search vẫn đi qua callback cũ.

[MapPresentationViews](../../FamilyTracker/Presentation/Scenes/LiveMap/Components/MapPresentationViews.swift)
tách header/controls/status/member panel với trách nhiệm nhỏ; production và QA app
dùng cùng components. Native target test nằm ngoài app chính, có fixture repositories
cho search; không có APIClient/auth bypass/GPS manager trong QA app.

MemberAvatar optional presence nil có nghĩa chưa biết, chỉ ẩn dot; false vẫn là offline
khi thật sự có nguồn dữ liệu. Màu tên dùng deterministic scalar fold thay hashValue
để không đổi ngẫu nhiên giữa process. Marker name chip phụ trợ cố định size; full name
vẫn đọc trong VoiceOver/list, không coi label chip là nguồn thông tin duy nhất.

Date/time label dùng selected locale; invalid không được báo “vừa cập nhật”. Tọa độ
được giữ trong disclosure để không mất chức năng khi panel được làm gọn. Action labels
nói rõ recenter khác Journey, SOS chỉ mở confirmation flow hiện có.

Kiểm thử giảm theo yêu cầu cuối của người dùng: giữ bằng chứng PASS thật và ghi rõ
SKIPPED; không đánh dấu toàn bộ release/device/E2E pass khi chưa chạy. Xem verification.md.
