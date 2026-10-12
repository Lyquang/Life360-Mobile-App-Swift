# Direct Message UI - Interview Notes

## Architecture flow

```text
MemberRowView
  -> optional intent closure
  -> CirclesCoordinator
  -> CircleListViewModel
  -> OpenDirectChatUseCase
  -> ChatRepository
  -> POST /conversations/direct
  -> sheet onDismiss
  -> MainTabCoordinator
  -> ChatCoordinator
```

The View renders state and emits intent. The ViewModel owns loading, friendly errors and
the use-case call. Coordinators own sheet lifecycle, cross-tab routing and Chat stack
reset. The repository remains the only layer that knows the REST endpoint.

## Key decisions and trade-offs

### Why an optional closure on `MemberRowView`?

It keeps the row reusable and unaware of repositories or navigation. Omitting the
closure removes every direct-message affordance, which naturally represents the current
user. The visible 44 pt button remains the primary path; swipe and context menu call the
same closure and are only shortcuts.

### Why wait for `sheet.onDismiss`?

Changing tab and pushing Chat while the Circle sheet is animating out can produce a
blank flash or race SwiftUI presentation state. Success stages a route, sets the sheet to
nil and consumes the route only from `onDismiss`. Consumption clears the route first, so
duplicate callbacks cannot navigate twice. Interactive dismissal has no staged route,
cancels the request and ignores a late response.

### Why disable all member actions during the request?

The get-or-create call is short and only one destination can be presented. Disabling all
entry points avoids two successful requests racing to navigate. Only the selected row
shows a spinner; other rows retain their layout to avoid list movement.

### Why reset the Chat stack?

Cross-tab navigation should produce one predictable destination. Resetting to the Chat
root and pushing the returned conversation prevents duplicate nested rooms. Back then
returns to the conversation list rather than unexpectedly switching tabs.

### Why upsert and refresh?

Upsert makes a newly created conversation visible immediately. Identity is
`conversation.id`. When IDs match, the activity block (`lastMessage`, `lastMessageAt`,
`unreadCount`) comes from whichever record has the newer `lastMessageAt`; metadata comes
from the latest REST response. A background list refresh then reconciles server state.

### Why no Socket.IO join event?

The available mobile/backend contract defines authenticated session events and
`chat:new_message`, but no client join-conversation event. Inventing one would couple the
app to an undocumented protocol. The acceptance test keeps both devices connected,
creates a new direct chat and verifies bidirectional realtime delivery. Failure is
recorded as a backend room-membership issue until the contract changes.

## Error and concurrency handling

- HTTP 403 maps to typed `DomainError.forbidden`; its default description remains the
  previous generic permission message, so existing endpoints do not change behavior.
- Direct chat specializes that type to “Người này không còn trong nhóm.”
- Network and unknown failures receive short localized messages and retry context.
- The opening task uses weak captures. Manual dismissal cancels it and the ViewModel
  checks `Task.isCancelled` before publishing a route or failure.
- Media upload retains its separate `MediaUploadError.forbidden` behavior.

## Accessibility and UI

- The message control and spinner have stable 44x44 pt frames.
- Presence is conveyed by text as well as color.
- VoiceOver receives the member name, self marker, presence, battery and action label.
- Email is omitted to reduce visual density and unnecessary personal-data exposure.
- Dynamic Type permits two-line names while preserving the trailing action.
- Dark Mode uses existing semantic colors; avatar pulsing stops under Reduce Motion.
- New direct chats show a successful empty state, not an endless loading indicator.

## STAR answer

**Situation:** The backend supported get-or-create direct conversations, but users could
only reach rooms that already happened to appear in the Chat list.

**Task:** Add a low-friction entry point for children and older family members without
putting networking or navigation logic into SwiftUI rows.

**Action:** I connected the existing use case through DI, modeled per-member loading and
typed errors, added a 44 pt visible action plus native shortcuts, and staged cross-tab
navigation until sheet dismissal completed. I upserted by conversation ID with timestamp
conflict resolution, then refreshed server state in the background. Cancellation and
pending-route consumption prevent stale or duplicate navigation.

**Result:** A member can open an existing or new one-to-one room in one obvious action;
Back behavior is predictable, the Chat list stays synchronized, and accessibility,
localization and realtime acceptance criteria are explicit and testable.
