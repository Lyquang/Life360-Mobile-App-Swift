#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/familytracker-notifications.XXXXXX")"
trap 'rm -rf "$TEST_BUILD_DIR"' EXIT
xcrun swiftc -swift-version 5 -module-cache-path "$TEST_BUILD_DIR/module-cache" \
  FamilyTracker/Domain/Entities/NotificationPreferences.swift \
  FamilyTracker/Domain/Entities/NotificationDeeplink.swift \
  FamilyTracker/Domain/Repositories/NotificationRepository.swift \
  FamilyTracker/Domain/Errors/DomainError.swift \
  FamilyTracker/Data/Local/Preferences/UserDefaultsNotificationPreferences.swift \
  FamilyTracker/Presentation/Scenes/Settings/NotificationSettingsViewModel.swift \
  Tests/NotificationTests.swift -o "$TEST_BUILD_DIR/notification-tests"
"$TEST_BUILD_DIR/notification-tests"
