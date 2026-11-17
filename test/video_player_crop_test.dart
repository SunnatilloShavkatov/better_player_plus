import 'package:better_player_plus/src/video_player/video_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final TestDefaultBinaryMessenger messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const MethodChannel channel = MethodChannel('better_player_channel');
  const String eventsChannelName = 'better_player_channel/videoEvents0';
  const Size videoSize = Size(704, 396);

  Future<void> reportFromPlatform(Map<String, Object> event) => messenger.handlePlatformMessage(
    eventsChannelName,
    const StandardMethodCodec().encodeSuccessEnvelope(event),
    (ByteData? data) {},
  );

  setUp(() {
    messenger
      ..setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'create':
            return <String, dynamic>{'textureId': 0};
          case 'setDataSource':
            await reportFromPlatform(<String, Object>{
              'event': 'initialized',
              'duration': 100,
              'width': videoSize.width,
              'height': videoSize.height,
            });
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

  Future<VideoPlayerController> pumpPlayer(WidgetTester tester) async {
    late final VideoPlayerController controller;
    await tester.runAsync(() async {
      controller = VideoPlayerController();
      await controller.setNetworkDataSource('https://example.com/live.m3u8');
    });
    await tester.pumpWidget(
      Center(
        child: SizedBox.fromSize(size: videoSize, child: VideoPlayer(controller)),
      ),
    );
    return controller;
  }

  group('A platform whose frames carry padding rows under the picture', () {
    testWidgets('stretches the frame so the picture fills the player and the padding falls outside it', (
      WidgetTester tester,
    ) async {
      final VideoPlayerController controller = await pumpPlayer(tester);

      // A decoder rounding 396 rows up to 416: the last 20 rows of each frame are padding.
      await tester.runAsync(
        () =>
            reportFromPlatform(<String, Object>{'event': 'crop', 'left': 0, 'top': 0, 'right': 1, 'bottom': 396 / 416}),
      );
      await tester.pump();

      expect(tester.getSize(find.byType(Texture)), const Size(704, 416));
      expect(tester.getTopLeft(find.byType(Texture)), tester.getTopLeft(find.byType(VideoPlayer)));
      expect(find.ancestor(of: find.byType(Texture), matching: find.byType(ClipRect)), findsOneWidget);

      await tester.runAsync(controller.dispose);
    });
  });

  group('A source swapped in place for one cut the same way', () {
    testWidgets('keeps the padding out of the player, though the platform does not report the crop again', (
      WidgetTester tester,
    ) async {
      final VideoPlayerController controller = await pumpPlayer(tester);
      await tester.runAsync(
        () =>
            reportFromPlatform(<String, Object>{'event': 'crop', 'left': 0, 'top': 0, 'right': 1, 'bottom': 396 / 416}),
      );

      await tester.runAsync(() => controller.setNetworkDataSource('https://example.com/live.m3u8?token=fresh'));
      await tester.pump();

      expect(tester.getSize(find.byType(Texture)), const Size(704, 416));

      await tester.runAsync(controller.dispose);
    });
  });

  group('A platform whose frames are all picture', () {
    testWidgets('shows the frame as it is', (WidgetTester tester) async {
      final VideoPlayerController controller = await pumpPlayer(tester);

      expect(tester.getSize(find.byType(Texture)), videoSize);
      expect(find.ancestor(of: find.byType(Texture), matching: find.byType(ClipRect)), findsNothing);

      await tester.runAsync(controller.dispose);
    });
  });
}
