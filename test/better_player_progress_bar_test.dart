import 'dart:async';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:better_player_plus/src/controls/better_player_cupertino_progress_bar.dart';
import 'package:better_player_plus/src/controls/better_player_material_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'better_player_mock_controller.dart';
import 'mock_video_player_controller.dart';

enum _ProgressBarStyle { material, cupertino }

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final style in _ProgressBarStyle.values) {
    group('${style.name} progress bar', () {
      late MockVideoPlayerController videoController;
      late BetterPlayerMockController betterPlayerController;

      Future<void> pumpProgressBar(
        WidgetTester tester, {
        bool deferredSeek = true,
        bool enableDrag = true,
        bool initiallyPlaying = false,
      }) async {
        videoController = MockVideoPlayerController()..setDuration(const Duration(seconds: 100));
        if (initiallyPlaying) {
          await videoController.play();
          videoController.playCalls = 0;
        }
        betterPlayerController = BetterPlayerMockController(
          BetterPlayerConfiguration(
            controlsConfiguration: BetterPlayerControlsConfiguration(
              enableProgressBarDrag: enableDrag,
              seekOnProgressBarInteractionEnd: deferredSeek,
            ),
          ),
        )..videoPlayerController = videoController;

        final Widget progressBar = switch (style) {
          _ProgressBarStyle.material => BetterPlayerMaterialVideoProgressBar(videoController, betterPlayerController),
          _ProgressBarStyle.cupertino => BetterPlayerCupertinoVideoProgressBar(videoController, betterPlayerController),
        };

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  key: const ValueKey<String>('progress-bar'),
                  width: 200,
                  height: 48,
                  child: progressBar,
                ),
              ),
            ),
          ),
        );
      }

      Offset pointAt(WidgetTester tester, double fraction) {
        final Rect rect = tester.getRect(find.byKey(const ValueKey<String>('progress-bar')));
        return Offset(rect.left + rect.width * fraction, rect.center.dy);
      }

      test('configuration defaults to immediate seeking', () {
        expect(const BetterPlayerControlsConfiguration().seekOnProgressBarInteractionEnd, isFalse);
      });

      testWidgets('deferred drag seeks once on release', (tester) async {
        await pumpProgressBar(tester);

        final TestGesture gesture = await tester.startGesture(pointAt(tester, 0.2));
        await gesture.moveTo(pointAt(tester, 0.5));
        await tester.pump(const Duration(milliseconds: 200));
        await gesture.moveTo(pointAt(tester, 0.8));
        await tester.pump();

        expect(videoController.seekCalls, isEmpty);
        expect(videoController.value.position, Duration.zero);

        await gesture.up();
        await tester.pump();

        expect(videoController.seekCalls, hasLength(1));
        expect(videoController.seekCalls.single.inMilliseconds, closeTo(80000, 1000));
      });

      testWidgets('tap seeks only on release', (tester) async {
        await pumpProgressBar(tester);

        final TestGesture gesture = await tester.startGesture(pointAt(tester, 0.6));
        await tester.pump();
        expect(videoController.seekCalls, isEmpty);

        await gesture.up();
        await tester.pump();

        expect(videoController.seekCalls, hasLength(1));
        expect(videoController.seekCalls.single.inMilliseconds, closeTo(60000, 1000));
      });

      testWidgets('cancelled interaction does not seek and restores playback', (tester) async {
        await pumpProgressBar(tester, initiallyPlaying: true);

        final TestGesture gesture = await tester.startGesture(pointAt(tester, 0.3));
        await tester.pump(const Duration(milliseconds: 200));
        expect(videoController.value.isPlaying, isFalse);

        await gesture.cancel();
        await tester.pump();

        expect(videoController.seekCalls, isEmpty);
        expect(videoController.value.isPlaying, isTrue);
      });

      testWidgets('cancelled drag does not seek and restores playback', (tester) async {
        await pumpProgressBar(tester, initiallyPlaying: true);

        final TestGesture gesture = await tester.startGesture(pointAt(tester, 0.2));
        await gesture.moveTo(pointAt(tester, 0.6));
        await tester.pump();
        final GestureDetector detector = tester.widget<GestureDetector>(
          find
              .descendant(
                of: find.byKey(const ValueKey<String>('progress-bar')),
                matching: find.byType(GestureDetector),
              )
              .first,
        );
        detector.onHorizontalDragCancel!.call();
        await gesture.cancel();
        await tester.pump();

        expect(videoController.seekCalls, isEmpty);
        expect(videoController.value.isPlaying, isTrue);
      });

      testWidgets('playback resumes only when it was active before drag', (tester) async {
        await pumpProgressBar(tester, initiallyPlaying: true);

        await tester.dragFrom(pointAt(tester, 0.2), const Offset(100, 0));
        await tester.pump();

        expect(videoController.seekCalls, hasLength(1));
        expect(videoController.value.isPlaying, isTrue);
        expect(videoController.pauseCalls, 1);
        expect(videoController.playCalls, 1);

        await pumpProgressBar(tester);
        await tester.dragFrom(pointAt(tester, 0.2), const Offset(100, 0));
        await tester.pump();

        expect(videoController.seekCalls, hasLength(1));
        expect(videoController.value.isPlaying, isFalse);
        expect(videoController.playCalls, 0);
      });

      testWidgets('drag endpoints are clamped and seek only once', (tester) async {
        await pumpProgressBar(tester);

        await tester.dragFrom(pointAt(tester, 0.5), const Offset(300, 0));
        await tester.pump();

        expect(videoController.seekCalls, <Duration>[const Duration(seconds: 100)]);

        await pumpProgressBar(tester);
        await tester.dragFrom(pointAt(tester, 0.5), const Offset(-300, 0));
        await tester.pump();

        expect(videoController.seekCalls, <Duration>[Duration.zero]);
      });

      testWidgets('disabled progress bar drag prevents tap and drag seeks', (tester) async {
        await pumpProgressBar(tester, enableDrag: false);

        await tester.tapAt(pointAt(tester, 0.5));
        await tester.dragFrom(pointAt(tester, 0.2), const Offset(100, 0));
        await tester.pump();

        expect(videoController.seekCalls, isEmpty);
      });

      testWidgets('interactions are ignored while the final seek is pending', (tester) async {
        await pumpProgressBar(tester);
        final Completer<void> pendingSeek = Completer<void>();
        videoController.seekCompleter = pendingSeek;

        await tester.tapAt(pointAt(tester, 0.4));
        await tester.pump();
        expect(videoController.seekCalls, hasLength(1));

        await tester.tapAt(pointAt(tester, 0.8));
        await tester.pump();
        expect(videoController.seekCalls, hasLength(1));

        pendingSeek.complete();
        await tester.pump();
      });

      testWidgets('legacy mode still seeks during drag updates', (tester) async {
        await pumpProgressBar(tester, deferredSeek: false);

        final TestGesture gesture = await tester.startGesture(pointAt(tester, 0.2));
        await gesture.moveTo(pointAt(tester, 0.5));
        await tester.pump();
        await gesture.moveTo(pointAt(tester, 0.7));
        await tester.pump();

        expect(videoController.seekCalls, isNotEmpty);
        await gesture.up();
      });
    });
  }
}
