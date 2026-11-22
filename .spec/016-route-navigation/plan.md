# Implementation Plan: Route navigation

**Branch**: `main` (current working tree) | **Date**: 2026-11-14 | **Status**: DESIGNING, awaiting review
**Spec**: [spec.md](spec.md) | **Approval record**: [progress.md](progress.md)
**Backend source**: [routing owner](../../../Backend/specs/features/routing/spec.md)

## Summary

Add mode-specific route preview and in-app MapKit navigation from an existing place search selection. Backend owns the TomTom v1 key and returns bounded route options. Mobile owns an account-scoped, in-memory navigation session, progresses coded maneuvers from reliable fixes, speaks vi/en instructions, reroutes online within limits and keeps the loaded route when connectivity drops. Private navigation location stays independent of Circle sharing.

## Technical Context

- **Language/platform**: Swift 5 language mode, iOS 16 deployment target (project settings); SwiftUI, MapKit, CoreLocation, AVFoundation, Combine.
- **Transport**: Existing authenticated `APIClient`; no TomTom key in app bundle.
- **Storage**: Active route in memory only. Search history cache is separate. No persisted route, destination or trip in this slice.
- **Testing**: Existing XCTest target; local `xcodebuild` after implementation. Background speech and real roads require device QA.
- **Correction recorded 2026-11-14**: the app scheme has no XCTest test target. Local route domain/DTO checks use `scripts/test_route_navigation.sh`; presentation/integration coverage remains a convergence task. This corrects the test infrastructure description without changing approved product scope.
- **Constraints**: Preserve adaptive location/battery policy. No second GPS loop or polling. Overlay changes on route selection/reroute, not every fix. No performance baseline yet.

## Constitution Check

- MVVM-C: View renders, ViewModel presents state, Domain owns navigation rules, Data decodes Backend DTO, Core owns location/audio. Reuse `MapCoordinator`, `APIClient`, `CLLocationService`, `FTDesignSystem`.
- No route/destination/private navigation fix enters Circle publisher, history, trail or socket. A separate opt-in controls private navigation; logout fences old callbacks.
- iOS 16 APIs, MainActor/cancellation, `L10n.tr` vi/en, VoiceOver, Dynamic Type, safe area and 44pt controls. Background behavior depends on permission and OS lifecycle; force-quit continuity is not promised.
- No known constitution exception. Backend handoff, provider account terms, device/background checks and explicit approval of this plan are gates. Recheck after design/API implementation.

## Project Structure

### Documentation

```text
.spec/016-route-navigation/
  spec.md          requirements and acceptance
  plan.md          this design
  tasks.md         ordered work
  progress.md      stage and approval
  verification.md actual checks after implementation
  study.md        Vietnamese mechanism/limits after implementation
```

### Source code (proposed ownership)

```text
FamilyTracker/Domain/Entities/RouteNavigation.swift
FamilyTracker/Domain/Repositories/RoutePreviewRepository.swift
FamilyTracker/Domain/UseCases/Navigation/NavigationSession.swift
FamilyTracker/Data/DTO/RoutePreviewDTO.swift
FamilyTracker/Data/Repositories/BackendRoutePreviewRepository.swift
FamilyTracker/Core/Location/CLLocationService.swift
FamilyTracker/Core/Audio/NavigationSpeechService.swift
FamilyTracker/Presentation/Scenes/LiveMap/Navigation/{RouteNavigationViewModel,RouteNavigationView}.swift
FamilyTracker/Presentation/Scenes/LiveMap/Map/LiveTrailMapView.swift
FamilyTracker/Presentation/Coordinators/MapCoordinator.swift
FamilyTracker/App/DI/AppContainer.swift
FamilyTracker/Resources/Info.plist
FamilyTracker/Resources/{vi,en}.lproj/Localizable.strings
FamilyTrackerTests/RouteNavigation*Tests.swift
```

These are planned locations, not a claim new files exist. Check Xcode target membership before adding files. Do not change the historical journey renderer.

## FamilyTracker Architecture & API Mapping

| Source/status | Endpoint | Contract and errors | Consumer |
| --- | --- | --- | --- |
| [Backend proposed contract](../../../Backend/specs/features/routing/contracts.md), unimplemented | `POST /api/v1/routes/preview` | Bearer JWT; origin/destination and `motorcycle\|car\|walking`; alternatives/geometry/coded maneuvers/modeSections/traffic; 400/401/429/503 or empty routes | `BackendRoutePreviewRepository` → UseCase → ViewModel |

Do not code the draft path/DTO until Backend tests, Swagger and `api-docs/ROUTING_API_DOC.md` confirm the implementation. Response-local route ID is not a server trip ID. Cancellation and a session generation token discard responses after mode switch, end, logout or newer request. A 429 stops automatic reroute until cooldown; no provider call from device.

## Route and navigation lifecycle

1. `MapCoordinator.selectedPlace` supplies destination; a fresh consented self location supplies origin. Show mode picker (motorcycle first, car, walking), loading/one-or-many alternatives/no-route/error. Show distance, ETA, attribution and truthful traffic availability. If a motorcycle option has `TRAVEL_MODE=other`, show a persistent warning that that segment is not confirmed for motorcycles; do not call it walking.
2. Start requires explicit private-location opt-in and a valid chosen route. Session owns account ID, route revision, selected option, current step and freshness. Route stays in memory until end/arrival/logout. Circle pause does not revoke separately enabled navigation, but cannot resume Circle publishing. Missing/revoked permission degrades or stops truthfully.
3. Add an independent navigation consumer/lease to existing location service instead of a second manager. Preserve adaptive power policy and verify listener fan-out/sharing gates. Reject stale, inaccurate or impossible fixes. Progress/announce coded maneuvers once at safe lead distances. Localize known codes in vi/en, preserve road names; unknown codes stay neutral and never speak a guessed turn. The provider's `vi-VN` probe returned English turn verbs.
4. Proposed tuning: off-route requires two credible fixes >40m from route ≥10s apart; reroute online ≤1/60s and ≤10/trip. Arrival requires two credible fixes ≤50m from destination spanning ≥30s. These are reviewable engineering thresholds, not verified product facts. Quota/offline suppress reroute without deleting loaded route. Old responses cannot replace new revision.
5. Offline during an active process: continue local route/voice, mark ETA/traffic stale and reroute unavailable. No offline basemap or recovery after process termination is promised. Handle audio interruption/calls/logout. Review `UIBackgroundModes` (`location` exists, `audio` absent), AVAudioSession and OS restrictions before background speech. Validate locked-screen behavior on device.

## Reusability & Optimization Analysis

- `PlaceSearchView` selects destinations; `MapCoordinator` and `LiveTrailMapView` own Map tab. Reuse `FTColors`, `FTFont`, `FTSpacing`, `FTControl` rather than a second map shell.
- `APIClient` handles auth transport; `AppContainer` wires dependencies; `CLLocationService` owns adaptive fixes. Chat `VoicePlaybackController` supplies audio-session precedent, not navigation TTS.
- New route repository isolates DTO; navigation session isolates progression/reroute/arrival from SwiftUI; speech adapter isolates AVFoundation. No persistent trip store, new DI framework or unrelated refactor.
- Backend owns transient preview; ViewModel owns preview UI; session owns active route/rule state; location service owns hardware; Circle publisher remains independently gated.
- Route overlays, location and reroutes risk battery/quota. Pilot measures calls per trip, GPS activity and UI responsiveness. No optimization claim before measurement.

## Approval & Verification Plan

Milestones: Backend preview + verified API handoff → Mobile repository/preview → private location/session/maneuver/voice → offline/reroute/arrival/background device pilot → docs/converge. Commit/push only after a function meets accepted scope and checks, as the user requested. No paid plan/deployment.

Tests map to FR-001…007 and SC-001…004: three distinct modes; unknown code/`other` warning; error and response race; offline; fix noise; cooldown; arrival once; Circle pause; account switch. Use real project build/test commands and record results in `verification.md`. Vietnam road legality, locked-screen speech, interruptions, permission changes, VoiceOver and small/large screenshots remain device checks. Rollback touches routing UI/consumer only; Circle-sharing regression coverage is required.

## Design Review

**UI impact: SUBSTANTIVE.** Flow: search result → route preview sheet with mode/alternatives → Start → map navigation with next maneuver, ETA/distance, status/warning and End. Distinct loading, no-route, failure, quota, offline, stale traffic, denied permission, degraded background, arrived, ended and expired-account states. Close/back must never silently start location use.

Reuse map overlays/sheet patterns and `FTDesignSystem`. Route selection cannot rely on color alone. Keep attribution visible, actions within safe area, targets ≥44pt, Dynamic Type wrapping and VoiceOver labels for mode/route/warning/next maneuver. Localize app-owned labels and speech for mode, cards, `other`, start/end, rerouting, arrival, offline/stale, permission/quota and unknown maneuver. Sources: `PlaceSearchView`, `MapCoordinator`, `FTDesignSystem`, local design skills and [Apple HIG](https://developer.apple.com/design/human-interface-guidelines/) via `.specify/design-workflow.md`. After implementation inspect light/dark vi/en screenshots at large text and test background guidance on device.
