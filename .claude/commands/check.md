# /check

Runs standard project validations to ensure code health and version consistency.

## Usage
`/check`

## Procedure
1. Execute `bash .claude/hooks/check-versions.sh` to ensure `pubspec.yaml`, `android/build.gradle.kts`, and `ios/better_player_plus.podspec` are in sync.
2. Run `dart format --output=none --set-exit-if-changed .` to verify formatting.
3. Run `flutter analyze` or `dart analyze` to ensure 0 lint warnings.
4. Report any issues found.
