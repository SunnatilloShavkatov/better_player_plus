import 'package:better_player_plus/src/video_player/video_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final TestDefaultBinaryMessenger messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const MethodChannel channel = MethodChannel('better_player_channel');
  const String eventsChannelName = 'better_player_channel/videoEvents0';
  const Map<String, Object> initializedEvent = <String, Object>{
    'event': 'initialized',
    'duration': 100,
    'width': 1920,
    'height': 1080,
  };

  Future<void> sendInitialized() => messenger.handlePlatformMessage(
    eventsChannelName,
    const StandardMethodCodec().encodeSuccessEnvelope(initializedEvent),
    (ByteData? data) {},
  );

  tearDown(() {
    messenger
      ..setMockMethodCallHandler(channel, null)
      ..setMockMethodCallHandler(const MethodChannel(eventsChannelName), null);
  });

  testWidgets('ignores a second initialized event for the same data source', (WidgetTester tester) async {
    messenger
      ..setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'create':
            return <String, dynamic>{'textureId': 0};
          case 'setDataSource':
            // A late `initialized` from the previous source arrives together with the one for the new source.
            await sendInitialized();
            await sendInitialized();
        }
        return null;
      })
      ..setMockMethodCallHandler(const MethodChannel(eventsChannelName), (MethodCall methodCall) async => null);

    await tester.runAsync(() async {
      final VideoPlayerController controller = VideoPlayerController();
      await controller.setNetworkDataSource('https://example.com/video.mp4');

      expect(controller.value.initialized, isTrue);

      await controller.dispose();
    });
  });
}
