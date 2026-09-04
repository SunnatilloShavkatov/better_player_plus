---
paths:
  - "ios/**"
---

# iOS Rules for better_player_plus

1. **Memory Management & Retain Cycles**:
   - Always use `[weak self]` in closures, time observer blocks, notification observers, and delegates to prevent retain cycles.
   - FlutterMethodChannel and FlutterEventChannel can form retain cycles if stream handlers hold strong references. Explicitly break these on `dispose()` by calling `eventChannel?.setStreamHandler(nil)`.

2. **Differentiating `clear()` vs `dispose()`**:
   - `clear()`: Used when resetting the current player item or switching streams without discarding the player instance. Observers must be removed before setting `player.replaceCurrentItem(with: nil)`.
   - `dispose()`: Full destruction of the player. Must detach `AVPlayerLayer` (`playerView?.player = nil`), remove all observers, remove notification handlers, clean up `dataSourceDict[textureId]`, and nullify channels.

3. **KVO & NotificationCenter Safety**:
   - Always track the observed `AVPlayerItem` with a weak reference:
     ```swift
     private weak var observedItem: AVPlayerItem?
     ```
   - In `removeObservers()`, unregister observers safely from `observedItem ?? player.currentItem`.
   - Never unregister `UIApplication.didEnterBackgroundNotification` when merely ending a video or looping.
   - Always remove all observers in `deinit`.

4. **CocoaPods & Podspec**:
   - Keep `ios/better_player_plus.podspec` version synchronized with `pubspec.yaml` (`s.version = 'X.Y.Z'`).
   - Do NOT include conflicting Objective-C headers alongside Swift headers (e.g., exclude `BetterPlayerPlugin.{h,m}` if using Swift-generated headers).
