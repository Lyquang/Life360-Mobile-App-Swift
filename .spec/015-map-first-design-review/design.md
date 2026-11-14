# Đề xuất thiết kế V1 — chờ duyệt

**APPROVED v1 · IMPLEMENTED** cho M01–M06 theo approval trong session. Approval014
không áp dụng batch này. Có thể duyệt/từ chối/yêu cầu sửa từng mã; approval phải nêu V1.

## Cách xem và phạm vi

Mở [gallery HTML](mockups/index.html) hoặc từng PNG trong bảng. Gallery chạy local,
không gọi API, không tải ảnh/tên/vị trí thật. Map là sơ đồ tự vẽ, không phải screenshot
MapKit; status bar/keyboard/tab bar là hình minh hoạ, không xác nhận native runtime.
Font là system font của trình duyệt, SF Symbols được minh hoạ bằng SVG nét đồng bộ;
implementation sau duyệt sẽ dùng FTFont/SF Symbols/native controls của app.

Đọc sản phẩm như tiện ích gia đình iOS cần thông tin nhanh, trung thực khi di chuyển.
Map là nội dung chính; giữ indigo và rounded typography, giảm thành phần nổi cạnh tranh.
Không thêm circle switching trên Map, chat CTA, ETA, movement, accuracy, online hoặc
live connection số liệu mà client không cung cấp.

## Các thiết kế cần duyệt

| Mã / mục tiêu | Light / Dark | Thay đổi chính / lợi ích | Giữ chức năng / trade-off / complexity | Status |
| --- | --- | --- | --- | --- |
| M01 Bản đồ | [Light](mockups/map-light.png) · [Dark](mockups/map-dark.png) | Search luôn vùng trên, header gọn theo safe area; member strip có timestamp; recenter/SOS44 tách khỏi panel; bớt chrome | Giữ pan/zoom/selection/search/SOS và6destinations. Header top khó với ngón cái hơn; user đã yêu cầu top. Native More minh hoạ cho overflow, không đổi thứ tự tab. M–L | APPROVED v1 |
| M02 Chi tiết member | [Light](mockups/member-light.png) · [Dark](mockups/member-dark.png) | Panel có close44, tên/cập nhật/pin rõ; Xem vị trí/Lộ trình có text, tránh icon khó đoán | Xem vị trí chỉ recenter; Lộ trình route hiện có. Pin chỉ khi có dữ liệu; không online giả. Panel làm map ít diện tích hơn khi mở; scroll khi chữ lớn. M | APPROVED v1 |
| M03 Search focused/results | [Light](mockups/search-light.png) · [Dark](mockups/search-dark.png) | Ô nhập ở trên cả khi focus; results gần query, Huỷ rõ; phần map phía dưới còn nhìn được trên keyboard | Dùng lại MapCoordinator/PlaceSearchViewModel/MapKit/history. Cần safe-area/layout keyboard QA, có thể dùng native presentation lớn hơn ở compact/XXXL. Không ép partial map nếu hết chỗ. M–L | APPROVED v1 |
| M04 Profile/Pulse entry | [Light](mockups/profile-light.png) · [Dark](mockups/profile-dark.png) | Giao diện vào settings, chẩn đoán vào developer section hiện có; bỏ entry nổi global Debug khỏi vùng map | Giữ Pulse/log/export/monitoring, launch flag và keyboard shortcut; thêm1–2tap cho developer, chấp nhận vì ít dùng hơn task map. Production connectivity warning vẫn ở map. S–M | APPROVED v1 |
| M05 Appearance preference | [Light](mockups/appearance-light.png) · [Dark](mockups/appearance-dark.png) |3radio native-style: Theo hệ thống mặc định, Sáng, Tối; chọn lưu trên thiết bị, áp root/modal/map nhất quán | Đây là local UI setting mới người dùng yêu cầu, chưa triển khai. Không tạo theme framework mới; tăng test matrix/startup persistence. M–L | APPROVED v1 |
| M06 Map mất realtime | [Light](mockups/offline-light.png) · [Dark](mockups/offline-dark.png) | Banner nhỏ có icon+text, không chỉ đỏ/xanh; giữ vị trí/timestamp cuối, không làm đẹp bằng cách ẩn cảnh báo | Chỉ dùng LiveMapViewModel.isConnected hiện có; không gọi đó là Internet mất hoàn toàn hoặc mọi member offline. Banner chiếm thêm48–64pt lúc có vấn đề. S–M | APPROVED v1 |

## Search và network: quyết định cụ thể

**Search:** source hiện có entry ở header, dùng padding.top55. V1 bố trí header sau
safe area, search là hàng48pt bên dưới. Không auto-collapse entry mặc định vì khó tìm
và gây đổi vị trí control. Khi focused, input vẫn ở trên; results/recent/nearby có
scroll, keyboard dismiss không reset map/query; Huỷ đóng search, giữ map context.
Khi chữ lớn/compact, kết quả ưu tiên khả năng đọc, native large sheet được phép che
map nhiều hơn. Đây là trade-off đã ghi, không hy sinh a11y để giữ map lộ bằng mọi giá.

**Nút mạng:** waveform của DebugOverlay mở Pulse, không phải indicator mất mạng.
Profile đã có Developer → NetworkInspectorView. Đề xuất dùng lại entry này, giữ
Command-Shift-L và -PulseConsole để tiếp cận nhanh khi đang ở auth. Không xoá chức năng.
Đường monitoring/export trong Pulse phải được giữ khi implementation. Release hiện
đã không có DebugOverlay. Không thêm developer menu vào Release chỉ để có mockup.

Đối chiếu ảnh thật: [Login có entry Pulse](current/login-light-current.png) và
[Pulse đang mở](current/pulse-light.png) → vị trí đề xuất trong [M04](mockups/profile-light.png).
Đây là so sánh vị trí entry giữa hai surface; **chưa có original screenshot Map** nên
không dựng ảnh “Map hiện tại” giả. M01 là proposed, không phải after đã triển khai.

## Theme và component reuse

Hiện có FTColors systemBackground/secondarySystemBackground/label và FTFont Dynamic
Type, card/radius/spacing/shared controls; MKMapView không ép UIUserInterfaceStyle.
Chưa có runtime appearance preference/persistence. Hai preferredColorScheme hiện có
chỉ trong PreviewProvider; không nhầm thành dark-only app.

Đề xuất tận dụng1preference ở composition root, đọc đồng bộ persisted choice trước
first content, system→nil/light→light/dark→dark; không recreate coordinator/session.
Map hosting annotations cần cùng trait với map, modal/nav/tab/status bar theo root.
Không thay SDK: app dùng Apple MapKit/MKMapView, không phải Google Maps. Map palette
trong PNG chỉ minh hoạ Light/Dark, không cam kết MapKit tile style giống ảnh tự vẽ.

| Vai trò token | Light mockup | Dark mockup | Mapping dự kiến sau duyệt |
| --- | --- | --- | --- |
| background | #F2F2F7 | #101115 | FTColors.background/systemGroupedBackground theo context |
| surface | #FFFFFF | #1C1D24 | FTColors.card/surface adaptive |
| textPrimary | #171A23 | #F4F4F8 | UIColor.label |
| textSecondary | #565D6A | #B0B3C0 | semantic secondary đủ contrast |
| action | #5843D6 | #B8ABFF | FTColors.primary adaptive variant, không đổi brand identity |
| action foreground | #FFFFFF | #19132E | semantic foreground đi với primary |
| destructive | #B52835 | #FF9AA4 | semantic danger adaptive |

Các hex là giá trị thiết kế minh hoạ, không rải literal vào source app. Contrast đo
cho cặp text/surface/primary trong verification; không gọi mọi màu MapKit đã đạt.
Spacing4/8/16/24, icon18–22, hit target≥44, text17body/15subheadline/12caption. Radius
12field/16card/24panel là proposal tương thích scale hiện có. Chỉ có ba lớp depth:
map, controls, panel; không thêm glow/loop/material cho từng row.

## States, dữ liệu và privacy

| State | Hành vi/copy đề xuất | Authority / giới hạn |
| --- | --- | --- |
| Map data/loading | Hiển thị map; member area có progress/hint; không vẽ fake members | existing locations/stream/loading nếu có, không thêm data state chưa có trong VM ngầm |
| Empty member list | “Chưa có vị trí thành viên”; giữ search/recenter/SOS phù hợp | memberLocations.isEmpty; không đồng nghĩa không có Circle |
| Selected member | Tên, vị trí trên map, timestamp, optional battery; Xem vị trí/Lộ trình | MemberLocation; raw coordinates có thể ở disclosure khi cần, không tạo địa chỉ reverse-geocode giả |
| Timestamp invalid/missing | “Chưa rõ thời điểm cập nhật” | Không fallback “vừa cập nhật”; không chọn stale threshold tùy ý |
| Realtime disconnected | M06; giữ last-known locations, không gắn online | local connectionState, khác connectivity/remote presence |
| Sharing paused/unavailable | Dùng Profile state hiện có; nếu sau này đưa lên Map phải inject đúng state được duyệt | privacy GET/PATCH hiện có; không suy từ empty list/offline; chưa mockup trạng thái trên Map |
| Trail unavailable/raw | Giữ retry/label hiện có, sắp theo vertical flow; không che search | trailUnavailable/drawing.style hiện có |
| Search idle | recent/nearby; empty history không phải lỗi | PlaceSearchViewModel |
| Search loading/error/empty | progress; localized retry nếu canRetry; empty rõ và sửa query/huỷ | existing failureKey/isLoading/didSearch/results/historyFailed |
| Permission denied | Recovery theo capability hiện có; không đánh lừa người dùng bật sharing thành granted | OS authorization khác Backend sharing; không auto-resume/đổi consent trong redesign |
| SOS incoming/busy | Ưu tiên banner quan trọng hơn member decoration; giữ confirmation/location fallback | EmergencyCoordinator, không che/đổi policy |

## Accessibility / iOS verification trước release sau duyệt

Native field/button/sheet roles, action/state labels vi/en; visual order = focus order.
Member list có alternate representation ngoài map marker. Panel expand có nút ngoài
gesture; min44 và spacing≥8. Body/placeholder4.5:1, meaningful icon3:1; không chỉ màu.
Dynamic Type: stack actions/scroll panel, không ép fixed-height card; header search
wrap ở XXXL, vùng map giảm theo ưu tiên đọc. Reduce Motion không spring/pulse lặp.
Attribution và legal link MapKit không bị panel che thường trực; phải test actual
layout margins trên MKMapView, mockup “Vùng attribution” chỉ đánh dấu reserve.
Không claim screenshot HTML chứng minh VoiceOver/native keyboard/map gestures.

## Approval và vòng phản hồi

Mỗi M01–M06 hiện **PROPOSED v1**. Người dùng có thể ghi “Duyệt M01/M02 v1”, “Sửa
M03…”, hoặc “Từ chối M05”. Khi có sửa, ghi REVISION_REQUESTED, render V2 rồi trình lại;
chỉ chuyển APPROVED khi có explicit confirmation, REJECTED cho phần bị từ chối.
Sau duyệt mới lập plan/tasks implementation theo Spec Kit và đúng mã/version được
phép. Đổi material sau duyệt cần duyệt lại; không áp toàn bộ audit như quyền sửa code.

## Approval nhận sau checkpoint

User trong session: “Tôi đồng ý toàn bộ những thiết kế của bạn, hãy hiện thực nó,”.
M01–M06 v1 được APPROVED cho implementation. Các nhãn PROPOSED ở ảnh/HTML là lịch sử
của artifact v1 đang duyệt, được giữ nguyên để bảo toàn hash; trạng thái hiện hành ở
progress.md và mục này. Không áp approval vào backlog chưa render.
