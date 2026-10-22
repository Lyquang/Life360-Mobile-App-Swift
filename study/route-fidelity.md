# F0: Độ trung thực của lộ trình trên Journey

> Chỉ chẩn đoán và thiết kế. Chưa có payload sản xuất đã che thông tin, số đo Instruments hoặc ảnh gốc riêng; không kết luận nguyên nhân của **chuyến đi cụ thể** từ mô tả ảnh. Không ghi tọa độ, tên, địa chỉ thật vào tài liệu hoặc log. **Quyết định mới nhất ở mục "Quyết định bám đường bộ" cuối file thay thế mọi đề xuất A/B/C hoặc fallback đường thẳng trước đó.**

## Kết luận dựa trên mã nguồn

| Giả thuyết | Kết luận | Bằng chứng |
| --- | --- | --- |
| Backend không trả `path` | **Không đúng với backend trong workspace**: moving segment có `path` của mọi điểm **đã lưu**. Chưa biết bản deploy có giống mã này không. | `../Backend/src/domain/journey.js:70-85`, `../Backend/src/application/history/historyUseCases.js:37-41` |
| `path` quá thưa | **Có thể**, chưa có số đo. iOS điều tiết emit; backend lưu khi cách lần lưu trước >=30 giây **hoặc** di chuyển >=50 m. | `FamilyTracker/Domain/Policies/LocationSendPolicy.swift:39-50`, `../Backend/src/application/location/locationUseCases.js:4-5,44-49,107-110` |
| Mapper tự nối `from/to` | **Không**. `from/to` chỉ làm mốc. Không có >=2 điểm `path`/`points` thì không có polyline. | `FamilyTracker/Data/Network/Mappers/CoreMappers.swift:134-149`, `FamilyTracker/Domain/Entities/RouteOverlayModel.swift:47-53` |
| Lớp vẽ/làm thưa | Douglas-Peucker dung sai 8 m có thể giữ lại đúng hai đầu nếu các điểm gần thẳng hàng; hai điểm cũng chỉ cho một đoạn thẳng. Chưa biết mức đóng góp của bước này trong ảnh. | `FamilyTracker/Presentation/Scenes/Timeline/Journey/JourneyViewModel.swift:93-105`, `FamilyTracker/Domain/Policies/PolylineSimplifier.swift:16-63`, `FamilyTracker/Presentation/Scenes/Timeline/Journey/RouteMapRenderer.swift:86-96` |

Một moving segment kéo dài 3 giờ 41 phút với 0 stay points có thể xuất hiện khi thuật toán không tìm được run >=5 phút trong bán kính 80 m; nó **không chứng minh** thiết bị đã gửi nhiều hay ít điểm. `../Backend/src/domain/journey.js:3-4,18-67,88-91`.

### Dòng dữ liệu và các nhánh quan trọng

`GET /history/{userId}/journey` -> DTO -> `compactMap` -> `MovingSegment.path: [GeoPoint]` -> lọc điểm không hợp lệ/trùng liền kề -> đơn giản hóa 8 m -> `MKPolyline`.

- DTO nhận `path` (chỉ lat/lon) hoặc `points` (lat/lon, `timestamp?`); `HistoryPointDTO` cho endpoint today có timestamp bắt buộc. Mapper **bỏ timestamp** khi đổi `points` thành `GeoPoint`; Domain không còn timestamp/accuracy từng điểm. `HistoryDTOs.swift:11-16,39-67`, `CoreMappers.swift:136-138`, `Journey.swift:20-35`.
- `path`/`points` rỗng nhưng có `from/to/start/end`: segment vẫn trong timeline với `path=[]`; bản đồ hiển thị `journey.map.empty.geometry`, **không** vẽ đường. Một điểm cũng không đủ polyline; đúng hai điểm tạo đoạn thẳng, chưa thể biết khoảng trống giữa chúng. `JourneyView.swift:45-61`, `RouteOverlayModel.swift:47-53`.
- Thiếu start/end, thiếu cả from/to lẫn tọa độ đường, hoặc type lạ: mapper trả `nil`, `compactMap` bỏ entry **không báo lỗi**; summary có thể vẫn báo tổng thời gian. `CoreMappers.swift:71-74,126-152`.
- Backend có `timestamp` và `accuracy` trong Mongo nhưng `path` Journey hiện chỉ chứa lat/lon. Vì vậy **không thể phân tích khoảng trống theo thời gian từ Journey hiện tại**; cần hợp đồng mới hoặc raw history. `../Backend/src/infrastructure/database/models/LocationHistory.js:33-45`, `../Backend/src/domain/journey.js:84`.
- `GET /history/:userId` hiện chỉ lấy **hôm nay**, trả toàn bộ mảng, không hỗ trợ `from/to/limit/cursor`; `/journey` có `date`. Quyền xem: bản thân hoặc cùng Circle, ngoài ra 403. `../Backend/src/presentation/http/routes/historyRoutes.js:23,43`, `../Backend/src/presentation/dto/history.schemas.js:4-12`, `../Backend/src/application/history/historyUseCases.js:15-41`.
- Backend tính ngày theo timezone **máy chủ** (`localDayRange` cộng cố định 24 giờ); iOS dùng lịch/locale thiết bị. Chưa xác nhận timezone production, và ngày DST có thể sai. `../Backend/src/domain/dates.js:3-15`, `FamilyTracker/Domain/UseCases/Timeline/TimelineUseCases.swift:14-23`.
- Không thấy TTL index cho Mongo `LocationHistory`; Redis last-location TTL mặc định 300 giây là cache, **không phải** retention lịch sử. Chưa có bằng chứng chính sách xóa lịch sử production. `../Backend/src/infrastructure/database/models/LocationHistory.js:52-60`, `../Backend/src/application/location/locationUseCases.js:20`.
- Backend chấp nhận `recordedAt`, `accuracy` tùy chọn và broadcast lại khi có; iOS `update_location` hiện **chỉ gửi** lat/lon/battery. Backend dùng server time nếu thiếu `recordedAt`; accuracy không có. Đây là lệch hợp đồng đã kiểm chứng với mô tả “đã có sau P5”. Socket không ack, nên emit không chứng minh đã lưu. `../Backend/src/presentation/dto/location.schemas.js:10-16`, `../Backend/src/application/location/locationUseCases.js:27-42,113-129`, `FamilyTracker/Data/Repositories/SocketRealtimeRepository.swift:64-70`, `../Backend/src/presentation/socket/gateways/locationGateway.js:7-24`.
- Offline buffer chỉ nhận điểm đã qua send policy khi socket chưa sẵn sàng; tối đa 500, làm thưa về 400, TTL 24 giờ. Batch đi thẳng vào Mongo, không phát lại như realtime. Điểm emit ngay trước lúc mất kết nối vẫn có thể mất vì không ack. `LocationBuffer.swift:22-27,68-79`, `LocationDeliveryService.swift:67-89`, `../Backend/src/application/location/syncLocationBatchUseCase.js:29-41`.

### Mật độ điểm: trần lý thuyết, **không phải số đo**

| Motion | Min interval iOS | Trần do interval nếu liên tục có fix hợp lệ | Tại 10 m/s | Ghi lịch sử backend |
| --- | ---: | ---: | ---: | --- |
| Walking/running | 20 s | 180 lần/giờ | ~200 m/điểm | Có thể, vì >=50 m |
| Cycling | 15 s | 240 lần/giờ | ~150 m/điểm | Có thể, vì >=50 m |
| Automotive | 10 s | 360 lần/giờ | ~100 m/điểm | Có thể, vì >=50 m |
| Stationary | 30 s | ~120 heartbeat/giờ nếu app tiếp tục chạy | Không áp dụng | Có thể lưu lặp tọa độ cũ mỗi 30 giây |

Đây là trần **cho một state ổn định**: điểm đầu/đổi motion có thể gửi ngay, còn callback GPS, quyền nền, mất mạng, sai số và backend có thể hạ mật độ. `LocationSendPolicy.swift:98-137` dùng ngưỡng động `clamp(speed * targetInterval, minDistance, maxDistance)`; `AdaptiveLocationPolicy.swift:15-55` đặt distanceFilter 20 m đi bộ, 50 m lái xe và tăng gấp đôi khi pin yếu; stationary dùng significant-change (`CLLocationService.swift:132-142`). **Ngoại lệ quan trọng:** heartbeat 30 giây vẫn đưa `lastKnownFix` cũ vào policy (`LiveMapUseCases.swift:123-138`), nên significant-change không đồng nghĩa với không emit/lưu điểm lặp. Chuyến 3 giờ 41 phút ở state automotive có trần giản lược khoảng 1.326 lần emit (không tính ranh giới/đổi state), **không được suy ra** 1.326 điểm đã lưu.

### Thu thập bằng chứng thật mà không lộ dữ liệu

1. Dùng Pulse lấy response Journey và raw history của **cùng ngày**, nhưng **không** đưa raw log vào repo/LLM. Tạo bộ thống kê chạy cục bộ chỉ xuất: HTTP status, `summary.totalPoints`, số stay/moving, `path.length`/`points.length` từng segment, số điểm trước/sau lọc và DP, p50/p90 khoảng thời gian (giây) và quãng cách (mét) liền kề, số gap theo ngưỡng. Bỏ ID, thời điểm cụ thể, token, tên, địa chỉ, tọa độ. Nếu chỉ có `path` cũ, p50/p90 **thời gian** phải ghi “không tính được”.
2. Fixture test phải là dữ liệu **tổng hợp**, không phải payload thật chỉ xóa tên: đường đi thật có thể nhận dạng nơi ở.
3. Đối chiếu `sum(path.length)` với `summary.totalPoints` (stay points không thuộc moving path), raw history count và số sau DP. Chưa có bảng số này, nên chưa quy kết được lỗi là backend, mật độ, hay phép đơn giản hóa.

## Thiết kế đề xuất sau F0

- **F1:** `RoutePoint` giữ lat/lon/`recordedAt`/`accuracy?` trong Domain, không import MapKit. Mapper trung thực, không dựng đường từ from/to, không bỏ entry im lặng; phân biệt “thiếu geometry”. Hỗ trợ schema `path` cũ và `points` mới **chỉ khi fixture xác nhận**. Không gán timestamp giả cho `path` cũ; nếu BE chưa hỗ trợ thì F1 chỉ có thể làm phần kiểm chứng được.
- **F2:** `RouteGapAnalyzer` thuần chia observed runs và estimated links. Giả thuyết ban đầu **cần đo**: gap nếu `deltaTime > 90 s` hoặc `deltaDistance > max(250 m, 3 * expectedSpeed * deltaTime)`; nhảy với tốc độ vô lý là invalid, không nối. Không đơn giản hóa xuyên qua gap; thiếu timestamp thì “chưa rõ”, không nhận là observed.
- **F3:** đoạn quan sát nét liền có viền; nối ước tính nét đứt, chú thích và VoiceOver rõ. Một điểm chỉ là marker. Giữ diff overlay, xử lý geometry ngoài main actor, không thay LiveMap.
- **F4:** cổng quyết định sau số đo p50/p90 và chuyến đi thực: A nối điểm thật; B backend map-match/cache geometry; C `MKDirections` chỉ cho gap nhỏ được chọn, **luôn** đánh dấu ước tính. B cần hạ tầng/chi phí và kiểm tra điều khoản hiện hành khi hiển thị trên Apple Maps; C gửi tọa độ cho Apple, phụ thuộc mạng/throttle và có thể gợi ý sai đường đã đi. Không tự làm B/C.
- **F5 tùy chọn:** chỉ hôm nay, nối tạm điểm socket có `recordedAt/accuracy` đáng tin cậy, dedupe/coalesce <=1 lần/giây, dừng khi đổi ngày/người/rời màn; đối soát lại từ server vì socket point chưa chắc đã được lưu.
- **F6:** đo FPS/bộ nhớ và chuyến đi thật, cập nhật tài liệu/tiến độ. Không sửa backend trong task iOS.

### Wireframe ASCII các trạng thái

```text
DATA:      [Thành viên v] [Ngày v]       [Căn lại]
           | Map: A --observed-- B ... C -- D  |
           | Bảng kéo: [Đoạn 1] [Gap] [Đoạn 2] |
           | Nét đứt: chưa có GPS giữa hai điểm|
LOADING:   [Map] Đang tải hành trình...
EMPTY:     [Map] Chưa có hành trình ngày này
NO PATH:   [Map: mốc nếu có] Chưa đủ điểm để vẽ
ONE POINT: [Map: một mốc] Chưa đủ điểm để vẽ
GAP ONLY:  [A] - - - - - [B] (ước tính, không phải đường đã đi)
ERROR:     Không tải được lộ trình [Thử lại]
FORBIDDEN: Không thể xem lịch sử [Đóng]
SHARING OFF: backend chưa phân biệt; chưa thể hiển thị riêng
```

### Key L10n vi/en đề xuất cho F3

| Key | vi | en |
| --- | --- | --- |
| `journey.map.gap.legend` | Nét đứt: chưa có dữ liệu GPS giữa hai điểm. | Dashed line: GPS data is missing between these points. |
| `journey.map.gap.accessibility` | Khoảng trống dữ liệu giữa hai điểm; đường nối chỉ là ước tính. | GPS data gap between two points; connector is only an estimate. |
| `journey.map.geometry.unknown` | Không đủ dữ liệu để xác nhận đường đã đi. | Not enough data to verify the traveled path. |
| `journey.map.sharing.off` | Thành viên đã tắt chia sẻ vị trí. | This member has turned off location sharing. |

Các key `journey.map.empty.geometry`, `journey.map.empty.day`, `journey.map.error.*`, `journey.loading` đã tồn tại trong cả vi/en. F0 **không** thêm key.

## Execution Plan: chờ `approved F0`

| Giai đoạn | File dự kiến (khoảng <=8) | Tiêu chí hoàn thành / test |
| --- | --- | --- |
| F1a: cổng backend | BE owner xử lý [hợp đồng](../api-docs/ROUTE_GEOMETRY_REQUEST.md), không phải commit iOS | Có fixture đã che, timestamps/accuracy từng điểm, raw history phân trang; nếu chưa có chỉ làm mapper có thể chứng minh |
| F1b: contract iOS | `HistoryDTOs.swift`, `CoreMappers.swift`, `Journey.swift`, `RoutePoint.swift` mới, `JourneyContractTests.swift` và test mapper | 0/1/2/N điểm, schema cũ/mới, sort/dedupe/invalid/403; build Debug/Release |
| F2: gap logic | `RouteGapAnalyzer.swift`, `RouteOverlayModel.swift`, `PolylineSimplifier.swift`, 2-3 test | Không nối qua gap như observed; giữ góc và ranh giới; 10.000 điểm không làm chậm main |
| F3: map/UI | `RouteMapRenderer.swift`, `RouteMapView.swift`, `JourneyViewModel.swift`, `JourneyView.swift`, vi/en strings, tests/previews | Nét đứt, chú thích, VoiceOver, chọn đoạn, diff/Dark Mode; nếu >8 file thì tách F3a/F3b **trước khi code** |
| F4: decision gate | Bảng số đo + A/B/C, chưa code | Chủ dự án chọn riêng cách bám đường sau khi biết mật độ/terms/chi phí |
| F5 tùy chọn | Realtime adapter/VM/map/tests; tách nếu >8 file | Chỉ hôm nay, dedupe/coalesce, đối soát BE, không đổi LiveMap |
| F6 | `PROGRESS.md`, `AI_RULES.md` nếu cần, `study/route-fidelity-interview-notes.md` | Checklist thiết bị thật; không nhận “bám đường” khi chưa map-match |

Mỗi giai đoạn code: build Simulator Debug/Release không ký, `scripts/test_networking.sh`, `scripts/test_localization.sh`, SwiftLint, `xcodebuild test` nếu scheme hỗ trợ, `git diff --check`; báo kết quả thật trước giai đoạn tiếp. Test thủ công: chuyến nhiều góc phố, GPS mất giữa chừng, ngày trống/một điểm, thành viên khác, Dark Mode, Dynamic Type, VoiceOver, 1.000+ điểm/Instruments, mở/đóng nhiều lần. Không thêm dependency; không đổi LiveMap/chat/SOS/auth. **F0 không có code, không commit.**

## Cần tôi quyết định trước F1/F3/F5

1. Ngưỡng gap 90 giây / 250 m là **giả thuyết**, đề xuất hiệu chỉnh theo p50/p90; quá thấp tạo gap giả, quá cao che gap thật. Đề xuất nét đứt để không phụ thuộc màu.
2. Mật độ lưu backend: đề xuất thử 10-15 giây hoặc 25 m **khi di chuyển**, có giới hạn chi phí; không tự sửa P4 client.
3. F4 A/B/C và quyền gửi lịch sử cho dịch vụ ngoài: chưa chọn; ưu tiên đo trước, A nếu đủ dày.
4. F5 trong đợt này: đề xuất để sau F3 và sau khi socket iOS thực sự gửi `recordedAt/accuracy`.
5. Chú thích gap: đề xuất trong bảng kéo + accessibility, không đè map nhỏ.
6. Quãng đường: đề xuất lấy `distanceMeters` từ server và ghi “ước tính GPS”; nếu chưa có, tính cục bộ nhưng vẫn đánh dấu ước tính.
7. Cần BE xác nhận timezone IANA, retention và bản deploy; không suy từ backend local.
8. **Xung đột commit:** `study/route-on-map.md:177` ghi “không tạo commit”; yêu cầu mới lại nói một commit mỗi F1-F5. Đề xuất giữ **không commit** cho đến khi bạn chốt lại trước F1; F0 không commit.
9. Trước F3/F5, cần xác nhận khóa Presentation (i18n/tab/refactor) và Location/Realtime (P7D/P7E) đã mở.

---

## F0.1 - Hợp đồng BE đã giao (B6a) và khoảng lệch

> Phần này **thay thế kế hoạch F1-F6 ở trên** khi có mâu thuẫn. Nguồn chuẩn: `../Backend/api-docs/JOURNEY_ROUTE_API_DOC.md`, `../Backend/api-docs/LOCATION_UPDATE_API_DOC.md`, đối chiếu `../Backend/Study/route-geometry-mobile-contract-followup.md` và mã backend hiện tại. **Chỉ xác nhận mã trong workspace, chưa xác nhận bản deploy.** F0.1 chỉ sửa tài liệu; không sửa app, backend hoặc tạo commit.

### Trạng thái thực tế và điều cần kiểm chứng

- **B6a có trong mã backend:** `detail=geometry` trả `timeZone` và `geometryPolicy` ở cấp cao nhất; `version=2`, `gapIndexSpace=points`, `toBoundary=inclusive`; raw range thêm alias `recordedAt === timestamp`. Xem `../Backend/src/application/history/historyUseCases.js:36-56,88-129,132-147`, `../Backend/src/config/env.js:172-180`. API doc Journey hiện **chưa mô tả hai metadata B6a** và tài liệu B6 vẫn viết ở thì kế hoạch; mã là bằng chứng triển khai cục bộ, không phải bằng chứng deploy.
- **B6b chưa có trong mã đọc được:** `detectStayPoints` vẫn là thuật toán legacy; stay không có `confidence`, `containsDataGap`, `segmentId`; summary chưa có `observedStaySeconds`/`unobservedSeconds`. `../Backend/src/domain/journey.js:29-74,202-220`. Quy tắc **hybrid đã duyệt nhưng chưa triển khai**: interval > `gapThresholdSeconds` và hai đầu xa hơn `stayRadiusMeters` mới là route gap; cùng khu vực là stay `inferred`, không có nét đứt trong stay. `leftAt` là fix in-radius cuối; `durationMinutes` có thể gồm thời gian không quan sát. Chỉ áp dụng UX inferred khi BE thực sự trả field này.
- **B6c chưa có:** query parser mới nhận `date`, `detail`; geometry hiện luôn có cả `path` lẫn `points`. Không gửi `includePath=false` tới BE trước khi xác nhận deploy. `../Backend/src/presentation/dto/history.schemas.js:24-31`, `../Backend/src/domain/journey.js:100-118`.
- **B2-B5 đã có trong mã:** geometry response có `points`, `gaps`, `segmentId`, `pointCount` (số điểm **đã trả**), `originalPointCount`, `distanceMeters` (tính từ điểm gốc), `thinned`, `observedMovingSeconds`. Backend làm thưa theo run giữa các gap và giới hạn mặc định 1000 điểm/segment. `../Backend/src/domain/journey.js:82-119`, `../Backend/src/domain/routeGeometry.js:48-71,134-189`, `../Backend/src/config/env.js:37-39`.
- **Quan trọng:** B6a **chưa** thay phân loại gap time-only; `analyzeRouteGaps` hiện đánh dấu mọi interval > threshold, bất kể khoảng cách. Không thể hứa UX “ngồi yên nhiều giờ = một inferred stay, không nét đứt” cho tới B6b deploy. `../Backend/src/domain/routeGeometry.js:48-69`, `../Backend/src/domain/journey.js:29-74`.
- **Môi trường chưa biết:** chưa có payload có token của app đang gọi Render; không biết bản deploy đã có B6a chưa, cờ `LOCATION_HISTORY_DENSE_ENABLED` đang bật hay tắt, B6b/B6c có được deploy mới hơn workspace hay không. `../Backend/render.yaml:16-17,36-49` và `.env.example` đặt dense=`false`, nhưng dashboard/env thực tế có thể khác. Xác nhận bằng request Journey có `detail=geometry` qua Pulse: chỉ ghi **tên các key, version và aggregate counts**, không xuất JSON thật. Với cờ dense, BE owner xác nhận cấu hình môi trường; có thể so aggregate mật độ điểm trước/sau ở môi trường thử, không suy đoán từ Render YAML.

### Bảng lệch hợp đồng: Journey (`GET /history/{userId}/journey?date=...&detail=geometry`)

`B6a` = đã có trong mã backend; `B6b/B6c` = chờ. Mọi trường mới trong DTO iOS phải optional để app mới đọc được BE cũ. `path` cũ vẫn là fallback **chỉ khi không có `points`**.

| Trường BE | Kiểu/ý nghĩa | Trạng thái | iOS hiện tại -> cần làm |
| --- | --- | --- | --- |
| `timeZone` | IANA String, cấp cao nhất | B6a | Chưa decode -> optional, dùng cho ranh giới ngày; đối chiếu timezone phiên |
| `geometryPolicy.version` | Int, mã hiện là 2 | B6a | Chưa decode -> optional; thiếu = legacy, version lạ vẫn decode additive và đếm tổng hợp |
| `geometryPolicy.gapThresholdSeconds` | Number, ngưỡng BE hiệu lực | B6a | Chưa decode -> optional; **không tự dùng 90/180 giây** khi server có `gaps` |
| `geometryPolicy.gapIndexSpace` / `toBoundary` | String `points` / `inclusive` | B6a | Chưa decode -> optional; validate trước khi giải nghĩa index |
| `geometryPolicy.stayRadiusMeters` / `minStayMinutes` | Number, ngưỡng stay | B6a | Chưa decode -> optional, chỉ dùng theo ngữ nghĩa version được hỗ trợ |
| moving `segmentId` | String ổn định | B2-B5 | Chưa decode; Domain `id=startTime` -> ưu tiên segmentId, fallback cũ |
| moving `points[]` | `{latitude,longitude,recordedAt,accuracy?}` | B2-B5 | DTO chỉ có `timestamp?`, mapper bỏ thời gian -> `RoutePoint` giữ Date/accuracy; `points` là nguồn chính |
| moving `path[]` | `{latitude,longitude}` | Hiện có; B6c có thể bỏ | DTO optional nhưng mapper **ưu tiên path** -> đảo ưu tiên, fallback legacy nếu không có points |
| moving `pointCount` / `originalPointCount` | Int, điểm trả / điểm gốc | B2-B5 | DTO có `pointCount` nhưng Domain moving chưa có; bổ sung optional, **không đồng nhất hai số** |
| moving `distanceMeters` | Number, từ điểm gốc trước thinning | B2-B5 | Chưa có -> optional, hiển thị “ước tính theo GPS”, không tính lại từ `points` |
| moving `maxGapSeconds` | Number, gap lớn nhất thực tế | B2-B5 | Chưa có -> optional; **không dùng làm threshold** |
| moving `gaps[]` | `{fromIndex,toIndex,seconds,meters}` | B2-B5 | Chưa có -> optional, validate `0 <= from < to < count`, thường kề nhau, tăng thời gian và không chồng lấn |
| moving `thinned` / `observedMovingSeconds` | Bool / Number | B2-B5 | Chưa có -> optional; không DP thêm 8 m khi `thinned=true` nếu không cần cho hiệu năng |
| stay `arrivedAt/leftAt/durationMinutes/pointCount` | String/String/Int/Int | Cũ và mới | Đã decode; B6b thay **cách hiểu** duration, không coi là quan sát liên tục nếu inferred |
| stay `segmentId/confidence/containsDataGap/maxGapSeconds` | String/enum/Bool/Number | B6b chờ | Chưa có -> optional; inferred có nhãn + marker khác hình dạng, không tự suy ra khi thiếu |
| summary `observedMovingSeconds` | Number | B2-B5 | Chưa có -> optional; dùng cho nhãn “đã quan sát”, không gán nghĩa này cho `totalMovingMinutes` |
| summary `observedStaySeconds/unobservedSeconds` | Number | B6b chờ | Chưa có -> optional, chỉ hiển thị khi có; `unobservedSeconds` gồm cả im lặng tại chỗ và route gap |
| summary `firstSeenAt/lastSeenAt` | ISO-8601 String | Cũ và mới | Đã decode String; parser hiện hỗ trợ mili-giây, F1 cân nhắc Date nội bộ nhất quán |

**Union/decoder:** `JourneyItemDTO` hiện là một struct nhiều optional (`HistoryDTOs.swift:18-71`), `toDomain()` trả nil khi thiếu field/type lạ rồi `compactMap` bỏ im lặng (`CoreMappers.swift:71-74,113-152`). F1 tách decode theo `type`, đếm tổng hợp type lạ/entry lỗi (không log nội dung), giữ response legacy. `BackendJSONCoding.makeDecoder()` đã dùng `ISO8601.date` hỗ trợ có/không mili-giây (`BackendJSONDecoder.swift:3-17`, `Domain/Common/ISO8601.swift:3-20`); vấn đề chính là DTO còn String và bỏ thời gian từng điểm, **không phải** parser không đọc được mili-giây.

**Gap invariant:** `fromIndex/toIndex` trỏ vào `points` **sau thinning**. Backend hiện giữ biên gap khi làm thưa (`routeGeometry.js:134-161`, `journey.js:90-98`); mobile vẫn validate range, tính kề nhau, thời gian tăng và thứ tự. Gap lỗi: bỏ riêng metadata, tăng **aggregate metric**, nhưng **không vẽ cạnh nghi vấn thành nét liền**; nếu không thể xác định cạnh thì chọn không vẽ liên kết/đánh dấu geometry không chắc chắn. Không sắp xếp lại `points` một cách độc lập mà quên remap `gaps`: nếu thứ tự sai, phải loại/chế độ an toàn hoặc tái ánh xạ có test.

**Raw history, không tích hợp đợt này:** range hỗ trợ `from/to/limit/cursor`, `to` là **inclusive**, `nextCursor` opaque; B6a trả cả `recordedAt` và `timestamp` bằng nhau. iOS `HistoryPointDTO` hiện chỉ nhận timestamp và không có range DTO. Không thêm request raw vào luồng Journey nếu geometry đủ. `../Backend/src/application/history/historyUseCases.js:36-45,88-129`; đây **sửa lại** giả định `to` exclusive trong đề nghị cũ `api-docs/ROUTE_GEOMETRY_REQUEST.md`.

### Phụ thuộc P7, socket và pin

- P7A-D có mã trong working tree; `PROGRESS.md:60-76` đánh dấu xong P7D, **P7E còn pending**. Tuy nhiên các thay đổi P7/route chưa phải đều trong HEAD (`git status` còn nhiều file đã sửa/chưa theo dõi), vì vậy **không thể khẳng định đã merge**. Không xóa, revert hoặc gom những thay đổi này vào commit F1.
- `SocketRealtimeRepository.emitLocationIfReady` đang gửi `latitude`, `longitude`, `batteryLevel` (`:64-70`). `LocationFix` có `timestamp`, `horizontalAccuracy`, `speed`, `course` (`LocationFix.swift:4-12`); `MotionState.rawValue` đã trùng enum BE (`LocationSendPolicy.swift:3-10`, `../Backend/src/presentation/dto/location.schemas.js:7,11-19`). BatteryMonitor trả 0...100 (`BatteryMonitor.swift:30-38`), phù hợp BE, không phải 0...1.
- `BufferedLocationPoint` tạo UUID **lúc append**; batch DTO gửi UUID, `recordedAt`, accuracy, battery nhưng chưa có motionState. Socket không gửi UUID; một fix đi socket trước rồi batch sau chưa bảo đảm dùng chung pointId do P7D chưa phủ metadata. `BufferedLocationPoint.swift:3-19`, `LocationBatchDTOs.swift:3-22`, `LocationDeliveryService.swift:67-85`.
- Hai hướng để bạn chọn: **A (đề xuất)** hoàn tất metadata/identity trong P7 riêng trước F5, truyền `AcceptedFix`/stable pointId qua cả socket và buffer, giữ UUID khi heartbeat/retry, test tính nhất quán; giảm chồng lấn và dễ rollback. **B** mở rộng F5 của task Journey để sửa socket + batch/identity, phạm vi lớn, phải tách giai đoạn/commit và kiểm thử lại P7. Nếu BE cũ, client vẫn gửi payload tối thiểu cho tới khi xác nhận hỗ trợ trường mới; không gửi accuracy âm, NaN hoặc vô hạn. Không tự chọn.

### Thiết kế thích ứng và hiển thị trung thực

- **Geometry mode sau quyết định bám đường bộ:** request `detail=geometry`; `points` là nguồn tọa độ/thời gian chuẩn, `path` chỉ để đọc bản cũ. `gaps` chia observed runs và liên kết thiếu dữ liệu; **chỉ run có `roadGeometry` hợp lệ từ BE mới được vẽ nét liền bám đường**. Khi BE chưa có map matching, không nối raw points bằng nét đặc. Gap chỉ là nét đứt có nhãn ước tính hoặc không nối. Không dựng điểm mới, không tự tính lại ngưỡng gap. Run một điểm -> marker; 0 điểm -> `journey.map.empty.geometry`. Khi `thinned=true`, không làm thưa thêm trước khi match; renderer có thể giản lược *matched geometry* trong từng run nếu hiệu năng đòi hỏi, giữ biên.
- **Legacy response sau quyết định bám đường bộ:** không vẽ `path` thành đường đặc. Giữ marker/điểm quan sát và thông báo chưa có tuyến đường bộ; không tạo đường từ from/to. Nếu `points` có nhưng thiếu `gaps` hoặc geometry khớp đường, cũng không gọi là tuyến đã đi.
- **Stay B6b:** `confidence=observed` giữ marker hiện tại; `confidence=inferred` hoặc `containsDataGap=true` dùng nhãn/hình dạng riêng, duration gắn “ước tính”, bảng kéo và VoiceOver nêu “có thời gian thiếu GPS”. Không có các trường B6b: giữ stay hiện tại, không tự suy luận. Stay **không** có gap link. Khi B6b chưa deploy, không hứa một stay duy nhất sau im lặng dài.
- **Số liệu:** `observedMovingSeconds` là thời gian di chuyển **được quan sát**; `totalMovingMinutes` là khoảng hành trình legacy có thể gồm gap, vẫn hữu ích nếu gắn đúng nhãn. `observedStaySeconds`/`unobservedSeconds` chỉ hiển thị khi có. `distanceMeters` là ước tính GPS theo **điểm gốc**, không cộng lại từ points đã thinning. Định dạng giờ/quãng đường bằng locale app; `L10n.tr` cho mọi nhãn.
- **Ngày:** xây `date` ở một nơi theo timezone cấu hình ban đầu `Asia/Ho_Chi_Minh`; khi response `timeZone` khác thì lưu trong phiên và tải lại **một lần tối đa**, không loop. Hiển thị giờ theo timezone thiết bị + locale app; “hôm nay”/ngày lọc theo timezone server. Cần test nửa đêm và máy đang ở nước ngoài; chưa thay đổi ở F0.1.

### Wireframe bổ sung cho F3 (B6b có và chưa có)

```text
GEOMETRY: [Ngày v] [Thành viên v] [Căn lại]
          A ===== B - - - C ===== D     (liền: đường bộ đã khớp; đứt: thiếu GPS)
          [Bảng kéo] Đoạn di chuyển · 1 khoảng trống · ~quãng đường GPS
STAY B6b: [Marker ~] Có thể đã ở đây · ~20 phút
          [Bảng kéo] Có thời gian không có dữ liệu GPS
STAY CŨ:  [Marker stay cũ] Dừng 20 phút (không tự suy luận inferred)
LEGACY:   [A]     [B] Chưa có tuyến đường bộ đã xác minh
1 ĐIỂM:   [Marker] Chưa đủ điểm để vẽ đường đi
0 ĐIỂM:   Chưa có hành trình / chưa đủ hình học
LỖI:      Không tải được [Thử lại] | 403: Không có quyền xem
```

| Key mới đề xuất (vi/en cùng giai đoạn F3) | vi | en |
| --- | --- | --- |
| `journey.map.gap.count` | %d khoảng trống dữ liệu | %d GPS data gaps |
| `journey.map.legacy.uncertain` | Chưa có tuyến đường bộ cho hành trình này. | A road-aligned route is not available for this journey. |
| `journey.map.stay.inferred` | Có thể đã ở đây | Possibly stayed here |
| `journey.map.stay.inferred.detail` | Thời lượng ước tính; có khoảng thời gian không có dữ liệu GPS. | Estimated duration; some time has no GPS data. |
| `journey.map.moving.observed` | Di chuyển được quan sát: %@ | Observed movement: %@ |
| `journey.map.unobserved` | Không có dữ liệu: %@ | No GPS data: %@ |
| `journey.map.distance.approx` | Quãng đường ước tính theo GPS: %@ | Estimated GPS distance: %@ |

`journey.map.distance.approx` cần **kiểm tra lại trước khi thêm**, vì yêu cầu nói đã có nhưng `rg` trong hai `Localizable.strings` hiện **không tìm thấy**. Plural `%d` dùng một cấu trúc chung ở cả hai ngôn ngữ; nếu cần plural thực sự theo quy tắc locale, dùng `.stringsdict`/formatter hiện có thay vì nối chuỗi thủ công. Không thêm key ở F0.1.

### Execution Plan F1-F6 sau khi duyệt F0.1

Mỗi giai đoạn là **một thay đổi riêng, khoảng <=8 file**, báo build/test/lint thật và **đề xuất** commit message; **không tự commit**. Chờ bạn báo đã commit rồi mới sang giai đoạn kế. Nếu buộc vượt 8 file, tách nhỏ và hỏi trước. Không sửa backend.

| Giai đoạn | File dự kiến / ranh giới | Tiêu chí và test |
| --- | --- | --- |
| F1a - request/DTO | `Endpoints.swift`, `HistoryDTOs.swift`, `RoutePoint.swift` mới, test contract mới (<=4) | `detail=geometry`; metadata/points/gaps/stay B6b optional; BE cũ/thiếu policy/version lạ/0-1-N điểm/mili-giây; chưa đổi UI |
| F1b - mapper/domain | `CoreMappers.swift`, `Journey.swift`, `JourneyContractTests.swift`, test mapper bổ sung (<=4) | `JourneyItem` custom `Decodable` đọc `type` trước; unknown/invalid có counter aggregate, không im lặng; points ưu tiên, path fallback, segmentId ổn định, 403 không bị nuốt; build/test |
| F2 - runs/gaps thuần | `RouteOverlayModel.swift`, `PolylineSimplifier.swift`, `RouteGapAnalyzer.swift` mới, tests (<=6) | Validate index/time/order; gap lỗi không thành nét liền; A-C-D, gap đầu/cuối, nhiều gap, `thinned`, 10.000 điểm; DP chỉ trong run |
| F3a - MapKit | `RouteMapRenderer.swift`, `RouteMapView.swift`, `RouteMapMarker.swift`, tests/previews (<=5) | Trước khi BE map-match: không vẽ raw GPS thành đường bộ. Khi có matched geometry: vẽ chỉ các run hợp lệ; gap không thành đường đặc; inferred marker, diff overlay, 1 điểm/0 điểm, Dark Mode/VoiceOver |
| F3b - UI/locale | `JourneyViewModel.swift`, `JourneyView.swift`, `JourneyTimelineRows.swift`, vi/en strings, tests (<=7) | observed/unobserved/distance chính xác, nhãn legacy/inferred, plural/localization; chỉ sau mở khóa Presentation |
| F4 - timezone | `TimelineUseCases.swift`, `JourneyViewModel.swift`, helper timezone/config, tests (<=5) | Date theo TZ server, tải lại tối đa 1 lần, đổi TZ/nửa đêm; không loop |
| F5 - socket metadata **nếu duyệt** | Scope P7 riêng hoặc task Journey tách thêm, chưa gộp F1-F4 | `pointId` ổn định giữa socket/batch/heartbeat, `recordedAt/accuracy/motionState` đúng, BE cũ vẫn dùng payload tối thiểu |
| F6a - payload opt-out **khi B6c deploy** | `Endpoints.swift`, cấu hình capability, tests (<=4) | `includePath=false` chỉ bật sau xác nhận deploy, mặc định tắt; không dò bằng lỗi 400 |
| F6b - realtime hôm nay **nếu duyệt** | Socket observation/VM/map/tests; tách nếu >8 | Dedupe/coalesce <=1 lần/s, chỉ hôm nay; pin vị trí mới cập nhật ngay, **không** kéo dài đường bộ bằng đoạn thẳng raw. Chỉ nối khi BE trả matched geometry mới; refresh từ BE là chuẩn |
| F6c - tích hợp bám đường/tài liệu | DTO matched geometry, renderer/VM/tests và `study/route-fidelity-interview-notes.md`; tách thành nhiều giai đoạn <=8 file sau khi BE bàn giao | Backend map-matching (phương án B) đã được chọn. Chỉ vẽ kết quả matched theo từng run; kiểm tra thiết bị thật, aggregate mật độ/p50/p90, không coi đoạn thiếu dữ liệu là đường đã đi |

Gate mỗi giai đoạn: build Simulator Debug/Release không ký, `scripts/test_networking.sh`, `scripts/test_localization.sh`, SwiftLint, `xcodebuild test` nếu scheme chạy được (nếu không nêu lệnh/lý do), `git diff --check`. Checklist máy thật: nhiều góc phố/dense bật, tắt mạng lúc đi, im lặng đứng yên lâu **chỉ kỳ vọng inferred khi B6b deploy**, xuất hiện xa sau mất tín hiệu, ngày trống/1 điểm, thành viên khác, 403, Dark Mode, Dynamic Type, VoiceOver, ngày dài/Instruments, mở/đóng nhiều lần. Script thống kê nếu làm ở F6c chỉ xuất aggregate, không lưu/đưa payload thật vào repo/LLM.

### Hỏi Backend / xác nhận deploy

1. B6a đã deploy lên URL nào của app? Có thể kiểm chứng bằng các **key** `timeZone`, `geometryPolicy.version` trên response `detail=geometry` sau khi auth, không cần chia sẻ raw payload.
2. `LOCATION_HISTORY_DENSE_ENABLED` thực tế bật hay tắt? `render.yaml:36-37` là `false`, có thể bị override. B6b/B6c dự kiến và đã deploy đến đâu?
3. Khi B6b hoàn tất, xác nhận `leftAt`, duration inferred, `observedStaySeconds`, `unobservedSeconds` như tài liệu B6; có cần một trường summary cho khoảng im lặng dài nhất không?
4. Version policy hiện là 2 trong mã (`env.js:172-180`); quy tắc tăng version khi thay đổi **ngữ nghĩa** (hybrid ở B6b) là gì? iOS sẽ bỏ diễn giải version không hiểu thay vì crash.
5. Nếu gửi `includePath=false` đến BE cũ, hiện parser sẽ loại/bỏ qua query hay 400? Mobile sẽ **không gửi** trước xác nhận B6c, nhưng cần hợp đồng rollback rõ.

### Cần tôi quyết định (sau F0.1, không tự chọn)

1. **P7D/F5:** đề xuất làm metadata + pointId chung trong task P7 riêng trước F5; phương án gộp sẽ mở rộng phạm vi và phải test lại batch/realtime.
2. Stay inferred: đề xuất nhãn `~` **kèm chữ** “Có thể đã ở đây”, marker khác hình dạng; `maxGapSeconds` chỉ ở phần chi tiết, tránh quá tải dòng.
3. Thời gian: đề xuất hiển thị `observedMovingSeconds` chính; `totalMovingMinutes` là khoảng hành trình phụ, có nhãn rõ. `unobservedSeconds` trong bảng kéo, không trên map.
4. Timezone: đề xuất ngày theo `timeZone` server, giờ hiển thị theo thiết bị và locale app; người ở nước ngoài có thể thấy giờ địa phương nhưng ngày lọc theo VN. Cần xác nhận UX này.
5. `includePath=false`: đề xuất cờ capability mặc định tắt, bật thủ công sau deploy B6c; **không** dựa riêng vào version 2 vì B6a cũng version 2.
6. Legacy: **đã chốt** không vẽ đường thẳng/đường đặc từ raw path; hiển thị mốc quan sát và trạng thái chưa có tuyến đường bộ.
7. Raw history: đề xuất không nối vào Journey đợt này; tránh hai nguồn dữ liệu phức tạp.
8. Realtime F6b: đề xuất task/giai đoạn riêng sau khi F5 socket metadata và P7E sẵn sàng; không chặn F1-F4.
9. A/B/C bám đường bộ: **đã chọn B - map-matching ở backend**; nhà cung cấp, chi phí, giấy phép và chất lượng vẫn cần task backend đánh giá. Không dùng `MKDirections` để giả hành trình đã đi.

## Quyết định bám đường bộ (sau F0.1)

Chủ dự án xác nhận: hành trình của **chính tài khoản và mọi thành viên được phép xem trong Circle** phải theo cùng một đường bộ đã được map-match phía backend. `RouteMapView` vẫn là màn riêng của Journey; khác nhau chỉ là `userId` được phép truy cập, không có thuật toán vẽ riêng cho từng người. Đặc tả giao backend: [ROAD_MATCHING_BACKEND_TASK.md](../api-docs/ROAD_MATCHING_BACKEND_TASK.md).

**Ranh giới tin cậy:** map matching suy ra con đường khả dĩ từ các fix, không chứng minh tuyệt đối người dùng đã đi đúng đường đó. Với fix quá thưa, mất GPS, độ tin cậy thấp, không có đường hợp lệ hoặc backend chưa hỗ trợ, **không vẽ đường thẳng đặc**. Chỉ hiển thị các mốc GPS được phép xem, cảnh báo dữ liệu chưa đủ, và nếu phù hợp một liên kết đứt có nhãn “ước tính/không có GPS”, tuyệt đối không gọi nó là tuyến đã đi. Gap không được map-match xuyên qua.

**Thứ tự phụ thuộc:** F1a DTO/request đã xong nhưng chưa commit; F1b/F2 xử lý metadata điểm/gap; task backend riêng tạo matched geometry có version/provenance/confidence; sau khi có contract và fixture tổng hợp mới chia F6c thành các thay đổi iOS <=8 file để decode/render/test. Các D1-D3 hiện còn trong working tree là nền bản đồ, **chưa đạt tiêu chí bám đường**, không commit như tính năng đã hoàn tất. Không tự chạy `git commit` khi chưa chốt lại phạm vi với bạn.

**Điều còn phải quyết định trong task backend:** engine/provider và điều khoản hiển thị trên Apple Maps, hạ tầng/chi phí, ngưỡng đủ dữ liệu và confidence, retention của hình học khớp đường. Dữ liệu thực không đưa vào log, fixture hoặc tài liệu. Mật độ GPS lịch sử và trạng thái cờ dense trên bản deploy vẫn chưa được xác nhận.
