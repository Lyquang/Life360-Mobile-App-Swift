# U0 - Vẽ hành trình đã đi trên bản đồ (iOS 16)

Tài liệu thiết kế, chưa triển khai Swift. Đối chiếu mã tại workspace ngày
2026-10-16 với `study/API_INTERGRATION.MD`. Không có payload Journey thật từ
Pulse/server trong lượt này; **không** suy diễn rằng JSON mẫu phản ánh deploy.

## Xác nhận cách hiểu yêu cầu

**Hướng A đề xuất:** nâng màn `JourneyView` hiện có thành trải nghiệm bản đồ là
chính, vẽ **đường thực tế đã ghi nhận** của thành viên theo ngày, giữ timeline
chữ ở panel kéo được để đọc và chọn đoạn. Đây không phải tìm đường đi tối ưu
trên đường phố. **Hướng B:** tính tuyến từ tôi đến thành viên bằng `MKDirections`
là bài toán khác, chỉ làm sau khi được duyệt riêng.

Điểm cần sửa trong mô tả ban đầu: `JourneyView` **đã có bản đồ SwiftUI `Map`**
cao 240pt và marker stay point, có nút ẩn/hiện, chọn ngày và chọn thành viên ở
màn trước. Cái thiếu là **polyline đoạn đi**, marker đầu/cuối, chọn đoạn từ map,
và bố cục map-first; không phải xây bản đồ từ số 0.

## Hiện trạng kiểm chứng

| Phần | Mã/hợp đồng hiện có | Hệ quả |
| --- | --- | --- |
| Điều hướng | `TimelineCoordinator` mở `MemberPickerView` -> `JourneyView`; `MapCoordinator` cũng mở cùng `JourneyView` từ thẻ thành viên trên live map. | Nâng một màn Journey sẽ phục vụ cả hai lối vào, không sửa điều hướng/SOS. |
| Journey UI | `JourneyView.swift`: summary, `Map(coordinateRegion:annotationItems:)` chỉ vẽ `StayPointMapMarker`, rồi `StayPointRow`/`MovingSegmentRow` trong ScrollView. Tap stay row đổi region; moving row hiện **không** có tap. Nút header hiện 36x36. | Map không có route. Cần tăng hit target 44pt và giữ timeline accessibility. |
| Live map | `LiveMapView.swift` cũng là SwiftUI `Map`, full-screen, avatar `MapMemberPin`; chưa thấy clustering/`MKMapView` wrapper. | Không có lợi thế reuse overlay trong live map. Chọn map riêng cho Journey, không đụng tracking/SOS. |
| Domain | `MovingSegment.path: [GeoPoint]`, đầu/cuối và thời gian; `StayPoint` có tọa độ, arrived/left, duration. `JourneyEntry.points` trả path/stay. | Đủ mô hình đường **nếu** backend thật trả >=2 tọa độ cho mỗi đoạn. Domain chưa có accuracy/timestamp từng tọa độ path. |
| DTO/mapper | `JourneyItemDTO` chấp nhận optional `path: [PathCoordinateDTO]?` và `points: [HistoryPointDTO]?`, nhưng mapper chỉ dùng `path`; với moving còn bắt buộc `fromLatitude/fromLongitude/toLatitude/toLongitude/startTime/endTime`. Thiếu trường -> `compactMap` bỏ entry. | Không được nối thẳng hai đầu để giả vờ là tuyến đã đi. Cần test JSON thật và sửa mapper có chủ đích trước D3. |
| Tài liệu API | `study/API_INTERGRATION.MD` mẫu journey dùng `points` + `startTime/endTime`; moving mẫu **không** có from/to, stay mẫu **không** có arrivedAt/leftAt. | Mẫu hiện mâu thuẫn với DTO/mapper; chưa biết deploy thật dùng schema nào. |
| Lịch sử/ngày | `/history/{userId}` chỉ lấy hôm nay; `/history/{userId}/journey?date=yyyy-MM-dd` đã có. `FetchDayJourneyUseCase` gửi date cho ngày khác; `JourneyViewModel` có Trước/Hôm nay/Sau. | **Đã** chọn được ngày khác trong Journey; không cần endpoint mới cho Hướng A nếu deploy hỗ trợ contract. Raw history ngày khác chưa có. |
| Số/độ chính xác | `summary.totalPoints` có tổng, `HistoryPointDTO` có timestamp, không có accuracy; `PathCoordinateDTO` chỉ có lat/lon. Không thấy giới hạn server hay số điểm tối đa. | Không thể lọc theo `horizontalAccuracy` trên dữ liệu hiện có; speed-based filter cũng không đáng tin khi path thiếu timestamp. Chỉ có thể kiểm tra tọa độ hợp lệ/điểm lặp, và ghi rõ thiếu metadata. |
| Quyền | Tài liệu API: xem bản thân hoặc người có chung ít nhất một Circle; 403 khi không được phép. MemberPicker lấy nhóm rồi gọi members từng nhóm, tải lỗi members hiện bị `try?` biến thành mảng rỗng. | Không suy được "tắt chia sẻ vị trí" chỉ từ hành trình rỗng. 403 phải có trạng thái không quyền riêng, không lộ dữ liệu cũ. |
| Định dạng/cache | `JourneyViewModel.formattedDisplayDate(locale:)` dùng locale từ environment; `DisplayFormat.time` qua `L10n.time`, duration qua `L10n.duration`. Reverse geocode có `GeocodeCache` in-memory theo ô ~11m; JourneyVM giữ address theo `arrivedAt`. Chưa có cache route hình học. | Tái dùng locale đang chọn; cache route riêng theo user/day và phiên bản dữ liệu, không dùng geocode cache làm route cache. |
| Thiết kế | `FTColors.primary` tím, `accent` xanh lá, nền `systemBackground`; `FTSpacing` và font chung. Marker stay đang dùng accent/primary. | Tuyến dùng `FTColors.primary` + casing tương phản theo light/dark; không thêm màu traffic giả. |

**Chưa biết:** payload thực của journey, số điểm/giới hạn, path có timestamp/
accuracy hay không, backend có map-matching không, cách trả về khi thành viên tắt
chia sẻ, hiệu năng ngày dài trên thiết bị thật và chính sách retention. Các điều
này phải được xác minh bằng fixture đã che dữ liệu nhạy cảm hoặc test trên máy;
không ghi tọa độ/tên/địa chỉ vào log hay tài liệu.

## Chọn kiến trúc

| Phương án | Ưu điểm | Đánh đổi | Kết luận |
| --- | --- | --- | --- |
| 1. `RouteMapView: UIViewRepresentable` bọc `MKMapView` chỉ trong Journey | iOS 16 vẽ `MKPolyline`/renderer được; độc lập với live map, dễ rollback | Hai kiểu map trong app, phải tự quản delegate/annotation/camera | **Đề xuất** |
| 2. Chuyển live map sang `MKMapView` rồi tái dùng | Một renderer cho cả live/historical | Đụng avatar realtime, camera, SOS, selection; blast radius lớn | Không làm trong Hướng A |
| 3. Vẽ đường thủ công bằng SwiftUI Canvas trên `Map` | Ít wrapper UIKit | Khó đồng bộ projection/zoom/rotate với MapKit iOS 16 | Không chọn |

Sau khi Hướng A ổn định mới cân nhắc tách renderer/overlay adapter dùng chung
cho live map. Không thay live map trong task này.

### Dữ liệu và hình học

- `RouteOverlayModel` Domain chứa các segment ID ổn định, điểm theo thứ tự, stay
  marker, start/end marker và selected ID. Không import MapKit/CoreLocation.
- D1 dùng Douglas-Peucker thuần trên tọa độ đã project (xử lý unwrap kinh độ qua
  +/-180), giữ điểm đầu/cuối, ranh giới segment và điểm quan trọng; mỗi segment
  làm thưa riêng, không nối các khoảng trống giữa hai segment. Ngưỡng ban đầu
  là **giả thuyết** theo mét, cần đo với ngày dài/zoom; mục tiêu vài trăm điểm
  mỗi segment. Với đường đi qua antimeridian, tính arc ngắn nhất trước khi tạo
  bounding box. Không áp dụng "kẹp 300 điểm" bằng cách bỏ đều nếu gây mất góc.
- Trước khi vẽ: loại NaN, tọa độ ngoài miền, điểm lặp; chỉ lọc accuracy/speed
  khi contract thật cung cấp metadata. Không đổi dữ liệu history gốc. Nếu path
  rỗng hoặc chỉ 1 điểm, không vẽ đường giả từ `from` đến `to`; hiển thị trạng
  thái thiếu hình học và có thể chỉ đặt marker hợp lệ.
- Hình học chạy ngoài main actor qua task/worker, trả về model bất biến; cache
  in-memory theo `(userId, date, dataVersion)` (hash/timestamp của response),
  giới hạn số ngày cache và xóa khi logout/đổi account. `MKMapView` chỉ tạo/cập
  nhật overlay trên main actor. Chưa đưa tọa độ vào disk/UserDefaults.
- Path GPS không được map-match nên có thể cắt ngang đường hoặc gấp khúc; không
  dùng giao thông vàng/đỏ khi không có dữ liệu traffic.

### Bản đồ và tương tác

- Mỗi segment thành `MKPolyline` riêng với ID tra được trong Coordinator của
  `UIViewRepresentable`. Renderer vẽ casing phía dưới và nét chính phía trên,
  bo đầu/cuối, `FTColors.primary` và biến thể tương phản theo trait Light/Dark.
  Đoạn chọn thêm độ dày và marker/nhãn, đoạn khác giảm opacity; không chỉ đổi
  màu. Một mũi tên nhỏ theo chiều đi ở midpoint của **mỗi segment đủ dài** là
  đề xuất đơn giản; không phủ mũi tên dày đặc, giữ start/end marker phân biệt.
- Diff overlay/annotation theo ID + geometry version; đổi selection chỉ cập
  nhật renderer liên quan và camera, không remove/add toàn bộ. `setVisibleMapRect`
  khi tải ngày mới hoặc bấm Căn lại, thêm padding trên và dưới theo header/
  panel/tab bar. Không tự reset camera mỗi lần SwiftUI gọi `updateUIView` sau
  khi người dùng kéo/zoom; nút Căn lại hiện khi camera đã bị chỉnh thủ công.
- Chọn mục timeline -> chọn overlay/marker -> zoom đoạn; tap đường trên map cần
  tự hit-test trong screen space (MapKit overlay không tự là button), xử lý
  tolerance và đoạn giao nhau. Nếu độ tin cậy thấp, ưu tiên danh sách làm nguồn
  chọn và ghi rõ giới hạn thay vì chọn nhầm segment.
- Map chiếm phần lớn viewport. Panel timeline kéo được ở dưới bằng in-screen
  bottom panel 2 mức (thu gọn/mở rộng), để map vẫn nhận gesture trên iOS 16.0;
  `.sheet(presentationDetents:)` có thể chặn tương tác bản đồ ở một số phiên bản
  iOS 16, nên chỉ dùng nếu thử thiết bị chứng minh phù hợp. Danh sách chữ vẫn
  đầy đủ cho VoiceOver. Giảm chuyển động camera khi Reduce Motion bật; kích
  thước chạm >=44pt.
- Không đặt `UIViewRepresentable` hay coordinator trong Domain. Khi rời màn,
  cancel task render/geocode, dọn delegate/observer, tránh giữ vòng tham chiếu;
  không `removeOverlays` mỗi lần state nhỏ đổi.

## Wireframe ASCII (bố cục logic)

```text
THÀNH CÔNG, PANEL THU GỌN               PANEL MỞ RỘNG / ĐÃ CHỌN ĐOẠN
+----------------------------------+    +----------------------------------+
| <  Lộ trình của An  16/10     ... |    | <  Lộ trình của An   16/10        |
| [Trước]      [Hôm nay]    [Sau]   |    |  [Bản đồ: đoạn 2 nổi bật] [Căn]  |
|                                  |    | ~~~~~~~~~~~~~~~  B -> C           |
| A(start) ====>> B(stay)          |    +----------------------------------+
|              \\                  |    | _____ Hành trình trong ngày _____ |
|               ==== C(end)  [Căn] |    | 08:00-08:25  Di chuyển 3,2 km   |
|                                  |    | 08:25-09:05  Dừng 40 phút       |
| ______  Hành trình  ^  _________ |    | 09:05-09:40  Di chuyển ...      |
| 2 điểm dừng · 3 đoạn · 80 phút    |    | [Thu gọn]                        |
+----------------------------------+    +----------------------------------+

ĐANG TẢI                              LỖI MẠNG / SERVER
+----------------------------------+    +----------------------------------+
| Lộ trình của An                  |    | Lộ trình của An                  |
| [Bản đồ giữ nền, chưa có đường]  |    | Không tải được lộ trình.         |
|      (spinner) Đang tải...       |    | [Thử lại]                        |
+----------------------------------+    +----------------------------------+

KHÔNG CÓ DỮ LIỆU                     CHỈ MỘT ĐIỂM / THIẾU PATH
+----------------------------------+    +----------------------------------+
| [Bản đồ khu vực, không có tuyến]  |    | [Bản đồ: A(start=end)]            |
| Chưa có hành trình ngày này.      |    | Chưa đủ điểm để vẽ đường đi.      |
| [Chọn ngày khác]                  |    | [Chi tiết điểm]                   |
+----------------------------------+    +----------------------------------+

403 / KHÔNG QUYỀN                    TẮT CHIA SẺ (CHƯA XÁC MINH)
+----------------------------------+    +----------------------------------+
| Không thể xem lịch sử thành viên. |    | Không có vị trí được chia sẻ.     |
| [Quay lại]                        |    | [Quay lại]                        |
+----------------------------------+    +----------------------------------+
```

Ô "tắt chia sẻ" chỉ được dùng nếu backend có trạng thái phân biệt; không suy
ra từ mảng rỗng. Khoảng cách 3,2 km trong wireframe chỉ là ví dụ; dữ liệu API
hiện không trả distance, nếu hiện thật phải tính **ước lượng từ path GPS** và
ghi rõ, hoặc bỏ số này.

## Key L10n dự kiến

Tái dùng `journey.loading`, `journey.title.member`, `journey.day.*`,
`journey.timeline.title`, `common.action.retry`, `common.action.close` đã có.
Các key mới phải thêm đồng thời ở `vi.lproj` và `en.lproj`:

| Key | vi | en |
| --- | --- | --- |
| `journey.map.action.recenter` | Căn lại lộ trình | Fit journey on map |
| `journey.map.action.expand` | Mở chi tiết hành trình | Expand journey details |
| `journey.map.action.collapse` | Thu gọn chi tiết hành trình | Collapse journey details |
| `journey.map.marker.start` | Điểm bắt đầu | Start point |
| `journey.map.marker.end` | Điểm kết thúc | End point |
| `journey.map.marker.stay` | Dừng %@ | Stay for %@ |
| `journey.map.segment.accessibility` | Từ %@ đến %@, di chuyển %@ | From %@ to %@, moving for %@ |
| `journey.map.empty.day` | Chưa có hành trình ngày này. | No journey for this day. |
| `journey.map.empty.geometry` | Chưa đủ điểm để vẽ đường đi. | Not enough points to draw the route. |
| `journey.map.error.load` | Không tải được lộ trình. | Could not load the journey. |
| `journey.map.error.forbidden` | Không thể xem lịch sử thành viên này. | You cannot view this member's history. |
| `journey.map.status.unavailable` | Không có vị trí được chia sẻ. | No shared location is available. |
| `journey.map.distance.approx` | Khoảng %@ (ước tính) | About %@ (estimated) |

Giờ dùng `L10n.time`/locale đang chọn; duration dùng `L10n.duration`. Nếu hiện
khoảng cách thì `MeasurementFormatter`/`NumberFormatter` dùng chính locale đó,
không `String(format:)` cố định. Tên người, địa chỉ là nội dung do người dùng/
hệ thống cung cấp, không dịch. Text panel có label đầy đủ, không phụ thuộc
overlay vốn không đọc tốt bởi VoiceOver. Haptic nhẹ chỉ trên selection có chủ
đích, không rung theo từng cập nhật GPS.

## Execution Plan sau khi U0 được duyệt

Mỗi D là một commit riêng, tối đa khoảng 8 file. Sau từng D: Debug/Release
simulator unsigned build, `scripts/test_networking.sh`,
`scripts/test_localization.sh`, SwiftLint, `xcodebuild test` nếu scheme có test
target, `git diff --check`; báo kết quả thật rồi mới làm giai đoạn kế. Hiện
`FamilyTracker.xcodeproj` chưa khai báo `FamilyTrackerTests` trong project/scheme;
không sửa `project.pbxproj` bằng tay và không coi test source là XCTest đã chạy.

| Giai đoạn | File dự kiến (<=8) | Tiêu chí hoàn thành |
| --- | --- | --- |
| D1 - Logic thuần | Mới `Domain/Policies/PolylineSimplifier.swift`, `Domain/Entities/RouteOverlayModel.swift`; `FamilyTrackerTests/PolylineSimplifierTests.swift`, `RouteOverlayModelTests.swift` | Đường thẳng/đỉnh cong/điểm trùng/rỗng/1 điểm/qua +/-180, thứ tự segment, bounding box, 10.000 điểm có số điểm đầu ra và thời gian đo. Không MapKit/I/O. |
| D2 - MapKit cô lập | Mới `Presentation/Scenes/Timeline/Journey/RouteMapView.swift`, `RouteMapRenderer.swift`, Preview/fixture ở file mới, test geometry/renderer nếu khả dụng | `MKMapView` vẽ casing + nét chính, marker stay/start/end, camera fit/padding, selection diff, tap map theo quyết định, dọn delegate. Chưa gắn vào Journey. |
| D3a - Hợp đồng dữ liệu | Chỉ nếu payload thật khác mapper: `HistoryDTOs.swift`, `CoreMappers.swift`, `Journey.swift`, test fixture JSON và repository; chỉnh use case nếu thực sự cần | Không `compactMap` mất moving/stay; giữ path/thời gian/accuracy **nếu backend có**; 403 và path thiếu ra state rõ. Không tự sửa backend. Đây là cổng trước D3b. |
| D3b - Journey UI | `JourneyView.swift`, `JourneyViewModel.swift`, `JourneyTimelineRows.swift`, hai `Localizable.strings`, test ViewModel/selection, `TimelineCoordinator.swift` nếu cần | Map-first + panel kéo, chọn từ danh sách và map, ngày/thành viên, loading/error/empty/1 điểm/403, VoiceOver; không đụng LiveMap. Chỉ sau khi khóa Presentation mở. |
| D4 - Đo và chốt A | `study/route-on-map-interview-notes.md`, `PROGRESS.md`, test/fixture liên quan | Instruments và kiểm tra thiết bị thật; không tuyên bố "mượt" nếu chưa đo. Ghi giới hạn GPS không map-match và độ chính xác. |
| D5 - Chỉ đường tới thành viên | **Không làm khi chỉ duyệt U0/A**; lập spec riêng cho `RoutingService`/MKDirections/use case + UI | Cần duyệt phạm vi, quyền riêng tư gửi tọa độ cho Apple, throttle, Apple Maps và ngôn ngữ hệ thống. |
| D6 - Tài liệu | `AI_RULES.md`, `PROGRESS.md`, ghi chú phỏng vấn nếu chưa cập nhật | Đồng bộ lại quy tắc kiến trúc và kết quả thực đo. |

Giữ route Hướng B riêng: nếu được duyệt sau, Domain protocol không import
MapKit, Data/Core bọc `MKDirections`; quyết định tính lại bằng hàm thuần theo
khoảng cách/thời gian, chỉ foreground; hủy request cũ. Chỉ hiện tóm tắt theo
locale app và mở Apple Maps để turn-by-turn. Không hiện thô `MKRoute.Step`
theo ngôn ngữ hệ thống nếu chưa chấp nhận giới hạn i18n; không giả traffic
theo từng đoạn. `showsTraffic` chỉ là overlay hệ thống, cần quyết định riêng.

### Checklist thủ công

- Trên iOS 16, ngày 0/1/nhiều điểm, có nhiều stay/segment; đổi ngày liên tiếp;
  mạng yếu/lỗi/403; path thiếu; bản đồ không nối qua khoảng trống.
- Ngày hàng nghìn điểm: zoom/pan/tap segment, panel kéo, căn lại, đổi selection;
  so đường thực trên iPhone; đo Time Profiler/Memory Graph/Energy Log.
- VoiceOver đọc được timeline và marker, Dynamic Type lớn không che điều khiển,
  Dark Mode/Reduce Motion, vòng chạm >=44pt; mở/đóng màn nhiều lần không tăng
  memory; live map/SOS/chat giữ nguyên.
- Hướng B chỉ sau duyệt: ở Việt Nam trên iOS 16, thử route ngắn/dài, đích di
  chuyển, throttle, mất mạng/quyền, mở Apple Maps; không lộ tọa độ trong log.

## Rủi ro, rollback và việc backend

Rủi ro lớn nhất là **mismatch contract** và thiếu path thực: nếu server chỉ trả
đầu/cuối, mobile không thể phục dựng đường đã đi. Cần backend trả chuỗi điểm
theo segment hoặc endpoint lịch sử theo ngày/khoảng thời gian; cùng với timestamp
và horizontalAccuracy nếu muốn lọc speed/accuracy đáng tin. Backend cũng nên
nêu số điểm tối đa, quyền xem lịch sử, retention, và có thể làm thưa/map-match
server-side cho ngày dài. Không gửi dữ liệu nhạy cảm vào issue/log công khai.

Rollback: D1/D2 độc lập với UI; D3a chỉ sửa mapping có fixture; D3b có thể
revert về JourneyView hiện tại mà không chạm live map. Từng D là commit riêng.

## Cần tôi quyết định trước khi code liên quan

1. Xác nhận Hướng A (vẽ đường **đã đi**) là mục tiêu chính; Hướng B để task
   riêng sau D4 (đề xuất), hay muốn duyệt đồng thời?
2. Chọn `RouteMapView` riêng cho Journey (đề xuất, ít rủi ro) hay đổi live map
   sang `MKMapView` (rủi ro cao hơn).
3. Giữ timeline chữ trong bottom panel kéo được (đề xuất vì VoiceOver) hay bỏ?
4. Chỉ chiều đi bằng 1 mũi tên/segment + start/end khác hình (đề xuất), gradient
   theo thời gian (cần timestamp từng điểm), hay không cần?
5. Chọn ngày khác hôm nay: **đã có trên Journey**; đề xuất giữ nguyên. Có muốn
   thêm raw history ngày khác/đổi phạm vi ngày không?
6. Có bật `showsTraffic` trong Hướng B không (đề xuất không, tránh hiểu nhầm
   đây là traffic của hành trình lịch sử)?
7. Hướng B: chỉ tóm tắt + mở Apple Maps (đề xuất), hay chấp nhận Step tiếng hệ
   thống không theo ngôn ngữ app?
8. Tap đoạn trên map để chọn timeline: đề xuất làm sau chọn từ list, kèm
   hit-test có ngưỡng; nếu giao nhau quá nhiều thì bỏ tap map để tránh chọn sai.
9. **Cần xác nhận payload thật:** dùng `path`/`arrivedAt`/`from...to...` như
   mapper, hay `points`/`startTime`/`endTime` như mẫu doc? Đề xuất cung cấp
   fixture đã xóa tọa độ/tên thật hoặc kiểm tra Pulse; D3a dừng nếu chưa rõ.
10. Có nhánh/PR đang khóa Presentation (i18n/ChatHub/refactor) hay Location/
    Realtime không? D1 và D2 file mới có thể làm độc lập; D3b chờ mở khóa.
11. Panel trong màn hình (map vẫn tương tác, đề xuất) hay sheet hệ thống
    `presentationDetents` (native hơn nhưng phải kiểm chứng tương tác map trên
    iOS 16.0 thật)?

Không thêm dependency, không đổi backend, không log tọa độ/token/tên/địa chỉ.
