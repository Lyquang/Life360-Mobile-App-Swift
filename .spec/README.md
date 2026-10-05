# Spec-Kit Workflow

Every feature or user-facing behavior change starts with a short spec. Specs are intentionally small so agents can load them cheaply and avoid reading unrelated implementation files.

## Required Sequence

1. Copy `.spec/templates/feature-spec.md` to `.spec/<feature-name>.md`.
2. Fill in objective, inputs/outputs, modeled state, edge cases, architecture path, and verification.
3. Implement only after the spec is coherent.
4. Update the spec if architecture or behavior changes during implementation.
5. Update `PROGRESS.md` after completion.

## Naming

Use lowercase kebab-case:

```text
.spec/live-map-background-location.md
.spec/emergency-sos-deeplink.md
.spec/circles-invite-flow.md
```

## Token Discipline

- Prefer reading a feature spec plus `scripts/codebase_skeleton.sh` output before opening source files.
- Use `rg` and AST queries to jump to declarations.
- Open implementation bodies only for files directly touched by the current task.
