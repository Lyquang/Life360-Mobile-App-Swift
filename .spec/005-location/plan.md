# Kế hoạch triển khai: Vị trí, tối ưu năng lượng và đồng bộ offline

## Tóm tắt

Chia sẻ vị trí theo chính sách, bảo vệ quyền riêng tư và lưu các điểm đã chấp nhận khi offline. Kế hoạch theo từng giai đoạn và trạng thái lịch sử nằm trong [spec.md](spec.md) và các tài liệu nguồn; không coi kế hoạch là bằng chứng triển khai.

## Bối cảnh kỹ thuật

- iOS 16, SwiftUI/Combine, MVVM-C và Clean Architecture theo `AI_RULES.md`.
- Tách View, ViewModel, Coordinator, Domain và Data/Core; không thêm dependency hoặc sửa backend chỉ để chuẩn hóa spec.
- L10n vi/en cho nội dung do app sở hữu; không log token hoặc vị trí.

## Cấu trúc dự án

- Đặc tả, model, checklist và kế hoạch nằm cùng thư mục tính năng.
- Code thực tế dưới `FamilyTracker/`; kiểm thử theo `FamilyTrackerTests/` và các script hiện có.

## Nguồn triển khai và quyết định

- [study/REALTIME_LOCATION_AND_BATTERY_OPTIMIZATION.md](../../study/REALTIME_LOCATION_AND_BATTERY_OPTIMIZATION.md)
- [study/location/P7-offline-location-buffer.md](../../study/location/P7-offline-location-buffer.md)
- [api-docs/LOCATION_UPDATE_API_DOC.md](../../api-docs/LOCATION_UPDATE_API_DOC.md)
- [api-docs/LIVE_TRAIL_API_DOC.md](../../api-docs/LIVE_TRAIL_API_DOC.md)

## Rủi ro và giới hạn

- Thiết bị bị kill, GPS nhiễu, đồng bộ một phần, 401/429, mất quyền, logout và thay đổi tài khoản.

- Trạng thái production, quyền máy thật và khả năng chạy XCTest phải được xác nhận riêng.
