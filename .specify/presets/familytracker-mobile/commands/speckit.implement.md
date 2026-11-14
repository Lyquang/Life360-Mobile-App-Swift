## Mandatory FamilyTracker approval gate

BEFORE ANY implementation or refactoring in the native steps below, read AGENTS.md,
AI_RULES.md, the active feature spec/plan/tasks and progress.md if present. Verify
explicit user approval for this exact feature scope, architecture, API assumptions
and refactor plan. Evidence must come from a real user message or recorded decision,
not a generated plan, a checklist, workflow setup approval or an agent-created flag.
If absent, present the review package required by .specify/README.md, record
AWAITING_APPROVAL and STOP. Do not modify application code or run implementation.
Existing session approval persists; do not ask again without material scope change.

After approval, reuse existing UI/logic and central networking, preserve iOS16,
Coordinator ownership, location privacy/power policy, vi/en and cancellation. Run
actual relevant checks; refactor only within approved scope. Record evidence in
verification.md and task completion in tasks.md. Study explanations are Vietnamese;
feature progress.md owns phase/approval/API/refactor/docs status and root PROGRESS.md
is a short summary. No unsolicited commit, push, branch switch or dependency upgrade.
