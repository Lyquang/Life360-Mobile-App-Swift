# Location fix metadata (P1)

Goal: carry an accepted CoreLocation fix's coordinate, timestamp, horizontal accuracy, speed, and course to `ShareLocationUseCase` without changing observable sending behavior.

Input: `CLLocationService`'s accepted `CLLocation` callbacks and latest fix. Output: immutable Domain `LocationFix` stream/property; compatibility `GeoPoint` stream/property for Map and SOS. Negative speed/course remain negative to mean unavailable.

State: `ShareLocationUseCase.lastSent` stores the full fix and the separate send-attempt time. The 50 m OR 30 s rule and heartbeat use send-attempt time, not fix timestamp. Socket `update_location` keeps latitude, longitude and optional batteryLevel only.

Edge cases: delayed GPS timestamp, invalid negative speed/course, no last fix, simultaneous Map/Share subscribers. This task adds no filtering, retry, or background behavior.

Acceptance: mapping retains exact metadata; the old point projection is unchanged; baseline decision sequence and socket payload remain unchanged. XCTest target is not declared in the checked-in Xcode project and must not be added by editing `project.pbxproj` in P1.
