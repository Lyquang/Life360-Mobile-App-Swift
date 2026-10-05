# Local MCP Memory

`mcp.json` stores Memory MCP data at `.mcp/memory.json`.

Recommended memory entities:

- `ArchitectureDecision`: lasting design choices.
- `FeatureSpec`: implemented or planned feature contracts.
- `ServiceBoundary`: ownership between Core, Data, Domain, Presentation, and Coordinators.
- `KnownRisk`: technical debt, missing checks, and production risks.

Do not store secrets, tokens, private keys, or personal user data here.
