# Kế hoạch triển khai: Circle và danh sách thành viên

## Tóm tắt

Tải danh sách nhóm và thành viên đáng tin cậy, hỗ trợ làm mới và xử lý lỗi. Kế hoạch theo từng giai đoạn và trạng thái lịch sử nằm trong [spec.md](spec.md) và các tài liệu nguồn; không coi kế hoạch là bằng chứng triển khai.

## Bối cảnh kỹ thuật

- iOS 16, SwiftUI/Combine, MVVM-C và Clean Architecture theo `AI_RULES.md`.
- Tách View, ViewModel, Coordinator, Domain và Data/Core; không thêm dependency hoặc sửa backend chỉ để chuẩn hóa spec.
- L10n vi/en cho nội dung do app sở hữu; không log token hoặc vị trí.

## Cấu trúc dự án

- Đặc tả, model, checklist và kế hoạch nằm cùng thư mục tính năng.
- Code thực tế dưới `FamilyTracker/`; kiểm thử theo `FamilyTrackerTests/` và các script hiện có.

## Nguồn triển khai và quyết định

- [api-docs/PRIVACY_AND_CIRCLE_MEMBERSHIP_API_DOC.md](../../api-docs/PRIVACY_AND_CIRCLE_MEMBERSHIP_API_DOC.md)

## Rủi ro và giới hạn

- Response 200 thiếu groupId, tab chuyển trong lúc tải, lỗi giải mã, hủy và retry.

- Trạng thái production, quyền máy thật và khả năng chạy XCTest phải được xác nhận riêng.
