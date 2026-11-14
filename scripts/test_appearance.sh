#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
APPEARANCE_TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/familytracker-appearance.XXXXXX")"
trap 'rm -rf "$APPEARANCE_TEST_DIR"' EXIT
xcrun swiftc -swift-version 5 -module-cache-path "$APPEARANCE_TEST_DIR/cache" \
  FamilyTracker/Presentation/Scenes/Settings/AppearanceSettings.swift \
  Tests/AppearanceTests.swift -o "$APPEARANCE_TEST_DIR/checks"
"$APPEARANCE_TEST_DIR/checks"
