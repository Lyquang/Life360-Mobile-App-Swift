# Kế hoạch triển khai: SOS và hỗ trợ khẩn cấp

## Tóm tắt

Tạo SOS, tiếp nhận hỗ trợ và phục hồi trạng thái sự cố theo REST và sự kiện realtime. Kế hoạch theo từng giai đoạn và trạng thái lịch sử nằm trong [spec.md](spec.md) và các tài liệu nguồn; không coi kế hoạch là bằng chứng triển khai.

## Bối cảnh kỹ thuật

- iOS 16, SwiftUI/Combine, MVVM-C và Clean Architecture theo `AI_RULES.md`.
- Tách View, ViewModel, Coordinator, Domain và Data/Core; không thêm dependency hoặc sửa backend chỉ để chuẩn hóa spec.
- L10n vi/en cho nội dung do app sở hữu; không log token hoặc vị trí.

## Cấu trúc dự án

- Đặc tả, model, checklist và kế hoạch nằm cùng thư mục tính năng.
- Code thực tế dưới `FamilyTracker/`; kiểm thử theo `FamilyTrackerTests/` và các script hiện có.

## Nguồn triển khai và quyết định

- [study/sos-assistance-integration.md](../../study/sos-assistance-integration.md)
- [study/sos-live-location-backend-request.md](../../study/sos-live-location-backend-request.md)

## Rủi ro và giới hạn

- Timeout và 401/403/404/409/429/503, SOS đóng, location permission, logout và event tới muộn.

- Trạng thái production, quyền máy thật và khả năng chạy XCTest phải được xác nhận riêng.
