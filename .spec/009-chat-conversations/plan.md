# Kế hoạch triển khai: Trò chuyện và nhắn tin trực tiếp

## Tóm tắt

Cho phép người dùng xem cuộc trò chuyện, mở chat nhóm hoặc chat 1-1 và theo dõi tin chưa đọc. Kế hoạch theo từng giai đoạn và trạng thái lịch sử nằm trong [spec.md](spec.md) và các tài liệu nguồn; không coi kế hoạch là bằng chứng triển khai.

## Bối cảnh kỹ thuật

- iOS 16, SwiftUI/Combine, MVVM-C và Clean Architecture theo `AI_RULES.md`.
- Tách View, ViewModel, Coordinator, Domain và Data/Core; không thêm dependency hoặc sửa backend chỉ để chuẩn hóa spec.
- L10n vi/en cho nội dung do app sở hữu; không log token hoặc vị trí.

## Cấu trúc dự án

- Đặc tả, model, checklist và kế hoạch nằm cùng thư mục tính năng.
- Code thực tế dưới `FamilyTracker/`; kiểm thử theo `FamilyTrackerTests/` và các script hiện có.

## Nguồn triển khai và quyết định

- [study/direct-message-ui.md](../../study/direct-message-ui.md)
- [study/unified-chat-tab.md](../../study/unified-chat-tab.md)

## Rủi ro và giới hạn

- Mất mạng, đối tượng không còn quyền, socket reconnect và danh sách trống.

- Trạng thái production, quyền máy thật và khả năng chạy XCTest phải được xác nhận riêng.
