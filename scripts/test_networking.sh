#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/familytracker-networking.XXXXXX")"
trap 'rm -rf "$TEST_BUILD_DIR"' EXIT
cp -R FamilyTracker/Resources/en.lproj FamilyTracker/Resources/vi.lproj "$TEST_BUILD_DIR/"
xcrun swiftc -swift-version 5 -module-cache-path "$TEST_BUILD_DIR/module-cache" \
  FamilyTracker/Domain/Entities/AppLanguage.swift \
  FamilyTracker/Core/Localization/L10n.swift \
  FamilyTracker/Core/Localization/LocalizedErrors.swift \
  FamilyTracker/Domain/Errors/DomainError.swift \
  FamilyTracker/Domain/Common/ISO8601.swift \
  FamilyTracker/Domain/Entities/MediaUpload.swift \
  FamilyTracker/Domain/Entities/AuthTokens.swift \
  FamilyTracker/Domain/Entities/SOSIncident.swift \
  FamilyTracker/Domain/Repositories/SOSLocationProviding.swift \
  FamilyTracker/Core/Location/SOSLocationService.swift \
  FamilyTracker/Domain/Entities/Chat.swift \
  FamilyTracker/Domain/Entities/Alerts.swift \
  FamilyTracker/Domain/Entities/LocationModels.swift \
  FamilyTracker/Domain/Repositories/SOSIncidentRepository.swift \
  FamilyTracker/Domain/UseCases/SOS/SOSRetryPolicy.swift \
  FamilyTracker/Domain/UseCases/SOS/SOSFollowTimestampPolicy.swift \
  FamilyTracker/Data/Local/SOS/SOSPendingIntentStore.swift \
  FamilyTracker/Data/Services/SOSIntentRunner.swift \
  FamilyTracker/Data/Services/SOSIntentLifecycle.swift \
  FamilyTracker/Data/Services/SOSSessionController.swift \
  FamilyTracker/Data/Services/SOSRealtimeEventAdapter.swift \
  FamilyTracker/Presentation/Scenes/SOS/SOSViewModel.swift \
  FamilyTracker/Domain/Entities/GeoPoint.swift \
  FamilyTracker/Domain/Entities/LiveTrail.swift \
  FamilyTracker/Domain/Entities/LiveTrailAssembler.swift \
  FamilyTracker/Domain/Entities/LiveTrailGeometry.swift \
  FamilyTracker/Domain/Entities/LocationSharing.swift \
  FamilyTracker/Domain/Entities/LocationFix.swift \
  FamilyTracker/Domain/Entities/BufferedLocationPoint.swift \
  FamilyTracker/Domain/Repositories/LocationBatchRepository.swift \
  FamilyTracker/App/DI/AppEnvironment.swift \
  FamilyTracker/Core/Logging/NetworkLogger.swift \
  FamilyTracker/Core/Logging/DiagnosticRedactor.swift \
  FamilyTracker/Core/Concurrency/AsyncBroadcaster.swift \
  FamilyTracker/Core/Realtime/SocketClient.swift \
  FamilyTracker/Core/Realtime/SocketEvent.swift \
  FamilyTracker/Core/Monitoring/MobileMetricsRecording.swift \
  FamilyTracker/Core/Monitoring/PerformanceSignposts.swift \
  FamilyTracker/Core/Monitoring/NetworkTaskMetricsDelegate.swift \
  FamilyTracker/Data/Network/Endpoint.swift \
  FamilyTracker/Data/Network/Endpoints/Endpoints.swift \
  FamilyTracker/Data/Network/Endpoints/SOSEndpoint.swift \
  FamilyTracker/Data/Repositories/SOSIncidentRepositoryImpl.swift \
  FamilyTracker/Data/Network/APIClient.swift \
  FamilyTracker/Data/Network/BackendJSONDecoder.swift \
  FamilyTracker/Data/Network/TokenRefreshCoordinator.swift \
  FamilyTracker/Data/Services/MediaUploadService.swift \
  FamilyTracker/Data/Repositories/LocationBatchRepositoryImpl.swift \
  FamilyTracker/Data/Network/DTOs/*.swift \
  FamilyTracker/Data/Network/DTOs/Realtime/RealtimeDTOs.swift \
  FamilyTracker/Data/Network/Mappers/ChatRealtimeMappers.swift \
  Tests/SOSChatChecks.swift \
  Tests/SOSRecoveryChecks.swift \
  Tests/SOSLocationChecks.swift \
  Tests/SOSLifecycleChecks.swift \
  Tests/SOSPresentationChecks.swift \
  Tests/NetworkingContractTests.swift \
  -o "$TEST_BUILD_DIR/networking-tests"
"$TEST_BUILD_DIR/networking-tests"
