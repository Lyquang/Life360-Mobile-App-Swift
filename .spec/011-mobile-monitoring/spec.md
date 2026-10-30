# Đặc tả tính năng: Giám sát pin, mạng và hiệu năng

**Phạm vi**: iOS FamilyTracker · **Trạng thái**: theo từng tài liệu gốc và `PROGRESS.md`; cần kiểm chứng trước khi báo hoàn thành.

## Ranh giới phạm vi

Thu số đo tổng hợp phục vụ kiểm thử hiệu năng và năng lượng theo giới hạn của iOS. Tài liệu này là chỉ mục tổng hợp; các spec gốc và quyết định theo giai đoạn được giữ nguyên bên dưới. Không coi đề xuất hoặc kết quả kiểm thử cũ là xác nhận production hiện tại.

## Kịch bản người dùng và kiểm thử

### Câu chuyện 1

Lập trình viên xem số đo tổng hợp Debug và đối chiếu bằng Instruments.

**Kiểm thử độc lập:** Mở màn Debug, kiểm tra số liệu tổng hợp và dữ liệu xuất không có tọa độ hoặc token.

### Câu chuyện 2

Nhóm phát triển so sánh các lần đo pin trong điều kiện có kiểm soát.

**Kiểm thử độc lập:** Ghi pin đầu/cuối, thời gian và điều kiện như quy trình thí nghiệm; không kết luận phần pin riêng của app.

### Trường hợp biên

- Không có payload MetricKit, simulator không hỗ trợ, chuyển mạng và app background.

## Yêu cầu chức năng

- **FR-001**: Không log tọa độ, token, danh tính hoặc nội dung tin nhắn; tuân điều kiện đồng ý và phạm vi đã duyệt.
- **FR-002**: Không tuyên bố iOS đo trực tiếp phần pin do riêng app tiêu thụ hoặc MetricKit là realtime.

## Thực thể chính

- Bộ đếm tổng hợp, histogram, trạng thái thiết bị, MetricKit summary.

## Tiêu chí hoàn thành

- Phạm vi, điều kiện biên và các bất biến của spec chi tiết được đáp ứng; trạng thái không rõ phải được kiểm tra lại.
- Có kết quả kiểm thử phù hợp và ghi lại các giới hạn chưa xác minh; UI dùng vi/en khi áp dụng.

## Phụ thuộc và ngoài phạm vi

- Backend, quyền iOS và kiểm thử thiết bị thật theo từng spec chi tiết; không giả định hợp đồng chưa được xác nhận.
- Không thay đổi các chức năng khác chỉ vì cấu trúc tài liệu.

## Nguồn tham khảo

Xem [research.md](research.md) và [plan.md](plan.md) để đối chiếu tài liệu gốc và tình trạng triển khai.

