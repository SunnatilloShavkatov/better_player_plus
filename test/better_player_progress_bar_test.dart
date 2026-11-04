import 'package:better_player_plus/better_player_plus.dart';
import 'package:better_player_plus/src/controls/better_player_cupertino_progress_bar.dart';
import 'package:better_player_plus/src/controls/better_player_material_progress_bar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'better_player_mock_controller.dart';
import 'mock_video_player_controller.dart';

class _CountingVideoPlayerController extends MockVideoPlayerController {
  final List<Duration?> seeks = <Duration?>[];

  @override
  Future<void> seekTo(Duration? position) {
    seeks.add(position);
    return super.seekTo(position);
  }
}

void main() {
  late _CountingVideoPlayerController videoPlayerController;
  late BetterPlayerMockController betterPlayerController;

  setUp(() {
    videoPlayerController = _CountingVideoPlayerController();
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

  for (final (String name, Widget Function(void Function(Duration)) buildBar) in [
    (
      'Material',
      (void Function(Duration) onDragUpdate) => BetterPlayerMaterialVideoProgressBar(
        videoPlayerController,
        betterPlayerController,
        onDragUpdate: onDragUpdate,
      ),
    ),
    (
      'Cupertino',
      (void Function(Duration) onDragUpdate) => BetterPlayerCupertinoVideoProgressBar(
        videoPlayerController,
        betterPlayerController,
        onDragUpdate: onDragUpdate,
      ),
    ),
  ]) {
    testWidgets('$name progress bar previews the drag position and seeks once on release', (WidgetTester tester) async {
      final List<Duration> dragPositions = <Duration>[];
      final Widget progressBar = buildBar(dragPositions.add);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: progressBar)));
      final Finder bar = find.byWidget(progressBar);

      // Drag from the middle (0:50) to a quarter of the width (0:25) in several steps.
      final TestGesture gesture = await tester.startGesture(tester.getCenter(bar));
      final double step = tester.getSize(bar).width / 16;
      for (int i = 0; i < 4; i++) {
        await gesture.moveBy(Offset(-step, 0));
        await tester.pump();
      }

      expect(videoPlayerController.seeks, isEmpty);
      expect(dragPositions, isNotEmpty);
      expect(dragPositions.last, const Duration(seconds: 25));

      await gesture.up();
      await tester.pump(const Duration(seconds: 2));

      expect(videoPlayerController.seeks, <Duration>[const Duration(seconds: 25)]);
    });
  }
}
