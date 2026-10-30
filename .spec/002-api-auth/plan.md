# Kế hoạch triển khai: API và xác thực

## Tóm tắt

Kết nối API bằng transport dùng chung, bảo vệ phiên đăng nhập và xử lý refresh token an toàn. Kế hoạch theo từng giai đoạn và trạng thái lịch sử nằm trong [spec.md](spec.md) và các tài liệu nguồn; không coi kế hoạch là bằng chứng triển khai.

## Bối cảnh kỹ thuật

- iOS 16, SwiftUI/Combine, MVVM-C và Clean Architecture theo `AI_RULES.md`.
- Tách View, ViewModel, Coordinator, Domain và Data/Core; không thêm dependency hoặc sửa backend chỉ để chuẩn hóa spec.
- L10n vi/en cho nội dung do app sở hữu; không log token hoặc vị trí.

## Cấu trúc dự án

- Đặc tả, model, checklist và kế hoạch nằm cùng thư mục tính năng.
- Code thực tế dưới `FamilyTracker/`; kiểm thử theo `FamilyTrackerTests/` và các script hiện có.

## Nguồn triển khai và quyết định

- [study/API_INTERGRATION.MD](../../study/API_INTERGRATION.MD)
- [api-docs/REFRESH_TOKEN_MOBILE_API_DOC.md](../../api-docs/REFRESH_TOKEN_MOBILE_API_DOC.md)
- [study/refresh-token-mobile-integration.md](../../study/refresh-token-mobile-integration.md)

## Rủi ro và giới hạn

- 401 đồng thời, timeout không rõ kết quả, 429, Keychain lỗi và logout trong lúc refresh.

- Trạng thái production, quyền máy thật và khả năng chạy XCTest phải được xác nhận riêng.
