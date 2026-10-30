# Hiến chương FamilyTracker iOS

Tài liệu này tóm tắt quy trình cho Spec Kit. [AI_RULES.md](../../AI_RULES.md) là quy chuẩn repo; khi có khác biệt, áp dụng `AI_RULES.md` cùng chỉ dẫn hiện hành của người dùng. Trạng thái thực tế được ghi trong [PROGRESS.md](../../PROGRESS.md); code và hợp đồng backend được xác minh là nguồn kiểm chứng, không suy luận từ tài liệu mẫu.

## Nguyên tắc

1. **MVVM-C và Clean Architecture:** View chỉ hiển thị/binding; ViewModel quản lý trạng thái trên MainActor; Coordinator điều hướng; Domain độc lập UI; Data/Core hiện thực repository và dịch vụ. Tái sử dụng thành phần sẵn có.
2. **Nền tảng:** iOS 16 theo project hiện tại; SwiftUI, Combine/`ObservableObject` tại những phần đang sử dụng. Không tự đưa API chỉ có từ iOS 17 vào tính năng hỗ trợ iOS 16.
3. **Mạng và phiên:** request qua APIClient/repository, token trong Keychain, refresh dùng cơ chế chung. Xử lý lỗi có kiểu, hủy và phản hồi cũ; không tự đoán contract backend.
4. **Riêng tư và vị trí:** không log token, tọa độ hoặc nội dung nhạy cảm. Tôn trọng quyền, pause và vòng đời; không tự vượt cơ chế bảo vệ vị trí vì SOS. Không khẳng định push nền, tiêu thụ pin hay delivery nếu chưa kiểm chứng.
5. **Đa ngôn ngữ:** mọi nội dung do app sở hữu, kể cả accessibility, dùng `L10n.tr` và key trong cả vi/en. Nội dung người dùng và hộp thoại hệ thống có quy tắc riêng trong `AI_RULES.md`.
6. **Phân tích theo bằng chứng:** đọc spec liên quan trong `.spec/`, dùng `rg`, AST/graph khi có ích và xác minh bằng code. Công cụ graph chỉ là chỉ mục, không thay thế code hoặc contract.
7. **Chất lượng và kiểm chứng:** kiểm tra phù hợp với rủi ro và thay đổi. Chạy build/test/lint cần thiết; nếu XCTest target hay thiết bị không khả dụng, báo rõ. Không đặt ngưỡng coverage hoặc tuyên bố test đã chạy khi chưa có bằng chứng.
8. **Quy trình:** cập nhật spec và `PROGRESS.md`; tôn trọng yêu cầu plan-first, duyệt từng giai đoạn, không tự commit/push khi chưa được yêu cầu. Cần xin duyệt chỉ khi yêu cầu của người dùng hoặc quy định áp dụng thực sự đòi hỏi.

## Quản trị

Quy tắc nguồn nằm ở `AI_RULES.md`; sửa tài liệu này khi quy chuẩn liên quan thay đổi. Không chuyển các quy tắc, ngưỡng test hoặc ngôn ngữ từ dự án mẫu sang FamilyTracker mà không có căn cứ.
