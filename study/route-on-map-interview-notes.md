# Route-on-map: ghi chú phỏng vấn iOS

## Phạm vi đã hiện thực

Màn Lộ trình vẽ **GPS đã ghi nhận** của chính người dùng hoặc thành viên Circle
được chọn. `TimelineCoordinator` vẫn quyết định thành viên và điều hướng;
`JourneyViewModel` gọi `FetchDayJourneyUseCase`, dựng `RouteOverlayModel` ngoài
main actor; `JourneyView` chỉ trình bày state. `RouteMapView` bọc `MKMapView`
riêng cho Journey, không thay bản đồ LiveMap. Timeline chữ vẫn hiện trong panel
kéo được để người dùng và VoiceOver đọc được hành trình.

Đây **không phải** chỉ đường đến thành viên và không dùng `MKDirections`. Tuyến
hiện tại nối các GPS fix mà backend trả về, không map-match theo mạng lưới đường.
Không có dữ liệu traffic nên không tô màu giả ùn tắc.

## Quyết định kỹ thuật và đánh đổi

| Quyết định | Lý do | Đánh đổi / giới hạn |
| --- | --- | --- |
| `UIViewRepresentable` + `MKMapView` | SwiftUI `Map` trên deployment target iOS 16 không có `MapPolyline`; `MKPolylineRenderer` cho phép vẽ viền và nét chính. | Phải tự quản lý delegate, overlay, annotation, camera và vòng đời. |
| Một polyline mỗi moving segment | Không nối giả qua khoảng trống hoặc stay point. | Nếu backend chỉ trả đầu/cuối hay một fix thì chỉ có marker/thông báo, không có đường. |
| Douglas-Peucker 8 m | Giảm số đỉnh khi một ngày có nhiều fix, giữ các góc gãy lớn. | Tuyến đơn giản hóa không phải dữ liệu đo gốc; ngưỡng cố định chưa thích ứng zoom. |
| Lọc tọa độ sai/trùng trước khi vẽ | Tránh MapKit nhận giá trị ngoài biên hoặc điểm lặp vô ích. | DTO `points` có timestamp nhưng Domain `MovingSegment.path` hiện chỉ giữ lat/lon; chưa đủ metadata để lọc tốc độ/accuracy đáng tin. |
| Hai lớp nét cased polyline | Nét chính `FTColors.primary`, viền `FTColors.background` giúp tách khỏi nền map sáng/tối. | Giao điểm của nhiều đoạn chưa có logic giao thông hay thứ tự lớp phức tạp. |
| Dấu vân tay hình học và diff overlay | Chọn timeline/geocode không cần duyệt lại hàng nghìn tọa độ; renderer chỉ đổi style đoạn được chọn. | Hash FNV-1a là tối ưu giao diện, không dùng làm định danh bảo mật. |
| `Task.detached` dựng model; `@MainActor` cập nhật state | Giữ đơn giản hóa tuyến khỏi luồng UI, tránh ghi state từ background. | Tác vụ thuần đang chạy có thể hoàn thành sau khi bị cancel; revision guard bỏ kết quả cũ. |
| Panel timeline trong cùng màn hình | Giữ map tương tác và có nguồn thay thế cho VoiceOver. | Phải căn `edgePadding` theo chiều cao panel; Dynamic Type lớn giảm phần map còn nhìn thấy. |

`CoreMappers` hiện hỗ trợ hai dạng có trong repo: `path` + from/to cũ và
`points` + start/end trong tài liệu. Đây là **hỗ trợ tương thích**, chưa phải
xác nhận deploy thực tế. Không log tọa độ, tên thành viên hoặc nội dung lịch sử.

## Câu trả lời STAR mẫu

**Situation:** Màn Journey trước đây chỉ có danh sách chữ và các marker điểm
dừng, nên người dùng khó hiểu hướng di chuyển trong ngày.

**Task:** Hiển thị đường đã đi cho mình hoặc thành viên Circle trên iOS 16,
không làm hồi quy bản đồ realtime và không tạo tuyến sai khi API thiếu GPS fix.

**Action:** Tôi giữ MVVM-C, tạo `RouteOverlayModel` thuần ở Domain, làm thưa
polyline bằng Douglas-Peucker ngoài main actor, và bọc `MKMapView` riêng cho
Journey. Mỗi moving segment là một overlay có viền và nét chính; start/end/stay
có marker. Timeline và map chọn hai chiều, camera fit có padding cho panel.
Parser nhận hai dạng payload đã được tài liệu hóa, nhưng không dựng đường từ
hai endpoint nếu không có path thật.

**Result:** Mã nguồn build Debug/Release Simulator; kiểm tra networking,
localization và SwiftLint đạt. **Chưa có số đo FPS, thời gian dựng 10.000 điểm,
bộ nhớ hoặc thử máy thật**; không nêu phần trăm cải thiện trong phỏng vấn trước
khi đo. XCTest source đã viết nhưng scheme hiện không có Test action.

## Checklist đo cần thực hiện trên iPhone

| Ca | Cách đo | Kết quả |
| --- | --- | --- |
| 0/1 điểm; thiếu path | Kiểm tra empty/marker đơn, không có đường thẳng giả | Chưa đo |
| 1.000 và 10.000 điểm | Instruments Time Profiler; thời gian mở màn, zoom/pan, chọn 10 mục | Chưa đo |
| Mở/đóng Journey 20 lần | Memory Graph và Allocations; MKMapView/delegate không tăng dai dẳng | Chưa đo |
| Dark Mode, chữ lớn nhất, VoiceOver | Casing rõ, không chồng text; đọc đủ timeline | Chưa đo |
| Chọn ngày liên tục, mất mạng, HTTP 403 | Không hiện dữ liệu ngày cũ; lỗi/thử lại đúng | Chưa đo |
| So với hành trình thật | Kiểm tra GPS nhiễu, đường không bám đường khi thiếu map-matching | Chưa đo |

Chỉ ghi các kết quả thực đo sau khi có fixture deploy đã che dữ liệu nhạy cảm,
XCTest target hoạt động và kiểm thử trên thiết bị. Hướng B (`MKDirections` tới
thành viên) là task khác: cần tính tới quyền vị trí, tọa độ gửi cho Apple,
throttle, ngôn ngữ của `MKRoute.Step`, và nút mở Apple Maps thay vì tự viết
turn-by-turn.
