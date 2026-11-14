#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/familytracker-place-search.XXXXXX")"
trap 'rm -rf "$TEST_BUILD_DIR"' EXIT
xcrun swiftc -swift-version 5 -module-cache-path "$TEST_BUILD_DIR/module-cache" \
  FamilyTracker/Domain/Entities/GeoPoint.swift \
  FamilyTracker/Domain/Entities/PlaceSearch.swift \
  FamilyTracker/Domain/Repositories/PlaceSearchRepository.swift \
  FamilyTracker/Domain/UseCases/Places/PlaceSearchUseCases.swift \
  FamilyTracker/Data/Local/Cache/SearchHistoryCache.swift \
  FamilyTracker/Presentation/Scenes/Places/Search/PlaceSearchViewModel.swift \
  Tests/PlaceSearchTests.swift -o "$TEST_BUILD_DIR/place-search-tests"
"$TEST_BUILD_DIR/place-search-tests"
