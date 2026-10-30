# Hướng dẫn kiểm thử: Circle và danh sách thành viên

## Điều kiện

- macOS, Xcode và simulator phù hợp với project; kiểm tra scheme/test target thực tế trước khi chạy XCTest.
- Chỉ dùng tài khoản và môi trường test được phép khi kiểm tra dữ liệu thật.

## Kiểm tra tự động

```bash
bash scripts/test_networking.sh
bash scripts/test_localization.sh
swiftlint lint --quiet
git diff --check
xcodebuild -project FamilyTracker.xcodeproj -scheme FamilyTracker -destination 'platform=iOS Simulator,name=<ten-simulator>' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project FamilyTracker.xcodeproj -scheme FamilyTracker -destination 'platform=iOS Simulator,name=<ten-simulator>' CODE_SIGNING_ALLOWED=NO test
```

Thay `<ten-simulator>` bằng tên trong `xcrun simctl list devices available`. Nếu scheme không cấu hình Test action, ghi rõ không chạy được XCTest; không tự sửa `project.pbxproj`. Chọn kiểm tra và build Debug/Release theo phạm vi thay đổi thực tế.

## Kiểm thử thủ công

Đối chiếu các kịch bản và trường hợp biên trong [spec.md](spec.md) cùng spec chi tiết; ghi kết quả, thiết bị, môi trường và những mục chưa thử. Không dùng production để thử SOS hoặc thay đổi dữ liệu nếu chưa được phép.
