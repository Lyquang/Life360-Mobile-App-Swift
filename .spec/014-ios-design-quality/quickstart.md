# Kiểm chứng

1. `bash scripts/test_specify.sh` — native + conditional design integration.
2. `bash scripts/test_localization.sh` với Homebrew Ruby hiện có trên PATH.
3. Build app bằng Xcode26.2, Debug/Release, iOS Simulator; xem verification.md cho log.
4. `scripts/test_design_ui.sh <simulator-uuid>` chỉ trên Simulator QA riêng đã cài app,
   logged out; không dùng tài khoản thật. Tests không submit thông tin hợp lệ lên server.
5. Xem screenshots/ và evidence matrix trong verification.md; không coi source inventory
   là ảnh của authenticated screens. VoiceOver spoken output/device energy còn manual.
