# AI Tooling Activation Guide

This repo is configured for token-efficient AI work on a Swift/iOS codebase.

## 1. Required First Reads

For every coding task, read:

```bash
sed -n '1,220p' AI_RULES.md
sed -n '1,220p' PROGRESS.md
```

For a feature task, create a spec:

```bash
cp .spec/templates/feature-spec.md .spec/<feature-name>.md
```

## 2. Codebase Skeleton

Generate a compact architecture overview without implementation bodies:

```bash
scripts/codebase_skeleton.sh > codebase-skeleton.txt
```

Use a subdirectory when you only need one layer:

```bash
scripts/codebase_skeleton.sh FamilyTracker/Presentation/Scenes/LiveMap
```

## 3. ast-grep

Install if needed:

```bash
brew install ast-grep
```

Run repository rules:

```bash
ast-grep scan
```

Useful direct queries:

```bash
ast-grep --lang swift -p 'final class $NAME: ObservableObject $$$' FamilyTracker
ast-grep --lang swift -p 'import CoreLocation' FamilyTracker/Presentation
ast-grep --lang swift -p 'try? $EXPR' FamilyTracker
```

## 4. Graphtify

Install or expose the `graphtify` CLI according to your local toolchain, then run from repo root:

```bash
graphtify --config graphtify.yml
```

Expected investigation path:

```text
View -> ViewModel -> Coordinator -> UseCase -> Repository Protocol -> Data Repository -> Core Service
```

## 5. Memory MCP

`mcp.json` defines a local Memory MCP server:

```json
{
  "mcpServers": {
    "memory": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-memory"],
      "env": {
        "MEMORY_FILE_PATH": ".mcp/memory.json"
      }
    }
  }
}
```

Activation depends on the client:

- Codex/Claude-style clients: add or import this `mcp.json` in the client MCP settings.
- First run may need network access because `npx -y @modelcontextprotocol/server-memory` downloads the package.
- Store design decisions as entities such as `ArchitectureDecision`, `FeatureSpec`, `ServiceBoundary`, and `KnownRisk`.

## 6. Repomix

Optional compact export:

```bash
npx repomix --config repomix.config.json
```

Prefer `scripts/codebase_skeleton.sh` when you only need declarations.

## 7. Pulse In-App Debugger

Pulse and PulseUI 5.2.3 are pinned in `project.yml` and the Xcode project.
Xcode resolves them through Swift Package Manager. Build the Debug configuration.

- Tap the waveform button above the app content, including the login screen,
  or press Command-Shift-L with a hardware keyboard. Profile's Network Inspector
  opens the same Pulse console. The root button occupies a safe-area inset.
- Console includes REST/image-upload requests, sanitized headers/JSON, HTTP
  statuses and transport errors. Socket.IO application events are separate logs.
  Recording uses LoggerStore.storeRequest at completion, so requests in flight
  and detailed DNS/TLS URLSession metrics are not shown. Elapsed milliseconds
  are included in the task description and JSON export.
- Use Pulse's built-in share controls for native log archives. Tap the document
  export icon (accessibility label: Export JSON for AI) to save a JSON file with
  an analysis prompt and the latest 100 events from this process. Individual
  report bodies are capped at 8 KB; the report is not a full historical archive.
- JSON export is local. Attach the file to an AI conversation yourself. No LLM
  endpoint/key is configured, and the app does not automatically send logs to AI.
- Pulse Settings -> Remote Logging lets you select a Mac running Pulse. Allow
  Local Network access when prompted. Bonjour `_pulse._tcp` is configured;
  automatic remote connection is not enabled by application startup code.
- Logging and debugger UI are gated by DEBUG; Release uses NoopNetworkLogger.
  The SPM products remain project dependencies in both configurations.

Credential headers/query values, password/token JSON fields, coordinates and
common personal/chat fields are redacted before storage. Non-JSON bodies and
large bodies are omitted. Review exported files before sharing: this is structured
redaction, not a guarantee against secrets embedded in arbitrary field names.

Pulse does not intercept every OS console line or capture process crashes.
Keyboard Auto Layout/haptics warnings still need Xcode's console; use a dedicated
crash reporter or OS crash reports for crashes. Shake-to-open is not installed;
use the button or keyboard shortcut.

The supplied log's `::1.3000 / Connection refused` came from the old localhost
configuration. Both Debug and Release now use the deployed backend as requested:
REST `https://life360-backend-latest.onrender.com/api/v1` and Socket.IO
`https://life360-backend-latest.onrender.com`. No localhost fallback is configured.

Verification: `bash scripts/test_networking.sh` includes nested JSON/header/query
redaction checks and ensures redaction never mutates the actual network request.
Launch argument `-PulseConsole` opens the console for Debug UI smoke checks.

Official integration reference: https://github.com/kean/Pulse
