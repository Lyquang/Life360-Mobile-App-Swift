# Global Repository Rules - FamilyTracker iOS

This file is the source of truth for all AI agents working in this repository. Every change must preserve the architecture, power policy, concurrency safety, and task-memory workflow below.

## Agent Operating Contract

1. Read this file, `PROGRESS.md`, and any relevant `.spec/` document before editing Swift code.
2. Use scoped `rg` searches and `scripts/codebase_skeleton.sh` before opening broad source trees. AST/graph tools are optional when installed; do not require rebuilding deleted graph caches for routine work.
3. Use the mode policy below: substantive feature work needs approved feature artifacts; SMALL fixes need only proportional context, verification and documentation.
4. Keep changes scoped to the current feature boundary. Do not rewrite unrelated layers.
5. Update `PROGRESS.md` after every completed task or commit-equivalent change.
6. For non-trivial code investigations, use the FamilyTracker Graphify index when
   available and relevant; query it narrowly, check freshness and verify every
   conclusion against source. If unavailable or stale, use `rg`/AST or rebuild as
   documented in `TOOLING.md`. Never use the copied `graphify-out/` from another project.

## Architecture Boundaries

The repository follows MVVM-C plus Clean Architecture:

```text
Presentation/View -> Presentation/ViewModel -> Coordinator -> Domain/UseCase -> Domain/Repository Protocol -> Data/Core Service
```

### View - SwiftUI

- Views render UI and bind state only.
- Views may import `SwiftUI`, local design-system modules, and view-specific UI frameworks such as `MapKit` only when the view is purely presenting data.
- Views must not import `CoreLocation`, call network clients, use databases, touch keychain, or start background services directly.
- Views may call ViewModel intent methods and Coordinator navigation commands.

### ViewModel

- ViewModels own UI state using `@Observable`, `ObservableObject`, or Combine as already established by the surrounding code.
- ViewModels format display data and expose user intents.
- ViewModels must not directly create navigation stacks, present sheets, parse deep links, or trigger push-notification routing.
- ViewModels depend on UseCases or Repository protocols, not concrete network/database services.
- UI state mutations must run on `@MainActor`.

### Coordinator

- Coordinators own 100% of navigation, sheet/modal presentation, and deep-link routing.
- SOS push-notification deep links must enter through a Coordinator, then delegate business work to UseCases.
- Do not place navigation decisions in Views, ViewModels, Data repositories, or Core services.

### Domain / Use Cases

- Domain is pure Swift business logic.
- Domain must not import `SwiftUI`, `UIKit`, `MapKit`, `CoreLocation`, or concrete networking/storage frameworks.
- UseCases orchestrate Repository protocols and return typed values or typed errors.
- Repository protocols live in `FamilyTracker/Domain/Repositories`.

### Data

- Data implements Domain repository protocols.
- DTO mapping stays in Data/Network/Mappers or a nearby Data mapper.
- Data may depend on Core services, but Domain must never depend on Data.

### Core Services

- Platform capabilities are centralized in `FamilyTracker/Core`, including `LocationService`, `SocketClient`, `KeychainManager`, logging, push notification, image storage, and battery/motion services.
- Core services must expose small protocol-friendly APIs so UseCases and repositories can be tested without platform side effects.

## Life360-Class Location And Battery Rules

- `CMMotionActivityManager` must be used alongside `CLLocationManager` for background location features.
- Stationary state must reduce power use by lowering accuracy and/or switching to significant-change monitoring.
- Walking/running/cycling/automotive states may enable precise tracking with an adaptive `distanceFilter`.
- Low Power Mode or low battery must degrade accuracy and increase `distanceFilter`.
- Never add always-on high-accuracy GPS loops without an explicit adaptive policy.
- Background location changes must handle authorization denial, reduced accuracy, app suspension, no network, and offline queueing.

Current expected services:

- `FamilyTracker/Core/Location/MotionActivityService.swift`
- `FamilyTracker/Core/Location/AdaptiveLocationPolicy.swift`
- `FamilyTracker/Core/Location/CLLocationService.swift`
- `FamilyTracker/Core/Device/BatteryMonitor.swift`

## Historical Journey Map Rules

- The deployment target is iOS 16. Draw historical polylines in the dedicated
  `RouteMapView` (`MKMapView` via `UIViewRepresentable`); do not replace LiveMap
  or use iOS 17-only SwiftUI `MapPolyline` in this feature.
- Use only recorded GPS points for a traveled route. Never infer a traveled
  polyline from segment start/end coordinates when the path is absent.
- Keep route simplification and geometry in Domain without MapKit/CoreLocation;
  prepare large models off the main actor and publish UI state on `@MainActor`.
- Keep moving segments separate across stays or data gaps. Marker, timeline,
  error, and empty states must remain usable with VoiceOver and vi/en localization.
- Treat location history as sensitive: never log coordinates, member names, or
  addresses. Do not claim speed/accuracy filtering without per-point metadata.
- Routing *to* a member with `MKDirections` is a separate approved task, not a
  fallback when recorded history lacks path points.

## Concurrency And Memory Safety

- Use `[weak self]` in escaping closures and long-lived async tasks that capture reference types.
- Prefer structured concurrency; cancel tasks in `deinit` or lifecycle stop methods.
- UI state changes require `@MainActor`.
- Shared cross-task data must be isolated by an actor, `@MainActor`, or a clearly safe synchronization primitive.
- Types crossing concurrency boundaries should be `Sendable` when practical.
- Avoid retain cycles between Coordinators, ViewModels, Services, delegates, timers, sockets, and notification observers.

## Error Handling

- Use typed errors. Avoid broad `try?` except for explicitly non-critical best-effort work.
- User-facing flows must map errors into recoverable UI state.
- Prefer one central app-level error vocabulary, backed by Domain-specific cases when needed:

```swift
enum AppError: Error, Equatable, Sendable {
    case unauthorized
    case permissionDenied(PermissionKind)
    case networkUnavailable
    case server(message: String)
    case decoding
    case offlineQueueFailed
    case unknown(message: String)
}
```

If the existing code uses `DomainError`, bridge or extend it deliberately rather than creating duplicate unrelated error enums.

## Multi-language Rule (Mandatory)

- Every app-owned user-visible or audible string must be localized for Vietnamese and English: SwiftUI/UIKit text, placeholders, navigation, alerts, accessibility, user-facing errors, local notifications, and date/number/unit formatting.
- New app-owned strings must use `L10n.tr("<area>.<type>.<name>")`; add the same key to both `vi.lproj/Localizable.strings` and `en.lproj/Localizable.strings` in the same change. `L10n.tr` treats strings as verbatim; do not wrap its result in a second localization lookup.
- Do not add display literals through `Text("...")`, `Button("...")`, `Label("...")`, `navigationTitle("...")`, `NSLocalizedString`, or `String(localized:)`. Resolve the string with `L10n.tr` first and pass the resulting `String` to SwiftUI. Existing legacy call-sites may be migrated feature-by-feature; do not add new ones.
- Use positional format placeholders for variable content; never concatenate translated fragments. Use `L10n.plural` with `.one`/`.other` resource keys for counts and test 0/1/multiple values. Date, number, distance, speed, and percentage formatters must use the selected in-app locale, not `Locale.current` implicitly.
- User-facing errors must map stable error codes/cases to localized keys. Never display raw server `message` text as a localization strategy; use a translated generic fallback for unknown codes. Do not put tokens, another user's email, or coordinates in user-facing errors.
- Each feature spec/execution plan that adds UI must have a `Localization` section listing new keys with Vietnamese and English copy, plus the longest string to check for clipping. AI-generated translations are drafts until reviewed.
- A UI task is not complete until `scripts/test_localization.sh` passes. Add new languages by adding a complete `.lproj/Localizable.strings` resource; do not require feature-specific source changes.
- Exclusions: user-authored content (names, group/place names, chat/custom SOS text), product brand `FamilyTracker`, technical protocol/JSON keys, logs/Pulse/diagnostics, Debug-only tooling, and OS-owned dialogs. `InfoPlist.strings` purpose text follows the OS language and cannot be controlled by the in-app picker.

## File Placement Rules

- `FamilyTracker/Presentation/Scenes/<Feature>`: Views and ViewModels.
- `FamilyTracker/Presentation/Coordinators`: navigation and deep links.
- `FamilyTracker/Domain/UseCases/<Feature>`: feature business operations.
- `FamilyTracker/Domain/Entities`: pure models.
- `FamilyTracker/Domain/Repositories`: protocols.
- `FamilyTracker/Data/Repositories`: concrete repository implementations.
- `FamilyTracker/Core/<Capability>`: platform services.

## Required Feature Workflow

The installed native commands are Codex `$speckit-*` skills. See `.specify/README.md`
for setup, commands, artifact templates and actual verification tools. Core assets
are managed by Spec Kit; project customization belongs in local overrides.

- SMALL: trivial UI corrections or bounded bug fixes without material behavior,
  architecture or API changes. Read relevant context, clarify if needed, fix,
  verify and update relevant docs. The user's direct fix request authorizes this
  bounded work; do not force a full interview or artificial approval loop.
- STANDARD (default): context/API discovery → specify → clarify as needed → plan →
  tasks → analyze → explicit human approval → implement → scoped refactor → verify
  → documentation/study → converge.
- COMPLEX: add discovery, API/interview, requirements and architecture reviews,
  then the STANDARD gates and milestone delivery. Material changes need renewed
  approval. No automatic branch creation or commit/push.

Before feature implementation or significant refactoring, present requirements,
API sources/endpoints/status, UI states/screens, reused/new components and logic,
state ownership, architecture, files, refactor/optimization scope, tasks, risks and
verification plan. Record AWAITING_APPROVAL until the user approves the current
scope. User approval from this session persists; never manufacture it or ask again
for unchanged approved work. Setup approval is not approval of any app feature.

Read only relevant source/designs and API docs before planning. Resolve material
conflicts across spec/interview/plan/tasks/API/source/constitution before approval.
Keep native spec.md/plan.md/tasks.md/research.md/data-model.md/quickstart.md/contracts/
when relevant. Interview answers stay consistent with native spec Clarifications.
Use interview.md for substantive rounds, verification.md for evidence, study.md
in Vietnamese for substantive features, and feature progress.md for phase/approval/
API/refactor/docs status. Supporting templates are in the local overrides folder.
`tasks.md` alone owns task completion; root PROGRESS.md summarizes feature progress.
On resume, inspect actual changes and remaining task IDs before proceeding.

## Clean Code, Reuse and Scoped Refactoring

Prefer readable names, cohesive small responsibilities and simple control flow.
Apply DRY/KISS/YAGNI without extracting misleading shared abstractions. Search
Presentation/Common, Presentation/Components, the design system and similar scenes
before introducing UI. Search UseCases, repositories, APIClient, cache, formatting,
validation and DTO mappers before new logic. Prefer composition and small APIs;
justify new abstractions and check shared consumers. Preserve existing state tools
and distinguish local UI, shared/session, server, derived and persistent state.

Every significant plan must contain `Reusability & Optimization Analysis`: reused
components/services/utilities, new abstractions with reasons, scoped duplication
removal, render/network/state risks and proportional performance checks. Before
refactoring, understand behavior, tests, interfaces and consumers. Preserve
behavior unless approved, and verify consumers/navigation/API afterward. Propose
broader architectural cleanup separately; findings do not authorize rewrites.

## Backend API Documentation Policy

Discover relevant documents in api-docs/, feature contracts and explicitly supplied
OpenAPI/Swagger/Markdown attachments. Authority is: approved feature contract/version
→ provided Backend documentation → existing Mobile client/types → authorized test
environment observations. Record source/revision when supplied, never invent it.
For each relevant HTTP endpoint/socket event, map method/path, params/headers/auth,
body/response, success/error/validation codes, pagination/filter/sort/upload,
dates/nullability/optional/enums/versioning to DTO/mapper/repository/UI/tests.
Reference documents rather than copying whole specs. Mark Verified/Pending/Conflict/
N/A. Report conflicts and ask whether Backend or Mobile changes; block dependent
work until material missing details are resolved. Mock behavior requires approval,
isolation and a migration path. Never fabricate production behavior or send unsafe
requests to production. Document API changes and compatibility impacts before
implementation; request renewed approval for material changes. Do not edit Backend
source from this repo; create a change request with endpoint/current/needed behavior,
reason, compatibility and affected Mobile feature.

## Performance and Verification Evidence

Consider render/list identity, map overlays, image sizes/decoding/cache, navigation,
startup/app size, async cleanup, duplicate/stale requests, cancellation/pagination,
offline storage and battery according to feature risk. No speculative caching,
polling, memoization or dependencies. Significant optimization claims need an
original symptom/baseline, change, measurement, result and trade-off. Label unmeasured
reasoning honestly. Use the configured build/lint/contract/UI tools; report failed,
skipped and unverified checks. Files under FamilyTrackerTests are not evidence of
execution: the current app scheme has no testable target. Keep known limitations
visible; do not add arbitrary coverage or timing thresholds.

## Forbidden Shortcuts

- No network/database/keychain/background-location calls from SwiftUI Views.
- No navigation ownership in ViewModels.
- No Domain imports of UI or platform frameworks.
- No new background GPS behavior without motion and battery adaptation.
- No large context dumps when a skeleton or AST query can answer the question.
- No silent error swallowing for user-visible flows.
