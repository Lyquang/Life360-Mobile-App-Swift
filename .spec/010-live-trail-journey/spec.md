# Đặc tả tính năng: Bản đồ, vệt realtime và lịch sử

**Phạm vi**: iOS FamilyTracker · **Trạng thái**: theo từng tài liệu gốc và `PROGRESS.md`; cần kiểm chứng trước khi báo hoàn thành.

## Ranh giới phạm vi

Hiển thị vị trí và vệt ghi nhận trên bản đồ, cùng lịch sử hành trình được phép xem. Tài liệu này là chỉ mục tổng hợp; các spec gốc và quyết định theo giai đoạn được giữ nguyên bên dưới. Không coi đề xuất hoặc kết quả kiểm thử cũ là xác nhận production hiện tại.

## Kịch bản người dùng và kiểm thử

### Câu chuyện 1

Người dùng xem vị trí và vệt của mình hoặc thành viên Circle theo quyền.

**Kiểm thử độc lập:** Chọn thành viên có quyền và xác minh marker/vệt theo dữ liệu server.

### Câu chuyện 2

Người dùng xem lại hành trình hằng ngày và các điểm dừng.

**Kiểm thử độc lập:** Xem ngày có dữ liệu, dữ liệu rỗng và dữ liệu chưa matching; không tự tạo đường giữa hai điểm đầu cuối.

### Trường hợp biên

- Không có dữ liệu, mất quyền, dữ liệu bị trễ, nhiều điểm và mất mạng.

## Yêu cầu chức năng

- **FR-001**: Dùng dữ liệu đường đi được ghi nhận, không tự dựng đường đã đi từ điểm đầu và cuối.
- **FR-002**: Bản đồ iOS 16 dùng MKMapView; phân biệt GPS chưa khớp đường và kết quả matching hợp lệ.

## Thực thể chính

- LiveTrail snapshot/delta, RouteOverlayModel, journey và location fix.

## Tiêu chí hoàn thành

- Phạm vi, điều kiện biên và các bất biến của spec chi tiết được đáp ứng; trạng thái không rõ phải được kiểm tra lại.
- Có kết quả kiểm thử phù hợp và ghi lại các giới hạn chưa xác minh; UI dùng vi/en khi áp dụng.

## Phụ thuộc và ngoài phạm vi

- Backend, quyền iOS và kiểm thử thiết bị thật theo từng spec chi tiết; không giả định hợp đồng chưa được xác nhận.
- Không thay đổi các chức năng khác chỉ vì cấu trúc tài liệu.

## Nguồn tham khảo

Xem [research.md](research.md) và [plan.md](plan.md) để đối chiếu tài liệu gốc và tình trạng triển khai.

