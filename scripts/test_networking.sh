#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/familytracker-networking.XXXXXX")"
trap 'rm -rf "$TEST_BUILD_DIR"' EXIT
xcrun swiftc -swift-version 5 -module-cache-path "$TEST_BUILD_DIR/module-cache" \
  FamilyTracker/Domain/Errors/DomainError.swift \
  FamilyTracker/App/DI/AppEnvironment.swift \
  FamilyTracker/Core/Logging/NetworkLogger.swift \
  FamilyTracker/Core/Logging/DiagnosticRedactor.swift \
  FamilyTracker/Data/Network/Endpoint.swift \
  FamilyTracker/Data/Network/Endpoints/Endpoints.swift \
  FamilyTracker/Data/Network/APIClient.swift \
  FamilyTracker/Data/Network/DTOs/*.swift \
  Tests/NetworkingContractTests.swift \
  -o "$TEST_BUILD_DIR/networking-tests"
"$TEST_BUILD_DIR/networking-tests"
