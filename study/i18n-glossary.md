# FamilyTracker Localization Glossary

G0 baseline: resources hiện dùng câu tiếng Việt làm key; bảng dưới đây phân biệt cách viết đang thấy trong UI/resources với đề xuất thuật ngữ. Nội dung trong cột đề xuất chưa phải quyết định dịch đã được duyệt.

| Khái niệm | Đang dùng tiếng Việt | Đang dùng tiếng Anh | Đề xuất thống nhất | Ghi chú / cần chốt |
|---|---|---|---|---|
| Circle | Nhóm | Circles, circle, group | **Nhóm** / **Circle** | Chọn “Circle” cho khái niệm nhóm chia sẻ vị trí; tránh lẫn Group nếu backend/API dùng Group. UI `Nhóm của tôi` hiện dịch `My circles`. |
| Member | Thành viên | Member(s) | **Thành viên** / **Member(s)** | Count phải plural-aware; danh xưng không chứa giới tính. |
| Presence: online | Đang online, Đang hoạt động, Thành viên trực tuyến | Online, Active, Active now, Online members | **Đang trực tuyến** / **Online** | Tách connection state (“Connected”) khỏi presence state (“Online”). `Đang hoạt động` hiện là duplicate key với hai nghĩa. |
| Presence: offline | Offline, ⚫ Offline | Offline, Disconnected | **Ngoại tuyến** / **Offline** | “Disconnected” nên dành cho kết nối app/socket, không mô tả thành viên. |
| SOS | SOS Khẩn Cấp, SOS Khẩn Cấp! | Emergency SOS | **SOS khẩn cấp** / **Emergency SOS** | Giữ acronym SOS; thống nhất capitalization/emoji ở UI, title, push. |
| Emergency alert | Cảnh báo khẩn cấp | Emergency alert | **Cảnh báo khẩn cấp** / **Emergency alert** | Server nên gửi event code + parameters; raw message có thể tùy biến. |
| Stay / stay point | Ở đây, Ở lại, Điểm dừng, Đang đứng yên | Stays, Stay, Stops, Staying here | **Điểm dừng** (danh từ), **Đang ở đây** (trạng thái) / **Stay**, **Staying here** | Phân biệt event “đã ở lâu” và đoạn stay trong journey. Cần bạn duyệt từ tiếng Anh cho tab `Ở đây` (hiện `Stays`). |
| Journey | Lộ trình, Hành trình | Journey, journeys, route | **Hành trình** / **Journey** | Hiện có cả `Lộ trình` và `Hành trình`; chọn một thuật ngữ cho phân tích ngày, dùng “route” chỉ đường đi cụ thể nếu cần. |
| Direct message | Nhắn tin riêng, cuộc trò chuyện riêng | Message, private conversation | **Nhắn tin riêng** / **Direct message** | “Nhắn tin” cũng đang dùng cho action chung. Có thể giữ “Cuộc trò chuyện riêng” ở hint, “Nhắn tin” ở nút. |
| Group chat | Nhắn tin nhóm, phòng chat chung | Circle chat, shared chat room | **Chat nhóm** / **Circle chat** | “Chat” đã quen thuộc; nếu muốn thuần Việt, dùng “Trò chuyện nhóm” nhất quán. |
| Place | Địa điểm | Place(s) | **Địa điểm** / **Place(s)** | Tên địa điểm do user tạo không dịch; category labels dịch. |
| Place category | Nhà hàng, Giải trí, Cà phê, Mua sắm, Khác | Restaurant, Entertainment, Cafe, Shopping, Other | Giữ cặp hiện tại | `PlaceCategory.displayName` còn hard-coded Việt; nên dùng key theo enum case. |
| Invite code | Mã mời, Mã mời nhóm | Invite code, Circle invite code | **Mã mời** / **Invite code** | Không cần lặp “nhóm/circle” nếu ngữ cảnh đã rõ. |
| Check-in | Chưa thấy thuật ngữ UI rõ ràng | Chưa thấy | Chưa áp dụng | Nếu thêm tính năng, cần quyết định cách dịch theo hành vi (đánh dấu đã đến hay cập nhật trạng thái vị trí). |
| Location history | Lịch sử vị trí | Location history | Giữ cặp hiện tại | Không dịch địa chỉ reverse-geocode hay nội dung bản đồ do dịch vụ trả về nếu không kiểm soát locale. |
| Voice note | Tin nhắn thoại, ghi âm | Voice note, recording | **Tin nhắn thoại** / **Voice message** | Dùng “ghi âm” cho thao tác recorder, “tin nhắn thoại” cho media đã gửi. |
| Battery | Pin | Battery | **Pin** / **Battery** | Phần trăm có accessibility template; giá trị số không dịch. |
| Connected | Đã kết nối, Đang kết nối, Chưa kết nối | Connected, Connecting, Disconnected | Giữ theo trạng thái kết nối | Không dùng “Online/Offline” thay cho trạng thái socket/backend. |
| Loading | Đang tải… / Đang xử lý… | Loading… / Working… | Dịch theo đối tượng | Không gom thành một label nếu ngữ cảnh cần nói rõ đang tải messages/places/journey. |
| User/system content | Tên, tin nhắn, địa chỉ, custom SOS | User/server-authored content | Không dịch | Không tự dịch tên, chat, tên circle/place, custom message hay raw geocoded address. |

## Cần Duyệt

1. Dùng “Circle” trong tiếng Anh sản phẩm hay “Group” để sát khái niệm phổ thông? Đề xuất: UI English giữ “Circle”, nhất quán API feature hiện tại; không đổi tên backend.
2. Tab `Ở đây` nên là “Stays” (cụ thể về analytics) hay “Places”/“At a glance”? Đề xuất giữ “Stays” nếu tab hiển thị thời lượng thành viên ở một vị trí.
3. Chuẩn hóa `Lộ trình` thành `Hành trình` hay ngược lại? Đề xuất “Hành trình/Journey” cho toàn bộ tính năng theo ngày, và “lộ trình/route” cho tuyến di chuyển.
4. SOS default message có phải text app-generated hay người dùng/server-authored? Chỉ localized default app-generated; không dịch custom message.
