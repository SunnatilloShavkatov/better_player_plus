# AGENTS.md — better_player_plus Guidelines

This file provides instructions and guidelines for AI agents (Antigravity, Cursor, Codex, etc.) working on `better_player_plus`.
Detailed Claude Code conventions and scoped rules are also documented in `CLAUDE.md` and `.claude/rules/`.

## 🏗 Project Architecture

- **Dart Plugin (`lib/`)**: Public API, player controllers (`BetterPlayerController`), configuration models, UI controls, and event listeners.
- **Android Plugin (`android/`)**:
  - Namespace: `uz.shs.better_player_plus`
  - Engine: AndroidX Media3 (`1.11.0`)
  - Target/Compile SDK: `compileSdk = 36`, `minSdk = 24`
  - Compatibility: Java 17 (`sourceCompatibility` & `targetCompatibility = JavaVersion.VERSION_17`, `JvmTarget.JVM_17`)
  - AGP Compatibility: Supports both AGP < 9 (conditional KGP plugin) and AGP 9.0+ (Built-in Kotlin).
- **iOS Plugin (`ios/`)**:
  - Engine: Native AVPlayer, AVPlayerViewController, AVPlayerItem
  - Written in: Swift (`ios/better_player_plus/Sources/better_player_plus/`)
  - Podspec: `ios/better_player_plus.podspec`
  - Third-party: `Cache ~> 6.0.0`
- **Example App (`example/`)**:
  - Demo application showcasing configurations, caching, playlists, and player features.

---

## ⚠️ Non-Negotiable Rules

### 1. Synchronized 3-File Versioning
Whenever the plugin version is updated, you **MUST** update all 3 files to the exact same version string, and document the changes in `CHANGELOG.md`:
1. `pubspec.yaml` -> `version: X.Y.Z`
2. `android/build.gradle.kts` -> `version = "X.Y.Z"`
3. `ios/better_player_plus.podspec` -> `s.version = 'X.Y.Z'`
4. `CHANGELOG.md` -> Add `## X.Y.Z` section detailing the changes.

*Verification command*: `bash .claude/hooks/check-versions.sh`

### 2. Flutter SDK Compatibility
- The `pubspec.yaml` constraint must retain `flutter: ">=3.41.0"` (to ensure compatibility with Flutter 3.41.0 through 3.41.9+). Do NOT arbitrarily bump this constraint to 3.44.0+.

### 3. Android Kotlin Gradle Plugin (KGP) & Built-in Kotlin
In `android/build.gradle.kts`:
- Do NOT unconditionally apply `id("org.jetbrains.kotlin.android")`.
- Keep the conditional AGP check:
  ```kotlin
  val agpMajor = com.android.Version.ANDROID_GRADLE_PLUGIN_VERSION.substringBefore('.').toInt()
  if (agpMajor < 9) {
      apply(plugin = "org.jetbrains.kotlin.android")
  }
  ```
- Target Java 17 (`JavaVersion.VERSION_17`).

### 4. iOS Memory Management & Lifecycle
- Prevent retain cycles: Always use `[weak self]` in closures, notification observers, and delegates.
- Differentiate `clear()` vs `dispose()`:
  - `clear()` is for resetting or switching media streams without destroying the player instance or platform channels.
  - `dispose()` must completely release AVPlayer, detach player layers, remove all observers (`NotificationCenter` & KVO), and nullify `eventChannel`/`eventSink`.
- Prevent KVO dealloc crashes:
  - Track observed AVPlayerItem using `private weak var observedItem: AVPlayerItem?`.
  - Always call `removeObservers()` safely and unregister before discarding the player item.

### 5. Pub.dev Code Quality
- Ensure 160/160 pub points:
  - Zero analysis warnings (`analysis_options.yaml`).
  - Keep `.pubignore` up to date to exclude heavy example runners and test media.

---

## 🛠 Standard Commands

```bash
# Check version consistency across pubspec, gradle, and podspec
bash .claude/hooks/check-versions.sh

# Run static analysis
flutter analyze

# Format code
dart format .

# Run tests
flutter test
```
