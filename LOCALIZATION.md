# Ngôn ngữ ứng dụng: Tiếng Việt và English

## Sử dụng

- Trước đăng nhập: chọn ngôn ngữ bên dưới tên FamilyTracker.
- Sau đăng nhập: **Cá nhân -> Cài đặt -> Ngôn ngữ**.
- Chuyển ngay, không logout, không reset navigation hoặc khởi động lại tracking.
- Ngôn ngữ được lưu trên thiết bị và giữ qua lần mở lại. Mặc định Tiếng Việt.

Tên người dùng, tên nhóm, địa chỉ và nội dung chat/SOS do người dùng hoặc server
cung cấp không được tự động dịch. Thời lượng được định dạng từ số phút, không dùng
chuỗi tiếng Việt đã format sẵn từ API.

## Cấu trúc

- Domain: `AppLanguage`, `LanguagePreferencesRepository`.
- Data: `UserDefaultsLanguagePreferences`, khóa `app.language`.
- Presentation: `LanguageSettingsViewModel`, `LanguagePicker`, locale environment
  tại `FamilyTrackerApp`; không dùng `.id(language)` để dựng lại cây navigation.
- Core: `L10n` lookup bundle rõ ngôn ngữ cho notification và String formatting.
- Resources: `vi.lproj` / `en.lproj`, `Localizable.strings` và `InfoPlist.strings`.

UI literal như `Text("Đăng nhập")` sử dụng localization của SwiftUI. Với String
label do ứng dụng sở hữu, dùng `AppLocalizedText`; với nội dung người dùng, giữ
`Text(value)` để không dịch nhầm. Interpolation trong SwiftUI dùng template key
(`%@`, `%lld`); với String ngoài View, dùng `L10n.format` cùng template cố định.
Không truyền nội dung server/user vào tham số format string.

Không dịch business errors trong Domain; các thông báo validation của app được
tra bản dịch ở Presentation. Chi tiết lỗi mạng/decoding được thay bằng thông báo
thân thiện. Lỗi server không có bản dịch vẫn giữ nguyên để không bịa nội dung.

Hộp thoại cấp quyền, Photos picker và các UI do iOS quản lý theo ngôn ngữ hệ thống
hoặc ngôn ngữ ứng dụng trong Settings của iOS. `InfoPlist.strings` cung cấp purpose
strings song ngữ, nhưng bộ chọn trong app không ép iOS thay ngôn ngữ hộp thoại.
Giao diện bên trong thư viện Pulse phụ thuộc hỗ trợ localization của thư viện đó.

## Kiểm tra

```bash
bash scripts/test_localization.sh
bash scripts/test_networking.sh
```

UI test độc lập không thêm target vào project sản phẩm. Cần XcodeGen, Simulator
đang boot, app đã cài và chưa đăng nhập:

```bash
SIMULATOR_ID=<simulator-udid> bash scripts/test_localization_ui.sh
```

Test nhập email, chuyển Việt -> Anh ngay trên form, xác nhận email không mất,
mở lại app để kiểm tra persistence, rồi đổi về Việt. Không gửi login request hay
tạo tài khoản backend. Ảnh chụp được giữ trong xcresult ở đường dẫn script in ra.
Profile picker và các màn hình cần dữ liệu xác thực vẫn cần kiểm tra bằng tài khoản
test khi có sẵn; không dùng test này để khẳng định đã kiểm tra mọi flow backend.
