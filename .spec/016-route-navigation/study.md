# Học từ luồng tìm tuyến và dẫn đường

Trạng thái: triển khai cục bộ; xem [verification](verification.md) để biết phần chưa kiểm chứng. [Yêu cầu](spec.md) và [Backend API](../../../Backend/api-docs/ROUTING_API_DOC.md) là nguồn riêng cho quy tắc và giao tiếp.

Ứng dụng nhận geometry, maneuver và các đoạn `travelMode` từ Backend. `MapCoordinator` mở màn hình chọn tuyến trên MapKit; `RouteNavigationViewModel` giữ preview, lựa chọn và vòng đời; `NavigationSession` chỉ xử lý fix/tiến độ/reroute/arrival trong bộ nhớ. Việc tách session khỏi View giúp quy tắc GPS được kiểm tra bằng Swift harness mà không cần chạy toàn bộ UI.

Khi đang đi, panel lấy tiến độ gần nhất trên polyline để ước tính quãng đường và thời gian còn lại. Đây là phép nội suy từ thời gian ban đầu của provider, không phải ETA giao thông mới; khi mất mạng app giữ cảnh báo dữ liệu cũ. Bản đồ theo vị trí người dùng trong phiên dẫn đường và chỉ fit toàn tuyến khi chọn/tính lại route.

Vị trí dẫn đường dùng một lease riêng trên `CLLocationService`. Người dùng phải bật riêng; tạm dừng chia sẻ Circle không tự tắt dẫn đường, nhưng fix dùng cho dẫn đường không được gửi qua publisher của Circle. Logout kết thúc session, huỷ request và lease. Request preview mang generation để callback muộn không phục hồi tuyến của account/mode trước.

TomTom từng trả câu rẽ tiếng Anh cho `vi-VN`, nên giọng nói dựa trên maneuver code đã biết và bản dịch vi/en của app; code lạ không được đoán hướng. `other` trong tuyến xe máy được giữ nguyên và cảnh báo liên tục, không được gọi là đoạn đi bộ. Walking không có traffic khả dụng ngay cả khi provider trả delay bằng 0.

Hai fix đáng tin cậy cách tuyến hơn 40 m, cách nhau ít nhất 10 giây mới đề nghị tính lại; giới hạn 60 giây và 10 lần mỗi chuyến. Gần đích cần hai fix trong 50 m, cách nhau ít nhất 30 giây. Đây là ngưỡng trong plan đã duyệt, chưa chứng minh tối ưu trên đường Việt Nam. Mất mạng vẫn đi theo tuyến đã tải nhưng không có traffic/reroute mới. App bị iOS dừng tiến trình thì session trong bộ nhớ mất; chưa có phục hồi chuyến.

Mẫu test cục bộ kiểm tra thứ tự chỉ dẫn, GPS nhiễu, offline, cooldown, arrival một lần và DTO walking. Chưa có pilot thiết bị cho nền/giọng nói, nên không dùng simulator build để kết luận khả năng đó.
ViewModel harness còn kiểm tra request preview không bị gọi lặp khi bật vị trí, response mode cũ không thay mode mới, offline không gửi request và lỗi unauthorized dừng lease vị trí riêng. Nó dùng fake dependency để kiểm chứng state machine, không thay thế kiểm tra giao diện và Circle publisher thật.
