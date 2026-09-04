# Proguard / R8 Consumer rules for better_player_plus

# Keep plugin classes and members called via reflection/platform channels
-keep class uz.shs.better_player_plus.** { *; }

# Media3 / ExoPlayer rules for consumer apps
-keep class androidx.media3.exoplayer.** { *; }
-dontwarn androidx.media3.**
