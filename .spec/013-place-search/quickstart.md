# Kiểm tra search/history

## Luồng trong app

1. Đăng nhập tài khoản test, mở tab Bản đồ → Tìm địa điểm.
2. Gõ tên địa điểm: có loading/gợi ý. Đổi query nhanh: kết quả cũ không thay query mới.
3. Chọn gợi ý hoặc nhấn Search để tìm; chọn kết quả để đóng sheet, focus pin và xem tên/địa chỉ.
4. Bỏ chọn pin hoặc bấm theo dõi vị trí của mình; marker thành viên/vệt vẫn hoạt động.
5. Mở search lại để xem query gần đây; thử xóa một mục bằng swipe/context menu và Xóa lịch sử.
6. Thử Quán cà phê/Nhà hàng theo vùng đang xem, kể cả khi không cấp GPS mới.
7. Đóng/mở app: giữ history còn hạn trong cache. Logout/expiry kết thúc session và xóa history account đó; account khác không thấy dữ liệu cũ.
8. Kiểm tra vi/en, Dynamic Type/VoiceOver, mất mạng/throttling/retry và provider trả empty.

Những bước tương tác trên app/thiết bị thật là QA còn cần thực hiện; không coi app
build hoặc fake-provider test là đã thực hiện các bước này. Không test bằng tài
khoản production của người khác. Search không tạo saved place hoặc chuyến đi tự động.

## Checks đã chạy — 2026-11-12

- `bash scripts/test_place_search.sh`: 21 executable tests passed, no Xcode Test target required. Includes TTL/cap/dedup/restart/corrupt cache, account/session isolation, stale responses/errors, cancellation, retry and release of model.
- `bash scripts/test_localization.sh` with existing Homebrew Ruby on PATH: 550 vi/en keys, zero parity/duplicate/missing/helper/literal findings. System Ruby 2.6 lacks `filter_map`; no script/dependency installation was made to work around that.
- Scoped strict SwiftLint using the repository rule set: 13 new/affected production Swift files, zero findings. Whole-tree strict lint still finds pre-existing DesignSystem/GoogleSignInButton spacing violations; not modified for this feature.
- Unsigned Debug Simulator build: pass using Xcode26.2, iOS16 deployment and existing package checkouts, no dependency install or package update. No new search actor warning after fixing delegate bridging.
- Native macOS MapKit adapter smoke with public Ben Thanh Market query/region: 7 suggestions, completion resolution 1 place, text search 1 valid place. No device/user GPS, account, key or backend request. This is not an iOS device/coverage SLA check.
- Working-tree `scripts/test_networking.sh`: fails to compile because its pre-existing edited source list omits SOS check/types. Preserved that edit. Ran committed HEAD script from a temporary file against current sources: REST/SOS contract/refresh/media checks pass, 26 REST examples decoded/round-tripped. No claim the edited working-tree script passes.
- `git diff --check`: pass. No commit/push or production API mutation.

CI now runs the standalone search tests before the existing networking stage.
Scripts/tests do not contact Apple; the public native smoke was a separate session
check in /tmp, not a network requirement in CI. Existing Xcode scheme still has
no runnable XCTest target; this feature does not change project targets.
