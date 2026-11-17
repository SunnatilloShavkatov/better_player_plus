import 'package:better_player_plus/src/video_player/video_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final TestDefaultBinaryMessenger messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const MethodChannel channel = MethodChannel('better_player_channel');
  const String eventsChannelName = 'better_player_channel/videoEvents0';
  late List<String> calls;

  Future<void> reportFromPlatform(String event) async {
    await messenger.handlePlatformMessage(
      eventsChannelName,
      const StandardMethodCodec().encodeSuccessEnvelope(<String, Object>{'event': event}),
      (ByteData? data) {},
    );
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() {
    calls = [];
    messenger
      ..setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        calls.add(methodCall.method);
        switch (methodCall.method) {
          case 'create':
            return <String, dynamic>{'textureId': 0};
          case 'setDataSource':
            await messenger.handlePlatformMessage(
              eventsChannelName,
              const StandardMethodCodec().encodeSuccessEnvelope(<String, Object>{
                'event': 'initialized',
                'duration': 100,
                'width': 1920,
                'height': 1080,
              }),
              (ByteData? data) {},
            );
        }
        return null;
      })
      ..setMockMethodCallHandler(const MethodChannel(eventsChannelName), (MethodCall methodCall) async => null);
  });

  tearDown(() {
    messenger
      ..setMockMethodCallHandler(channel, null)
      ..setMockMethodCallHandler(const MethodChannel(eventsChannelName), null);
  });

  group('A play or pause reported by the platform', () {
    test('is followed without being sent back to the platform', () async {
      final VideoPlayerController controller = VideoPlayerController();
      await controller.setNetworkDataSource('https://example.com/video.m3u8');
      calls.clear();

      // What a pause and a play sent back to back look like from the platform.
      await reportFromPlatform('pause');
      await reportFromPlatform('play');

      expect(calls.where((call) => call == 'play' || call == 'pause'), isEmpty);
      expect(controller.value.isPlaying, isTrue);

      await controller.dispose();
    });

    test('leaves the player paused when the platform last reported a pause', () async {
      final VideoPlayerController controller = VideoPlayerController();
      await controller.setNetworkDataSource('https://example.com/video.m3u8');

      await reportFromPlatform('play');
      await reportFromPlatform('pause');

      expect(controller.value.isPlaying, isFalse);

      await controller.dispose();
    });
  });
}
