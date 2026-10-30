# Thí nghiệm pin, GPS, dữ liệu mạng và chi phí giám sát - T0

Trạng thái 23/10/2026: **quy trình, chưa có kết quả đo**. Không dùng dữ liệu Simulator để kết luận pin/4G. Các bảng dưới đây giữ `Chưa đo` cho đến khi chạy trên iPhone thật. Tài liệu thiết kế: [mobile-monitoring.md](mobile-monitoring.md).

## Câu hỏi và chỉ số

### Thao tác với bản Debug hiện tại

1. Mở app, đăng nhập rồi mở bảng Pulse bằng nút Debug. Bấm biểu tượng biểu đồ để vào **Chẩn đoán ứng dụng**.
2. Kéo để làm mới sau một lượt thử. Nút chia sẻ xuất `FamilyTracker-Metrics.json`; đây là report tổng hợp, khác với nút xuất log AI trong Pulse.
3. JSON có hai phần `windows` và `metricKit`. `windows.start` dùng mặc định Codable Date của Swift: số giây từ 01/01/2001 UTC, không phải Unix epoch. Dictionary có khóa enum có thể encode thành mảng key/value xen kẽ; không giả định mọi dictionary đều là JSON object.
4. Màn mạng hiện cộng tất cả loại mạng theo các cửa sổ còn lưu. Muốn phân tích riêng cellular, đọc nhãn network trong JSON. Không gọi tổng hiển thị là “4G mỗi giờ”. Một cửa sổ đầu/cuối có thể chỉ bao phủ một phần thí nghiệm, nên ghi rõ sai số thời gian.
5. Report MetricKit chưa có là trạng thái bình thường; không thay bằng 0. Release hiện không thu collector/MetricKit và không có màn Debug. Thí nghiệm Release bằng Instruments/Settings là lượt riêng, không thể dùng nó để xác nhận đầy đủ đường xuất Debug.
6. Trong Instruments, tìm subsystem `com.familytracker.app`, category `performance`; các mốc hiện có được giải thích trong [ghi chú phỏng vấn](mobile-monitoring-interview-notes.md). Chưa có marker “màn đầu đã vẽ xong”; không dùng `ComposeApp` làm launch-to-first-frame.

**M1 chưa sẵn sàng end-to-end:** chưa có công tắc tắt toàn bộ instrumentation, gồm collector, MetricKit, observer và signpost. `MobileMetricsCollector.setEnabled(false)` chỉ tắt collector; không đủ làm đối chứng toàn hệ thống. Giữ hàng M1 ở trạng thái chưa đo cho tới khi có cấu hình bật/tắt thống nhất và được kiểm chứng. Chưa thực hiện đo trên iPhone trong phiên làm việc này.

1. App đang chạy chia sẻ vị trí làm mức pin **toàn máy** thay đổi thế nào so với cùng máy không chia sẻ? Phân biệt foreground/background, stationary/walking/cycling/automotive, màn hình bật/tắt.
2. GPS chạy bao lâu ở mỗi mức accuracy thực tế theo MetricKit, so với chế độ mà app nghĩ đang áp dụng? Có chuyển từ standard sang significant-change khi đứng yên không?
3. Mỗi giờ/ngày, app dùng bao nhiêu Wi-Fi/cellular theo MetricKit? REST/Socket/media ước tính đóng góp bao nhiêu và coverage thiếu ở đâu?
4. Sau thay đổi thuật toán/location trail, p50/p95 fix handling, CPU, memory, disk, launch/hang/scroll hitch có xấu đi không? Bật collector có tự làm tăng chi phí không?

**Không có API đọc “FamilyTracker tiêu thụ X% pin”.** `UIDevice.batteryLevel`, Settings > Battery và Instruments đo các góc khác nhau; không gán chênh lệch pin toàn máy là năng lượng riêng của app. MetricKit thường gửi tổng hợp khoảng 24 giờ và không tự tách đúng một thí nghiệm 30 phút; dùng Instruments và log cửa sổ cục bộ cho khoảng ngắn. [MetricKit](https://developer.apple.com/documentation/metrickit), [Apple Battery Usage](https://developer.apple.com/documentation/xcode/analyzing-your-app-s-battery-use).

## Chuẩn bị cho một cặp đo A/B

- Cùng **một iPhone**, bản iOS, SIM, nhà mạng, cấu hình thông báo/quyền, thiết bị kết nối Bluetooth, độ sáng cố định (tắt Auto-Brightness/Night Shift nếu có thể), cùng chất lượng mạng và mức pin khởi đầu trong một dải hẹp (ví dụ 70-80%). Không sạc, không dùng Low Power Mode trừ khi đó là biến thí nghiệm. Ghi ngày/giờ, nhiệt độ môi trường, tình trạng nóng máy, % pin đầu/cuối và phút sử dụng màn hình.
- Dùng bản Release ad hoc/TestFlight khi đo năng lượng thực, tránh ảnh hưởng debugger, Pulse và Xcode tether; khi cần Instruments thì ghi rõ đó là phiên đo có gắn công cụ. Giữ build/commit và cấu hình Backend cố định trong một cặp. Không chạy thêm app nặng, không thay đổi tải bản đồ/ảnh giữa hai lần.
- Đối chứng “không có app chạy”: tắt chia sẻ, xác minh không còn location/socket work rồi đóng app. Nếu force-quit, ghi rõ vì iOS có thể thay đổi hành vi relaunch nền; đây là **baseline hệ thống**, không phải phép đo chính xác công suất của app. Không xoá app giữa các lần vì có thể đổi cache/quyền.
- Với đi bộ/lái xe, dùng cùng tuyến đường và cùng khoảng thời gian/khung giờ mạng càng gần nhau càng tốt; không thể tái tạo sóng và traffic y hệt. Người cầm lái **không thao tác điện thoại**, người ngồi cùng phụ trách kiểm tra. Đóng gói trước route/screenshot chỉ sau khi xóa tọa độ, tên và địa chỉ.
- Thứ tự thử A/B nên đảo chiều giữa các lần (`A-B`, `B-A`, `A-B`); cho máy nguội và quay về dải pin khởi đầu trước cặp tiếp. Mỗi kịch bản ít nhất **3 lần**, báo trung bình, min/max hoặc độ lệch chuẩn; không suy luận từ khác biệt 1 điểm % đơn lẻ.

## Ma trận chạy

| Mã | Kịch bản và thời lượng | A (đối chứng) | B (can thiệp) | Thứ khác giữ cố định |
| --- | --- | --- | --- | --- |
| S1 | Đứng yên, màn hình tắt, 60 phút | Tắt chia sẻ/đóng app | Bật chia sẻ nền | Cùng Wi-Fi, không sạc; xác minh stationary và significant-change. |
| S2 | Đi bộ, 30 phút | Không chia sẻ | Chia sẻ live trail | Cùng đường; ghi Wi-Fi hoặc cellular, không trộn hai loại. |
| S3 | Đi xe, 30 phút | Không chia sẻ | Chia sẻ live trail | Cùng đường; điện thoại cố định; người đi cùng thao tác. |
| S4 | Đi bộ, 30 phút | Bản/chính sách `minSendInterval` hiện tại | Một cấu hình thử đã duyệt | Chỉ đổi **một** tham số, build tag khác; không sửa policy âm thầm trong thí nghiệm. |
| S5 | Đi bộ, 30 phút | Live trail off | Live trail on | Cùng thuật toán GPS; Backend match on/off là biến riêng, đo thêm quota Mapbox bên server. |
| S6 | Offline 20 phút rồi online | Không có điểm buffer | Có batch replay | Cùng số fix đầu vào; đo spike REST, CPU, disk và thời gian đồng bộ. |
| M1 | Cùng kịch bản S1/S2 | Collector kill switch off | Collector on | **Đo chi phí riêng của giám sát**; cả hai vẫn chạy cùng tính năng app. |

Không thể kiểm soát một tuyến đường tuyệt đối như phòng thí nghiệm; mọi kết luận ghi phạm vi máy/mạng/điều kiện. Tránh dùng cùng lúc “collector off” và “live trail off” trong M1.

## Các bước một lần chạy

1. Ghi `trial_id` ngẫu nhiên trong sổ đo **ngoài app** (không đưa vào telemetry), build/version, ngày, iPhone model **trong sổ kiểm thử** (không gửi T4), iOS, network mode, cellular signal bars, nhiệt độ, Low Power/charging và mức pin. Chờ máy ổn định 5-10 phút; ghi màn hình bật/tắt.
2. Bắt đầu thao tác đã định, dùng đồng hồ bên ngoài. Với bản có collector, ghi `window_start/end`, `motion_state`, số fix/emit/buffer, `accuracy_mode`, byte từng nhóm, `coverage`. Khi foreground hoặc người dùng chủ động mở chẩn đoán mới xuất bản tóm tắt; **không đánh thức app để lấy số**.
3. Sau đúng thời lượng, ghi mức pin cuối, số lần app bị kill/relaunch, nhiệt, tín hiệu, người dùng có mở app khác không. Lưu bản tóm tắt **không chứa vị trí/ID**. Nếu collector không hoạt động ở một nhịp, ghi thiếu dữ liệu, không nội suy.
4. Dùng Instruments **Energy Log**, Time Profiler, Allocations/Leaks, Network hoặc signposts tương ứng, đặc biệt S1 (background) và M1 (overhead). Instruments có thể thay đổi năng lượng; đối chiếu cấu hình nhưng không trộn số với phiên không cắm debugger.
5. Sau khi iOS gửi MetricKit, ghi `timeStampBegin/End`, `includesMultipleApplicationVersions`, CPU/background location/accuracy/network/memory/disk; báo cáo nào bao trùm nhiều kịch bản thì **không gán riêng** cho một kịch bản. Trong Xcode, `Debug > Simulate MetricKit Payloads` chỉ kiểm tra parser/UI, không đưa vào bảng năng lượng thật. [Apple MXMetricManager](https://developer.apple.com/documentation/metrickit/mxmetricmanager).
6. Kiểm tra **Cài đặt > Pin** và Xcode Organizer (nếu build đã phân phối TestFlight/App Store). Settings là một góc kiểm chứng, Organizer không khả dụng cho Personal Team local build; không cộng các % từ các nguồn khác nhau. [Apple Organizer](https://developer.apple.com/documentation/xcode/analyzing-the-performance-of-your-shipping-app).

## Bảng nhập dữ liệu thô (một dòng/một trial)

| Trial | Mã | A/B | Build | Phút | Mạng | Pin đầu/cuối (%) | Sạc? | Nhiệt/thermal | Màn hình bật (phút) | GPS mode (phút) | Emit | Cellular/Wi-Fi (MiB) | CPU (s) | Ghi chú nhiễu |
| --- | --- | --- | --- | ---: | --- | --- | --- | --- | ---: | --- | ---: | --- | ---: | --- |
| Chưa đo | S1 | A | Chưa đo | 60 | Chưa đo | Chưa đo | Không | Chưa đo | 0 | Chưa đo | Chưa đo | Chưa đo | Chưa đo | Chưa đo |
| Chưa đo | S1 | B | Chưa đo | 60 | Chưa đo | Chưa đo | Không | Chưa đo | 0 | Chưa đo | Chưa đo | Chưa đo | Chưa đo | Chưa đo |

## Bảng tổng hợp theo kịch bản

| Mã | n A/B | Pin toàn máy A/B (%/h; mean +/- SD) | Chênh có ý nghĩa? | Cellular A/B (MiB/h) | Fix/emit/buffer | CPU p50/p95 | OS high-accuracy (phút) | Collector overhead | Kết luận giới hạn |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| S1 | Chưa đo | Chưa đo | Chưa kết luận | Chưa đo | Chưa đo | Chưa đo | Chưa đo | N/A | Chưa đo |
| S2 | Chưa đo | Chưa đo | Chưa kết luận | Chưa đo | Chưa đo | Chưa đo | Chưa đo | N/A | Chưa đo |
| S3 | Chưa đo | Chưa đo | Chưa kết luận | Chưa đo | Chưa đo | Chưa đo | Chưa đo | N/A | Chưa đo |
| M1 | Chưa đo | Chưa đo | Chưa kết luận | Chưa đo | Chưa đo | Chưa đo | Chưa đo | Chưa đo | Chưa đo |

Tính `pin_hao_%/h = (pin_đầu - pin_cuối) * 60 / phút` **chỉ** khi không sạc, đủ 30 phút và không đổi điều kiện lớn; biểu thị mức giảm của toàn máy. Chênh `B-A` là so sánh trong điều kiện cụ thể, không phải công suất riêng của app. Nếu mức chênh cùng bậc với độ phân giải pin 1%/độ phân tán giữa các lần, ghi **không kết luận**. Với dữ liệu mạng, chuyển byte sang MiB bằng `1_048_576`; ghi `URLSessionTaskMetrics`/Socket estimate/MetricKit thành các cột khác nhau, không cộng trùng.

## Đo overhead của collector (M1)

| Chỉ số | Kill switch off | On | Chênh | Gate dự kiến (giả thuyết) | Kết quả |
| --- | --- | --- | --- | --- | --- |
| CPU trên 30 phút | Chưa đo | Chưa đo | Chưa đo | <1 điểm % | Chưa đo |
| Peak memory | Chưa đo | Chưa đo | Chưa đo | <2 MiB | Chưa đo |
| Disk written | Chưa đo | Chưa đo | Chưa đo | <=256 KiB store + atomic rewrite đã đo | Chưa đo |
| Background wakeups | Chưa đo | Chưa đo | Chưa đo | 0 thêm | Chưa đo |
| Network bytes T1-T3 | Chưa đo | Chưa đo | Chưa đo | 0 thêm | Chưa đo |
| p95 xử lý một fix | Chưa đo | Chưa đo | Chưa đo | <1 ms thêm | Chưa đo |

Nếu overhead vượt gate, trước tiên giảm tần suất ghi file, số histogram/nhãn và việc encode JSON trong hot path; không bật thêm sensor hoặc timer nền để “đo chính xác hơn”. Các gate chỉ là mục tiêu ban đầu, chỉnh sau 3 lần chạy và ghi lý do.

## Kiểm tra chất lượng/riêng tư trước khi chốt

- Bản tóm tắt, file xuất và (nếu sau này có) request T4 qua JSON schema allowlist: không có `latitude`, `longitude`, đường URL, tọa độ dạng chuỗi, user/email/name/token/message/SSID hay ID thiết bị; không serialize raw MetricKit diagnostics/Pulse. Quét thêm dữ liệu mẫu chứa những giá trị này và khẳng định chúng **không thể đi qua serializer**.
- Chạy trường hợp mất mạng, đổi Wi-Fi/cellular, ứng dụng xuống nền/bị kill, quyền GPS đổi, Low Power, thermal serious, kết nối socket lại, replay buffer; collector lỗi/đầy thì sharing/chat/SOS vẫn hoạt động.
- Kiểm tra instrumentation iOS 16 trên iPhone thật, Dynamic Type/VoiceOver của màn Debug khi T3 có; công bố giới hạn “ước tính” cạnh byte socket và pin toàn máy. Không đưa log chứa GPS lên repo hay công cụ bên ngoài.
