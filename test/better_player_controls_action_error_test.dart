import 'package:better_player_plus/better_player_plus.dart';
import 'package:better_player_plus/src/controls/better_player_cupertino_controls.dart';
import 'package:better_player_plus/src/controls/better_player_material_controls.dart';
import 'package:better_player_plus/src/video_player/video_player_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'mock_video_player_controller.dart';

/// A video player whose data source fails to load once [failDataSource] is set, like a retry without network.
class _FailingVideoPlayerController extends MockVideoPlayerController {
  bool failDataSource = false;

  @override
  Future<void> setNetworkDataSource(
    String dataSource, {
    VideoFormat? formatHint,
    Map<String, String?>? headers,
    bool useCache = false,
    int? maxCacheSize,
    int? maxCacheFileSize,
    String? cacheKey,
    bool? showNotification,
    String? title,
    String? author,
    String? imageUrl,
    String? notificationChannelName,
    Duration? overriddenDuration,
    String? licenseUrl,
    String? certificateUrl,
    Map<String, String>? drmHeaders,
    String? activityName,
    String? clearKey,
    String? videoExtension,
  }) async {
    if (failDataSource) {
      throw PlatformException(code: 'VideoError', message: 'Source error');
    }
  }
}

void main() {
  for (final (String name, Widget Function(BetterPlayerControlsConfiguration) buildControls) in [
    (
      'Material',
      (BetterPlayerControlsConfiguration configuration) =>
          BetterPlayerMaterialControls(onControlsVisibilityChanged: (_) {}, controlsConfiguration: configuration),
    ),
    (
      'Cupertino',
      (BetterPlayerControlsConfiguration configuration) =>
          BetterPlayerCupertinoControls(onControlsVisibilityChanged: (_) {}, controlsConfiguration: configuration),
    ),
  ]) {
    testWidgets('$name retry button does not leak an uncaught error when the source still fails', (
      WidgetTester tester,
    ) async {
      final _FailingVideoPlayerController videoPlayerController = _FailingVideoPlayerController();
      final BetterPlayerController controller = BetterPlayerController(const BetterPlayerConfiguration())
        ..videoPlayerController = videoPlayerController;
      await tester.runAsync(
        () => controller.setupDataSource(BetterPlayerDataSource.network('https://example.com/video.mp4')),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BetterPlayerControllerProvider(
              controller: controller,
              child: buildControls(const BetterPlayerControlsConfiguration()),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Playback fails, so the controls show the error widget with the retry button.
      videoPlayerController
        ..failDataSource = true
        ..value = videoPlayerController.value.copyWith(errorDescription: 'Source error');
      await tester.pump();

      await tester.tap(find.text(controller.translations.generalRetry));
      await tester.pump(const Duration(seconds: 5));

      expect(tester.takeException(), isNull);
    });
  }
}
