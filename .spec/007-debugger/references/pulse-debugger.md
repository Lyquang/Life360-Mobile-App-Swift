# Pulse In-App Debugger

Status: Complete
Date: 2026-10-02

Integrate Pulse/PulseUI in Debug builds. Keep networking and logging in Core/Data;
debug presentation/export state belongs to DebugCoordinator. Provide a root overlay
button and Command-Shift-L shortcut, including before authentication. Replace the
existing profile inspector with Pulse Console. Remote logging is manually enabled
through Pulse settings; declare Bonjour/local-network usage.

Capture REST and image-upload requests/responses/errors via the existing logger
boundary, and Socket.IO events as Pulse messages. Sanitize headers, query strings,
JSON credentials, personal location/chat fields before persistence. Omit binary or
unstructured bodies. Never forward backend Bearer tokens to media storage.

Export native Pulse archives through its console and bounded sanitized JSON with
an AI analysis prompt through an explicit export action. No LLM credential or
endpoint is configured; no automatic external transmission or crash-capture claim.
System stderr warnings are not automatically captured by Pulse.

User clarification: Debug and Release both use the deployed production REST
base `/api/v1` and root Socket.IO host. Remove the localhost environment.

States: debugger hidden/presented, report prepared/exporting, export failure.
Edge cases: localhost unavailable, offline, non-JSON responses, sensitive URLs,
large image payloads, canceled export, no logs, Release build.

Verify Debug/Release simulator builds, networking regression checks and redaction
tests. Document launch/export steps and limitations in TOOLING.md and PROGRESS.md.
