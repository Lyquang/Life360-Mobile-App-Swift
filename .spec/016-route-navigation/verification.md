# Verification — Route navigation

Updated: 2026-11-14. Status: implemented locally, activation checks pending.

| Requirement | Evidence | Result |
|---|---|---|
| FR-001/002/003, SC-001 | Backend `node --test tests/routingPreview.test.js` (5 pass); Mobile DTO/session and ViewModel Swift harnesses; authenticated repository uses Backend only | Three modes, stale mode response, duplicate preview avoidance and offline no-request checks pass. Visual route-card/`other` warning review remains. |
| FR-004, SC-002 | `bash scripts/test_route_navigation.sh`; iOS Simulator Debug build | Domain progression, cooldown and stable arrival pass; real device foreground/background voice and road guidance unverified. |
| FR-005, SC-003 | Swift harness offline fix and local loaded-route logic | No offline reroute in domain check; offline map tiles are outside scope. |
| FR-006, SC-004 | Separate navigation location lease and logout teardown reviewed in source; ViewModel harness checks unauthorized teardown | Circle publisher isolation is architectural; an end-to-end pause/account switch test remains. |
| FR-007 | `PATH=/opt/homebrew/opt/ruby/bin:$PATH bash scripts/test_localization.sh` | Pass: 638 vi/en keys, no missing references; VoiceOver/large-text device review pending. |

Commands run: `xcodebuild -quiet -project FamilyTracker.xcodeproj -scheme FamilyTracker -sdk iphonesimulator -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/familytracker-routing-build CODE_SIGNING_ALLOWED=NO build` passed before the latest ViewModel test harness addition; `bash scripts/test_route_navigation.sh` and `bash scripts/test_route_navigation_viewmodel.sh` passed; `swiftlint lint --config .swiftlint.yml --quiet` passed without warnings. The app scheme has no XCTest target, so `xcodebuild test` was not run. `git diff --check` passed before the final doc update; rerun at close.

Pending: account-specific TomTom display/navigation/retention terms, actual Vietnam motorcycle road pilot, locked-screen/interruption/background voice, permission revocation, light/dark and large text accessibility screenshots. These checks cannot be inferred from simulator compilation or a public-point API call. No deployment or paid billing performed.

Device attempt 2026-11-14: user authorized Debug installation. The paired iPhone 11 Pro Max reports iOS 26.6; local Xcode is 26.2. A generic signed iOS Debug build passed with an existing interface-orientation warning. Xcode initially timed out mounting the Developer Disk Image. The subsequent `devicectl device install app` gave the actionable underlying error `kAMDMobileImageMounterDeviceLocked`: the phone was locked. No app was installed, launched or tested on the phone. Retry after the owner unlocks the phone; do not treat the signed build as a device test.

2026-11-15: user installed the app on the iPhone through Xcode and supplied a screenshot of the route panel showing `route.state.unavailable`. The app's production Backend URL points to the Render service; a credential-free probe of that service returned health 200 and unauthenticated route preview 404. The local Backend route is authenticated and would return 401 without a token. Thus the screenshot is consistent with an undeployed route endpoint. No turn-by-turn, voice, background or road pilot could be verified from this screenshot; no user location/token was used in the probe. Backend routing progress records the deployment discrepancy.

Later on 2026-11-15, the user authorized full device access for this test. `devicectl device install app` succeeded on the paired iPhone using the signed Debug build; `devicectl device process launch` succeeded and the app process remained listed. This verifies installation/startup only. Device UI route, voice, location background behavior and account-specific API success remain unverified while Render still returns 404.

Render endpoint recheck later on 2026-11-15: unauthenticated preview changed from 404 to 401. This shows the new route is mounted and protected; it does not test the key or user session. The earlier 404 observations above remain historical. Actual in-app retry is pending user interaction with a destination.

Later iPhone screenshot on 2026-11-15: a 1.7 km, 5 minute TomTom route draws on MapKit, with the motorcycle `other` segment warning, and an active navigation session. This establishes authenticated preview and route drawing on this device; it does not establish spoken audio, maneuver progression while moving, or background guidance. Following that evidence, the agent changed the active UI to a turn banner/compact summary, heading-follow camera and initial-fix departure processing. Simulator Debug build, signed generic iOS Debug build, `bash scripts/test_route_navigation.sh`, `bash scripts/test_route_navigation_viewmodel.sh`, vi/en localization (641 keys), and SwiftLint pass. Installation/launch of the new build and a road/locked-screen voice check remain separate evidence.

Final signed Debug build with explicit departure announcement passed and was installed with `devicectl` on the paired iPhone. A command-line launch was denied by iOS because the device was locked (`FBSOpenApplicationErrorDomain`, Locked). Installation is verified; first-run visual/audio/locked-screen behavior of this latest build is not. User was asked to unlock the device for a launch check. The build emitted the pre-existing interface-orientation warning.

## Pre-PR verification — 2026-11-22

Reran `scripts/test_route_navigation.sh`, `scripts/test_route_navigation_viewmodel.sh`,
`swiftlint lint --config .swiftlint.yml --quiet` and localization via existing
Homebrew Ruby: PASS (641 matching vi/en keys, zero missing/duplicate/parity/literal
errors). `git diff --check` PASS. No device/Simulator/build matrix was started.
GitHub PR build/quality checks and the manual/provider checks above are separate
evidence; publication does not imply those pending checks have passed.

Additional pre-PR checks: `bash scripts/test_networking.sh` PASS (26 documented
REST examples plus auth/media/SOS contracts) and `bash scripts/test_place_search.sh`
PASS (21 deterministic checks). No device tests were added.
