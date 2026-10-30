# Yêu cầu Backend: chia sẻ vị trí realtime tạm thời cho SOS

Trạng thái: **đề xuất hợp đồng, chưa có API được xác nhận hoặc triển khai**. Không sử dụng các endpoint minh họa như API đã tồn tại. Mobile đã được yêu cầu chỉ kích hoạt sau khi người gửi xác nhận rõ ràng.

## Bài toán và hiện trạng đã kiểm chứng

- Người A gửi SOS; khi A đồng ý chia sẻ liên tục, B trong Circle được phép theo dõi vị trí mới và vệt di chuyển trong thời gian SOS còn hiệu lực.
- `GET/PATCH /api/v1/privacy/location-sharing` là cài đặt **toàn tài khoản**. Khi tạm dừng, `update_location`, batch và quyền xem lịch sử/vệt thông thường bị chặn. Đổi `enabled=true` mở chia sẻ thông thường cho toàn bộ Circle được phép; backend chưa có TTL bật chia sẻ, phiên bản để compare-and-set, hay quyền tạm theo SOS.
- `SOS_ASSISTANCE_API_DOC.md` hiện chỉ mô tả vị trí một lần trong SOS. `update_location` không có ack. Chưa có APNs/FCM để bảo đảm thông báo khi app bị dừng.
- Vì vậy không dùng PATCH bật/tắt toàn tài khoản làm cách giả lập chia sẻ SOS: app có thể bị kill, nhiều thiết bị đổi trạng thái, hoặc việc khôi phục ghi đè lựa chọn mới.

## Mục tiêu hợp đồng

1. Một quyền chia sẻ tạm (*lease*) gắn với **SOS đang active** và người tạo SOS, có sự đồng ý rõ ràng. Không thay đổi `privacy/location-sharing` thông thường; khi lease hết hiệu lực, cài đặt trước và mọi thay đổi mới của người dùng vẫn giữ nguyên.
2. Server xác thực JWT, kiểm tra owner, trạng thái SOS và quyền hiện hành của người nhận. Chỉ người trong Circle có quyền liên quan SOS mới được nhận; quyền phải được kiểm tra lại khi người dùng rời/bị xóa khỏi Circle. Đề nghị BE xác định rõ quy tắc giao giữa snapshot lúc tạo SOS và membership hiện tại, bao gồm trường hợp hai người còn một Circle chung khác.
3. Server tự hết hạn theo giờ server ngay cả khi app bị kill, logout hoặc mất mạng. Đóng/hủy SOS, chủ động thu hồi quyền hoặc hết hạn phải dừng việc nhận điểm mới và quyền xem SOS tạm. Đồng bộ nhiều thiết bị và nhiều instance backend; kiểm tra hạn/quyền tại thời điểm xử lý, không dựa vào job dọn TTL Mongo để thực thi quyền.
4. Tái sử dụng một bộ thu GPS và một kết nối Socket.IO. Chia sẻ SOS không được âm thầm mở luồng thường cho các Circle ngoài phạm vi. Không gửi lại các điểm đã thu khi user đang pause trước thời điểm đồng ý.

## API đề xuất — BE quyết định tên và xuất hợp đồng chính thức

Tất cả thao tác dùng Bearer; identity lấy từ JWT. Date ISO-8601 UTC có mili giây. Ví dụ chỉ là đề xuất, không phải response thật.

### Tạo hoặc khôi phục lease

`POST /api/v1/sos/{sosId}/location-sharing`

```json
{ "clientRequestId": "<UUID-cua-y-dinh-chia-se>", "durationSeconds": 3600 }
```

- Chỉ owner của SOS active; giới hạn thời gian do BE công bố, ví dụ một giờ chỉ là giả thuyết. Response trả `leaseId`, `sosId`, `status`, `expiresAt`, `serverTime`, `revision` và phạm vi người nhận dưới dạng chính sách, không lộ danh tính không cần thiết.
- UUID phải idempotent theo owner/SOS và payload: timeout/retry cùng UUID không tạo lease khác hoặc vô tình kéo dài thời hạn. Định nghĩa rõ conflict khi cùng UUID khác payload; nhiều thiết bị xác nhận đồng thời không tạo hai trạng thái mâu thuẫn.
- Cần xác định SOS create và lease tạo tuần tự hay một transaction. Nếu SOS đã tạo nhưng lease thất bại, SOS vẫn có hiệu lực; response/UI phải báo *chưa chia sẻ liên tục*, không khẳng định người hỗ trợ nhìn thấy realtime.

### Kiểm tra và thu hồi

- `GET /api/v1/sos/{sosId}/location-sharing`: phục hồi trạng thái và thời hạn cho owner và người xem có quyền; không cấp quyền xem chỉ vì đoán được ID.
- `DELETE /api/v1/sos/{sosId}/location-sharing`: owner thu hồi, idempotent; trả trạng thái và revision. SOS có thể tiếp tục active nhưng không chia sẻ vị trí liên tục.
- Khi PATCH SOS đóng/hủy, đóng lease theo cách nhất quán với transaction/outbox. Phát sự kiện `sos:location-sharing-updated` gồm `eventId`, `sosId`, `revision`, `status`, `expiresAt` tới người có quyền và các thiết bị owner. Cho biết hành vi khi quyền/TTL thay đổi, khi reconnect và khi event trùng/đến sai thứ tự.
- Nếu có gia hạn: yêu cầu thao tác xác nhận riêng hoặc quy tắc được mô tả rõ, idempotent, có trần thời gian; không tự gia hạn vô hạn.

## Gửi và nhận tọa độ

Đề xuất **mở rộng** `update_location` với `sosId`/`leaseId` khi chia sẻ SOS; BE xác nhận chính xác JSON, validation và version tương thích. Điểm gồm latitude, longitude, `recordedAt`, accuracy hợp lệ và battery nếu được phép. Server phải xác định owner từ socket token, kiểm tra lease/SOS active và hạn tại mỗi lần xử lý; không tin ID hay phạm vi do client tự khai.

- Định nghĩa đường phát riêng theo audience SOS, không broadcast điểm SOS tạm lên Circle room thông thường khi privacy chung đang pause. Nếu privacy chung đang bật, làm rõ chống nhân đôi event và quyền xem theo từng mục đích.
- Đề nghị event nhận có `eventId`, `sosId`, `ownerId`, `recordedAt`, tọa độ và `revision`/thứ tự đủ để bỏ điểm cũ; định nghĩa rõ trường hợp gửi tới nhiều thiết bị và reconnect. Không báo người khác đã nhận khi chỉ emit. Cho mobile biết có ack hay không; nếu không, không xem emit là xác nhận server lưu.
- Muốn có vệt: cung cấp endpoint/watch có **scope SOS**, ví dụ `GET /api/v1/sos/{sosId}/location-trail` + socket delta, cursor/revision và cơ chế đối soát khi reconnect. Chỉ trả điểm thuộc khoảng thời gian lease được đồng ý và người xem còn quyền; tránh cho phép đọc toàn bộ lịch sử bình thường chỉ bằng lease SOS. Làm rõ TTL/xóa dữ liệu, có lưu Mongo/Redis, giới hạn điểm và thứ tự.
- Offline: xác nhận rõ có hỗ trợ batch SOS và schema nhận `pointId`, `recordedAt`, lease/sosId, `accepted`/`duplicates`/`rejected` theo từng điểm; chỉ chấp nhận điểm được đo khi lease còn hợp lệ theo quy tắc server công bố và không phát lại điểm cũ thành realtime. Nếu chưa hỗ trợ, mobile không tự gắn các điểm SOS vào batch thông thường.

## Lỗi, giới hạn và bảo mật

- `400` validation; `401` refresh chung; `403` không có quyền/lease hết hạn hoặc bị thu hồi với mã máy đọc được; `404` SOS không tồn tại/không thể truy cập theo chính sách; `409` SOS đóng, xung đột idempotency hoặc revision; `429` kèm `Retry-After`; `503` tính năng/tài nguyên không sẵn sàng. BE xác nhận mã chính xác và envelope.
- Áp dụng rate limit, giới hạn thời gian và số điểm, không log tọa độ, token hay nội dung SOS. Lưu/truyền bảo mật; ghi tài liệu retention, xóa sau hết hạn và quyền sau khi thành viên rời nhóm. Redis/cache và Mongo phải tuân cùng scope quyền.
- Không cam kết định vị liên tục khi iOS không có quyền, bị hệ điều hành dừng hoặc mất mạng. Cần trạng thái mất kết nối và thời điểm đo cuối ở mobile; SOS và vị trí one-shot vẫn hoạt động khi chưa tạo được lease.
- APNs/FCM là hạng mục backend riêng nếu muốn cảnh báo khi app background/terminated; không coi Socket.IO hay local notification là push.

## Kiểm thử nghiệm thu đề nghị Backend

1. Pause thông thường → đồng ý SOS: chỉ audience hợp lệ nhận điểm SOS, người ngoài không xem được; privacy thường vẫn pause.
2. SOS đóng/hủy, chủ thu hồi, lease hết hạn, app kill, logout, server restart: lease không còn hiệu lực sau mốc/quyết định tương ứng, không phụ thuộc job TTL.
3. Đổi cài đặt privacy ở thiết bị khác trong lúc SOS active: kết thúc lease không ghi đè cài đặt mới; test các race create/close/revoke/expiry và nhiều instance.
4. Rời/bị xóa khỏi Circle, các Circle chung chồng lấn, nhiều thiết bị, reconnect và event trùng/đảo thứ tự: quyền và revision đúng.
5. Timeout POST → retry cùng UUID; replay khi lease/SOS đã đóng; conflict khác payload; không tạo trùng hoặc gia hạn ngoài ý muốn.
6. Điểm sai, timestamp tương lai/cũ, điểm trước consent/sau hết hạn, batch gửi lại và quota; không lộ tọa độ trong log.
7. Contract test có JSON ví dụ cho từng response, lỗi, socket payload, quyền xem và pagination. Backend xác nhận API đã deploy, feature flag và cách kiểm tra trên môi trường test trước khi Mobile nối.

## Việc Mobile sau khi nhận hợp đồng

Thêm lựa chọn xác nhận vi/en nêu phạm vi và thời hạn; tạo/khôi phục/thu hồi lease có UUID bền vững; chặn gửi đến khi server xác nhận; kết nối `LocationSharingGate` và delivery theo scope mới; dừng khi hết hạn, đóng, đổi tài khoản hoặc mất quyền; hiển thị trạng thái rõ ràng và timestamp thật. Có test clock giả, lỗi mạng/401/403/409/429/503, idempotency và race lifecycle; test hai iPhone. Không thay đổi payload/endpoint theo ví dụ trên cho đến khi BE xác nhận.
