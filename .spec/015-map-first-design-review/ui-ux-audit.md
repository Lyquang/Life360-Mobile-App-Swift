# Audit UI/UX toàn ứng dụng — bản review V1

> Đây là baseline trước implementation. M01–M06 v1 đã được duyệt và hiện thực; kết quả hiện hành ở progress.md/verification.md. Các finding/backlog dưới đây giữ để truy vết, không phải tất cả còn chưa sửa.

Ngày2026-11-14 · Source baseline `e72997c` · iOS16+ · **PROPOSED, chưa duyệt redesign**.

## Tóm tắt đánh giá

App có nền tảng tốt: MapKit native, SF Rounded/semantic surfaces, vi/en, coordinator
routing, search có history/error/retry, Profile có sharing controls, Journey có
panel/recenter/accessibility. Batch014 đã sửa shared fonts/targets/auth; không ghi
lại những lỗi đã sửa thành lỗi hiện hành.

Điểm cần ưu tiên là bố cục map theo safe area, tính trung thực của freshness/online,
khả năng tiếp cận control bản đồ, đường phục hồi lỗi và theme xuyên suốt. Nút waveform
là **Pulse Debugger chỉ DEBUG**, không phải connectivity warning. Header search hiện
đã ở trên trong source; vấn đề là fixed offset, không có bằng chứng search nằm đáy.

Đây là full **source audit**, không phải full visual coverage. Có ảnh thật Login,
Register, Pulse; chưa có credentials/fixture hợp lệ để mở Map/Chat/Places/Profile/
SOS. Vì vậy không cho điểm chắc chắn những màn đó. Không có Critical đã xác minh;
High dưới đây phần lớn là rủi ro/hành vi xác nhận từ source, có chỉ rõ.

## Bằng chứng và cách đọc

- **S**: đọc source/route/data, chưa nhìn được runtime authenticated.
- **V**: đã xem ảnh thật của app; chế độ/nguồn ảnh ghi rõ.
- **P**: mockup đề xuất, không dùng làm bằng chứng giao diện hiện tại.
- Ảnh014 được chụp trước lượt review này và có cùng source app hiện tại; không gọi là
  screenshot mới. Build mới lượt này bị disk-full; capture dùng app Debug đã cài.
- Mọi điểm1–5 là heuristic chuyên gia, không phải kết quả khảo sát/hài lòng người dùng.
  1 kém,2 cần sửa nhiều,3 chấp nhận,4 tốt,5 xuất sắc; N/A là không đủ bằng chứng.

## Inventory toàn bộ surface

24 entry sau gồm screen, wrapper, overlay và1legacy component; không gọi là24screen
độc lập. Subview đi cùng cha: MapMemberPin/MemberInfoCard/StayAlertBanner/MessageBubble/
PlaceCard/rows/avatars. Mỗi route/sheet/dialog có thật được nối vào đây.

| ID / tên | Route và quan hệ điều hướng | Source | Mục đích/components | Tái sử dụng | API/data | States | Hành động chính | Inspection / findings |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| S01 Splash/root | AppCoordinator.launching | [AppCoordinator.swift](../../FamilyTracker/Presentation/Coordinators/AppCoordinator.swift) | Khôi phục phiên; gradient + ProgressView | FTColors; Auth/Main transition | restoreSession | launching/authenticated/unauthenticated | Chờ restore; đến Auth/Main | S; cần authenticated/fixture hoặc không có route; — |
| S02 Login | AuthCoordinatorView root | [LoginView.swift](../../FamilyTracker/Presentation/Scenes/Auth/Login/LoginView.swift) | Email/password + Google + register | FTTextField/FTSecureField/FTButton/LanguagePicker; register sheet | LoginViewModel→Auth UseCases | idle/loading/local validation/server error | Nhập email/password; login/Google; đăng ký; ngôn ngữ | Ảnh thật Light mới + Dark XXXL từ014; UX13 |
| S03 Register | AuthCoordinator.isShowingRegister sheet | [RegisterView.swift](../../FamilyTracker/Presentation/Scenes/Auth/Register/RegisterView.swift) | Form đăng ký, strength, terms | shared fields/buttons/OrDivider; dismiss→Login | RegisterViewModel→Auth UseCases | idle/loading/error/password strength | Nhập form; show password; tạo tài khoản; đóng | Ảnh thật014 Light/Dark XXXL; UX13 |
| S04 Main tabs | MainTabView selectedTab | [MainTabCoordinator.swift](../../FamilyTracker/Presentation/Coordinators/MainTabCoordinator.swift) | Map/chat/duration/journey/places/profile | TabView; EmergencyPresentation | feature coordinators | selected tab/badge/deeplink | Chọn destination; badge/deeplink | S; cần authenticated/fixture hoặc không có route; UX12 |
| S05 LiveMap | MapCoordinatorView tab map | [LiveMapView.swift](../../FamilyTracker/Presentation/Scenes/LiveMap/Map/LiveMapView.swift) | Map + members + selected place + controls | LiveTrailMapView/MemberInfoCard/MapMemberPin/StayAlertBanner | LiveMapViewModel→location/liveTrail/group use cases | tracking/selected member/place/member list/empty | Pan/zoom; tìm địa điểm; chọn member; recenter; SOS; lộ trình | S; cần authenticated/fixture hoặc không có route; UX02–05 |
| S06 Search place | MapCoordinator.searchPresented sheet | [PlaceSearchView.swift](../../FamilyTracker/Presentation/Scenes/Places/Search/PlaceSearchView.swift) | Autocomplete/results/recent/nearby | native List/TextField/Section; selection→Map | PlaceSearchViewModel→MapKit repository + local history | loading/empty/error/retry/history-error/suggestions/results | Query/recent/nearby; chọn kết quả; retry; huỷ | S; cần authenticated/fixture hoặc không có route; UX03 |
| S07 Duration | MainTabView duration | [DurationView.swift](../../FamilyTracker/Presentation/Scenes/LiveMap/Duration/DurationView.swift) | Chọn nhóm và thời lượng lưu trú | DurationMemberCard/FTEmptyView | DurationViewModel→groups/location | loading/empty/data/filter | Xem thành viên và lưu trú; xem cảnh báo | S; cần authenticated/fixture hoặc không có route; UX10–11 |
| S08 Chat hub | ChatHubCoordinatorView root | [ChatHubView.swift](../../FamilyTracker/Presentation/Scenes/Chat/ChatHubView.swift) | Group/direct conversations + people/search | ChatHubContent/ChatHubRow/MemberAvatarView | ChatHubViewModel→chat/groups | loading/empty/error/search/filter/opening | Tìm hội thoại/người; tạo/join nhóm; mở chat/info | S; cần authenticated/fixture hoặc không có route; UX01 |
| S09 Conversation | ChatHubCoordinator.Route.conversation | [ChatView.swift](../../FamilyTracker/Presentation/Scenes/Chat/Conversation/ChatView.swift) | Tin nhắn/media/voice/composer | MessageBubble/CachedMediaImage; group info/SOS routes | ChatViewModel→ChatUseCases/media/playback | loading/empty/data/typing/sending/retry/recording | Nhập/gửi ảnh/voice/text; retry; group info/SOS | S; cần authenticated/fixture hoặc không có route; UX14 |
| S10 Create circle | ChatHubCoordinator.sheet.create | [CreateGroupSheet.swift](../../FamilyTracker/Presentation/Scenes/Circles/Create/CreateGroupSheet.swift) | Tên nhóm và submit | FTTextField/FTButton/toast/error; onClose | CircleListViewModel→CreateCircle | loading/error/name validation | Nhập tên; tạo; huỷ | S; cần authenticated/fixture hoặc không có route; UX01 |
| S11 Join circle | ChatHubCoordinator.sheet.join | [JoinGroupSheet.swift](../../FamilyTracker/Presentation/Scenes/Circles/Join/JoinGroupSheet.swift) | Nhập mã mời | FTTextField/FTButton/toast/error; onClose | CircleListViewModel→JoinCircle | loading/error/code entry | Nhập mã6số; join; huỷ | S; cần authenticated/fixture hoặc không có route; UX07 |
| S12 Group detail | ChatHubCoordinator.sheet.detail | [GroupDetailView.swift](../../FamilyTracker/Presentation/Scenes/Circles/Detail/GroupDetailView.swift) | Mã mời/member list/chat action | MemberRowView/native List; direct/group chat | CircleListViewModel→members/direct chat | loading/error/retry/current-user-only | Copy invite; mở chat/member; retry; đóng | S; cần authenticated/fixture hoặc không có route; UX01 |
| S13 Member picker | TimelineCoordinatorView root | [MemberPickerView.swift](../../FamilyTracker/Presentation/Scenes/Timeline/MemberPicker/MemberPickerView.swift) | Chọn nhóm/thành viên hoặc history | JourneyMemberRow/GroupJourneySection/FTEmptyView | MemberPickerViewModel→groups/members | loading/empty/data | Chọn nhóm/member; mở Journey/History | S; cần authenticated/fixture hoặc không có route; UX01 |
| S14 Journey | TimelineCoordinator.Route.journey; map member journey | [JourneyView.swift](../../FamilyTracker/Presentation/Scenes/Timeline/Journey/JourneyView.swift) | Route map + day navigation + timeline panel | RouteMapView/StayPointRow/MovingSegmentRow | JourneyViewModel→journey/liveTrail | loading/empty/error/retry/stay/gap/selected entry | Chọn ngày/entry; map/timeline; recenter; đóng | S; cần authenticated/fixture hoặc không có route; UX01 |
| S15 History | TimelineCoordinator.Route.history | [HistoryView.swift](../../FamilyTracker/Presentation/Scenes/Timeline/History/HistoryView.swift) | Summary/mini map/location timeline | HistoryTimelineRow/FTEmptyView/custom header | HistoryViewModel→history | loading/empty/data/day/selected entry | Xem điểm; chọn marker/row; chuyển Journey | S; cần authenticated/fixture hoặc không có route; UX06 |
| S16 Places | PlacesCoordinatorView root | [PlacesView.swift](../../FamilyTracker/Presentation/Scenes/Places/PlacesView.swift) | Favorite places/group/category | PlaceCard/FTEmptyView; AddPlace sheet | PlacesViewModel→places/groups | loading/empty/data/category/filter/error | Chọn nhóm/category; thêm; refresh; chọn place | S; cần authenticated/fixture hoặc không có route; UX09 |
| S17 Add place | PlacesCoordinator.isShowingAddPlace sheet | [AddPlaceSheet.swift](../../FamilyTracker/Presentation/Scenes/Places/AddPlaceSheet.swift) | Tên/loại/toạ độ hoặc vị trí hiện tại | FTTextField/native Form/Picker; save/cancel | PlacesViewModel→AddPlace/currentLocation | entry/adding/error | Tên/category; tọa độ/current location; lưu/huỷ | S; cần authenticated/fixture hoặc không có route; UX01 |
| S18 Profile | MainTabView profile | [ProfileView.swift](../../FamilyTracker/Presentation/Scenes/Profile/ProfileView.swift) | Thông tin tài khoản và sharing/logout | InfoRow/LanguagePicker/native List/dialog | ProfileViewModel→privacy/session | sharing pending/error/paused/status/logout confirm | Ngôn ngữ; sharing; logout/all; Debug diagnostics | S; cần authenticated/fixture hoặc không có route; UX01–02 |
| S19 Language menu | Auth/Profile menu | [LanguagePicker.swift](../../FamilyTracker/Presentation/Scenes/Settings/LanguagePicker.swift) | Chọn vi/en | native Picker/AppLocalizedText/LocalizedDurationText | UserDefaults language prefs | selected language | Chọn vi/en | S; cần authenticated/fixture hoặc không có route; UX01 |
| S20 SOS confirmation / fallback / incoming | EmergencyPresentation on MainTabView | [EmergencyCoordinator.swift](../../FamilyTracker/Presentation/Coordinators/EmergencyCoordinator.swift) | Confirm SOS/location choice/resume/incoming | native confirmationDialog/alert/busy overlay; SOS detail sheet | SOSViewModel/SOSSessionController | pending/busy/location failed/error/incoming | Xác nhận SOS có/không vị trí; huỷ/resume; mở incoming | S; cần authenticated/fixture hoặc không có route; UX08 |
| S21 SOS detail | EmergencyCoordinator.route sheet | [SOSDetailView.swift](../../FamilyTracker/Presentation/Scenes/SOS/SOSDetailView.swift) | Chi tiết/responders/help/close/map | native List/sections/buttons | SOSViewModel→SOS repository | loading/detail/error/responders/closed | Xem detail/responders; giúp; resolved/cancel; map; đóng | S; cần authenticated/fixture hoặc không có route; UX08 |
| S22 Pulse console | DebugOverlay sheet | [NetworkInspectorView.swift](../../FamilyTracker/Presentation/Scenes/Debug/NetworkInspectorView.swift) | Network debug console/export | Pulse ConsoleView/fileExporter | local diagnostic store | console/export/error | Filter log; export; mở monitoring; đóng | Ảnh thật Light mới; empty log; UX02 |
| S23 Monitoring | DebugCoordinator NavigationLink | [MobileMonitoringView.swift](../../FamilyTracker/Presentation/Scenes/Debug/MobileMonitoringView.swift) | Aggregate metrics + export | native List/sections | MobileMonitoringViewModel→metrics stores | loading/empty/data/export error | Xem aggregate; export; retry/đóng alert | S; cần authenticated/fixture hoặc không có route; — |
| S24 Legacy SOS banner (component, not active route) | No call site found in current source | [SOSAlertBanner.swift](../../FamilyTracker/Presentation/Scenes/SOS/SOSAlertBanner.swift) | Old SOS presentation component | glyph/text/dismiss/map callback | SOSAlert parameter | visible/pulse | Không có route/call site hoạt động được tìm thấy | S; cần authenticated/fixture hoặc không có route; Legacy, ngoài runtime audit |

| S25 Quyền vị trí hệ thống | CLLocationService/SOSLocationService, sau sharing/SOS intent | [CLLocationService](../../FamilyTracker/Core/Location/CLLocationService.swift), [SOSLocationService](../../FamilyTracker/Core/Location/SOSLocationService.swift) | OS-owned When In Use/Always, không có onboarding custom | iOS authorization + purpose strings | notDetermined/denied/restricted/authorized; reduced accuracy | Cho phép/từ chối; recovery theo flow | S; chưa trigger quyền hoặc đổi consent |
| S26 Quyền thông báo hệ thống | MainTabCoordinator.start → requestAuthorization | [PushNotificationService](../../FamilyTracker/Core/PushNotification/PushNotificationService.swift) | OS alert, sau đăng nhập | native UserNotifications | granted/denied | Cho phép/từ chối | S; cần authenticated; timing review backlog |
| S27 Chọn ảnh hệ thống | ChatView PhotosPicker | [ChatView](../../FamilyTracker/Presentation/Scenes/Chat/Conversation/ChatView.swift) | Chọn attachment | system photo picker + media use cases | selected/cancelled/uploading/error | Chọn/huỷ ảnh; retry upload | S; không chụp thư viện ảnh cá nhân |
| S28 Xuất/chia sẻ tài liệu hệ thống | Debug Console/Monitoring fileExporter | [NetworkInspectorView](../../FamilyTracker/Presentation/Scenes/Debug/NetworkInspectorView.swift) | Xuất JSON đã redact | FileDocument/system picker | cancelled/export/error | Lưu/huỷ | S; không tạo/chia sẻ log production |

**Các surface điều kiện không bị bỏ sót:** S05 gồm member-list overlay, selected-member
card, selected-place card, trail unavailable/raw label và SOS-follow offline overlay;
S08/S12 có lỗi mở direct-chat; S18 có2confirmation logout; S20 có confirmation,
location fallback, incoming banner, busy overlay và error alert; S21 có pagination/
conflict/awaiting refresh; S22/S23 có export error. Loading/empty/error là states
trong screen cha, không phát minh error screen độc lập. Không tìm thấy onboarding,
appearance settings screen hay circle switcher trên Map trong source hiện tại.
M05 là **surface mới đang đề xuất**, không được đưa vào inventory hiện hành.

## Điểm từng screen và nhận xét

Thứ tự5tiêu chí: Usability / Visual / iOS native / Accessibility / Consistency.
Mọi N/A giữ nguyên cho màn chưa xem, kể cả có thể suy đoán khá tốt từ source.

| Surface | U | V | iOS | A11y | Nhất quán | Giải thích / điều cần review |
| --- | --- | --- | --- | --- | --- | --- |
| S02 Login | 3 | 4 | 4 | 3 | 4 | U3: primary action cần cuộn ở compact; V4: card/font rõ; iOS4: native fields/autofill; A3: ảnh XXXL cuộn được, VoiceOver chưa kiểm chứng; C4: dùng chung auth tokens. UX13 |
| S03 Register | 3 | 4 | 4 | 3 | 4 | U3: nhiều field làm form dài; V4: card/terms rõ; iOS4: native sheet; A3: XXXL có scroll nhưng back link chưa explicit44; C4: shared fields, giữ validation. UX13 |
| S22 Pulse | 3 | 3 | 4 | N/A | 3 | U3: screenshot empty có filters nhưng nhiều icon; V3: toolbar dày trên compact; iOS4: native sheet; A N/A: chưa review spoken/focus; C3: công cụ development khác ngôn ngữ/style. Không redesign library Pulse |
| S01 Splash/root | N/A | N/A | N/A | N/A | N/A | —; chưa đủ visual evidence, xem evaluation bên dưới |
| S04 Main tabs | N/A | N/A | N/A | N/A | N/A | UX12; chưa đủ visual evidence, xem evaluation bên dưới |
| S05 LiveMap | N/A | N/A | N/A | N/A | N/A | UX02–05; chưa đủ visual evidence, xem evaluation bên dưới |
| S06 Search place | N/A | N/A | N/A | N/A | N/A | UX03; chưa đủ visual evidence, xem evaluation bên dưới |
| S07 Duration | N/A | N/A | N/A | N/A | N/A | UX10–11; chưa đủ visual evidence, xem evaluation bên dưới |
| S08 Chat hub | N/A | N/A | N/A | N/A | N/A | UX01; chưa đủ visual evidence, xem evaluation bên dưới |
| S09 Conversation | N/A | N/A | N/A | N/A | N/A | UX14; chưa đủ visual evidence, xem evaluation bên dưới |
| S10 Create circle | N/A | N/A | N/A | N/A | N/A | UX01; chưa đủ visual evidence, xem evaluation bên dưới |
| S11 Join circle | N/A | N/A | N/A | N/A | N/A | UX07; chưa đủ visual evidence, xem evaluation bên dưới |
| S12 Group detail | N/A | N/A | N/A | N/A | N/A | UX01; chưa đủ visual evidence, xem evaluation bên dưới |
| S13 Member picker | N/A | N/A | N/A | N/A | N/A | UX01; chưa đủ visual evidence, xem evaluation bên dưới |
| S14 Journey | N/A | N/A | N/A | N/A | N/A | UX01; chưa đủ visual evidence, xem evaluation bên dưới |
| S15 History | N/A | N/A | N/A | N/A | N/A | UX06; chưa đủ visual evidence, xem evaluation bên dưới |
| S16 Places | N/A | N/A | N/A | N/A | N/A | UX09; chưa đủ visual evidence, xem evaluation bên dưới |
| S17 Add place | N/A | N/A | N/A | N/A | N/A | UX01; chưa đủ visual evidence, xem evaluation bên dưới |
| S18 Profile | N/A | N/A | N/A | N/A | N/A | UX01–02; chưa đủ visual evidence, xem evaluation bên dưới |
| S19 Language menu | N/A | N/A | N/A | N/A | N/A | UX01; chưa đủ visual evidence, xem evaluation bên dưới |
| S20 SOS confirmation / fallback / incoming | N/A | N/A | N/A | N/A | N/A | UX08; chưa đủ visual evidence, xem evaluation bên dưới |
| S21 SOS detail | N/A | N/A | N/A | N/A | N/A | UX08; chưa đủ visual evidence, xem evaluation bên dưới |
| S23 Monitoring | N/A | N/A | N/A | N/A | N/A | —; chưa đủ visual evidence, xem evaluation bên dưới |
| S24 Legacy SOS banner (component, not active route) | N/A | N/A | N/A | N/A | N/A | Legacy, ngoài runtime audit; chưa đủ visual evidence, xem evaluation bên dưới |
| S25 Location permission | N/A | N/A | N/A | N/A | N/A | OS-owned; chưa trigger, không chấm thay hệ thống |
| S26 Notification permission | N/A | N/A | N/A | N/A | N/A | OS-owned; chưa trigger, không chấm thay hệ thống |
| S27 Photo picker | N/A | N/A | N/A | N/A | N/A | OS-owned; chưa trigger, không chấm thay hệ thống |
| S28 File export | N/A | N/A | N/A | N/A | N/A | OS-owned; chưa trigger, không chấm thay hệ thống |

## Findings và ma trận ưu tiên

Mỗi finding nêu nơi/evidence → vấn đề → người dùng bị ảnh hưởng → hướng sửa/appearance,
phạm vi chức năng và effort tương đối. High/Medium/Low là mức chuyên gia đánh giá;
không gán Critical vì thiếu quan sát runtime. S = source-confirmed, V = screenshot.

| ID / mức | Nơi và evidence | Vấn đề và tác động | Đề xuất / giao diện | Tác động chức năng / effort |
| --- | --- | --- | --- | --- |
| UX04 **High** | S05: MapMemberPin:20, MemberInfoCard:12/59; LiveMapView member list; MemberLocation không có online field (S) | `isOnline:true` cố định; timestamp parse lỗi → “vừa cập nhật”; dễ tin vị trí còn mới/online | M02: timestamp rõ, unknown trung thực; bỏ green-online không có authority, không thay bằng offline giả | Presentation semantics cần duyệt; không Backend field; M |
| UX05 **High** | S05 MemberInfoCard:71 button40pt/close nhỏ; LiveMapView mapControlButton thiếu action name; member overlay VStack/ForEach không scroll (S) | Người đọc màn hình khó hiểu action; nhiều member/chữ lớn có thể vượt viewport | M01/M02:44pt, tên “Về vị trí của tôi”, SOS, Xem vị trí/Lộ trình; panel/list có scroll và đóng rõ | Callback giữ nguyên; M |
| UX06 **High** | S15 HistoryView:32–40, ViewModel.load catch (S) | Lỗi fetch đi vào empty view, không có retry/action; dễ nghĩ không có dữ liệu | Tách error/empty, retry dùng load có sẵn; timeline/map vẫn cùng nguồn điểm thật | UI state distinction; M; mockup batch2 |
| UX07 **High, risk** | S11 JoinGroupSheet:11–84 VStack/Spacer, numberPad, tracking8 fixed32 (S) | Không ScrollView; keyboard/chữ lớn có nguy cơ che CTA hoặc mã; chưa xác nhận runtime | Form cuộn, CTA trong safe area, giữ6digit/autofill/paste; normal/error/keyboard states | Layout only, giữ validation; M; batch2 |
| UX08 **High** | S21 SOSDetailView:85–88 gọi close trực tiếp; SOSViewModel.perform (S) | Đóng/cancel SOS active ngay, không thấy bước xác nhận/undo trong UI source | Native confirmation ghi rõ kết quả, đặt cancel an toàn; không thay gửi SOS/consent | Thêm interaction xác nhận cần duyệt riêng; M; batch2 |
| UX01 **Medium / requirement mới** | S01–23: FTColors semantic; App root chỉ locale; Profile settings chỉ LanguagePicker; appearance search chỉ thấy2preview overrides (S) | Tự theo OS một phần, chưa có persisted Sáng/Tối/Hệ thống; colors literal/gradients rải rác không tự thích ứng đồng bộ | M04/M05: tận dụng FTColors,1local preference ở app root, persist trước render; map/sheets cùng traits | UI preference mới, chưa triển khai; L |
| UX03 **Medium, risk** | S05 LiveMapView header padding.top55; offsets175/225/232; member top100; DebugOverlay safeAreaInset (S) | Search đã trên nhưng fixed offsets chồng/lệch theo máy/chữ/theme/debug | M01/M03: search nằm ngay dưới safe-area header; vertical flow thay offset; results trên khi focused | Giữ coordinator/search use cases; M–L |
| UX02 **Medium** | DebugCoordinator DebugOverlay safeAreaInset top44; App #if DEBUG; Profile developer section; ảnh Login/Pulse (S+V) | Pulse nổi mọi màn Debug, dễ nhầm trạng thái mạng, chiếm vùng trên/map | M04: dùng lại Cá nhân → Nhà phát triển; giữ shortcut/launch flag; map chỉ hiển thị warning mất realtime có thật (M06) | Không xoá Pulse/export/monitoring; S–M |
| UX09 **Medium** | S16 PlacesView filteredPlaces.isEmpty dùng cùng thông điệp “Chưa có địa điểm” dù filter/category/group; loadError vẫn có alert (S) | Filter rỗng dễ bị hiểu thành nhóm chưa có place; người dùng bị hướng thêm thay vì đổi filter | Empty theo nguyên nhân, “Không có địa điểm trong danh mục này”, Clear filter; giữ add khi hợp lệ | Không đổi API; S–M; batch2 |
| UX10 **Medium** | S07 DurationMemberCard `if isStaying else stay.moving`; isStaying từ nil→0 (S) | Thiếu duration có thể bị diễn đạt “đang di chuyển”, suy luận quá dữ liệu | “Chưa có thông tin lưu trú” khi nil; không suy ra movement/online | Copy + state presentation, cần duyệt; S; batch2 |
| UX11 **Medium** | S07 active StayAlertBanner repeatForever/rotation không đọc Reduce Motion (S); legacy SOS khác không active | Animation lặp khi người dùng cần giảm chuyển động | Static symbol hoặc transition ngắn khi Reduce Motion; giữ cảnh báo/text | Presentation only; S; batch2 |
| UX12 **Medium / cần xác minh** | S04 MainTabView6destinations (S) | iPhone native overflow có thể đưa Places/Profile vào More; task hay dùng cần kiểm tra discoverability | V1 giữ6destination, minh hoạ native “Thêm”; không tự gộp/đổi thứ tự; review screenshot sau login | Không redesign IA trong batch1; effort TBD |
| UX13 **Medium** | S02/S03 ảnh compact/XXXL; Login top60/logo90; Register back link không min44 (S+V) | Intro cao làm form/CTA cần cuộn; back text nhỏ hơn shared button target | Giảm decorative header trên compact/chữ lớn; link min44; giữ identity/card được sửa014 | Low-risk layout nhưng lần này vẫn chờ duyệt; S–M; batch3 |
| UX14 **Medium** | S09 MessageBubble upload progress/cancel icon không explicit44/name (S) | Cancel upload nhỏ, assistive action có thể không rõ; composer đã được sửa014 | Dùng shared progress/cancel44 + label; giữ send/retry/draft behavior | Presentation only; S; batch3 |

## Đánh giá theo từng nhóm màn

- **S01/S04:** splash/restore có state rõ nhưng chưa visual-test startup theme/flicker;
  native TabView có badge và deep links. Giữ state/navigation model; UX01/12.
- **S02/S03:** card semantic/font/visibility đã tốt hơn014. Form dài vẫn cuộn được;
  chưa có bằng chứng field bị che. Giảm intro là proposal UX13, không gọi là auth lỗi.
- **S05:** map là nhiệm vụ chính; overlay tự đặt theo số cố định và member controls
  có evidence UX03–05. Recenter chỉ căn camera, không phải turn-by-turn navigation.
  MapKit iOS16 đã dùng MKMapView; giữ gestures, attribution và camera policy.
- **S06:** source có loading/empty/error/retry/recent/nearby và dismiss keyboard; giữ
  những điểm này. M03 chỉnh composition/safe area theo yêu cầu, không thêm search API.
- **S07:** source hiển thị duration/since/battery có dữ liệu; kiểm tra unknown (UX10),
  animation (UX11), chữ dài/card wrapping sau login. Không coi thiếu duration là moving.
- **S08:** ChatHub có List/search/create/join và row44/AX/name/large-text treatment;
  không có evidence cần redesign; theme audit apply, cần runtime screenshot.
- **S09:** chat có lazy messages/load older/retry/photo/voice; giữ shared composer.
  UX14 ở upload bubble, cần keyboard/offline/progress fixtures trước mockup batch3.
- **S10:** create group có ScrollView/shared field/native Cancel; reuse, chưa cần
  redesign lớn. Cần error/keyboard visual evidence; không invent error behavior.
- **S11:** UX07 là nguy cơ layout cụ thể từ VStack/keyboard; giữ numeric6digit contract.
- **S12:** copy44/name đã sửa014, List/Close/retry/direct-chat error có sẵn. Long invite
  code/name và theme cần visual-check; không báo target vẫn40 như lịch sử014.
- **S13:** nhóm/member chooser có empty/load/rows; source avatar cố định cần long-name
  visual QA. Chưa đủ bằng chứng đề xuất thay toàn screen.
- **S14:** Journey có Reduce Motion, dynamic panel, accessible rows/recenter/day button,
  loading/error/empty/gap/raw trail; giữ pattern tốt này làm reference cho map panel.
- **S15:** UX06 retry/error là ưu tiên; marker/row dùng tap gesture cần AX review trước
  chấm điểm. Không đo hoặc đổi route geometry vì UI audit.
- **S16/S17:** Places có category/group picker, alert fetch error và Form/native Save/
  Cancel. UX09 phân biệt filtered-empty; coordinates fallback là flow hiện có, không
  tự thêm picker bản đồ hay đổi precision/privacy.
- **S18/S19:** sharing toggle có checking/unavailable/error và retry; logout/all có
  confirmation; giữ guard/consent. Giao diện mới + Debug entry reuse là M04/M05.
- **S20/S21:** create SOS có confirmation/location fallback/busy/refresh; không báo
  thiếu confirm ở flow create. UX08 chỉ ở hành động close/cancel active detail.
- **S22/S23:** Pulse/monitoring là Debug tools, không phải feature production/network
  truth. Không đổi library/filter/export/redaction; chỉ di chuyển entry UX02.
- **S24:** không tìm thấy call site; không tính thành màn visual coverage, không xoá.
- **S25–S28:** giữ OS controls, purpose strings và quyền từ chối. Notification prompt
  gọi khi MainTab.start, timing/context cần nghiên cứu sau; chưa chứng minh bị ép cấp
  quyền. Không trigger SOS hoặc permissions bằng tài khoản thật chỉ để chụp audit.

## Tính nhất quán và hướng thiết kế

Giữ indigo/SF Rounded/SF Symbols, spacing4/8/16/24, bán kính theo vai trò, hierarchy
17body/15subheadline/12caption. Opaque semantic surface cho form; material chỉ dùng
khi cần phân lớp trên map. Tránh thêm gradient/glass/loop cho vẻ “hiện đại”.
Map là signature của sản phẩm: ưu tiên nội dung bản đồ và thông tin cập nhật có thật,
không dashboard thống kê hoặc avatar-ring online không có authority.

Chi tiết tokens/interaction/approval ở [design.md](design.md); có12PNG và gallery
[review V1](mockups/index.html), không phải source app đã triển khai.

## Backlog mockup và thứ tự duyệt

| Batch | Surface/finding | Quyết định |
| --- | --- | --- |
| 1 — đã render V1 | M01 map, M02 member, M03 search, M04 profile/Pulse, M05 appearance, M06 offline | Mỗi mục có Light/Dark; PROPOSED, chờ feedback |
| 2 — chưa render | SOS close confirmation UX08, History recovery UX06, Join keyboard UX07, Places filtered-empty UX09, Duration unknown/motion UX10/11 | Functional UX ưu tiên tiếp theo; cần signed-in fixture/screenshot cho comparison thật |
| 3 — chưa render | Auth compact header UX13, Chat upload UX14, create/join/group long content và các shared theme consumers | Không bỏ qua; proportional polish sau batch1/2, theo feedback |
| IA research — chưa đề xuất redesign |6tab/overflow UX12; permission timing S26 | Cần task-frequency/user feedback/runtime evidence trước đổi hierarchy |

Những màn chưa có issue đủ bằng chứng vẫn nằm trong inventory/QA backlog; không
redesign để tăng số mockup. Stage implementation phải có approval version cụ thể,
plan/tasks/tests mới hoặc cập nhật có traceability sau duyệt.

## Nguồn chính thức và nghiên cứu

Đã đọc hai SKILL.md và references critique/craft-floor/platform-ios/typography-color/
navigation/design-process. Query UI UX Pro Max stack swiftui và UX contrast hỗ trợ
semantic accessibility; kết quả generic/web hoặc navigation-rewrite không áp máy móc.

Apple HIG đọc ngày2026-11-14: [Maps](https://developer.apple.com/design/human-interface-guidelines/maps/)
cho map gestures/overlays/attribution; [Search fields](https://developer.apple.com/design/human-interface-guidelines/search-fields/)
cho search theo layout/task; [Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets/)
cho scoped tasks/dismiss; [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility/)
và [Color](https://developer.apple.com/design/human-interface-guidelines/color/) cho adaptive
system colors/contrast. Dark-mode endpoint trực tiếp không tải được; dùng Color và
Accessibility chính thức đã đọc, không bịa nội dung trang lỗi. Target44 là tiêu chí
review iOS; screenshot/mockup không chứng minh VoiceOver hoặc Dynamic Type runtime.
