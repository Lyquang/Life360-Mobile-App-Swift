# FamilyTracker: từ React Native đến Junior iOS Engineer

Ngày đối chiếu mã: 05/10/2026. Mục tiêu: giải thích được cơ chế, bảo vệ được quyết định thiết kế, chứng minh bằng test hoặc phép đo. Không chỉ kể tên framework.

## Điểm xuất phát và cách sử dụng

Bạn không bắt đầu lại nghề mobile từ đầu. Kinh nghiệm TypeScript, UI state, API, debugging và release vẫn hữu ích. Phần cần xây thêm là ownership/lifetime, isolation, native lifecycle và giới hạn thực thi của iOS.

Lộ trình gợi ý: 6 tuần, 10-12 giờ/tuần. Mỗi buổi: 25 phút học cơ chế, 60 phút thực hành, 20 phút test/ghi bằng chứng, 15 phút giải thích thành lời. Điều chỉnh theo tiến độ, không coi 6 tuần là cam kết thành thạo.

Các bài tập và STAR dưới đây là đề xuất, không phải thay đổi đã triển khai. Chỉ dùng thì quá khứ khi chính bạn đã thực hiện và kiểm chứng. Phiên này chỉ đọc mã/tài liệu và viết hướng dẫn, không chạy benchmark hay xác nhận leak bằng Instruments.

### Những gì repo thực sự có

| Bằng chứng trong repo | Có thể trình bày | Không nên khẳng định |
| --- | --- | --- |
| `project.yml`: deployment iOS 16, Swift language mode 5 | Có ràng buộc tương thích hệ điều hành | Đã bật Swift 6 strict concurrency toàn bộ; language mode không phải phiên bản compiler |
| `Presentation/Scenes/LiveMap/Map/LiveMapViewModel.swift` | `@MainActor`, `ObservableObject`, `@Published`, nhận stream | App hiện dùng `@Observable` |
| `Core/Location/AdaptiveLocationPolicy.swift` | Chính sách theo motion và pin, stationary dùng significant-change | Đã giảm pin X% nếu chưa đo |
| `Data/Network/APIClient.swift` | URLSession async, Bearer, HTTP/envelope errors, cancellation | Đã có refresh-token flow hoàn chỉnh |
| `Data/Repositories/SocketRealtimeRepository.swift` | Nhận/gửi realtime, tích hợp queue | Reconnect bảo đảm không mất sự kiện |
| `Data/Local/OfflineQueue/OfflineQueue.swift` | Lưu hàng đợi ra file, gộp location mới nhất | Đã lưu toàn bộ hành trình offline và bảo đảm gửi thành công |

Các đường dẫn trong bảng tính từ `FamilyTracker/`, trừ `project.yml`. Những phân tích mã bên dưới là suy luận tĩnh, không phải kết quả đo hiệu năng.

## Phần 1. Cầu nối React Native sang Swift

### 1. State management: tách ownership, observation và injection

| React Native/TypeScript | SwiftUI | Khác biệt cần nhớ |
| --- | --- | --- |
| `useState` | `@State` | State gắn với identity/lifetime của view, không phải mỗi lần tạo lại struct |
| Props và callback cập nhật | Giá trị truyền vào và `@Binding` | Binding là đường đọc/ghi tới nguồn state, không phải bản sao độc lập |
| Store Zustand/Redux | Một model/store được observe | Không có ánh xạ một-một; SwiftUI không tự cung cấp reducer/middleware/time travel |
| Context Provider | `@Environment` / `@EnvironmentObject` | Cấp dependency theo cây view, không đồng nghĩa singleton toàn app |
| Selector | Đọc property được Observation theo dõi | Không mang nguyên mô hình selector Redux sang SwiftUI |

Repo iOS 16: `@StateObject` khi view tạo và sở hữu `ObservableObject`; `@ObservedObject` khi nhận model từ bên ngoài; `@EnvironmentObject` cho model được inject. `@Published` phát thay đổi qua Combine.

Với Observation trên iOS 17+: `@Observable` làm model có thể được theo dõi; `@State` giữ model do view sở hữu; `@Bindable` tạo binding; `@Environment(Model.self)` nhận model. Observation theo dõi property được đọc khi tính `body`. Không tự migrate repo chỉ để dùng cú pháp mới. [Apple: Discover Observation](https://developer.apple.com/videos/play/wwdc2023/10149/)

**Bài tập FamilyTracker:** phân loại `selectedMemberID` là state màn hình, phiên đăng nhập là shared state, tọa độ server là dữ liệu bên ngoài. Quyết định owner của từng loại trước khi chọn property wrapper. Thử push/pop map: model nên sống theo màn hình hay theo phiên tracking?

**Cách nói:** “Em tách ai sở hữu state, ai quan sát và ai được quyền sửa. Em dùng cơ chế phù hợp deployment target, không xem Environment là nơi chứa mọi thứ.”

### 2. Reconciliation và SwiftUI dependency graph

React so sánh cây element và identity/key để quyết định cập nhật. SwiftUI cũng khai báo UI theo state, nhưng không phải React Virtual DOM viết bằng Swift. `View` struct là giá trị mô tả UI; SwiftUI quản lý identity, lifetime và dependency để quyết định tính lại phần liên quan. Tính lại `body` không đồng nghĩa dựng lại toàn bộ UI nền. [Apple: Demystify SwiftUI](https://developer.apple.com/videos/play/wwdc2021/10022/)

Áp dụng trên map: `userId` phải là identity ổn định. Nếu tạo UUID mới cho annotation mỗi lần nhận tọa độ, framework có thể coi đó là xóa/thêm thay vì cập nhật. Không đặt decode JSON, sort lớn hoặc tạo formatter đắt đỏ trong `body`. Đo hitch và công việc main thread, không chỉ đếm số lần `body` chạy. [Apple: SwiftUI performance](https://developer.apple.com/videos/play/wwdc2023/10160/)

**Bài tập:** mở `LiveMapViewModel.upsert`; hiện mỗi event tìm tuyến tính và sửa array được publish. Sinh dữ liệu thử nhiều thành viên, so sánh với cache theo ID và publication theo batch. Đừng kết luận O(n) là nguyên nhân lag khi chưa profile; nhóm ít người có thể không đáng tối ưu lookup.

### 3. Event loop không tương đương actor

JS event loop lên lịch callback/job trên JS runtime; CPU-heavy JavaScript vẫn có thể chặn xử lý tiếp theo. Cần phân biệt RN legacy bridge với New Architecture: JSI/Fabric/TurboModules không còn mô hình mọi tương tác đều serialize qua JSON bridge. [React Native: New Architecture](https://reactnative.dev/architecture/landing-page)

Trong Swift: task là đơn vị công việc, thread là tài nguyên thực thi, actor là ranh giới isolation. `await` cho phép tạm ngưng, không bảo đảm tạo thread mới. `Task {}` có thể kế thừa actor context; `@MainActor` dành cho UI state. Actor có thể xử lý việc khác lúc một hàm đang `await`, vì vậy phải kiểm tra lại giả định sau điểm suspend. `Sendable` diễn đạt khả năng truyền giá trị an toàn qua isolation boundary, không tự thêm lock. [Swift: Concurrency](https://github.com/swiftlang/swift-book/blob/main/TSPL.docc/LanguageGuide/Concurrency.md)

**Ví dụ sát app:** tải lịch sử circle A, người dùng chuyển B, response A về muộn. Không có data race vẫn có thể hiển thị sai circle. Lưu request generation/circle ID, cancel request cũ và kiểm tra identity trước khi publish. Đây là logic race, không chữa chỉ bằng `@MainActor`.

**Bẫy:** bọc sort/decode nặng trong `Task {}` bên trong MainActor không tự chuyển việc đó ra background. Chọn isolation/executor rõ ràng theo toolchain; không dùng `Task.detached` như cách tắt cảnh báo compiler. Dữ liệu chuyển đi phải phù hợp `Sendable`, và phải tự quản lý cancellation nếu dùng unstructured task.

### 4. Garbage collection và ARC

GC của JS dựa vào khả năng truy cập từ roots; một vòng tham chiếu không còn reachable có thể được thu hồi. Listener vẫn được một global emitter giữ sẽ vẫn sống: JS cũng có memory leak. [MDN: Memory management](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Memory_management)

Swift ARC quản lý lifetime của class instance qua strong references. `strong` giữ sống; `weak` không giữ sống và về `nil` khi object bị giải phóng; `unowned` không giữ sống nhưng yêu cầu object vẫn tồn tại lúc truy cập, nếu không có thể crash. Hai object/closure giữ strong lẫn nhau có thể không được giải phóng. [Swift: ARC](https://github.com/swiftlang/swift-book/blob/main/TSPL.docc/LanguageGuide/AutomaticReferenceCounting.md)

Compiler sinh các thao tác retain/release cần thiết và có thể tối ưu chúng. Khi không còn strong owner, instance được deinitialize rồi giải phóng; ARC không định kỳ quét toàn bộ đồ thị để tìm cycle như tracing GC. Ví dụ màn hình đã bỏ ViewModel nhưng closure trong socket singleton vẫn giữ nó, strong count chưa về 0. `deinit` không phải sự kiện “màn hình vừa đóng”.

**Cách suy luận:** vẽ `ViewModel -> listener/token -> closure -> ViewModel`. Tìm cạnh nào thể hiện ownership thực, cạnh nào chỉ quan sát. Thay cạnh quan sát bằng weak khi đúng lifetime; đồng thời hủy subscription/task. Không dùng weak khắp nơi: một thao tác hữu hạn có thể cần giữ owner tới khi hoàn tất. Không dùng unowned cho socket callback chỉ vì không muốn viết optional.

## Phần 2. Lộ trình thực hành 6 tuần

### Tuần 1. Swift, mô hình dữ liệu và DSA

**Kiến thức cần nắm:** struct/enum có value semantics; class có reference semantics và identity. `let` trên class reference không làm mọi property của object bất biến. Struct chứa class vẫn có thể chia sẻ object đó. Không nói “struct luôn stack, class luôn heap”: vị trí lưu là chi tiết triển khai/tối ưu. `Array` có copy-on-write, không nhất thiết sao chép toàn bộ buffer ngay khi gán. [Swift: Structures and Classes](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/classesandstructures/)

**Bài tập thiết kế:** dùng value model `CoordinateSample` gồm memberID, coordinate, capturedAt, accuracy; dùng class/actor cho service có identity/lifecycle. Tạo enum state `idle`, `loading`, `loaded([Sample])`, `failed(AppError)` để tránh tổ hợp vô nghĩa như vừa loading vừa error. Mô hình refresh giữ dữ liệu cũ riêng, đừng ép mọi màn hình vào một enum quá đơn giản.

```swift
// Minh họa associated values: payload gắn với từng trường hợp hợp lệ.
enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(message: String)
}
```

Khác enum raw-value dùng để ánh xạ hằng số, associated values mang dữ liệu theo từng instance/case. `switch` exhaustive buộc xử lý đủ các trạng thái; ở app thật dùng lỗi typed thay vì để message string thay thế toàn bộ error model.

**DSA gắn dự án:**

| Bài | Cấu trúc và độ phức tạp cần giải thích | Test cần có |
| --- | --- | --- |
| Upsert vị trí thành viên | Array lookup O(n); Dictionary trung bình O(1), không bảo đảm worst-case O(1) | Trùng ID, sai circle, event cũ tới sau |
| Dedupe trang chat | Set ID trung bình O(1)/item; giữ thứ tự hiển thị riêng | Hai trang overlap, message realtime chen vào |
| Queue offline có giới hạn | Ring buffer/deque tránh dịch toàn array mỗi lần bỏ đầu | Overflow, TTL, thứ tự, ưu tiên SOS |
| Stay-point detection | Sliding window theo thời gian; phân tích cả chi phí tính lại khoảng cách | GPS jitter, gap dài, outlier, đổi ngày/time zone |

Không tuyên bố sliding window luôn O(n): nếu mỗi bước quét lại toàn cửa sổ k phần tử thì có thể O(nk). Nêu tiêu chí định nghĩa “stay”: thời gian tối thiểu, bán kính, chất lượng fix và cách xử lý khoảng trống.

**Đầu ra:** unit tests cho mô hình/state và hai bài DSA; giải thích được chi phí thời gian/bộ nhớ. **Câu nói:** “Em chọn struct cho snapshot dữ liệu; service cần identity và quản lý tài nguyên nên có reference lifetime rõ ràng.”

### Tuần 2. OOP, POP, MVVM-C và UIKit/runtime

OOP vẫn quan trọng: encapsulation bảo vệ invariant; polymorphism cho phép thay implementation; ưu tiên composition khi không có quan hệ kế thừa thật. POP không phải tạo protocol cho mọi class. Đặt protocol tại ranh giới thay thế/test, ví dụ `LiveLocationRepository`; implementation thật và fake cùng đáp ứng contract.

Protocol extension cung cấp hành vi mặc định. Phân biệt requirement khai báo trong protocol với method chỉ có trong extension: khi gọi qua protocol abstraction, cách chọn implementation có thể khác. Làm một ví dụ nhỏ trước khi nói “Swift dispatch tất cả bằng vtable”. [Swift: Protocols](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/protocols/)

Luồng đúng để giải thích app:

```text
View --intent--> ViewModel --> UseCase --> Repository protocol
                                                ^
                                                | implements
                                        Data repository --> Core service

View/ViewModel --navigation intent--> Coordinator --> route / sheet / deep link
AppContainer: lắp ghép concrete dependencies ở composition root
```

Coordinator không phải trạm bắt buộc cho mọi request nghiệp vụ. Dependency trong Clean Architecture hướng về abstraction của Domain; runtime vẫn gọi implementation do DI cung cấp. Sơ đồ tuyến tính ở đầu `AI_RULES.md` cần được hiểu cùng các quy tắc chi tiết, không dùng để biện minh cho việc đưa mọi UseCase qua Coordinator.

Gắn pattern vào vấn đề: Strategy cho accuracy policy; Adapter cho Socket.IO/CoreLocation; Repository tách nguồn dữ liệu; Observer/AsyncSequence cho realtime; Coordinator cho navigation; DI cho test. Không tăng số lớp chỉ để có đủ tên pattern.

**UIKit và runtime cần luyện:** tạo một màn hình phụ UIKit bằng `UIViewController`, Auto Layout, table/collection view reuse, delegate; hiểu `viewDidLoad` khác `viewWillAppear` và state SwiftUI. Bọc UIKit bằng `UIViewRepresentable` khi cần, không tạo lại native view tùy tiện trong update. Coordinator của representable là bridge delegate, không tự động là app navigation Coordinator.

Objective-C runtime gửi message qua selector; Swift có các cơ chế dispatch khác nhau. `@objc` expose thành phần tương thích sang runtime; `@objc dynamic` dùng dynamic dispatch qua runtime khi cần. `NSObject`, target-action, delegate và KVO là các điểm gặp thực tế; enum associated values không tự bridge nguyên dạng sang Objective-C. Biết vai trò bridging header và generated Swift header; không cần swizzling để chứng minh năng lực Junior. [Apple: Objective-C runtime in Swift](https://developer.apple.com/documentation/swift/using-objective-c-runtime-features-in-swift)

**Đầu ra:** fake repository test ViewModel không cần backend; demo UIKit nhỏ; một sơ đồ dependency. **Câu nói:** “Domain không biết URLSession hay MapKit. DTO mapping ở Data; UI formatting ở ViewModel; navigation do Coordinator sở hữu.”

### Tuần 3. ARC, task lifetime và kiểm chứng bằng công cụ

**Bài lab memory:** mở/đóng Chat hoặc LiveMap 20 lần, sau đó logout/login. Ghi số ViewModel, listener và task còn sống. Dùng Xcode Memory Graph truy incoming references của instance đã rời màn hình; dùng Instruments Allocations so sánh generations, Leaks bổ sung kiểm tra. Bộ nhớ tăng không tự chứng minh leak: cache có thể giữ dữ liệu hợp lệ. [Apple: Gathering memory information](https://developer.apple.com/documentation/xcode/gathering-information-about-memory-use)

**Bẫy cần tự tái hiện:**

```swift
// Minh họa rủi ro lifetime, không phải bản vá cho repo.
task = Task { [weak self] in
    guard let self else { return }
    for await value in stream {
        self.consume(value)
    }
}
```

`guard let self` trước vòng lặp giữ strong reference trong suốt vòng lặp. Nếu stream không kết thúc và chỉ trông chờ `deinit` để cancel, owner có thể không đạt tới deinit. Đặt lifecycle `start/stop` rõ; tránh giữ self xuyên thời gian chờ không cần thiết; đóng/unregister producer khi subscriber kết thúc. Weak capture không thay cho cancellation.

**Bài đọc mã:** `ShareLocationUseCase` đã có stop/cancel. Tuy nhiên `try? await Task.sleep` nuốt cancellation rồi còn đi tiếp tới `handle`. Viết test stop đúng lúc đang sleep; yêu cầu không phát thêm location sau stop. Đây là rủi ro từ luồng mã, chưa phải bug đã tái hiện trên máy thật.

**Concurrency lab:** hai task gọi cập nhật cùng cache; actor hóa phần mutable state, rồi tạo tình huống một hàm await giữa read/write để thấy reentrancy. Bật kiểm tra concurrency theo từng phạm vi; không rải `@unchecked Sendable` để build xanh.

**Đầu ra:** ảnh graph đường giữ object trước/sau nếu tái hiện được; test lifecycle idempotent; assertion không nhân listener sau reconnect. **Câu nói:** “Em chứng minh lifetime bằng reference graph và số instance, không chỉ thêm weak self rồi kết luận hết leak.”

### Tuần 4. REST, URLSession, Keychain và lỗi phiên đăng nhập

Pipeline nên giải thích được: Endpoint -> URLRequest -> token/header -> transport -> HTTP/envelope validation -> DTO decode -> Domain mapping -> UI state. URLSession async trả Data/URLResponse; response HTTP 401/500 phải được app kiểm tra, không mặc định trở thành transport error. Hủy tác vụ khác lỗi mạng cần báo cho người dùng. [Apple: URLSession async/await](https://developer.apple.com/videos/play/wwdc2021/10095/)

**Đối chiếu repo:** `URLSessionAPIClient.send` đã có pipeline tương tự, lấy token từ `AccessTokenProvider`, kiểm tra `requiresAuth`, xử lý HTTP/envelope và `CancellationError`. Không viết thêm APIClient trong ViewModel hoặc View. Request public bị 401 không nên tự xóa phiên đang có.

**Bài tập test với URLProtocol stub:** 200 hợp lệ, 200 sai schema, 204 không body nếu contract có endpoint đó, 401/403, HTML từ proxy, timeout, cancellation, response cũ sau login mới. Kiểm tra headers và query encoding, không gọi backend thật cho unit test.

**Token an toàn:** Keychain là nơi lưu secret, nhưng không giải quyết mọi race. Đọc token T1 để gửi request, user đăng nhập ra T2, response 401 của T1 về muộn: không được xóa T2. Repo truyền `sentToken` vào invalidate; cần kiểm tra read/compare/delete có được serialize nguyên khối không. Thiết kế session generation hoặc actor/lock bảo vệ toàn bộ thao tác, không chỉ riêng từng Keychain call.

Không log token/password hoặc tọa độ nhạy cảm ra log chia sẻ. Backend mới quyết định có refresh endpoint hay không. Nếu có: single-flight refresh, chặn retry vô hạn, invalidate đúng phiên, phối hợp reconnect socket. Nếu chưa có: xử lý hết phiên và đăng nhập lại, không tự phát minh contract.

**Ownership lab:** định nghĩa bảng lỗi transport/HTTP/decoding/domain; UI giữ dữ liệu cũ khi refresh lỗi, có retry hợp lệ. Không biến cancellation lúc rời màn hình thành banner “mất mạng”. **Đầu ra:** contract tests và sequence diagram stale-401. **Câu nói:** “Em kiểm tra status và business envelope riêng; retry phụ thuộc idempotency, không lặp mọi POST.”

### Tuần 5. Socket, reconnect, backpressure và offline

WebSocket là transport hai chiều; Socket.IO bổ sung protocol riêng, event/namespace/ack trên Engine.IO. `URLSessionWebSocketTask` không thay trực tiếp Socket.IO client. Heartbeat Ping/Pong phát hiện kết nối chết, không xác nhận một location hay SOS đã được xử lý. [Socket.IO: How it works](https://socket.io/docs/v4/how-it-works/)

Reconnect khôi phục kết nối, không tự bảo đảm mọi event đã tới. Muốn retry đáng tin cần event ID, ack, persistence và dedupe phía server. Không mặc định API `retries` trong tài liệu JavaScript tồn tại tương đương ở Swift SDK. [Socket.IO: Delivery guarantees](https://socket.io/docs/v4/delivery-guarantees/)

**State machine bài tập:** `disconnected -> connecting -> authenticating/joining -> ready -> reconnecting`. Transport connected chưa chắc app session/room đã sẵn sàng. Repo flush ở cả connected và session-ready; xác minh contract rồi chỉ flush tại trạng thái đủ điều kiện. Dùng exponential backoff có jitter và giới hạn; không tạo reconnect loop thứ hai cạnh SDK. Network path available chỉ là gợi ý, không chứng minh server reachable.

**Phân biệt 3 loại dữ liệu:**

| Loại | Chính sách gợi ý | Lý do |
| --- | --- | --- |
| Live position | Coalesce theo user/circle, giữ mới nhất, kèm thời điểm đo | UI cần trạng thái mới, không cần phát lại mọi frame |
| Journey/history | Lưu mẫu theo thời gian, batch, dedupe event ID | Gộp hết thành điểm cuối sẽ mất hành trình |
| SOS | Ack nghiệp vụ, trạng thái pending/failed, TTL và cảnh báo rõ | Không được hiển thị đã gửi chỉ vì gọi emit |

**Lab hàng đợi đáng tin:** đọc bản ghi nhưng chưa xóa; gửi ID ổn định; server dedupe và trả ack theo contract; chỉ xóa sau ack. Mất ack có thể gửi trùng, nên cần at-least-once + idempotency. Thử kill app trước gửi, sau server nhận nhưng trước ack, sau ack trước local delete. Scope queue theo tài khoản và quy định khi logout, tránh replay dữ liệu của người A dưới token B.

**Lab backpressure:** `AsyncBroadcaster` hiện dùng AsyncStream mặc định không giới hạn buffer. Sinh producer nhanh hơn consumer, theo dõi backlog/memory. Giới hạn buffer theo semantics: map có thể giữ mới nhất theo từng member; `.bufferingNewest(1)` trên stream trộn nhiều member sẽ làm mất cập nhật người khác. Bounded buffer chỉ giới hạn tích lũy, không tự khiến producer chậm lại.

**Đầu ra:** test disconnect/reconnect/readiness, duplicate delivery, queue restart, overflow. **Câu nói:** “Em tách connection state khỏi delivery state và live snapshot khỏi durable history. UI không hứa độ tin cậy mà backend chưa bảo đảm.”

### Tuần 6. Background, pin, CPU và quyền riêng tư

CoreLocation nhận location qua callback, không phải app cứ “ping GPS” là có fix chính xác. Accuracy cao/thời gian tracking dài và network wakeups đều có chi phí; chọn accuracy vừa đủ, dừng hoặc giảm tracking khi phù hợp. Significant-change không phải timer hay bộ lấy mẫu đúng mỗi N mét. [Apple: Location energy practices](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/EnergyGuide-iOS/LocationBestPractices.html)

App background có thể bị suspend. Không hứa Timer/Task.sleep hoặc socket chạy liên tục theo chu kỳ 30 giây; background capability không phải quyền chạy vô hạn. Cần thiết kế theo authorization, lifecycle và cơ chế location hệ thống cho phép. [Apple: Background location](https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background)

**Policy đã có:** stationary dùng significant-change; walking/running accuracy 10m, distance filter 20m; automotive dùng best-for-navigation, filter 50m. Low Power Mode hoặc pin dưới 20% làm giảm accuracy và tăng filter. Đây là chính sách cấu hình, không phải độ chính xác/nhịp callback được hệ thống bảo đảm.

**Bài nâng cấp:** CoreMotion bị từ chối/không hỗ trợ hoặc trạng thái unknown phải có fallback. Thêm hysteresis/thời gian ổn định trước đổi chế độ để tránh stationary/moving dao động liên tục. Review liệu automotive có thực sự cần best-for-navigation cho sản phẩm chia sẻ gia đình. Nhận mẫu GPS cần kiểm tra timestamp, horizontalAccuracy và outlier, không chỉ lat/lng.

**Phân biệt ba nhịp:** thu thập location, gửi lên server, publish UI. `ShareLocationUseCase` hiện gửi khi đi >=50m HOẶC đã >=30 giây, không phải đồng thời cả hai. Heartbeat đọc lastKnownLocation không chứng minh có GPS fix mới; cần giữ capturedAt và biểu diễn stale location. Không đổi thời điểm gửi thành thời điểm đo để làm vị trí cũ trông mới.

**Computer architecture gắn bài toán:** array truy cập liên tiếp thường có locality tốt; object graph/dictionary có thêm indirection và chi phí allocation. ARC retain/release, copy buffer, JSON decode và context switching không miễn phí. Async I/O giảm thời gian thread bị chặn, không làm phép tính CPU miễn phí. Nếu CPU giữ main thread bận, UI trễ; deadline khung hình khoảng 16.7ms ở 60Hz và 8.3ms ở 120Hz là ngân sách tổng, không dành hết cho code app.

**Lab thiết bị thật:** cùng tuyến đi, thời lượng, thiết bị, brightness/network và build cấu hình; so stationary/walking/automotive, bật/tắt Low Power, lock screen, revoke permission, reduced accuracy, mất mạng. Ghi số callback, số request, CPU time, hitch và energy metrics mà toolchain cung cấp. Mức pin thô bị nhiễu và Simulator không chứng minh tiết kiệm GPS battery; lặp phép đo trước khi nêu phần trăm.

**Ownership:** người dùng phải biết đang chia sẻ với ai, vị trí mới tới đâu và cách dừng. Không coi app demo là hệ thống cứu hộ bảo đảm. Nếu SOS chưa được server xác nhận, thể hiện pending/failed và phương án liên lạc khác phù hợp sản phẩm, không âm thầm báo thành công.

**Đầu ra:** bảng policy/permission, test matrix thiết bị thật, trace trước/sau có điều kiện đo. **Câu nói:** “Em tối ưu freshness, độ chính xác và năng lượng theo mục tiêu sản phẩm, không cố giữ GPS/socket chạy mãi.”

## Phần 3. Mười câu hỏi phỏng vấn tình huống và STAR

### Cách trả lời trong 90-120 giây

S (Situation): bối cảnh và tín hiệu cụ thể. T (Task): trách nhiệm của bạn và tiêu chí đạt. A (Action): giả thuyết, bằng chứng, quyết định và trade-off. R (Result): test/trace/số đo thực tế và giới hạn còn lại. Dành nhiều thời gian nhất cho A; nhà tuyển dụng cần thấy cách suy luận, không chỉ kết quả.

Mọi R bên dưới là **bằng chứng cần thu thập**, không phải kết quả đã đạt. Khi chưa làm: nói “Trong repo hiện có X; em phát hiện rủi ro Y qua đọc mã; em sẽ kiểm chứng bằng Z”, không nói “em đã xử lý triệt để”.

### 1. Map lag khi nhiều tọa độ tới cùng lúc. Em bắt đầu từ đâu?

- **S:** replay một luồng nhiều member làm thao tác map chậm; phân biệt dữ liệu mô phỏng với traffic thật.
- **T:** giữ vị trí mới nhất từng người, không làm mất tương tác hay hiển thị nhầm circle.
- **A:** profile main thread/allocations và event rate; kiểm tra `upsert` O(n), publish array từng event, identity annotation, decoding và camera update. Chỉ sau đó chọn cache ID, coalesce từng member, batch UI và xử lý event lỗi thời. Lưu timestamp/sequence theo contract.
- **R:** so p95 thời gian xử lý, hitch và độ trễ hiển thị trên cùng workload; test không bỏ quên member ít gửi. Điền số thật và thiết bị, không tự viết “giảm 80%”.
- **Hỏi xoáy:** tại sao không debounce tất cả? Vì stream liên tục có thể bị trì hoãn mãi; live state thường cần throttle/coalesce với giới hạn freshness.

### 2. Đóng Chat rồi mở lại, tin nhắn nhận hai lần và RAM tăng. Có phải retain cycle?

- **S:** số callback tăng sau mỗi lần mở, memory tăng là triệu chứng chứ chưa kết luận nguyên nhân.
- **T:** mỗi owner có đúng một subscription hợp lệ; màn hình rời đi phải được giải phóng khi không còn owner.
- **A:** đếm listener/task, log deinit ở debug, truy Memory Graph; tách duplicate registration khỏi retain cycle. Với cycle thật, sửa capture/ownership; thêm unregister token và stop idempotent. Kiểm tra task giữ self xuyên vòng lặp.
- **R:** 20 vòng mở/đóng không tăng subscription; instance màn hình cũ biến mất; allocation plateau sau warm-up. Chấp nhận cache hợp lệ thay vì đòi RAM về đúng số ban đầu.
- **Hỏi xoáy:** vì sao weak self chưa đủ? Nó không tự unregister listener, kết thúc stream hoặc hủy tài nguyên đang hoạt động.

### 3. User mất mạng 15 phút khi di chuyển. Khôi phục hành trình thế nào?

- **S:** queue hiện coalesce location thành bản mới nhất, nên không thể khôi phục đầy đủ lịch sử từ queue đó.
- **T:** xác định yêu cầu là live position hay route history; yêu cầu lưu toàn route cần contract/storage khác.
- **A:** tách snapshot và history; lưu capturedAt, accuracy, eventID và account scope; batch khi ready, ack rồi delete, dedupe server; giới hạn TTL/dung lượng và báo lỗi lưu.
- **R:** test restart và mất mạng giữa gửi/ack không mất bản ghi đã commit local; phát lại không tạo duplicate business records nếu server hỗ trợ idempotency. Ghi rõ giới hạn lấy mẫu/thời gian background.
- **Hỏi xoáy:** xóa sau emit được không? Không; emit chỉ là hành động phía client, chưa chứng minh server nhận và lưu.

### 4. Request cũ nhận 401 đúng lúc người dùng vừa login lại. Xử lý sao?

- **S:** request dùng T1 đang chạy, login mới lưu T2 rồi 401 của T1 quay về.
- **T:** không xóa phiên mới hoặc tự đưa user ra login sai.
- **A:** gắn session generation/sent token vào request; compare-and-invalidate atomic trong session owner; kiểm tra session trước khi áp kết quả. Phối hợp reset socket/queue đúng tài khoản. Refresh chỉ khi backend hỗ trợ.
- **R:** test ép thứ tự hoàn thành T2 trước 401 T1, T2 vẫn tồn tại; nhiều request hết phiên chỉ tạo một quyết định logout/refresh hợp lệ.
- **Hỏi xoáy:** actor có tự giải quyết không? Không nếu read/compare/write bị tách qua await hoặc trạng thái được sửa ngoài owner.

### 5. App “connected” nhưng người trong circle không nhận tọa độ. Em debug gì?

- **S:** transport báo connected nhưng room/auth chưa ready, hoặc server đã từ chối payload.
- **T:** tìm điểm đứt bằng correlation/event ID và không báo delivery thành công sai.
- **A:** kiểm tra deployed host, path, TLS, token, namespace/event schema, sequence auth/join/ready và ack. Repo flush ở connected lẫn session-ready là điểm cần xác minh. Dùng log đã redact; không log token đầy đủ.
- **R:** integration test trì hoãn ready, queue vẫn giữ nguyên; ready rồi mới gửi; lỗi auth dẫn tới state có thể phục hồi.
- **Hỏi xoáy:** ping/pong thành công có chứng minh SOS đã tới? Không, heartbeat không phải application acknowledgement.

### 6. Điện thoại nóng và tụt pin khi đứng yên. Em thay đổi gì?

- **S:** đo thấy tracking/network vẫn hoạt động nhiều khi stationary; không đoán mọi lỗi do GPS.
- **T:** giảm công việc nền trong khi vẫn giữ mức freshness sản phẩm chấp nhận.
- **A:** kiểm tra motion classification, accuracy/filter, frequency gửi, reconnect storm và UI work. Repo đã có stationary/low-power policy; kiểm chứng service thực sự áp dụng. Thêm fallback/hysteresis và tách nhịp capture/send nếu cần.
- **R:** trace cùng kịch bản trước/sau cho callback/request/CPU và energy; chứng minh chuyển moving phục hồi tracking đúng. Không cam kết tick 30 giây lúc suspend.
- **Hỏi xoáy:** significant-change có thay được mọi continuous tracking không? Không; đây là đánh đổi độ chi tiết/freshness, phụ thuộc yêu cầu hành trình.

### 7. Vì sao model vị trí dùng struct, nhưng service lại class hoặc actor?

- **S:** nhiều màn hình cần snapshot vị trí, còn socket cần một vòng đời kết nối có owner.
- **T:** tránh vô tình chia sẻ mutable state và tránh tạo nhiều connection ngoài ý muốn.
- **A:** dùng struct cho dữ liệu value; class cho identity/lifecycle; actor khi mutable state cần isolation. Protocol tại repository boundary để inject fake. Giải thích struct chứa reference không bảo đảm deep copy, Sendable không tự suy ra từ tên struct.
- **R:** test mutate bản sao snapshot không làm đổi nguồn đối với model value thuần; fake kiểm chứng use case không cần network; lifecycle test số connection.
- **Hỏi xoáy:** dùng singleton cho tất cả có đơn giản hơn? Có thể ít wiring nhưng làm mờ lifetime, shared state và test isolation; DI cho phép một instance dùng chung mà không global hóa.

### 8. User mở lịch sử A rồi chuyển B. Response A về sau B. MainActor có cứu được không?

- **S:** state bị overwrite bởi response cũ dù mọi mutation đều ở main actor.
- **T:** chỉ kết quả phù hợp lựa chọn hiện tại được xuất hiện.
- **A:** cancel request cũ, gắn generation/circleID, kiểm tra trước commit; không dựa riêng cancellation vì completion có thể đã tới. Tách loading/error theo request active; không để finally/defer của A tắt spinner của B.
- **R:** fake repository điều khiển response đảo thứ tự; UI vẫn ở B; test cancellation không hiện error banner.
- **Hỏi xoáy:** data race khác logic race thế nào? Data race là truy cập bộ nhớ không được đồng bộ; logic race vẫn tồn tại khi các thao tác riêng lẻ đều được serialize.

### 9. Tích hợp SDK Objective-C và màn hình UIKit trong app SwiftUI ra sao?

- **S:** tính năng bản đồ hoặc SDK hiện hữu cung cấp delegate/target-action, UI chính là SwiftUI.
- **T:** bridge đúng lifecycle mà không để SDK lan vào Domain.
- **A:** adapter bọc SDK, map callback sang model/stream; expose `@objc` selector khi cần và kiểu dữ liệu bridge được. UIKit view qua representable, tránh tạo lại resource ở mỗi update; tháo delegate/observer đúng lifecycle, xác nhận callback queue trước đổi UI state.
- **R:** demo mount/update/unmount và callback sau unmount không gây crash/leak; test adapter bằng fake. Ghi rõ đây là demo bổ sung nếu app chưa có flow này.
- **Hỏi xoáy:** `@objc` có làm mọi hàm Swift dynamic không? Không; exposure và lựa chọn dispatch là hai vấn đề cần phân biệt.

### 10. Một SOS mất mạng vẫn hiện “gửi thành công”. Em xử lý như owner thế nào?

- **S:** UI coi emit/enqueue là thành công, nhưng người thân chưa được xác nhận đã nhận.
- **T:** bảo vệ niềm tin người dùng trước, rồi làm rõ mức bảo đảm end-to-end.
- **A:** phân biệt queued, server-accepted, delivery/recipient acknowledgement theo contract; pending/failed rõ ràng; retry ID ổn định, TTL và dedupe; bàn với backend/product về push fallback và thông báo thay thế. Xác định thứ tự ưu tiên so với location thường và quyền truy cập circle.
- **R:** test mất mạng, app restart, ack trễ và duplicate; không hiển thị delivered khi chỉ có local enqueue. Ghi giới hạn còn lại trong release notes và theo dõi failure rate với dữ liệu tối thiểu.
- **Hỏi xoáy:** em hứa exactly-once được không? Không chỉ từ client. Nêu cơ chế cụ thể và invariant nghiệp vụ thay vì hứa bằng tên protocol.

## Bộ bằng chứng mang đi phỏng vấn

1. Sơ đồ architecture một trang, một sequence REST và một sequence reconnect/ack.
2. Một test suite có race/cancellation/offline, không chỉ happy path.
3. Một memory investigation có graph, owner và lifecycle được giải thích.
4. Một performance comparison ghi thiết bị, workload, build, sample size và hạn chế.
5. Một decision note nêu vấn đề, lựa chọn, trade-off, test và việc chưa làm.

Pitch 45 giây, điều chỉnh theo việc đã thực sự hoàn thành:

> “Em có nền tảng React Native/TypeScript và đang xây FamilyTracker bằng Swift để đào sâu native lifecycle, ARC và concurrency. App đã có phân tầng MVVM-C/Clean, URLSession async, realtime socket và policy location theo motion/pin. Khi đọc lại offline queue, em nhận ra giữ vị trí cuối khác lưu cả hành trình, và emit khác server acknowledgement. Em đang dùng các bài test mất mạng, session race và đo trên thiết bị thật để kiểm chứng thiết kế thay vì chỉ làm happy path.”

Tự chấm mỗi chủ đề: 0 = chỉ biết tên; 1 = giải thích được; 2 = chỉ ra được trong mã và test; 3 = có phép đo, trade-off và tình huống thất bại. Ưu tiên mức 2 vững ở Swift, ARC, concurrency, REST, UIKit/SwiftUI trước khi mở rộng sang runtime nâng cao.
