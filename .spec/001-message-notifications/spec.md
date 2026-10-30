# Feature Specification: Message Management — Mobile Experience

**Feature Branch**: `001-message-notifications`

**Created**: 2026-08-04

**Status**: Draft

**Jira**: [SSA0-962 — Message Management](https://heineken.atlassian.net/browse/SSA0-962)

**Design**: [Figma — SIX SK App / Mobile Messages](https://www.figma.com/design/04ovSv51Qho6Ls31tFWdXx/SIX-SK-App---CMS-Portal?node-id=34-10868&m=dev)

**Input**: Deliver the Storekeeper-facing half of the Message Management feature: messages authored in the Web Administration Portal must reach the Storekeeper on the mobile app through four delivery channels — Push Notification, In-app Inbox, Popup and Home Banner — with support for image and video content and an optional acknowledgement action.

## Scope Boundary

This specification covers **only the mobile application**. The Web Administration Portal, the Heiway SSO admin login, the scheduling/publishing engine, reporting dashboards, exports and the Audit Log are delivered by other teams and are treated here as **external dependencies** (see Dependencies). Mobile is a consumer of the published message data and a producer of read/acknowledge events.

## Clarifications

### Session 2026-08-04

- Q: Does a message reach the Inbox even when the author did not select the In-app Inbox channel (e.g. a Popup-only or Banner-only message)? → A: No. The Inbox lists only Push Notification and In-app Inbox messages. The backend applies this filtering and the app renders exactly what the inbox API returns.
- Q: How should the app treat read vs acknowledge? → A (amended): Reading is an **explicit** action — the Storekeeper taps the **Mark as read** button on the inbox list. Opening a message's detail view does **not** mark it read. Pop-ups and Home Banners are not inbox messages and have no read state; they are **acknowledged** server-side when dismissed, which stops the backend returning them again.
- Q: When exactly should a popup appear? → A: Home screen only — when Home becomes active after app launch or foreground resume. Popups are never shown over any other screen.
- Q: What happens when the Storekeeper taps acknowledge with no connectivity? → A: Fail fast. The request fails, an error is shown, the button returns to its un-acknowledged state, and the Storekeeper can retry when back online. No offline queue or local retry.
- Q: How should the inbox load its history? → A: Paginated. Each tab requests one page at a time and loads more as the Storekeeper scrolls, with pull-to-refresh. No history cap.

## User Scenarios & Testing _(mandatory)_

### Amendment 2026-10-30: Separate push opens from Inbox reads

- Tapping a push notification records a push-open interaction independently of an Inbox read confirmation, including cold starts and taps held until login.
- Opening message detail, whether from the Inbox or a push notification, does not itself confirm an Inbox read. The existing **Mark as read** action remains unchanged.
- Merely receiving a notification does not record a push open. A push-open reporting failure must not block navigation; the failure is recorded diagnostically, without a local retry queue.
- Mobile sends the interaction source to the backend; storage and the Admin Message Details reporting UI remain external dependencies.

### User Story 1 - Read messages in the Inbox (Priority: P1)

A Storekeeper opens the Messages inbox from the **Inbox** bottom tab (or the bell shortcut in the Home header) and sees the messages the backend has returned for them, newest first and grouped by month. Unread messages are visually distinguished from read ones, and each unread row offers a **Mark as read** action. Tapping a message opens its detail view with the full title, body and any attached image or video, and leaves it unread — only **Mark as read** changes that. Messages that have passed their end date move automatically to an "Expired" tab where they remain readable. The Storekeeper can never delete a message.

**Why this priority**: The Inbox is the persistent message center and the durable home for every Push Notification and In-app Inbox message. Without it, messages delivered via push have nowhere to live and no history. Shipping only this story already gives Storekeepers a working communication channel.

**Independent Test**: Publish a message targeted at a test store from the portal (or seed it via the backend), open the app's Messages inbox, and verify the message appears unread, opens with its media, can be acknowledged, and reappears under "Expired" after its end date passes.

**Acceptance Scenarios**:

1. **Given** the backend returns active messages for the Storekeeper, **When** they open the Messages inbox, **Then** every returned active message is listed under the "All" tab grouped by month with unread items visually marked, in the order and grouping the backend response implies.
2. **Given** the Storekeeper has no messages, **When** they open the Messages inbox, **Then** an empty state is displayed instead of an empty list.
3. **Given** an unread message, **When** the Storekeeper taps its **Mark as read** action in the list, **Then** the message is marked as read and the event is reported to the backend as an Inbox confirmation, separately from push opens. Opening the detail view alone leaves it unread.
4. **Given** a message with an attached image, **When** the Storekeeper taps the image in the detail view, **Then** the image opens full screen and can be dismissed back to the detail view.
5. **Given** a message with an attached video, **When** the Storekeeper plays it, **Then** the video plays inline with standard playback controls and can be expanded to full screen including landscape orientation.
6. **Given** a read message, **When** the Storekeeper views the list, **Then** it no longer shows the unread marker or the **Mark as read** action.
7. **Given** a message whose end date has passed, **When** the Storekeeper views the inbox, **Then** the message no longer appears under "All" and is readable under "Expired", shown in the read style with no unread marker and no **Mark as read** action, whatever its read state.
8. **Given** any message in either tab, **When** the Storekeeper interacts with it, **Then** no delete action is available.

---

### User Story 2 - Receive a push notification and jump to the message (Priority: P2)

When a message is published with the Push Notification channel selected, the Storekeeper's device receives a system notification carrying the message title and a short body. Tapping the notification opens the app directly on that message's detail view. If the app is already open in the foreground, the Storekeeper is alerted in-app rather than being interrupted by a system banner they cannot see.

**Why this priority**: Push is what makes time-sensitive operational notices actually timely. It depends on the Inbox existing as the landing destination, so it follows P1.

**Independent Test**: Publish a push-enabled message to a test store with the app closed, confirm the device shows the notification, tap it, and verify the app opens on the correct message detail.

**Acceptance Scenarios**:

1. **Given** the Storekeeper has granted notification permission, **When** a push-enabled message is published to their store, **Then** the device displays a notification with the message title.
2. **Given** the app is closed or backgrounded, **When** the Storekeeper taps the notification, **Then** the app opens on that message's detail view.
3. **Given** the app is in the foreground, **When** a push-enabled message arrives, **Then** the Storekeeper is notified in-app without a disruptive system banner, and the inbox unread count updates.
4. **Given** the Storekeeper has not yet been asked, **When** they first reach the point in the app where messages are relevant, **Then** they are asked for notification permission with a clear explanation.
5. **Given** the Storekeeper declined notification permission, **When** a push-enabled message is published, **Then** the message is still delivered to the Inbox and the app continues to function normally.
6. **Given** the Storekeeper logs out or switches accounts, **When** messages are published to the previous account, **Then** no notifications for that account are delivered to the device.
7. **Given** the app is backgrounded or closed, **When** the Storekeeper taps a message notification, **Then** the app reports a push-open interaction separately from Inbox read confirmation and opens the corresponding detail without changing the local Inbox read state.
8. **Given** the Storekeeper is logged out, **When** they tap a message notification, **Then** neither the push-open report nor detail navigation occurs until login succeeds, after which the pending interaction is reported once.
9. **Given** push-open reporting fails, **When** the notification is opened, **Then** detail navigation still proceeds, the failure is recorded diagnostically, and no retry is queued locally.

---

### User Story 3 - See a popup on app open (Priority: P3)

When a message is published with the Popup channel selected, the Storekeeper sees it as a modal overlay on the Home screen the next time Home becomes active after launching the app or bringing it back from the background. The popup shows the message title, body, media and — when configured — the acknowledgement button. The Storekeeper can dismiss the popup and continue using the app. If the same message also carries the Push Notification or In-app Inbox channel, it additionally remains available in the Inbox.

**Why this priority**: Popups guarantee visibility for high-importance notices, but they are an amplification of content that is usually also delivered through another channel, so they can ship after P1 and P2.

**Independent Test**: Publish a popup-enabled message to a test store, relaunch the app, and verify the popup appears once on Home and can be dismissed without blocking the rest of the app.

**Acceptance Scenarios**:

1. **Given** a popup-enabled message is active for the Storekeeper, **When** the Home screen becomes active after app launch or foreground resume, **Then** the popup is displayed over Home.
2. **Given** the popup is displayed, **When** the Storekeeper dismisses it, **Then** the popup closes and is not shown again on subsequent app opens.
3. **Given** a popup is shown, **When** the Storekeeper taps its confirmation CTA, **Then** the popup closes immediately and the acknowledgement is sent to the backend; if the backend records it, the popup is not shown again on a later launch, and if it fails, an error toast is shown after the popup has closed.
4. **Given** multiple popup-enabled messages are active, **When** the Home screen becomes active, **Then** the popups are presented one at a time newest first, each advancing only after the previous is dismissed or acknowledged, rather than stacked on top of each other.
5. **Given** the Storekeeper is on any screen other than Home, such as the electronic order flow or login, **When** a popup becomes eligible, **Then** no popup is displayed until they return to Home.

---

### User Story 4 - Browse the Home banner carousel (Priority: P4)

When a message is published with the Home Banner channel selected, it appears as a banner on the app's Home screen. When several banner messages are active, they are presented as a swipeable carousel with a position indicator. Tapping a banner opens the corresponding message detail.

**Why this priority**: The banner is a passive, always-visible reminder surface. It adds reach without introducing new content types, so it is the last increment.

**Independent Test**: Publish one banner-enabled message and verify a single static banner renders on Home; publish a second and verify the carousel with indicators and swipe navigation, and that tapping opens the right message.

**Acceptance Scenarios**:

1. **Given** exactly one banner-enabled message is active, **When** the Storekeeper opens Home, **Then** a single banner is displayed without carousel controls.
2. **Given** two or more banner-enabled messages are active, **When** the Storekeeper opens Home, **Then** a swipeable carousel with a position indicator is displayed.
3. **Given** the banner carousel is displayed, **When** the Storekeeper taps a banner, **Then** the corresponding message detail opens.
4. **Given** no banner-enabled messages are active, **When** the Storekeeper opens Home, **Then** no banner area is displayed and the rest of Home is unaffected.
5. **Given** a banner message expires, **When** the Storekeeper next opens Home, **Then** the banner is no longer displayed.

---

### Edge Cases

- **No connectivity**: The Storekeeper opens the inbox while offline — previously loaded messages remain readable and the app communicates that content may be out of date rather than showing a blank screen.
- **Media fails to load**: An image or video cannot be downloaded — the message text remains fully readable and the media area shows a non-blocking failure state.
- **Large or slow video**: A video near the 30 MB / ~1 minute guidance is opened on a slow connection — playback buffers with visible feedback and does not block the rest of the detail view.
- **Message expires while open**: A message reaches its end date while the Storekeeper is reading it — the Storekeeper is allowed to finish reading; the move to "Expired" happens on the next inbox refresh.
- **Acknowledgement while offline**: The Storekeeper taps acknowledge with no connection — the request fails, an error message is shown, the button returns to its un-acknowledged state, and the Storekeeper can tap it again once connectivity returns. The button never shows a false "acknowledged" state.
- **Duplicate delivery**: The same message arrives through push and is already present in the inbox — it appears exactly once in the inbox.
- **Notification for an already-read message**: Tapping an old notification for a message that has since expired — the app opens the message from the "Expired" tab rather than showing an error.
- **Message no longer available**: Tapping a notification or list row for a message that has been removed, is not a delivery for this keeper (404), or is locked for the recipient (423) — the detail shows a not-available state (the not-found illustration plus the backend's `Data` and `Details` strings) instead of a raw error.
- **Session expiry**: A push notification is tapped after the session expired — the Storekeeper is routed through login and then to the intended message.
- **Unsupported or missing media type**: A message references media the app cannot render — the message still opens and displays its text content.

## Requirements _(mandatory)_

### Functional Requirements

**Message retrieval and inbox**

- **FR-001**: The app MUST retrieve the message list the backend returns for the signed-in Storekeeper and display it in a dedicated Messages inbox, reachable from a dedicated **Inbox** bottom tab and from the bell icon in the Home header.
- **FR-001a**: The Inbox MUST contain only messages delivered through the Push Notification and In-app Inbox channels. This filtering is performed by the backend; the app MUST render the returned list as-is and MUST NOT apply its own channel filtering.
- **FR-002**: The inbox MUST present two tabs, "All" and "Expired"; active messages appear under "All" and messages past their end date appear under "Expired".
- **FR-003**: Messages in each tab MUST be grouped by month and ordered newest first.
- **FR-003a**: Each tab MUST load its messages one page at a time, fetching the next page as the Storekeeper scrolls, and MUST support pull-to-refresh to reload from the first page. No history cap is applied — all past messages remain reachable by continued scrolling.
- **FR-003b**: The inbox MUST show a loading state while a page is being fetched and MUST allow the Storekeeper to retry when a page fails to load, without losing the pages already displayed.
- **FR-004**: The inbox MUST visually distinguish unread from read messages. Expired messages (server `IsExpired`) can no longer be acted on, so they MUST always render in the read style — no unread marker and no **Mark as read** action — even when `IsRead` is `false`.
- **FR-005**: The inbox MUST display a dedicated empty state when the selected tab contains no messages.
- **FR-006**: The app MUST surface an unread message count on the entry point to the inbox.
- **FR-007**: The Storekeeper MUST NOT be able to delete any message from any surface.
- **FR-008**: Expired messages MUST remain fully readable, including their media, under the "Expired" tab.

**Message detail and media**

- **FR-009**: The message detail view MUST display the message title, body and publication date.
- **FR-009a**: When the message detail request fails because the message is unavailable (e.g. `404` not found or `423` locked), the detail MUST show a not-available state: the not-found illustration plus the two strings **returned by the backend** — `Data` as the bold line and `Details` on the line below. The app MUST NOT substitute its own copy for these strings.
- **FR-010**: The message detail view MUST render an attached image and allow it to be opened full screen and dismissed.
- **FR-011**: An attached video MUST first show a poster (its first frame) with a play button; tapping play starts playback with play, pause and seek controls. This applies in the message detail and the popup, and the inbox list shows the same poster (tapping the row opens the message).
- **FR-012**: Video playback MUST support a full-screen mode, including landscape orientation, and return to the previous layout on exit. Full screen is available in the message detail; inside the popup the video plays inline only.
- **FR-013**: The app MUST remain usable and the message text readable when attached media fails to load.
- **FR-014**: The app MUST render at most one media item per message.

**Read and acknowledge tracking**

- **FR-015**: The app MUST report a read event to the backend only when the Storekeeper taps the **Mark as read** action on the inbox list. Opening a message's detail view MUST NOT mark it read.
- **FR-015a**: Inbox read confirmations and push-open interactions MUST identify their source separately. A push open MUST NOT be treated by the mobile app as an Inbox read confirmation.
- **FR-016**: Inbox messages are marked read via the list's **Mark as read** action; the message detail view MUST NOT show a separate acknowledgement button (the Figma detail has none). Pop-up and Home Banner acknowledgement is server-side (see FR-026, FR-029a).
- **FR-017**: The app MUST report a pop-up/banner acknowledgement to the backend when the Storekeeper dismisses a pop-up or taps a banner's confirmation CTA, and MUST remove that item so it is not shown again.
- **FR-017a**: Pop-ups and Home Banners have no read state of their own; acknowledging one records the acknowledgement server-side and removes it — it does not produce an inbox read event.
- **FR-018**: An acknowledgement MUST NOT be reversible from the mobile app.
- **FR-019**: The app MUST NOT show a message as read or acknowledged if the corresponding event was not successfully recorded.
- **FR-019a**: Read and acknowledge events MUST NOT be queued or retried locally. When reporting an event fails, the app MUST surface an error toast carrying the backend's message. The action MUST stay available to retry, except for a pop-up, which closes regardless (see FR-026).

**Push notification channel**

- **FR-020**: The app MUST register the device to receive push notifications for the signed-in Storekeeper and MUST stop receiving that Storekeeper's notifications after logout.
- **FR-021**: The app MUST request notification permission with a user-facing explanation, and MUST continue to deliver messages to the Inbox when permission is denied.
- **FR-022**: Tapping a message notification MUST open the app on the corresponding message detail view, routing through login first if the session is not valid.
- **FR-022a**: A recognised notification tap MUST report one push-open interaction when processed by the authenticated routing flow, including cold starts and taps deferred until login. Receipt alone MUST NOT generate this interaction. Reporting MUST NOT block navigation or invalidate/update the local Inbox read state. A reporting failure MUST be recorded diagnostically without a user-facing error toast or local retry queue; the existing Inbox read/acknowledge failure behaviour remains unchanged.
- **FR-023**: When a message notification is received while the app is in the foreground, the app MUST inform the Storekeeper in-app and refresh the unread count without a disruptive system banner.
- **FR-024**: The app MUST handle notifications received while it is closed, backgrounded, or in the foreground.

**Popup channel**

- **FR-025**: The app MUST display popup-configured messages as a modal overlay on the Home screen when Home becomes active after app launch or after the app returns from the background.
- **FR-026**: A popup MUST be dismissible and MUST close as soon as it is dismissed, without waiting for the backend — its dismiss button is the only way out, so waiting on a failing request would trap the Storekeeper. Dismissing it MUST send an acknowledgement to the backend so it is not returned again on a later launch, and it MUST NOT be shown again in the same session. If the acknowledgement fails, the app MUST show an error toast after the popup has closed.
- **FR-027**: When multiple popups are eligible, the app MUST present them one at a time, ordered by publication date descending (newest first), advancing to the next only after the current one is dismissed or acknowledged. Popups MUST NOT be stacked.
- **FR-028**: The app MUST NOT display a popup on any screen other than Home.

**Home banner channel**

- **FR-029**: The app MUST display banner-configured messages on the Home screen, as a single banner when one is active and as a swipeable carousel with a position indicator when more than one is active.
- **FR-030**: Tapping a banner MUST open the corresponding message detail view.
- **FR-029a**: The banner's confirmation CTA ("OK, understood!") MUST acknowledge the banner to the backend and remove it from the carousel only once the backend confirms, centring the next banner. While the request is pending the CTA MUST show a loading state and ignore further taps. If the acknowledgement fails, the banner MUST stay in the carousel and the app MUST show an error toast, so the Storekeeper can retry.
- **FR-031**: The Home screen MUST render normally with no banner area when no banner messages are active.

**Cross-cutting**

- **FR-032**: All user-visible text introduced by this feature MUST be available in both Spanish and English, with Spanish as the default.
- **FR-033**: The app MUST record analytics for message-related interactions, at minimum: message opened, media played, acknowledgement tapped, notification opened, popup dismissed and banner tapped.
- **FR-034**: All message surfaces MUST degrade gracefully without connectivity, keeping previously retrieved content readable and clearly communicating stale or unavailable data.
- **FR-035**: The app MUST only ever display messages targeted to the currently signed-in Storekeeper, and MUST clear message content on logout.

### Key Entities

- **Message**: A communication authored in the portal. Attributes relevant to mobile: identifier, title, body, publication date, end date, selected delivery channels, optional media reference, optional acknowledgement label, and the current Storekeeper's read and acknowledge state.
- **Media Item**: The single optional image or video attached to a message. Attributes: type (image or video), source reference, and optional preview representation.
- **Delivery Channel**: One of Push Notification, In-app Inbox, Popup or Home Banner. A message carries one or more. Push Notification and In-app Inbox messages populate the Messages inbox; Popup and Home Banner drive only their own surfaces.
- **Message Interaction Event**: A record that the Storekeeper confirmed an Inbox read, opened a push notification, or acknowledged a popup/banner, reported separately to the backend for delivery statistics and reporting.

## Success Criteria _(mandatory)_

### Measurable Outcomes

**Reference conditions** — SC-001, SC-003 and SC-007 are measured on the following baseline, on a warm app start with a primed session:

- Network: 4G/LTE, ~10 Mbps downstream, ~100 ms round-trip time
- Device: mid-tier Android (4 GB RAM, Android 13) or an iPhone 11-class device
- Content: an inbox page of 20 messages; a video at the upper guidance bound (~1 minute, ≤ 30 MB)

**Verification split** — SC-001, SC-003, SC-007 and SC-008 are verified on device before release. SC-002, SC-004, SC-005 and SC-006 are post-launch outcome metrics measured through backend delivery statistics, portal reporting and user research; they are not device-verifiable and are not build scope.

- **SC-001**: A Storekeeper can go from receiving a notification to reading the full message, including its media, in under 15 seconds.
- **SC-002**: 95% of published push messages are visible to a Storekeeper with an active device within 2 minutes of publication.
- **SC-003**: The Messages inbox displays its first screen of content within 2 seconds.
- **SC-004**: 100% of the messages the backend returns for a store's inbox are retrievable from that inbox — no returned message is ever lost or unreachable, including after expiry.
- **SC-005**: 90% of Storekeepers can locate a previously received message without assistance on their first attempt.
- **SC-006**: Message read and acknowledgement events are reflected in portal reporting for at least 99% of interactions.
- **SC-007**: Attached videos begin playing within 3 seconds of the play action.
- **SC-008**: No message surface — inbox, popup or banner — causes a crash or blocks the Storekeeper from completing an electronic order.

## Assumptions

- The backend exposes the published messages for the signed-in Storekeeper as paginated lists per tab, together with their read/acknowledge state, and accepts read and acknowledge events; mobile does not compute targeting, scheduling or expiry itself.
- Expiry is determined by the message end date supplied by the backend; the mobile app reflects it rather than owning it.
- A message carries at most one media item, which is an image (PNG or JPG, ≤ 5 MB) or a video (MP4, guidance ~1 minute and ≤ 30 MB), per the ticket's non-functional criteria.
- Media is hosted and served by the backend; the mobile app does not upload media.
- Storekeeper authentication reuses the app's existing login; no new sign-in method is introduced by this feature.
- "Read" is an explicit action — the Storekeeper taps **Mark as read** on the inbox list. Opening the detail view does not change read state. Pop-ups and Home Banners are not inbox messages and have no read state; they are **acknowledged** server-side when dismissed, which stops them being returned again.
- The Inbox is the persistent message center for the Push Notification and In-app Inbox channels only. Popup-only and Home Banner-only messages do not appear in the Inbox. The backend owns this filtering and the app displays whatever the inbox API returns.
- Dismissal state for popups is tracked per Storekeeper so a dismissed popup does not reappear on another app open.
- The push notification provider account and the platform-side push credentials are already provisioned by the customer; the remaining work is inside the application.
- Localization covers Spanish and English only, matching the app's existing locales.

## Dependencies

- **Backend message APIs**: paginated endpoints to list the "All" and "Expired" messages for the signed-in Storekeeper, fetch message detail, and record read and acknowledge events. The read endpoint must distinguish Inbox confirmations from push opens using the source channel without turning a push open into an Inbox read.
- **Admin Message Details reporting**: the backend and portal teams expose the separately recorded push-open and Inbox-read interactions to Admins; mobile only produces the channel-qualified events.
- **Backend scheduling and publishing engine**: determines when a message becomes active and when it expires.
- **Push Notification provider**: message payloads must carry enough information to route the app to the correct message detail.
- **Web Administration Portal**: the authoring surface that produces the messages; not modified by this feature.
- **Media hosting**: publicly reachable or authenticated URLs for images and videos.

## Out of Scope

- Web Administration Portal, its Heiway SSO login, dashboard, search, filtering, export and Audit Log.
- Backend scheduling, publishing, expiry, validation, CSV audience processing and reporting APIs.
- Reporting dashboards, delivery statistics views and export generation.
- Message creation, editing, cancellation or deletion from the mobile app.
- Approval workflow, role management UI, message templates and immediate send.
- Survey Management and Deeplink Management modules (the mobile message surfaces should not preclude them, but nothing is built for them here).
