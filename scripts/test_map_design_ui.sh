#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
MAP_QA_SIMULATOR="${1:?Pass a booted isolated iPhone Simulator UUID}"
MAP_QA_OUTPUT="${2:-$(mktemp -d "${TMPDIR:-/tmp}/familytracker-map-ui.XXXXXX")}"
MAP_QA_PROJECT_DIR="${MAP_QA_PROJECT_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/familytracker-map-project.XXXXXX")}"
mkdir -p "$MAP_QA_OUTPUT" "$MAP_QA_PROJECT_DIR"
cp Tests/MapDesignQA/PreviewApp.swift Tests/MapDesignQA/PreviewTests.swift "$MAP_QA_PROJECT_DIR/"
xcodegen generate --spec Tests/MapDesignQA/project.yml --project "$MAP_QA_PROJECT_DIR"
xcodebuild test -project "$MAP_QA_PROJECT_DIR/MapDesignQA.xcodeproj" -scheme MapDesignQA \
  -destination "platform=iOS Simulator,id=$MAP_QA_SIMULATOR" -parallel-testing-enabled NO \
  -derivedDataPath "$MAP_QA_PROJECT_DIR/build" -resultBundlePath "$MAP_QA_OUTPUT/results.xcresult" \
  CODE_SIGNING_ALLOWED=NO -quiet
