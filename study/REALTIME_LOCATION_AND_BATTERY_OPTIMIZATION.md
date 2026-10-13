# Định vị thời gian thực giữa hai thiết bị và tối ưu pin

> FamilyTracker iOS + Node.js/Socket.IO backend. Đối chiếu mã nguồn ngày 12/10/2026. Tài liệu phân biệt **đã triển khai** với **đề xuất**; các khoảng thời gian và mức tiết kiệm pin đề xuất chưa được đo hoặc triển khai.

## 1. Kiến trúc end-to-end

Hai iPhone **không kết nối trực tiếp**. Thiết bị A phát `update_location` lên backend; backend xác thực socket, cập nhật cache/lịch sử rồi phát `location_update` vào room `group:<groupId>` cho các socket khác. Thiết bị B nhận sự kiện và cập nhật MapKit. HTTP `GET /history/:userId` phục vụ lịch sử, không phải đường truyền cho từng điểm realtime.

Tên trong yêu cầu và tên **thực tế** trong repo:

| Vai trò | Implementation hiện có |
| --- | --- |
| `LocationTrackerService` | `CLLocationService` + `DeviceLocationRepositoryImpl` + `ShareLocationUseCase` |
| `LocationReceiverService` | `SocketIOClientAdapter` + `SocketRealtimeRepository` + `AsyncBroadcaster` |
| `MapViewModel (@Observable)` | `LiveMapViewModel: ObservableObject`, state bằng `@Published`, chạy trên `@MainActor` |
| Redis GEO cache | `RedisCacheManager.setWithTTL("location:last:<userId>", ..., 300s)` khi Redis được bật; **không có `GEOADD`** |

```mermaid
sequenceDiagram
    autonumber
    participant CM as A: CMMotionActivityManager
    participant GPS as A: CLLocationManager
    participant Track as A: CLLocationService / ShareLocationUseCase
    participant SockA as A: SocketIOClientAdapter
    participant Gate as Backend: Socket Gateway / Location Use Case
    participant Redis as Backend: Redis / Noop Cache
    participant Mongo as Backend: MongoDB
    participant Room as Backend: Socket.IO group room
    participant SockB as B: SocketIOClientAdapter
    participant Receive as B: SocketRealtimeRepository
    participant VM as B: LiveMapViewModel
    participant Map as B: SwiftUI Map / MapKit

    SockA->>Gate: connect(auth.token)
    SockB->>Gate: connect(auth.token)
    Gate->>Room: join group:<groupId> for each socket
    Gate-->>SockB: session:ready
    CM-->>Track: stationary / walking / running / cycling / automotive
    Track->>GPS: set desiredAccuracy, distanceFilter, activityType
    alt Stationary and supported
        Track->>GPS: startMonitoringSignificantLocationChanges()
    else Other motion state
        Track->>GPS: startUpdatingLocation()
    end
    GPS-->>Track: didUpdateLocations(CLLocation)
    Track->>Track: GeoPoint; 50 m OR 30 s; heartbeat 30 s
    Track->>SockA: sendLocation(latitude, longitude, batteryLevel)
    alt Socket connected
        SockA->>Gate: emit update_location
    else Socket disconnected
        SockA->>SockA: OfflineQueue coalesces latest location
    end
    Gate->>Gate: Zod validation + trackDuration
    opt Redis enabled and healthy
        Gate->>Redis: SET location:last:<userId> EX 300
    end
    opt History threshold: >=50 m OR >=30 s
        Gate->>Mongo: update User.lastKnownLocation + insert LocationHistory
    end
    Gate->>Room: emit location_update except sender socket
    Room-->>SockB: location_update
    SockB->>Receive: decode LocationUpdateDTO; AsyncStream
    Receive->>VM: upsert member by userId on MainActor
    VM->>Map: publish memberLocations; update annotations
```

Room được tham gia sau bước xác thực và truy vấn danh sách Circle. Backend phát `session:ready` khi join xong. Một sự kiện gửi có thể tới nhiều Circle của cùng người dùng; socket phát sự kiện **một lần**, backend fan-out theo room. `SocketRealtimeRepository` giữ điểm mới nhất trong offline queue (coalesce key `location`) và flush khi reconnect/`session:ready`; chưa có ack cho `update_location`, nên “đã emit” không phải bằng chứng người nhận đã thấy.

**Đường mã nguồn:** iOS `FamilyTracker/Core/Location/{MotionActivityService,AdaptiveLocationPolicy,CLLocationService}.swift`, `FamilyTracker/Domain/UseCases/LiveMap/LiveMapUseCases.swift`, `FamilyTracker/Data/Repositories/{DeviceRepositories,SocketRealtimeRepository}.swift`, `FamilyTracker/Core/Realtime/SocketIOClientAdapter.swift`. Backend nằm ở checkout anh em `../Backend/src/{presentation/socket,application/location,infrastructure/cache,infrastructure/realtime}` tính từ gốc repo Mobile.

## 2. Thuật toán pin và tần suất gửi: hiện trạng

### 2.1. Máy trạng thái thích ứng theo chuyển động

`MotionActivityService` dùng `CMMotionActivityManager.startActivityUpdates(to: .main)`, bỏ kết quả `confidence == .low`, ưu tiên `automotive`, `cycling`, `running`, `walking`, `stationary`; khi không rõ hoặc Motion không khả dụng dùng `.unknown`. Đây là phép ánh xạ trạng thái theo callback, **chưa phải một FSM có hysteresis, dwell time hay xác nhận chuyển trạng thái**. `CLLocationService` chỉ áp lại cấu hình nếu trạng thái/pin làm `LocationSettings` đổi.

| Trạng thái hiện có | `desiredAccuracy` | `distanceFilter` | Nguồn cập nhật GPS | Quy tắc gửi Socket |
| --- | --- | ---: | --- | --- |
| Stationary | `HundredMeters` | 100 m | Significant-change nếu thiết bị hỗ trợ; ngược lại standard | Heartbeat dùng tọa độ gần nhất khoảng **30 s/lần khi task chạy**; thay đổi đáng kể cũng có thể gửi sớm |
| Walking / Running | `NearestTenMeters` | 20 m | Standard | >=50 m từ lần gửi **hoặc** >=30 s khi nhận callback |
| Cycling | `NearestTenMeters` | 30 m | Standard | Cùng quy tắc 50 m **hoặc** 30 s |
| Automotive | `BestForNavigation` | 50 m | Standard | Cùng quy tắc; 50 m ở tốc độ cao có thể tới trước 30 s |
| Unknown / mới khởi động | `NearestTenMeters` | 25 m | Standard | Cùng quy tắc |

Khi Low Power Mode bật **hoặc** pin <20%, `AdaptiveLocationPolicy.degrade` hạ một bậc độ chính xác và **nhân đôi** `distanceFilter` (tương ứng 200/40/60/100/50 m). Nó **không** tự chuyển mọi trạng thái sang significant-change. Stationary vẫn significant-change; automotive vẫn standard, chỉ hạ từ `BestForNavigation` xuống `NearestTenMeters`. `BatteryMonitor` đọc mức pin thật từ `UIDevice`; Simulator có thể trả `nil`.

Sau CoreLocation là bộ lọc gửi độc lập trong `ShareLocationUseCase`:

```swift
// LiveMapUseCases.swift, rút gọn đúng điều kiện hiện tại.
if let last = lastSent,
   point.distance(to: last.point) < minDistance,      // mặc định 50 m
   now.timeIntervalSince(last.date) < minInterval {   // mặc định 30 s
    return
}
lastSent = (point, now)
liveLocation.sendLocation(point, batteryLevel: deviceStatus.batteryLevel)
```

Vì cả hai điều kiện nhỏ hơn ngưỡng phải **đồng thời** đúng mới bỏ điểm, phép gửi thực tế là `d >= 50 m OR elapsed >= 30 s`. Điểm đầu tiên gửi ngay. Heartbeat thử `handle(lastKnownLocation)` mỗi 30 s, vì vậy máy đứng yên **không** có nhịp 5–15 phút như mục tiêu đề bài. Heartbeat gửi lại tọa độ cũ, không ép CoreLocation đo GPS mới. `lastSent` ghi nhận lần **thử gửi**, không phải ack từ server. Từ P3, sleeper ném `CancellationError` khi `stop()` hủy task và vòng lặp kiểm tra cancellation cả trước lẫn sau sleep, nên heartbeat cũ không thể emit sau stop/logout.

Ví dụ định lượng, chỉ là ước lượng khi có GPS callback đều: tại 5 km/h, 50 m mất khoảng 36 s nên nhịp 30 s có thể chi phối; tại 60 km/h, 50 m mất khoảng 3 s nên app có thể emit nhiều hơn 1 lần/30 s. `distanceFilter` là ngưỡng yêu cầu hệ điều hành, **không phải lịch hẹn chính xác**; nhiễu, chất lượng tín hiệu, pause/background làm khoảng cách thực tế khác đi.

### 2.2. Các lớp tiết kiệm năng lượng đang có

1. CoreMotion đổi độ chính xác và ngưỡng nhận điểm theo trạng thái; đứng yên dừng standard GPS để dùng significant-change khi khả dụng.
2. `pausesLocationUpdatesAutomatically = true`; `activityType` là `.fitness`, `.automotiveNavigation` hoặc `.other` tùy trạng thái. `Info.plist` có `NSMotionUsageDescription`, quyền vị trí Always/When In Use và background mode `location`.
3. Low Power Mode/pin thấp giảm độ chính xác và tăng `distanceFilter`, nhưng **ngưỡng emit 50 m/30 s không đổi**.
4. Khi offline, hàng đợi chỉ giữ tọa độ mới nhất; cấu hình tổng quát tối đa 200 item, tối đa 24 h, nhưng các item có key `location` thay thế nhau.

`CLLocationService` hiện chỉ loại `horizontalAccuracy < 0`. Nó **chưa** bỏ điểm có sai số >50 m, timestamp cũ >10 s, tốc độ bất thường hoặc vị trí nhảy xa; `DeviceLocationRepositoryImpl` còn chuyển `CLLocation` sang `GeoPoint(latitude, longitude)`, nên mất `speed`, `horizontalAccuracy`, `timestamp` trước khi vào use case.

### 2.3. Các ngưỡng trong yêu cầu là **đề xuất**, chưa triển khai

| Mode mục tiêu | Ngưỡng yêu cầu | Trạng thái repo và đánh đổi |
| --- | --- | --- |
| Đứng yên | `HundredMeters`, 50–100 m, ping 5–15 phút hoặc geofence exit | Hiện là 100 m + significant-change nhưng **socket heartbeat 30 s**. Muốn 5–15 phút phải đổi heartbeat theo mode và xử lý stale/presence ở backend. |
| Đi bộ/chạy | `NearestTenMeters`, 15–20 m, gửi 15–30 s | Hiện 20 m, gửi 50 m **hoặc** 30 s. Gửi 15 s có thể tăng radio wakeups. |
| Ô tô | `BestForNavigation`, 5–10 m, gửi 3–5 s | Hiện 50 m, không có interval 3–5 s. 5–10 m rất tốn pin và dễ theo nhiễu GPS; chỉ cân nhắc trong phiên điều hướng foreground có nhu cầu rõ ràng, không mặc định 24/7. |

**Speed-based throttling đề xuất:** `speed < 1 m/s -> 60–300 s`; `1 <= speed < 5 m/s -> 15–20 s`; `speed >= 5 m/s -> 3–5 s`. Đây **không phải logic hiện có**. Cần truyền đầy đủ `CLLocation.speed` (giá trị âm nghĩa là không hợp lệ), accuracy và timestamp qua tầng dữ liệu. Áp dụng hysteresis/minimum dwell time để tránh chuyển mode liên tục khi tốc độ dao động quanh 1 hoặc 5 m/s. Nên tách `minSendInterval` (chặn trần số emit), `distanceThreshold` và `maxHeartbeatAge` thay vì dùng OR như hiện tại; vẫn phải có ngoại lệ cho SOS hoặc geofence.

**Noise filter đề xuất:** bỏ `horizontalAccuracy < 0`, điểm quá cũ (>10 s khi đang di chuyển) và điểm quá kém chính xác. Mốc **>50 m** chỉ hợp lý cho mode yêu cầu tracking chính xác; áp dụng toàn cục sẽ loại chính các điểm stationary/coarse mà mode `HundredMeters` cần. Với significant-change/background resume, dùng ngưỡng sai số/tuổi điểm theo mode, không áp một con số cứng. Có thể so tốc độ suy ra giữa hai điểm để chặn teleport nhưng phải xét sai số cả hai điểm.

**Low-power fallback đề xuất:** có thể chuyển sang significant-change khi pin <20% **nếu** chấp nhận giảm độ tươi vị trí. Repo hiện chưa làm điều đó ở mọi mode. Không được tuyên bố “tiết kiệm 90% pin” khi chưa đo bằng thiết bị thật, Energy Log/MetricKit và cùng lộ trình thử nghiệm.

**Background không phải timer chính xác:** `UIBackgroundModes=location` và `allowsBackgroundLocationUpdates=true` cho phép nhận cập nhật theo chính sách iOS; `Task.sleep(30s)` không bảo đảm chạy đều khi app bị suspend. `AppDelegate` có nhánh khôi phục chia sẻ khi được đánh thức bởi location event. Khi chỉ có quyền When In Use, bị từ chối, Reduced Accuracy, hoặc bị force-quit, trải nghiệm/độ chính xác có thể khác đáng kể; cần test trên máy thật.

## 3. Backend: cache, lịch sử và fan-out

`locationGateway.js` xác thực socket ở `socketServer.js`, kiểm tra payload bằng Zod (`latitude`, `longitude`, `batteryLevel?`), rồi gọi `location.updateLocation`. User ID lấy từ JWT/socket session, **không tin userId do client gửi**. Server tính `durationAtLocation` bằng vùng bán kính 50 m trong `durationTracker` in-memory và phát stay alerts ở 30, 60, 120, 240, 480, 1440 phút.

Thứ tự thực tế trong `locationUseCases.js`:

1. Tính stay duration và `SET location:last:<userId>` TTL mặc định **300 s** nếu `REDIS_ENABLED=true` và `REDIS_URL` có mặt. Redis adapter là key/value JSON (`SET EX`), **không phải Redis GEO/GEOADD**; nếu Redis tắt/lỗi, `NoopCacheManager` hoặc fallback không chặn luồng tiếp.
2. Nếu điểm đầu tiên **hoặc** đã >=30 s **hoặc** cách điểm lưu trước >=50 m: cập nhật `User.lastKnownLocation` và tạo một document `LocationHistory` trong MongoDB. Đi xe nhanh vượt 50 m liên tục có thể tạo nhiều write cách nhau **ít hơn 30 s**. Không đúng khi nói backend chỉ ghi Redis và không ghi MongoDB theo luồng realtime.
3. Lấy các Circle của user rồi phát `location_update` vào từng `group:<id>`, trừ socket gửi. Redis write/Mongo write/group lookup đều được `await` **trước** broadcast; độ trễ lưu trữ có thể tăng latency người nhận. Không có Socket.IO Redis adapter để fan-out room qua nhiều Node instance trong source hiện tại.

`lastSavedLocation` và `durationTracker` là `Map` trong RAM của **một** Node process; restart/reset hoặc nhiều instance làm bộ đếm lịch sử/stay không đồng nhất cho tới khi có cơ chế state chia sẻ.

Ví dụ code backend (rút gọn đúng thứ tự):

```js
await cacheManager.setWithTTL(lastLocationKey(userId), {
  userId, name: userName, latitude, longitude,
  batteryLevel: batteryLevel ?? fallbackBatteryLevel,
  durationMinutes, recordedAt: at.toISOString(),
}, locationCacheTtlSeconds);
if (shouldSaveHistory(userId, latitude, longitude, now)) {
  await userRepo.updateLastKnownLocation(userId, { latitude, longitude, batteryLevel, durationMinutes, at });
  await locationHistoryRepo.create({ userId, latitude, longitude, at });
}
for (const group of await groupRepo.listSummariesByMember(userId)) {
  realtime.emitToGroup(group._id, 'location_update', payload, { exceptSocketId: socketId });
}
```

Đoạn trên là **snippet rút gọn** từ `../Backend/src/application/location/locationUseCases.js`. Muốn chỉ ghi Redis ở hot path rồi ghi Mongo theo batch cần thay đổi durability, crash recovery, quyền xem history và kiểm thử mất dữ liệu; đó là đề xuất khác, chưa được hiện thực.

## 4. Thiết bị B: nhận và vẽ bản đồ

`SocketIOClientAdapter` nhận `location_update`, `SocketRealtimeRepository` giải mã `LocationUpdateDTO` và phát `AsyncStream<MemberLocation>`. `LiveMapViewModel` chạy trên `@MainActor`, thay hoặc thêm phần tử theo `userId`; SwiftUI `Map` dùng `annotationItems: viewModel.memberLocations` và `MapAnnotation` cho từng member. Đây là **upsert theo ID**, không tái tạo toàn bộ màn hình điều hướng; tuy nhiên `@Published` vẫn phát thay đổi mảng, và code chưa chứng minh chỉ một pin được vẽ lại ở cấp MapKit nội bộ.

```swift
// LiveMapViewModel.swift, logic thực tế.
if let index = memberLocations.firstIndex(where: { $0.id == location.id }) {
    memberLocations[index] = location
} else {
    memberLocations.append(location)
}
```

**Chưa triển khai:** `@Observable` property-level tracking, `MKAnnotation` mutable coordinate qua `UIViewRepresentable`, nội suy tọa độ, anti-teleport, kiểm tra timestamp để bỏ sự kiện đến sai thứ tự, REST bootstrap map sau cold start. Map hiện gán tọa độ mới khi event tới; `withAnimation` đang dùng khi người dùng chọn member, **không** phải animation cho từng `location_update`. Trạng thái pin ở `MemberLocation` được nhận nhưng thiếu stale/offline annotation policy riêng.

**Hướng mở rộng nội suy (không phải code hiện tại):** giữ `from`, `to`, `t0`, `t1` cho từng user; trên display tick tính `p = clamp((now-t0)/(t1-t0), 0...1)` và `coordinate = from + p*(to-from)`; giới hạn animation horizon, hủy interpolation nếu event quá cũ/nhảy xa, không dự đoán vô hạn khi mất mạng. Với MapKit cần đo FPS/CPU và cân nhắc annotation UIKit mutable thay vì ép SwiftUI cập nhật toàn bộ danh sách mỗi frame.

## 5. Kiểm chứng trên hai thiết bị

| Cần đo | Cách kiểm tra | Điều kiện đạt mong muốn |
| --- | --- | --- |
| Nhịp gửi | Debug Pulse trên A, lọc `→ update_location`, so timestamp | Nhìn được nhịp thật theo mode; payload tọa độ đã redact |
| Nhịp nhận | Pulse trên B, lọc `location_update` | Event vào đúng Circle; không nhầm với HTTP history |
| Độ trễ | Ghi timestamp gửi/nhận bằng telemetry an toàn, đồng bộ đồng hồ hoặc dùng server timestamp | p50/p95, không suy từ một ảnh chụp màn hình |
| Pin | Xcode Energy Log / Instruments, cùng thiết bị/lộ trình/mạng trong foreground và background | So sánh baseline với từng thay đổi; chưa có số liệu hiện tại |
| Background | Quyền Always/When In Use, Low Power Mode, màn khóa, tắt mạng, reconnect | Không giả định heartbeat chính xác 30 s khi suspend |
| Backend write | Đếm `LocationHistory` và Redis operations theo user/phút | Phát hiện write dồn dập khi ô tô vượt 50 m liên tục |

Không ghi tọa độ thô vào log chia sẻ: `DiagnosticRedactor` che `latitude`, `longitude`, token và dữ liệu cá nhân. Unit/integration test backend hiện có xác nhận `update_location` được phát thành `location_update` và lưu một điểm lịch sử (`../Backend/tests/api.test.js`). Chưa có benchmark pin, benchmark độ trễ hai máy hoặc test nội suy.

## 6. Trả lời phỏng vấn theo STAR

**Câu hỏi:** “Bạn thiết kế định vị liên tục thế nào để cân bằng realtime với pin iPhone?”

| STAR | Câu trả lời bám mã nguồn |
| --- | --- |
| **S - Situation** | “FamilyTracker cần cho người thân thấy vị trí qua Socket.IO, nhưng GPS chính xác liên tục và network heartbeat quá dày có thể tốn pin.” |
| **T - Task** | “Tôi cần giảm việc đánh thức định vị khi đứng yên, vẫn gửi điểm đủ mới lúc di chuyển và không mất trạng thái cuối khi Socket ngắt.” |
| **A - Action** | “Tôi kết hợp `CMMotionActivityManager` với `CLLocationManager`: stationary chuyển sang significant-change, walking/cycling/automotive chọn accuracy và `distanceFilter` khác nhau; Low Power Mode/pin <20% hạ accuracy và nhân đôi filter. Use case chỉ emit khi cách điểm gửi trước >=50 m hoặc >=30 s; offline queue coalesce tọa độ cuối. Backend cache last location tùy cấu hình Redis, ghi Mongo theo 50 m/30 s và broadcast theo Circle room.” |
| **R - Result** | “Luồng realtime và chính sách thích ứng đã có trong code/test tích hợp Socket; **tôi chưa có số đo phần trăm tiết kiệm pin hoặc p95 latency trên hai máy**, nên không khẳng định 90%. Bước tiếp là đo Energy Log và số emit/write theo mode, rồi giảm heartbeat stationary và cân nhắc interpolation theo dữ liệu đo.” |

**Câu hỏi phản biện nên chuẩn bị:** “Nếu xe chạy nhanh, OR 50 m/30 s có thật sự throttle không?” Trả lời: “Không tạo giới hạn thời gian tối thiểu; xe nhanh có thể emit và ghi Mongo rất dày. Tôi sẽ bổ sung `minSendInterval` theo mode, tách heartbeat khỏi movement updates, kiểm tra accuracy/timestamp, và đo độ trễ/pin trước khi chọn ngưỡng.” Câu trả lời này trung thực hơn việc nhận đã triển khai 3–5 s hoặc tiết kiệm 90%.

## Nguồn và giới hạn xác minh

- Apple: [CLLocationManager, distanceFilter và significant-change](https://developer.apple.com/documentation/corelocation/cllocationmanager), [CMMotionActivityManager](https://developer.apple.com/documentation/coremotion/cmmotionactivitymanager), [pausesLocationUpdatesAutomatically](https://developer.apple.com/documentation/corelocation/cllocationmanager/pauseslocationupdatesautomatically), [background location](https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background).
- iOS: [AdaptiveLocationPolicy.swift](../FamilyTracker/Core/Location/AdaptiveLocationPolicy.swift), [CLLocationService.swift](../FamilyTracker/Core/Location/CLLocationService.swift), [LiveMapUseCases.swift](../FamilyTracker/Domain/UseCases/LiveMap/LiveMapUseCases.swift), [SocketRealtimeRepository.swift](../FamilyTracker/Data/Repositories/SocketRealtimeRepository.swift), [LiveMapViewModel.swift](../FamilyTracker/Presentation/Scenes/LiveMap/Map/LiveMapViewModel.swift).
- Backend sibling checkout: `src/presentation/socket/{socketServer.js,gateways/locationGateway.js}`, `src/application/location/locationUseCases.js`, `src/infrastructure/{cache/RedisCacheManager.js,realtime/socketRealtime.js}`, `src/config/env.js`, `tests/api.test.js`.
- Chưa kiểm tra cấu hình môi trường **đang deploy** trên Render/Redis, nên “Redis được bật” là điều kiện, không phải khẳng định production hiện sử dụng Redis. Không có phép đo battery/latency thực địa trong repo.
