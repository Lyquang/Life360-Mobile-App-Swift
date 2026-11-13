## FamilyTracker repository context and feature path

Read AGENTS.md, AI_RULES.md and .specify/README.md first. Discover only relevant
source, existing UI/logic and Backend docs in api-docs/. Preserve uncommitted work.
No application code changes are allowed during specification.

The configured feature root is `.spec/`. This overrides the upstream `specs/` default
below. If the user supplies an existing feature, use its actual path and do not make
another feature. Otherwise choose the short name, then run this reviewed local
path helper ONCE in dry-run mode, with properly shell-quoted literal description:

`bash .specify/templates/overrides/scripts/create-new-feature.sh --json --dry-run --short-name <name> <description>`

Use the parent directory of its SPEC_FILE as SPECIFY_FEATURE_DIRECTORY for the native creation step below.
Do not run the helper a second time to create files: the native skill resolves and
writes the composed spec template itself. Scan `.spec/` for numbering, never `specs/`.
No branch changes or Git hooks are authorized by this setup.

Read the active templates via native resolve-template.sh and honor all mobile
additions. For substantial clarification rounds create interview.md from the local
supporting template, while retaining native Clarifications in spec.md as the final
requirements source. At completion record phase/approval/contract status in feature
progress.md; no implementation approval is implied.
