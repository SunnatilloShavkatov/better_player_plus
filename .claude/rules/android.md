---
paths:
  - "android/**"
---

# Android Rules for better_player_plus

1. **AndroidX Media3**:
   - Use AndroidX Media3 (`1.11.0`) artifacts (`media3-exoplayer`, `media3-exoplayer-hls`, `media3-exoplayer-dash`, `media3-datasource`, `media3-ui`).
   - Do NOT add legacy ExoPlayer (`com.google.android.exoplayer2`) dependencies.
   - Do NOT add unused heavy modules (e.g. Cronet) unless explicitly requested.

2. **Kotlin Gradle Plugin (KGP) & Built-in Kotlin**:
   - For backwards compatibility with older Flutter engines (Flutter 3.41.0+) while supporting AGP 9.0+:
     ```kotlin
     val agpMajor = com.android.Version.ANDROID_GRADLE_PLUGIN_VERSION.substringBefore('.').toInt()
     if (agpMajor < 9) {
         apply(plugin = "org.jetbrains.kotlin.android")
     }
     ```
   - Never apply `id("org.jetbrains.kotlin.android")` unconditionally in `plugins {}` of `android/build.gradle.kts`.

3. **Java & JVM Target**:
   - Always target Java 17:
     ```kotlin
     compileOptions {
         sourceCompatibility = JavaVersion.VERSION_17
         targetCompatibility = JavaVersion.VERSION_17
     }
     ```
   - If configuring Kotlin compiler options under AGP < 9:
     ```kotlin
     if (agpMajor < 9) {
         project.extensions.configure(org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension::class.java) {
             compilerOptions {
                 jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
             }
         }
     }
     ```

4. **Lifecycle & Memory Leaks**:
   - Release players, listeners, and time observer handlers cleanly in `dispose()`.
   - Clear QueuedEventChannel events to avoid memory leaks.
   - Ensure clean detachment in `onDetachedFromEngine` and `onDetachedFromActivity`.
   - Maintain `consumer-rules.pro` for release R8 shrinking safety.
