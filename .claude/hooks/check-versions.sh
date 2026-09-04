#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Extract version from pubspec.yaml
PUBSPEC_VERSION=$(grep '^version:' "$ROOT_DIR/pubspec.yaml" | head -n 1 | awk '{print $2}' | tr -d '\r')

# Extract version from android/build.gradle.kts
GRADLE_VERSION=$(grep '^version = "' "$ROOT_DIR/android/build.gradle.kts" | head -n 1 | sed -E 's/version = "([^"]+)"/\1/' | tr -d '\r')

# Extract version from ios/better_player_plus.podspec
PODSPEC_VERSION=$(grep "s\.version[[:space:]]*=" "$ROOT_DIR/ios/better_player_plus.podspec" | head -n 1 | sed -E "s/.*s\.version[[:space:]]*=[[:space:]]*'([^']+)'.*/\1/" | tr -d '\r')

echo "Checking better_player_plus synchronized versioning:"
echo " - pubspec.yaml:                $PUBSPEC_VERSION"
echo " - android/build.gradle.kts:    $GRADLE_VERSION"
echo " - ios/better_player_plus.podspec: $PODSPEC_VERSION"

if [[ "$PUBSPEC_VERSION" != "$GRADLE_VERSION" || "$PUBSPEC_VERSION" != "$PODSPEC_VERSION" ]]; then
  echo ""
  echo "❌ ERROR: Versions are out of sync!"
  echo "Please ensure pubspec.yaml, android/build.gradle.kts, and ios/better_player_plus.podspec have identical versions."
  exit 1
fi

echo ""
echo "✅ All 3 files are synchronized at version $PUBSPEC_VERSION."
exit 0
