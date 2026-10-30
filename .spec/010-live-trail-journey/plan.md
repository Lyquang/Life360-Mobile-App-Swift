# Kế hoạch triển khai: Bản đồ, vệt realtime và lịch sử

## Tóm tắt

Hiển thị vị trí và vệt ghi nhận trên bản đồ, cùng lịch sử hành trình được phép xem. Kế hoạch theo từng giai đoạn và trạng thái lịch sử nằm trong [spec.md](spec.md) và các tài liệu nguồn; không coi kế hoạch là bằng chứng triển khai.

## Bối cảnh kỹ thuật

- iOS 16, SwiftUI/Combine, MVVM-C và Clean Architecture theo `AI_RULES.md`.
- Tách View, ViewModel, Coordinator, Domain và Data/Core; không thêm dependency hoặc sửa backend chỉ để chuẩn hóa spec.
- L10n vi/en cho nội dung do app sở hữu; không log token hoặc vị trí.

## Cấu trúc dự án

- Đặc tả, model, checklist và kế hoạch nằm cùng thư mục tính năng.
- Code thực tế dưới `FamilyTracker/`; kiểm thử theo `FamilyTrackerTests/` và các script hiện có.

## Nguồn triển khai và quyết định

- [study/route-on-map.md](../../study/route-on-map.md)
- [study/route-fidelity.md](../../study/route-fidelity.md)
- [study/realtime-trail-phases.md](../../study/realtime-trail-phases.md)
- [api-docs/LIVE_TRAIL_API_DOC.md](../../api-docs/LIVE_TRAIL_API_DOC.md)

## Rủi ro và giới hạn

- Không có dữ liệu, mất quyền, dữ liệu bị trễ, nhiều điểm và mất mạng.

- Trạng thái production, quyền máy thật và khả năng chạy XCTest phải được xác nhận riêng.
