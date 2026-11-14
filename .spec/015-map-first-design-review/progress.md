# Tiến độ — map-first implementation

- Phase: COMPLETE cho M01–M06 v1 được duyệt; remaining release/manual QA ghi rõ.
- Approval: APPROVED; evidence user “Tôi đồng ý toàn bộ những thiết kế của bạn, hãy hiện thực nó,”.
- Scope: map/header/search/member panel, theme/system persistence, Pulse placement,
  realtime warning và paired localization; không mở rộng backlog chưa render.
- Contract: không đổi Backend/API/auth/sharing consent/GPS policy/Domain/Data/Core.
- Refactor: shared components/tokens/foreground, selected-member ID và layout margins;
  navigation/callbacks/state lifecycle hiện có giữ nguyên.
- Verification: Debug cuối PASS; lint33files PASS; localization585keys PASS; appearance
  persistence PASS; search21PASS; native8/8PASS; auth4/4PASS ở vòng trước màu/header cuối.
- Release: đã PASS vòng trước refinements cuối, final repeat SKIPPED theo yêu cầu giảm test.
- User steering: dừng mở rộng runtime/device/repeat; không đánh dấu phần chưa chạy PASS.
- Evidence/docs: verification.md, study.md, plan/analysis và12native PNG. Mockup v1
  HTML/PNG giữ nguyên hash. Task completion chỉ trong tasks.md.
- Remaining: manual/authenticated E2E/VoiceOver/device performance; xem verification.
  Không còn task implementation bắt buộc trong approved batch; không commit/push.
