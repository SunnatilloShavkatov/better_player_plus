import 'dart:async';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:better_player_plus/src/video_player/video_player.dart' show VideoPlayer;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final TestDefaultBinaryMessenger messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const MethodChannel channel = MethodChannel('better_player_channel');
  const MethodChannel eventsChannel = MethodChannel('better_player_channel/videoEvents0');

  late Completer<void> disposed;
  int platformPosition = 0;

  setUp(() {
    disposed = Completer<void>();
    platformPosition = 0;
    VisibilityDetectorController.instance.updateInterval = Duration.zero;

    // Keep the real controller and widget lifecycle; only replace native I/O.
    messenger
      ..setMockMethodCallHandler(channel, (MethodCall call) async {
        switch (call.method) {
          case 'create':
            return <String, Object>{'textureId': 0};
          case 'setDataSource':
            platformPosition = 0;
            await messenger.handlePlatformMessage(
              eventsChannel.name,
              const StandardMethodCodec().encodeSuccessEnvelope(<String, Object>{
                'event': 'initialized',
                'duration': 100000,
                'width': 1280,
                'height': 720,
              }),
              (ByteData? data) {},
            );
          case 'seekTo':
            final arguments = call.arguments as Map<Object?, Object?>;
            platformPosition = arguments['location']! as int;
          case 'position':
            return platformPosition;
          case 'dispose':
            disposed.complete();
        }
        return null;
      })
      ..setMockMethodCallHandler(eventsChannel, (MethodCall call) async => null);
  });

  tearDown(() {
    messenger
      ..setMockMethodCallHandler(channel, null)
      ..setMockMethodCallHandler(eventsChannel, null);
  });

  for (final (bool showPlaceholderUntilPlay, Matcher expectedVideo, String description) in [
    (false, findsOneWidget, 'keeps the video visible when showPlaceholderUntilPlay is false'),
    (true, findsNothing, 'hides the video until play when showPlaceholderUntilPlay is true'),
  ]) {
    testWidgets('paused resolution switch $description', (WidgetTester tester) async {
      final controller = BetterPlayerController(
        BetterPlayerConfiguration(
          autoDispose: false,
          handleLifecycle: false,
          showPlaceholderUntilPlay: showPlaceholderUntilPlay,
          controlsConfiguration: const BetterPlayerControlsConfiguration(showControls: false),
        ),
      );

      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(() async {
          controller.dispose(forceDispose: true);
          await disposed.future;
        });
      });

      await tester.runAsync(
        () => controller.setupDataSource(BetterPlayerDataSource.network('https://example.com/first.mp4')),
      );
      await tester.pumpWidget(MaterialApp(home: BetterPlayer(controller: controller)));
      await tester.pump();

      expect(find.byType(VideoPlayer), expectedVideo);

      await tester.runAsync(() async {
        await controller.play();
        await controller.seekTo(const Duration(seconds: 42));
        await controller.pause();
      });
      await tester.pump();

      expect(find.byType(VideoPlayer), findsOneWidget);

      await tester.runAsync(() => controller.setResolution('https://example.com/second.mp4'));
      await tester.pump();

      expect(controller.isPlaying(), isFalse);
      expect(controller.videoPlayerController!.value.position, const Duration(seconds: 42));
      expect(platformPosition, 42000);
      expect(find.byType(VideoPlayer), expectedVideo);

      await tester.runAsync(controller.play);
      await tester.pump();

      expect(find.byType(VideoPlayer), findsOneWidget);
    });
  }
}
