# SOS assistance integration

Status: approved for implementation, 2026-10-29. S1 REST contract, S2 durable
pending/retry runner, S3 REST recovery, S4 socket/lifecycle invalidations and chat
metadata, and S5 independent one-shot GPS implemented. Shared read/write cooldown,
secure REST write cutover, SOS UI and physical-device verification remain.
User requests reviewable batches of approximately 10–12 files or one coherent part.

Canonical mobile execution plan: [study/sos-assistance-integration.md](../study/sos-assistance-integration.md).
Backend contract: `/Users/lyq02/Desktop/Family Tracker Off/Backend/api-docs/SOS_ASSISTANCE_API_DOC.md`.

## Objective and boundaries

Persist SOS through REST, accept assistance, let the owner resolve/cancel, receive
Socket invalidations and recover authorized state through REST after reconnect.
Backend owns creation of SOS chat messages. No dual REST/socket write path, no
automatic use of cached private location, no promise of APNs/FCM delivery.

## Inputs and outputs

Explicit create/coming/close intent, authenticated session, typed REST results,
SOS and chat events. Outputs are authorized incident/responder state, pending
operation state, coordinator routes and localized vi/en UI.

## State and edge cases

Pending UUID and frozen payload survive ambiguous retry; active/closed incident
state follows server revision. Handle timeout, repeated events, pagination races,
403/404 revocation, rate limit deadlines, missing GPS permission and account changes.
Persist-before-send and cleanup are mandatory. Source inspection is not a production
response verification. The user confirmed both backend flags and transaction support
on 2026-10-29; production runtime responses/delivery remain unverified.

## Acceptance

See plan sections 9–12 for file batches, tests, localization and approval decisions.
Approval received; implement one reviewable part at a time. Never commit/push automatically.
