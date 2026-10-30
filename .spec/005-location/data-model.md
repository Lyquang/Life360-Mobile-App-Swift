# Mô hình dữ liệu: Vị trí, tối ưu năng lượng và đồng bộ offline

## Thực thể và trạng thái

- `LocationFix`, `GeoPoint`, `BufferedLocationPoint`, motion state và trạng thái socket.
- LocationBuffer và LocationSyncCoordinator quản lý điểm chờ và batch.

## Quy tắc

Xem yêu cầu, ranh giới và bất biến trong [spec.md](spec.md) và spec chi tiết. Không tự thêm field vào contract backend.
