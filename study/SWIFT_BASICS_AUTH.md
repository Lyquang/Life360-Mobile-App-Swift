# Học Swift qua FamilyTracker: bài 1, dữ liệu và đăng nhập

Dành cho người đã biết TypeScript và mới học Swift. Đối chiếu mã ngày 05/10/2026.

## Cách học bài này

Đọc mục 1-3 trước để hiểu `struct`, `class` và `defer`. Sau đó đọc optional, protocol, Codable và lần theo luồng đăng nhập.

**Phân biệt hai loại ví dụ:** các đoạn ghi “Mã thật” trích nguyên văn 2-3 dòng từ repo, đôi khi là phần đầu của một khai báo nên không chạy độc lập. Các đoạn ghi “Ví dụ thực hành” được viết riêng để giải thích, không phải tính năng đã có trong app.

## 1. Struct: value semantics là gì?

**Value semantics = suy nghĩ theo giá trị.** Khi gán một giá trị cho biến khác, bạn có thể thao tác trên giá trị của biến mới mà không sửa giá trị của biến ban đầu, với các model value thuần như ví dụ dưới.

### Mã thật: dữ liệu phiên đăng nhập

Nguồn: [User.swift](FamilyTracker/Domain/Entities/User.swift), dòng 20-22.

```swift
struct AuthSession {
    let user: User
    let token: String
```

- `struct AuthSession`: định nghĩa kiểu dữ liệu phiên đăng nhập.
- `let user: User`: property tên `user`, kiểu `User`, không được gán lại sau khởi tạo.
- `let token: String`: property token bắt buộc là chuỗi, không phải optional.

Phiên đăng nhập là dữ liệu để truyền giữa các tầng, không phải một đối tượng điều khiển kết nối.

### Ví dụ thực hành: sửa bản B không đổi bản A

Ví dụ độc lập để chạy trong Swift Playground:

```swift
struct ProfileValue {
    var name: String
}

let a = ProfileValue(name: "Quang")
var b = a
b.name = "An"

print(a.name) // Quang
print(b.name) // An
```

Diễn giải từng bước:

1. `a` chứa giá trị ProfileValue có name là Quang.
2. `var b = a` khởi tạo b bằng giá trị của a.
3. `b.name = "An"` sửa giá trị của b, không sửa a.

Sơ đồ tư duy, không phải sơ đồ địa chỉ bộ nhớ:

```text
a: ProfileValue(name: "Quang")
b: ProfileValue(name: "An")
```

### Áp dụng trực tiếp với User trong repo

Mã thật từ [User.swift](FamilyTracker/Domain/Entities/User.swift), dòng 6-8:

```swift
    let email: String
    var avatar: String? = nil
    var batteryLevel: Int? = nil
```

Ví dụ thực hành dùng kiểu `User` của app, chạy trong context có model này:

```swift
let original = User(id: "u1", name: "Quang", email: "quang@example.com")
var draft = original
draft.avatar = "avatar-new.png"

print(original.avatar == nil) // true
print(draft.avatar ?? "missing") // avatar-new.png
```

`draft` phù hợp làm bản nháp chỉnh sửa trước khi lưu. Không thể sửa `draft.name` trong model hiện tại vì property name được khai báo `let`; muốn đổi cần tạo giá trị mới hoặc thiết kế model chỉnh sửa riêng.

**Lưu ý:** value semantics không có nghĩa mọi lần gán đều lập tức sao chép từng byte. Swift có các tối ưu như copy-on-write cho Array. Cũng không có quy tắc “struct luôn ở stack”.

## 2. Class: reference semantics là gì?

**Reference semantics = suy nghĩ theo cùng một object có identity.** Gán biến A sang B không tạo thêm object; hai biến có thể cùng tham chiếu tới một object.

### Mã thật: ViewModel của form đăng nhập

Nguồn: [LoginViewModel.swift](FamilyTracker/Presentation/Scenes/Auth/Login/LoginViewModel.swift), dòng 4-6.

```swift
final class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
```

- `class`: tạo reference type, có identity và lifetime.
- `final`: không cho class khác kế thừa.
- `ObservableObject`: hợp đồng hỗ trợ quan sát thay đổi của object.
- `@Published`: phát thông báo khi property thay đổi để UI quan sát cập nhật.

Form cần quan sát đúng instance ViewModel đang giữ email/password. Không muốn mỗi nơi tự sửa một bản state không liên quan.

### Ví dụ thực hành: sửa qua B thì nhìn qua A cũng thấy thay đổi

Ví dụ độc lập trong Playground:

```swift
final class ProfileReference {
    var name: String

    init(name: String) {
        self.name = name
    }
}

let a = ProfileReference(name: "Quang")
let b = a
b.name = "An"

print(a.name) // An
print(b.name) // An
print(a === b) // true: cung mot instance
```

`init` là initializer, gần với constructor trong TypeScript. `self.name` là property của instance; `name` bên phải là tham số truyền vào.

```text
a ─┐
   ├──> cùng một ProfileReference(name: "An")
b ─┘
```

Điểm dễ nhầm: `let b` không cho gán b sang object khác, nhưng vẫn cho sửa property `var` của object đang được tham chiếu. Gần với `const` chứa object trong JS.

### Đối chiếu TypeScript

Ví dụ thực hành TypeScript:

```typescript
const a = { name: "Quang" };
const b = a;
b.name = "An";
console.log(a.name); // An
```

Đây gần với class reference semantics, không phải hành vi của struct ở ví dụ đầu. `{ ...a }` tạo object mới nhưng chỉ shallow copy; các object lồng bên trong vẫn có thể dùng chung reference.

| Câu hỏi | Struct | Class |
| --- | --- | --- |
| Gán `b = a` có ý nghĩa gì? | Gán giá trị | Gán reference tới cùng instance |
| Sửa property của b có đổi a? | Không với dữ liệu value thuần | Có nếu a và b cùng instance |
| Dùng `let` cho biến thì sao? | Không sửa stored property của giá trị đó | Không đổi reference, nhưng property `var` của object vẫn có thể sửa |
| Kiểm tra cùng object? | Không dùng `===` | Dùng `===` |
| Ví dụ repo | User, AuthSession, UserDTO | LoginViewModel, AuthRepositoryImpl |

**Ngoại lệ cần nhớ, chưa cần đào sâu:** struct có thể chứa một property kiểu class. Khi sao chép struct, property reference đó vẫn có thể trỏ tới cùng object. Vì vậy “struct luôn deep-copy tất cả” là sai. `==` là so sánh theo định nghĩa Equatable, không phải kiểm tra identity; riêng User trong repo định nghĩa bằng nhau theo id.

## 3. Defer không phải khai báo biến mặc định

**`defer` đăng ký một khối code chạy khi thoát khỏi scope hiện tại.** Scope thường là thân hàm hoặc một khối `{ ... }`. Nội dung không chạy ngay lúc gặp dòng defer.

### Đâu mới là giá trị ban đầu?

Mã thật từ [LoginViewModel.swift](FamilyTracker/Presentation/Scenes/Auth/Login/LoginViewModel.swift), dòng 5-7:

```swift
    @Published var email = ""
    @Published var password = ""
    @Published private(set) var isLoading = false
```

`var isLoading = false` khai báo property với giá trị ban đầu false. `private(set)` cho phép đọc từ bên ngoài nhưng giới hạn quyền gán trong phạm vi private của kiểu. Hai dòng trên khởi tạo email/password bằng chuỗi rỗng.

### Defer thực sự làm gì trong submit?

Mã thật từ cùng file, dòng 19-21:

```swift
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
```

Ở dòng 1, loading bật ngay. Dòng 2 xóa lỗi cũ. Dòng 3 chỉ đăng ký việc tắt loading khi rời hàm submit, không tắt ngay lập tức.

Luồng thành công:

```text
submit bắt đầu
  -> isLoading = true
  -> errorMessage = nil
  -> đăng ký defer
  -> chờ login
  -> gọi onAuthenticated(user)
  -> chuẩn bị rời submit
  -> defer chạy: isLoading = false
```

Luồng thất bại: login ném lỗi -> catch gán errorMessage -> rời submit -> defer tắt loading. Nhờ vậy không phải viết lại câu lệnh tắt loading ở cả nhánh thành công và thất bại.

### Ví dụ thực hành: đoán thứ tự in

```swift
func demoDefer() {
    print("1. Bat dau")
    defer { print("3. Don dep") }
    print("2. Dang xu ly")
}

demoDefer()
```

Kết quả: 1. Bat dau -> 2. Dang xu ly -> 3. Don dep.

**Liên hệ TypeScript:** mục đích gần với `finally` trong `try/finally`: dọn dẹp dù nhánh chính kết thúc bình thường hay ném lỗi. Khác biệt là defer gắn với scope chứa nó, không phải riêng một khối try. Không nhầm với `setTimeout`: defer không có thời gian chờ và không tạo task nền.

### Bốn lưu ý đủ dùng lúc mới học

1. Khi scope kết thúc bình thường, qua return hoặc throw, các defer đã được đăng ký sẽ chạy.
2. Nếu return xảy ra trước khi chương trình đi tới dòng defer, defer đó chưa được đăng ký nên không chạy.
3. `await` chỉ tạm ngưng hàm, chưa thoát scope nên không kích hoạt defer. Cancellation cũng không tự kết thúc mọi hàm ngay lập tức; defer chạy khi luồng thực sự thoát scope.
4. Nhiều defer trong cùng scope chạy theo thứ tự ngược lúc đăng ký. Không dùng defer để bảo đảm lưu dữ liệu khi app crash hoặc bị hệ điều hành kill.

## 4. Optional: String khác String? thế nào?

Mã thật từ [CoreDTOs.swift](FamilyTracker/Data/Network/DTOs/CoreDTOs.swift), dòng 38-40:

```swift
    let name: String
    let email: String?
    let avatar: String?
```

`String` phải có một giá trị chuỗi. `String?` có thể chứa chuỗi hoặc nil, gần với `string | null` trong TS có strict null checking. Nil khác chuỗi rỗng: `""` vẫn là String hợp lệ.

Bạn cần mở optional hoặc cung cấp fallback trước khi sử dụng như một String thường. Không dùng `!` để bỏ qua khả năng nil khi chưa có bảo đảm; force unwrap nil gây runtime trap.

## 5. Guard let: kiểm tra đầu vào rồi mới đi tiếp

Mã thật từ [CoreMappers.swift](FamilyTracker/Data/Network/Mappers/CoreMappers.swift), dòng 20-22:

```swift
        guard let token = token ?? accessToken else { throw APIError.serverError("Thiếu token đăng nhập.") }
        return AuthSession(user: user.toDomain(), token: token)
    }
```

Đọc theo thứ tự:

1. `token ?? accessToken`: lấy token nếu không nil; nếu nil mới thử accessToken. `??` tương tự nullish coalescing của JS, không phải `||`.
2. `guard let token = ...`: nếu có giá trị, tạo biến cục bộ token kiểu String, che tên property token optional trong phần code tiếp theo.
3. Nếu cả hai đều nil, nhánh else throw lỗi và thoát hàm. Nhánh else của guard phải thoát scope, ví dụ bằng return hoặc throw.
4. Sau guard, token không còn optional nên dùng được để tạo AuthSession.

Chưa bảo đảm token không rỗng hoặc còn hạn. Optional checking không thay thế validation nghiệp vụ.

## 6. Protocol: hợp đồng giữa các tầng

Mã thật từ [AuthRepository.swift](FamilyTracker/Domain/Repositories/AuthRepository.swift), dòng 3-5:

```swift
protocol AuthRepository {
    func login(email: String, password: String) async throws -> AuthSession
    func register(name: String, email: String, password: String) async throws -> AuthSession
```

Gần với interface TypeScript: protocol mô tả khả năng bắt buộc, không phải cách gọi HTTP cụ thể. Swift yêu cầu khai báo conformance; repo có AuthRepositoryImpl tuân thủ AuthRepository.

Đọc chữ ký login: hàm nhận hai String, có thể chờ bất đồng bộ (`async`), có thể ném lỗi (`throws`), khi thành công trả AuthSession (`->`). UseCase chỉ cần biết hợp đồng này; implementation thật có thể gọi API, implementation giả có thể phục vụ unit test.

## 7. Codable: không phải ép kiểu JSON bằng as

Mã thật từ [CoreDTOs.swift](FamilyTracker/Data/Network/DTOs/CoreDTOs.swift), dòng 36-38:

```swift
struct UserDTO: Codable, Sendable {
    let id: String
    let name: String
```

DTO là Data Transfer Object, biểu diễn dữ liệu trao đổi với API. Codable kết hợp Decodable và Encodable. Với model này, compiler có thể sinh phần decode/encode dựa trên properties; JSONDecoder/JSONEncoder dùng các khả năng đó để chuyển đổi JSON.

Trong cách decode được tổng hợp ở đây, id/name thiếu hoặc sai kiểu gây lỗi; email optional thiếu hoặc null có thể thành nil. Nếu email có giá trị sai kiểu như một number, dấu `?` không khiến decoder tự bỏ qua lỗi đó.

TypeScript `JSON.parse(text) as User` không kiểm tra payload có đúng schema lúc chạy. Swift decode thực sự kiểm tra kiểu/cấu trúc, nhưng vẫn cần validation riêng cho email hợp lệ hoặc token hết hạn. `Sendable` là khái niệm concurrency, có thể để sang bài sau.

## 8. Thứ tự đọc file, không mở toàn repo cùng lúc

### Buổi 1: dữ liệu và chuyển đổi, khoảng 30-45 phút

1. [CoreDTOs.swift](FamilyTracker/Data/Network/DTOs/CoreDTOs.swift): chỉ UserDTO và AuthDataDTO. Xác định property bắt buộc/optional.
2. [User.swift](FamilyTracker/Domain/Entities/User.swift): User và AuthSession. Phân biệt model của app với DTO từ API.
3. [CoreMappers.swift](FamilyTracker/Data/Network/Mappers/CoreMappers.swift): hai extension đầu. Theo dấu token từ optional tới String.

### Buổi 2: hành động đăng nhập, khoảng 45 phút

1. [AuthRepository.swift](FamilyTracker/Domain/Repositories/AuthRepository.swift): đọc hợp đồng login.
2. [AuthUseCases.swift](FamilyTracker/Domain/UseCases/Auth/AuthUseCases.swift): chỉ LoginUseCase; thấy validate, gọi login, lưu session và kết nối realtime.
3. [LoginViewModel.swift](FamilyTracker/Presentation/Scenes/Auth/Login/LoginViewModel.swift): đọc properties, init và submit; lần theo isLoading/defer.
4. [LoginView.swift](FamilyTracker/Presentation/Scenes/Auth/Login/LoginView.swift): chỉ tìm binding email/password và lời gọi submit, bỏ qua trang trí UI.

### Buổi 3: implementation và lắp ghép

1. [RESTRepositories.swift](FamilyTracker/Data/Repositories/RESTRepositories.swift): chỉ AuthRepositoryImpl.
2. [Endpoints.swift](FamilyTracker/Data/Network/Endpoints/Endpoints.swift): chỉ AuthEndpoint.
3. [APIClient.swift](FamilyTracker/Data/Network/APIClient.swift): request -> HTTP response -> DTO.
4. [AppContainer.swift](FamilyTracker/App/DI/AppContainer.swift): nơi tạo và truyền dependencies.
5. [AuthCoordinator.swift](FamilyTracker/Presentation/Coordinators/AuthCoordinator.swift), [AppCoordinator.swift](FamilyTracker/Presentation/Coordinators/AppCoordinator.swift) và [FamilyTrackerApp.swift](FamilyTracker/App/FamilyTrackerApp.swift): ai tạo màn hình, ai quyết định flow.

```text
View -> ViewModel -> UseCase -> Repository -> APIClient -> API
API -> DTO -> Mapper -> AuthSession -> UseCase -> ViewModel
ViewModel -> callback onAuthenticated -> Coordinator quyết định flow
```

Luồng response là sơ đồ rút gọn: sau khi nhận AuthSession, LoginUseCase lưu session, kết nối realtime và trả User về ViewModel. Coordinator không phải trạm bắt buộc cho mọi API request.

## 9. Tự kiểm tra trước khi sang bài tiếp theo

1. Trong ví dụ struct, tại sao sửa b.name không đổi a.name?
2. Trong ví dụ class, tại sao `let b` vẫn cho sửa b.name?
3. `defer { isLoading = false }` có tắt loading ngay không?
4. Đang chờ login tại await thì defer đã chạy chưa?
5. Cả token và accessToken nil thì có tạo được AuthSession không?
6. `email: String?` có chấp nhận JSON email là số không?

### Đáp án ngắn

1. a và b là các giá trị độc lập với model value thuần đó.
2. let cố định reference b; property name của object là var.
3. Không, nó đăng ký việc tắt loading khi thoát scope.
4. Chưa: suspend không phải exit scope.
5. Không qua mapper hiện tại; guard ném lỗi trước khi tạo session.
6. Không trong synthesized decoding ở đây; optional cho phép thiếu/null, không cho phép tùy ý sai kiểu.

**Ba câu chốt:** struct dùng tư duy giá trị; class dùng tư duy cùng một object; defer dùng để dọn dẹp khi rời scope, không phải khai báo giá trị mặc định.
