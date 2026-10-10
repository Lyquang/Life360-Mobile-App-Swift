#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/familytracker-localization.XXXXXX")"
trap 'rm -rf "$TEST_BUILD_DIR"' EXIT
cp -R FamilyTracker/Resources/en.lproj FamilyTracker/Resources/vi.lproj "$TEST_BUILD_DIR/"
xcrun swiftc -swift-version 5 -module-cache-path "$TEST_BUILD_DIR/module-cache" \
  FamilyTracker/Domain/Entities/AppLanguage.swift \
  FamilyTracker/Data/Local/Preferences/UserDefaultsLanguagePreferences.swift \
  FamilyTracker/Core/Localization/L10n.swift \
  FamilyTracker/Presentation/Scenes/Settings/LanguageSettingsViewModel.swift \
  Tests/LocalizationTests.swift \
  -o "$TEST_BUILD_DIR/localization-tests"
"$TEST_BUILD_DIR/localization-tests"
