# I0 - Kiểm kê tích hợp Location iOS

> Trạng thái: **I0 đã đối chiếu; dừng trước PV/JG/LT**, chưa sửa Swift/backend, chưa commit (21/10/2026). Dữ liệu vị trí nhạy cảm: fixture tổng hợp; không log tọa độ, token, tên, địa chỉ. Nền tảng thực tế: iOS 16, Combine, MVVM-C, `RouteMapView`/`MKMapView`.

**Kế hoạch canonical:** file `Mobile/study/location-integration-mobile.md` này, đúng deliverable của task Mobile. Ngày 21/10/2026, `Backend/docs/location-integration-mobile.md` giống hệt bản Mobile trước cập nhật này; đó là bản sao tham khảo, **không sửa/đồng bộ trong task Mobile**. Bốn API contract trong `Mobile/api-docs/` vẫn là nguồn chuẩn về wire format. Mọi quyết định mới phải cập nhật ở đây trước để tránh hai kế hoạch lệch nhau.

### Quyết định đã chốt ngày 21/10/2026

1. Chưa có road match hợp lệ: hiện **điểm GPS và nét đứt**, kèm nhãn **“Vệt GPS chưa khớp đường”**. Không vẽ raw GPS bằng đường đặc như thể đã biết tuyến đường bộ. Chỉ matched hợp lệ mới có đường đặc; match lạ/hỏng trở về raw có nhãn.
2. Tạm dừng chia sẻ theo **fail-closed**: chặn gửi ngay trên thiết bị **trước PATCH**. Nếu mất mạng, giữ dừng cục bộ và `pendingSync`, tuyệt đối không gửi socket/batch, retry PATCH có giới hạn khi có mạng. SOS vẫn lấy/gửi vị trí theo luồng riêng.
3. **Chưa mở khóa code:** Mobile còn thay đổi chưa commit ở Journey/ViewModel, DTO/endpoint/mapper, Domain, vi/en `.strings`, RouteMap và tests; API docs còn untracked. Backend có `PROGRESS.md` modified và docs untracked. Không bắt đầu PV/JG/LT trước khi xác nhận các thay đổi Mobile là phần Journey F1-F3 cần giữ. Git không xác định được có agent/process khác đang mở file hay không.

Đối chiếu diff hiện tại: các thay đổi Journey/RouteMap, localization, tests, `AI_RULES.md` và `PROGRESS.md` **phù hợp về nội dung** với D1-D3/F1 đang dở; đây chưa phải xác nhận quyền sở hữu hay cho phép ghi đè. Hai comment trong `AuthRepository.swift` và `AuthUseCases.swift` không thuộc Journey/Location; giữ nguyên, không tự hoàn tác.

### Định hướng sản phẩm được làm rõ ngày 21/10/2026

**Chức năng chính là vệt di chuyển realtime bám đường**, được vẽ tiếp khi người dùng đi và cho các thành viên có quyền trong Circle xem gần đồng thời. Vệt của chính mình ưu tiên cập nhật từ GPS trên máy, vệt của người khác qua snapshot + Socket.IO delta; hai phía dùng cùng ngữ nghĩa matched/raw/gap. **Journey là màn xem lại vệt đã ghi theo từng ngày**, không phải một thuật toán đường đi độc lập, cũng không phải chỉ đường `MKDirections` đến người khác. Không cần giả định có phiên chạy bộ phải bấm Bắt đầu/Kết thúc: đề xuất mặc định theo phiên chia sẻ vị trí hằng ngày; cần chủ dự án xác nhận nếu muốn workout session riêng.

**Khoảng cách contract hiện tại:** Live Trail của backend có snapshot/watch/delta theo `date` và lưu `matched[]`, nhưng mặc định tắt trên production; matcher production là Noop, chưa tạo đường bám đường thật. Live Trail giữ **7 ngày mặc định** (`LIVE_TRAIL_RETENTION_DAYS=7`, giới hạn cấu hình 1...30), trong khi `GET /history/{userId}/journey` dựng từ `LocationHistory` riêng và **không trả cùng matched geometry của Live Trail**. Nếu chỉ cần xem lại trong thời hạn Live Trail, mobile có thể dùng chính snapshot trail theo ngày **sau khi backend bật tính năng và có matcher thật**. Nếu cần lịch sử lâu hơn thời hạn đó, backend phải bổ sung hoặc điều chỉnh retention/hợp đồng lưu trữ. Cần task backend riêng để bật/đo Live Trail và tích hợp matcher thật; không sửa backend trong task Mobile. Khi backend chưa sẵn sàng, ứng dụng vẫn có thể hiển thị raw GPS bằng điểm + nét đứt có nhãn, **không được gọi đó là bám đường**.

**Thứ tự ưu tiên mới:** hoàn thiện quyền riêng tư và membership (PV/CM) như cổng an toàn; sau đó ưu tiên Live Trail realtime + matcher hợp lệ (LT) làm trải nghiệm chính; cuối cùng nối Journey theo ngày vào **cùng dữ liệu trail/matched** (JG), trước mắt trong thời hạn retention Live Trail. Bảng giai đoạn bên dưới còn theo thứ tự cũ A→B→C→D để giữ lịch sử I0; không dùng thứ tự đó để triển khai. Các file D1-D3 hiện có là nền MapKit có thể tái sử dụng sau khi sửa renderer, **không phải tính năng chính đã hoàn tất**. F1a mới là DTO/request một phần; F1b/F2/F3 vẫn chưa đạt tiêu chí.

## Tóm tắt cho người duyệt

- P7 đã có bộ đệm vị trí, batch và refresh token dùng chung. Socket hiện chỉ gửi ba trường tọa độ/pin, nên vẫn thiếu timestamp, accuracy, pointId và motionState trên đường realtime.
- Journey D1-D3/F1a là thay đổi **chưa commit**: có nền MapKit và một phần DTO, nhưng chưa có Live Trail realtime hay đường matched. F1b/F2/F3 còn ở mức kế hoạch. Privacy, rời/xóa thành viên Circle và Live Trail chưa được nối phía iOS.
- Backend trong workspace có các contract mới, nhưng cấu hình production thực tế chưa được xác minh; Live Trail và matcher đều mặc định tắt. Không được diễn giải vệt GPS thô là tuyến đường bộ đã được xác nhận.
- Hai xung đột về raw GPS và thời điểm dừng gửi đã được chốt ở trên. Các quyết định còn lại và khóa file vẫn nằm ở mục “Cần tôi quyết định”; không suy ra toàn bộ I0 đã được mở khóa triển khai.

## Nguồn và thứ tự ưu tiên

- Nam file `api-docs/MOBILE_LOCATION_INTEGRATION_INDEX.md`, `LOCATION_UPDATE_API_DOC.md`, `JOURNEY_ROUTE_API_DOC.md`, `LIVE_TRAIL_API_DOC.md`, `PRIVACY_AND_CIRCLE_MEMBERSHIP_API_DOC.md` **da co trong worktree, dang untracked va `cmp` giong tung byte** voi `../Backend/api-docs/` tai Backend commit `f6a6a5f`. Khong copy de tranh ghi de thay doi chua commit cua chu repo. Bon contract sau index la canonical; cac Study chi la boi canh.
- Da doi chieu `../Backend/Study/{CORE_FLOWS_MOBILE,OFFLINE_LOCATION_BATCH_SYNC,live-trail-backend,LIVE_TRAIL_PRIVACY_AND_CIRCLE_EXIT,route-geometry-mobile-contract-followup}.md`. `CORE_FLOWS_MOBILE.md` va nhieu doan F0/P7/H0 mo ta **thoi diem truoc** cac thay doi moi; khong dung chung lam bang chung trang thai hien tai.
- Mobile context: `study/route-on-map.md`, `study/route-fidelity.md`, `study/location/P7-offline-location-buffer.md`, `api-docs/REFRESH_TOKEN_MOBILE_API_DOC.md`, `study/unified-chat-tab.md`. `study/live-trail-mobile.md` **khong ton tai**.

## Hiện trạng đã kiểm chứng

| Khoi | Bang chung va ket luan |
| --- | --- |
| Nhanh/working tree | `main` tai `fd91d48`; F1-F3/Journey va DTO/routes/tests dang **modified/untracked**, chua merge/commit. Khong coi cac file nay la baseline da phat hanh. L1 local trail chua thay trong source. Chat tab hop nhat da co `ChatHubCoordinator`/`ChatHubViewModel`. i18n vi/en va `L10n.tr` da co; refactor dang do khong the khang dinh chi bang commit. |
| Test target | Co nhieu file `FamilyTrackerTests/*.swift`, nhung `FamilyTracker.xcodeproj/project.pbxproj` **khong chua `FamilyTrackerTests`**. XCTest chua the coi la da chay; khong sua pbxproj bang tay. |
| Realtime gui | `ShareLocationUseCase` giu `LocationFix`, chon fix bang `LocationSendPolicy`, heartbeat 30s; `SocketRealtimeRepository.emitLocationIfReady` **chi emit** `latitude`, `longitude`, `batteryLevel` (`Int?` 0-100 tu `BatteryMonitor`). Chua co `recordedAt`, `accuracy`, `pointId`, `motionState` tren socket. Socket update khong ack. |
| Offline | `LocationDeliveryService` buffer fix qua policy neu chua ready; `LocationBuffer` luu JSONL theo owner/TTL 24h, max 500; `LocationSyncCoordinator` single-flight, loi 429/Retry-After, 413 split, 401 qua `APIClient` refresh. Batch DTO gui UUID bang Codable mac dinh (can test chu HOA), ISO date string; **thieu `motionState`** va `accuracy` chua loc so khong huu han. Socket va batch hien sinh `pointId` o hai thoi diem khac nhau; khong dam bao cung fix dung cung ID. `OfflineQueue` con dung cho SOS; legacy location item duoc bo qua khi replay, chua co `removeLocationOnly`. |
| Auth/loi | `TokenRefreshCoordinator` dung chung duoc tao mot lan trong `AppContainer`; `URLSessionAPIClient` retry 401 mot lan, `sendWithMetadata` giu header 429. `APIError.domainError` hien gom **tat ca 403** thanh `.forbidden`, 409/503 thanh `.server`; response loi tu server co the ro vao UI. `LocationBatchRepositoryImpl` gom moi 400 thanh invalidBatch va 403 paused thanh `.other(.forbidden)`. |
| Nhan location | `LocationUpdateDTO` chi doc `timestamp`, `durationAtLocation: Double?`; chua doc `recordedAt`, `accuracy`, `motionState`; domain `MemberLocation` giu timestamp `String`. Socket handler `JSONPayload.decode` tra `nil` am tham neu shape la. |
| Journey | `HistoryEndpoint.journey` co `detail=geometry`, **chua `includePath=false`**; DTO optional `timeZone`, geometryPolicy, points/gaps, stay quality nhung mapper/domain bo nhieu truong, `compactMap` bo type la. `RouteOverlayModel` hien ve polyline GPS tu `path`/`points`, chua gap run va dashed links. `JourneyViewModel` dung `Calendar.current`; chua doi chieu `timeZone` server. Raw history chi co today DTO, khong range/cursor. |
| Privacy/membership/trail | Chua thay endpoint/DTO/store/UX `location-sharing`, leave/remove, hoac listener `group:membership_ended/member_left`; chua co REST trail, watch/delta/reset/closed, polyline6. `GroupDetailView` hien member/chat, chua nut roi/xoa. `ProfileView` chi co LanguagePicker. `ChatHub`/Circle list can lam moi/evict neu membership thay doi. |
| Duong don | `AppContainer.logout` qua `LogoutUseCase`/`realtime.disconnect` goi `LocationDeliveryService.endSession(clearBuffer:true)`; session expiry dung sharing va socket, giu buffer theo owner toi 24h (quyet dinh P7). Mat quyen GPS dung chia se, giu buffer cho TTL. SOS doc vi tri tu `DeviceLocationRepository` rieng; privacy khong duoc chan SOS. |
| Backend | Source co privacy va membership handlers; `LIVE_TRAIL_ENABLED=false`, matcher `noop`/`fake` staging; day la **cau hinh repo**, chua xac minh deployment. `getGroupMembers` populate `name/email/avatar/isOnline/batteryLevel/locationSharing`, **khong co lastKnownLocation**; online presence van co the la true khi pause. Event membership duoc emit ten event truc tiep voi payload object, khong boc `{event,payload}` tren day. Tu roi thi `removedBy=actorId=userId`. |

## Ma trận phủ hợp đồng (14 dòng index)

`Co` chi nghia la da thay duong code, khong phai da co test contract day du. Moi dong can fixture JSON **nguyen van** tu canonical (tach phan JSON, khong sua gia tri), request/response/event va loi theo hop dong.

| # | Contract | Trang thai hien tai | Giai doan | Test cu the |
| --- | --- | --- | --- | --- |
| 1 | `update_location` | Co, chi 3 field | PV2a | Fake socket kiem chung 7 key, millis/UUID lower-case, accuracy am/NaN omit, motion enum; payload cu 3 key van decode BE |
| 2 | `location_update` | Co, DTO thieu 3 field, duration sai kieu | PV2a | Decode fixture muc 3 + legacy `timestamp` fallback + unknown motion |
| 3 | `POST /locations/batch` | Co P7B/C/D, thieu motion, UUID canon | PV2b | URLProtocol body/header, partial accepted/duplicates/rejected, 401, 413 split, 429, 500, owner fence |
| 4 | `GET /history/{userId}` today + range | Today co; range chua | JG1b | Exact query `from/to/limit/cursor`, date alias, inclusive `to`, opaque cursor, legacy fixture |
| 5 | `GET .../journey` legacy + geometry | Geometry co mot phan, legacy decode co, gap/stay quality mat | JG1a/JG2 | Query `date/detail/includePath`; fixture hai mode, unknown item count, gap bounds |
| 6 | `GET .../journey/trail` | Chua co | LT1a/LT1b | Page + `revision`, `nextAfterSeq`, 404/409/503/429, matched upsert |
| 7 | `journey:watch/unwatch` | Chua co | LT2a | Emit sau ready/snapshot; ack metadata/failure; unwatch khi roi/nen; 5 watch/30 action limit |
| 8 | `journey:trail_delta` | Chua co | LT2b | Seq la insertion, path order `(recordedAt,seq)`, delta empty points, cursor mismatch catch-up |
| 9 | `journey:trail_reset/closed` | Chua co | LT2b | Revision reset; `sharing_paused`, `permission_revoked`, `trail_expired`, unknown reason |
| 10 | `GET /privacy/location-sharing` | Chua co | PV1 | Bearer, millis dates, owner cache, offline restart fail-closed |
| 11 | `PATCH /privacy/location-sharing` | Chua co | PV1/PV2 | Indefinite/timeboxed/resume, 7 ngay, loi mang giu pause, SOS van duoc gui |
| 12 | `DELETE /groups/{groupId}/members/me` | Chua co | CM1 | Method/path/header, success envelope, admin 409 |
| 13 | `DELETE /groups/{groupId}/members/{userId}` | Chua co | CM1 | Admin 200; self/admin/forbidden/not-found/concurrent duplicate |
| 14 | `group:membership_ended/member_left` | Chua co | CM2 | Payload thuc tren day; evict group chat/watch/idempotent; direct chat giu nguyen |

### Ma trận phục hồi (8 dòng index)

| Contract | Trang thai hien tai | Giai doan | Test cu the |
| --- | --- | --- | --- |
| 401 | Shared refresh/retry co | PV1 | 2 request song song chi 1 refresh, retry 1 lan, socket token xoay |
| 403 `LOCATION_SHARING_PAUSED` | Bi gom `.forbidden` | PV1/PV2 | Tu ngung realtime/batch, clear buffer/queue-location, refetch privacy, khong retry |
| 403 `FORBIDDEN` | Co `.forbidden` chung | PV1/CM2 | Dung xem target/watch, khong tu tat sharing cua ban than |
| 409 `TRAIL_REVISION_CHANGED` | 409 la `.server` | LT1b | Huy trang dang tai, clear revision cu, reload co gioi han |
| 429 | Batch giu Retry-After; noi khac chua | PV2b/LT1b | Header seconds/date, jitter, gate >60s, khong loop |
| 503 trail | 503 chung `.server` | LT1a | Disable feature phien, fallback Journey/History, khong poll |
| Socket disconnect | Buffer/reconnect co; trail watch chua | PV2/LT2 | Buffer chi fix qua policy, ready->fresh fix, REST catch-up truoc rewatch |
| `trail_closed` | Chua co | LT2b | Unwatch/stop render live; chi user retry, revoked cho doi quyen thay doi |

## Bảng lệch contract và quy tắc mã hóa

| Endpoint/event | Contract canonical (key/kieu) | Mobile hien tai | Thay doi can |
| --- | --- | --- | --- |
| `update_location` | `latitude/longitude: Double`; `batteryLevel?: Number(0...100)`; `recordedAt?: ISO Date`; `accuracy?: Double>=0`; `pointId?: UUID lower-case`; `motionState?: enum` | 2 double + pin int | DTO `Encodable`/socket serialization dung chung fix identity; ISO millis, accuracy finite, motion enum; khong doi chinh sach throttle |
| `location_update` | `recordedAt`/`timestamp` ISO, `accuracy?: Double`, `motionState?: String`, `durationAtLocation: Int`, `durationSince/durationFormatted: String` | Chi timestamp, duration Double? | Uu tien recordedAt, fallback timestamp, type int; unknown motion -> `.unknown` + aggregate count |
| Batch | `points[1...100]`, body <100KB; each `pointId: UUID`, `recordedAt` ISO, `accuracy/batteryLevel: Double?`, `motionState?: String`; response UUID arrays + rejected(index:Int,pointId?,code,reason) | Da co except motion; UUID Codable; `recordedAt` String tu helper; unknown rejection dem 3 lan | Stable lower-case ID, motion optional, finite accuracy; known permanent drops; unknown attempts bound; chi xoa by pointId |
| History today/range | `count:Int`, `data[].recordedAt??timestamp`, `accuracy?:Double`, `pointId?:UUID`, `nextCursor?:opaque String`, `range.from/to:Date` | Today DTO chi `timestamp` + lat/lon; no range | DTO optional, range Endpoint URLQueryItem, no UI range, millis roundtrip |
| Journey | `date:String`, `timeZone?:String`, `geometryPolicy` v2, summary observed seconds `Double?`, moving `points/gaps/segmentId/distanceMeters/maxGapSeconds/thinned/observedMovingSeconds`; stay `confidence/containsDataGap/maxGapSeconds`; `path?` | DTO gan du, domain/mapper bo; no includePath=false | Custom union decoder + unknown metric, optional backcompat; read thresholds from response; build runs/gap links |
| Trail REST | `revision/lastSeq/seq/afterSeq/nextAfterSeq:Int`, gaps seq pair, match confidence `Double?`, geometry `polyline6`, ISO dates | Chua co | Endpoint/DTO/repository + assembler, typed `409/404/503/429` |
| Trail socket | watch/unwatch ack `ok/status/code`, delta `afterSeq/fromSeq/toSeq:Int`, reset/closed reason string | Chua co | Socket adapter + current watcher lifecycle/cursor tests; unknown reason fallback |
| Privacy | `enabled:Bool`, `pausedUntil/updatedAt:Date?`; PATCH enabled + optional millis Date | Chua co | Store owner-scoped, REST, local fail-closed, typed paused error |
| Membership | DELETE paths; response `groupId/conversationId?/userId/left`; events `groupId/userId/removedBy` | Chua co | repository/use cases/events/coordinator cleanup + UI |

- `BackendJSONCoding.makeDecoder/Encoder` da ho tro ISO millis, nhung `Endpoint.encodedBody()` goi **`JSONEncoder()` mac dinh**. Thuoc tinh Date payload moi phai dung `BackendJSONCoding.makeEncoder()` (hoac explicit string) va test round-trip timezone. `UUID` tren wire phai `uuidString.lowercased()`; `UUID` trong memory van la UUID.
- Query chi qua `URLQueryItem`, `cursor` opaque, `afterSeq` buoc co `revision`; `date` la chuoi `YYYY-MM-DD`, khong serialize nhu Date. So nguyen phai ma hoa la Int, khong dua qua Double/NSNumber de mat semantics.
- Loi can 1 policy typed theo `(HTTP status, code)`: `VALIDATION_ERROR/BAD_REQUEST`=sua request; `UNAUTHORIZED`=refresh/retry; `FORBIDDEN`=mat quyen; `LOCATION_SHARING_PAUSED`=ngung gui hoac thong bao target; `NOT_FOUND`=empty/not found; `CONFLICT`=admin action; `TRAIL_REVISION_CHANGED`=reload; `PAYLOAD_TOO_LARGE/BATCH_LIMIT_EXCEEDED`=split; `RATE_LIMITED`=Retry-After; `SERVICE_UNAVAILABLE`=trail-off; `INTERNAL_ERROR`=retry co gioi han. View chi hien chuoi L10n, khong hien `message/reason` raw tu backend.
- Ranh gioi privacy: `LocationSharingStore` la source duy nhat; `ShareLocationUseCase`, `LocationDeliveryService`, `LocationSyncCoordinator`, `SocketRealtimeRepository`, background wake deu phai kiem tra fail-closed. Kiem thu race `pause` voi pending write/sync/reconnect. Khi resume chi fix moi; SOS co duong rieng.

## UI wireframe (để duyệt, không phải UI hiện có)

```text
Profile > Chia se vi tri
+--------------------------------------------------+
| Chia se vi tri                         [ ON/OFF ]  |
| Dang chia se / Da tam dung den HH:mm / Vo thoi han |
| [Tam dung] -> 1 gio | 8 gio | den sang | tuy chon  |
|             -> Xac nhan: Circle khong xem duoc... |
|                SOS van gui vi tri khan cap         |
| [Tiep tuc chia se] (chi sau PATCH thanh cong)     |
| Mat mang: Da dung tren may nay; chua dong bo      |
| Dang tai: spinner; loi: [Thu lai]                 |
+--------------------------------------------------+

Journey/Trail: [Chon nguoi] [Ngay] [Thu lai]
  dang tai | khong co du lieu | bi tu choi quyen
  nguoi xem: "Da tam dung chia se" / "Cap nhat luc HH:mm"
  503: "Viet truc tiep chua san sang" -> Journey
  matched final/provisional | raw GPS (khong gia duong bo)
  gap: net dut/khong noi + chu "Thieu du lieu"
  stay inferred: nhan "Uoc tinh" + thoi luong
  bottom sheet: danh sach de VoiceOver doc toan bo

Group detail: [Roi nhom] (thanh vien; xac nhan hau qua)
              [Xoa thanh vien] (admin, khong phai chinh minh)
  loading/403/404/409 -> thong bao than thien, khong double tap
  membership_ended -> dong sheet/chat/trail, quay ve danh sach
```

## Bảng key L10n để duyệt (mỗi key có cả vi/en trong cùng thay đổi)

| Key | vi | en |
| --- | --- | --- |
| `privacy.location.title` | Chia sẻ vị trí | Location sharing |
| `privacy.location.on` | Đang chia sẻ vị trí | Sharing location |
| `privacy.location.off` | Đã tạm dừng chia sẻ vị trí | Location sharing paused |
| `privacy.location.until` | Tạm dừng đến %@ | Paused until %@ |
| `privacy.location.indefinite` | Tạm dừng cho đến khi bật lại | Paused until you resume |
| `privacy.location.pending` | Đã dừng trên thiết bị này; chưa đồng bộ lên máy chủ | Paused on this device; not yet synced |
| `privacy.location.confirm` | Người trong Circle không xem được vị trí và hành trình. SOS vẫn gửi vị trí khẩn cấp. | Circle members cannot see your location or journey. SOS can still send emergency location. |
| `privacy.location.resume` | Tiếp tục chia sẻ | Resume sharing |
| `privacy.location.target_paused` | %@ đã tạm dừng chia sẻ vị trí | %@ paused location sharing |
| `privacy.location.last_seen` | Cập nhật lúc %@ | Last updated at %@ |
| `privacy.location.duration.1h` | 1 giờ | 1 hour |
| `privacy.location.duration.8h` | 8 giờ | 8 hours |
| `privacy.location.duration.morning` | Đến sáng mai | Until tomorrow morning |
| `privacy.location.duration.custom` | Chọn thời hạn | Choose duration |
| `groups.action.leave` | Rời nhóm | Leave Circle |
| `groups.action.remove_member` | Xóa thành viên | Remove member |
| `groups.leave.confirm` | Bạn sẽ mất quyền xem vị trí và rời cuộc trò chuyện nhóm. | You will lose location access and leave the group conversation. |
| `groups.leave.admin_conflict` | Quản trị viên chưa thể rời nhóm. | The Circle admin cannot leave yet. |
| `journey.trail.unavailable` | Vệt trực tiếp chưa sẵn sàng | Live trail is unavailable |
| `journey.trail.gap` | Thiếu dữ liệu vị trí ở đoạn này | Location data is missing here |
| `journey.trail.inferred` | Điểm dừng ước tính | Estimated stop |
| `journey.trail.raw` | Vệt GPS chưa khớp đường | GPS trail not road-matched |
| `journey.trail.closed` | Hành trình trực tiếp đã dừng | Live trail stopped |
| `location.error.forbidden` | Bạn không còn quyền xem vị trí này. | You no longer have access to this location. |
| `location.error.rate_limited` | Quá nhiều yêu cầu. Hãy thử lại sau. | Too many requests. Try again later. |
| `location.error.service` | Dịch vụ tạm thời chưa sẵn sàng. | Service is temporarily unavailable. |

Trong file `.strings` se dung chu co dau day du; bang nay giu ASCII de de soat key. Dinh dang ngay/gio dung `L10n` locale, khong dich ten nguoi. Bat buoc them key cho accessibility cua nut/nhan trang thai trong PV3/CM3/LT3; bang nay la danh sach khoi dau, khong phai day du moi trang thai.

## Execution Plan (sau khi `approved I0`)

**Thứ tự triển khai đã đổi theo định hướng sản phẩm:** PV1-PV3 và CM1-CM3 là cổng an toàn; tiếp đó LT1-LT4 cho vệt realtime; JG1-JG4 chuyển thành xem lại cùng vệt theo ngày từ snapshot Live Trail, trong thời hạn backend giữ dữ liệu. Lịch sử dài hơn cần quyết định retention/contract backend riêng. LT5 tổng kiểm thử sau các phần đó. Các ID giai đoạn giữ nguyên để đối chiếu ma trận phủ, nhưng vị trí hàng trong bảng dưới đây **không** còn là thứ tự chạy. Không tuyên bố chức năng bám đường hoàn tất khi backend vẫn dùng Noop matcher.

Moi giai doan <= khoang 8 file, thay doi rieng, **khong tu commit**. Sau moi giai doan: unsigned Debug/Release Simulator build, `scripts/test_networking.sh`, `scripts/test_localization.sh`, SwiftLint, `xcodebuild test` neu target co, `git diff --check`; bao ket qua that + de xuat mot commit message, **cho chu repo bao da commit**. Fixture dat `FamilyTrackerTests/Fixtures/`; neu target van vang, them source test nhung bao ro XCTest chua chay, khong sua pbxproj bang tay.

| Giai doan | File du kien (tao/sua; tach tiep neu >8) | Tieu chi hoan thanh/test |
| --- | --- | --- |
| PV1a | `Endpoint.swift`, `Endpoints.swift`, DTO privacy moi, `DomainError.swift`, `APIClient.swift` neu can, repository privacy moi, test privacy | Typed 403 paused vs forbidden; GET/PATCH request/response; millis Date; 401 test |
| PV1b | store owner-scoped moi, cache local moi, `AppContainer.swift`, tests | Mot store, startup offline fail-closed, owner switch/logout clear, pausedUntil sync/expiry |
| PV2a | `SocketRealtimeRepository.swift`, `RealtimeDTOs.swift`, mapper realtime, payload DTO moi, `ShareLocationUseCase.swift`, tests | 7 key socket, lower-case ID, fresh fix/reconnect, khong doi throttle, unknown values safe |
| PV2b | `LocationBatchDTOs.swift`, `BufferedLocationPoint.swift`, `LocationBatchRepositoryImpl.swift`, `LocationDeliveryService.swift`, `LocationSyncCoordinator.swift`, tests | Motion, same pointId qua hai transport, 100/100KB, partial success, split/429/500 |
| PV2c | `AppContainer.swift`, `OfflineQueue.swift`, `ShareLocationUseCase.swift`, `LocationDeliveryService.swift`, auth lifecycle, tests | Pause local ngay, cancel race, xoa chi queue-location, khong xoa SOS; SOS when paused; resume fresh fix |
| PV3a | privacy VM/view moi, `ProfileView.swift`, vi/en `.strings`, coordinator/factory, tests | ON/OFF/cho dong bo/loi/confirm, 44pt, VoiceOver, Dynamic Type |
| PV3b | viewer-state Journey/LiveMap VM/view, vi/en `.strings`, tests | Target paused khac forbidden, stale marker co thoi diem, app background/foreground |
| CM1 | `Endpoints.swift`, membership DTO/repo/use cases, `DomainError.swift`, tests | DELETE x2, Bearer, 403/404/409, admin self rule |
| CM2 | `SocketRealtimeRepository.swift`, event DTO, Circle/ChatHub state, `ChatHubCoordinator.swift`, tests | Idempotent cleanup + close chat/watch; direct chat khong tu xoa; two shared Circles |
| CM3 | `GroupDetailView.swift`, `MemberRowView.swift`, coordinator/VM, vi/en `.strings`, tests | Confirm, loading, admin affordance, error UX, navigation |
| JG1a | `HistoryDTOs.swift`, `CoreMappers.swift`, `Journey.swift`, `Endpoints.swift`, contract tests/fixtures | v2 optional, union custom Decodable, includePath=false, all fields mapped |
| JG1b | raw history DTO/endpoint/repository, tests | Range query/cursor/date alias; khong noi UI |
| JG2 | route assembly models/policy moi, `RouteOverlayModel.swift`, pure tests | Runs khong qua gap, validated index, stay quality, 10k points performance |
| JG3 | `RouteMapRenderer.swift`, `JourneyViewModel.swift`, `JourneyView.swift`, vi/en `.strings`, tests | Dashed gaps, sum observed/unobserved, accessibility, legacy neutral |
| JG4 | date formatter/policy moi, `JourneyViewModel.swift`, endpoint, tests | Asia/Ho_Chi_Minh, server TZ mismatch reload 1 lan |
| LT1a | feature config, trail endpoint/DTO/repository, assembler model, tests/fixtures | 503/404/409/429, page merge, typed Int cursor |
| LT1b | trail assembler pure, tests | Revision fence, gap `(fromSeq,toSeq)`, match upsert, path order `(recordedAt,seq)` |
| LT2a | socket trail adapter, watch use case, session readiness wiring, tests | Watch after snapshot/ready, unwatch on hide/background/logout, caps |
| LT2b | trail VM/service, event DTO, tests | Delta/reconnect/reset/closed, bounded reload, no auto rewatch after closed |
| LT3 | `RouteMapView/Renderer`, trail VM/view, vi/en `.strings`, tests | Diff overlays, tail <=1 redraw/s, 4 quality levels + textual labels |
| LT4 | polyline6 decoder/policy, match renderer, local-first self trail, tests | Valid/invalid geometry, provisional->final, pointId reconciliation, no MKDirections |
| LT5 | performance/cancel/privacy tests, `PROGRESS.md`, `AI_RULES.md`, interview notes | Instruments + two real devices; flags off production; docs synchronized |

### Kiểm thử thủ công sau mỗi workstream

- PV: hai may cung tai khoan, pause tren A/B, het han, khong mang/restart, SOS trong luc pause, foreground/background, offline batch + fresh fix khong trung.
- CM: tu roi, admin 409/xoa thanh vien, group chat dang mo bi dong, direct chat khong tu xoa, co chung Circle thu hai.
- JG: 1/10000 diem, gap, stay inferred, ngay khac, mui gio, dark mode/VoiceOver/chu lon.
- LT: staging 503/off/on, late point reset, socket reconnect, match fake staging, raw unmatched, background unwatch, Instruments Energy Log; production mac dinh off.

## Rủi ro và rollback

| Rui ro | Giam thieu / rollback |
| --- | --- |
| Chưa có matcher production; GPS thưa dễ tạo đường thẳng sai | Theo quyết định đã chốt: điểm GPS + nét đứt có nhãn, **không mô tả raw là đường bộ**. Giữ Live Trail off; Journey legacy vẫn đọc được. |
| Pause PATCH that bai nhung app da dung cuc bo | Store `pendingSync`, retry co gioi han, fail-closed; rollback UI khong duoc bat lai emit ma khong hoi server. |
| Thay doi shared `APIClient/DomainError` anh huong chat/auth | Typed location policy test endpoint khac (403 upload/chat), khong doi mapping cu neu khong can; moi change nho/commit rieng. |
| `pointId` UUID hoa-thuong | Canonical lowercase tren wire, giu gia tri trong buffer; test cung fix socket/batch + retry. |
| Watch leaky khi background/leave | Owner lifecycle + unwatch; server lease la fallback, khong phu thuoc lease cho privacy. |
| Source/fixtures chua vao project target | Khong sua pbxproj tay; bao loi test thuc te, can chu repo tao/cau hinh target. |

## Cần tôi quyết định / khóa phạm vi

1. **Đã chốt:** raw trail dùng điểm GPS + nét đứt có nhãn “Vệt GPS chưa khớp đường”; đường đặc chỉ dành cho matched hợp lệ. Không còn chọn marker-only hoặc đường raw đặc. Đây là quy tắc hiển thị mobile, không đổi payload backend.
2. **Đã chốt:** pause chặn gửi tại local trước PATCH; lỗi mạng giữ `pendingSync` và trạng thái dừng, retry có giới hạn, SOS độc lập. Quy tắc này ưu tiên riêng tư hơn trình tự tối thiểu của index/Study, không đổi contract backend.
3. Khi pause: tat GPS tracking han (de xuat) hay tiep tuc thu cuc bo? SOS van lay fix moi on-demand; can kiem tra do tre va quyen background.
4. Thoi han: 1h, 8h, den sang mai, chon toi da 7 ngay, vo thoi han; cong tac o Profile, shortcut Map de task sau? De xuat Profile truoc.
5. Marker cua target dang pause: backend member endpoint khong tra coordinates, nhung local client co marker cu va online presence co the van true. De xuat an marker cu hoac ghi "cap nhat luc ...", khong hien nhu live; can ban chon.
6. Admin: an nut Roi nhom neu biet role (de xuat), 409 van map than thien.
7. Live Trail internal: cờ off production, bat staging sau BE load gate; chua dat moi truong tai may. Can ban xac nhan.
8. Ve local-first cua chinh minh (de xuat); `includePath=false` ngay (de xuat); raw history range DTO-only (de xuat).
9. **Khoa file:** xac nhan i18n/tab Chat/refactor va Location/P7D/P7E co ai dang sua khong; hien Journey F1-F3 dang do, khong duoc de PV/JG de len thay doi do khi chua tach/commit.
10. **Mới cần chốt:** lịch sử matched hằng ngày cần giữ bao lâu? Backend Live Trail mặc định 7 ngày, tối đa cấu hình 30 ngày; snapshot theo `date` đã có. Nếu 7 ngày đủ, dùng endpoint hiện có sau khi backend bật trail/matcher; nếu dài hơn, cần backend điều chỉnh retention hoặc kho lưu dài hạn. `LocationHistory` hiện không giữ matched geometry tương ứng. Chưa chọn mốc retention thay bạn.
11. **Mới cần chốt:** vệt realtime tự động theo quá trình chia sẻ vị trí cả ngày (đề xuất, giống mô tả “đi đến đâu vẽ đến đó”) hay có nút Bắt đầu/Kết thúc một phiên chạy bộ? Phương án phiên riêng thay đổi UX, quyền và mô hình dữ liệu, cần tách task.

## Hỏi Backend (chỉ những gì chưa tự trả lời được)

Da tu giai: member endpoint khong expose last-known coordinate (`groupRepository.MEMBER_FIELDS`); pause khong tat presence; socket validation error `{message,errors}` con policy error `{code,message}` (`locationGateway.js`); watch ack `{ok,status,code,message,errors?}` (`liveTrailGateway.js`); event membership la direct event/payload (`groupUseCases.js`), `removedBy` tu roi bang chinh user; admin hien chua transfer/delete; feature on/off qua REST 503 va flag, khong co discovery endpoint; default TZ va dense flag trong `render.yaml`/`.env.example` **khong chung minh deployment that**.

1. Co event dong bo pause/resume den thiet bi khac cung account, hoac notification khi `pausedUntil` het han khong? Khong thay trong canonical privacy hoac `privacyUseCases.js`; mobile se poll o lifecycle/403 neu khong co.
2. Direct conversation cu cua hai nguoi khong con chung Circle co tiep tuc doc/gui duoc khong? `openDirectConversation` yeu cau shared Circle, nhung can doi chieu `getConversation`/`sendMessage` authorization va backend policy chinh thuc. Mobile tam **giu local direct chat**, khong tu xoa.
3. Backend so sanh `pointId` co phan biet hoa/thieu hoa khong? Mongo unique string la case-sensitive theo mac dinh, nhung can BE xac nhan index/collation production; mobile se luon lowercase.
4. `LOCATION_HISTORY_DENSE_ENABLED` va `LIVE_TRAIL_ENABLED` tren staging/production **thuc te** la gi, va production timezone/co match provider that hay chua? Source chi noi default.

**Dừng tại I0:** hai quyết định trên đã được duyệt, nhưng chưa có xác nhận bộ thay đổi Journey F1-F3 và khóa file. Chỉ bắt đầu PV/JG/LT sau khi chủ repo xác nhận rõ phạm vi được giữ/mở khóa; không sửa backend, không tự commit.
