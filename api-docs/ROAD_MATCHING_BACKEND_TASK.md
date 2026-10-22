# Backend task: map-match hành trình đã đi lên đường bộ

**Trạng thái:** đặc tả bàn giao, chưa triển khai backend. Không sửa repo `../Backend` trong task mobile. Áp dụng cho người dùng xem hành trình của chính mình **và** thành viên có chung Circle, theo cùng quy tắc quyền hiện có của `GET /api/v1/history/:userId/journey`. Không có đường riêng cho người khác.

## Vấn đề và mục tiêu nghiệm thu

`detail=geometry` hiện trả `points` GPS, `gaps` và `path` làm thưa (`../Backend/src/domain/journey.js:82-119`); **không có map matching**. Khi chỉ có vài điểm, nối chúng bằng `MKPolyline` cho đường chim bay. Mục tiêu là trả hình học theo đường bộ **chỉ ở nơi đủ dữ liệu để suy ra**, giữ raw `points`/`gaps` để kiểm tra và fallback trung thực. Không dùng tuyến điều hướng `MKDirections` giữa đầu/cuối để tuyên bố đó là hành trình đã đi.

### Đề xuất hợp đồng additive

Giữ `GET /api/v1/history/:userId/journey?date=YYYY-MM-DD&detail=geometry`, metadata B6a, B6b/B6c khi hoàn tất, và tất cả field `points`, `gaps`, `path` cũ theo quy tắc tương thích đã duyệt. Thêm **tùy chọn** vào mỗi moving segment:

```json
{
  "roadGeometry": {
    "version": 1,
    "status": "matched",
    "encoding": "polyline6",
    "runs": [
      {
        "fromPointIndex": 0,
        "toPointIndex": 2,
        "data": "<synthetic-encoded-polyline>",
        "confidence": 0.91
      }
    ],
    "sourceRevision": "synthetic-revision",
    "generatedAt": "2026-01-02T00:10:00.000Z"
  }
}
```

Ví dụ là **sơ đồ tổng hợp**, không phải kết quả mã hóa hợp lệ để đem giải mã. Đề nghị chốt cách mã hóa và scale (`polyline6`), giới hạn số đỉnh, `version`, `sourceRevision` và trạng thái `matched | partial | insufficient_data | unavailable | failed` bằng contract test. `runs` tách theo các **observed runs** của `points` sau thinning; chỉ số tham chiếu đúng mảng `points` được trả, giống `gaps`. Mỗi run bắt đầu/kết thúc ở fix tương ứng, tăng thời gian; **không** có geometry xuyên qua gap. `confidence` phải có định nghĩa/calibration trong tài liệu backend; dưới ngưỡng chất lượng thì không trả `matched` chỉ để đường trông đẹp. Nếu engine không thể khớp, trả `runs: []` và status thích hợp, không tự dựng đường thẳng.

Đề nghị cân nhắc `provider` trong metadata kỹ thuật nhưng **không log/hiển thị** thông tin nhạy cảm hoặc URL chứa tọa độ. Không nhúng tên người, địa chỉ hay token vào geometry. Một segment có thể `partial`: chỉ một số run hợp lệ; client vẽ các run đó, run thiếu hiện trạng thái chưa có tuyến. Khoảng trống chỉ được mô tả bằng `gaps`, nét đứt/nhãn ước tính hoặc không nối, tuyệt đối không thành phần của encoded road geometry.

### Pipeline và giới hạn

1. Dùng fix GPS đã lưu với `recordedAt`/accuracy; xác nhận `LOCATION_HISTORY_DENSE_ENABLED` trên môi trường thử. Không tăng tần suất định vị iOS một cách ngầm để phục vụ vẻ ngoài của bản đồ.
2. Tách run theo gap trước khi match; kiểm tra chất lượng fix, độ dày theo thời gian/quãng cách và các vị trí ngoại lệ. Không match các run quá ngắn hoặc hai điểm quá xa rồi chọn một tuyến tùy ý.
3. Match mỗi run độc lập trên hạ tầng/backend, lưu/cache theo `(userId, date, segmentId, geometryPolicy.version, nguồn điểm/revision, engine version)`; vô hiệu cache khi lịch sử nhận thêm điểm offline hoặc chính sách thay đổi. Không làm N lời gọi bên thứ ba mỗi lần mở Journey.
4. Giữ quyền xem bản thân/cùng Circle và 403 hiện có; không trả geometry của người không được phép. Có chính sách xóa/cache retention đồng bộ với lịch sử vị trí; mã hóa và hạn chế quyền truy cập theo hạ tầng hiện có.
5. Đánh giá engine/provider, license và điều khoản **hiển thị kết quả trên Apple Maps**, chi phí vận hành (đặc biệt plan Render hiện tại), mạng và riêng tư khi chuyển lịch sử cho bên thứ ba. Chưa chọn provider trong tài liệu này.

### Kiểm thử và rollout

- Fixture **tổng hợp**: nhiều góc phố, đường song song, hai điểm quá thưa, mất GPS giữa chừng, ở yên, off-road, một run khớp/một run không, đích ở Circle khác. Không đưa track thật vào repo hoặc log.
- Contract: raw `points` và `gaps` không đổi, chỉ số run hợp lệ, không có run xuyên gap; version/status lạ hoặc malformed geometry phải có fallback an toàn trên mobile. Client cũ vẫn đọc response cũ vì field mới additive.
- Đo trên thiết bị thật: đường bám đường bộ ở những run đủ dữ liệu; track thực và kết quả khác nhau phải được ghi nhận như **sai số suy luận**, không công bố độ chính xác nếu chưa đo. Chỉ xuất thống kê tổng hợp: số run matched/unmatched, confidence distribution, thời gian xử lý, kích thước response, chi phí và p50/p90 mật độ fix; không xuất tọa độ.
- Rollout qua cờ backend: deploy contract trước, thử trên dữ liệu tổng hợp và tài khoản thử, rồi bật từng phần. Nếu engine lỗi/quá tải, `roadGeometry.status=unavailable` và trả GPS metadata cũ; mobile không vẽ đường chim bay đặc.

## Ranh giới mobile

Sau khi backend bàn giao contract và fixture tổng hợp, iOS bổ sung DTO/mapper, giải mã geometry phiên bản đã hỗ trợ, kiểm tra chỉ số/run, vẽ đường bộ bằng `RouteMapView` cho **mọi `userId` được phép xem**. Khi không có matched run, hiển thị mốc GPS/trạng thái không đủ dữ liệu thay vì đường thẳng đặc. Các bước iOS vẫn theo phase gate trong [route-fidelity.md](../study/route-fidelity.md); không gộp với sửa Socket/P7 hoặc hướng chỉ đường đến thành viên.
