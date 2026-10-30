# Kế hoạch triển khai: Pulse và chẩn đoán

## Tóm tắt

Cung cấp công cụ debug mạng và log cho quá trình phát triển, bảo vệ dữ liệu nhạy cảm. Kế hoạch theo từng giai đoạn và trạng thái lịch sử nằm trong [spec.md](spec.md) và các tài liệu nguồn; không coi kế hoạch là bằng chứng triển khai.

## Bối cảnh kỹ thuật

- iOS 16, SwiftUI/Combine, MVVM-C và Clean Architecture theo `AI_RULES.md`.
- Tách View, ViewModel, Coordinator, Domain và Data/Core; không thêm dependency hoặc sửa backend chỉ để chuẩn hóa spec.
- L10n vi/en cho nội dung do app sở hữu; không log token hoặc vị trí.

## Cấu trúc dự án

- Đặc tả, model, checklist và kế hoạch nằm cùng thư mục tính năng.
- Code thực tế dưới `FamilyTracker/`; kiểm thử theo `FamilyTrackerTests/` và các script hiện có.

## Nguồn triển khai và quyết định

- [TOOLING.md](../../TOOLING.md)
- [study/mobile-monitoring.md](../../study/mobile-monitoring.md)

## Rủi ro và giới hạn

- Offline, JSON không hợp lệ, binary, xuất hủy và dữ liệu nhạy cảm.

- Trạng thái production, quyền máy thật và khả năng chạy XCTest phải được xác nhận riêng.
