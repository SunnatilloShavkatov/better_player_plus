import 'package:better_player_plus/better_player_plus.dart';
import 'package:better_player_plus/src/controls/better_player_cupertino_progress_bar.dart';
import 'package:better_player_plus/src/controls/better_player_material_progress_bar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'better_player_mock_controller.dart';
import 'mock_video_player_controller.dart';

void main() {
  late MockVideoPlayerController videoPlayerController;
  late BetterPlayerMockController betterPlayerController;

  setUp(() {
    videoPlayerController = MockVideoPlayerController();
    videoPlayerController.value = videoPlayerController.value.copyWith(
      duration: const Duration(seconds: 100),
      position: const Duration(seconds: 50),
    );
    betterPlayerController = BetterPlayerMockController(const BetterPlayerConfiguration())
      ..videoPlayerController = videoPlayerController;
  });

  Future<void> dragToStart(WidgetTester tester, Widget progressBar) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: progressBar)));
    final Finder bar = find.byWidget(progressBar);
    // Drag past the left edge, as a user does when scrubbing back to the beginning.
    await tester.dragFrom(tester.getCenter(bar), const Offset(-2000, 0));
    // Let the progress bar's update block timer finish.
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('Material progress bar seeks to the start when dragged past the left edge', (WidgetTester tester) async {
    await dragToStart(tester, BetterPlayerMaterialVideoProgressBar(videoPlayerController, betterPlayerController));

    expect(videoPlayerController.value.position, Duration.zero);
  });

  testWidgets('Cupertino progress bar seeks to the start when dragged past the left edge', (WidgetTester tester) async {
    await dragToStart(tester, BetterPlayerCupertinoVideoProgressBar(videoPlayerController, betterPlayerController));

    expect(videoPlayerController.value.position, Duration.zero);
  });
}
