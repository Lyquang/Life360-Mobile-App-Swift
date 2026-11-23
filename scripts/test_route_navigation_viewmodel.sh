#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
output="$(mktemp -t familytracker-route-viewmodel)"
trap 'rm -f "$output"' EXIT
swiftc -swift-version 5 -o "$output" \
  FamilyTracker/Domain/Entities/GeoPoint.swift \
  FamilyTracker/Domain/Entities/LocationFix.swift \
  FamilyTracker/Domain/Entities/RouteNavigation.swift \
  FamilyTracker/Domain/Repositories/RoutePreviewRepository.swift \
  FamilyTracker/Domain/Repositories/RouteConnectivity.swift \
  FamilyTracker/Domain/UseCases/Navigation/NavigationSession.swift \
  FamilyTracker/Presentation/Scenes/LiveMap/Navigation/RouteNavigationViewModel.swift \
  scripts/test_route_navigation_viewmodel.swift
"$output"
