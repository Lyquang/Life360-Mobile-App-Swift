# Giám sát pin, mạng, GPS và hiệu năng Mobile - T0

Trạng thái: **thiết kế, chưa viết code** (23/10/2026). Phạm vi iOS 16, Combine, MVVM-C. Mục tiêu là đo tác động của **FamilyTracker**, không gán phần trăm pin của cả iPhone cho app. Không sửa backend và không gửi telemetry trong T1-T3.

## Hiện trạng đã kiểm chứng

| Nơi trong repo | Đang có | Khoảng trống đối với task này |
| --- | --- | --- |
| `Core/Logging/LocationDiagnostics.swift` | `NSLock`, bộ đếm emit theo `MotionActivity`, heartbeat attempt, đổi motion, tái cấu hình manager, drop accuracy âm, offline enqueue, send/hold/drop theo lý do; phân đoạn thời gian/mức pin; tóm tắt Debug mỗi 15 phút, lúc vào nền và kết thúc; Release no-op. | Không có fix-accepted/accuracy histogram, byte mạng, CPU, storage, quyền, thermal. `recordPolicyDecision(reason: String)` không phải nhãn danh sách trắng. Timer P2 vẫn được giữ khi app vào nền; T1 không được tạo thêm timer nền. |
| `Core/Device/BatteryMonitor.swift` | Bật `UIDevice.current.isBatteryMonitoringEnabled`, quan sát level, `BatterySnapshot` an toàn luồng; Simulator có thể trả nil. | Chưa quan sát charging state; % là pin **cả máy**, không phải pin FamilyTracker. |
| `Core/Location/CLLocationService.swift`, `AdaptiveLocationPolicy.swift`, `MotionActivityService.swift` | CoreMotion + CoreLocation; stationary dùng significant-change nếu có; walking/running 10 m, filter 20 m; cycling 10 m/30 m; automotive navigation/50 m; Low Power hoặc pin <20% giảm accuracy; `pausesLocationUpdatesAutomatically=true`; loại accuracy <0. | Chưa đếm thời gian theo accuracy mode, accuracy bucket, thay đổi quyền/độ chính xác giảm, wake reason. Không thấy region monitoring; chỉ có standard, significant-change, one-shot. `AppDelegate` phân biệt relaunch do location qua launch option, không biết chính xác mọi wake source. |
| `LocationSendPolicy`, `ShareLocationUseCase`, `LocationDeliveryService`, `LocationBuffer`, `LocationSyncCoordinator`, `OfflineQueue` | Min interval 30/20/15/10 s theo state; heartbeat attempt 30 s; buffer bền vững tối đa 500 điểm/24 h và batch REST; `OfflineQueue` còn dùng cho SOS. | Không có tổng số fix vào/được chọn, tuổi/độ sâu buffer theo bucket, số batch đã nhận và byte batch. Không được đếm heartbeat attempt như emit thành công. |
| `Data/Network/APIClient.swift`, `TokenRefreshCoordinator.swift` | `URLSession.shared.data(for:)` cho REST và refresh, Pulse Debug; retry 401. | Không có `URLSessionTaskMetrics` delegate; refresh là đường riêng; endpoint path chứa ID nên tuyệt đối không dùng URL thật làm nhãn. |
| `Core/Realtime/SocketIOClientAdapter.swift` | Một Socket.IO manager, websocket, handlers/reconnect thủ công, Debug log sự kiện. | Không có byte/wire metric; có thể đếm byte JSON **ước lượng** ngay trước emit và sau decode, không gồm Engine.IO/WebSocket/TLS/compression/ping-pong. |
| `MediaUploadService.swift`, `CachedMediaImage.swift`, `VoicePlaybackController.swift` | PUT R2 dùng `URLSession.shared.upload(for:delegate:)` với delegate tiến độ; ảnh qua `URLCache.shared`/`URLSession.shared`; voice qua AVPlayer. | PUT có delegate nhưng chưa thu task metrics; tải ảnh/voice ngoài APIClient. AVPlayer có thể dùng network stack riêng nên không hứa đo byte voice chính xác. |
| `AppContainer`, `FamilyTrackerApp`, `AppDelegate`, `DebugCoordinator`, Pulse | Có composition root, scenePhase, launch location, Debug Pulse overlay, `DiagnosticRedactor`; Release `NoopNetworkLogger`. | Chưa có MetricKit, signpost, NWPathMonitor, collector hay consent. Redactor không loại ID trong URL path, nên telemetry phải dùng mô hình typed allowlist riêng, không tái sử dụng log/Pulse export. Không tìm thấy Sentry. |
| `FamilyTrackerTests` | Có nhiều file XCTest, gồm test P2. | `xcodebuild -list` chỉ cho thấy target/scheme `FamilyTracker`; **không có test target trong project hiện tại**. Không sửa `project.pbxproj` thủ công. |

Chi phí năng lượng/mạng dự kiến cần đo đúng chỗ: GPS nền + độ chính xác cao, CoreMotion, socket reconnect/heartbeat, vẽ MKMapView/vệt dài, tải ảnh/voice và upload R2. Chưa có baseline thực nghiệm; không xếp hạng thủ phạm theo cảm giác.

## Giới hạn nền tảng và API đã xác minh

- iOS không cung cấp API cho app đọc “FamilyTracker đã dùng X% pin”. `UIDevice.batteryLevel` thô, chịu ảnh hưởng màn hình, sóng, nhiệt, app khác và sạc; chỉ báo **xu hướng pin toàn máy** khi đủ mẫu, không dùng làm chứng cứ riêng lẻ.
- MetricKit iOS 16 dùng `MXMetricManager.shared.add(_:)`/`remove(_:)` và `MXMetricManagerSubscriber.didReceive(_:)`; báo cáo metric thường bao phủ khoảng 24 giờ và có thể đến muộn. Diagnostics (`MXDiagnosticPayload`) có từ iOS 14; `appLaunchDiagnostics` iOS 16. API `MetricManager`/`MetricReport` mới trong tài liệu Apple 2026 dành cho iOS 27+, **không dùng**. Chỉ thử payload trên máy thật; `Debug > Simulate MetricKit Payloads` cho dữ liệu mẫu, không phải số thật của app. [MetricKit](https://developer.apple.com/documentation/metrickit), [MXMetricManager](https://developer.apple.com/documentation/metrickit/mxmetricmanager).
- Đã đối chiếu header của iPhoneOS SDK 26.2: `MXMetricPayload.cpuMetrics.cumulativeCPUTime`; `applicationTimeMetrics.cumulativeForegroundTime`/`cumulativeBackgroundTime`/`cumulativeBackgroundLocationTime`; `locationActivityMetrics.cumulativeBestAccuracyTime`/`cumulativeBestAccuracyForNavigationTime`/`cumulativeNearestTenMetersAccuracyTime`/`cumulativeHundredMetersAccuracyTime`/`cumulativeKilometerAccuracyTime`/`cumulativeThreeKilometersAccuracyTime`; `networkTransferMetrics.cumulativeWifiUpload`/`cumulativeWifiDownload`/`cumulativeCellularUpload`/`cumulativeCellularDownload`; `memoryMetrics.peakMemoryUsage`; `diskIOMetrics.cumulativeLogicalWrites`; `displayMetrics.averagePixelLuminance` (nullable); `cellularConditionMetrics.histogrammedCellularConditionTime`; `applicationResponsivenessMetrics.histogrammedApplicationHangTime`; `animationMetrics.scrollHitchTimeRatio` (iOS 14+). **Không dùng** `animationMetrics.hitchTimeRatio` vì iOS 26+.
- Chỉ đọc các trường typed trên; không lưu `JSONRepresentation`/stack trace của `MXDiagnosticPayload`. Lưu số lượng crash/hang và duration bucket, loại trừ mọi call stack, địa chỉ, metadata tự do. `includesMultipleApplicationVersions=true` thì ghi `mixed_version`, không quy toàn bộ báo cáo cho `latestApplicationVersion`.
- `URLSessionTaskDelegate.urlSession(_:task:didFinishCollecting:)` nhận `URLSessionTaskMetrics`; `transactionMetrics` có byte header/body, `isCellular`, `isExpensive`, `isConstrained`, reused connection. `data(for:delegate:)`/`upload(for:delegate:)` cho phép delegate **theo task**, không cần thay tất cả session. Các byte này không phải hóa đơn 4G: cache, TLS, WebSocket/AVPlayer, retry/redirect và hạ tầng mạng có giới hạn đo khác. [Apple URLSessionTaskMetrics](https://developer.apple.com/documentation/foundation/urlsessiontasktransactionmetrics), [delegate](https://developer.apple.com/documentation/foundation/urlsessiontaskdelegate/urlsession(_:task:didfinishcollecting:)).
- Xcode Organizer chỉ có chỉ số phát hành khi phân phối phù hợp qua TestFlight/App Store, không kỳ vọng từ Personal Team build. [Apple Organizer](https://developer.apple.com/documentation/xcode/analyzing-the-performance-of-your-shipping-app).

## Thiết kế đề xuất

`MobileMetricsRecording` (port typed, Core) nhận **enum cố định + số**, không nhận URL, `Any`, JSON tự do, `userId`, payload socket hoặc tên người. `MobileMetricsCollector` (actor, Core/Monitoring) tổng hợp vào cửa sổ UTC 15 phút theo đồng hồ tiêm được; khi có sự kiện thì đóng/mở cửa sổ, foreground có thể flush nhẹ khi rời màn/lúc vào nền, **không timer nền**. Histogram và nhãn có danh sách trắng/giới hạn số tổ hợp. Store giữ tối đa 24 giờ hoặc 96 cửa sổ và tối đa 256 KiB; ghi atomic chỉ sau khi cửa sổ đóng, loại khỏi iCloud backup, file protection như buffer, xóa khi logout/đổi tài khoản/tắt đồng ý. Lỗi ghi/đọc bị bỏ qua có counter lỗi nội bộ (không log payload), không làm hỏng app. Debug bật mặc định, cục bộ; Release T1-T3 hard-off và không lưu gì cho tới khi có UI consent của T4. Có runtime kill switch.

| Miền | Số đo cục bộ; nguồn | Giới hạn báo cáo |
| --- | --- | --- |
| Pin/năng lượng | Giây foreground/background, charging/unplugged, Low Power, thermal; level đầu/cuối của cửa sổ không sạc và `motion_state` (BatteryMonitor, ProcessInfo, lifecycle). MetricKit CPU, background location, accuracy time, luminance. | Dưới 30 phút hoặc đổi trạng thái sạc/Low Power/nhiệt thì ẩn phép tính pin/giờ; ghi `low_confidence`, không nói “pin app”. MetricKit không tách pin theo `motion_state` của ta. |
| GPS | Fix đến/được chấp nhận/drop, accuracy bucket `<10/10-50/50-100/>100/invalid`, thời gian state và accuracy mode, reconfiguration, emit/heartbeat attempt, quyền Always/WhenInUse/reduced/denied, pause count, buffer depth/age bucket, batch outcome. | Không ghi fix, tọa độ, course, timestamp GPS, địa điểm. Background wake chỉ đếm launch option `.location`; không khẳng định phân biệt region/significant-change nếu OS không cung cấp. |
| REST | `URLSessionTaskMetrics` header+body bytes, request count, latency histogram `<100/<500/<2000/>=2000 ms`, retry/failure bucket theo **EndpointGroup enum** (`auth/groups/chat/history/trail/places/location_batch/other`). | Nhóm từ endpoint typed **trước** khi thành URL; cấm path/query/host. Đếm mỗi network transaction, kiểm soát redirect/retry, không tính cache hit là 4G. |
| Socket | Byte JSON UTF-8 trước emit/sau nhận theo tên `SocketEvent` allowlist, connect/disconnect/reconnect, thời gian `session:ready`. | Giá trị này chỉ là **application payload estimate**, không phải traffic trên dây; không stringify lại payload nhiều lần ở hot path nếu đo cho thấy tốn CPU. |
| Media | PUT ảnh/voice qua cùng task delegate metrics (phối hợp `UploadProgressDelegate`); ảnh qua cache hit/miss và task metrics khi tải; voice AVPlayer báo **không được instrument ở T1**. | Không cộng bytes `data.count` với task metrics của cùng upload; cần trường `coverage` cho tải voice và socket overhead. |
| Hiệu năng | Signpost tĩnh cho launch, restore, fix processing, Journey map, chat list, media send; MetricKit launch, hang histogram/count, scroll hitch ratio, peak memory, disk write. | Không đính ID/URL/tọa độ vào signpost; không lưu raw crash stack. Không watchdog main thread luôn bật. |

`NWPathMonitor` hiện **chưa có**: tạo một monitor chỉ khi collector hoạt động để gắn nhãn wifi/cellular/other/offline cho socket và khoảng thời gian; dừng khi disabled. REST ưu tiên `transaction.isCellular` vì đó là path thực của task. Không lấy SSID. Khi path đổi giữa một transaction, dùng path mà task metrics báo hoặc `unknown`, không suy từ path cuối.

Điểm đánh đổi: tách dữ liệu Debug/Pulse khỏi schema telemetry; Pulse hiện có thể chứa đường URL với ID nên **không dùng Pulse export làm dữ liệu gửi**. Đối chiếu tổng byte app tự đếm với MetricKit theo ngày chỉ có ý nghĩa khi coverage rõ ràng và cùng loại mạng; không ép bằng nhau. T4 muốn “ẩn danh” nhưng endpoint có xác thực vẫn có thể liên kết request với user/IP trên server: đây là quyết định hợp đồng Backend, chưa được phép gọi là vô danh.

## Wireframe ASCII (Debug, không nằm trong Pulse)

```text
Chẩn đoán thiết bị                         [x]
--------------------------------------------
Đang thu trên máy              15 phút gần nhất
Pin toàn máy: 86 -> 84%      Độ tin cậy: thấp
GPS: walking 18m | high accuracy 12m
Fix 42  |  Gửi 17  |  Lọc 3  |  Đệm 2
Mạng: Wi-Fi 1.2 MB | Di động ~0.3 MB
REST 28 | Socket payload ~84 KB | Media 0
MetricKit: Chưa có báo cáo (dữ liệu theo ngày)
                         [Xuất bản tóm tắt]

Khi chờ:   "Chưa đủ dữ liệu trong phiên này"
Khi lỗi:   "Không thể đọc số đo" [Thử lại]
Khi tắt:   "Giám sát đã tắt" [Bật trên máy]
Khi xuất:  [Đang tạo tệp...] -> Share Sheet
```

Release (chỉ T4 nếu được duyệt) dùng một màn Cài đặt riêng, mặc định tắt: `[ ] Chia sẻ số liệu chẩn đoán tổng hợp`, mô tả rõ không có vị trí/danh tính, `[Xóa số liệu trên máy]`. Việc chọn bật phải là hành động chủ động, không preselect. Mọi cỡ chữ lớn hiển thị theo hàng dọc, không dùng màu làm tín hiệu duy nhất.

| Key `L10n.tr` (đề xuất) | vi | en |
| --- | --- | --- |
| `monitor.title` | Chẩn đoán thiết bị | Device diagnostics |
| `monitor.local_only` | Chỉ lưu trên thiết bị | Stored on this device only |
| `monitor.current_window` | 15 phút gần nhất | Last 15 minutes |
| `monitor.battery_whole_device` | Pin toàn máy | Whole-device battery |
| `monitor.low_confidence` | Độ tin cậy thấp | Low confidence |
| `monitor.gps_summary` | Hoạt động GPS | GPS activity |
| `monitor.network_estimate` | Dữ liệu mạng ước tính | Estimated network data |
| `monitor.metric_pending` | Chưa có báo cáo MetricKit | No MetricKit report yet |
| `monitor.empty` | Chưa đủ dữ liệu trong phiên này | Not enough data in this session |
| `monitor.error` | Không thể đọc số đo | Could not read diagnostics |
| `monitor.retry` | Thử lại | Retry |
| `monitor.disabled` | Giám sát đã tắt | Monitoring is off |
| `monitor.enable_local` | Bật trên máy | Enable on this device |
| `monitor.export` | Xuất bản tóm tắt | Export summary |
| `monitor.exporting` | Đang tạo tệp... | Preparing export... |
| `monitor.share_opt_in` | Chia sẻ số liệu chẩn đoán tổng hợp | Share aggregated diagnostics |
| `monitor.share_explanation` | Không gồm vị trí hay danh tính. Có thể tắt và xóa bất cứ lúc nào. | No location or identity data. Turn off and delete at any time. |
| `monitor.delete_local` | Xóa số liệu trên máy | Delete local data |

Key được thêm vào **cả** `vi.lproj` và `en.lproj` cùng commit với UI; cả accessibility label/hint dùng key tương ứng. Đơn vị/giờ định dạng theo `AppLanguage.locale`, không hard-code trong view.

## Chi phí của lớp giám sát (dự toán, KHÔNG phải kết quả)

Đặt ngân sách khởi đầu để kiểm thử: cửa sổ 15 phút, tối đa 96 cửa sổ/256 KiB; không request mạng T1-T3, không sensor/timer nền, 1 `NWPathMonitor` khi đang thu, event update O(1) trên histogram cố định, tránh stringify payload nhiều lần. **Chưa biết** CPU, RAM, disk writes, wakeups và thời gian tăng của một fix: mục tiêu giả thuyết là CPU tăng <1 điểm %, RAM tăng <2 MiB, mỗi fix tăng <1 ms ở p95 và không thêm background wake; chỉ giữ sau khi đo trên máy thật theo tài liệu thí nghiệm.

## Execution Plan (mỗi nhịp <=8 file; chờ duyệt trước khi code)

Mỗi nhịp: build Debug/Release simulator không ký; `scripts/test_networking.sh`, `scripts/test_localization.sh`, SwiftLint, `xcodebuild test` **nếu có test target**, `git diff --check`; báo kết quả thật và đề xuất **một** message commit. **Chờ người dùng báo đã commit** mới qua nhịp sau. Nếu test target vẫn vắng, không sửa `.pbxproj` bằng tay; báo lệnh `xcodebuild test -project FamilyTracker.xcodeproj -scheme FamilyTracker -destination 'platform=iOS Simulator,name=<máy>'` để chạy sau khi tạo target bằng Xcode.

| Nhịp | File dự kiến (tối đa 8; tên cuối cùng theo repo) | Hoàn thành/test |
| --- | --- | --- |
| T1a - lõi thu | mới `Core/Monitoring/MobileMetricsRecording.swift`, `MobileMetricsCollector.swift`, `MobileMetricsStore.swift`, `FamilyTrackerTests/MobileMetricsCollectorTests.swift`; nối nhẹ `AppContainer.swift` | Clock giả, 15 phút, bucket/whitelist, cap/atomic, fail-soft, disabled/no disk Release, xóa theo lifecycle. |
| T1b - năng lượng/GPS | sửa `BatteryMonitor.swift`, `LocationDiagnostics.swift`, `CLLocationService.swift`, `LocationDeliveryService.swift`, `ShareLocationUseCase` (file hiện tại), `AppDelegate.swift`; test mới `MobileEnergyLocationTests.swift` | Giây mode, battery confidence, permission/pause/accuracy, buffer bucket; P2 timer không còn chạy nền; không bật thêm GPS. Cần mở khóa Location. |
| T1c - REST/Socket | mới `Core/Monitoring/NetworkTaskMetricsDelegate.swift`, `NetworkPathObserver.swift`; sửa `APIClient.swift`, `TokenRefreshCoordinator.swift`, `SocketIOClientAdapter.swift`, `AppContainer.swift`; test mới `MobileNetworkMetricsTests.swift` | Task metrics mỗi transaction, socket estimate/connection, route/event whitelist, redirect/retry và mạng đổi, không log URL. Cần mở khóa Realtime. |
| T1d - media/cache | sửa `MediaUploadService.swift`, `CachedMediaImage.swift`, `AppContainer.swift` nếu cần; test mới `MobileMediaMetricsTests.swift` | PUT metrics + tiến độ vẫn đúng, cache hit/miss và download; AVPlayer ghi coverage chưa đo, không bịa số. Cần mở khóa Presentation cho ảnh. |
| T2 - MetricKit | mới `Core/Monitoring/MetricKitReceiver.swift`, `MetricKitSummary.swift`; sửa `AppContainer.swift`; test mới `MetricKitSummaryTests.swift` | Chỉ field iOS 16 typed, nil/mixed-version, crash/hang count, xóa khi logout/tắt; simulated payload chỉ kiểm callback. |
| T3a - signpost | mới `Core/Monitoring/PerformanceSignposts.swift`; sửa tối đa 5 luồng ở `AppContainer`, `LiveMapUseCases`, `JourneyViewModel`, chat list, media service; test/check Instruments | Tên tĩnh, không metadata nhạy cảm, đo không đổi luồng. Cần mở khóa Presentation/Location. |
| T3b - Debug UI | mới `Presentation/Scenes/Debug/MobileMonitoringView.swift`, view model, export document/test; sửa `DebugCoordinator.swift`, `en.lproj`/`vi.lproj` | Không card lồng, Dynamic Type, VoiceOver, empty/error/disabled/export; không để mở Debug ở Release. Cần mở khóa Presentation/i18n. |
| T4 - tùy chọn, chờ BE contract/duyệt riêng | chia T4a consent local + T4b client/transport, mỗi nhịp <=8 file | Mặc định off, foreground+Wi-Fi, report size cap/idempotency, xóa và App Privacy; không làm trước endpoint và quyết định ẩn danh. |
| T5 - đo và chốt | cập nhật 2 study docs, `PROGRESS.md`, mới interview notes | Thực nghiệm **trên máy thật**; chỉ điền số khi đã đo, không coi simulator là pin/network baseline. |

T1a có `AppContainer` nhưng không thay Presentation/Location; T1b/T1c/T1d/T3 chỉ bắt đầu sau xác nhận khóa. Không tự chạy `git commit`. Nếu file thực tế cần sửa vượt 8, dừng và tách nhịp nhỏ hơn.

## Rủi ro, rollback và điều cần quyết định

- Rủi ro: collector làm tăng pin/ghi đĩa; tag cardinality/fingerprinting; race khi logout; payload MetricKit cũ đến sau đổi phiên; `URLSessionTaskMetrics` có nhiều transaction/redirect; estimations của Socket/AVPlayer thiếu overhead; so sánh version bị trộn; consent không tương đương ẩn danh nếu server xác thực/IP log. Tất cả đi qua typed serializer + unit privacy test và gate tắt toàn cục.
- Rollback T1-T3: tắt collector flag, giữ LocationDiagnostics hiện tại, không thay API/Socket behavior. T4: tắt gửi từ server/client, xóa local reports; không ảnh hưởng location/chat/SOS.
- **Cần tôi quyết định:** (1) T1-T3 local trước (đề xuất) hay T4 ngay; (2) Release chỉ sau consent (đề xuất); (3) T4 Wi-Fi only (đề xuất); (4) nhãn thiết bị: chỉ iOS major (đề xuất) hay họ iPhone; (5) không có Sentry hiện tại, MetricKit diagnostics counts thôi (đề xuất); (6) Release thật hay internal-only; (7) ngưỡng pin/data và app tham chiếu sau baseline; (8) BE auth nhưng muốn “ẩn danh”: chọn không gửi, endpoint vô danh có chống lạm dụng, hoặc chấp nhận pseudonymous có công bố minh bạch. **Đề xuất T0: chỉ làm T1-T3 cục bộ trước, T4 hoãn.**
- **Khóa cần xác nhận trước code:** i18n/Presentation/tab Trò chuyện/refactor còn agent hay nhánh đang sửa không? P7D/P7E Location/Realtime đã merge và không còn bị khóa chưa? T0 chỉ sửa docs nên chưa đụng các vùng đó.

Backend tương lai (chưa làm): `POST /api/v1/telemetry/mobile` cần schema/rate limit/idempotency, giới hạn cardinality, retention và hợp đồng quyền riêng tư; không chèn `userId` vào báo cáo. Xác thực vẫn cho BE khả năng liên kết qua request, nên không dùng từ “ẩn danh” cho đến khi giải quyết quyết định trên.
