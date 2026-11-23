# Progress — route navigation

Stage: **AWAITING_APPROVAL** | Updated: 2026-11-14.

User authorized implementation of route finding/navigation and routing-scoped
Mobile edits plus local iOS build/tests. Confirmed: Vietnam first, free trial,
TomTom Maps Routing API v1 candidate, motorcycle/car/walking alternatives, in-app
turn-by-turn/voice including background, bounded reroute, stable-arrival auto-end,
offline loaded-route continuation and private opt-in location during Circle pause.
Source: [spec](spec.md) and [Backend interview](../../../Backend/specs/system/mobility-interview.md).

**Implementation approval for the current iOS plan: pending.** Mobile
[plan](plan.md) and [tasks](tasks.md) are drafted; native analysis and exact
Backend API handoff are pending.
The earlier implementation request confirms intended scope; the repository's
`AGENTS.md`/`AI_RULES.md` require approval of a current reviewable feature plan
before significant Swift changes. Q-MOB-32 is now answered: show an `other`
segment with an explicit unverified-motorcycle warning; Q-MOB-33: user reports
Free + Routing API key assignment. No Swift code, key or account data changed.

Next: verify Backend contract and provider terms, and present the exact Mobile
review packet for approval. Do not mark
device/traffic/background readiness from Backend public-point API probes.

## Current review packet — 2026-11-14

[Spec](spec.md) · [Plan](plan.md) · [Tasks](tasks.md) ·
[Backend proposed contract](../../../Backend/specs/features/routing/contracts.md).
Read-only native Spec Kit prerequisite check selected this feature and confirmed
spec/tasks. Cross-artifact/constitution analysis found no critical internal
conflict: FR-001…007 and SC-001…004 map to T001…018; UI/privacy/contract and
device checks are explicit. The Backend contract is still proposed, provider
terms and motorcycle/device QA are external gates, and background speech is
conditional on platform permission/lifecycle. These checks are **pending**, not
evidence of feature readiness. No Swift implementation approval recorded.

Review snapshot SHA-256: spec `54746492a39353c2d306430abfc36764a0137d6ebd8c64c64a775922bb907d80`,
plan `1430d2bceb99c160cd3aafb17d237d4bf212d3c8be946eff51a11f39a5708e41`,
tasks/scope digest `a0802c18b142db58a74491d9687e0c2faa317359f5a32aa2f32e40b30e963345`.
Implementation waits for explicit human approval of this current plan.

## Implementation approval — 2026-11-14

User explicitly replied “Tôi duyệt plan trên, hiện thực đầy đủ cho tôi” after
reviewing the Revision 2 summary, including the Backend-first and Mobile-second
sequence. This approves the exact spec/plan/task hashes above and the linked
Backend preview contract as proposed for implementation. Stage: **IMPLEMENTING**.
Actual Backend DTO must be verified before Mobile integration. Provider terms,
Vietnam road/device pilot and locked-screen background voice remain checks, not
assumed results.

User additionally authorized installing the Debug app on the paired iPhone for local routing checks on 2026-11-14. This authorizes device installation/testing, not travel on a real road, deployment or paid provider usage. The `my.tomtom.com/keys` link supplied by the user is an account sign-in page, not an account-specific terms record.
The generic signed iOS Debug build passed. Installation was attempted but iOS returned `kAMDMobileImageMounterDeviceLocked`; the device is still locked. Device pilot remains pending until the owner unlocks it. No app was installed or launched.

2026-11-15 update: user unlocked and installed the app with Xcode, then explicitly authorized full device access to debug the route error. Agent installed the signed Debug app on the paired iPhone with `devicectl`, launched it and confirmed a running process. Backend `main` commit `785cf39` has been pushed, but GitHub Actions failed at its Render Deploy Hook and the live route endpoint still returns 404. Device route/voice pilot remains blocked by live Backend deployment; install/launch are verified only. Historical locked-device statements above describe the previous attempt.

Later checkpoint: Render began answering unauthenticated `POST /api/v1/routes/preview` with 401 instead of 404, consistent with the new authenticated route being live. User was asked to retry an actual destination in the iPhone app. No authenticated preview, TomTom provider result, voice or background behavior is yet verified. The earlier 404 is pre-deploy history; GitHub Actions hook failure remains a separate CI issue.

2026-11-15 device screenshot: authenticated TomTom route preview and MapKit route overlay now work on the iPhone, and the app entered an active navigation session. The screenshot also exposed a gap: active directions occupied a large bottom panel, the map stayed north-up, and departure voice could wait for a later GPS fix. User selected MapKit guidance with heading-up camera, a prominent turn banner and voice; Street View imagery is outside this selected scope. Mobile now processes the reliable starting fix immediately, shows a compact active summary plus turn banner, follows heading with a modest camera pitch and offers a voice toggle. Real voice and road/background behavior still need a human device check. Render deploy-hook CI failure is separate from the working route API.

## Local implementation checkpoint — 2026-11-14

Backend handoff and Swagger were checked against the authenticated iOS DTO/repository. MapKit preview, mode selection, separate navigation location lease, coded vi/en speech, bounded local reroute, stable arrival and offline loaded-route behavior are implemented locally. Simulator Debug build, Swift domain/DTO harness and vi/en localization checks pass; [verification](verification.md) records exact limits. Stage stays **IMPLEMENTING** until account-specific terms, Vietnam motorcycle road and device/background/privacy/accessibility checks are resolved. There is no XCTest target in the app scheme, and no deployment or paid billing was performed.

## Publication qua PR — 2026-11-22

User yêu cầu commit Mobile lên GitHub, tạo PR trước rồi merge. Phạm vi publication
là toàn bộ route-navigation Mobile working tree hiện tại; không sửa Backend hoặc
đánh dấu các activation/device checks chưa chạy thành PASS. Nhánh publication
`feat/route-navigation` dựa trên main f616aa7. Route domain/DTO, ViewModel,
SwiftLint và localization641key vi/en đã chạy lại và PASS; GitHub CI sẽ quyết định
build/quality cho commit được đưa vào PR. Không tải thêm runtime hoặc mở ma trận
thiết bị. Tình trạng feature readiness/manual checks ở trên vẫn giữ nguyên.

Publication result: code commit `eeaafd2` was pushed to `origin/feat/route-navigation`.
GitHub rejected PR creation via both GraphQL and REST with HTTP403 / “Resource not
accessible by personal access token”. No PR was created, no PR CI started, and main
was not merged or pushed directly. Remaining action requires GitHub authentication
with permission to create/merge pull requests; user-requested PR-first order is kept.
