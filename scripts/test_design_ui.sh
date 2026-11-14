#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
SIMULATOR_ID="${1:?Pass an isolated booted iPhone Simulator UUID with the app installed and signed out}"
DESIGN_QA_OUTPUT="${2:-$(mktemp -d "${TMPDIR:-/tmp}/familytracker-design-qa.XXXXXX")}"
DESIGN_QA_BUILD_DIR="${DESIGN_QA_BUILD_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/familytracker-design-tests.XXXXXX")}"
mkdir -p "$DESIGN_QA_OUTPUT" "$DESIGN_QA_BUILD_DIR"
xcodegen generate --spec Tests/DesignUI/project.yml --project "$DESIGN_QA_BUILD_DIR"
xcodebuild test -project "$DESIGN_QA_BUILD_DIR/FamilyTrackerDesignChecks.xcodeproj" \
  -parallel-testing-enabled NO \
  -scheme DesignUITests -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  -derivedDataPath "$DESIGN_QA_BUILD_DIR/build" \
  -resultBundlePath "$DESIGN_QA_OUTPUT/results.xcresult" \
  CODE_SIGNING_ALLOWED=NO -quiet
