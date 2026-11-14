## Conditional iOS design review before planning

Read .specify/design-workflow.md and classify UI Impact in the active spec as
NONE/SMALL/SUBSTANTIVE/MAJOR before the native plan steps. For NONE skip design
research entirely. For SMALL do only the local component/HIG checks needed. For
SUBSTANTIVE/MAJOR, use the installed ui-ux-pro-max and mobile-design skills, verify
relevant official Apple HIG, inspect existing UI/tokens and write flows/states,
component reuse, accessibility, native interactions, localization and screenshot
QA into plan.md's Design Review before finalizing the technical plan. Create a
feature-local design.md only if useful; no separate design-system hierarchy.

Skills supply recommendations; Spec Kit alone owns requirements/tasks/approval and
implementation. Preserve safety/privacy, approved product requirements, iOS16 and
existing business/API behavior. Do not silently perform a major redesign. Keep the
existing human approval gate, no second approval process. Check evidence and state
what source-only inspection cannot verify.
