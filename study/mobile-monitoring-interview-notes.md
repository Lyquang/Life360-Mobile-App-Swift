# Monitoring iOS: ghi chú ôn tập phỏng vấn

Tài liệu phản ánh code tại nhánh có màn chẩn đoán Debug. Các số đo pin, CPU, lưu lượng và chi phí monitoring trên iPhone thật **chưa được thu thập**. Không trình bày mục tiêu thiết kế như kết quả đã đạt.

## 1. Mỗi công cụ trả lời câu hỏi nào?

| Thành phần | Câu hỏi trả lời | Giới hạn |
| --- | --- | --- |
| `MobileMetricsCollector` | Có bao nhiêu request, fix GPS, emit, byte trong các cửa sổ? | Chỉ các đường đã nối instrumentation; dữ liệu cục bộ Debug. |
| `URLSessionTaskMetrics` | Request truyền bao nhiêu byte, mất bao lâu? | Theo transaction/session được instrument; không đại diện toàn bộ traffic của máy. |
| Socket counters | Payload sự kiện Socket.IO lớn bao nhiêu? | Không tính framing, TLS, ping/pong và mọi chi phí truyền lại. |
| `MetricKitReceiver` | Hệ điều hành đo CPU, network, location và memory thế nào? | Báo cáo tổng hợp đến trễ; không gán cho một thao tác đơn lẻ. |
| `PerformanceSignposts` | Một công việc bắt đầu/kết thúc lúc nào? | Đo elapsed time, có thể gồm thời gian chờ mạng hoặc scheduling. |
| `BatteryMonitor` | Mức pin toàn máy tại thời điểm lấy mẫu? | Không cho biết riêng app dùng bao nhiêu phần trăm pin. |

Tham chiếu: [collector](../FamilyTracker/Core/Monitoring/MobileMetricsCollector.swift), [MetricKit](../FamilyTracker/Core/Monitoring/MetricKitSummary.swift), [signposts](../FamilyTracker/Core/Monitoring/PerformanceSignposts.swift).

## 2. Vì sao dùng actor và cửa sổ cố định?

GPS, callback mạng và socket có thể đến từ các executor khác nhau. Actor tuần tự hóa truy cập vào bộ đếm, tránh hai callback cùng đọc và ghi đè kết quả. Nó không đồng nghĩa mọi công việc chạy trên cùng một thread.

Collector chia cửa sổ 15 phút khi nhận sự kiện hoặc đọc snapshot, thay vì tạo timer đánh thức app ở nền. Bucket cố định và enum nhãn giới hạn số tổ hợp. Store giữ tối đa 96 cửa sổ/256 KiB; khi vượt trần phải bỏ dữ liệu cũ. Vì vậy tổng trên màn hình là tổng dữ liệu còn giữ, không mặc định là chính xác 24 giờ.

Đánh đổi: Task chuyển sự kiện vào actor vẫn có chi phí; giới hạn dữ liệu không chứng minh CPU thấp. Phải đo M1 bằng Instruments trước khi tuyên bố monitoring nhẹ.

## 3. Signpost có phải response time không?

Trong [ChatHubViewModel](../FamilyTracker/Presentation/Scenes/Chat/ChatHubViewModel.swift):

```swift
let signpost = PerformanceSignposts.begin(.loadChats)
defer { PerformanceSignposts.end(.loadChats, signpost) }
```

`begin` tạo mốc đầu; `defer` chạy khi rời phạm vi hàm, kể cả khi lỗi hoặc return sớm. ID riêng ghép đúng cặp khi nhiều lần gọi trùng nhau về thời gian. Tên interval lấy từ danh sách cố định, không có URL hay ID người dùng.

`LoadChats` bao gồm chờ các request và ghép danh sách. Nó không phải riêng response time của một endpoint, không phải thời gian CPU và không xác nhận SwiftUI đã vẽ xong. Muốn tìm nguyên nhân chậm, đặt signpost cạnh Network/Time Profiler trong cùng trace để phân biệt chờ I/O với CPU bận.

| Mốc hiện có | Phạm vi |
| --- | --- |
| `ComposeApp` | Khởi tạo các dependency trong AppContainer. Không phải toàn bộ launch time. |
| `RestoreSession` | Luồng khôi phục phiên. |
| `LoadJourney` | Tải và dựng model; không bao gồm toàn bộ render MapKit hoặc geocode bất đồng bộ phía sau. |
| `LoadChats` | Tải nhóm/hội thoại/unread và ghép danh sách. |
| `UploadMedia` | PUT và xử lý kết quả; không gồm xin ticket hay socket ack. |
| `DeliverLocationFix` | Chuyển phát sau policy, gồm đường socket hoặc buffer; không bao gồm toàn bộ GPS callback/throttle. |

## 4. Vì sao số byte của các nguồn khác nhau?

REST task metrics và media metrics đo các đường URLSession tương ứng. Socket dùng kích thước JSON payload và nhãn mạng từ path observer, nên chỉ là ước tính. Đổi mạng giữa lúc đo, cache, retry và request không instrument đều có thể làm chênh với MetricKit.

So sánh cùng khoảng thời gian và cùng coverage. Không cộng MetricKit vào tổng REST + media + socket: đó là hai góc quan sát có thể trùng nhau. AVPlayer và tài nguyên bản đồ chưa có bộ đếm app-level đầy đủ trong triển khai hiện tại.

## 5. Riêng tư và lưu trữ

Report xuất từ `MobileMonitoringReport` chỉ gồm typed windows và MetricKit summaries. Không xuất raw Pulse request, nội dung chat, tọa độ hoặc call stack. File xuất có trần 512 KiB; enum giới hạn loại nhãn, còn redactor là lớp bảo vệ khác cho log.

Release hiện không bật collector/MetricKit subscriber. Các signpost tĩnh vẫn có trong code Release để phục vụ Instruments; không nhầm chúng với báo cáo telemetry gửi server. T4 chưa có endpoint/consent được tích hợp, app chưa gửi báo cáo monitoring lên backend.

File tổng hợp được bảo vệ bằng data protection và loại khỏi backup. Logout/hết phiên dọn store; không nhập lại `pastPayloads` sau logout. Tuy nhiên MetricKit là số liệu cấp ứng dụng và có thể bao trùm nhiều phiên; không thể coi đó là báo cáo riêng của một tài khoản.

## 6. Mẫu STAR trung thực

**Situation:** FamilyTracker chia sẻ vị trí nền, dùng socket và upload media; cần biết tác động lên pin/mạng trước khi tối ưu thuật toán.

**Task:** Xây hệ đo cục bộ với dữ liệu tổng hợp, không thu vị trí hay nội dung người dùng, và phân biệt số đo app với số đo hệ điều hành.

**Action:** Tôi dùng actor với cửa sổ/bucket cố định, nối task metrics và bộ đếm payload socket, rút gọn báo cáo MetricKit, thêm signpost vào các luồng chính và màn Debug xuất JSON. Tôi chuẩn bị thí nghiệm A/B cùng thiết bị, ít nhất ba lần cho mỗi kịch bản.

**Result hiện tại:** Có công cụ thu/xem/xuất số liệu và các build/static checks đã chạy ở từng nhịp. XCTest còn bị chặn bởi scheme thiếu Test action. Chưa có dữ liệu thực nghiệm để khẳng định giảm bao nhiêu pin hoặc CPU. Khi có kết quả, thay đoạn này bằng số đo kèm điều kiện, độ phân tán và giới hạn.

## 7. Câu hỏi Tech Lead có thể hỏi tiếp

1. **Thấy signpost dài có kết luận CPU cao không?** Không; elapsed time có thể chủ yếu chờ mạng. Đối chiếu Time Profiler và network trace.
2. **Mạng mất giữa request thì số byte có bằng kích thước ảnh không?** Không nhất thiết; có retry, header, transfer chưa hoàn tất và khác biệt cache/protocol.
3. **Tại sao không lưu mọi sự kiện thô?** Tăng chi phí ghi đĩa, cardinality và nguy cơ lộ dữ liệu; counters/bucket đủ cho câu hỏi đã định.
4. **Làm sao chứng minh app ít tốn pin?** Thí nghiệm có kiểm soát và số liệu hệ điều hành; không dùng riêng mức pin đầu/cuối một lần chạy.
5. **Làm sao chứng minh monitoring không làm app chậm?** Đo A/B với toàn bộ instrumentation bật/tắt và cùng workload. Công tắc toàn cục phục vụ thí nghiệm vẫn cần hoàn thiện; chỉ tắt collector chưa loại toàn bộ overhead.

Quy trình và bảng kết quả: [mobile-energy-experiments.md](mobile-energy-experiments.md).
