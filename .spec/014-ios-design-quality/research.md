# Nghiên cứu thiết kế

- Decision: native system text styles, 44pt controls, semantic card surfaces và Reduce
  Motion. Rationale: FTFont hiện fixed-size; auth gray material/background không cùng
  semantic contrast context. Preserve rounded SF + palette; không áp generic web theme.
- UI UX Pro Max: Python stdlib search `dynamic type accessibility --stack swiftui`
  trả scalable typography/native labels phù hợp iOS16. UX icon query generic/off-topic;
  retry icons xác nhận semantic distinction, nhưng web imports/fonts không áp vào iOS.
- Mobile Design 1.0.0: Critique rồi Refine/Harden theo user request; đọc craft-floor,
  critique, platform-ios. Dùng source evidence, không chấm visual toàn app khi chưa thấy.
- Apple HIG verified 2026-11-14: accessibility.md, typography.md, color.md (official
  Markdown). Larger text, semantic adaptive colors và assistive control names là basis.
- Alternatives: global theme/brand rewrite, new fonts/icon libraries, custom navigation
  và new design-system hierarchy bị loại vì ngoài scope và tăng regression.
- Tools: UI Pro Max installer npm2.15.0 init --help không hỗ trợ dry-run; thực thi staging
  rồi promote đúng ui-ux-pro-max skill. Mobile installed npx skills1.8.1 project/codex/copy.

- Runtime follow-up: UI tests found the generic validation message is intentionally
  normalized by existing LocalizedErrors; test expectations follow that behavior,
  not an auth logic change. Missing Google keys and stale live-locale text were
  actual presentation defects, fixed in the existing shared/auth scope.
- Screenshot follow-up: accessibility XXXL revealed auto-scaled symbol overlap;
  fixed glyphs inside44pt targets and bounded native fields, then verified frames.
