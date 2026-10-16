# Gộp Nhóm và Tin nhắn: ghi chú phỏng vấn iOS

## Bài toán và quyết định

Trước H1-H5, người dùng phải đi qua hai tab riêng để tìm nhóm, mở chat nhóm hoặc
nhắn riêng cho thành viên. `CirclesCoordinator` quản lý sheet thông tin nhóm,
còn `ChatCoordinator` sở hữu stack hội thoại. Việc mở chat từ sheet phải chuyển
tab và reset stack, nên thứ tự dismiss/push dễ bị race. Giải pháp hiện tại là
`ChatHubCoordinator` sở hữu **một** `NavigationStack` và các sheet tạo/tham gia/
chi tiết nhóm; `MainTabCoordinator` chỉ chọn tab hoặc xử lý route liên tính năng.

Danh sách hợp nhất được xây bằng `ChatHubBuilder`: ghép nhóm và conversation theo
ID, giữ conversation nhóm chưa ghép được, sắp theo hoạt động, tìm tên tiếng Việt
không phân biệt dấu. `ChatHubViewModel` tải nhóm và conversation song song,
nhận sự kiện realtime, gom nhịp presence, và dùng
`GET /conversations/unread-summary` làm nguồn đối soát badge. Direct chat mới
được upsert theo `conversationId`; tin hoặc kết quả tải cũ không được tạo row
trùng.

## Luồng điều hướng và các bất biến

```text
Thông tin nhóm -> mở direct -> API tạo/lấy conversation
               -> stage route -> đóng sheet
               -> sheet.onDismiss -> consume đúng một lần
               -> reset stack -> push chat -> Back về ChatHub

Push chat -> MainTabCoordinator -> chọn tab ChatHub
          -> reset stack -> push conversation
Push SOS  -> MainTabCoordinator -> Map/EmergencyPresentation (không đổi)
```

- Người dùng vuốt đóng sheet trong lúc mở direct: hủy task, bỏ route đến muộn,
  không điều hướng. Một yêu cầu đang chạy vô hiệu hóa thao tác mở direct khác.
- Chat nhóm mở được bằng `conversationId` của group ngay cả khi danh sách
  conversation chưa tải xong. Thông tin nhóm mở từ row hoặc tiêu đề/icon ở chat.
- `ChatHubViewModel` vẫn quan sát message/presence khi tab không hiển thị để badge
  theo kịp; khi vào tab/kéo làm mới thì đối soát lại với server. View không gọi
  `APIClient` hay `URLSession` trực tiếp.
- Sáu tab theo thứ tự: Bản đồ, Trò chuyện, Ở đây, Lộ trình, Địa điểm, Cá nhân.
  iOS có thể gom hai mục cuối vào More. Không thay luồng SOS/location.

## Đánh đổi

| Lựa chọn | Lợi ích | Chi phí / giới hạn |
| --- | --- | --- |
| Một coordinator sở hữu stack và sheet | Không chuyển qua hai navigation owner; Back nhất quán | Coordinator lớn hơn, cần test dismiss và deeplink |
| Upsert ngay rồi refresh nền | Direct/group mới xuất hiện nhanh | REST cũ đến muộn có thể cần đối soát; backend vẫn là nguồn cuối |
| Badge từ unread-summary | Không phụ thuộc trang conversation đang hiển thị | Thêm request đối soát khi mở/refresh |
| Search trên members đã có | Không N+1 request mỗi row | Có thể bỏ sót người nếu backend chỉ trả ID; cần đo payload thật |
| Giữ group chưa có conversation | Không giấu nhóm mới tạo | Row chỉ vào thông tin nhóm tới khi có conversation ID |

## Cách trả lời STAR

**S:** FamilyTracker có hai tab Nhóm/Tin nhắn và hai coordinator, khiến luồng
nhắn riêng từ sheet phải đổi tab, dễ race giữa dismiss và push. **T:** Gộp trải
nghiệm mà không đổi backend, SOS hay thứ tự Back. **A:** Tôi tách phép ghép/sort/
search thành builder thuần để test, đưa route và sheet về một ChatHubCoordinator,
stage route rồi chỉ consume trong `onDismiss`, upsert conversation theo ID, và
đối soát badge bằng unread-summary. **R:** Debug/Release Simulator build cùng
networking/localization/lint đều qua; test source có các ca deeplink, dismiss
một lần và upsert. Chưa có kết quả XCTest hoặc kiểm tra thiết bị thật, nên tôi
không khẳng định đã chứng minh UX trên iPhone.

## Kiểm chứng còn phải làm

Scheme `FamilyTracker` trong workspace này chưa có Test Action, nên `xcodebuild
test` chưa chạy được. Trên hai thiết bị thật cần kiểm tra: tạo/join nhóm; group
chat và direct chat hai chiều không reconnect; swipe đóng sheet khi loading;
Back về hub; push chat/SOS khi đang ở tab khác; badge/unread và presence; tên dài,
Dynamic Type lớn, VoiceOver, Dark Mode. Chưa có bằng chứng runtime rằng
`Conversation.members` luôn đủ cho tìm kiếm mọi người; nếu thiếu, phương án tải
member theo nhóm khi bắt đầu search phải được quyết định ở task riêng.

Chia sẻ QR/mã mời và rời nhóm vẫn là task riêng sau H5; không gọi các tính năng
đó là đã hoàn thành trong luồng gộp tab.
