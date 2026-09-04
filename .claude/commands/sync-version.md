# /sync-version <version>

Synchronizes the version string across all 3 configuration files and updates the changelog.

## Usage
`/sync-version 1.4.2`

## Procedure
1. Parse the target version `<version>` provided in the argument.
2. Update `pubspec.yaml`: `version: <version>`.
3. Update `android/build.gradle.kts`: `version = "<version>"`.
4. Update `ios/better_player_plus.podspec`: `s.version          = '<version>'`.
5. Check if `CHANGELOG.md` already has `## <version>`. If not, add a placeholder section at the top.
6. Run `bash .claude/hooks/check-versions.sh` to confirm synchronization.
