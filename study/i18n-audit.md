# G0 Localization Audit

## Phạm Vi Và Kết Luận

Audit chỉ đọc `FamilyTracker/` (142 Swift files), `FamilyTracker/Resources/`, `Info.plist`, `api-docs/LOCALIZATION.md`, `AI_RULES.md`, `PROGRESS.md`, script và test localization. `README.md` đang có thay đổi từ trước; không chỉnh sửa file đó. Không sửa mã app trong G0.

Mục tiêu đang yêu cầu `L10n.tr`, nhưng API đó **không tồn tại**. API thật trong `Core/Localization/L10n.swift` là `text`, `format`, `duration`, `message`. Do đó ví dụ `L10n.tr("voice.error.permission_denied")` hiện không biên dịch. Tài liệu nhiệm vụ mô tả nhầm trạng thái hiện tại; đề xuất thêm API tương thích `tr` hoặc đổi tên có kiểm soát sau khi bạn duyệt (xem Cần tôi quyết định).

| Hạng mục | Hiện trạng đã kiểm chứng |
|---|---|
| Chọn ngôn ngữ | `AppLanguage` hỗ trợ `vi`/`en`; mặc định tiếng Việt. `FamilyTrackerApp` gắn `languageSettings.language.locale` vào SwiftUI environment. `LanguageSettingsViewModel` cập nhật `L10n.language` và preference khi chọn, nên String lookup/non-View notification đổi ngay; `AppLocalizedText` đọc locale environment. |
| Lookup | `L10n.text(key, language:, bundle:)` tìm `<language>.lproj/Localizable.strings` trong bundle truyền vào (mặc định `.main`). |
| Thiếu key | `localizedString(forKey:value:)` dùng chính key làm fallback; key hoặc chuỗi nguồn có thể lộ ra giao diện. |
| Định dạng | `L10n.format(_ key, _ arguments: CVarArg..., language:)` format chuỗi đã lookup với locale ngôn ngữ chọn. Hỗ trợ format theo template, nhưng không có API `tr`/plural riêng hoặc kiểm tra kiểu key. |
| Message/error | `L10n.message` chỉ chuẩn hóa hai tiền tố app-owned `Lỗi mạng:` và `Lỗi parse dữ liệu:`; các dòng còn lại tra lookup theo nguyên văn. Unknown text, gồm server message, được giữ nguyên thay vì hiện fallback chung. |
| SwiftUI literal | `Text("...")`, `Button("...")`... đang dựa vào cơ chế `LocalizedStringKey` của SwiftUI; `FamilyTrackerApp` có environment locale nhưng những call-site này không đi qua `L10n`. Có 5 dạng dùng `LocalizedStringKey(...)` tường minh trong tab, category và placeholder components. |
| Tài liệu hiện có | `api-docs/LOCALIZATION.md` khuyên dùng SwiftUI literal/`AppLocalizedText`, chưa buộc toàn bộ text qua `L10n`; `AI_RULES.md` không có quy tắc localization. |
| Resources | `vi.lproj` và `en.lproj` đều có `Localizable.strings` và `InfoPlist.strings`; không có `.stringsdict`. G0 ban đầu có 262 khai báo, 261 key duy nhất; G1 thêm key namespaced `localization.missing_translation`, hiện mỗi file có 263 khai báo và 262 key duy nhất; 1 key theo namespace. Có khai báo lặp `"Đang hoạt động"`: dòng 10 và 250, khác nghĩa EN (`Active` / `Active now`) nhưng cùng key nên dictionary không thể phân biệt ổn định. |
| Test hiện có | `scripts/test_localization.sh` biên dịch harness Swift, kiểm tra preference lifecycle, lookup một số key, formatting, lỗi/duration, placeholder parity và tổng số entries đọc được. Nó không quét string literals trong app, không kiểm tra mọi key call-site, accessibility, server error mapping, formatter locale, plural, notifications hoặc overflow UI. UI test script chỉ kiểm tra một flow đổi locale ở form auth; không phải audit UI toàn app. |

## Thống Kê Quét

| Đo lường | Kết quả | Cách hiểu |
|---|---:|---|
| Swift files dưới `FamilyTracker/` | 142 | Bao gồm app, domain, data và debug. |
| Khai báo mỗi `Localizable.strings` | 263 | Sau G1 thêm fallback key; có một duplicate key trong mỗi ngôn ngữ. |
| Key duy nhất mỗi ngôn ngữ | 262 | Bao gồm key fallback namespaced mới. |
| Key dạng namespace | 1 | `localization.missing_translation`; 261 legacy keys còn lại là câu nguồn. |
| `.stringsdict` | 0 | Chưa có plural resource. |
| Literal construction candidates trong Swift | 136 | Đếm raw match cho `Text`, `Button`, `Label`, title, form, section, accessibility và `LocalizedStringKey`; có cả brand, dynamic template, debug và technical text nên phải phân loại, không xem 136 là số chuỗi cần dịch chính xác. |
| Dùng helper localization | 70 raw call-site matches | `L10n.*`, `AppLocalizedText`, `LocalizedDurationText`; nhiều helper tra key dạng câu, chưa phải namespaced key. |
| String formatting/date/locale candidates | 20 raw matches | Bao gồm API date format cố định, display time, format số/timer và các format kỹ thuật; không phải toàn bộ đều là UI cần localize. |
| `NSLocalizedString` / `String(localized:)` | 0 | Không thấy dùng trong Swift app. |

### G1 Report-Only Scanner Baseline

`bash scripts/test_localization.sh` hiện gọi thêm `scripts/check_localization_report.rb`. Baseline thực đo ở G1: 142 Swift files; 262 key khác nhau cho mỗi locale sau khi parser loại trùng; 1 key namespaced mới (missing-translation fallback); 120 literal UI/accessibility candidate sau allowlist; 22 static localization-helper key references phát hiện trong scan multiline, 0 key references thiếu ở cả hai bảng; parity 0/0, empty 0, duplicate 2 (một duplicate logic trong mỗi locale); bypass `NSLocalizedString`/`String(localized:)` 0; 10 resource templates có integer placeholders. Scanner luôn exit 0 cho finding, nên CI chưa bị chặn.

Đây là baseline heuristic, không phải chứng minh coverage hoàn chỉnh: string key được kiểm tra khi first argument là literal tĩnh; dynamic keys, một số conditional/indirect calls và chuỗi build từ nhiều dòng có thể lọt. Literal candidates gồm UI đang hoạt động, dynamic templates và một số presentation/debug paths; cần review theo feature, không xóa bằng allowlist rộng. File allowlist ghi regex hẹp kèm lý do.

Số literal và helper ở trên là số lần match theo scan tĩnh, không phải số string unique. Những chuỗi tạo gián tiếp qua component (`FTTextField`/`AppLocalizedText`, error text trong ViewModel, enum `displayName`) được ghi riêng trong inventory để không bỏ sót.

## Inventory Theo Tính Năng

Trạng thái `Hard-code` ở bảng này nghĩa là call-site không đi qua `L10n`; `Một phần` nghĩa là có helper/lookup nhưng dùng key dạng câu, có fallback raw, hoặc ghép nội dung; `Loại trừ` là dữ liệu động/brand/debug theo yêu cầu. Dòng có nhiều literal/call-site cùng một file được gom lại để inventory gọn; không hàm ý chỉ có một occurrence.

### Auth Và Trường Dùng Chung

| File:dòng | Chuỗi gốc / nhóm | Loại | Trạng thái | Key đề xuất |
|---|---|---|---|---|
| `Presentation/Scenes/Auth/Login/LoginView.swift:60,68,78,143,147`; `Register/RegisterView.swift:41,45,125,137,189` | `FamilyTracker`; slogan; đăng nhập/đăng ký; thỏa thuận điều khoản; strength labels | Brand + UI | Brand loại trừ; UI hard-code SwiftUI literal | `auth.title.login`, `auth.title.register`, `auth.subtitle`, `auth.legal.terms`, `auth.action.*`, `auth.password.strength.*` |
| `Presentation/Common/Components/FTTextField.swift:24,39,70,83,87,135` và các call-site Auth/Places/Circles | Label/placeholder/title truyền vào; `Đang xử lý...` | UI/placeholder | Một phần: title qua `AppLocalizedText` → `L10n.message`; placeholder qua `LocalizedStringKey`, không qua `L10n` | `common.field.*`, `common.state.processing` |
| `Presentation/Common/Components/GoogleSignInButton.swift:23,89` | `Đang xác thực...`, `Tiếp tục với Google`, `hoặc` | UI | Có literal trong SwiftUI; audit đánh dấu hard-code theo quy tắc mới | `auth.google.loading`, `auth.google.continue`, `common.separator.or` |
| `Presentation/Scenes/Auth/Login/LoginViewModel.swift:50,81,84,87`; `Register/RegisterViewModel.swift:51,82,85,88` | Không mở được Google; mạng; OAuth config; Google token invalid | Error | Hard-code trong ViewModel; cancellation không nên bị trình bày như lỗi | `auth.error.google_*` |
| `Domain/Errors/DomainError.swift:12-22`; `Data/Network/Endpoint.swift:32-...` | Session, forbidden, network/decoding, validation và HTTP fallback | Error | Một phần: `LocalizedError` trả raw Vietnamese/server body; 400/401/409/default có thể giữ `message` server | `error.session_expired`, `error.forbidden`, `error.network`, `error.invalid_response`, `error.generic`, theo code HTTP/API |
| `Core/Audio/AudioRecorderService.swift:10-20`; `Core/Storage/ImageProcessor.swift:11-14`; `Domain/Entities/MediaUpload.swift:44-69` | Quyền mic, ghi âm, upload, ticket, lỗi media | Error | Hard-code trong Domain/Core `LocalizedError`; MediaUpload `.backend`/`.socketRejected` giữ server message | `voice.error.*`, `media.error.*` |
| `Presentation/Common/Components/FTFeedbackViews.swift:20,161` | `Thử lại`, `OK` | UI action | Hard-code SwiftUI literal | `common.action.retry`, `common.action.ok` |

### Circles, Chat, Places, Journey

| File:dòng | Chuỗi gốc / nhóm | Loại | Trạng thái | Key đề xuất |
|---|---|---|---|---|
| `Presentation/Coordinators/MainTabCoordinator.swift:129-167` | Bản đồ, Nhóm, Tin nhắn, Ở đây, Lộ trình, Địa điểm, Cá nhân | Tab/navigation | Hard-code; `tabLabel` đổi String thành `LocalizedStringKey`, không gọi `L10n` | `tab.map`, `tab.circles`, `tab.messages`, `tab.stays`, `tab.journey`, `tab.places`, `tab.profile` |
| `Presentation/Scenes/Circles/List/CircleListView.swift:59,62`; `GroupCard.swift:27,36,53`; `Detail/GroupDetailView.swift:33,56,67,75,92,112,116,122-125`; `Create/CreateGroupSheet.swift:24-68`; `Join/JoinGroupSheet.swift:23-89` | Tiêu đề, tạo/join, hướng dẫn, thành viên/online, mã mời, retry/cancel, detail và dialog direct chat | UI | Nhiều literal SwiftUI hard-code; `Section("Thành viên (...)" )` nội suy; Create/Join textfield có wrapper pha trộn | `circles.*`, `members.count`, `presence.online_count`, `chat.direct.error.*` |
| `Presentation/Scenes/Circles/Components/MemberRowView.swift:18,46,100-111` | Nhắn tin, Bạn, mở chat, hint, pin | UI/accessibility | Một phần: summary/accessibility dùng `L10n.text/format` sentence key; visible button/label hard-code; `presenceKey` dynamic app-owned string | `members.action.message`, `common.you`, `members.accessibility.*`, `members.battery_percent`, `presence.*` |
| `Presentation/Scenes/Circles/List/CircleListViewModel.swift:106,123,209-215`; `Presentation/Scenes/Places/PlacesViewModel.swift:74` | Thành công nhóm/place và lỗi nhóm | Status/error | Một phần qua `L10n.format/text`, nhưng key là nguyên câu; dynamic content được format | `circles.success.*`, `circles.error.*`, `places.success.added` |
| `Presentation/Scenes/Chat/Conversation/ChatView.swift:16,25,60,65,79,128-137,243` | Typing, title, empty, first-message prompt, older messages, composer, recorder labels, retry state | UI/accessibility | Pha trộn: một số `L10n.format/text`, nhiều SwiftUI literals; typing concatenates names + Vietnamese suffix | `chat.*`, `voice.*`, `common.action.load_older`; typing cần template positional |
| `Presentation/Scenes/Chat/ConversationList/ConversationListView.swift:31,55-91`; `ChatViewModel.swift:261` | Title, no-message, image preview, fallback “Ai đó” | UI/dynamic | Một phần: empty/image/fallback lookup; preview nối sender + localized prefix + user message; dynamic name/message giữ nguyên | `chat.list.title`, `chat.preview.image`, `common.person.unknown`, `chat.preview.from_sender` |
| `Presentation/Scenes/Places/PlacesView.swift:68,71,127-191`; `AddPlaceSheet.swift:16-77`; `Entity+Display.swift:63-69` | Place title/count, filters/categories, form, unavailable location, coordinates | UI/enum | Literal/hard-code; `category.displayName` hardcoded Vietnamese nhưng được gửi qua `AppLocalizedText` hoặc `LocalizedStringKey`; count không plural-aware | `places.*`, `places.category.*`, `places.count` |
| `Presentation/Scenes/Timeline/MemberPicker/MemberPickerView.swift:64-121` | Journey/history labels, accessibility, self label | UI/accessibility | Hard-code literal trừ subtitle truyền qua app-localized wrapper | `journey.member_picker.*`, `history.today.accessibility`, `common.you` |
| `Presentation/Scenes/Timeline/History/HistoryView.swift:74,85-86,131-134,167,241`; `HistoryViewModel.swift:43-49` | History title, journey/map toggles, daily journey, map action, formatted date/time range | UI/format | Hard-code và một số `AppLocalizedText`; date label dùng selected locale, time display ở `Entity+Display` hiện ghim vi_VN | `history.*`, `journey.*`, `time.range` |
| `Presentation/Scenes/Timeline/Journey/JourneyView.swift:35,68,108-136,162-225`; `JourneyTimelineRows.swift:77,95,105,124,167,174` | Journey prompt/title, previous/today/next, summaries, arrival/departure/stay/moving, addresses | UI/format/dynamic | Pha trộn; title nội suy tên; `L10n.format` dùng câu làm key; dates được format bằng locale truyền vào, nhưng capitalization/locale cần xác nhận | `journey.*`, `journey.title_for_member`, `journey.empty_for_member`, `journey.segment.moving` |

### Map, SOS, Settings, Notifications, System

| File:dòng | Chuỗi gốc / nhóm | Loại | Trạng thái | Key đề xuất |
|---|---|---|---|---|
| `Presentation/Scenes/LiveMap/Map/LiveMapView.swift:70,78,141,154,172`; `Duration/DurationView.swift:62,65,84,106-123`; `DurationBadge.swift:55`; `StayAlertBanner.swift:40,44,85,99,136-138` | Connection, online/empty, stay status/title, elapsed time, navigation action | UI | Pha trộn; có app-localized wrapper và literal; thời gian ghép template chưa nhất quán | `map.*`, `presence.*`, `stay.*` |
| `Presentation/Scenes/LiveMap/Components/MemberInfoCard.swift:19`; `LiveMapView.swift:172`; `PlacesView.swift:191`; `HistoryView.swift:236` | Tọa độ lat/lon hiển thị với format %.4f/%.5f | Debug/technical data | Coordinate display cần xác nhận có thật sự là user-facing trong production; không nên đưa tọa độ vào notification/error hoặc analytics text | Nếu sản phẩm giữ: `location.coordinate_format`; quyết định trước khi migrate |
| `Presentation/Coordinators/EmergencyCoordinator.swift:42,86-94`; `Presentation/Scenes/SOS/SOSAlertBanner.swift:36-76` | SOS confirm, nội dung gửi mặc định, SOS banner, tên/người gửi, nhóm, nút xem vị trí | UI + nội dung server | Dialog/banner literal; `alert.name`, `alert.message`, group là dữ liệu server/user, hiện render nguyên văn | `sos.*`; phần backend trong mục riêng |
| `App/RealtimeNotificationBridge.swift:25,31`; `Core/PushNotification/PushNotificationService.swift:55-58` | Local notification title/body | Notification | Wrapper SOS title có `L10n.format` sentence-key, nhưng body SOS dùng `alert.message` nguyên văn; stay alert title server-authored và body có template. Push service nhận String không tự localize | `notification.sos.*`, `notification.stay.*`; structured server content cần backend |
| `Presentation/Scenes/Profile/ProfileView.swift:25,33-86,97-100`; `ProfileViewModel.swift:29-33`; `LanguagePicker.swift:9-36` | Profile/settings/account/logout, connection state, language picker | UI | Profile literals; connection state is String literal fed into `AppLocalizedText`; language names are native fixed labels; generic label routes through `L10n.message` | `profile.*`, `settings.*`, `connection.*` |
| `Presentation/Scenes/Debug/NetworkInspectorView.swift:13,22,26`; `Presentation/Coordinators/DebugCoordinator.swift:42`; `Presentation/Scenes/Profile/ProfileView.swift:50,54` | Pulse/debug tools | Debug-only UI | Loại trừ theo chính sách (Debug tooling) | Không cần key app production; nếu localize Debug UX thì là quyết định riêng |
| `Resources/Info.plist`; `Resources/{vi,en}.lproj/InfoPlist.strings` | Location, motion, microphone, local network purpose descriptions | System permission | Đã có đủ 4 mục ở cả hai ngôn ngữ. iOS quyết định ngôn ngữ theo system/app language settings của OS, không theo picker nội bộ | `InfoPlist.strings` key hệ thống, không đổi sang `L10n` |
| `Presentation/Coordinators/DebugCoordinator.swift`, `NetworkInspectorView.swift`; `Core/Logging/*` | Pulse, log, diagnostics | Diagnostics | Loại trừ; không đưa tọa độ/token/raw URL vào chuỗi người dùng | Không dịch |

### Dữ Liệu Động Và Các Trường Hợp Không Dịch

- User content: tên người/nhóm/địa điểm, địa chỉ, nội dung chat, caption và custom message SOS không dịch. Không được hiểu tên do server trả là label UI chỉ vì đang hiển thị trong `Text`.
- System/map data: địa chỉ từ `CLGeocoder` chịu locale/cấu hình geocoder hiện tại; `ReverseGeocoder` không truyền locale của app. Cần quyết định hỗ trợ địa chỉ theo ngôn ngữ app hay giữ theo dịch vụ hệ thống.
- Brand `FamilyTracker`, technical JSON/event/key/protocol strings, coordinates phục vụ debug, logs/Pulse và chuỗi chỉ hiện trong Debug được loại trừ.
- `InfoPlist.strings` là ngoại lệ nền tảng: không bị picker trong app điều khiển; bộ prompt quyền/Photos picker cũng do iOS quản lý.

## Các Vấn Đề Xuyên Suốt

### Lỗi Và Nội Dung Server

- `DomainError.errorDescription`, `AudioRecorderError`, `ImageProcessingError`, `MediaUploadError` trả chuỗi Việt trực tiếp từ Domain/Core. Đây là ranh giới layering cần giải quyết trong implementation plan: lỗi domain nên là code/case ổn định; Presentation chuyển sang localization key.
- `APIError` ánh xạ status nhưng có nhánh dùng trực tiếp `message` server (401, 409, default; validation errors field-level); `MediaUploadError.backend` và `.socketRejected` giữ server message. Các ViewModel thường gán `error.localizedDescription` trực tiếp lên UI. Vì vậy yêu cầu “không hiển thị server message thô, map theo code + fallback” chưa đạt.
- Không thể xác định mapping server-code đầy đủ chỉ từ mobile; cần danh sách `code` ổn định/backend contract. Fallback tổng quát có thể triển khai mobile-side nhưng phải giữ thông tin chẩn đoán đã redacted trong log, không show raw text.

### Plural, Ghép Chuỗi, Locale

- Count cases hiện có: Circle list `"\(count) nhóm"`, members section `"Thành viên (\(count))"`, GroupCard `"\(memberCount) thành viên"`, online count, places `"\(count) địa điểm"`, invite length và các badge. Resources có template `%lld` nhưng không có plural category/`.stringsdict`; tiếng Anh hiện dùng dạng cứng `Members: %lld`, `Circles: %lld`, `Places: %lld`.
- Cần dùng positional placeholders khi có nhiều arguments, ví dụ `%1$@`/`%2$@`, không nối sender/name với nội dung đã dịch. `L10n.format` hiện nhận variadic arguments nhưng test chỉ kiểm tra placeholder multiset, không kiểm tra positional order.
- `Entity+Display.swift` dùng static `DateFormatter` khóa `vi_VN`, ảnh hưởng thời gian Chat/history/arrival/departure kể cả app chọn English. History/Journey date formatter nhận locale được truyền từ view, nhưng các formatter khác cần rà soát theo table. `String(format:)` cho timer/coordinates/diagnostics không nhất thiết là localized; số hiển thị tọa độ đang là technical display.
- Reverse-geocoded address lấy từ Apple Maps service, không có locale app truyền vào.
- Không thấy `RelativeDateTimeFormatter`, `NumberFormatter`, `MeasurementFormatter`; scan phát hiện `DateFormatter`, `ISO8601DateFormatter` (protocol data), `String(format:)` và các format timer/coordinate/log. API date/ISO/network format là kỹ thuật, không nên dịch.

### Duplicates/Key Design

- Tập key hiện dùng câu nguồn tiếng Việt làm key, không có namespace prefix. Cùng nghĩa có nhiều key/câu gần giống: `"Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại."` và `"Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại."`; `"Mã mời phải có 6 chữ số."` và `"Mã mời phải gồm đúng 6 chữ số."`; `"Đang ở đây"` và `"Đã ở đây %@"` là các trạng thái gần nghĩa, cần phân biệt ngữ cảnh. Không nên tự gom khi chưa xác nhận vì có thể thay đổi sắc thái.
- Khai báo trùng `"Đang hoạt động"` là duplicate key thực sự; dòng 10 dịch `Active`, dòng 250 dịch `Active now`. Nên tách theo ngữ cảnh, ví dụ `connection.active` và `presence.active_now`.
- Key đang dùng cả emoji/prefix (ví dụ image preview, SOS/stay title), sentence punctuation, dynamic formats và technical labels; migration nên giữ nguyên bản dịch, đổi key trong cùng change và parity test.

## Glossary

Bảng thuật ngữ ở [i18n-glossary.md](i18n-glossary.md). Các điểm cần thống nhất trước khi viết lại hàng loạt: “Circle”/“Group” (app hiện dịch `Nhóm` nhưng English resources dùng `Circles` và form dùng `Circle`), “Stay”/`Ở đây`/`Ở lại`, “Journey”/`Lộ trình`/`Hành trình`, cách viết “SOS Khẩn Cấp” và cụm “Direct message”.

## Execution Plan G1-G5

Mỗi giai đoạn có commit riêng, chạy toàn bộ build/test/lint được yêu cầu trong task, báo kết quả trước khi chuyển bước. Nếu một giai đoạn cần sửa hơn khoảng 8 file, tách thành commit/đợt nhỏ theo feature; không đổi `project.pbxproj` thủ công. XcodeGen tồn tại tại root (`project.yml`), vì vậy nếu cần resource/file mới phải xác nhận cách project spec tự include chúng trước khi tạo file.

| Giai đoạn | Phạm vi/files dự kiến | Tiêu chí hoàn thành |
|---|---|---|
| G1 - Quy tắc và báo cáo | `AI_RULES.md`, `api-docs/LOCALIZATION.md`, `scripts/test_localization.sh` hoặc scanner mới, tests localization và allowlist có giải thích | Quy tắc cấm hard-code mới; báo cáo scanner tìm key thiếu/empty, literal suspect và bypass API; baseline legacy được lưu nhưng script ban đầu chỉ report; key mới parity; document flow thêm mục Localization. Chốt API `L10n.tr` với code thực tế trước khi viết quy tắc. |
| G2 - Errors/notifications/system | Tách dưới 8 file mỗi commit: error model/mapper + các ViewModel; notification bridge/resources + tests; audit/kiểm tra InfoPlist resources | Map server errors theo code khi contract có; generic localized fallback; loại bỏ raw server text khỏi UI; local notifications có title/body bản địa hóa; purpose strings đã có, chỉ sửa nếu phát hiện thiếu/khác; kiểm tra cancellation/noise. Xuất bảng key/vi/en mới để duyệt. |
| G3 - Màn hình, feature commits | Từng PR/commit nhỏ: Auth; Circles; Chat; Map/Duration; Profile/Settings; Journey/Places; SOS. Tập trung files trong `Presentation/Scenes`, `Coordinators`, `Entity+Display.swift`, enum category/display và resource cặp | Thay app-owned literal bằng L10n; accessibility đi cùng; user/server content giữ nguyên; không migrate quá 8 file trong một commit; key mới vi/en kèm bảng review. |
| G4 - Format và plural | `L10n`/resource plural mechanism (hoặc helper tối thiểu được duyệt), count call-sites, date/display formatters, localization tests và UI layout test/checklist | Locale app được truyền nhất quán cho formatter; plural 0/1/many đúng vi/en; placeholder positional; date/time/number/unit và long strings kiểm tra với Dynamic Type lớn/pseudo-language. |
| G5 - Siết chặt | Scanner/report baseline, CI workflow hiện hữu nếu được duyệt, `PROGRESS.md`, `study/i18n-interview-notes.md` | Chỉ đổi scanner thành CI-failing sau khi baseline sạch/ngoại lệ được review; xác nhận Linux/macOS toolchain phù hợp; update tiến độ và ghi lại quyết định/đánh đổi. |

**Lệnh kiểm tra mỗi giai đoạn (theo yêu cầu):** build Simulator không ký; `scripts/test_networking.sh`; `scripts/test_localization.sh`; `scripts/test_notifications.sh`; SwiftLint; `xcodebuild test` nếu `FamilyTrackerTests` khả dụng; `git diff --check`. Ở G0 không chạy vì chưa sửa code. Báo unavailable/failure đúng thực tế; không báo pass nếu chưa chạy.

## Cần Tôi Quyết Định

| # | Câu hỏi | Đề xuất | Đánh đổi |
|---:|---|---|---|
| 1 | Có thêm ngôn ngữ ngoài vi/en? | Không trong task này; giữ cấu trúc dễ mở rộng. | Không phát sinh scope dịch và QA ngôn ngữ mới. |
| 2 | Server error mapping? | Map theo `code`, generic localized fallback cho code lạ; cần backend cung cấp contract/code list. | Thông báo an toàn, dễ hiểu nhưng có thể mất chi tiết thân thiện mà server hiện gửi cho tới khi mapping đầy đủ. |
| 3 | API `L10n.tr` chưa tồn tại: thêm alias `tr(key, args...)` hay đổi `text`/`format`? | Thêm `tr` theo namespace, có overload không argument/arguments và locale app; migrate dần, giữ API cũ tạm để giảm blast radius. | API alias giữ tương thích nhưng tồn tại hai cách gọi trong giai đoạn chuyển tiếp. |
| 4 | Plural/format API nhỏ nhất? | Dùng `.stringsdict` + helper L10n cho số lượng; giữ positional format helper hiện có hoặc bổ sung overload rõ ràng. | `.stringsdict` chuẩn hệ thống nhưng cấu hình/test phức tạp hơn; không thêm dependency. |
| 5 | `InfoPlist.strings` theo locale OS chứ không theo app picker? | Chấp nhận giới hạn nền tảng hiện tại. | Quyền hệ thống có thể hiện ngôn ngữ khác với nội dung app nếu picker khác OS locale. |
| 6 | G5 scanner cục bộ hay CI đỏ? | Ban đầu report-only; chuyển CI đỏ sau khi baseline sạch. | Tránh block contributor bởi debt cũ; cần một giai đoạn dọn hết ngoại lệ trước. |
| 7 | Sinh key kiểu-safe? | Chưa dùng dependency/codegen; có thể thêm enum/namespace Swift thuần nếu lỗi typo đáng kể. | Enum an toàn hơn nhưng tăng công bảo trì và có thể trùng key data nếu codegen. |
| 8 | Backend-authored content (digest, stay alert, SOS)? | Task backend riêng: gửi `type/code + parameters`, mobile định dạng; giữ text tùy biến thật sự như user content. | Contract cần thay đổi hai phía; không thể dịch chính xác raw text tự do một cách đáng tin cậy. |
| 9 | Reverse geocoding theo app locale? | Truyền locale đã chọn khi có thể hoặc ghi rõ địa chỉ theo ngôn ngữ hệ thống/service; chốt trước G4. | Hành vi geocoder/cache có thể đổi, có thể phải phân biệt cache theo locale. |
| 10 | Hai key `Đang hoạt động` có nên tách riêng? | Có: `connection.active` và `presence.active_now`. | Sửa hai call-sites và entry trùng; nghĩa hiển thị ổn định hơn. |
| 11 | Tọa độ số trên các card/UI có phải production UI? | Xác nhận; nếu chỉ chẩn đoán thì loại khỏi giao diện localization và cân nhắc ẩn production. | Không tự ẩn/đổi hành vi trước khi biết đây có phải tính năng chủ ý. |

## Việc Cho Backend

1. Cung cấp danh mục error `code` ổn định cho Auth/Circles/Chat/Places/History/Media/SOS, cùng ý nghĩa và trường hợp retry; tránh buộc mobile parse `message`.
2. Với thông báo hệ thống do backend soạn (SOS, stay/digest), gửi code/type + typed parameters (actor/group/duration) thay vì chỉ câu tự do; mobile tự localize template.
3. Phân biệt user-authored custom message với app-generated canned SOS text. Custom text giữ nguyên; default canned text nên gửi semantic type hoặc để mobile chọn localized default mà API vẫn tương thích.

## Hạn Chế G0

Đây là scan tĩnh + đọc code thủ công, không runtime snapshot mọi màn hình. Một số UI chỉ hiện khi authenticated/debug/permitted; accessibility text động, native system UI và lỗi backend phụ thuộc dữ liệu runtime. G1 scanner phải được thiết kế report-first, review false positives/allowlist, và G3 cần kiểm tra thủ công song ngữ cho UI có dữ liệu dài.

## Kết Quả Sau G1-G5

- Đã chuyển app-owned presentation strings, accessibility labels, typed user-facing errors, media/audio errors, notification templates, date/time labels, and count forms sang `L10n.tr`/`L10n.plural`. Remaining `L10n.message` use is for dynamic error or content strings and only translates known resource entries.
- Current resources have 411 unique keys per locale, parity is exact, and the scanner reports no missing references, empty values, duplicates, placeholder mismatches, direct API bypasses, or unallowlisted UI literals. Nine exact allowlist rules document language-neutral/brand/debug values.
- `DomainError` and `MediaUploadError` no longer reference localization; `Core/Localization/LocalizedErrors.swift` owns localized presentation.
- Current verification commands/results are recorded in the task close-out. Runtime inspection of authenticated screens at accessibility Dynamic Type and native permission prompt behavior remains manual QA.
- The original G0 counts are historical audit baselines, not current totals. Re-run `bash scripts/test_localization.sh` for the live report.
