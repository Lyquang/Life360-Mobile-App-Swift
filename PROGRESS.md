# Project Progress - FamilyTracker iOS

AI agents must update this file after every completed task or commit-equivalent change.

Legend:

- `[x]` Complete
- `[-]` In progress
- `[ ]` Not started

## Feature Status

- `[x]` Debug tooling: Pulse/PulseUI 5.2.3 console, Debug root button/keyboard
  shortcut, HTTP/upload/socket logging, local AI JSON export and manual remote logging.

- `[-]` LiveMap: realtime family locations, adaptive location, member cards, tracking controls.
- `[-]` Circles: create/join/list/detail family groups.
- `[-]` Chat: conversation list, realtime messages, chat repositories.
- `[-]` Emergency SOS: SOS use cases, alert banner, coordinator-driven emergency flow.
- `[-]` Background Service: motion-aware location, socket bridge, push notification routing, offline queue.

## Architecture Decisions

- 2026-10-02: Both Debug and Release now select the deployed REST `/api/v1`
  and root Socket.IO host at life360-backend-latest.onrender.com, per user request.
  Removed localhost environment. Read-only deployed health check returned HTTP 200
  and mongodb=connected.
- 2026-10-02: Pulse stores sanitized request/response records through NetworkLogger.
  DebugCoordinator owns console/export presentation. Release keeps NoopNetworkLogger.
  No automatic LLM transmission; export contains a prompt plus at most 100 events.
  Native Pulse sharing and manually enabled remote logging remain available.
  See `.spec/pulse-debugger.md` and `TOOLING.md` section 7.

### Pulse Verification

- Debug and Release unsigned simulator builds passed with Pulse 5.2.3.
- Networking contract tests passed, including redaction and deployed host assertions.
- Installed/launched the Debug app on iPhone 17 Pro Max Simulator and inspected
  the console screenshot; removed a duplicate dismiss button found during inspection.
- Remaining manual checks: document export through Files, remote pairing with Pulse
  on a Mac, physical-device keyboard shortcut, and authenticated backend flows.
  No crash reporter or OS stderr interception is provided by this integration.

- 2026-10-01: Established `AI_RULES.md` as canonical global rules for MVVM-C plus Clean Architecture.
- 2026-10-01: Added Spec-Kit workflow under `.spec/`; every feature change must create or update a spec before Swift edits.
- 2026-10-01: Added local code graph and AST configuration for token-efficient source discovery.
- 2026-10-01: Added Memory MCP config template in `mcp.json` for local design-decision memory.
- 2026-10-02: API phase 1 follows `API_INTERGRATION.MD`; retain Data/Network and
  KeychainSessionRepository rather than duplicate networking/keychain layers.
  Preserve DomainError at the repository boundary; APIError retains HTTP status,
  backend code and field errors. DTO timestamps remain ISO strings for existing mappers.

## API Integration Phases

- `[x]` Phase 1: all 25 documented feature REST endpoints plus versioned health,
  Codable requests/responses including digests, Bearer injection, HTTP/envelope
  error handling, cancellation and explicit JSON encoding failures.
- `[ ]` Phase 2: complete repository services/use cases and AppContainer wiring
  for Google login, interval/digests, conversation detail/update/unread and remaining
  feature contracts. Existing repositories already implement many basic operations.
- `[ ]` Phase 3: connect missing presentation flows, bootstrap LiveMap via REST,
  expose history and harden pagination/upload UI state.

### Phase 1 Verification (2026-10-02)

- `bash scripts/test_networking.sh`: PASS. Compiles the real networking sources;
  decodes and round-trips all 26 REST response examples from the API document;
  checks endpoint contracts, avatar null/omission, cursor parameters and token policy.
  URLProtocol tests cover status errors, field errors, HTML, malformed JSON,
  cancellation, offline mapping, missing token and stale-token invalidation.
- Unsigned Debug build for generic iOS Simulator: PASS with Xcode 26.2.
  Initial sandbox build could not resolve packages; the authorized retry succeeded.
- No production API mutations or live-account integration tests were performed.
- Full endpoint inventory and continuation scope: `.spec/api-integration.md`.

### Follow-up Findings For Phases 2 And 3

- Journey DTO now supports documented `startTime/endTime/points`, but the existing
  domain mapper still expects `arrivedAt/leftAt` and explicit segment endpoints.
  Adapt it in phase 2 to avoid discarding documented journey items.
- UserDTO now decodes `lastKnownLocation`; User/domain mapping and LiveMap still
  need REST bootstrap integration. Current LiveMap observes socket updates only.
- Login/register already persist sessions through use cases; keep Keychain work
  there instead of adding storage dependencies to ViewModels.
- Preserve the existing class names (LoginViewModel, CircleListViewModel,
  ChatViewModel, AppContainer) when wiring the later phases.

## Current Agent Notes

- 2026-10-05: Added `SWIFT_BASICS_AUTH.md`, a beginner Auth walkthrough with
  verified source excerpts, value/reference semantics examples, defer execution
  order, TypeScript comparisons, reading order and self-check questions.
  Documentation only; no application behavior changed.

- 2026-10-05: Added `IOS_INTERVIEW_PLAYBOOK.md`, a Vietnamese React Native-to-iOS
  learning roadmap with six project-based stages and ten STAR interview scenarios.
  Cross-checked source and official documentation; distinguished existing behavior
  from proposed labs, especially queue delivery, task lifetime and location policy.
  Documentation only; no Swift changes, runtime profiling or new performance claims.

- 2026-10-04: Moved CV Skills immediately after Education as requested; retained
  skill content, compact section spacing and project order.

- CV visual preference: restored LinkedIn/GitHub/globe icons and the labels
  QUANG LY THANH NHAT, Lyquang and Portfolio. Reduced section spacing from
  0.28/0.14 cm to 0.20/0.10 cm, preserving content and link destinations.

- CV review: polished Introduction, Experience, Projects, Education and Skills;
  preserved company names, date ranges, GPA, TOEIC and ~40%/80%/under-300ms metrics.
  Clarified PREP's Innovation Challenge context. Added user-confirmed Express.js,
  Spring Boot, PostgreSQL, MongoDB, SwiftUI and MapKit to grouped Skills; shortened
  AI-assisted tooling to one phrase. Did not infer Java/Bootstrap or production use.
  PDF remains 2 pages; extracted word count reduced from 612 to 537 (~12%).
- CV validation: Tectonic compilation has no warnings/errors; inspected both pages
  and PDF text/link extraction. Removed decorative icon fonts causing ToUnicode
  warnings, standardized repository labels to GitHub, and fixed LinkedIn URL
  percent encoding without changing the destination. GitHub/profile/portfolio
  URLs returned HTTP 200; LinkedIn returned 999 and needs a manual browser check.

- CV Introduction: updated the target role to Full-stack Developer, emphasizing
  web/mobile development, Node.js, REST APIs, databases and real-time services.

- CV Skills: added AI-Assisted Development covering MCP integration, agent skills,
  spec-driven development, codebase analysis and context/token optimization tools.

- CV link update: Family Tracker now links to
  `https://github.com/Lyquang/Life360-BackEnd.git` with the label `Link repo`.

- 2026-10-03: CV pagination verified in compiled `main.pdf` (2 pages). Skills is
  last; project order is Smart Learning, Family Tracker, Bookington. Removed the
  whole-project minipage constraint and excessive reserved space: headings stay
  with the first bullet, while page breaks are allowed between complete bullets.
  Projects now follows Experience on page 1 without the large blank area.
  Compiled with Tectonic and visually inspected both pages using PDFKit renders.

- CV follow-up: the full `main.tex` is now available. Reformatted Bookington to
  match Smart Learning: dates/repository in the right column, italic project type,
  two flat achievement bullets and selective bold keywords. Preserved the supplied
  technical claims and other entries; Family Tracker is already project 3.

- CV update: revised the Family Tracker entry in `main.tex` to reflect implemented
  iOS architecture, adaptive tracking, networking contract tests and Pulse diagnostics.
  The supplied file contains only this entry; moving it to Projects position 3
  requires the full Projects section. No standalone LaTeX build is possible without
  the document preamble and custom entry/list environment definitions.

- Current repo root is not a Git repository in this workspace snapshot.
- Existing structure already separates `App`, `Core`, `Domain`, `Data`, `Presentation`, and `Resources`.
- Existing location stack already includes `MotionActivityService`, `AdaptiveLocationPolicy`, `CLLocationService`, and `BatteryMonitor`.

## Update Rule

When finishing a task:

1. Mark affected feature status.
2. Add or update an architecture decision when design changes.
3. Add a short note for important verification results or known gaps.
