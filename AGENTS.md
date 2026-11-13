# FamilyTracker — Codex

- Follow `AI_RULES.md` for repository engineering rules and `.specify/README.md`
  for the installed Spec Kit workflow. Read relevant feature artifacts in `.spec/`
  and the applicable Backend contracts in `api-docs/` before feature work.
- Default mode is STANDARD: specify → clarify → plan → tasks → analyze → explicit
  human approval → implement → scoped refactor → verify → document → converge.
  SMALL fixes use the lighter path in `AI_RULES.md`; COMPLEX work adds reviews.
- Before feature implementation or significant refactoring, verify that the user
  explicitly approved the current scope/plan. Record evidence in feature
  `progress.md`. A generated plan, setup approval, or agent-written APPROVED value
  does not authorize a feature. Stop at AWAITING_APPROVAL when approval is absent.
- Preserve existing work, iOS 16 support, MVVM-C boundaries, authentication,
  location/power/privacy policy and Vietnamese/English localization.
- Reuse the existing design system, APIClient, UseCases and repositories. Do not
  introduce a dependency, speculative abstraction or unrelated refactor by default.
- Before every Spec Kit helper shell invocation, run `source .specify/env.sh` in
  that same shell. It selects the CLI tool Python with PyYAML, without a repo venv.
- Native Spec Kit core lives in `.specify/scripts/` and `.specify/templates/`.
  Use `.specify/mobile-preset/` for composable rules and local overrides for
  repository paths/supporting templates; retain `.spec/` as the
  feature root. Follow the installed `$speckit-*` skills; do not invent commands.
- Never create/change Git branches, commit, push or modify Backend source without
  the user's authorization. No Git automation extension is installed.
- Check actual changes when resuming. `tasks.md` owns task completion; feature
  `progress.md` owns phase/approval/contract status; root `PROGRESS.md` is a summary.
  Report real verification results and limitations. Study explanations use Vietnamese.
