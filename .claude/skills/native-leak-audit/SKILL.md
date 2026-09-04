---
name: native-leak-audit
description: Audits native iOS (Swift/AVPlayer) and Android (Kotlin/Media3) code in better_player_plus for retain cycles, memory leaks, unreleased observers, and improper lifecycle disposal.
---

# Native Memory Leak & Lifecycle Audit

Use this skill when modifying player lifecycle code or investigating issue reports regarding memory leaks, background playback anomalies, or crashes on dispose.

## iOS Checklist (`ios/better_player_plus/Sources/better_player_plus/`)
1. **Retain Cycles**:
   - Are all closures capturing `self` using `[weak self]`?
   - Is `eventChannel?.setStreamHandler(nil)` called on player disposal?
   - Is `playerView?.player` set to `nil` before clearing player references?
2. **KVO Observers**:
   - Is `observedItem` weakly referenced (`weak var observedItem: AVPlayerItem?`)?
   - Are observers removed *before* `player.replaceCurrentItem(with: nil)` in `clear()`?
   - Is `removeObservers()` idempotent and safe to call multiple times?
3. **NotificationCenter**:
   - Are player-level notifications (e.g. `AVPlayerItemDidPlayToEndTime`) removed without removing global app lifecycle observers?
   - Does `deinit` clean up `NotificationCenter.default.removeObserver(self)`?

## Android Checklist (`android/src/main/kotlin/uz/shs/better_player_plus/`)
1. **Media3 Player Lifecycle**:
   - Is `player.release()` called when disposing?
   - Are time-update handlers/runnables (`handler.removeCallbacksAndMessages(null)`) cancelled?
2. **Event Channel Cleanup**:
   - Are queued events emptied on player disposal to avoid leaking pending messages?
3. **Activity/Engine Detachment**:
   - Are notification providers and background services cleanly unbound when detaching from Activity or Flutter Engine?
