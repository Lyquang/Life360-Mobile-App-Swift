# Kế hoạch triển khai: Giám sát pin, mạng và hiệu năng

## Tóm tắt

Thu số đo tổng hợp phục vụ kiểm thử hiệu năng và năng lượng theo giới hạn của iOS. Kế hoạch theo từng giai đoạn và trạng thái lịch sử nằm trong [spec.md](spec.md) và các tài liệu nguồn; không coi kế hoạch là bằng chứng triển khai.

## Bối cảnh kỹ thuật

- iOS 16, SwiftUI/Combine, MVVM-C và Clean Architecture theo `AI_RULES.md`.
- Tách View, ViewModel, Coordinator, Domain và Data/Core; không thêm dependency hoặc sửa backend chỉ để chuẩn hóa spec.
- L10n vi/en cho nội dung do app sở hữu; không log token hoặc vị trí.

## Cấu trúc dự án

- Đặc tả, model, checklist và kế hoạch nằm cùng thư mục tính năng.
- Code thực tế dưới `FamilyTracker/`; kiểm thử theo `FamilyTrackerTests/` và các script hiện có.

## Nguồn triển khai và quyết định

- [study/mobile-monitoring.md](../../study/mobile-monitoring.md)
- [study/mobile-energy-experiments.md](../../study/mobile-energy-experiments.md)

## Rủi ro và giới hạn

- Không có payload MetricKit, simulator không hỗ trợ, chuyển mạng và app background.

- Trạng thái production, quyền máy thật và khả năng chạy XCTest phải được xác nhận riêng.
