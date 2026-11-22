#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
output="$(mktemp -t familytracker-route-navigation)"
trap 'rm -f "$output"' EXIT
swiftc -swift-version 5 -o "$output" \
  FamilyTracker/Domain/Entities/GeoPoint.swift \
  FamilyTracker/Domain/Entities/LocationFix.swift \
  FamilyTracker/Domain/Entities/RouteNavigation.swift \
  FamilyTracker/Data/DTO/RoutePreviewDTO.swift \
  FamilyTracker/Domain/UseCases/Navigation/NavigationSession.swift \
  scripts/test_route_navigation.swift
"$output"
