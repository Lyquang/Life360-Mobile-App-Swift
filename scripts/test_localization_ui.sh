#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${SIMULATOR_ID:?Set SIMULATOR_ID to a booted iPhone Simulator with the app installed and logged out}"
command -v xcodegen >/dev/null
TEST_BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/familytracker-localization-ui.XXXXXX")"
echo "UI test artifacts: $TEST_BUILD_DIR"
xcodegen generate --spec Tests/LocalizationUI/project.yml --project "$TEST_BUILD_DIR"
xcodebuild -project "$TEST_BUILD_DIR/FamilyTrackerLanguageChecks.xcodeproj" \
  -scheme LocalizationUITests \
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  -derivedDataPath "$TEST_BUILD_DIR/build" \
  -resultBundlePath "$TEST_BUILD_DIR/results.xcresult" \
  CODE_SIGNING_ALLOWED=NO test -quiet
