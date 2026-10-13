# Project Progress - FamilyTracker iOS

AI agents must update this file after every completed task or commit-equivalent change.

Legend:

- `[x]` Complete
- `[-]` In progress
- `[ ]` Not started

## Feature Status

- `[x]` Engineering CI: unsigned Xcode 26.2 Simulator build, networking/localization
  contract tests, SwiftLint baseline, full-history Gitleaks scan and weekly Dependabot.

- `[x]` Vietnamese / English interface: Login and Profile settings picker,
  persistent device preference, localized labels/errors/durations and permission
  purpose strings. Authenticated-screen manual verification remains.

- `[x]` Debug tooling: Pulse/PulseUI 5.2.3 console, Debug root button/keyboard
  shortcut, HTTP/upload/socket logging, local AI JSON export and manual remote logging.

- `[-]` LiveMap: realtime family locations, adaptive location, member cards, tracking controls.
- `[x]` Location P1: accepted GPS fixes now retain timestamp, horizontal accuracy,
  speed and course through the Domain repository and sharing use case. The 50 m/30 s
  send rule, heartbeat clock, GeoPoint Map/SOS API and socket payload are unchanged.
  Unsigned Simulator build, networking and localization scripts pass. XCTest source
  is present but cannot run until the missing test target is configured; SwiftLint
  is not installed on this machine.
- `[x]` Location P2 instrumentation: Debug-only aggregate counters for socket emits
  by motion state, heartbeat attempts, motion changes, manager reconfiguration,
  invalid-accuracy drops and offline enqueue calls. Battery is sampled at session
  and motion boundaries; Pulse writes summaries every 15 minutes while active,
  on backgrounding and on stop. Release is no-op. Debug/Release Simulator builds
  and contract scripts pass; XCTest target and real-device Energy Log remain pending.
- `[x]` Location P3 privacy fix: heartbeat cancellation now exits before reading or
  emitting the last fix, including cancellation while sleeping and the wake/stop
  race. Logout/session expiry retain their shared stop paths; denied/restricted
  location permission now stops sharing. Debug/Release Simulator builds and contract
  scripts pass; lifecycle XCTest source awaits a configured test target.
- `[x]` Location P4A: pure `LocationSendPolicy`, centralized per-motion baseline
  configuration and CoreMotion-to-Domain state stream are implemented. Scenario
  XCTest source covers cap, accuracy, fallback speed, heartbeat and trailing-edge
  decisions. Debug/Release builds and contract scripts pass; the scheme still has
  no Test action and SwiftLint is unavailable. Runtime sharing remains on 50 m/30 s
  until P4B is separately approved.
- `[-]` Circles: create/join/list/detail family groups.
- `[x]` Circle members response compatibility: deployed 200 payload may omit
  `groupId`; detail sheet now shows retryable load errors and ignores stale member
  responses. Networking contract and Simulator build pass; device check remains.
- `[x]` Groups request cancellation: Circle refresh keeps one ViewModel-owned load
  alive across SwiftUI refresh-task cancellation; Circle, Places, and Journey do
  not show cancellation as a network-error alert. XCTest source added; app build
  passes, but the Xcode project still has no configured test target.
- `[-]` Chat: conversation list, realtime messages, chat repositories.
- `[x]` Direct message entry: accessible member-row action, get-or-create 1-1 flow,
  ordered sheet-to-tab routing, idempotent conversation upsert and empty-chat state.
- `[x]` Chat media: R2 image/voice upload, optimistic delivery, playback, retry,
  cancellation and public-URL deduplication.
- `[-]` Refresh Token Rotation: token-pair Keychain storage, shared single-flight
  refresh, auth/logout flows and Socket.IO rotation integrated. Contract/build/lint
  pass; saved XCTest target and physical-device checks remain.
- `[-]` Emergency SOS: SOS use cases, alert banner, coordinator-driven emergency flow.
- `[-]` Background Service: motion-aware location, socket bridge, push notification routing, offline queue.
- `[x]` Realtime location/battery architecture study: cross-checked Mobile and
  sibling Backend flows, current thresholds, optional Redis cache, Mongo history,
  map rendering and unimplemented optimization targets. See
  `study/REALTIME_LOCATION_AND_BATTERY_OPTIMIZATION.md` (the existing lowercase
  directory; this macOS volume treats `Study/` as the same path).

## Architecture Decisions

- 2026-10-12: Split CI by workload: Xcode build and contract tests run on pinned
  `macos-15`; SwiftLint and Gitleaks use checksum-verified official Linux binaries.
  Workflows have read-only permissions, immutable action SHAs, superseded-run
  cancellation and no signing credentials. XCTest target creation remains separate.

- 2026-10-12: Production REST and Socket.IO now use the canonical Render service
  `life360-backend-6v9n.onrender.com`; networking contract tests and integration
  documentation were updated with the same host.

- 2026-10-05: Inject language preferences through AppContainer and a MainActor
  settings model. Update root SwiftUI locale without replacing coordinator/state
  identity. Use explicit localized bundles for non-View strings; keep user/server
  content verbatim. OS-owned dialogs follow the OS-selected language. See
  `.spec/app-language.md` and `LOCALIZATION.md`.

- 2026-10-12: Both Debug and Release default to deployed REST `/api/v1` and the
  deployed Socket.IO host. Localhost is available only through the explicit
  `FAMILYTRACKER_USE_LOCAL_BACKEND=1` launch environment flag; physical devices may
  provide `FAMILYTRACKER_LOCAL_HOST` for a LAN address.
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

- 2026-10-13: Completed approved P4A only. Added a framework-independent policy
  returning reasoned send/hold/drop decisions and exposed `MotionState` through
  `DeviceLocationRepository`. No pending timer, app-state integration, diagnostics
  reason counters or send behavior migration was performed. See
  `.spec/location-send-policy.md` and `study/location/P4-location-send-policy.md`.

- 2026-10-13: Replaced the heartbeat's cancellation-swallowing `try?` with an
  injected sleeper and explicit pre/post-sleep cancellation exits. Added lifecycle
  regression source for pending sleep, wake/stop race, failed server logout, double
  start and stop/restart. Location authorization revocation routes to the same
  `ShareLocationUseCase.stop()`. See `.spec/location-heartbeat-cancellation.md` and
  `study/location/P3-heartbeat-cancellation.md`.

- 2026-10-13: Implemented approved P2 without changing GPS policy, send threshold,
  socket payload, backend or UI. See `.spec/location-diagnostics.md` and
  `study/location/P2-location-diagnostics.md` for counter definitions and the
  device baseline worksheet. SwiftLint is not installed and the saved Xcode
  project still lacks a runnable `FamilyTrackerTests` target.

- 2026-10-13: Added `LocationFix` with the approved `course` field and a parallel
  repository fix stream, preserving the GeoPoint projection for other screens.
  Regression source covers CLLocation metadata (including negative speed/course),
  old send decisions, compatibility projection and `update_location` payload.
  See `.spec/location-fix.md` and `study/location/P1-location-fix.md`.

- 2026-10-12: Implemented the approved Refresh Token Rotation plan in iOS 16/Combine.
  Added atomic token-pair Keychain updates with legacy JWT fallback, refresh error
  classification/cooldown, one app-wide actor, stale-401 and session-generation guards,
  one retry, auth-body omission from Pulse, logout/logout-all cleanup, Login expiry
  message, fresh-token Socket.IO reconnect and offline queue cleanup. Networking and
  localization contracts, unsigned Simulator build and SwiftLint passed. XCTest source
  was added under `FamilyTrackerTests`, but `xcodebuild test` reports the checked-in
  scheme is not configured for Test Action; no project target was created by the agent.
  See `study/refresh-token-interview-notes.md` and `.spec/refresh-token-rotation.md`.

- 2026-10-12: Audited the new Refresh Token Rotation contract against the iOS session,
  networking, Socket.IO and Pulse code. Wrote the gap analysis and G1-G5 approval plan
  in `study/refresh-token-mobile-integration.md`. No Swift implementation has begun.
  The checked-in Xcode project still lacks a discoverable `FamilyTrackerTests` target;
  its shared scheme has an empty Test Action. Decisions on ambiguous refresh failures
  and the Profile logout-all entry are pending plan approval.

- 2026-10-12: Connected Circle members to direct chat through the existing use case and
  MVVM-C routing. Added self-row protection, 44 pt button/loading state, swipe/context
  shortcuts, friendly retryable errors, localized accessibility, Reduce Motion support,
  ordered sheet dismissal, timestamp-aware conversation upsert and background
  reconciliation. No undocumented socket join event was added. XCTest sources are in
  `FamilyTrackerTests`; the target still needs to be present in the saved Xcode project
  before command-line tests can execute.

- 2026-10-12: Added GitHub Actions for an unsigned FamilyTracker Simulator build,
  networking/localization contract tests, non-strict SwiftLint and full-history secret
  scanning. Added weekly SPM/Actions Dependabot, exact allowlisting for two reviewed
  truncated historical fixtures, failure-only `.xcresult` upload, README badges and CI
  interview notes. Removed the empty orphaned npm lockfile. Temporary runner paths are
  resolved only inside workflow steps, where the GitHub `runner` context is available.
  Repository rulesets and GitHub code-security switches still require one-time
  configuration in the web UI.

- 2026-10-12: Integrated foreground Cloudflare R2 chat media uploads using the
  documented ticket -> raw PUT -> Socket.IO acknowledgement flow. Added JPEG/BlurHash
  image preparation, voice recording/playback, optimistic progress/cancellation,
  timeout reconciliation and self-echo deduplication by public URL, URLCache image
  loading, strict media limits/date decoding and a single-flight refresh seam.
  Production remains the default backend; local mode requires an explicit launch
  environment flag. Networking contract tests and unsigned Simulator build pass.
  Physical-device weak-network, microphone interruption and two-device realtime
  checks remain manual; backend `clientMessageId` and refresh rotation are follow-ups.

- 2026-10-05: Added Vietnamese/English switching and 231 matching translation
  keys. Localization tests, strings plist validation, networking regression tests
  and unsigned Debug Simulator build passed. Login UI test verified immediate
  switching, preservation of typed email and persistence on relaunch; both
  language screenshots inspected. No live-account/backend mutations performed.
  Profile/authenticated screens and physical-device permission prompts still
  need manual checks. Standalone UI test harness does not alter app targets.

- 2026-10-05: Added `FRONTEND_SWIFT_DESIGN_PATTERNS.md`, a source-grounded iOS
  architecture/pattern interview guide with per-pattern classification, code,
  trade-offs and STAR answers plus five advanced scenarios. Documented current
  Combine observation, REST image-message creation, factory scope, SOS presentation
  limits and best-effort offline delivery without claiming unimplemented features.
  Verified 21 Swift excerpts against source, 47 local links and all six requested
  fields across 19 pattern/mechanism sections; five interview scenarios included.
  Documentation only; no Swift edits, new app test results or performance claims.

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
