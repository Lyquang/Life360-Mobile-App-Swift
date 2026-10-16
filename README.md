# FamilyTracker · Life360 Alternative

**Real-time family location sharing, built with native SwiftUI and a layered Node.js backend.**

[![iOS CI](https://github.com/Lyquang/Life360-Mobile-App-Swift/actions/workflows/ci.yml/badge.svg)](https://github.com/Lyquang/Life360-Mobile-App-Swift/actions/workflows/ci.yml)
[![Code Quality](https://github.com/Lyquang/Life360-Mobile-App-Swift/actions/workflows/quality.yml/badge.svg)](https://github.com/Lyquang/Life360-Mobile-App-Swift/actions/workflows/quality.yml)
![Swift](https://img.shields.io/badge/Swift-5-F05138?logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-iOS_16%2B-007AFF?logo=swift&logoColor=white)
![Node.js](https://img.shields.io/badge/Node.js-20%2B-339933?logo=nodedotjs&logoColor=white)
![Express](https://img.shields.io/badge/Express-4-000000?logo=express&logoColor=white)
![MongoDB](https://img.shields.io/badge/MongoDB-Mongoose-47A248?logo=mongodb&logoColor=white)
![Socket.io](https://img.shields.io/badge/Socket.io-Realtime-010101?logo=socketdotio&logoColor=white)
![Architecture](https://img.shields.io/badge/Architecture-Clean-167D7F)
![MVVM-C](https://img.shields.io/badge/iOS-MVVM--C-555555)

FamilyTracker brings **live maps, Circle-based sharing, emergency SOS, group and
direct messaging, and journey analytics** into one iOS application. The engineering
focus is practical: isolate business logic, centralize navigation, adapt location
accuracy to motion and battery conditions, and recover gracefully from connectivity changes.

This repository contains the **native iOS client**. The companion
[Node.js backend](https://github.com/Lyquang/Life360-BackEnd) is maintained separately.
It is an independent portfolio project, not affiliated with Life360 and not a
replacement for emergency services. Feature status below reflects the inspected
source, not a claim of production certification or guaranteed delivery.

[Features](#-key-features) · [Architecture](#-technical-architecture) ·
[Quick Start](#-quick-start) · [Verification](#-verification) · [Roadmap](#-delivery-status)

## ✨ Key Features

| Capability | Engineering highlights | Current scope |
| --- | --- | --- |
| **Real-time Location Tracking** | MapKit member pins, battery levels, presence and location updates via Socket.IO | Implemented; initial map population relies on realtime events |
| **Emergency SOS** | Circle-wide SOS events, app-wide alert banner and coordinator-driven map focus | Implemented banner flow; fullscreen alarm/siren and Critical Alerts are not implemented |
| **Smart Background & Battery Saving** | CoreLocation + CoreMotion policy adjusts accuracy, distance filter and significant-change monitoring | Implemented adaptive policy; no measured battery-saving percentage claimed |
| **Real-time Chat & Media** | Circle/direct conversations, cursor pagination, typing, JPEG images and AAC voice notes via presigned uploads | Upload, optimistic state, retry, cancellation and playback are implemented; storage credentials are required; per-message read-receipt UI is not implemented |
| **Journey & Stay-Point Analytics** | Date-based history, stay-point/moving-segment timeline and reverse geocoding | Implemented screens and backend analytics; journey DTO compatibility remains a follow-up in [PROGRESS.md](PROGRESS.md) |
| **Places & Notifications** | Saved places, stay-duration alerts, local chat/SOS notifications and per-account settings | Saved places are not enter/exit geofences; remote APNs delivery still needs backend integration |
| **Vietnamese / English** | In-app language selection, persisted preference and localized UI/errors/durations | Available from Login and Profile settings |
| **Developer Observability** | Pulse network inspector, sanitized diagnostics and JSON export for AI-assisted investigation | Debug tooling; no automatic log transmission to an LLM |

## 🧰 Technology Stack

| Layer | Technologies used |
| --- | --- |
| **iOS language and UI** | Swift 5, SwiftUI, Combine (`ObservableObject` / `@Published`), async/await, iOS 16+ |
| **Apple frameworks** | MapKit, CoreLocation, CoreMotion, AVFoundation, PhotosUI, UserNotifications, Security / Keychain, UIKit |
| **iOS networking and realtime** | URLSession, Codable DTOs, REST/JSON, Socket.IO rooms/events, access tokens and refresh-token rotation |
| **iOS persistence and media** | Keychain credentials, UserDefaults preferences, protected owner-scoped JSONL location buffer, JPEG and AAC `.m4a`, presigned S3-compatible uploads |
| **iOS packages (SwiftPM)** | Socket.IO Client Swift **16.1.1**, Pulse / PulseUI **5.2.3**, GoogleSignIn-iOS **10.0.0** (`Package.resolved`) |
| **Backend runtime and API** | Node.js **20+**, Express **4.x**, Socket.IO **4.x**, REST endpoints and authenticated realtime events |
| **Backend data and infrastructure** | MongoDB with Mongoose **8.x**, optional Redis with ioredis **6.x**, Cloudflare R2 or AWS S3-compatible storage |
| **Backend security and validation** | JWT access tokens + rotating refresh tokens, bcryptjs, Zod, Helmet, express-rate-limit, Google Auth Library |
| **Backend operations** | dotenv, Docker, Swagger UI / OpenAPI generation, Node's built-in test runner |
| **Engineering and AI-assisted workflow** | Xcode 26.2 CI, GitHub Actions, SwiftLint, Gitleaks, XCTest source, contract-test scripts, feature specs, ast-grep, Graphtify, Memory MCP and codebase skeleton tooling |

The iOS package versions are resolved in the checked-in Xcode project's
`Package.resolved`; backend version ranges and scripts live in the separate
[backend package.json](https://github.com/Lyquang/Life360-BackEnd/blob/main/package.json).
AI/AST/MCP tools are development aids, not runtime app dependencies.

### Battery-aware tracking, not a fixed GPS loop

| Motion / power state | Policy in the iOS client |
| --- | --- |
| Stationary | Significant-change monitoring; reduced precision |
| Walking / running | Approximately 10 m requested accuracy, 20 m distance filter |
| Cycling | Approximately 10 m requested accuracy, 30 m distance filter |
| Automotive | Navigation accuracy, 50 m distance filter |
| Low Power Mode / battery below 20% | Lower precision and double the distance filter |

Requested accuracy is a system hint, not a guarantee. Unknown motion uses a
moderate tracking policy; permission, device conditions and iOS scheduling still
govern delivery. See [AdaptiveLocationPolicy.swift](FamilyTracker/Core/Location/AdaptiveLocationPolicy.swift).

## 🧭 Technical Architecture

### Native iOS: MVVM-C + Clean Architecture

```mermaid
flowchart LR
    V[SwiftUI View] --> VM[ViewModel]
    V --> C[Coordinator]
    C --> VM
    VM --> U[Domain Use Cases]
    U --> P[Repository Protocols]
    R[Data Repositories] -. implements .-> P
    R --> S[Core Services / REST / Socket.IO]
    DI[AppContainer] -. injects dependencies .-> C
    DI -. injects dependencies .-> R
```

- **Views render; ViewModels own UI state.** The current implementation uses
  Combine `ObservableObject`, `@Published` and `@StateObject` for an **iOS 16+**
  baseline. It does **not** claim adoption of iOS 17's `@Observable` Observation framework.
- **Coordinators own navigation.** Auth, tabs, chat, map, timelines and emergency
  presentation are separated from business logic. Notification taps enter this
  routing layer; access is checked before opening chat/member content.
- **Domain stays platform-independent.** Repository protocols and use cases
  separate workflows from URLSession, Keychain, CoreLocation and Socket.IO adapters.
- **Composition Root, not scattered construction.**
  [AppContainer.swift](FamilyTracker/App/DI/AppContainer.swift) wires repositories,
  services and use cases; platform capabilities are centralized in `Core/`.
- **Concurrency and ownership are explicit.** MainActor presentation state,
  async/await REST calls, AsyncStream realtime subscriptions, cancellation and
  weak captures support predictable lifecycle management. Strict Swift 6 migration
  is not claimed by this Swift 5 project.
- **Typed boundaries.** Codable DTOs map to domain entities; authenticated requests
  use Keychain-backed Bearer tokens, with API errors translated at repository boundaries.

### Backend: dependency direction matters

The companion backend separates **Domain, Application, Infrastructure and Presentation**.
Presentation invokes application use cases; infrastructure implements their dependencies;
the composition root in `src/container.js` injects repositories, token services,
storage, realtime delivery and a unit of work. Domain does not depend on Express
or Mongoose. This is a service-oriented modular backend, not a claim of microservices.

The backend's stay detector groups consecutive points within an **80 m radius**
for at least **5 minutes**, then derives moving segments. These are inspectable
algorithm parameters, not benchmark or accuracy claims.

### API Surface

The iOS client uses the deployed `/api/v1` REST base for request/response workflows
and Socket.IO for live collaboration:

| Module | REST surface | Realtime surface |
| --- | --- | --- |
| **Authentication** | Register, login, Google social login, refresh-token rotation, current user and logout | Authenticated socket session and `session:ready` |
| **Circles / Places** | List/create/join groups, members, notification interval, saved places | Circle membership and live location/presence events |
| **Chat** | Conversations, direct conversation, cursor-paginated messages, mark read, media upload ticket | Typing, new messages, read receipts and conversation updates |
| **Location / History** | Batch location history at `/locations/batch`, daily history and journey data | `update_location` / `location_update`, SOS and stay alerts |

The realtime `update_location` payload currently stays at `latitude`, `longitude`
and optional `batteryLevel`. GPS timestamp/accuracy are preserved in the mobile
buffer and included in REST batch history uploads.

### Realtime and media paths

```text
Location -> adaptive CoreLocation policy -> domain use case -> Socket.IO
         -> authenticated user/Circle rooms -> member state -> MapKit

Text -> REST create message
Image / voice -> prepare or record -> upload ticket -> raw HTTP PUT to S3/R2
              -> Socket.IO send-with-ack -> conversation room

Notification tap -> pending route -> authenticated session -> membership check
                 -> ChatHubCoordinator / MapCoordinator
```

Socket.IO adds event framing, rooms and reconnection behavior on top of its
transport; it is not interchangeable with a raw WebSocket client. The backend
uses user, Circle and conversation rooms.

There are two distinct offline paths. The generic
[OfflineQueue](FamilyTracker/Data/Local/OfflineQueue/OfflineQueue.swift) is a bounded,
best-effort queue for eligible realtime events (up to 200 items / 24 hours); it does
not provide acknowledged exactly-once delivery. Location history uses the separate
[LocationBuffer](FamilyTracker/Data/Local/LocationBuffer/LocationBuffer.swift):
owner-scoped JSONL in protected Application Support, a 24-hour TTL, duplicate-fix
suppression and deterministic thinning from 500 to 400 points when full. After
authenticated `session:ready`, the app requests a fresh fix for realtime, then uploads
older buffered points chronologically through `POST /api/v1/locations/batch`. If no
fresh fix arrives within the active task's 10-second wait, history sync may start while
realtime continues waiting for a fresh fix. Old points are never replayed as live socket
updates. P7E foreground/network-path triggers are not implemented yet, so synchronization
can wait until a later ready event or the app receives execution time.

## 📂 Directory Structure

**Actual layout of this repository:** the iOS source folder is `FamilyTracker/`,
not `FamilyTrackerApp/`, and the backend is not vendored here.

```text
.
├── FamilyTracker.xcodeproj/       # Checked-in Xcode project
├── FamilyTracker/
│   ├── App/                       # Entry point, lifecycle, DI, event bridge
│   ├── Presentation/              # SwiftUI scenes, ViewModels, Coordinators
│   ├── Domain/                    # Entities, protocols, use cases, errors
│   ├── Data/                      # REST DTOs/mappers, repositories, local storage
│   ├── Core/                      # Location, sockets, notifications, logging
│   └── Resources/                 # Assets, Info.plist, vi/en localization
├── FamilyTrackerTests/            # XCTest source; no target in the main Xcode project yet
├── Tests/                         # Networking/localization contracts and UI-test source
├── scripts/                       # Test runners and codebase skeleton
├── .spec/                         # Feature specifications
├── .ast-grep/                     # Swift architecture/AST rules
├── .mcp/                          # Local Memory MCP data
├── .github/workflows/             # iOS CI and code-quality workflows
├── FamilyTracker.entitlements
├── project.yml                    # XcodeGen description; not used by CI build
├── AI_RULES.md                     # Architectural and agent constraints
└── PROGRESS.md                     # Status, decisions and verification gaps
```

The checked-in `FamilyTracker.xcodeproj` is the build source of truth. Before
regenerating it from `project.yml`, keep package dependencies in sync; the Xcode
project also includes Google Sign-In packages.

**Suggested two-repository checkout** (`FamilyTrackerApp/` is an optional local alias):

```text
workspace/
├── FamilyTrackerApp/              # This repository, layout shown above
└── backend/                       # Separate Life360-BackEnd checkout
    ├── server.js
    ├── src/
    │   ├── domain/                # Framework-independent business rules
    │   ├── application/           # Feature use cases
    │   ├── infrastructure/        # MongoDB, Socket.IO, S3, security adapters
    │   ├── presentation/          # Express routes, socket gateways, DTO validation
    │   ├── config/
    │   └── container.js           # Dependency injection composition root
    ├── tests/
    ├── .env.example
    ├── Dockerfile
    └── package.json
```

## 🚀 Quick Start

### Prerequisites

| Tool | Requirement |
| --- | --- |
| macOS + Xcode | Xcode 16+; iOS deployment target 16.0; CI and current unsigned Simulator builds use Xcode 26.2 |
| Swift Package Manager | Xcode resolves Socket.IO, Pulse and Google Sign-In from `Package.resolved` |
| iPhone / Simulator | Simulator for UI; physical device for realistic motion, battery, background GPS and APNs testing |
| Apple signing | Your own Team/Bundle ID; APNs-capable provisioning for push entitlements |
| Node.js / npm | Node.js 20+ and npm for the separate backend |
| MongoDB | Local instance or Atlas connection string; use a replica set where transaction-backed flows require it |
| Optional services | Redis (optional cache), Google OAuth credentials, Cloudflare R2 or AWS S3-compatible storage; Docker for backend deployment |

### 1. Run the iOS client against the deployed API

Open this repository in Terminal:

```bash
open FamilyTracker.xcodeproj
```

Select scheme **FamilyTracker**, allow package resolution, choose an iPhone
Simulator and Run. For a physical device, select your own signing Team and a
matching Bundle Identifier, enable Developer Mode as required and grant the
location/motion/notification permissions you intend to test.

Both Debug and Release currently use the **deployed HTTPS backend**, not localhost:

| Connection | Configured URL |
| --- | --- |
| REST | `https://life360-backend-6v9n.onrender.com/api/v1` |
| Socket.IO | `https://life360-backend-6v9n.onrender.com` |

The source of truth is [AppEnvironment.swift](FamilyTracker/App/DI/AppEnvironment.swift).
No production credentials are embedded in this guide, and backend availability
is not guaranteed. Use dedicated test accounts and consented test locations.
Running a backend locally does **not** automatically redirect the mobile app.

**Unsigned Simulator build:**

```bash
xcodebuild -project FamilyTracker.xcodeproj -scheme FamilyTracker \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

### 2. Run the companion backend independently

These commands run in a **separate checkout**, not this iOS repository:

```bash
git clone https://github.com/Lyquang/Life360-BackEnd.git backend
cd backend
npm ci
cp .env.example .env
```

Edit `.env` with your own values. The backend's `.env.example` is authoritative;
this local-development subset shows the current variable names:

```dotenv
NODE_ENV=development
PORT=3000
MONGODB_URI=mongodb://127.0.0.1:27017/location-sharing-app
JWT_SECRET=replace-with-a-long-random-secret
JWT_ACCESS_EXPIRES_IN=15m
REFRESH_TOKEN_TTL_DAYS=30
REDIS_ENABLED=false
TZ=Asia/Ho_Chi_Minh
CORS_ORIGIN=*
```

Generate a secret with `openssl rand -hex 32`; never commit `.env`, access tokens,
real locations or signing keys. `CORS_ORIGIN=*` is only a local-development sample;
set explicit browser origins for a public deployment. Native clients do not use
browser CORS enforcement.

```bash
npm run dev
```

For the normal Node entry point use `npm start`. For an image-based deployment:

```bash
docker build -t familytracker-backend .
docker run --rm --env-file .env -p 3000:3000 familytracker-backend
```

The Docker command runs the API only, **not MongoDB**. Use an Atlas/container-reachable
`MONGODB_URI`; `127.0.0.1` inside that API container is not your host MongoDB.
The Docker image uses production mode, so supply explicit production-safe settings.

Google sign-in additionally needs the matching `GOOGLE_CLIENT_ID` on the backend.
For Cloudflare R2, configure all `R2_*` variables shown in the backend `.env.example`
(account, access key, secret, bucket and public domain); alternatively use its
documented `S3_*` compatibility settings. Redis is optional and disabled by default.
With media storage unset, upload-ticket requests return 503. Never put backend
secrets in the iOS app.

### 3. Notifications and App Icon

Open **Profile → Settings → Notifications** for master/chat/SOS preferences and
the iOS permission recovery action. The app can request APNs authorization,
register with APNs and handle notification taps; device tokens are not yet
registered with the backend, so **remote push is not end-to-end connected**.
Local notifications can be scheduled by the app.

Push and background-location capabilities are declared in the project, but valid
Apple signing and backend token registration are still required. `remote-notification`
does not keep sockets running indefinitely. Critical Alerts require separate Apple
approval and are not implemented.

The [AppIcon asset catalog](FamilyTracker/Resources/Assets.xcassets/AppIcon.appiconset)
currently has its universal iOS slot but no artwork. Add an opaque 1024×1024 PNG
there before distributing a branded build.

## 🧪 Verification

Run from this repository root:

```bash
bash scripts/test_networking.sh
bash scripts/test_localization.sh
```

| Check | Scope |
| --- | --- |
| Networking contract harness | 26 documented REST examples, DTO round trips, endpoint contracts, authorization and transport errors |
| Localization contract harness | Key/format parity, saved language, errors and durations; 261 translations |
| XCTest source | Focused tests exist under `FamilyTrackerTests/`, but there is no XCTest target in the main Xcode project, so `xcodebuild test` cannot run them yet |
| Simulator build | Compilation/integration; not proof of physical APNs, GPS, motion or background behavior |

The separate Login language UI test project is generated with XcodeGen and requires
a booted Simulator with the app installed and logged out:

```bash
SIMULATOR_ID=<booted-simulator-udid> bash scripts/test_localization_ui.sh
```

Do not confuse contract tests with live production integration tests. Notifications
on locked devices, battery behavior, remote push delivery, and authenticated UI
flows need separate device/account testing. Backend tests run independently with
`npm test` in the backend checkout.

## 🛠 Engineering Notes

| Topic | Read more |
| --- | --- |
| Architecture and ownership rules | [AI_RULES.md](AI_RULES.md) |
| Implementation status and known gaps | [PROGRESS.md](PROGRESS.md) |
| API contracts: Google OAuth, token rotation, media upload | [api-docs](api-docs/) |
| Location buffer and batch synchronization | [P7 location design](study/location/P7-offline-location-buffer.md) |
| Swift patterns with source references | [Frontend Swift patterns](study/FRONTEND_SWIFT_DESIGN_PATTERNS.md) |
| Language switching | [Localization contract](api-docs/LOCALIZATION.md) |
| Push and notification implementation | [PushNotificationService.swift](FamilyTracker/Core/PushNotification/PushNotificationService.swift) |
| Spec-driven work, AST/graph tooling, Memory MCP and Pulse | [TOOLING.md](TOOLING.md) |

AI-assisted workflows support engineering decisions; they do not replace code
review or tests. `scripts/codebase_skeleton.sh` provides a compact source overview;
specs document scope before changes, and `PROGRESS.md` records verification limits.

## 📌 Delivery Status

- **Available:** native map/chat/history/places screens, adaptive location services,
  REST/Socket.IO integration, bilingual UI, local notification settings and Pulse diagnostics.
- **Offline location:** owner-scoped, protected 24-hour buffer and chronological REST batch
  sync after authenticated socket readiness. Foreground/network-path triggers are not implemented yet.
- **Next integration steps:** APNs provider and device registration/preferences APIs,
  server-side notification filtering, unread badge reconciliation, robust cold-start
  incident-location retrieval, P7E foreground/network location-sync triggers, and complete
  physical-device notification validation.
- **Not advertised as shipped:** fullscreen SOS siren, Critical Alerts, enter/exit
  geofence notifications, per-message read-receipt UI, `@Observable` migration,
  completed icon artwork or guaranteed offline/event delivery.

**Privacy first:** location and message data are sensitive. Share only with consent,
keep credentials out of source control, and review any exported diagnostics before
sharing them with people or AI tools.
