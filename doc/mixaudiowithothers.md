### Mix audio with others
You can enable mix with audio with others app with method:
```dart
betterPlayerController.setMixWithOthers(true)
```
Default value is false.

### Managing the audio session in the app
On iOS the plugin configures `AVAudioSession` itself: it sets the category when a player is created,
and activates and deactivates the session. An app that manages the session itself can turn that off,
once, before creating its first player:
```dart
BetterPlayerController.setManagesAudioSession(false)
```
The plugin then never touches the session, and `setMixWithOthers` does nothing: mixing is a category
option the app sets itself. The app must activate a `.playback` session before relying on background
audio or picture-in-picture. On Android the call does nothing.
