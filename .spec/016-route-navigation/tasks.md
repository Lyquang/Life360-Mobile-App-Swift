# Tasks: Route navigation

**Input**: [spec](spec.md), [plan](plan.md), [Backend proposed contract](../../../Backend/specs/features/routing/contracts.md). Implementation was approved for the reviewed scope on 2026-11-14; see [progress](progress.md). Verification/activation tasks remain open.

## Phase 1: Review prerequisites

- [x] T001 Verify Backend implemented DTO/errors in `api-docs/ROUTING_API_DOC.md` and Swagger against `FamilyTracker/Data/Network/APIClient.swift`; record contract revision and mismatches in `progress.md` (FR-001).
- [ ] T002 Review TomTom account navigation/display/retention terms, Free entitlement and Vietnam motorcycle sample; record permitted behavior/limits in Backend `specs/features/routing/research.md` before activation (FR-001/003).
- [x] T003 Complete native consistency analysis of `spec.md`, `plan.md` and this file; resolve critical findings and record human approval of exact scope in `progress.md` before Swift changes.

## Phase 2: User Story 1 — Preview and choose a route (P1)

**Independent check**: Fixture responses for motorcycle/car/walking, one/multiple/zero routes, quota and provider failure drive distinct UI states with no mode substitution.

- [x] T004 [US1] Add typed `FamilyTracker/Domain/Entities/RouteNavigation.swift` and `Domain/Repositories/RoutePreviewRepository.swift`; preserve route option identity and `other` sections (FR-002/003).
- [x] T005 [US1] Implement verified Backend DTO decoding and typed errors in `FamilyTracker/Data/DTO/RoutePreviewDTO.swift` and `Data/Repositories/BackendRoutePreviewRepository.swift` through existing APIClient; no provider key in app (FR-001/003).
- [x] T006 [US1] Wire repository/use case in `FamilyTracker/App/DI/AppContainer.swift`; request generation/cancellation guards stale mode responses (FR-002).
- [x] T007 [US1] Add mode/alternative preview, warnings and map overlay in `Presentation/Scenes/LiveMap/Navigation/RouteNavigationViewModel.swift`, `RouteNavigationView.swift`, `Presentation/Scenes/LiveMap/Map/LiveTrailMapView.swift` and `Presentation/Coordinators/MapCoordinator.swift`; use design tokens, accessibility and vi/en resources (FR-002/003/007).
- [ ] T008 [US1] Add fixture and presentation tests in `FamilyTrackerTests/RouteNavigationPreviewTests.swift` for three modes, no-route/error, stale response, walking traffic unavailable and persistent `other` warning (SC-001).

## Phase 3: User Story 2 — In-app navigation (P1)

**Independent check**: Loaded route and controlled GPS fixes produce ordered, single-fire instructions, bounded reroute, stable arrival and truthful background state.

- [x] T009 [US2] Implement account-scoped fix progression, route revision, off-route cooldown/budget and stable arrival in `FamilyTracker/Domain/UseCases/Navigation/NavigationSession.swift` (FR-004).
- [x] T010 [US2] Add separate private navigation location consumer to `FamilyTracker/Core/Location/CLLocationService.swift` and DI; verify Circle sharing pause never publishes private navigation fixes (FR-006).
- [x] T011 [US2] Implement coded-maneuver vi/en speech and interruption handling in `FamilyTracker/Core/Audio/NavigationSpeechService.swift`; inspect/adjust `FamilyTracker/Resources/Info.plist` background audio capability only as needed and verify platform behavior (FR-004/007).
- [x] T012 [US2] Connect live maneuver/banner, voice, reroute, arrival and End in `RouteNavigationViewModel.swift`, `RouteNavigationView.swift`, `MapCoordinator.swift`; stop on logout/revoked permission (FR-004/006/007).
- [ ] T013 [US2] Add `FamilyTrackerTests/RouteNavigationSessionTests.swift` for stale/noisy fixes, one-time speech, unknown codes, bounded reroute, arrival once, account switch and Circle privacy (SC-002/004).

## Phase 4: User Story 3 — Offline continuity and privacy (P1)

**Independent check**: A running session keeps loaded instructions when network fails and cannot leak route/GPS to Circle or old account.

- [x] T014 [US3] Add loaded-route offline state/stale traffic and no offline reroute in `NavigationSession.swift` and navigation ViewModel/View (FR-005).
- [ ] T015 [US3] Add network-loss, permission revocation, logout and pause regression fixtures in `FamilyTrackerTests/RouteNavigationSessionTests.swift` and affected existing sharing tests (SC-003/004).

## Phase 5: Verification and handoff

- [ ] T016 Run targeted XCTest and local app build using confirmed project commands; record exact pass/fail in `verification.md`. Inspect screenshots/accessibility in vi/en, light/dark and large text; record missing environments honestly.
- [ ] T017 Pilot real Vietnam routes and locked-screen/interruption/permission/background voice on device; log no private coordinates, record limitations in `verification.md`. Do not claim device completion from simulator.
- [ ] T018 Update `spec.md`, `progress.md`, `study.md` (Vietnamese), `.spec/README.md` and root `PROGRESS.md`; run native append-only converge and reconcile unmet scope before function commit/push.

**Dependencies**: T001–003 gate code. T004–008 enable preview; T009–013 require route model/preview; T014–015 require active session; T016–018 follow implementation. No paid account, deployment or background traffic alert worker is in scope.

## Phase 6: Convergence — 2026-11-14

- [ ] T019 Add a testable presentation harness or project test target and verify stale mode responses, no-route/quota, route selection and persistent `other` warning per SC-001/SC-004 (partial).
- [ ] T020 Verify Circle pause and account switch end-to-end with private navigation lease, including no location/history/socket publication and old callback teardown per FR-006/SC-004 (partial).
- [ ] T021 Pilot actual Vietnam routes and locked-screen/background voice, interruption, permission revocation, VoiceOver/large text and vi/en screenshots on iPhone per SC-002/FR-007 (missing).
- [ ] T022 Reconcile device/provider terms findings and rerun affected checks before marking complete or pushing per T002/T016/T017 (partial).
