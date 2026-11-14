## FamilyTracker cross-artifact analysis

Keep this analysis read-only. In addition to native spec.md/plan.md/tasks.md,
read the relevant interview.md, Backend API dependencies and actual client/types,
constitution and approval state. Review only the affected source and designs.
Check requirements coverage, endpoint/event authority, nullable/error/auth/date/
pagination mapping, UI states, state ownership, navigation, reusable components/
logic and shared consumers, task dependencies, test availability, localization,
scoped refactor and measurable performance claims. Do not rewrite artifacts or
resolve Backend conflicts silently. Report material inconsistencies with file/
requirement/task references, their blocking impact and a focused next action.

Before implementation the review package and actual user approval must cover the
current scope. If approval is absent, report AWAITING_APPROVAL; findings or completed
analysis never authorize implementation. Scope changes require renewed approval.
