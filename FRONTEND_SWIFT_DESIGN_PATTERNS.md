# FamilyTracker iOS: Design Patterns và Architectural Patterns

Tài liệu ôn phỏng vấn Swift Native, từ Fresher/Junior đến Mid. Đối chiếu mã nguồn ngày **05/10/2026**.

## Phạm vi và cách đọc

Phân tích ứng dụng iOS trong `FamilyTracker/`: SwiftUI Presentation, Domain, Data, Core và App composition. Không suy diễn implementation của backend từ tên event hoặc comment phía client.

Đã đối chiếu [AI_RULES.md](AI_RULES.md), [CLAUDE.md](CLAUDE.md), [PROGRESS.md](PROGRESS.md), [spec API](.spec/api-integration.md) và [project.yml](project.yml). Quy chuẩn là mục tiêu kiến trúc; mã hiện tại mới là bằng chứng về mức độ triển khai. Deployment target trong project.yml là iOS 16; Swift language mode 5 không có nghĩa compiler chỉ là Swift 5 hay đã bật strict concurrency toàn bộ.

Các snippet là đoạn trích nguyên văn, có thể chỉ là một phần hàm/class nên không chạy độc lập. Các đề xuất cải tiến được ghi rõ; không có bản vá Swift trong tài liệu này. Không có phép đo FPS, pin hay leak mới được thực hiện.

**Cách dùng STAR:** S = Situation, T = Task, A = Action, R = Result. Các câu mẫu giúp trình bày implementation đang có; chỉ nói “em đã” khi bạn thực sự làm và hiểu phần đó. R về cấu trúc có thể kiểm tra bằng mã, nhưng không được đổi thành số liệu hiệu năng hoặc kết quả production chưa đo.

**Mục lục:** [Kiến trúc](#architecture) · [Khởi tạo](#creation) · [Cấu trúc](#structure) · [Hành vi](#behavior) · [Phỏng vấn](#interview) · [Giới hạn và ôn tập](#verification).

## Bản đồ pattern và mức độ có thật

| Pattern | Phân loại | Bằng chứng / mức độ |
| --- | --- | --- |
| MVVM-C | Kiến trúc | ViewModel + use cases + feature coordinators |
| Coordinator | Kiến trúc điều hướng; vai trò điều phối hành vi | NavigationPath, tab routing, sheet và SOS overlay |
| Clean Architecture, Repository, DTO Mapper | Kiến trúc | Domain protocols, Data implementations, Core adapters |
| Dependency Injection / Composition Root | Kỹ thuật kiến trúc và khởi tạo | AppContainer, không phải DependencyContainer.swift |
| Simple Factory | Khởi tạo | makeJourneyViewModel, use-case computed properties; không phải GoF Factory Method qua kế thừa |
| Shared instance / singleton-style access | Khởi tạo | CompositionRoot.container, PulseDiagnostics.shared; không cưỡng chế duy nhất mọi instance |
| Adapter / Wrapper | Cấu trúc | CLLocationService, URLSessionAPIClient, SocketIOClientAdapter |
| Facade / workflow orchestration | Cấu trúc ở API cung cấp; UseCase ở tầng nghiệp vụ | SendImageMessageUseCase, MediaRepositoryImpl |
| Decorator-like ViewModifier | Cấu trúc | EmergencyPresentation, DebugOverlay; không phải class Decorator GoF nguyên mẫu |
| Observer | Hành vi | ObservableObject/@Published, Combine, AsyncStream; **chưa có @Observable** |
| Event-driven fan-out | Kiến trúc tương tác / hành vi | Socket repositories + AsyncBroadcaster |
| Delegate / closure callback | Hành vi | CLLocationManagerDelegate, notification delegate, navigation callbacks |
| Strategy-like Policy | Hành vi | AdaptiveLocationPolicy, hiện là concrete value policy |
| Explicit state modeling | Hành vi | Enum state và switch, chưa phải GoF State với các state object |
| Cache-aside | Kiến trúc truy cập dữ liệu | GeocodingRepositoryImpl + GeocodeCache |
| Persistent queue / store-and-forward | Kiến trúc độ tin cậy | OfflineQueue cho location/SOS, chưa có ack-based durable outbox |
| Null Object | Hành vi | NoopNetworkLogger trong Release |

Apple cung cấp API và framework, không cung cấp một “kiến trúc mặc định” bắt buộc. Trade-off dưới đây so sánh với dùng trực tiếp API/state của Apple hoặc triển khai ít lớp hơn, không coi pattern là sự thay thế cho framework.

<a id="architecture"></a>

## PHẦN 1: ARCHITECTURAL PATTERNS

### 1.1. MVVM-C: tách state màn hình khỏi navigation và I/O

**1. Tên và phân loại:** Model-View-ViewModel + Coordinator, pattern kiến trúc Presentation.

**2. Bài toán:** LiveMap vừa hiển thị vị trí, trạng thái kết nối, camera, vừa cần mở journey và gửi SOS. Nếu dồn tất cả vào View, thay UI dễ ảnh hưởng socket/location và navigation.

**3. Trong mã:** [LiveMapView](FamilyTracker/Presentation/Scenes/LiveMap/Map/LiveMapView.swift) render Map, giữ state giao diện cục bộ `selectedMember/showMemberList`; [LiveMapViewModel](FamilyTracker/Presentation/Scenes/LiveMap/Map/LiveMapViewModel.swift) nhận use cases, cập nhật UI state; [MapCoordinator](FamilyTracker/Presentation/Coordinators/MapCoordinator.swift) giữ path và tạo destination; [MemberLocation](FamilyTracker/Domain/Entities/LocationModels.swift) là model.

**4. Snippet, LiveMapViewModel.swift:**

```swift
@MainActor
final class LiveMapViewModel: ObservableObject {
    @Published var mapRegion: MKCoordinateRegion = .defaultCity
    @Published private(set) var memberLocations: [MemberLocation] = []
    @Published private(set) var connectionState: RealtimeConnectionState
    @Published var isTrackingUser = true
```

Luồng nghiệp vụ: View intent -> ViewModel -> UseCase -> Repository protocol -> Data implementation -> Core. Luồng điều hướng: View/callback từ ViewModel -> Coordinator -> route/sheet/tab. Không phải mọi API request đều đi qua Coordinator như một trạm trung gian.

**5. Trade-offs:** nhiều lớp và dependency hơn một View dùng @State trực tiếp, đổi lại test state không cần render Map. ViewModel import MapKit là hợp lý ở Presentation; không có nghĩa Domain được import MapKit. View giữ state thuần giao diện không phá MVVM. `selectedMember` hiện là snapshot nên card có thể cũ hơn location array sau event mới; dùng selected ID và derive dữ liệu mới là hướng cần kiểm chứng, không phải đã có.

**6. STAR mẫu:**
- **S:** “Map có cả realtime state và thao tác mở lịch sử/SOS.”
- **T:** “Em cần thay đổi giao diện mà không trộn transport và navigation.”
- **A:** “Em đặt UI state trong MainActor ViewModel, inject use cases; MapCoordinator nhận ý định điều hướng.”
- **R:** “Có thể lần theo từng trách nhiệm trong các file riêng; em chưa quy kết cách chia lớp tự động làm map mượt hơn.”

### 1.2. Coordinator: navigation, SOS và notification deep link

**1. Tên và phân loại:** Coordinator, kiến trúc điều hướng với vai trò điều phối hành vi. Không phải một trong 23 GoF patterns chính thức.

**2. Bài toán:** từ Chat/Places vẫn nhận SOS; bấm thông báo phải chuyển tab và focus đúng thành viên, không bắt từng màn hình tự hiểu payload notification.

**3. Trong mã:** [NavigationCoordinator](FamilyTracker/Presentation/Coordinators/Coordinator.swift) có push/pop/popToRoot; MapCoordinator có typed Route; [MainTabCoordinator](FamilyTracker/Presentation/Coordinators/MainTabCoordinator.swift) xử lý cross-tab; [EmergencyCoordinator](FamilyTracker/Presentation/Coordinators/EmergencyCoordinator.swift) giữ incomingAlert và confirmation state. [PushNotificationService](FamilyTracker/Core/PushNotification/PushNotificationService.swift) parse NotificationDeeplink; [RealtimeNotificationBridge](FamilyTracker/App/RealtimeNotificationBridge.swift) tạo local notification khi app không active nhưng còn nhận được realtime.

**4. Snippet, MainTabCoordinator.swift:**

```swift
func handle(_ deeplink: NotificationDeeplink) {
    switch deeplink {
    case .sos(let userId), .member(let userId):
        selectedTab = .map
        map.focus(onMember: userId)
    case .conversation(let id):
        selectedTab = .chat
        chat.openConversation(id: id, title: "Tin nhắn")
    }
}
```

Hai đường cần phân biệt:

```text
Socket sos_alert -> SOSRepository stream -> EmergencyCoordinator.present
                 -> EmergencyPresentation overlay trên MainTabView

Tap notification -> UNUserNotificationCenterDelegate -> pendingDeeplink
                 -> Combine sink ở MainTabCoordinator -> handle -> MapCoordinator
```

**5. Trade-offs:** Coordinator quản lý quyết định; `NavigationStack`, `navigationDestination` và `.sheet` vẫn render UI. Dùng thêm Coordinator hữu ích cho đa tab/deep link, nhưng app một flow ngắn có thể chỉ cần state trong View. [Apple: NavigationStack](https://developer.apple.com/documentation/swiftui/navigationstack)

Giới hạn thực tế: overlay gắn vào MainTabView, không bảo đảm nằm trên mọi sheet/fullScreenCover hoặc màn hình Auth. Tap SOS chọn Map và focus member đã có trong `memberLocations`; chưa có fetch/retry khi cold start thiếu member. Code đăng ký APNs token nhưng chưa thấy flow gửi device token lên backend; không coi đây là xác nhận remote push end-to-end. Socket nền cũng không được bảo đảm hoạt động lúc app suspend. `isSending` SOS tắt sau timer 3 giây, không phải ack server; `sosConfirmed` mới có constant, chưa có consumer xử lý.

**6. STAR mẫu:**
- **S:** “SOS có thể đến trong lúc người dùng ở tab khác.”
- **T:** “Em cần một nơi quyết định chuyển tab và trình bày cảnh báo.”
- **A:** “Em tách EmergencyCoordinator cho alert và MainTabCoordinator cho deep link, vẫn sử dụng NavigationStack của SwiftUI.”
- **R:** “Đường routing không lặp trong từng View; em nêu rõ còn cần test cold start, sheet đang mở và member chưa tải.”

### 1.3. Clean Architecture, Repository và DTO Mapper

**1. Tên và phân loại:** kiến trúc phân tầng, dependency inversion, Repository và mapping boundary. DTO Mapper không nhất thiết là một GoF Adapter riêng.

**2. Bài toán:** server schema, URLSession, CLLocation và Keychain thay đổi không nên buộc ViewModel biết chi tiết transport hoặc quyền hệ điều hành.

**3. Trong mã:** [Domain/Repositories/AuthRepository.swift](FamilyTracker/Domain/Repositories/AuthRepository.swift) là abstraction; [AuthRepositoryImpl](FamilyTracker/Data/Repositories/RESTRepositories.swift) thực hiện bằng API; [AuthUseCases](FamilyTracker/Domain/UseCases/Auth/AuthUseCases.swift) validate/lưu phiên; [CoreMappers](FamilyTracker/Data/Network/Mappers/CoreMappers.swift) đổi DTO thành Domain; [DeviceLocationRepositoryImpl](FamilyTracker/Data/Repositories/DeviceRepositories.swift) đổi CLLocation thành GeoPoint.

**4. Snippet, RESTRepositories.swift:**

```swift
func login(email: String, password: String) async throws -> AuthSession {
    try await withDomainErrors {
        try await api.send(AuthEndpoint.login(email: email, password: password), as: APIResponseDTO<AuthDataDTO>.self)
            .unwrap(fallbackMessage: "Đăng nhập thất bại.")
            .toDomain()
    }
}
```

Dependency tĩnh: Data phụ thuộc protocol/type trong Domain; Domain không import Data. Runtime gọi Data implementation được inject. Use cases có `callAsFunction`, cho API ngắn gọn nhưng không vì thế đã là GoF Command có undo/queue/history.

**5. Trade-offs:** có thêm DTO, entity, mapper và file; đổi lại tránh truyền JSON dictionary vào UI. Repo tách theo folder trong một target, không phải module/package boundary cưỡng chế bởi compiler; vẫn cần review/static check. Foundation trong Domain không đồng nghĩa phụ thuộc UI. Một số use cases chỉ forward một dòng, cần cân nhắc chi phí abstraction. Progress còn ghi mapping Journey và LiveMap REST bootstrap chưa hoàn tất: có kiến trúc không có nghĩa integration đã đầy đủ.

**6. STAR mẫu:**
- **S:** “REST trả schema phục vụ API, còn UI cần model ổn định.”
- **T:** “Em cần giới hạn phạm vi sửa khi payload thay đổi.”
- **A:** “Em giữ protocol ở Domain, decode/mapping ở Data, inject repository vào UseCase.”
- **R:** “ViewModel không phải đọc URLSession/Keychain; độ đúng của mapping vẫn cần contract tests, không được mặc định từ tên Clean Architecture.”

<a id="creation"></a>

## PHẦN 2: CREATIONAL PATTERNS

### 2.1. Dependency Injection và Composition Root

**1. Tên và phân loại:** DI là kỹ thuật kiến trúc/khởi tạo; Composition Root là nơi lắp object graph, không phải một GoF factory mặc định.

**2. Bài toán:** dùng chung socket, session và location service nhưng không để ViewModel tự tạo URLSession/CLLocationManager, hoặc truy global service tùy ý.

**3. Trong mã:** tên đúng là [AppContainer.swift](FamilyTracker/App/DI/AppContainer.swift), class `AppContainer`, enum `CompositionRoot`. Coordinator lấy use cases từ container rồi truyền vào init ViewModel; services không được inject trực tiếp tràn lan vào View.

**4. Snippet, AppContainer.swift:**

```swift
session = KeychainSessionRepository()
api = URLSessionAPIClient(baseURL: environment.apiBaseURL, tokenProvider: session, logger: logger)
authRepository = AuthRepositoryImpl(api: api)
circleRepository = CircleRepositoryImpl(api: api)
placeRepository = PlaceRepositoryImpl(api: api)
historyRepository = HistoryRepositoryImpl(api: api)
realtime = SocketRealtimeRepository(socket: socketClient, offlineQueue: OfflineQueue())
```

Object graph tiêu biểu: URLSessionAPIClient -> AuthRepositoryImpl -> LoginUseCase -> LoginViewModel. Location graph: CLLocationService -> DeviceLocationRepositoryImpl -> use case -> ViewModel. Container giữ các dependency sống lâu, computed factory tạo các value use cases khi cần.

**5. Trade-offs:** constructor dài hơn dùng `.shared` hoặc Environment khắp nơi; đổi lại dependencies dễ thấy và có thể fake ở protocol boundary. Environment hợp lý cho dependency theo cây UI, không thay constructor injection ở Domain. Container hiện tự tạo concrete Core objects trong init, vì vậy test cả container khó thay thế hơn test riêng ViewModel/repository. Truy container ở mọi tầng sẽ biến nó thành Service Locator; repo chủ yếu giới hạn ở App/Coordinator.

**6. STAR mẫu:**
- **S:** “Nhiều feature cần dùng chung session và socket.”
- **T:** “Em muốn lifetime rõ ràng nhưng không hard-code service trong ViewModel.”
- **A:** “Em lắp graph ở AppContainer và inject use cases qua initializer.”
- **R:** “Có điểm thay implementation tập trung; em phân biệt khả năng inject từng tầng với việc container hiện chưa được thiết kế hoàn toàn cho test.”

### 2.2. Simple Factory và những gì chưa phải Factory

**1. Tên và phân loại:** Simple Factory / factory function, khởi tạo. Không có bằng chứng một hệ GoF Factory Method dựa trên subclass hoặc Abstract Factory đầy đủ cho map pin.

**2. Bài toán:** mở journey của một member cần ViewModel khác theo userId/name, nhưng View không nên tự lắp repository và use cases.

**3. Trong mã:** `MapCoordinator.makeJourneyViewModel`, `MainTabCoordinator.makeDurationViewModel/makeProfileViewModel`, computed use-case factories ở AppContainer. [MapMemberPin](FamilyTracker/Presentation/Scenes/LiveMap/Components/MapMemberPin.swift) và [MemberAvatarView](FamilyTracker/Presentation/Common/Components/MemberAvatarView.swift) là data-driven View composition, không phải family factory theo moving/stationary/low-battery.

**4. Snippet, MapCoordinator.swift:**

```swift
func makeJourneyViewModel(userId: String, name: String) -> JourneyViewModel {
    JourneyViewModel(userId: userId, memberName: name,
                     fetchDayJourney: container.fetchDayJourney, reverseGeocode: container.reverseGeocode)
}
```

**5. Trade-offs:** tránh lặp object construction, song factory không tự giải quyết ownership: gọi trong body có thể tạo candidate mới; phải xem View nhận bằng StateObject hay ObservedObject và identity của destination. Không thêm factory class chỉ vì có switch trong ViewBuilder. Pin hiện hard-code `isOnline: true`; truyền batteryLevel vào avatar nhưng body avatar chưa dùng nó để vẽ pin yếu. Có `BatteryIndicatorView` riêng, không suy diễn nó đã tích hợp vào map pin. Chưa có factory chọn pin theo motion state; nếu bổ sung nên bắt đầu bằng presentation state và ViewBuilder nhỏ.

**6. STAR mẫu:**
- **S:** “Mỗi destination journey cần tham số member và cùng nhóm dependencies.”
- **T:** “Em muốn View chỉ khai báo destination.”
- **A:** “Em tập trung khởi tạo ở makeJourneyViewModel của Coordinator.”
- **R:** “Dependency wiring nằm ngoài destination View; em gọi đúng là factory function, không tuyên bố app đã có Abstract Factory cho annotation.”

### 2.3. Shared instance và phạm vi singleton

**1. Tên và phân loại:** shared-instance access, khởi tạo; singleton-style nhưng không cưỡng chế chỉ một instance của mọi type.

**2. Bài toán:** SwiftUI App và UIApplicationDelegate phải cùng dùng một graph service, tránh hai socket/location managers do tạo container riêng.

**3. Trong mã:** CompositionRoot được MainActor-isolated; [FamilyTrackerApp](FamilyTracker/App/FamilyTrackerApp.swift) và [AppDelegate](FamilyTracker/App/AppDelegate.swift) dùng chung container. [PulseDiagnostics](FamilyTracker/Core/Logging/PulseDiagnostics.swift) có shared dùng cho debug logging/export.

**4. Snippet, AppContainer.swift:**

```swift
@MainActor
enum CompositionRoot {
    static let container = AppContainer()
}
```

**5. Trade-offs:** lifetime toàn app dễ quản lý tài nguyên dùng chung, nhưng global access có thể làm test lẫn state. AppContainer vẫn có initializer, nên đây không phải guarantee “không thể có instance thứ hai”. Không thay mọi DI bằng singleton; chỉ dùng shared entry point ở mép app. Không mặc định mọi shared object thread-safe; isolation/lock phải được xem riêng.

**6. STAR mẫu:**
- **S:** “AppDelegate cần phục hồi tracking khi launch vì location event.”
- **T:** “Em cần nó dùng cùng service graph với SwiftUI App.”
- **A:** “Em đặt static container ở CompositionRoot và vẫn inject xuống tầng dưới.”
- **R:** “Hai entry points không tự lắp hai graph; em giữ rõ giới hạn global lifetime và test isolation.”

<a id="structure"></a>

## PHẦN 3: STRUCTURAL PATTERNS

### 3.1. Adapter/Wrapper cho CoreLocation và CoreMotion

**1. Tên và phân loại:** Adapter/Wrapper, cấu trúc. CLLocationService còn có vai trò facade nhỏ cho nhiều API nền tảng.

**2. Bài toán:** các feature cần GeoPoint stream, không nên tự quản CLLocationManagerDelegate, quyền GPS, motion và các mode tiết kiệm pin.

**3. Trong mã:** [CLLocationService](FamilyTracker/Core/Location/CLLocationService.swift) implements LocationService, sở hữu CLLocationManager; [MotionActivityService](FamilyTracker/Core/Location/MotionActivityService.swift) bọc CMMotionActivityManager; DeviceLocationRepositoryImpl đổi callback/location thành Domain stream. LocationService vẫn expose CLLocation/CLAuthorizationStatus nên chưa phải abstraction thuần Domain; repository là boundary tiếp theo.

**4. Snippet, CLLocationService.swift:**

```swift
if settings.significantChangesOnly, CLLocationManager.significantLocationChangeMonitoringAvailable() {
    manager.stopUpdatingLocation()
    manager.startMonitoringSignificantLocationChanges()
} else {
    manager.stopMonitoringSignificantLocationChanges()
    manager.startUpdatingLocation()
}
```

**5. Trade-offs:** thêm adapter và mapping nhưng tập trung quyền/lifecycle. Wrapper không vượt qua giới hạn iOS; `allowsBackgroundLocationUpdates` không cho chạy vô hạn. [Apple: Background location](https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background) Chỉ cần một fix thì dùng requestLocation có thể đơn giản hơn chạy tracking liên tục. Chi phí location phụ thuộc độ chính xác và thời gian hoạt động; giảm yêu cầu khi hợp lý mới có cơ sở tiết kiệm năng lượng. [Apple: Location energy practices](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/EnergyGuide-iOS/LocationBestPractices.html)

Rủi ro còn lại: delegate chỉ lọc horizontalAccuracy âm, chưa loại fix quá cũ/outlier; mapper bỏ timestamp/accuracy khi tạo GeoPoint; didFailWithError chưa truyền lỗi cho UI. Motion không có dữ liệu thì policy unknown vẫn khá chính xác; cần cân nhắc fallback/hysteresis. Không lấy comment “near-zero battery cost” làm kết quả đo.

**6. STAR mẫu:**
- **S:** “Map và SOS cùng cần location, còn background có policy riêng.”
- **T:** “Em cần một owner điều khiển API hệ thống.”
- **A:** “Em bọc manager/motion, chuyển CLLocation thành GeoPoint ở repository.”
- **R:** “Domain không cần import CoreLocation; mức tiết kiệm pin và phục hồi background vẫn cần đo trên thiết bị thật.”

### 3.2. URLSession Adapter và Bearer request policy

**1. Tên và phân loại:** Adapter/Wrapper, cấu trúc; interceptor-like request policy được đặt trong client, chưa phải middleware chain hay GoF Chain of Responsibility.

**2. Bài toán:** nhiều endpoint cần Bearer, error mapping, decoding và logging giống nhau; public auth request không nên vô tình mang token.

**3. Trong mã:** [URLSessionAPIClient](FamilyTracker/Data/Network/APIClient.swift) implements APIClient, gọi URLSession; AccessTokenProvider được [KeychainSessionRepository](FamilyTracker/Data/Local/Keychain/KeychainStore.swift) cung cấp. Repository map APIError thành DomainError; View không gọi URLSession.

**4. Snippet, APIClient.swift:**

```swift
var token: String?
if endpoint.requiresAuth {
    guard let accessToken = tokenProvider.accessToken, !accessToken.isEmpty else { throw APIError.unauthorized }
    token = accessToken
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
}
```

**5. Trade-offs:** direct URLSession đủ cho request nhỏ, wrapper hợp lý khi policy lặp ở nhiều endpoint. Client tập trung dễ phình thành god object nếu trộn refresh, navigation và caching. Repo đã tách URLSession injection để stub bằng URLProtocol. Chưa có refresh-token workflow; đừng mô tả nó như implementation hiện hữu. Invalidate nhận sentToken để tránh xóa phiên mới một cách hiển nhiên, nhưng read/compare/delete ở KeychainSessionRepository chưa được serialize như transaction: còn rủi ro race. KeychainStore chưa trả lỗi OSStatus đầy đủ. Signed upload là transport khác, không tự gắn Bearer vào storage host.

**6. STAR mẫu:**
- **S:** “Mỗi feature có auth và lỗi HTTP cần xử lý nhất quán.”
- **T:** “Em cần một điểm áp policy và một boundary cho test.”
- **A:** “Em inject token provider, validate HTTP/envelope trong URLSessionAPIClient và map lỗi ở repository.”
- **R:** “Các contract test trong repo kiểm tra Bearer/public request/error; đó không phải chứng minh session race đã được giải quyết toàn diện.”

### 3.3. Socket.IO Adapter

**1. Tên và phân loại:** Adapter, cấu trúc.

**2. Bài toán:** Domain muốn event stream typed, không nên import SocketIO hoặc phụ thuộc cách SocketManager reconnect.

**3. Trong mã:** [SocketClient](FamilyTracker/Core/Realtime/SocketClient.swift) là transport protocol; [SocketIOClientAdapter](FamilyTracker/Core/Realtime/SocketIOClientAdapter.swift) chuyển SDK callbacks thành on/onStatusChange; SocketRealtimeRepository và ChatRepositoryImpl decode/mapping sang Domain.

**4. Snippet, SocketIOClientAdapter.swift:**

```swift
socket.onAny { [weak self] event in
    guard let payload = event.items?.first as? [String: Any] else { return }
    self?.dispatch(event.event, payload)
}
```

**5. Trade-offs:** cô lập SDK và dễ fake transport, nhưng `[String: Any]` làm mất type-safety tại mép adapter nên phải validate payload. Socket.IO có protocol riêng trên Engine.IO, không thay trực tiếp bằng URLSessionWebSocketTask. `.forceWebsockets(true)` hiện bỏ lựa chọn polling fallback của transport. [Socket.IO: How it works](https://socket.io/docs/v4/how-it-works/)

Adapter lưu handlers qua reconnect; `disconnect` xóa SDK handlers nhưng không xóa các mảng handler của wrapper. Đây hỗ trợ register-once cho repository sống lâu, nhưng chưa có token/off để unsubscribe riêng. Fallback `#if !canImport(SocketIO)` báo connected sau delay dù không có transport thật; không dùng fallback để chứng minh realtime hoạt động.

**6. STAR mẫu:**
- **S:** “Chat và tracking cùng dùng Socket.IO.”
- **T:** “Em muốn domain độc lập SDK và registration không lặp theo màn hình.”
- **A:** “Em bọc transport trong SocketClient adapter; repository sở hữu handlers typed.”
- **R:** “UI nhận model thay vì packet SDK; lifecycle unsubscribe và delivery guarantee vẫn là vấn đề riêng.”

### 3.4. Facade cho gửi ảnh: upload rồi tạo message qua REST

**1. Tên và phân loại:** facade-like interface, cấu trúc; SendImageMessageUseCase đồng thời là application workflow orchestration. Không phải transaction phân tán có rollback.

**2. Bài toán:** ViewModel muốn “gửi ảnh”, không cần biết resize/encode, upload ticket, headers ký sẵn và tạo message.

**3. Trong mã:** [SendImageMessageUseCase](FamilyTracker/Domain/UseCases/Chat/ChatUseCases.swift), `MediaRepositoryImpl` và `ChatRepositoryImpl` trong [ChatRepositoryImpl.swift](FamilyTracker/Data/Repositories/ChatRepositoryImpl.swift), [ImageProcessor](FamilyTracker/Core/Storage/ImageProcessor.swift), [ImageUploader](FamilyTracker/Core/Storage/ImageUploader.swift).

**4. Snippet, ChatUseCases.swift:**

```swift
func callAsFunction(imageData: Data, caption: String?, conversationId: String) async throws -> ChatMessage {
    let image = try media.prepareImage(imageData)
    let fileUrl = try await media.uploadChatImage(image, conversationId: conversationId)
    return try await chat.sendImage(attachmentUrl: fileUrl, caption: caption, image: image, conversationId: conversationId)
}
```

Luồng thật:

```text
ChatViewModel.sendPhoto
 -> prepareImage
 -> POST upload-ticket
 -> URLSession.upload tới ticket.uploadUrl, method từ ticket (fallback PUT)
 -> REST POST conversation message chứa attachmentUrl/metadata
 -> trả ChatMessage; socket chat:new_message là kênh nhận event riêng
```

Client không hard-code nhà cung cấp S3/R2; ticket quyết định storage target. **Không có bước client emit socket event xác nhận upload** trong workflow này. Không suy diễn từ comment backend hoặc tên service.

**5. Trade-offs:** facade giảm orchestration trong ViewModel nhưng cần thiết kế lỗi từng bước. Upload thành công rồi tạo message thất bại có thể để file mồ côi; retry cả pipeline có thể upload trùng. Chưa có resumable upload, durable upload queue hay cleanup transaction. ImageUploader dùng headers ticket, không Bearer của API; lỗi uploader được throw trực tiếp nên chưa mọi lỗi media đều map thành DomainError. `prepareImage` là hàm đồng bộ: cần profile executor/call site trước khi nói image processing đã chạy background.

**6. STAR mẫu:**
- **S:** “Một thao tác gửi ảnh gồm nhiều bước có thể lỗi độc lập.”
- **T:** “Em cần giữ ViewModel ngắn và test thứ tự thao tác.”
- **A:** “Em dùng một use case phối hợp media repository và chat repository; upload xong mới tạo REST message.”
- **R:** “UI chỉ gọi một workflow; em nêu rõ chưa có atomicity, retry idempotent hay số liệu upload nhanh hơn.”

### 3.5. Decorator-like composition bằng ViewModifier

**1. Tên và phân loại:** cấu trúc, tương tự Decorator qua SwiftUI ViewModifier; không phải class decorator giữ cùng interface theo GoF nguyên bản.

**2. Bài toán:** thêm SOS presentation hoặc debug overlay mà không sửa body của từng feature screen.

**3. Trong mã:** EmergencyPresentation bọc MainTabView; [DebugOverlay](FamilyTracker/Presentation/Coordinators/DebugCoordinator.swift) thêm nút và sheet debug. State thuộc Coordinator; modifier lo render presentation.

**4. Snippet, EmergencyCoordinator.swift:**

```swift
struct EmergencyPresentation: ViewModifier {
    @ObservedObject var coordinator: EmergencyCoordinator

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
```

**5. Trade-offs:** đúng cơ chế composition của SwiftUI, giảm duplication; thứ tự modifier và nơi gắn quyết định z-order, safe area và presentation scope. Không mặc định overlay là window-level. Nếu cần phủ toàn app kể cả modal, phải thiết kế presentation ownership phù hợp và kiểm tra accessibility/focus.

**6. STAR mẫu:**
- **S:** “SOS phải xuất hiện nhất quán trong vùng tab.”
- **T:** “Em tránh gắn banner riêng vào từng màn hình.”
- **A:** “Em tách modifier render từ Coordinator giữ alert.”
- **R:** “Feature views không lặp banner logic; phạm vi hiện chỉ là cây view được bọc, chưa phải bảo đảm phủ mọi presentation.”

<a id="behavior"></a>

## PHẦN 4: BEHAVIORAL PATTERNS

### 4.1. Observer cho UI: implementation hiện tại và Observation iOS 17+

**1. Tên và phân loại:** Observer, hành vi; Combine/SwiftUI là cơ chế triển khai hiện có.

**2. Bài toán:** location/connection thay đổi phải cập nhật UI, nhưng không muốn View tự polling hoặc biết socket.

**3. Trong mã:** LiveMapViewModel/ChatViewModel/Coordinators dùng ObservableObject và @Published; LiveMapView dùng @ObservedObject; [ChatView](FamilyTracker/Presentation/Scenes/Chat/Conversation/ChatView.swift) dùng @StateObject cho ViewModel nhận lúc khởi tạo. Không tìm thấy macro @Observable trong app source.

**4. Snippet, LiveMapView.swift:**

```swift
struct LiveMapView: View {
    @ObservedObject var viewModel: LiveMapViewModel
    let coordinator: MapCoordinator
```

**5. Trade-offs:** ObservableObject phù hợp target iOS 16; View observe object có thể bị invalidated khi @Published khác đổi, dù body không đọc property đó. Với Observation iOS 17+, SwiftUI theo dõi các observable properties được đọc khi tính body; model do View sở hữu thường giữ bằng @State, binding qua @Bindable. Không cần giả lập snippet @Observable và gắn nhãn “mã hiện có”. [Apple: Discover Observation](https://developer.apple.com/videos/play/wwdc2023/10149/)

Observation không tự throttle socket, không tự tách từng member trong array value và không bảo đảm “không re-render thừa”. Invalidation/body evaluation khác layout/drawing thực tế; đo workload trước khi chọn giải pháp. [Apple: SwiftUI performance](https://developer.apple.com/videos/play/wwdc2023/10160/)

Hiện upsert publish array cho mỗi event, chưa batch/coalesce inbound. MemberLocation có identity theo userId nhưng Equatable cũng chỉ so id: không dùng removeDuplicates/equatable một cách mù quáng, vì tọa độ mới cùng id có thể bị coi không đổi.

**6. STAR mẫu:**
- **S:** “Map cần phản ánh stream member locations.”
- **T:** “Em cần UI update đúng và phù hợp iOS 16.”
- **A:** “Em publish state trên MainActor và để View observe; em phân biệt implementation này với Observation iOS 17.”
- **R:** “UI state có một owner rõ; em không nói đã đạt property-level optimization khi app chưa migrate hoặc profile.”

### 4.2. Event-driven fan-out và AsyncSequence

**1. Tên và phân loại:** Observer/Pub-Sub-like fan-out, hành vi và kiến trúc tương tác. Không có event bus toàn cục tùy ý; streams gắn repository.

**2. Bài toán:** một event SOS có nhiều consumer: banner và notification bridge; location vừa phục vụ Map vừa Duration, không muốn mỗi View mở một socket.

**3. Trong mã:** [SocketRealtimeRepository](FamilyTracker/Data/Repositories/SocketRealtimeRepository.swift) decode `location_update`, `sos_alert`; ChatRepositoryImpl decode `chat:new_message`; [AsyncBroadcaster](FamilyTracker/Core/Concurrency/AsyncBroadcaster.swift) tạo stream riêng cho mỗi subscriber; use cases expose streams; MainActor ViewModels consume bằng Task.

**4. Snippet, SocketRealtimeRepository.swift:**

```swift
socket.on(SocketEvent.locationUpdate) { [weak self] payload in
    guard let dto = JSONPayload.decode(LocationUpdateDTO.self, from: payload) else { return }
    self?.locations.send(dto.toDomain())
}
```

Snippet consumer, LiveMapViewModel.swift:

```swift
tasks.append(Task { [weak self] in
    for await location in locations { self?.upsert(location) }
})
```

Task ở đây được tạo trong context của MainActor ViewModel, nên cập nhật UI đi qua actor đó; không phải socket callback tự nhiên luôn ở MainActor. Broadcaster dùng NSLock bảo vệ registry, chụp danh sách continuations rồi yield ngoài lock; onTermination gỡ subscriber.

**5. Trade-offs:** nhiều consumers độc lập, dễ inject stream hơn NotificationCenter với string payload toàn app. AsyncStream mặc định ở wrapper này buffer không giới hạn; consumer chậm có thể tích lũy. Chưa có bounded buffering/backpressure policy. `.bufferingNewest(1)` cho stream trộn nhiều users sẽ bỏ cập nhật của user khác; nên coalesce theo member khi phù hợp. Stream không tự replay state cũ: ViewModel đọc connection.current riêng, và LiveMap chưa có REST bootstrap hoàn chỉnh. Khai báo constant event không có nghĩa đã có listener cho mọi event.

**6. STAR mẫu:**
- **S:** “Cùng một location/SOS event phục vụ nhiều màn hình và dịch vụ.”
- **T:** “Em cần fan-out nhưng không nhân kết nối.”
- **A:** “Repository decode một lần rồi phát qua stream cho từng consumer, ViewModel cập nhật trên MainActor.”
- **R:** “Consumers tách nhau; tốc độ producer/consumer và dung lượng buffer vẫn cần stress test.”

### 4.3. Delegate, closure callback và ownership

**1. Tên và phân loại:** Delegate và callback, hành vi. Weak capture là kỹ thuật quản lý ownership, không phải một pattern tự bảo đảm không leak.

**2. Bài toán:** Apple APIs gọi ngược vào app; navigation child báo intent cho parent mà không giữ parent sống mãi.

**3. Trong mã:** CLLocationService implements CLLocationManagerDelegate; PushNotificationService implements UNUserNotificationCenterDelegate; MainTabCoordinator nối closure từ Map/Emergency; DeviceLocationRepositoryImpl nhận onLocationUpdate; ViewModel cancel tasks trong deinit.

**4. Snippet, CLLocationService.swift:**

```swift
func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last, location.horizontalAccuracy >= 0 else { return }
    lastLocation = location
    onLocationUpdate?(location)
}
```

Snippet nối parent/child, MainTabCoordinator.swift:

```swift
map.onRequestSOS = { [weak self] in self?.emergency.requestSOS() }
emergency.onShowLocation = { [weak self] alert in self?.showOnMap(alert.point) }
circles.onOpenConversation = { [weak self] id, title in self?.openConversation(id: id, title: title) }
```

Nếu capture strong: parent -> child -> closure -> parent là cycle. Weak phá cạnh giữ parent ở closure. Unowned không thích hợp khi callback có thể chạy sau lifetime owner. [Swift: ARC](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/automaticreferencecounting/)

**5. Trade-offs:** delegate hợp với nhiều callback liên quan và contract Apple; closure gọn cho một action nhưng khó theo dõi khi quá nhiều. Callback phải có contract executor/lifecycle. `[weak self]` không gỡ listener hoặc hủy task; `guard let self` trước vòng for-await dài có thể lại giữ strong suốt vòng lặp. Deinit-only cancellation không đủ nếu task giữ owner không cho deinit chạy. Repo có start guards/cancel ở nhiều chỗ, chưa phải bằng chứng không leak trên mọi flow.

**6. STAR mẫu:**
- **S:** “Coordinator giữ child và child cần gọi ngược parent.”
- **T:** “Em cần callback không tạo chu kỳ ownership.”
- **A:** “Em dùng weak ở cạnh callback và kiểm tra lifecycle subscription/task riêng.”
- **R:** “Reference graph tránh cạnh giữ vòng đã xác định; em chỉ kết luận hết leak sau khi đo số instance và Memory Graph.”

### 4.4. Strategy-like Policy cho định vị thích ứng

**1. Tên và phân loại:** hành vi, tách thuật toán chọn cấu hình thành policy. Giống ý tưởng Strategy, nhưng chưa có protocol Strategy cùng nhiều concrete strategies hoán đổi runtime.

**2. Bài toán:** stationary không nên chạy accuracy cao như automotive; low-power cần giảm chi phí mà các màn hình không phải biết luật đó.

**3. Trong mã:** [AdaptiveLocationPolicy](FamilyTracker/Core/Location/AdaptiveLocationPolicy.swift) trả LocationSettings từ motion/pin; CLLocationService áp settings; [BatteryMonitor/BatterySnapshot](FamilyTracker/Core/Device/BatteryMonitor.swift) cung cấp pin.

**4. Snippet, AdaptiveLocationPolicy.swift:**

```swift
case .stationary:
    base = LocationSettings(desiredAccuracy: kCLLocationAccuracyHundredMeters, distanceFilter: 100,
                            activityType: .other, significantChangesOnly: true)
case .walking, .running:
    base = LocationSettings(desiredAccuracy: kCLLocationAccuracyNearestTenMeters, distanceFilter: 20,
                            activityType: .fitness, significantChangesOnly: false)
```

Policy pin dưới 20% hoặc Low Power Mode giảm accuracy, tăng distanceFilter gấp đôi. CLLocationService so settings với appliedSettings để tránh cấu hình lại không cần thiết. Đây là lựa chọn yêu cầu cho hệ thống, không guarantee fix sẽ chính xác 10m hoặc callback đúng sau 20m.

**5. Trade-offs:** policy tách biệt dễ unit test hơn switch rải trong delegate, nhưng chuyển significant-change đánh đổi chi tiết/freshness. Hiện policy reevaluate theo start/motion/authorization/power-state; battery snapshot đổi riêng chưa trực tiếp gọi applyPolicy, nên không hứa phản ứng ngay khi pin vượt ngưỡng. Chưa có hysteresis hay mô hình chất lượng fix đầy đủ. Kiểm tra thu GPS, gửi mạng và publish UI là ba nhịp khác nhau; heartbeat không ép iOS chạy liên tục lúc suspend.

**6. STAR mẫu:**
- **S:** “Yêu cầu vị trí khác nhau khi đứng yên và di chuyển.”
- **T:** “Em cần policy tiết kiệm năng lượng có thể giải thích và test.”
- **A:** “Em tách hàm chọn LocationSettings, áp theo motion và trạng thái pin.”
- **R:** “Luật chuyển mode có thể kiểm tra bằng test bảng; giảm pin bao nhiêu phải đo cùng điều kiện trên máy thật.”

### 4.5. Explicit state modeling thay vì gắn nhãn GoF State quá mức

**1. Tên và phân loại:** mô hình trạng thái, hành vi. Enum + switch không tự là GoF State pattern với các state object và delegation hành vi.

**2. Bài toán:** launch cần quyết định splash, login hay main; kết nối cần phản ánh disconnected/connecting/connected.

**3. Trong mã:** [AppCoordinator.State](FamilyTracker/Presentation/Coordinators/AppCoordinator.swift), SocketConnectionStatus và RealtimeConnectionState. State chuyển trong coordinator/adapter, View switch để render.

**4. Snippet, AppCoordinator.swift:**

```swift
enum State: Equatable {
    case launching
    case unauthenticated
    case authenticated
}
```

**5. Trade-offs:** enum dễ đọc và exhaustive hơn các booleans độc lập, nhưng chưa thể hiện đủ mọi state nghiệp vụ. Socket.connected chưa có session-ready/authenticated riêng; routing deep link chưa có pending-user-fetch state. Thêm state object class chỉ hợp lý khi hành vi từng state đủ phức tạp, không phải điều kiện để “đạt Mid”.

**6. STAR mẫu:**
- **S:** “App phải phục hồi phiên trước khi chọn root screen.”
- **T:** “Em muốn tránh tổ hợp boolean vừa loading vừa logged out.”
- **A:** “Em dùng enum State ở AppCoordinator và render theo switch.”
- **R:** “Ba trạng thái root rõ ràng; phần realtime cần mô hình readiness sâu hơn, em không gọi enum đơn giản là state machine hoàn chỉnh.”

### 4.6. Cache-aside cho reverse geocoding

**1. Tên và phân loại:** cache-aside, kiến trúc truy cập dữ liệu; repository chủ động kiểm tra và cập nhật cache, cache không tự tải dữ liệu nguồn.

**2. Bài toán:** nhiều điểm gần nhau trong journey cần địa chỉ; gọi geocoder lặp lại tăng latency và áp lực dịch vụ.

**3. Trong mã:** GeocodingRepositoryImpl điều phối [GeocodeCache](FamilyTracker/Data/Local/Cache/GeocodeCache.swift) và ReverseGeocoder. Cache là dictionary trong RAM, key lat/lng làm tròn bốn chữ số thập phân; không phải database offline.

**4. Snippet, DeviceRepositories.swift:**

```swift
func address(for point: GeoPoint) async -> String? {
    if let cached = cache.address(for: point) { return cached }
    guard let address = await geocoder.address(latitude: point.latitude, longitude: point.longitude) else { return nil }
    cache.store(address, for: point)
    return address
}
```

**5. Trade-offs:** giảm lookup trùng nhưng key xấp xỉ có thể gộp hai địa chỉ khác nhau; kích thước ô kinh độ thay đổi theo vĩ độ, không nói luôn chính xác 11m. Chưa có TTL/eviction/persistence hoặc single-flight; NSLock bảo vệ từng thao tác dictionary, không ngăn hai concurrent misses cùng geocode. So với gọi CLGeocoder trực tiếp, đây là policy cache của sản phẩm, không phải thay thế geocoder Apple.

**6. STAR mẫu:**
- **S:** “Journey có các điểm gần nhau cần địa chỉ.”
- **T:** “Em muốn tránh gọi dịch vụ lặp lại cho cùng khu vực.”
- **A:** “Em kiểm cache trước, geocode khi miss rồi lưu kết quả.”
- **R:** “Có đường cache hit rõ trong mã; hit rate, giới hạn memory và concurrent miss cần phép đo/test riêng.”

### 4.7. Persistent queue: store-and-forward, chưa phải durable outbox đầy đủ

**1. Tên và phân loại:** pattern kiến trúc độ tin cậy / hành vi lưu rồi gửi lại. Không phải transactional outbox: chưa có transaction dữ liệu + event và chưa có ack-based removal.

**2. Bài toán:** location/SOS phát sinh lúc mất mạng cần giữ lại có giới hạn. Tin nhắn chat và history có yêu cầu khác live location.

**3. Trong mã:** [OfflineQueue](FamilyTracker/Data/Local/OfflineQueue/OfflineQueue.swift) dùng file JSON, NSLock, maxItems mặc định 200, lọc tuổi 24h khi drain; SocketRealtimeRepository emitOrQueue. Location coalesce với key `location`, SOS không coalesce. ChatRepositoryImpl gửi REST, chưa có chat outbox hay persistent message cache.

**4. Snippet, SocketRealtimeRepository.swift:**

```swift
private func emitOrQueue(_ event: String, _ payload: [String: Any], coalesceKey: String?) {
    if socket.status == .connected {
        socket.emit(event, payload)
    } else {
        offlineQueue.enqueue(event: event, payload: payload, coalesceKey: coalesceKey)
    }
}
```

**5. Trade-offs:** giữ bản location mới nhất giảm backlog nhưng mất các điểm hành trình trung gian. Queue ghi file đồng bộ dưới lock, dùng try? nên lỗi lưu có thể bị bỏ qua. Drain xóa trước khi emit/ack; item UUID không được gửi như idempotency key. Flush cả connected và session:ready; transport connected chưa chắc business-ready. Chưa có account namespace/clear queue khi logout, cần tránh replay dữ liệu user cũ với phiên mới. Đây là rủi ro suy ra từ mã, chưa phải incident đã tái hiện.

Socket reconnect không bảo đảm delivery của từng event; bảo đảm cao hơn cần protocol ack/retry/dedupe phù hợp, không chỉ một array ở client. [Socket.IO: Delivery guarantees](https://socket.io/docs/v4/delivery-guarantees/)

**6. STAR mẫu:**
- **S:** “Người dùng di chuyển qua vùng mất mạng.”
- **T:** “Em cần giữ event nhưng kiểm soát dung lượng và độ cũ.”
- **A:** “Implementation hiện lưu JSON và coalesce live location; em phân biệt nó với history queue và chat outbox chưa có.”
- **R:** “Có khả năng replay best-effort; em không tuyên bố exactly-once hay không mất GPS history khi drain chưa chờ ack.”

### 4.8. Null Object cho logging

**1. Tên và phân loại:** Null Object, hành vi.

**2. Bài toán:** client gọi logger nhất quán nhưng Release không cần in-app diagnostics; không muốn mọi call site kiểm optional hoặc DEBUG.

**3. Trong mã:** [NetworkLogger](FamilyTracker/Core/Logging/NetworkLogger.swift) là protocol; `NoopNetworkLogger` không làm gì; AppContainer chọn PulseDiagnostics.shared ở Debug, Noop ở Release.

**4. Snippet, NetworkLogger.swift:**

```swift
struct NoopNetworkLogger: NetworkLogger {
    func logRequest(id: UUID, method: String, url: String, body: [String: Any]?) {}
    func logResponse(id: UUID, method: String, url: String, statusCode: Int, data: Data, duration: TimeInterval) {}
    func logError(id: UUID, method: String, url: String, message: String, duration: TimeInterval) {}
    func logSocket(event: String, payload: Any) {}
}
```

**5. Trade-offs:** call sites đơn giản, dependency có contract; đổi lại Release thiếu quan sát nếu không có telemetry khác. Noop không chứng minh mọi tham số truyền vào đều miễn phí tính toán. PulseDiagnostics là adapter sang Pulse, không phải crash reporter hay cơ chế ghi mọi OS socket stderr; redaction phải xảy ra trước lưu/export.

**6. STAR mẫu:**
- **S:** “Network/socket cần diagnostics lúc phát triển nhưng không muốn UI debug trong Release.”
- **T:** “Em cần thay hành vi logging mà không rải nhánh ở từng request.”
- **A:** “Em inject cùng NetworkLogger contract, dùng Noop ở Release.”
- **R:** “Call sites giữ nguyên; em cân nhắc observability production riêng thay vì gọi tắt log là giải pháp đầy đủ.”

<a id="interview"></a>

## PHẦN 5: NĂM CÂU HỎI PHỎNG VẤN CHUYÊN SÂU

### 5.1. Vì sao Coordinator thay vì NavigationStack/NavigationLink?

**Trả lời cốt lõi:** đây không phải lựa chọn loại trừ nhau. Coordinator sở hữu quyết định và navigation state; NavigationStack/Link là cơ chế UI. MapCoordinatorView hiện bind NavigationStack vào coordinator.path.

**STAR 90 giây:**
- **S:** “FamilyTracker có SOS từ notification và điều hướng giữa nhiều tab.”
- **T:** “Em cần mở đúng màn hình mà không bắt từng View hiểu payload.”
- **A:** “Em parse thành NotificationDeeplink, route trong MainTabCoordinator rồi giao MapCoordinator focus member. Destination vẫn render bằng NavigationStack.”
- **R:** “Routing tập trung, dễ đưa intent vào test. Em chưa hứa cold-start focus thành công khi member chưa load; đó là edge case cần bổ sung.”

**Tech Lead hỏi tiếp:** alert có đè lên sheet không? Trả lời đúng: implementation hiện là overlay trong MainTabView, không bảo đảm mọi presentation. Test: đang Chat, đang mở sheet, chưa login, cold start và member không tồn tại. Với app ít màn hình, state navigation trực tiếp có thể đủ và ít code hơn.

### 5.2. Làm sao tránh map update quá nhiều khi nhận GPS realtime?

**Trả lời cốt lõi:** không cố ngăn mọi body evaluation; giảm công việc không cần thiết nhưng vẫn giữ freshness. Trước hết đo input rate, work trên main thread, hitch và memory.

**STAR 90 giây, bài tập đề xuất chứ chưa có benchmark:**
- **S:** “Code hiện nhận từng location rồi tìm firstIndex, sửa @Published array.”
- **T:** “Em cần map tương tác mượt, mỗi member vẫn có vị trí mới nhất.”
- **A:** “Em replay workload có kiểm soát, dùng Instruments xác định bottleneck. Sau đó thử dictionary/index theo ID, coalesce theo member và publish batch theo ngân sách freshness; tách camera follow khỏi pin updates.”
- **R:** “Em báo p95 latency, hitch, backlog và số member cập nhật đúng trước/sau trên cùng thiết bị. Hiện chưa có số đo nên không nêu phần trăm cải thiện.”

**Bẫy quan trọng:** removeDuplicates dựa vào MemberLocation.== hiện chỉ so ID sẽ có thể bỏ tọa độ mới. Global debounce có thể trì hoãn vô hạn trên stream liên tục; bufferingNewest(1) làm rơi users khác. Dictionary chỉ tối ưu lookup, không tự tối ưu SwiftUI diff/render. Observation không chữa decode/sort nặng trên MainActor.

### 5.3. Phát hiện và gỡ retain cycle ở socket/location listener?

**Trả lời cốt lõi:** vẽ owner graph và phân biệt leak với listener đăng ký trùng hoặc cache hợp lệ. Memory Graph giúp truy references; Allocations giúp theo dõi lifetime/instance qua nhiều vòng mở đóng. [Apple: Memory investigation](https://developer.apple.com/documentation/xcode/gathering-information-about-memory-use)

**STAR 90 giây, kịch bản điều tra:**
- **S:** “Giả sử mở Chat nhiều lần thấy callback tăng và RAM tăng.”
- **T:** “Em cần biết còn instance nào đáng lẽ phải chết và ai giữ nó.”
- **A:** “Em đếm listener/task, ghi deinit ở Debug, mở/đóng 20 lần rồi xem incoming references. Nếu có owner -> closure -> owner, sửa cạnh capture phù hợp; nếu listener trùng, thêm unsubscribe/lifecycle idempotent. Kiểm tra task giữ self qua for-await.”
- **R:** “Chỉ kết luận sau khi instance cũ được giải phóng, listener không tăng và allocations ổn định sau warm-up. Không nói thêm weak self là xong.”

**Chi tiết repo:** handlers adapter sống qua reconnect, chưa có off token; ViewModel consume stream thay vì đăng ký socket trực tiếp; onTermination gỡ continuation. Chính sách singleton-lifetime của repositories khác lifetime một màn hình. Không dùng unowned cho callback có thể về trễ. Không hủy app-wide location chỉ vì một View biến mất nếu sản phẩm cần tiếp tục chia sẻ.

### 5.4. @Observable và ObservableObject khác nhau về hiệu năng?

**Trả lời cốt lõi:** app hiện dùng ObservableObject. @Observable là lựa chọn mới cần quyết định tương thích iOS 17+, không phải tính năng đã có trong repo.

| Tiêu chí | ObservableObject + @Published hiện tại | Observation hướng nâng cấp |
| --- | --- | --- |
| Cơ chế | Object change publisher, có thể subscribe từng $property bằng Combine | Theo dõi observable property access trong body |
| View sở hữu model | @StateObject | Thường @State |
| View nhận model | @ObservedObject / @EnvironmentObject | Property thường, @Environment, @Bindable khi cần binding |
| Tốc độ stream | Không tự giới hạn | Cũng không tự giới hạn |
| Array locations value | Sửa array có thể invalidate observer | View đọc array vẫn phụ thuộc array, không tự thành per-member subscription |

**STAR 90 giây:**
- **S:** “Deployment target hiện là iOS 16; LiveMap observe một ViewModel có nhiều properties.”
- **T:** “Em cần cải thiện phạm vi invalidation nhưng không bỏ thiết bị đang hỗ trợ tùy tiện.”
- **A:** “Em đo hot path và chia state phù hợp trước. Khi nâng target, em thử migration nhỏ, kiểm tra ownership/binding và so trace, không chỉ đổi annotation.”
- **R:** “Em chỉ công bố cải thiện sau benchmark; hiện câu đúng là app dùng Combine-backed observation, chưa tối ưu bằng @Observable.”

Đây là so sánh cơ chế, không khẳng định một framework luôn nhanh hơn. Nguồn cơ chế Observation đã dẫn tại mục 4.1.

### 5.5. Tổ chức offline caching cho chat và GPS thế nào?

**Trả lời cốt lõi:** tách read cache, outgoing queue và live snapshot. “Có JSON file” không đồng nghĩa offline-first hoàn chỉnh.

| Loại dữ liệu | Hiện tại | Thiết kế tiếp theo, chưa triển khai |
| --- | --- | --- |
| Tin nhắn đã tải | Array trong ChatViewModel | Persistent store theo account/conversation, cursor và sync metadata |
| Tin nhắn đang gửi | REST; text lỗi trả lại draft | Outbox pending/sending/failed/sent, client ID và server dedupe |
| Live location | Queue coalesce điểm cuối | Coalesce theo account/circle/member, lưu capturedAt và freshness |
| GPS history | Queue này không giữ đủ hành trình | Append/batch samples với TTL, dung lượng, dedupe và chất lượng fix |
| SOS | Queue không coalesce | Priority/expiry, acknowledgement state và UI pending/failed rõ ràng |
| Địa chỉ | GeocodeCache RAM | Eviction/TTL; persistence nếu yêu cầu offline thật sự |

**STAR 90 giây:**
- **S:** “Khi mất mạng, live map cần điểm mới nhất nhưng journey cần chuỗi điểm.”
- **T:** “Em phải chọn guarantee theo loại dữ liệu, không dùng chung một chính sách coalesce.”
- **A:** “Em phân tích OfflineQueue hiện tại: drain xóa trước ack. Đề xuất giữ bản ghi tới xác nhận, event ID ổn định, retry hữu hạn và dedupe server; scope dữ liệu theo account.”
- **R:** “Bằng chứng cần là test restart và mất ack không làm mất bản ghi đã commit local, gửi lại không tạo bản ghi nghiệp vụ trùng. Implementation hiện chưa đạt bảo đảm đó.”

**Ma trận test cần làm:** offline trước send; rớt mạng sau server nhận nhưng trước ack; kill app trước local delete; overflow queue; hết TTL; logout user A/login B; storage lỗi; reconnect nhưng session chưa ready. Không hứa exactly-once chỉ từ client. Chọn Core Data/SQLite/file theo query, transaction và dung lượng; nếu target vẫn iOS 16 thì không mặc định dùng SwiftData yêu cầu iOS 17+. [Apple: Migrate to SwiftData](https://developer.apple.com/videos/play/wwdc2023/10189/)

<a id="verification"></a>

## PHẦN 6: GIỚI HẠN KIẾN TRÚC VÀ BẰNG CHỨNG ÔN TẬP

### Những câu không nên nói trong phỏng vấn

- “Coordinator thay thế NavigationStack.” Nó tổ chức state/decision, vẫn dùng NavigationStack.
- “Repo đã dùng @Observable nên không re-render.” Chưa dùng; body evaluation không đồng nghĩa vẽ lại toàn bộ.
- “Map có factory cho moving/stationary/low-battery.” Chưa tìm thấy factory đó; hiện là View composition.
- “Gửi ảnh xong client emit socket xác nhận.” Hiện tạo message qua REST, socket là kênh nhận events.
- “Weak self triệt tiêu mọi leak.” Vẫn phải quản lý subscriptions/tasks/observer lifecycle.
- “Có reconnect và queue nên không mất tin nhắn.” Chat chưa có durable queue; location queue xóa trước ack.
- “SOS overlay luôn đè mọi màn hình.” Hiện chỉ gắn vùng tab, chưa bảo đảm mọi modal.
- “Clean Architecture được compiler bảo vệ.” Hiện folder boundaries trong một target.
- “Bật background mode thì chạy GPS/socket đúng chu kỳ mãi.” Không vượt giới hạn runtime của iOS.

### Kiểm chứng nào đã có, kiểm chứng nào còn thiếu?

[NetworkingContractTests.swift](Tests/NetworkingContractTests.swift) và [test_networking.sh](scripts/test_networking.sh) có kiểm tra DTO/endpoint, Bearer, lỗi HTTP, redaction và trường hợp token cũ. PROGRESS ghi kết quả kiểm thử từ task trước; việc viết tài liệu này không chạy lại build/test hoặc xác nhận hệ thống production.

Chưa dùng tài liệu này để khẳng định test coverage cho Coordinator deep links, memory leaks, ack delivery, offline account isolation hoặc battery/performance. Các mục đó cần test/trace riêng.

### Lộ trình ôn theo cấp độ

| Cấp độ | Cần tự giải thích được | Bằng chứng nên chuẩn bị |
| --- | --- | --- |
| Fresher | Ai sở hữu state, ViewModel gọi gì, protocol/DI là gì | Trace login từ View tới DTO và ngược lại |
| Junior | Ownership/cancellation, socket stream, typed errors, Coordinator | Fake repository test; deep-link matrix; Memory Graph |
| Mid | Consistency, backpressure, readiness, retry/idempotency, giới hạn background | Profiling có workload; failure injection; decision note có trade-off |

Ưu tiên đọc ba chuỗi:

1. **Map:** LiveMapView -> LiveMapViewModel -> ObserveMemberLocationsUseCase -> SocketRealtimeRepository -> SocketIOClientAdapter; sau đó MapCoordinator.
2. **Location:** ShareLocationUseCase -> DeviceLocationRepositoryImpl -> CLLocationService -> MotionActivityService + AdaptiveLocationPolicy + BatterySnapshot.
3. **Ảnh chat:** ChatViewModel.sendPhoto -> SendImageMessageUseCase -> MediaRepositoryImpl -> ImageUploader -> ChatRepositoryImpl.sendImage.

Một pattern chỉ đáng đưa vào câu trả lời khi bạn nêu được **vấn đề, owner, luồng dữ liệu, chi phí và cách kiểm chứng**. Số lượng tên pattern không thay thế khả năng giải thích hành vi thật của ứng dụng.
