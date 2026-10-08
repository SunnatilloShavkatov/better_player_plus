import 'package:better_player_plus/src/video_player/video_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final TestDefaultBinaryMessenger messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const MethodChannel channel = MethodChannel('better_player_channel');
  const String eventsChannelName = 'better_player_channel/videoEvents0';

  void mockPlatform(Map<String, Object> initializedEvent) {
    messenger
      ..setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'create':
            return <String, dynamic>{'textureId': 0};
          case 'setDataSource':
            await messenger.handlePlatformMessage(
              eventsChannelName,
              const StandardMethodCodec().encodeSuccessEnvelope(initializedEvent),
              (ByteData? data) {},
            );
        }
        return null;
      })
      ..setMockMethodCallHandler(const MethodChannel(eventsChannelName), (MethodCall methodCall) async => null);
  }

  Future<VideoPlayerController> pumpInitializedPlayer(WidgetTester tester) async {
    late final VideoPlayerController controller;
    await tester.runAsync(() async {
      controller = VideoPlayerController();
      await controller.setNetworkDataSource('https://example.com/video.mp4');
    });
    await tester.pumpWidget(VideoPlayer(controller));
    return controller;
  }

  tearDown(() {
    messenger
      ..setMockMethodCallHandler(channel, null)
      ..setMockMethodCallHandler(const MethodChannel(eventsChannelName), null);
  });

  for (final (int degrees, int quarterTurns) in [(90, 1), (180, 2), (270, 3)]) {
    testWidgets('rotates the video by $degrees degrees when the platform reports that correction', (
      WidgetTester tester,
    ) async {
      mockPlatform(<String, Object>{
        'event': 'initialized',
        'duration': 100,
        'width': 1080,
        'height': 1920,
        'rotationCorrection': degrees,
      });

      final VideoPlayerController controller = await pumpInitializedPlayer(tester);

      expect(tester.widget<RotatedBox>(find.byType(RotatedBox)).quarterTurns, quarterTurns);

      await tester.runAsync(controller.dispose);
    });
  }

  testWidgets('does not rotate the video when the platform reports no correction', (WidgetTester tester) async {
    mockPlatform(<String, Object>{'event': 'initialized', 'duration': 100, 'width': 1920, 'height': 1080});

    final VideoPlayerController controller = await pumpInitializedPlayer(tester);

    expect(find.byType(Texture), findsOneWidget);
    expect(find.byType(RotatedBox), findsNothing);

    await tester.runAsync(controller.dispose);
  });
}
