# Global Repository Rules - FamilyTracker iOS

This file is the source of truth for all AI agents working in this repository. Every change must preserve the architecture, power policy, concurrency safety, and task-memory workflow below.

## Agent Operating Contract

1. Read this file, `PROGRESS.md`, and any relevant `.spec/` document before editing Swift code.
2. Use token-efficient discovery first: `rg`, `ast-grep`, `graphtify`, and `scripts/codebase_skeleton.sh` before opening broad source trees.
3. Create or update a short feature spec before adding new `.swift` files or changing a user-facing flow.
4. Keep changes scoped to the current feature boundary. Do not rewrite unrelated layers.
5. Update `PROGRESS.md` after every completed task or commit-equivalent change.

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

## File Placement Rules

- `FamilyTracker/Presentation/Scenes/<Feature>`: Views and ViewModels.
- `FamilyTracker/Presentation/Coordinators`: navigation and deep links.
- `FamilyTracker/Domain/UseCases/<Feature>`: feature business operations.
- `FamilyTracker/Domain/Entities`: pure models.
- `FamilyTracker/Domain/Repositories`: protocols.
- `FamilyTracker/Data/Repositories`: concrete repository implementations.
- `FamilyTracker/Core/<Capability>`: platform services.

## Required Feature Workflow

Before writing Swift for a feature:

1. Create `.spec/<feature-name>.md` from `.spec/templates/feature-spec.md`.
2. Define objective, input/output, modeled state, architecture path, edge cases, and test plan.
3. Use `scripts/codebase_skeleton.sh` and AST/code graph tools to identify touched files.
4. Implement by layer: Domain contracts, UseCases, Core/Data services, ViewModel, View, Coordinator.
5. Verify with the narrowest useful build/test/static checks.
6. Update `PROGRESS.md`.

## Forbidden Shortcuts

- No network/database/keychain/background-location calls from SwiftUI Views.
- No navigation ownership in ViewModels.
- No Domain imports of UI or platform frameworks.
- No new background GPS behavior without motion and battery adaptation.
- No large context dumps when a skeleton or AST query can answer the question.
- No silent error swallowing for user-visible flows.
