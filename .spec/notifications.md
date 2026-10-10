# Notifications and showcase README

Approved by user 2026-10-10. Status: iOS local portion implemented; remote push pending.

Extend PushNotificationService with account-scoped UserDefaults preferences,
OS permission state/recovery, chat/SOS local delivery, bounded deduplication and
authenticated coordinator routing. Retain Combine and iOS 16 support.
View -> ViewModel -> notification repository protocol -> Core/Data adapter;
Coordinators own navigation and AppContainer owns wiring.

Backend inspected read-only in ../Backend: no APNs provider/device API exists.
Do not invent live endpoints or claim push works while suspended/terminated.
Document missing provider, signing, server preference sync and icon artwork.

Test defaults, account isolation, toggles, payload validation and dedupe; build
Debug, run localization/network regressions. Physical APNs remains unverified.
README must distinguish actual features from roadmap, use actual paths and
verified backend commands. Update PROGRESS after implementation.

## Results and scope adjustments

MainTabCoordinator owns the Settings sheet; no extra ProfileCoordinator was needed.
NotificationRepository bridges the existing Core service; no unused network
repository/use-case abstractions or speculative endpoints were added.
Tests passed for account-scoped preferences, category gating, bounded dedupe,
payload validation and ViewModel state/error handling. Networking/localization
regressions and unsigned Debug Simulator build passed. README links/plists checked.
Physical APNs, authenticated Settings UI, badge sync, server-side preferences,
modal takeover and historical SOS position retrieval remain unverified/incomplete.
App icon import instructions provided; artwork not supplied.
