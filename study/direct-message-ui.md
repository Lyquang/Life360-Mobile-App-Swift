# Direct Message UI - Verified Design and Execution Plan

Date: 2026-10-12

## 1. Goal and scope

Add an obvious, accessible entry point for opening a one-to-one conversation from a
Circle member list. The backend remains unchanged. The implementation must preserve
MVVM-C boundaries:

```text
MemberRowView (intent only)
  -> CirclesCoordinator
  -> CircleListViewModel
  -> OpenDirectChatUseCase
  -> ChatRepository
  -> POST /conversations/direct
  -> MainTabCoordinator
  -> ChatCoordinator
  -> ChatView
```

## 2. Verified current state

### Confirmed

| Layer | Existing implementation | Status |
| --- | --- | --- |
| Endpoint | `ChatEndpoint.openDirect(userId:)`, `POST /conversations/direct` | Complete |
| Request | `DirectConversationRequestDTO { userId }` | Complete |
| Repository | `ChatRepository.openDirectConversation` and `ChatRepositoryImpl` | Complete |
| Domain | `OpenDirectChatUseCase` returns `Conversation` | Complete but unused |
| Response mapping | `ConversationDTO.toDomain()` supports `.direct` | Complete |
| Chat list | Direct conversations use `person.fill` and `displayName` | Complete |
| Chat navigation | `ChatCoordinator.openConversation` resets to root then pushes | Complete |
| Cross-tab route | `CirclesCoordinator.onOpenConversation` is wired by `MainTabCoordinator` | Group chat only |
| Circle member row | Avatar, name, email, online state and battery | No action |

The API document states that opening a direct conversation has **get-or-create**
semantics, returns HTTP 200, rejects self-chat with 400, and returns 403 when the users
no longer share a Circle.

### Missing presentation and DI links

- `AppContainer` does not expose an `OpenDirectChatUseCase` factory.
- `CircleListViewModel` has no direct-chat dependency, loading state, retry context or
  friendly error mapping.
- `CirclesCoordinator` does not know the current user's ID and cannot identify the self
  row.
- `GroupDetailView` does not pass message actions or per-row loading state.
- `MemberRowView` has no button, swipe action, context menu or direct-message
  accessibility metadata.
- A newly returned conversation is not inserted into `ConversationListViewModel`.

### Corrections to the task assumptions

- The checked-in project targets **iOS 16.0** and Swift 5.0, not iOS 17+.
- Presentation state currently uses Combine `ObservableObject`, `@Published`,
  `@ObservedObject` and `@StateObject`, not Observation `@Observable`.
- The Xcode project has no unit-test target. `Tests/` contains standalone contract
  executables and one separately generated localization UI-test harness.

The feature should follow the actual deployment target and observation style. Migrating
the app to iOS 17/Observation is outside this task.

## 3. API, errors and realtime

### REST contract

```http
POST /api/v1/conversations/direct
Authorization: Bearer <access-token>
Content-Type: application/json

{ "userId": "<member-id>" }
```

`APIClient` already attaches the token and handles its existing stale-token/refresh
coordination. This feature must not add separate authorization logic.

### Error gap

`APIError.http(403, ...)` currently becomes a generic `DomainError.server`, so the
presentation layer cannot reliably distinguish “not in the same Circle” from other
server failures. The proposed implementation adds a typed `DomainError.forbidden`
mapping while preserving the existing generic description for other screens. Direct
chat maps it to “Người này không còn trong nhóm.” Network and fallback messages remain
friendly and localized.

### Socket behavior

The mobile socket authenticates once at session connection and globally observes
`chat:new_message`, `chat:typing`, and `chat:conversation_updated`. Neither the mobile
code nor the available API/media documents define a client `join conversation` event.
The implementation should therefore not invent one. Two-device manual testing must
verify that the backend automatically places authenticated users into the appropriate
rooms. Missing realtime delivery would be a backend-contract clarification, not a
reason to guess an event name.

## 4. UI/UX proposal

### Member row

Keep the row light and scannable:

- Keep the 48 pt existing avatar and online dot.
- Show name on the first line. Show a localized `Bạn` badge for the current user.
- Replace email with a compact semantic line: online/offline text plus battery icon and
  percentage. Email is unnecessary for choosing a family member, consumes width and is
  more private.
- Use a trailing `message.fill` button in a 44x44 pt hit area for other members.
- Keep the whole-row tap behavior unchanged: it currently does nothing.
- Add matching `Nhắn tin` swipe and context-menu actions as shortcuts. They are hidden
  for the current user.

Apple recommends a minimum 44x44 pt button hit region and says context-menu actions
must also be available in the main interface. References:
[Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons),
[Context menus](https://developer.apple.com/design/human-interface-guidelines/context-menus),
[Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility).

### Interaction state

`CircleListViewModel` owns `openingDirectMemberId` and an optional retryable error.
While a request is active, every message entry point is disabled: the selected row shows
a spinner and other rows keep their normal layout but disable their button, swipe action,
and context-menu action. This prevents both duplicate requests and competing navigation
results without relying on cancellation timing.

On success:

1. Produce a light success haptic.
2. Store the returned conversation as a pending cross-tab route.
3. Set the Circle detail sheet to `nil`.
4. Wait for SwiftUI's sheet `onDismiss` callback, which fires after dismissal completes.
5. From `onDismiss`, upsert the conversation, select Chat, reset its path and push.

No arbitrary sleep or animation-duration assumption is used. Interactive/manual sheet
dismissal has no pending route and therefore performs no cross-tab navigation.

On failure, preserve list scroll position and present a short alert with `Thử lại` and
`Đóng`. Retry repeats the action for the stored member ID. No full-screen loading layer
is used.

### Accessibility and adaptability

- Visible icon button plus localized VoiceOver label `Nhắn tin cho <name>` and hint.
- The loading spinner retains the same 44x44 pt frame and has an accessibility label
  such as `Đang mở cuộc trò chuyện với <name>`.
- Combine row semantics into a concise value: name, self marker, presence and battery.
- Do not rely on green/gray alone; presence always has text.
- Use semantic design-system colors for Dark Mode.
- Let the name use up to two lines and give the action a stable 44 pt frame.
- At accessibility Dynamic Type sizes, move status below the name and keep the message
  control visible. Previews cover a long name and an accessibility size.
- Existing avatar animation should respect `accessibilityReduceMotion`; disable its
  repeating pulse when Reduce Motion is enabled.
- Swipe and long press remain optional shortcuts; the visible button is always present.

## 5. Wireframes

### Normal member

```text
+------------------------------------------------------+
| (AQ)  Anh Quang                              [message]|
|  *    Đang hoạt động · battery.75 78%                |
+------------------------------------------------------+
          swipe left -> [Nhắn tin]
          long press  -> Nhắn tin
```

### Current user

```text
+------------------------------------------------------+
| (MQ)  Minh Quang  [Bạn]                              |
|  *    Đang hoạt động · battery.100 92%               |
+------------------------------------------------------+
       no message button, swipe action or context menu
```

### Opening chat

```text
+------------------------------------------------------+
| (AQ)  Anh Quang                           [spinner]   |
|  *    Đang hoạt động · battery.75 78%                |
+------------------------------------------------------+
       all message actions disabled until this request finishes
```

### Error without losing list position

```text
+------------------- Circle detail --------------------+
| ... member list remains at the same scroll position  |
|                                                      |
| Alert: Không có kết nối mạng. Hãy thử lại.           |
|                         [Đóng]  [Thử lại]             |
+------------------------------------------------------+
```

### Destination

```text
+-------------------- Anh Quang -----------------------+
|                 loading message history...           |
|                                                      |
| [photo] [mic] [Nhắn tin...]                  [send]   |
+------------------------------------------------------+
Back -> conversation list in the Chat tab
```

Loading is transient and distinct from a successfully loaded empty direct chat:

```text
+-------------------- Anh Quang -----------------------+
|                                                      |
|              Hãy gửi lời chào đến Anh Quang          |
|                                                      |
| [photo] [mic] [Nhắn tin...]                  [send]   |
+------------------------------------------------------+
```

The empty prompt appears only after the initial history request succeeds with zero
messages. A failed request continues to use the existing retryable error presentation.

### Circle with only the current user

```text
+-------------------- Thành viên (1) ------------------+
| (MQ) Minh Quang [Bạn]                                |
| Hãy chia sẻ mã mời phía trên để thêm người thân.     |
+------------------------------------------------------+
```

The existing detail header really does render `group.inviteCode` above the member list,
but only when that optional value is non-nil. The self-only hint therefore mentions the
code only when it is visible. If the API omits it, use the neutral text `Hãy mời thêm
người thân vào nhóm.` instead of pointing to a nonexistent control.

## 6. Cross-tab navigation options

### Option A - Existing closure route (recommended)

`CirclesCoordinator` exposes a conversation callback. `MainTabCoordinator` owns tab
selection and delegates to `ChatCoordinator`.

Pros: matches current group-chat routing, minimal coupling, easy weak capture, no global
router. Cons: the callback contract must carry enough conversation data to update the
chat list.

Recommended signature:

```swift
var onOpenConversation: ((Conversation) -> Void)?
```

Group chat can continue using its ID/title through a small route value or the existing
overload; direct chat uses the returned `Conversation`.

### Option B - App-wide route enum

A typed `AppRoute.openConversation(Conversation)` scales to more deep links but adds a
new routing abstraction when the existing parent/child closure is sufficient.

### Option C - Shared navigation/event bus

A global router or notification broadcasts cross-feature requests. This lowers direct
references but hides ownership, complicates testing and risks duplicate observers. It is
not recommended for this scope.

### Stack and Back recommendation

Reuse `ChatCoordinator.openConversation`, which calls `popToRoot()` before push. This
prevents duplicate rooms and stale nested stacks. Back returns to the conversation list
in the Chat tab, matching the visible navigation hierarchy. Automatically jumping back
to Circles would make the Back button cross tabs unexpectedly; users can select Circles
to return to it.

## 7. Conversation-list synchronization

Add an idempotent `upsert(_ conversation:)` to `ConversationListViewModel`:

- Replace an existing item with the same ID while preserving newer local last-message
  data when appropriate.
- Insert a newly created direct conversation at the top.
- Set `activeConversationId` when Chat opens as it already does.

This makes the new room immediately visible after Back without waiting for another
network request. When the Chat tab appears, it still starts a background `load()` to
reconcile authoritative `lastMessage` and `unreadCount`. Existing list content remains
visible during that refresh.

For the room title, use the same source as the existing conversation list:
`Conversation.displayName`. It prefers a non-empty `conversation.name`, then joins
member names. Because a get-or-create response may contain both an empty `name` and an
empty `members` array, use the selected Circle member's name only as the final
presentation fallback. Do not create a separate naming rule for the destination.

## 8. File-level execution plan

### G1 - Domain error, DI and state orchestration

Modify:

- `Domain/Errors/DomainError.swift`: add typed forbidden handling without exposing HTTP.
- `Data/Network/Endpoint.swift`: map HTTP 403 to that domain error.
- `App/DI/AppContainer.swift`: expose `openDirectChat` factory.
- `Presentation/Scenes/Circles/List/CircleListViewModel.swift`: inject the use case;
  manage selected-member loading, global action disabling, retry context and friendly
  errors.
- `Presentation/Coordinators/CirclesCoordinator.swift`: inject current user, own the
  navigation task, cancel it only on manual dismissal/deinit, and report the successful
  conversation after sheet dismissal completes.

Completion criteria:

- Correct user ID reaches the use case exactly once per active selection.
- A repeated tap on the same row does nothing.
- Selecting another row while a request is active does nothing because all message
  entry points are disabled.
- Success returns the backend conversation, including an existing one.
- 403, network and fallback errors produce the approved localized messages.

### G2 - Member UI, localization and previews

Modify:

- `MemberRowView.swift`: optional message closure, self/loading inputs, 44 pt control,
  accessibility, Dynamic Type layout, context menu and preview matrix.
- `GroupDetailView.swift`: pass current-user/loading/actions, add swipe action, retry
  alert, `allowsFullSwipe: false`, and the conditional self-only invitation hint.
- `MemberAvatarView.swift`: suppress repeating animation under Reduce Motion.
- `vi.lproj/Localizable.strings` and `en.lproj/Localizable.strings`: add all new labels,
  hints and friendly errors.

Preview matrix: normal, online, offline, low battery, current user, loading, very long
name, accessibility Dynamic Type and Dark Mode.

Completion criteria:

- No self-message affordance exists.
- Button, swipe and context menu call the same closure.
- Long text does not cover the action on an iPhone SE width.
- VoiceOver receives a concise row summary and descriptive action.

### G3 - Cross-tab routing and synchronization

Modify:

- `MainTabCoordinator.swift`: receive the returned conversation, select Chat and route.
- `ChatCoordinator.swift`: upsert, reset root and push the direct conversation.
- `ConversationListViewModel.swift`: idempotent conversation-ID upsert and background
  reconciliation on Chat-tab appearance.
- `ChatView.swift`: distinguish initial loading from a successful empty state and show
  `Hãy gửi lời chào đến <tên>` for a new direct conversation.

Completion criteria:

- Sheet dismisses before the Chat transition, avoiding a blank flash.
- The title uses `Conversation.displayName`, with selected member name only as fallback.
- Back goes to the updated Chat list.
- Reopening the same member does not duplicate the list or navigation destination.

### G4 - Feedback, tests and polish

Add or modify:

- Success/error haptics in the presentation/coordinator layer.
- Direct-message flow tests with a mock opening dependency.
- Endpoint response decode fixture if the existing contract suite does not cover it.
- `FamilyTrackerTests` XCTest files, without editing `project.pbxproj` to create the
  owner-managed target.
- `PROGRESS.md` and `study/direct-message-interview-notes.md` after implementation.

Verification per phase:

- `bash scripts/test_networking.sh` and `bash scripts/test_localization.sh`.
- `xcodebuild test` for the owner-created `FamilyTrackerTests` target.
- SwiftLint with the repository configuration.
- Unsigned generic Simulator build using Xcode 26.2.
- Preview inspection for all required states.
- Physical-device/two-account checklist below.

## 9. Test matrix

Automated behavior:

- Correct member ID is passed to the opening dependency.
- Self member exposes no message action.
- Same-row double tap produces one request.
- Every message entry point is disabled while a request is in flight.
- Loading transitions to success and routes the exact returned `Conversation`.
- Network, forbidden and generic errors map to friendly state and retry works.
- Get-or-create response opens normally and conversation upsert remains unique by ID.
- Direct-conversation JSON response decodes into the expected domain entity.

Manual device checks:

- Two accounts in one Circle exchange realtime messages in both directions.
- With both devices already online, create a brand-new direct conversation and exchange
  messages in both directions without reconnecting either device. If delivery fails,
  record a backend room-join defect for the newly created conversation; do not add an
  undocumented mobile join event.
- Reopening an existing direct chat returns to the same room.
- Removed/non-shared member, offline tap and rapid repeated taps.
- Back navigation, pre-existing Chat stack and switching tabs from the detail sheet.
- Button, swipe and long press all produce the same destination.
- VoiceOver, largest Dynamic Type, Dark Mode and Reduce Motion.
- iPhone SE-sized and large-screen Simulator/device.

## 10. Risks and trade-offs

- A 200 direct response may legally contain an empty `members` array while `name` holds
  the peer name; navigation must use `displayName` with the selected member name as a
  safe presentation fallback.
- Cancelling because the sheet closes or the coordinator is destroyed does not guarantee
  the server stopped processing the POST. Get-or-create semantics make a later retry safe
  and upsert-by-ID prevents UI duplicates.
- Presence updates currently mutate one `User` in a published array; SwiftUI may refresh
  the list rather than only one row. Rows remain lightweight, but true property-level
  Observation optimization requires a separate iOS 17 migration.
- `MemberAvatarView` derives color from Swift `hashValue`, which is not stable across app
  launches. This task preserves behavior; stable avatar color would be separate work.

## 11. Approved decisions and pending prerequisite

Recommended defaults are listed first:

1. **Testing (approved):** the owner will create `FamilyTrackerTests` in Xcode. Add XCTest
   unit tests to that target and do not edit `project.pbxproj` to create it. Once present,
   tests must run through `xcodebuild test` and can be adopted by CI later.
2. **Cross-tab route:** use the existing weak closure chain and reset the Chat stack.
   Alternative: introduce an app-wide route enum.
3. **Back behavior:** return to the Chat conversation list. Alternative: switch back to
   Circles, which is less consistent with native navigation.
4. **List refresh (approved):** upsert by `conversationId`, then refresh in the
   background when the Chat tab appears to reconcile last message and unread state.
5. **Member row:** remove email and use a visible 44 pt message icon, plus labeled swipe
   and context-menu actions. Alternative: retain email or use a wider icon-plus-text
   button, both of which crowd accessibility layouts.
6. **Socket (approved):** do not emit an undocumented join event. Verify a new direct
   conversation in realtime while both devices remain connected. Classify failure as a
   backend room-join issue until an explicit contract says otherwise.

Implementation covers G1-G4. XCTest sources live under `FamilyTrackerTests`, but the
saved Xcode project must contain that owner-created target before `xcodebuild test` can
discover and execute them. Mobile does not emit an undocumented socket join event.

Final verification completed on 2026-10-12: the unsigned generic iOS Simulator build,
networking contracts, localization contracts, plist validation, Swift test-source parse,
SwiftLint and `git diff --check` pass. Running the XCTest cases remains blocked only by
the missing `FamilyTrackerTests` target/Test Action in the saved Xcode project; per the
approved constraint, this implementation does not edit `project.pbxproj` to create it.
