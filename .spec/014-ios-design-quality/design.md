# Audit và quyết định thiết kế — 2026-11-14

## Phạm vi bằng chứng

Đã kiểm kê toàn bộ SwiftUI screen/coordinator/scene source hiện có; subviews trong
cùng file được liệt kê với screen cha, không phát minh route. EmergencyPresentation
là modifier/dialog chứ không có màn CreateSOS riêng. Circle list hiện thuộc ChatHub,
không có CircleListView riêng. Map renderers/markers, MemberInfoCard, StayAlertBanner,
DurationMemberCard, PlaceCard, MessageBubble, Journey rows và shared components là
subviews, không được đếm thêm thành màn hình độc lập.

Baseline có build thật và ảnh Login trên Simulator riêng iPhone SE3. Source scan
không chứng minh visual, gesture, performance hoặc trạng thái authenticated. Bảng
sau là inventory source, không phải khẳng định tất cả màn đã được mở trong Simulator.
Không có token/tài khoản/vị trí gia đình thật trong artifacts.

## Screen inventory

| Screen | Source | Route/navigation | Purpose/main components | Shared / relationships | API/data dependency | States found in source | Issues / scope | Priority |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Splash/root | [AppCoordinator.swift](../../FamilyTracker/Presentation/Coordinators/AppCoordinator.swift) | AppCoordinator.launching | Khôi phục phiên; gradient + ProgressView | FTColors; Auth/Main transition | restoreSession | launching/authenticated/unauthenticated | motion scale chưa xét Reduce Motion | P2 |
| Login | [LoginView.swift](../../FamilyTracker/Presentation/Scenes/Auth/Login/LoginView.swift) | AuthCoordinatorView root | Email/password + Google + register | FTTextField/FTSecureField/FTButton/LanguagePicker; register sheet | LoginViewModel→Auth UseCases | idle/loading/local validation/server error | F01–F07; ảnh baseline compact-light có thật | P1 |
| Register | [RegisterView.swift](../../FamilyTracker/Presentation/Scenes/Auth/Register/RegisterView.swift) | AuthCoordinator.isShowingRegister sheet | Form đăng ký, strength, terms | shared fields/buttons/OrDivider; dismiss→Login | RegisterViewModel→Auth UseCases | idle/loading/error/password strength | F01–F07; cần ảnh sau ở cả appearance | P1 |
| Main tabs | [MainTabCoordinator.swift](../../FamilyTracker/Presentation/Coordinators/MainTabCoordinator.swift) | MainTabView selectedTab | Map/chat/duration/journey/places/profile | TabView; EmergencyPresentation | feature coordinators | selected tab/badge/deeplink | 6 destinations; chưa đề xuất đổi navigation | P3 |
| LiveMap | [LiveMapView.swift](../../FamilyTracker/Presentation/Scenes/LiveMap/Map/LiveMapView.swift) | MapCoordinatorView tab map | Map + members + selected place + controls | LiveTrailMapView/MemberInfoCard/MapMemberPin/StayAlertBanner | LiveMapViewModel→location/liveTrail/group use cases | tracking/selected member/place/member list/empty | font/overlay/labels cần visual QA có data; camera giữ nguyên | P2 |
| Search place | [PlaceSearchView.swift](../../FamilyTracker/Presentation/Scenes/Places/Search/PlaceSearchView.swift) | MapCoordinator.searchPresented sheet | Autocomplete/results/recent/nearby | native List/TextField/Section; selection→Map | PlaceSearchViewModel→MapKit repository + local history | loading/empty/error/retry/history-error/suggestions/results | native44pt/labels đã có; authenticated review chưa chạy | P3 |
| Duration | [DurationView.swift](../../FamilyTracker/Presentation/Scenes/LiveMap/Duration/DurationView.swift) | MainTabView duration | Chọn nhóm và thời lượng lưu trú | DurationMemberCard/FTEmptyView | DurationViewModel→groups/location | loading/empty/data/filter | F01 shared fonts; row overflow cần visual data | P2 |
| Chat hub | [ChatHubView.swift](../../FamilyTracker/Presentation/Scenes/Chat/ChatHubView.swift) | ChatHubCoordinatorView root | Group/direct conversations + people/search | ChatHubContent/ChatHubRow/MemberAvatarView | ChatHubViewModel→chat/groups | loading/empty/error/search/filter/opening | dynamic-size/44pt/labels đã có; preserve row pattern | P3 |
| Conversation | [ChatView.swift](../../FamilyTracker/Presentation/Scenes/Chat/Conversation/ChatView.swift) | ChatHubCoordinator.Route.conversation | Tin nhắn/media/voice/composer | MessageBubble/CachedMediaImage; group info/SOS routes | ChatViewModel→ChatUseCases/media/playback | loading/empty/data/typing/sending/retry/recording | F08 composer targets/names; cần QA signed-in | P1 |
| Create circle | [CreateGroupSheet.swift](../../FamilyTracker/Presentation/Scenes/Circles/Create/CreateGroupSheet.swift) | ChatHubCoordinator.sheet.create | Tên nhóm và submit | FTTextField/FTButton/toast/error; onClose | CircleListViewModel→CreateCircle | loading/error/name validation | F01/F05 shared; giữ close/system sheet | P2 |
| Join circle | [JoinGroupSheet.swift](../../FamilyTracker/Presentation/Scenes/Circles/Join/JoinGroupSheet.swift) | ChatHubCoordinator.sheet.join | Nhập mã mời | FTTextField/FTButton/toast/error; onClose | CircleListViewModel→JoinCircle | loading/error/code entry | F01/F05 shared; code input chưa visual QA | P2 |
| Group detail | [GroupDetailView.swift](../../FamilyTracker/Presentation/Scenes/Circles/Detail/GroupDetailView.swift) | ChatHubCoordinator.sheet.detail | Mã mời/member list/chat action | MemberRowView/native List; direct/group chat | CircleListViewModel→members/direct chat | loading/error/retry/current-user-only | F10 copy glyph; no behavior change in this batch | P2 |
| Member picker | [MemberPickerView.swift](../../FamilyTracker/Presentation/Scenes/Timeline/MemberPicker/MemberPickerView.swift) | TimelineCoordinatorView root | Chọn nhóm/thành viên hoặc history | JourneyMemberRow/GroupJourneySection/FTEmptyView | MemberPickerViewModel→groups/members | loading/empty/data | F01 shared; rows fixed avatar and long names source risk | P2 |
| Journey | [JourneyView.swift](../../FamilyTracker/Presentation/Scenes/Timeline/Journey/JourneyView.swift) | TimelineCoordinator.Route.journey; map member journey | Route map + day navigation + timeline panel | RouteMapView/StayPointRow/MovingSegmentRow | JourneyViewModel→journey/liveTrail | loading/empty/error/retry/stay/gap/selected entry | already handles Dynamic Type/Reduce Motion in scene; retain camera policy | P3 |
| History | [HistoryView.swift](../../FamilyTracker/Presentation/Scenes/Timeline/History/HistoryView.swift) | TimelineCoordinator.Route.history | Summary/mini map/location timeline | HistoryTimelineRow/FTEmptyView/custom header | HistoryViewModel→history | loading/empty/data/day/selected entry | F09 36pt back target; stats layout needs authenticated QA | P2 |
| Places | [PlacesView.swift](../../FamilyTracker/Presentation/Scenes/Places/PlacesView.swift) | PlacesCoordinatorView root | Favorite places/group/category | PlaceCard/FTEmptyView; AddPlace sheet | PlacesViewModel→places/groups | loading/empty/data/category/filter/error | F09 40pt add target, fixed labels; test more before change | P2 |
| Add place | [AddPlaceSheet.swift](../../FamilyTracker/Presentation/Scenes/Places/AddPlaceSheet.swift) | PlacesCoordinator.isShowingAddPlace sheet | Tên/loại/toạ độ hoặc vị trí hiện tại | FTTextField/native Form/Picker; save/cancel | PlacesViewModel→AddPlace/currentLocation | entry/adding/error | shared label typography; numeric field keyboard/layout static-only | P2 |
| Profile | [ProfileView.swift](../../FamilyTracker/Presentation/Scenes/Profile/ProfileView.swift) | MainTabView profile | Thông tin tài khoản và sharing/logout | InfoRow/LanguagePicker/native List/dialog | ProfileViewModel→privacy/session | sharing pending/error/paused/status/logout confirm | native sharing states exist; no consent change permitted | P2 |
| Language menu | [LanguagePicker.swift](../../FamilyTracker/Presentation/Scenes/Settings/LanguagePicker.swift) | Auth/Profile menu | Chọn vi/en | native Picker/AppLocalizedText/LocalizedDurationText | UserDefaults language prefs | selected language | native pattern preserve; QA both locales on auth | P3 |
| SOS confirmation / fallback / incoming | [EmergencyCoordinator.swift](../../FamilyTracker/Presentation/Coordinators/EmergencyCoordinator.swift) | EmergencyPresentation on MainTabView | Confirm SOS/location choice/resume/incoming | native confirmationDialog/alert/busy overlay; SOS detail sheet | SOSViewModel/SOSSessionController | pending/busy/location failed/error/incoming | no consent/status/navigation changes; requires synthetic/private-safe QA | P1 review |
| SOS detail | [SOSDetailView.swift](../../FamilyTracker/Presentation/Scenes/SOS/SOSDetailView.swift) | EmergencyCoordinator.route sheet | Chi tiết/responders/help/close/map | native List/sections/buttons | SOSViewModel→SOS repository | loading/detail/error/responders/closed | native controls; contrast/long-content QA not available | P2 |
| Pulse console | [NetworkInspectorView.swift](../../FamilyTracker/Presentation/Scenes/Debug/NetworkInspectorView.swift) | DebugOverlay sheet | Network debug console/export | Pulse ConsoleView/fileExporter | local diagnostic store | console/export/error | third-party UI; no redesign; preserve redaction | P3 |
| Monitoring | [MobileMonitoringView.swift](../../FamilyTracker/Presentation/Scenes/Debug/MobileMonitoringView.swift) | DebugCoordinator NavigationLink | Aggregate metrics + export | native List/sections | MobileMonitoringViewModel→metrics stores | loading/empty/data/export error | native scalable text; functional device metrics not tested | P3 |
| Legacy SOS banner (component, not active route) | [SOSAlertBanner.swift](../../FamilyTracker/Presentation/Scenes/SOS/SOSAlertBanner.swift) | No call site found in current source | Old SOS presentation component | glyph/text/dismiss/map callback | SOSAlert parameter | visible/pulse | F11 repeatForever without Reduce Motion; not an observed active-screen bug | P3 |

Coordinator wrappers Auth/Map/Places/Timeline/ChatHub/App/Main được đối chiếu với bảng;
chúng không phải screen thêm. Loading/empty/error/offline/permissions chỉ ghi state
source cung cấp, không tự thêm unavailable/online/location freshness vào sản phẩm.

## Findings ban đầu theo mức ưu tiên

| ID / severity | Bằng chứng trước sửa | Tác động / giải pháp | Batch |
| --- | --- | --- | --- |
| F01 P1 | FTDesignSystem: FTFont dùng `.system(size:)` cố định | Chuyển sang system text styles cùng rounded weights; layout consumer cần kiểm tra | Implement |
| F02 P1 | Ảnh before-login-compact-light: text tối trên gray translucent form card; source Login/Register dùng ultraThinMaterial trên dark gradient | Opaque semantic card dùng cùng semantic label, native theme; giữ brand/background | Implement |
| F03 P1 | FTSecureField eye glyph 14pt không label/value/frame44 | 44pt button, localized next action + visible state, binding không đổi | Implement |
| F04 P2 | FTButton spinner luôn white dù outline/ghost foreground primary | Tinted spinner theo foreground, label/disabled state giữ đúng | Implement |
| F05 P2 | FTTextField/FTSecureField label tách khỏi native input; decorative icon có thể thành focus phụ | Gán label cho input, ẩn title/icon trùng; native keyboard/content type, giữ field binding | Implement |
| F06 P2 | FTButton scale/spring và shared field animation chưa đọc Reduce Motion | Conditional animation, không thêm haptics/loop | Implement |
| F07 P2 | FTErrorView retry chỉ có text; FTEmptyView CTA/toast lineLimit2 | Minimum44, scalable/wrapping shared feedback, không đổi data/action | Implement |
| F08 P1 | ChatView.inputBar photo/send glyph thiếu named accessibility và explicit44 | Bổ sung semantics/targets trong batch conversation riêng có signed-in fixture | Batch B: names/44pt; visual QA pending |
| F09 P2 | Places header add40 và History custom back36 | Target44 + tên đọc màn hình, kiểm tra header ở large text | Batch B: names/44pt; visual QA pending |
| F10 P2 | GroupDetail invite-copy glyph chưa label/44; invite code tracking8 | Native copy action label/target và long-code layout với fixture | Batch B: names/44pt; visual QA pending |
| F11 P3 | SOSAlertBanner repeatForever, nhưng không tìm thấy call site | Xác minh retirement/usage trước sửa hoặc xoá; active SOS dùng EmergencyPresentation | Backlog: xác minh usage trước sửa/xoá |
| F14 P1 | Existing language-switch UI test: Login tagline stays in old language until restart | Reuse AppLocalizedText and environment locale for native field/Google labels; do not reset entered state | Implement |
| F13 P1 | Runtime accessibility hierarchy: Google button says “This text is not available.”; legacy keys absent from both resource tables | Add two namespaced localized button labels; callback unchanged | Implement |
| F12 P3 | MainTabView có 6 top-level destinations | Review discoverability/native More với người dùng trước mọi navigation redesign | Requires separate decision |

Không có P0 được xác minh. Dynamic Type, label/target và source motion findings
không phụ thuộc suy đoán screenshot. Contrast của mọi state/surface khác, marker
clustering, frame rate, memory, GPS frequency và real VoiceOver speech chưa được đo;
đó là giới hạn kiểm chứng, không phải defects được bịa thêm. Không chấm điểm visual
toàn app từ một screenshot.

## Visual direction / component decisions

Giữ indigo, SF Rounded, map-first utility và palette hiện có. Chỉ dùng semantic SF
text roles/surfaces, tránh bổ sung glass/gradient/animation. CardModifier hiện có
được thêm cornerRadius default-compatible để Login/Register tái sử dụng thay blur
styling lặp lại. Auth background gradient hợp nhất thành một token, giá trị màu cũ.
Password visibility là native Button, target chung44; system password/autofill vẫn dùng.
Google button giữ nền/logo hiện có, font scalable, spinner/semantics đầy đủ.

UI UX Pro Max hỗ trợ scalable SwiftUI/native-label recommendation; Mobile Design
critique ưu tiên khả năng đọc/interaction hơn trang trí. Apple HIG accessibility,
typography và color đã được đọc; tham chiếu trong .specify/design-workflow.md.

## Authorization / remaining work

Thực hiện F01–F07 theo §11 user attachment và scope đã ghi trong spec/plan. F08–F10 được xử lý thêm tên/vùng chạm trong batch B; long-code layout và visual QA
của các màn authenticated còn cần fixture. F11–F12 là backlog cần quyết định riêng. Không đổi
consent, sharing, authentication, Backend hoặc navigation. Authenticated screens
được source-review; cần credentials/fixtures được phép cho visual/interaction QA.
