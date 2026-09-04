---
paths:
  - "pubspec.yaml"
  - "android/build.gradle.kts"
  - "ios/better_player_plus.podspec"
  - "CHANGELOG.md"
---

# Versioning & Release Rules

Whenever the plugin version changes:

1. **Simultaneous 3-File Update**:
   - `pubspec.yaml`:
     ```yaml
     version: X.Y.Z
     ```
   - `android/build.gradle.kts`:
     ```kotlin
     version = "X.Y.Z"
     ```
   - `ios/better_player_plus.podspec`:
     ```ruby
     s.version          = 'X.Y.Z'
     ```

2. **Changelog Entry**:
   - In `CHANGELOG.md`, add a new header `## X.Y.Z` at the top with bullet points describing all fixes, features, or breaking changes.

3. **Verification**:
   - Run `bash .claude/hooks/check-versions.sh` to ensure all 3 files share the exact same version string.
