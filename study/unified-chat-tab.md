# H0 - Tab trò chuyện hợp nhất

Trạng thái: **thiết kế, chưa duyệt H0; không sửa Swift**. Khảo sát code ngày 2026-10-16. Các mockup bên dưới dành để duyệt, không mô tả UI đã tồn tại.

**H0 đã duyệt có điều chỉnh.** Source hiện có bảy mục `TabView`, không phải năm; gộp đúng hai mục sẽ còn sáu. Ảnh tab Circles của chủ dự án hiển thị đúng số thành viên/online, vì vậy không coi mapper là lỗi đã xảy ra trên dữ liệu thật. Danh sách tin nhắn chưa có nhãn cho voice note, chưa có unread badge ở tab và chưa lắng nghe `chat:conversation_updated`. Màn thông tin nhóm hiện có sao chép mã mời và nhắn tin riêng; chia sẻ QR/mã mời và rời nhóm là task riêng sau H5.

## Hiện trạng đã kiểm chứng

| Chu de              | Bang chung trong repo                                                                                                                                                                                                                                                      | He qua                                                                                                                                                                                                         |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Tab                 | `MainTabCoordinator.swift` khai bao **7** case/map, circles, chat, duration, journey, places, profile va `MainTabView` tao 7 tab.                                                                                                                                          | Mo ta "5 tab -> 4 tab" khong dung voi source. iOS co the don tab vao More; neu chi go circles+chat thi source con **6** muc, khong phai 4. Can quyet dinh truoc H4.                                            |
| Dieu huong          | `CirclesCoordinator` quan ly `.sheet` create/join/detail; `ChatCoordinator` quan ly `NavigationStack`, reset stack khi mo direct; `MainTabCoordinator` doi sang `.chat` khi mo conversation/deep link.                                                                     | Can mot owner cho route chat + detail, giu thu tu dismiss sheet roi push. SOS qua `EmergencyPresentation` o cap `MainTabView`, khong phu thuoc tab.                                                            |
| Nhóm | `CircleListViewModel.loadGroups()` gọi `FetchMyCirclesUseCase`; `GroupDTO.members` có thể là ID hoặc user object; mapper `compactMap` chỉ giữ object. `FamilyGroup.memberCount` là `members?.count ?? 0`. `loadMembers(for:)` chỉ gọi khi mở detail. | Ảnh chụp đang hiển thị đúng `3 members • 2 online`; chưa có response `GET /groups` thật của phiên này để kết luận lỗi. Không có N+1 hiện tại. Kiểm chứng response/mapper trên thiết bị trước; "chưa có dữ liệu" chỉ là fallback nếu field thiếu. |
| Chat                | `ConversationListViewModel` fetch list, nghe `chat:new_message`, upsert direct theo id va so `lastMessageAt`. `ConversationListView` la `List`, co refresh, chua co search/filter va tab unread badge.                                                                     | Reuse use case; can merge thuần, fetch lai khi tab xuat hien va xu ly conversation moi chua co trong list.                                                                                                     |
| Preview             | `ConversationRow.preview` chi phan biet image, con lai hien `message.content`. `ChatMessageType` co `.voice`; voice thuong co content rong.                                                                                                                                | Nguyen nhan co the lam dong "Ten:" rong; H1 can preview voice va fallback cho media thieu content.                                                                                                             |
| Member/direct       | `GroupDetailView` la sheet + `List`, co `MemberRowView` nut 44pt, swipe khong full, context menu; `OpenDirectChatUseCase` da noi trong `AppContainer`. `DirectMessageFlowTests` kiem tra block nhan doi, dismiss route dung mot lan va upsert.                             | Co the tai su dung; khi doi stack phai sua test dieu huong co chu dich. Search nguoi can du lieu member, hien tai chi tai member cua **mot** nhom khi mo detail.                                               |
| Group info          | `GroupDetailView` hien ten, invite code + copy, member, chat, close. `CircleListView` co nut QR goi `showJoin`, nut + goi `showCreate`.                                                                                                                                    | Chua thay nut chia se QR, chia se ma, roi nhom. Khong duoc goi do la "giu nguyen"; them can scope/API rieng. Nut QR hien tai la loi vao join, can xac minh flow scan trong `JoinGroupSheet`.                   |
| Realtime            | `ChatRepositoryImpl` lang nghe `chat:new_message` va `chat:typing`; `SocketEvent.chatConversationUpdated` chi co ten, chua listener. Presence duoc `SocketRealtimeRepository` phat, nhung `CircleListViewModel` chi cap nhat `members` cua sheet, khong cap nhat `groups`. | Rename/avatar/unread tu event conversation_updated chua co. Reconcile bang REST khi tab hien lai; H2 can quyet dinh co wire event theo contract hay khong.                                                     |
| Model               | `FamilyGroup.conversationId: String?`; `Conversation.groupId: String?`; ca hai nullable. `Conversation.displayName` fallback noi member.                                                                                                                                   | Khong the khang dinh 1:1 cho moi ban ghi. Merge theo id lien ket neu co; co quy tac cho legacy/mismatch.                                                                                                       |
| Debug               | `DebugOverlay` nam tren root `FamilyTrackerApp` trong `#if DEBUG`, dung `.safeAreaInset(edge: .top, alignment: .trailing)`, nut ECG 44pt.                                                                                                                                  | Co the anh huong header goc phai; can test overlap voi QR/+ tren iPhone SE, khong xoa Pulse.                                                                                                                   |
| Localization/design | `L10n.tr`, vi/en `Localizable.strings`; `FTColors`, `FTSpacing`, `FTFont`, `MemberAvatarView`. Một so view cu dung key literal; cac key moi phai theo namespace.                                                                                                           | Tai su dung token, dung Dynamic Type trong row moi. Khong dua ten/tin nhan nguoi dung vao L10n.                                                                                                                |
| Test target         | Co file `FamilyTrackerTests/DirectMessageFlowTests.swift`, nhung `FamilyTracker.xcodeproj/project.pbxproj` hien chi khai bao mot `PBXNativeTarget` FamilyTracker.                                                                                                          | `xcodebuild test` target FamilyTrackerTests chua kha dung tu project hien tai. Khong tu sua pbxproj; can chu repo tao/luu target vao scheme.                                                                   |

### Các điểm chưa có bằng chứng

- **Đối chiếu dữ liệu nhóm:** ảnh chụp trước đó cho thấy `3 thành viên • 2 trực tuyến`; response thật `GET /groups/{id}/members` do chủ dự án cung cấp có ba member object và đúng hai `isOnline=true`. Đây là endpoint chi tiết, **không phải** response thật `GET /groups` nuôi `GroupCard`. Ví dụ `GET /groups` trong `study/API_INTERGRATION.MD` lại có `members` dạng ID; `UserOrIdDTO.user` trả `nil` với ID và `GroupDTO.toDomain()` dùng `compactMap`, nên nếu response list đúng y ví dụ thì card sẽ hiện 0. Chưa thể kết luận backend production trả như ví dụ. H2 cần kiểm tra `GET /groups` trên thiết bị bằng dữ liệu đã che PII, hoặc test fixture từ backend, trước khi thay mapper/UI.
- **Dữ liệu tìm người:** ví dụ `GET /conversations` trong cùng tài liệu có `members` là object với `id/name/isOnline`, nhưng chỉ một member mẫu. Chưa chứng minh conversation nhóm luôn chứa đủ mọi thành viên, nhất là nhóm mới/legacy. Cần đối chiếu số ID với `GET /groups/{id}/members` trên cùng group; nếu đủ thì dùng ngay `Conversation.members` để search, không phát sinh request.
- Backend co the tao group conversation cung circle, nhung iOS model va UI cho phep `conversationId == nil`; can fixture/kiem thu hai tai khoan va API contract truoc khi xem quan he 1:1 la bat bien.
- `GroupDTO.members` khong dam bao member object. `ConversationDTO.members` co ten/presence, nhung khong co bang chung no bao phu tat ca thanh vien moi circle. Tim kiem "Moi nguoi" chi day du neu co du lieu member; khong fetch N+1 ngam.
- Chua co luong `leave group` trong repository/use case/view da khao sat; khong dua vao H1-H5 nhu tinh nang da co.

## Đề xuất UI và wireframe ASCII

Ten mockup: **Tro chuyen / Chats**, icon `bubble.left.and.bubble.right`. Dung `List` (swipeActions, accessibility, lazy rows), header/search co the qua `.searchable` iOS 16. Moi dong group co loi vao ro rang `info.circle` den GroupDetail; context menu copy code la loi tat phu. Chu tren dong la vi du, khong phai key thuc te.

### Đang tải và lỗi

```text
+------------------------------------+   +------------------------------------+
| Tro chuyen               [QR] [+]   |   | Tro chuyen               [QR] [+]   |
| [ Tim tro chuyen va nguoi        ]  |   | [ Tim tro chuyen va nguoi        ]  |
| Tat ca | Nhom | Ca nhan             |   | Tat ca | Nhom | Ca nhan             |
|                                    |   | Khong tai duoc tro chuyen/nhom.      |
|          (spinner)                 |   | [Thu lai]                          |
|                                    |   | Du lieu da tai van giu nguyen.      |
+------------------------------------+   +------------------------------------+
```

### Chưa có nhóm; có nhóm nhưng chưa có tin

```text
+------------------------------------+   +------------------------------------+
| Tro chuyen               [QR] [+]   |   | Tro chuyen               [QR] [+]   |
| [ Tim tro chuyen va nguoi        ]  |   | [ Tim tro chuyen va nguoi        ]  |
| Chua co nhom nao.                  |   | (G) Gia dinh Quang          [i]    |
| [Tao nhom]  [Tham gia bang ma]     |   |     Chua co tin nhan               |
|                                    |   |     Thanh vien: chua co du lieu     |
+------------------------------------+   +------------------------------------+
```

### Danh sách chat và unread

```text
+------------------------------------+
| Tro chuyen               [QR] [+]   |
| [ Tim tro chuyen va nguoi        ]  |
| Tat ca | Nhom | Ca nhan             |
| (G) Gia dinh Quang     11:22  [i]  |
|     Quang: Anh             (2)      |
|     3 thanh vien, 2 truc tuyen      |
|------------------------------------|
| (P*) Dat               Hom qua      |
|     Tin nhan thoai          (1)     |
|------------------------------------|
| (P) Bao Tien           Thu Hai      |
|     Chua co tin nhan                |
+------------------------------------+
```

### Tìm kiếm, kết quả và không có kết quả

```text
+------------------------------------+   +------------------------------------+
| [ quang ly                     x ]  |   | [ quang ly                     x ]  |
| Tat ca | Nhom | Ca nhan             |   | Khong tim thay ket qua.             |
| TRO CHUYEN                         |   | [Xoa tim kiem]                     |
| (G) Nhom Quang Ly                  |   |                                    |
| MOI NGUOI                         |   |                                    |
| (P) Quang Ly ... [Mo tro chuyen]  |   |                                    |
+------------------------------------+   +------------------------------------+
```

### Chat nhóm, thông tin nhóm, direct route

```text
Danh sach -> [<] Gia dinh Quang [i] -> [Dong] Thong tin nhom
                                       | Ten / ma moi [Copy] |
                                       | Thanh vien          |
                                       | Dat [Nhan tin]      |
                                       +---------------------+

Nhan tin rieng tu detail -> cho dismiss sheet xong -> mo direct chat tren
cung NavigationStack; Back ve danh sach. Neu yeu cau Back ve group chat,
can chot va thiet ke route stack khac. Trong khi dang mo, disable tat ca nut.
```

## Luồng dữ liệu và quy tắc thuần để test

`FetchMyCirclesUseCase + FetchConversationsUseCase + du lieu member da co -> ChatHubItem[] -> sort/filter/search -> ViewModel @MainActor -> View`. Match group qua `Conversation.groupId == FamilyGroup.id`, uu tien xac nhan `FamilyGroup.conversationId == Conversation.id`; neu hai gia tri mau thuan thi khong ghep, bao metric tong hop va reconcile. `Conversation.id` la khoa duy nhat cua chat, `group.id` la khoa nhom; hai group trung ten van tach.

- Group co conversation: mot dong, activity theo `lastMessageAt`; group khong conversation: dong co loi vao info, chat action disabled/co retry sau refresh. Group conversation khong co group duoc cap: hien dong chat theo conversation de khong mat tin, info group unavailable cho den khi reconcile, khong suy dien membership.
- Sort: co `lastMessageAt` giam dan; khong co tin theo `group.createdAt` neu parse duoc, sau do id de on dinh. Presence/pin khong thay doi sort. Ding group moi se xuat hien qua reload sau create/join va socket event can duoc xac minh.
- Search: normalize Unicode fold case/diacritic theo locale, thay `đ/Đ` thanh `d` truoc khi match; token hoa theo khoang trang va cho token khop tren ten day du khong can lien ke (`quang ly` khop ten co tu chen giua). Search nguoi can dedupe `User.id` va loai current user; neu member chua tai, hien thong bao ket qua gioi han, khong noi "khong co nguoi" mot cach sai.
- Preview theo `ChatMessageType`: text content; image co caption thi caption hoac nhan anh; voice nhan tin nhan thoai; unknown/empty fallback. Ten sender chi prefix neu co noi dung preview. Date: `DateFormatter`/`Calendar` theo `L10n.language.locale`, so voi `now` tiem vao; hom nay gio, hom qua, trong tuan ten thu, cu hon ngay. Khong log ten/noi dung/ma moi.
- Combine: row model value `Identifiable` + `Equatable`, `ForEach` tach row; chi publish khi snapshot thay doi, coalesce presence ngan neu can; khong publish pin lien tuc tren list. Giữ list va scroll khi refresh loi.

## Lựa chọn Coordinator

| Phuong an                                                                                   | Uu diem                                                        | Gia/Rui ro                                                                   |
| ------------------------------------------------------------------------------------------- | -------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| A. `ChatHubCoordinator` moi so huu stack + sheet; MainTab chi giu mot coordinator (de xuat) | Mot route tree, direct/notification cung vao hub; de test Back | Can chuyen logic tu hai coordinator, H4 phai lam theo nhip va test ky        |
| B. Giữ `ChatCoordinator`, them group sheet va hub root                                      | It file hon, giu route chat cu                                 | ChatCoordinator to phinh, de mang thao tac group vao nham owner              |
| C. Giu ca hai coordinator an trong mot tab                                                  | Giam sua ban dau                                               | Hai navigation stack can dong bo, Back/deep link/phuc tap; khong khuyen nghi |

De xuat A, group info **sheet** de tai su dung `GroupDetailView` hien co. Dismiss programmatic se stage route, chi consume trong `onDismiss`; vuot dong khi request dang tai se cancel va khong navigate. Test route dung mot lan. Title chat group co nut info ro rang >=44pt, direct title giu hien trang.

## Bảng key L10n cần thêm (cả vi và en, H3/H4)

| Key                                | vi                                          | en                                         |
| ---------------------------------- | ------------------------------------------- | ------------------------------------------ |
| `chat.hub.title`                   | Trò chuyện                                  | Chats                                      |
| `chat.hub.search.placeholder`      | Tìm trò chuyện và người                     | Search chats and people                    |
| `chat.hub.filter.all`              | Tất cả                                      | All                                        |
| `chat.hub.filter.groups`           | Nhóm                                        | Groups                                     |
| `chat.hub.filter.direct`           | Cá nhân                                     | Direct                                     |
| `chat.hub.section.chats`           | Trò chuyện                                  | Chats                                      |
| `chat.hub.section.people`          | Mọi người                                   | People                                     |
| `chat.hub.empty.groups`            | Chưa có nhóm nào                            | No groups yet                              |
| `chat.hub.empty.conversations`     | Chưa có tin nhắn                            | No messages yet                            |
| `chat.hub.empty.search`            | Không tìm thấy kết quả                      | No results found                           |
| `chat.hub.action.clear_search`     | Xóa tìm kiếm                                | Clear search                               |
| `chat.hub.action.group_info`       | Thông tin nhóm                              | Group info                                 |
| `chat.hub.action.copy_invite`      | Sao chép mã mời                             | Copy invite code                           |
| `chat.hub.preview.image`           | Ảnh                                         | Photo                                      |
| `chat.hub.preview.voice`           | Tin nhắn thoại                              | Voice message                              |
| `chat.hub.preview.empty`           | Chưa có tin nhắn                            | No messages yet                            |
| `chat.hub.date.yesterday`          | Hôm qua                                     | Yesterday                                  |
| `chat.hub.error.load`              | Không tải được danh sách. Vui lòng thử lại. | Could not load the list. Please try again. |
| `chat.hub.accessibility.unread`    | %lld tin chưa đọc                           | %lld unread messages                       |
| `chat.hub.accessibility.open_info` | Mở thông tin nhóm                           | Open group info                            |

Dung key plural rieng cho member/online/unread thay vi noi chuoi tay; co the tai su dung `members.count.*`, `presence.online_count.*`. `L10n.tr` format duoc tham so va locale tu `L10n.language`. Kiem tra key cu de tranh trung va test vi/en cung commit.

## Execution Plan sau khi duyệt H0

Moi H la **mot commit rieng**, toi da ~8 file; neu phat sinh vuot nguong se tach va xin duyet lai. Truoc moi commit: `git status`, khong de Presentation i18n/refactor ghi de len nhau; H3/H4 chi bat dau khi user xac nhan cua khoa Presentation da mo. Build Debug+Release simulator khong ky, `scripts/test_networking.sh`, `scripts/test_localization.sh`, SwiftLint, `xcodebuild test` neu target da duoc them vao project/scheme; neu chua, bao ro khong chay duoc; `git diff --check`. Bao ket qua that truoc H tiep.

| H                     | File du kien                                                                                                                                                                                                                            | Dieu kien hoan thanh va test                                                                                                                                                     |
| --------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| H1 - logic thuan      | Moi `Domain/Entities/ChatHubItem.swift`, `Domain/Policies/ChatHubBuilder.swift`, `Presentation/Scenes/Chat/ChatHubFormat.swift`, `FamilyTrackerTests/ChatHubBuilderTests.swift` (can chot vi tri formatter de Domain khong import L10n) | Merge theo ID, mismatch, sort on dinh, no messages, image/voice/text, Vietnamese search (`quang ly`, `nhat`, `dat`/`Đạt`), date fake clock/locale, duplicate names. Chua doi UI. |
| H2 - VM/data          | Moi `Presentation/Scenes/Chat/ChatHubViewModel.swift`; sua `AppContainer.swift` neu can factory; `ChatRepositoryImpl.swift`/protocol/DTO chi neu contract event duoc xac minh; tests mock                                               | Load song song 2 danh sach, refresh on appear, dedupe update, error/empty, create/join reconcile, cancel task, unread. Khong N+1. Neu can them >8 file, tach H2a/H2b xin duyet.  |
| H3 - UI chua wire tab | Moi `ChatHubView.swift`, `ChatHubRow.swift`; sua ca hai `Localizable.strings`, Preview/test UI lien quan                                                                                                                                | List search/filter, group info affordance, media preview, 44pt, VoiceOver, Dynamic Type, Dark Mode, Reduce Motion. Preview/Debug route chi neu khong can sua tab.                |
| H4 - routing/tab      | Moi `ChatHubCoordinator.swift`; sua `MainTabCoordinator.swift`, `ChatView.swift`, `GroupDetailView.swift` neu can, `DirectMessageFlowTests.swift`, notification route tests                                                             | Mot tab owner, dismiss->push, Back, deep link chat, SOS khong doi, unread badge. Chot truoc bai toan 7->6 hay 5->4. Khong xoa tab cu cho den H5.                                 |
| H5 - cleanup          | Chi file cu da chung minh khong duoc tham chieu, `PROGRESS.md`, `AI_RULES.md` neu can, `study/unified-chat-tab-interview-notes.md`                                                                                                      | User xac nhan chay that moi go old tab/view; doc interview notes va regression full.                                                                                             |

### Điều chỉnh đã duyệt cho H1-H5 (2026-10-16)

- **Gate trước H1:** chờ chủ dự án báo nguyên văn **"target đã lưu"** sau khi tạo `FamilyTrackerTests` trong project và scheme. Các file test đang có không đủ chứng minh target chạy được. H1/H2 chỉ thêm file Presentation mới, không chỉnh file Presentation hiện hữu; H3/H4 chờ chủ dự án báo mở khóa Presentation/i18n. Trạng thái i18n trong phản hồi hiện là chuỗi lựa chọn `[đã xong / còn dở]`, chưa được xác nhận là phương án nào; không tự suy đoán.
- **H1:** giữ logic thuần, thêm test merge với group/member đã có dữ liệu; không biến giá trị 0 do thiếu `members` thành kết luận "không có thành viên". Search "Mọi người" ưu tiên `Conversation.members` của conversation nhóm nếu đã đầy đủ. Đối chiếu với danh sách từ `GET /groups/{id}/members` trong fixture/test runtime để biết có đủ hay không; chỉ khi thiếu mới trình phương án tải member khi bắt đầu search cho chủ dự án chọn.
- **H2, badge mới:** `ChatEndpoint.unreadSummary` và `UnreadSummaryDTO` đã có, nhưng chưa có phương thức repository/use case dùng chúng. Bổ sung `GET /conversations/unread-summary` làm nguồn chuẩn cho tổng badge, reconcile khi vào tab/kéo làm mới, cập nhật tạm theo `chat:new_message` và khi mark-read, rồi đối soát với server để không trôi số. Chia H2a/H2b nếu vượt khoảng 8 file. Không suy tổng badge chỉ từ trang conversation đang hiển thị.
- **H2, online:** trước hết kiểm tra `GET /groups` thật và mapper trên tài khoản đang hiển thị `3 • 2`. Đề xuất lắng nghe presence, gom nhịp ngắn (ví dụ 300-500 ms) rồi cập nhật duy nhất row có member tương ứng, với refresh khi vào tab/kéo; đổi lại realtime hơn nhưng có thêm logic cache. Phương án đơn giản hơn là chỉ refresh khi vào tab/kéo, ít phát `@Published` nhưng trạng thái chậm và không còn realtime. Không fetch members theo từng row.
- **H3:** test layout ở Dynamic Type lớn nhất trên iPhone SE: tên, giờ, unread badge và nút `[i]` phải không đè nhau. Khi chật, chuyển `[i]` sang dòng phụ/toolbar row mà vẫn có vùng bấm 44pt. Preview thêm direct offline và tên rất dài, bên cạnh online/ảnh/voice/group unread; kiểm tra VoiceOver, Dark Mode và Reduce Motion.
- **H4, thứ tự tab cuối:** `Map` (Bản đồ), `ChatHub` (Trò chuyện), `Duration` (Ở đây), `Journey` (Lộ trình), `Places` (Địa điểm), `Profile` (Cá nhân). Trên tab bar iOS với 6 mục: bốn mục đầu hiện trực tiếp **Map, Trò chuyện, Ở đây, Lộ trình**, rồi **More** chứa Địa điểm và Cá nhân. Không gom thêm tab nào. `Circles` biến mất khỏi `TabView` ở H4 nhưng code cũ chỉ xóa ở H5 sau khi được xác nhận. Badge tổng chưa đọc gắn vào tab Trò chuyện, deep link chat trỏ tới hub; SOS giữ nguyên presentation trên root.

### Checklist thủ công

- Hai may cung circle nhan tin hai chieu, unread/badge va reorder; tao/join ma, QR join, roi nhom **neu backend/app co ho tro**; info group copy code va nhan tin rieng.
- Tim `quang`, `quảng`, `quang ly`, `dat`/`đạt`; ten dai, trung ten; chat anh/voice khong preview rong; group khong message/khong conversation va orphan conversation.
- Bam push chat khi dang o tab khac, SOS khi hub mo; swipe dismiss detail khi loading, Back tu direct; online thay doi lien tuc khong giat/reorder.
- VoiceOver, Dynamic Type lon nhat, Dark Mode, Reduce Motion, iPhone SE + may lon, iOS 16; Debug Pulse overlay khong che QR/+; Release khong co overlay.

## Rủi ro, rollback, backend

- Rui ro quan trong: count online/member khong day du do `GroupDTO.members` co the la ID; cach an toan la hien "chua co du lieu" cho den khi co aggregate/cached detail, khong hien so 0 sai. Member search co the thieu ten. Request aggregate circle + counts la viec backend rieng.
- `chat:conversation_updated` chua duoc xu ly. Can doc contract event truoc khi wire; H2 co the dung REST refresh khi foreground/tab hien de doi soat. Tim kiem toan bo noi dung tin nhan can server search rieng. Backend can dam bao `lastMessage` co media type/day du metadata va group-conversation linkage cho legacy.
- Rollback: H1-H3 doc lap, chua doi root tab. H4 chi doi wiring qua mot commit; neu regression, revert commit H4 (giu H1-H3). H5 chi sau thu nghiem thiet bi that.

## Quyết định H0 và các điểm còn mở

**Đã chốt:** mục 2-9 bên dưới theo phương án đề xuất: giữ bộ lọc; group info bằng sheet, chưa thêm info cho direct; không có dãy avatar trên row; xóa query khi rời tab, không lưu lịch sử; Back từ direct về hub; giữ group thiếu conversation dưới dạng row có detail và retry; mã mời chỉ ở context menu/detail. Mục 1 chốt tên **Trò chuyện / Chats**, icon `bubble.left.and.bubble.right`, sáu mục theo thứ tự H4 ở trên. Mục 9 chốt làm task riêng sau H5.

**Còn mở:** bằng chứng runtime cho `GET /groups` và độ đầy đủ của `Conversation.members` trên tài khoản thật; phương án tải thành viên khi search nếu thiếu (xem dưới); xác nhận tình trạng i18n/mở khóa Presentation; test target. Không truy xuất API riêng tư bằng token trong tài liệu hoặc log.

**Nếu `Conversation.members` chưa đủ cho tìm kiếm người:** (A) chỉ tìm trong dữ liệu đã tải, không thêm request, nhanh và ít tốn mạng nhưng có thể bỏ sót thành viên; (B) khi người dùng bắt đầu tìm, tải `GET /groups/{id}/members` **một lần mỗi nhóm**, song song có giới hạn (đề xuất 3 request đồng thời), cache theo phiên và hủy khi đóng search. B đầy đủ hơn nhưng có độ trễ, nhiều request với người có nhiều nhóm. Chờ chủ dự án chọn sau khi kiểm tra mẫu dữ liệu thật; không thêm N request theo từng dòng.

1. **Tab bar:** source co 7 muc. De xuat gop thanh 6 muc va giu Map, Stays, Journey, Places, Profile khong doi; neu thuc su muon 4 tab, can noi ro 2 muc nao se gom/dua vao More (phat sinh scope). Ten de xuat `Trò chuyện/Chats` + `bubble.left.and.bubble.right`; doi chon `Gia đình/Family` + `person.3`, hoac `Nhóm/Groups` + `person.3` (de hieu nham DM la phu).
2. **Bo loc:** de xuat giu `Tat ca/Nhom/Ca nhan` vi it buoc cho gia dinh nhieu chat; bo thi gon hon nhung tim DM kho hon.
3. **Group info:** de xuat sheet reuse; push co Back tu nhien hon nhung `GroupDetailView` hien tu so huu `NavigationStack`. Chat direct: de nguyen title, chua them info nguoi.
4. **Avatar group:** de xuat chi icon/avatar nhom tren dong; day avatar thanh vien se day cao row, co the xem trong detail.
5. **Search:** de xuat xoa query khi roi tab, khong luu lich su; quay lai tab hien list day du. Doi lai nguoi dung phai go lai.
6. **Back tu direct mo qua group info:** de xuat ve danh sach hub, khong quay lai group chat; it stack lap, nhung mat context group.
7. **Group thieu conversation:** de xuat giu dong group, cho vao detail va retry/refresh; khong tao chat gia neu backend chua co route tao.
8. **Copy ma nhanh:** de xuat context menu + detail, khong hien ma tren row; giam lo ma trong danh sach, nhung them mot thao tac.
9. **Chức năng chưa có:** chia sẻ mã bằng share sheet và tạo ảnh QR có thể làm phía iOS từ `inviteCode` hiện có, miễn backend xác nhận mã đó hợp lệ cho flow tham gia hiện tại; không nhất thiết cần endpoint chia sẻ riêng. Rời nhóm cần backend cung cấp endpoint xác thực (đề xuất `DELETE /groups/{groupId}/members/me` hoặc `POST /groups/{groupId}/leave`), mã lỗi owner/cuối nhóm, và cập nhật group conversation/unread/presence sau khi rời. Tài liệu API hiện chưa mô tả endpoint rời nhóm. Làm task riêng sau H5.
10. **Test gate:** file test co nhung Xcode project chua co test target. Can user luu target/scheme de dung `xcodebuild test`; khong sua `project.pbxproj` bang tay.
