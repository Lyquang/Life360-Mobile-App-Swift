# Implementation Plan — M01–M06 v1

## Summary
Hiện thực đúng v1 đã được người dùng duyệt trong session. Giữ iOS16, SwiftUI/MVVM-C,
MapKit/SPM và approval gate; không Backend/auth/consent/location service changes.

## Technical Context / Constitution Check
Swift5 mode/Xcode26.2, iOS16 deployment, ObservableObject/Combine hiện có. MapCoordinator
sở hữu search/navigation; View chỉ layout và local selection/expansion. Preferences
chỉ presentation-local, không tạo Domain abstraction cho theme. Không dependency mới.
Approval evidence trong progress.md. Native Spec Kit/core/constitution giữ nguyên.

## Design Review
V1 mockups/review-version.json là reference. Safe-area top header/search, native
sheet search có input trên; bottom member panel có scroll/44pt labels và callbacks
hiện có. Text/semantic colors thích ứng appearance; không copy map sơ đồ thành tiles.
Local disconnected warning khác member presence; không biến nil presence thành offline.

## Reusability & Optimization Analysis
Tái sử dụng FTColors/FTFont/FTControl/MemberAvatarView/FTButton, DisplayFormat/ISO8601,
MapKit renderers, PlaceSearchView/VM và existing Profile Developer entry. Thêm local
AppearanceSettings ObservableObject + native picker view; publish một selection,
đọc UserDefaults đồng bộ ở init, không recreate coordinators. MemberAvatar cho phép
unknown presence để ẩn dot ở map. Trích header/member panel có trách nhiệm rõ để
native preview harness dùng cùng production UI, không thêm generic framework.
Theo dõi panel bounds bằng preference cho attribution margins; tránh camera jump
khi theme/layout đổi. Không cache/memoization/network/GPS tuning hoặc perf claim.

## Project Structure / files
App root; Settings/AppearanceSettings.swift và AppearanceSettingsView.swift;
FTDesignSystem/FTTextField button foreground; Profile/DebugCoordinator/
NetworkInspectorView; LiveMapView/header/member panel/MemberInfoCard/MapMemberPin/
LiveTrailMapView; RouteMapView appearance; Search view/coordinator detents; paired
resources. Tests riêng ngoài app cho persistence và native component previews.
Không đổi AppContainer/Domain/Data/Core/network/contracts/navigation destinations.

## Verification
Localization/static scoped SwiftLint; native persistence/contrast; Debug+Release
Simulator arm64 builds; native component/appearance preview app và ảnh Light/Dark/
compact/large-text nếu đủ môi trường. App auth/localization regression. Preview
fixtures không gọi Backend, không auth bypass trong app production. Phân biệt
component render với authenticated end-to-end; dữ liệu giả trong test target.

Theme consumer audit: auth backdrop/header text/LanguagePicker và Splash indicator dùng semantic foreground cùng appearance; chỉ màu, giữ auth/state/navigation/layout. Avatar tonal có mapping tên ổn định, không dùng hashValue ngẫu nhiên mỗi process.
