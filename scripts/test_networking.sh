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
  FamilyTracker/Core/Monitoring/MobileMetricsRecording.swift \
  FamilyTracker/Core/Monitoring/PerformanceSignposts.swift \
  FamilyTracker/Core/Monitoring/NetworkTaskMetricsDelegate.swift \
  FamilyTracker/Data/Network/Endpoint.swift \
  FamilyTracker/Data/Network/Endpoints/Endpoints.swift \
  FamilyTracker/Data/Network/APIClient.swift \
  FamilyTracker/Data/Network/BackendJSONDecoder.swift \
  FamilyTracker/Data/Network/TokenRefreshCoordinator.swift \
  FamilyTracker/Data/Services/MediaUploadService.swift \
  FamilyTracker/Data/Repositories/LocationBatchRepositoryImpl.swift \
  FamilyTracker/Data/Network/DTOs/*.swift \
  Tests/NetworkingContractTests.swift \
  -o "$TEST_BUILD_DIR/networking-tests"
"$TEST_BUILD_DIR/networking-tests"
