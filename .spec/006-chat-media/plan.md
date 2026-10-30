# Kế hoạch triển khai: Chat media: ảnh và ghi âm

## Tóm tắt

Gửi, nhận và phát ảnh và voice note qua dịch vụ media và chat hiện có. Kế hoạch theo từng giai đoạn và trạng thái lịch sử nằm trong [spec.md](spec.md) và các tài liệu nguồn; không coi kế hoạch là bằng chứng triển khai.

## Bối cảnh kỹ thuật

- iOS 16, SwiftUI/Combine, MVVM-C và Clean Architecture theo `AI_RULES.md`.
- Tách View, ViewModel, Coordinator, Domain và Data/Core; không thêm dependency hoặc sửa backend chỉ để chuẩn hóa spec.
- L10n vi/en cho nội dung do app sở hữu; không log token hoặc vị trí.

## Cấu trúc dự án

- Đặc tả, model, checklist và kế hoạch nằm cùng thư mục tính năng.
- Code thực tế dưới `FamilyTracker/`; kiểm thử theo `FamilyTrackerTests/` và các script hiện có.

## Nguồn triển khai và quyết định

- [api-docs/CLOUDFLARE_R2_MEDIA_UPLOAD_API_DOC.md](../../api-docs/CLOUDFLARE_R2_MEDIA_UPLOAD_API_DOC.md)
- [study/media-upload-integration.md](../../study/media-upload-integration.md)

## Rủi ro và giới hạn

- Mất mạng, ticket hết hạn, 401/403/503, ack timeout, giới hạn file và ngắt ghi âm.

- Trạng thái production, quyền máy thật và khả năng chạy XCTest phải được xác nhận riêng.
