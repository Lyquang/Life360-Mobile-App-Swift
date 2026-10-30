# SOS và “Tôi sẽ đến ngay”: kế hoạch tích hợp iOS

Ngày kiểm kê: 29/10/2026. Trạng thái: **đã duyệt triển khai; S1 REST xong**, chưa chuyển luồng SOS trên UI.

S2a: đã tạo store pending bền vững và policy retry thuần. Store yêu cầu `activate`
cho mỗi phiên, dùng session UUID để chặn callback cũ khi đổi tài khoản, giữ payload
gốc và báo lỗi khi file hỏng thay vì tự sinh ý định khác. Policy tính mốc Retry-After
và giới hạn số lần thử.

S2b: `SOSIntentRunner` lưu trạng thái chưa chắc chắn trước POST, chia sẻ một flight
giữa các caller, retry tối đa ba lần trong lượt foreground và lưu cooldown. Kết quả
thành công chỉ xóa đúng UUID; lỗi xóa sau commit được báo riêng. Logout/cancel trên
runner chặn áp dụng callback cũ, nhưng runner **chưa được nối** vào logout/UI thật.
Trước S6 phải ràng buộc session generation của request REST ngay tại lần tạo request
đầu tiên: fence trong runner không đảm bảo token không đổi giữa lúc gọi closure và
`APIClient.makeRequest`. Không được nối runner vào UI trước khi có kiểm thử race này.

S3: `SOSSessionController` khôi phục tất cả trang active trước khi áp dụng,
đối soát incident đã cache qua detail, giới hạn một flight/detail, chặn revision cũ,
giữ cooldown read khi 429 và xóa dữ liệu khi 403/404. Test mock có response trễ,
logout, pagination và permission change. Chưa nối UI; cooldown đọc
chưa chia sẻ với thao tác ghi. Backend không cung cấp snapshot token xuyên các trang:
kiểm tra revision/groupIds và thay thế responder khi refresh giảm rủi ro nhưng
không chứng minh quyền bất biến nếu membership thay đổi giữa các request. Phải
refresh lại theo lifecycle và kiểm chứng quyền phía server, không hứa snapshot mạnh.
State `awaitingRefresh` đánh dấu incident chỉ có list hoặc nhận revision mới chưa
được detail xác minh; UI tương lai phải khóa các action cho tới khi cờ được xóa.

S4a: `SOSRealtimeEventAdapter` đăng ký socket handler một lần, chỉ chuyển `eventId`,
`sosId`, revision sang recovery, dedupe event theo session và bỏ event legacy thiếu ID.
`MainTabCoordinator` bắt đầu/đóng session, đối soát REST khi mở app, `session:ready`
và foreground; stop hủy observer/xóa state. Mock kiểm tra event trùng, session cũ,
403, revision và pagination. Đây chưa phải UI SOS mới: banner cũ vẫn nhận legacy
event qua luồng cũ và chưa dedupe theo sosId; nút gửi cũ vẫn dùng Socket. Cần cutover
an toàn và chat/responder UI ở các nhịp sau. Không hứa push khi app bị suspend/kill.

S1 đã build Debug/Release Simulator; mock networking kiểm tra 5 endpoint, response
create/replay/detail/assistance/close, lỗi và UUID giữ nguyên qua 401 → refresh.
Localization và SwiftLint qua với cảnh báo cũ; `xcodebuild test` chưa chạy vì scheme
thiếu Test action. Các response production, tích hợp realtime và UI chưa được xác nhận.

## 1. Nguồn chuẩn và giới hạn kiểm chứng

- Đã đọc toàn bộ `/Users/lyq02/Desktop/Family Tracker Off/Backend/api-docs/SOS_ASSISTANCE_API_DOC.md`.
- Mobile có `CLAUDE.md`, dẫn tới `AI_RULES.md`; không thấy `AGENTS.md` trong repository. Deployment iOS 16, SwiftUI + Combine (`ObservableObject`, `@Published`), MVVM-C, DI qua `AppContainer`.
- Đã đối chiếu hợp đồng với Backend: `src/presentation/http/controllers/sosController.js`, `routes/sosRoutes.js`, `src/presentation/dto/sos.schemas.js`, `src/application/sos/sosUseCases.js`, `sosOutboxDispatcher.js`, `src/application/chat/chatMappers.js` và các assertion trong `tests/sosHttp.test.js`, `tests/sosChatOutbox.test.js`. Đây là kiểm tra nguồn, **không phải kết quả chạy test hoặc response production**.
- `AppEnvironment.production` đã đúng: REST `https://life360-backend-6v9n.onrender.com/api/v1`, Socket cùng origin không có `/api/v1`. Giữ cấu hình này, không hard-code host tại feature.
- Người dùng đã xác nhận ngày 29/10/2026: production bật `SOS_API_ENABLED=true`, `SOS_OUTBOX_ENABLED=true` và MongoDB hỗ trợ transaction/replica set. Đây là xác nhận cấu hình từ người dùng; chưa gọi API hay phát SOS thử, chưa kiểm chứng response/delivery runtime.
- Backend source xác nhận hai flag mặc định false, và cấu hình API bật yêu cầu outbox bật. Giá trị trong source/local không chứng minh môi trường Render đã bật.
- `FamilyTrackerTests` có file Swift nhưng chưa có target trong `project.pbxproj`; scheme có thẻ `TestAction` rỗng. Không tự sửa pbxproj. Kiểm tra lại lúc triển khai, báo riêng nếu XCTest vẫn không chạy được.

## 2. Hiện trạng và gap analysis

| Phần            | Đã có trong Mobile                                                                                                | Cần thay đổi                                                                                         |
| --------------- | ----------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| Tạo SOS         | `SOSUseCases.swift`: `SendSOSUseCase` dùng `lastKnownLocation` và battery, gọi `SocketRealtimeRepository.sendSOS` | REST-only; UUID bền vững; không tự dùng tọa độ cache; body không có battery                          |
| UX gửi          | `EmergencyCoordinator.confirmSOS` đặt `isSending`, kết thúc bằng timer 3 giây                                     | Thành công chỉ sau response 200/201 hợp lệ; phân biệt lỗi và chưa xác định kết quả                   |
| Offline         | `OfflineQueue` thực tế đã lưu JSON trên đĩa; `drain()` xóa trước emit; flush cả lúc connected và session:ready    | Không đưa SOS mới vào queue socket; có migration xử lý SOS legacy, không phát lại ngoài REST         |
| Cảnh báo        | `SOSAlertDTO` bỏ qua `eventId/sosId/revision/status/location`; `SOSAlert.id` là UUID mới mỗi decode               | Identity theo incident/event Backend; nhận nullable location và trạng thái                           |
| Cập nhật        | Chỉ nghe `sos_alert`; chưa có `sos:updated`                                                                       | Invalidation → GET detail; chống stale response và coalesce reload                                   |
| Chi tiết/hỗ trợ | Chưa có REST SOS, responders, resolve/cancel                                                                      | Bổ sung repository, use cases, state và màn detail                                                   |
| Chat            | `ChatMessageDTO`/Domain chưa có `sos`; mapper bỏ metadata                                                         | Optional `sos {id,kind,responderId?}`, optional `eventId`; cả REST history và realtime               |
| Chat dedupe     | Chat room kiểm `message.id`; ChatHub có seen IDs nhưng clear-all khi vượt 500                                     | Giữ dedupe theo message.id; bounded eviction thay vì reset toàn bộ khi chạm trần                     |
| Auth            | APIClient Bearer + `TokenRefreshCoordinator` single-flight; rotation reconnect socket                             | Dùng nguyên cơ chế chung; bảo vệ SOS bằng session generation                                         |
| Rate limit      | `sendWithMetadata` giữ `APIError.rateLimited(retryAfter:)`; `send` thường chỉ trả HTTP error                      | SOS dùng `sendWithMetadata`, map lỗi theo feature trước generic `withDomainErrors` làm mất ngữ nghĩa |
| Location pause  | `requestFreshLocation` và callback của `CLLocationService` đều guard `isRunning`                                  | One-shot riêng cho SOS chủ động, không resume chia sẻ vị trí nền                                     |
| Notification    | `RealtimeNotificationBridge` phát local notification khi nhận socket lúc app không active; deep link theo userId  | Dedupe cùng nguồn SOS; route detail theo sosId; không hứa push/đánh thức app                         |
| Logging         | Pulse dùng `DiagnosticRedactor` cho HTTP/socket, che token và tọa độ kể cả object lồng                            | Test regression với payload SOS mới, không thêm log raw; lỗi UI theo key vi/en                       |

`SocketClient.on` hiện không có API remove listener; handlers sống qua reconnect. Đề xuất một event adapter sống cùng AppContainer, đăng ký đúng một lần bằng weak closure. Session/UI subscribe AsyncStream có hủy; không đăng ký lại socket handler mỗi lần mở view/login.

## 3. Contract phải giữ chính xác

| Endpoint (sau prefix `/api/v1`) | Request                                                                                                 | Decode `data`                                                      |
| ------------------------------- | ------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------ |
| POST `/sos`                     | UUID `clientRequestId`, message optional ≤500, cặp lat/lon optional, `recordedAt` ISO chỉ khi có tọa độ | `{created, incident: SOSSummary}`; 201 mới, 200 replay             |
| GET `/sos`                      | `status=active`, `limit` 1–100, `cursor=nextCursor`                                                     | `{items:[SOSIncident],hasMore,nextCursor}`                         |
| GET `/sos/{id}`                 | `limit` 1–100, `afterId=nextAfterId`                                                                    | `{incident,responders,hasMore,nextAfterId}`                        |
| POST `/sos/{id}/responses`      | Chỉ `{status:"coming"}`                                                                                 | `{created,sosId,revision,response}`; response không có name/avatar |
| PATCH `/sos/{id}`               | Chỉ `{status:"resolved"}` hoặc `{status:"cancelled"}`                                                   | `{changed,incident:SOSSummary}`; summary có closedAt               |

- Tái sử dụng `APIResponseDTO<T>`, không tạo envelope song song. Tách `SOSSummaryDTO` với `SOSIncidentDTO`; không ép summary có message/location/groupIds.
- Detail/list chứa ownerId nhưng **không có owner name/avatar**. UI lấy tên đã biết từ member/chat context, nếu thiếu dùng tên dự phòng đã dịch; không invent endpoint lấy profile.
- `location`, `closedAt`, responder name/avatar có thể null; response hỗ trợ không có profile. Không dùng tọa độ 0,0 làm mặc định.
- DTO có thể giữ ISO String như mẫu Backend rồi map bằng `ISO8601.date(from:)`; nếu dùng Date phải qua decoder chung. `recordedAt` request phải encode ISO String rõ ràng vì `Endpoint.encodedBody` dùng JSONEncoder mặc định, không mặc nhiên dùng `BackendJSONCoding.makeEncoder()`.
- List incident theo ID giảm dần; responder theo ID tăng dần. Không dùng chung biến cursor hoặc trộn với cursor chat `before`.
- Chat SOS vẫn là `type:"text"`; `sos.kind` phân biệt alert/assistance. Backend mapper tạo `responderId` từ senderId cho assistance. Không thêm `ChatMessageType.sos`, không suy luận card bằng cách tìm chữ “SOS” trong content.
- Số group/recipient là audience snapshot, không phải số người đã nhận hoặc đã đọc.
- Status lạ tương lai: hiển thị trạng thái chưa hỗ trợ, khóa thao tác; không tự hiểu là active. `expired` đọc được nhưng Backend chưa có job tự hết hạn.

## 4. Kiến trúc đề xuất

```text
SOS View / Chat card
  -> SOS ViewModel (@MainActor)
  -> SOS use cases / session state (@MainActor)
  -> SOSIncidentRepository (Domain port)
  -> SOSIncidentRepositoryImpl -> APIClient -> shared token refresh

SocketClient (đăng ký một lần)
  -> SOS event adapter -> session state -> GET detail -> ViewModel
  -> ChatRepositoryImpl -> ChatMessage.sos -> Chat card

EmergencyCoordinator: trình bày banner/list/detail và mở bản đồ
AppContainer: tạo dependencies, owner/session boundary, lifecycle cleanup
```

Domain chứa entity, port và policy thuần; Data chứa DTO, mapping, REST repository, pending store. Core chứa one-shot CoreLocation riêng. Coordinator giữ điều hướng; View không gọi API/socket/location.

Giữ `SOSRepository` legacy trong các nhịp đầu để build được. Chuyển toàn bộ UI sang REST trong một nhịp cutover, đồng thời tắt đường emit/flush SOS cũ. Không để production có nút gọi cả hai đường ghi.

## 5. Luồng giao diện

Giữ nút SOS hiện có trên Map; thêm danh sách SOS hiện hành bên trong luồng Emergency (không thêm tab). Bấm SOS khi đã có incident của mình sẽ mở incident đó; khi có nhiều cảnh báo, banner mở danh sách/detail, không mất incident cũ chỉ vì banner mới đến.

```text
Xác nhận SOS
  Tin nhắn (tùy chọn)
  [Gửi kèm vị trí hiện tại] / [Gửi không kèm vị trí]
  [Gửi SOS]  [Quay lại]

Đang xử lý
  Đang lấy vị trí / Đang gửi
  Nếu hết thời gian: Chưa xác nhận gửi thành công [Thử lại]

SOS của tôi (detail)
  Đã gửi yêu cầu | Đang hoạt động
  Người xác nhận sẽ đến:
    B — Tôi sẽ đến ngay
    [Tải thêm người hỗ trợ]
  [Tôi đã an toàn] [Hủy SOS]

SOS từ thành viên (banner/card/detail)
  A cần hỗ trợ | vị trí nếu được cấp quyền xem
  [Tôi sẽ đến ngay] [Xem chi tiết] [Xem vị trí nếu có]
  Sau commit: Bạn đã xác nhận sẽ đến

SOS đã đóng: Đã an toàn / Đã hủy / Đã hết hạn
  Lưu nội dung lịch sử, không còn nút nhận hỗ trợ/đóng lần nữa
```

Banner đóng chỉ là đóng UI, không đồng nghĩa cancel SOS. Không tự mở lại popup sau khi restore; active incident nằm trong danh sách. Nút gửi lại tắt khi operation đang chạy/cooldown. Nút hỗ trợ ẩn với owner và incident không active. Thông tin `coming` là lời xác nhận, không phải tracking đang di chuyển hay ETA.

Chat card có metadata lấy từ server, có điểm vào detail qua ChatHubCoordinator → MainTabCoordinator → EmergencyCoordinator. Chưa xác minh detail thì không khẳng định incident vẫn active từ tin chat lịch sử; có thể hiện nút “Xem SOS”, rồi cho hỗ trợ sau GET. Không GET một lần cho mỗi bubble: dùng cache chung và coalesce theo sosId.

UI vi/en, vùng bấm ≥44pt, Dynamic Type, VoiceOver, Reduce Motion. Không thêm còi/critical alert ngoài phạm vi này. Local notification chỉ best-effort khi process nhận được socket; không bảo đảm delivery khi app bị suspend/terminated.

## 6. Idempotency, lưu pending và vị trí chủ động

### Ý định SOS

- Khi người dùng xác nhận một ý định: sinh UUID đúng một lần và persist **trước POST**. Nếu lưu lỗi, báo lỗi không giả đã gửi.
- Pending record gồm ownerId/session scope, UUID, payload đã chốt, trạng thái, số lần thử, notBefore. OwnerId chỉ dùng local để phân vùng; không nằm trong body REST.
- Retry giữ UUID **và payload** (message/location/recordedAt); không lấy lại GPS rồi thay payload của UUID cũ. Backend replay không cập nhật nội dung.
- Đề xuất file atomic trong Application Support, excluded from backup, file protection; chỉ một pending create/tài khoản. Clear khi logout, hết phiên hoặc owner đổi. Cache incident/responders chỉ RAM và phục hồi REST, tránh lưu thêm tọa độ lâu dài.
- 200/201 replay có thể trả incident đã đóng: áp dụng status server, không hiển thị active theo giả định.
- 409 tạo: list active và mở incident owner; không tạo UUID liên tục. Nếu không tìm thấy, giữ trạng thái cần đối soát; danh sách không có clientRequestId nên **không thể chứng minh cùng ý định** bằng message/coordinate.
- Timeout sau POST: chưa biết commit hay chưa. GET/list giúp phục hồi; replay cùng UUID mới là cơ chế idempotency chắc chắn. Không đánh dấu failed như thể chắc chắn server chưa nhận.

### GPS

Đề xuất service one-shot riêng (`SOSLocationProvider`) bằng CLLocationManager, chỉ khởi động sau khi người dùng chọn gửi kèm vị trí. Không dùng `deviceLocation.lastKnownLocation`, không gọi `startTracking` và không mở lại chia sẻ nền. Timestamp dùng từ fix thực; bỏ fix invalid/stale so với thời điểm bắt đầu one-shot. Hủy delegate/request đúng lifecycle; timeout đề xuất 8 giây, không retry GPS vô hạn.

Mất quyền/timeout: hiển thị lựa chọn gửi không kèm vị trí. Không tự đưa cache vào request. Mở banner, đọc history, nhận hỗ trợ, đóng SOS đều không cần lấy vị trí của người đang thao tác.

### Queue cũ

Phải ngăn SOS legacy trong `OfflineQueue` bị phát khi reconnect hoặc restore. Đề xuất loại các item `sos_alert` cũ trước lần connect đầu và trong flush; không chuyển chúng thành REST tự động vì không có UUID/owner/consent đáng tin cậy. Không xóa các loại item khác. Quyết định này cần duyệt vì có thể bỏ một SOS chưa gửi từ phiên bản cũ.

## 7. Realtime, revision, pagination và phục hồi

- Dedupe theo `eventId` cho SOS event; popup theo `sosId`; chat theo `message.id` kể cả cùng incident có tin ở nhiều Circle. Không dùng sosId để bỏ các tin chat hợp lệ của những conversation khác nhau.
- Cache dedupe hữu hạn theo phiên, có eviction theo thứ tự thay vì clear-all. Popup đã thấy trong phiên không bật lại; restore list sau relaunch không tự popup hàng loạt.
- `sos:updated` là invalidation: lưu highest target revision và gọi GET detail, không tự thêm responder dựa trên event. Một flight/detail, gom event khoảng 250 ms; nếu revision mới xuất hiện khi flight đang chạy thì chạy thêm một lần sau đó.
- Snapshot revision nhỏ hơn cache/target không được ghi đè. Create/close summary chỉ cập nhật phần summary, không xóa message/location/responders do không có các field đó.
- Revision bằng nhau vẫn có thể khác quyền/profile. Chỉ nhận response của lần refresh/session còn hiệu lực; một refresh quyền mới phải thay danh sách responder được phép xem, không union vĩnh viễn. 403/404 xóa cache/camera target và khóa UI; response cũ đang bay không được hồi sinh incident vừa bị revoke.
- Pagination responders: cache phân trang gắn revision và refresh generation. Nếu revision đổi giữa các trang, tải lại trang đầu; không ghép mù các snapshot khác revision. Responder dedupe theo response.id/responderId. Không khẳng định “chưa hỗ trợ” chỉ vì không thấy mình ở trang đầu.
- `session:ready`, foreground authenticated và startup sau restore kích hoạt reconciliation single-flight. REST vẫn dùng được khi socket chưa ready; không chặn nút tạo REST vì socket mất kết nối.
- Reconciliation: lấy hết list active bằng `nextCursor`; GET lại mọi incident đang cache để tìm closed/403/404. Không xóa chỉ vì không có trong một trang. Nếu pagination lỗi hoặc 429, giữ state chưa xác minh và continuation; không coi partial list là complete.
- List/detail giới hạn concurrency đề xuất 2, debounce trigger; ưu tiên detail đang mở/operation cần đối soát. Cursor lặp/hasMore không có cursor là lỗi contract, dừng tránh loop.
- Logout/đổi account: tăng generation trước khi cancel tasks, clear pending/cache/dedupe, đóng UI/notification route SOS. Kết quả network/GPS cũ bị bỏ cả khi cancellation đến trễ. Callback transport sống lâu nhưng chỉ chuyển dữ liệu vào session hiện hành sau readiness fence; detail xác thực lại quyền trước thao tác.

## 8. Bảng lỗi và retry

SOS mapping riêng giữ HTTP status/code/notBefore; không đổi nghĩa lỗi của các feature khác.

| Lỗi              | Hành vi                                                                                                                                    |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| 400              | Lỗi payload/no Circle/self-assistance; không retry y nguyên; thông báo localized, giữ chi tiết kỹ thuật đã redacted khi debug              |
| 401              | Shared refresh single-flight, retry request một lần bởi APIClient với cùng UUID; hết phiên thì cleanup; không dựng refresh riêng           |
| 403              | Dừng retry, xóa incident/responders không còn quyền; đóng trạng thái hỗ trợ/định vị                                                        |
| 404              | Bỏ cache/card actionable và báo không còn SOS; tin text chat lịch sử vẫn theo quyền chat                                                   |
| 409              | GET/list đối soát; không reopen, không đổi UUID tự động; close khác terminal state hiển thị trạng thái server                              |
| 413              | Báo nội dung quá lớn, không retry body cũ                                                                                                  |
| 429              | Lấy Retry-After từ `sendWithMetadata`; mốc thử tiếp ≥ header + jitter không âm, dùng chung cooldown SOS cho read/write                     |
| 503              | Chưa xác nhận thành công; giữ payload/UUID để người dùng thử lại. Không kết luận chỉ do flag: có thể transaction/capacity/chat unavailable |
| 500/mất response | Retry hữu hạn cùng operation; trạng thái unknown nếu chưa đối soát được; không tự thông báo đã gửi                                         |

Đề xuất tối đa 3 HTTP attempt cho một lượt SOS (không tính 1 retry refresh nội bộ); clock/sleeper/random được inject để test. Sau khi background/hủy UI, không duy trì vòng retry nền. Retry-After dài >60s: lưu notBefore, kết thúc lượt thay vì giữ task sleep; trước deadline nút retry cũng không bypass. Header thiếu/hỏng: exponential backoff có jitter, không loop.

`TokenRefreshCoordinator` đã giữ cooldown của refresh; APIClient có thể trả rateLimited(nil) khi refresh bị 429. Không coi nil là có thể refresh ngay; dựa gate chung hiện có và backoff SOS hữu hạn.

## 9. Execution plan sau duyệt

Chia nhịp nhỏ, mỗi nhịp build được. Người dùng duyệt ngày 29/10/2026: khoảng 10–12 file hoặc một phần chức năng để review. Không commit/push tự động. Các nhịp UI thêm key vi/en cùng thay đổi; dừng báo cáo sau từng phần. S1 chưa nối vào DI/nút SOS, chưa tạo SOS thật trên production.

| Nhịp                          | File tạo/sửa chính                                                                                                                                                                                                                                                          | Hoàn thành và kiểm tra                                                                                                    |
| ----------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| S1 – Contract REST            | Mới `Domain/Entities/SOSIncident.swift`, `Domain/Repositories/SOSIncidentRepository.swift`, `Data/Network/DTOs/SOSDTOs.swift`, `Data/Network/Endpoints/SOSEndpoint.swift`, `Data/Repositories/SOSIncidentRepositoryImpl.swift`, `FamilyTrackerTests/SOSContractTests.swift` | 5 endpoints/body strict/query riêng; fixtures từ doc/source; 201/200 replay, null/date/error mapping; chưa thay UI        |
| S2 – Pending/retry            | Mới `Data/Local/SOS/SOSPendingIntentStore.swift`, `Domain/UseCases/SOS/SOSRetryPolicy.swift`, `SOSIntentUseCase.swift`, tests tương ứng                                                                                                                                     | Persist-before-send, UUID/payload không đổi, clock giả, 429/timeout, logout/file hỏng; chưa nối nút                       |
| S3 – State/REST recovery      | Mới `SOSSessionController.swift` (Application service ở `Data/Services`), port state/use cases và tests                                                                                                                                                                     | Single-flight, revision fence, responders pagination, list full scan, permission revocation, generation; model độc lập UI |
| S4a – Events                  | Sửa `SocketEvent.swift`, `RealtimeDTOs.swift`, `Alerts.swift`, `ChatRealtimeMappers.swift`; thêm SOS event adapter + tests                                                                                                                                                  | Decode alert/update, dedupe, đăng ký một lần, legacy thiếu sosId là cảnh báo chưa persist không có action coming          |
| S4b – Chat metadata           | Sửa `ChatDTOs.swift`, `Chat.swift`, `ChatRealtimeMappers.swift`, `ChatRepositoryImpl.swift`, dedupe ChatHub nếu cần; tests                                                                                                                                                  | Optional metadata/default nil giữ initializer cũ; history và realtime nhất quán; không gửi thêm text SOS                  |
| S5 – GPS chủ động             | Mới port/provider one-shot + tests                                                                                                                                                                                                                                          | Không đọc cache, không bật tracking nền; pause/denied/timeout/cancel và measured timestamp                                |
| S6a – Session wiring          | Sửa `AppContainer.swift`, `MainTabCoordinator.swift`, `FamilyTrackerApp.swift`; tests lifecycle                                                                                                                                                                             | Start/ready/foreground recovery, cleanup explicit logout/onExpired/owner change, stale result ignored                     |
| S6b – REST cutover            | Sửa `SOSUseCases.swift`, `EmergencyCoordinator.swift`, `SocketRealtimeRepository.swift`, `OfflineQueue.swift`; tests regression và L10n nếu có text                                                                                                                         | Nút dùng REST duy nhất; bỏ timer giả thành công; không emit/flush SOS legacy. Backend vẫn là nơi tạo chat                 |
| S7a – State màn hình          | Mới `SOSViewModel.swift`, tests; hoàn thiện factory và intents coordinator                                                                                                                                                                                                  | Sending/unknown/active/closed/no-access, operation locks, responders load-more                                            |
| S7b – Banner/detail           | Mới `SOSDetailView.swift`; sửa `SOSAlertBanner.swift`, `EmergencyCoordinator.swift`, vi/en; tests/Preview                                                                                                                                                                   | Nút coming, safe/cancel, list người hỗ trợ, Dynamic Type; lấy trạng thái từ shared model                                  |
| S7c – Chat route/notification | Sửa `ChatView.swift`, `ChatHubCoordinator.swift`, `MainTabCoordinator.swift`, `RealtimeNotificationBridge.swift`, notification deeplink và vi/en; tách nếu vượt trần                                                                                                        | Card mở đúng incident, không popup trùng; best-effort local route sosId, không hứa APNs                                   |
| S8 – Đối chiếu thật và chốt   | Tests, study doc, `PROGRESS.md`, networking/localization fixtures/scripts nếu cần                                                                                                                                                                                           | Backend gate xác nhận; test 2 thiết bị, fixtures response thực đã ẩn dữ liệu; rollback/checklist                          |

Tại mỗi nhịp có Swift: build Simulator Debug/Release không ký, networking/localization scripts, SwiftLint, `git diff --check`; chạy XCTest khi target khả dụng. Nếu target chưa có: để test trong `FamilyTrackerTests`, báo chưa chạy, không coi syntax parse là unit test pass. Không tạo target bằng sửa pbxproj thủ công.

## 10. Test bắt buộc

### Unit / mock URLProtocol (không gọi Backend)

- Create 201 và replay 200 decode summary; close summary không có message/location; detail nullable location/profile; dates có/không milliseconds.
- Payload không có userId/ownerId/batteryLevel; nil location bỏ cả hai tọa độ và recordedAt; message trim/limit.
- Một ý định nhiều tap/timeouts/relaunch giữ UUID + payload; intent mới chỉ khi hợp lệ; file persistence lỗi không báo đã gửi.
- 401 song song dùng một refresh chung; logout trong refresh/request không áp kết quả vào tài khoản mới.
- 429 giữ Retry-After, dài không giữ sleep background; 400/403/404/409/413/503 không thành công giả; 500 retry hữu hạn.
- Event trùng/out-of-order; revision 3 tới trước 2; event trong lúc GET; stale summary không ghi đè detail; equal revision nhưng membership thay đổi không giữ responder trái quyền.
- Phân trang cursor vs afterId, hai trang responders, revision đổi giữa trang, cursor lặp và incomplete list không xóa cache.
- Chat cùng message.id không tăng badge/append hai lần; cùng sosId ở hai Circle vẫn có hai message hợp lệ. Không có lời gọi sendText/chat:send_message khi create/coming/close.
- Stop/logout/account switch hủy listener task/GPS/retry và xóa pending, rồi callback cũ không resurrect state.
- Chủ động SOS khi pause: one-shot độc lập, không resume/batch/emit tracking; open card và coming không gọi GPS.
- Pulse/redactor che token và nested location; kiểm thử state/L10n không cần đưa tọa độ thực vào log.

### Integration sau khi xác nhận Backend

1. Xác nhận ba điều kiện deploy, dùng tài khoản/Circle thử được phép. Không đăng token hoặc Mongo URI lên chat/log.
2. GET list authenticated kiểm tra status/body thật. 401 không chứng minh feature đã bật; 200 không tự chứng minh worker đang delivery.
3. A tạo: REST 201, Backend tạo chat; B chỉ một popup dù chung nhiều Circle. Retry UUID → 200 và không tăng tin.
4. B coming → A nhận update, detail thấy B; retry không tăng response/chat; nhiều thiết bị cùng B vẫn idempotent.
5. A resolved/cancelled; B mới respond →409; B đã commit replay có thể200, UI vẫn GET và thấy closed.
6. B offline khi A tạo/đóng, mở lại/reconnect phục hồi REST; không đòi replay mọi event.
7. Người lạ/new member/leave group/owner leave, 403 và privacy cleanup. Mất mạng/refresh race/relaunch pending.
8. Pause location, denied permission, gửi không tọa độ; background/terminated không được quảng bá là có push.
9. Nếu 503: ghi chính xác method/path, HTTP status, code và message đã kiểm tra không có secret/tọa độ; giữ UI chưa xác nhận. Không fabricate response hoặc tự suy ra nguyên nhân duy nhất.

## 11. Localization dự kiến

| Key                         | vi                                                             | en                                                              |
| --------------------------- | -------------------------------------------------------------- | --------------------------------------------------------------- |
| `sos.incidents.title`       | Yêu cầu SOS                                                    | SOS requests                                                    |
| `sos.send.with_location`    | Gửi kèm vị trí hiện tại                                        | Include current location                                        |
| `sos.send.without_location` | Gửi không kèm vị trí                                           | Send without location                                           |
| `sos.state.sending`         | Đang gửi yêu cầu SOS…                                          | Sending SOS request…                                            |
| `sos.state.committed`       | Đã gửi yêu cầu                                                 | Request sent                                                    |
| `sos.state.unknown`         | Chưa xác nhận gửi thành công. Thử lại sẽ dùng cùng yêu cầu.    | Sending is not confirmed. Retrying will reuse this request.     |
| `sos.action.coming`         | Tôi sẽ đến ngay                                                | I'm on my way                                                   |
| `sos.state.coming`          | Bạn đã xác nhận sẽ đến                                         | You confirmed you're on your way                                |
| `sos.action.resolve`        | Tôi đã an toàn                                                 | I'm safe now                                                    |
| `sos.action.cancel`         | Hủy SOS                                                        | Cancel SOS                                                      |
| `sos.responders.title`      | Người xác nhận hỗ trợ                                          | People offering help                                            |
| `sos.responders.empty`      | Chưa có người xác nhận hỗ trợ                                  | No one has confirmed help yet                                   |
| `sos.responders.more`       | Tải thêm người hỗ trợ                                          | Load more helpers                                               |
| `sos.state.resolved`        | Đã an toàn                                                     | Resolved                                                        |
| `sos.state.cancelled`       | Đã hủy                                                         | Cancelled                                                       |
| `sos.state.expired`         | Đã hết hạn                                                     | Expired                                                         |
| `sos.error.unavailable`     | SOS tạm thời chưa khả dụng. Chưa xác nhận yêu cầu đã được gửi. | SOS is temporarily unavailable. Sending has not been confirmed. |
| `sos.error.access`          | Bạn không còn quyền xem SOS này                                | You can no longer view this SOS                                 |
| `sos.error.rate_limit`      | Vui lòng chờ trước khi thử lại                                 | Please wait before retrying                                     |

Tên người, nội dung do người dùng/Backend tạo giữ nguyên. Các nhãn trạng thái và action do app sở hữu được dịch. Kiểm tra câu unknown/unavailable (dài nhất), tên có dấu/tên dài, VoiceOver và cỡ chữ lớn; không hard-code số count dạng singular/plural.

## 12. Cần người dùng quyết định khi duyệt

1. **Backend readiness — đã xác nhận:** người dùng xác nhận đủ hai flag và transaction ngày 29/10/2026. Sau duyệt kế hoạch mới kiểm chứng API/delivery thực tế; xác nhận cấu hình không thay thế kiểm thử end-to-end.
2. **Vị trí:** đề xuất lựa chọn rõ ràng “kèm vị trí hiện tại” hoặc “không kèm vị trí”; timeout one-shot 8 giây, sau đó hỏi gửi không vị trí. Trade-off: thêm thao tác nhưng không âm thầm dùng cache hoặc trì hoãn SOS vô hạn.
3. **Pending sau relaunch/offline lâu:** đề xuất phục hồi state và để người dùng bấm tiếp tục cùng UUID, không tự tạo SOS nhiều giờ sau. Retry trong lượt foreground đang chủ động tối đa 3 lần. Persist chỉ ý định chưa xác nhận; không tự hết hạn/xóa UUID mơ hồ khiến retry tạo trùng.
4. **SOS legacy đã nằm trong OfflineQueue:** đề xuất loại bỏ có chọn lọc và thông báo cục bộ rằng cần gửi lại chủ động; không tự replay hoặc chuyển sang REST. Cần chấp nhận trade-off mất pending cũ để tránh phát SOS muộn/khác tài khoản.
5. **UI:** đề xuất banner + detail/list trong Emergency, chat card mở cùng detail; không thêm tab. Giữ nút Map SOS làm điểm vào và hiển thị SOS đang có thay vì tạo cái mới.

## 13. Rollback

Rollback bằng revert từng thay đổi đã review. Sau cutover, nếu Backend lỗi thì hiển thị lỗi/không khả dụng, **không tự fallback tạo SOS bằng Socket**. Không sửa Backend và không bật flag server từ Mobile. Source location/chat/auth ngoài ranh giới tích hợp giữ nguyên; không xóa tin chat Backend đã lưu khi xóa cache UI.
