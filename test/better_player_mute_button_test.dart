import 'package:better_player_plus/better_player_plus.dart';
import 'package:better_player_plus/src/controls/better_player_cupertino_controls.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'mock_video_player_controller.dart';

void main() {
  testWidgets('Cupertino mute button does not throw before the controls receive a video value', (
    WidgetTester tester,
  ) async {
    const BetterPlayerControlsConfiguration configuration = BetterPlayerControlsConfiguration();
    final BetterPlayerController controller = BetterPlayerController(const BetterPlayerConfiguration())
      ..videoPlayerController = MockVideoPlayerController();
    await tester.runAsync(
      () => controller.setupDataSource(BetterPlayerDataSource.network('https://example.com/video.mp4')),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BetterPlayerControllerProvider(
            controller: controller,
            child: BetterPlayerCupertinoControls(
              onControlsVisibilityChanged: (_) {},
              controlsConfiguration: configuration,
            ),
          ),
        ),
      ),
    );
    // The controls become visible after their 200 ms init timer. The video value has not changed since then,
    // so the controls have not stored it yet.
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(configuration.unMuteIcon));
    // Let the hide timer finish.
    await tester.pump(const Duration(seconds: 5));

    expect(tester.takeException(), isNull);
  });
}
