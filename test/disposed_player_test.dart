// ignore_for_file: unawaited_futures, cascade_invocations

import 'dart:async';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:better_player_plus/src/video_player/video_player.dart';
import 'package:better_player_plus/src/video_player/video_player_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'better_player_mock_controller.dart';
import 'better_player_test_utils.dart';
import 'mock_video_player_controller.dart';

/// Answers like the Android plugin: a method on a texture id that was disposed is an error, and an
/// initialization that fails arrives as an error envelope on the event channel.
class _NativePlayerMock {
  final MethodChannel channel = const MethodChannel('better_player_channel');
  final List<String> calls = [];
  final Set<int> disposed = {};
  bool failInitialization = false;
  int _nextId = 0;

  Future<Object?> handle(MethodCall methodCall) async {
    calls.add(methodCall.method);
    final arguments = methodCall.arguments;
    final textureId = arguments is Map ? arguments['textureId'] as int? : null;
    if (methodCall.method == 'create') {
      final id = _nextId++;
      _serveEvents(id);
      return <String, dynamic>{'textureId': id};
    }
    if (methodCall.method == 'dispose' && textureId != null) {
      disposed.add(textureId);
      return null;
    }
    if (textureId != null && disposed.contains(textureId)) {
      throw PlatformException(
        code: 'Unknown textureId',
        message: 'No video player associated with texture id $textureId',
      );
    }
    return <String, String>{};
  }

  void _serveEvents(int id) {
    final name = 'better_player_channel/videoEvents$id';
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(MethodChannel(name), (MethodCall methodCall) async {
      final envelope = failInitialization
          ? const StandardMethodCodec().encodeErrorEnvelope(
              code: 'VideoError',
              message: 'Video player had error: Source error',
            )
          : const StandardMethodCodec().encodeSuccessEnvelope(<String, dynamic>{
              'event': 'initialized',
              'height': 720.0,
              'width': 1280.0,
              'duration': 100,
            });
      messenger.handlePlatformMessage(name, envelope, (ByteData? data) {});
      return null;
    });
  }
}

/// A data source that loads only once the test says so, to dispose the controller mid-setup.
class _LoadingVideoPlayerController extends MockVideoPlayerController {
  new(this._loading);

  final Future<void> _loading;
  int trackSelections = 0;

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
  }) => _loading;

  @override
  Future<void> setTrackParameters(int? width, int? height, int? bitrate) async {
    trackSelections++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _NativePlayerMock native;

  setUp(() {
    native = _NativePlayerMock();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      native.channel,
      native.handle,
    );
  });

  Future<VideoPlayerController> initializedPlayer() async {
    final player = VideoPlayerController();
    await player.setNetworkDataSource(BetterPlayerTestUtils.forBiggerBlazesUrl);
    return player;
  }

  group('A call on a disposed player', () {
    test('setTrackParameters does not reach the native player', () async {
      final player = await initializedPlayer();
      await player.dispose();

      await player.setTrackParameters(1280, 720, 1000);

      expect(native.calls.where((call) => call == 'setTrackParameters'), isEmpty);
    });

    test('setAudioTrack and setMixWithOthers do not reach the native player', () async {
      final player = await initializedPlayer();
      await player.dispose();

      player.setAudioTrack('fr', 0);
      player.setMixWithOthers(true);
      await Future<void>.delayed(Duration.zero);

      expect(native.calls.where((call) => call == 'setAudioTrack' || call == 'setMixWithOthers'), isEmpty);
    });
  });

  group('A position read before the native player exists', () {
    test('answers null instead of calling the platform with no texture id', () async {
      final player = VideoPlayerController(autoCreate: false);

      expect(await player.position, isNull);
      expect(await player.absolutePosition, isNull);
      expect(native.calls, isEmpty);
    });
  });

  group('A controller disposed while its data source is still loading', () {
    test('does not select the default track on the native player', () async {
      final loading = Completer<void>();
      final player = _LoadingVideoPlayerController(loading.future);
      final controller = BetterPlayerMockController(const BetterPlayerConfiguration());
      controller.videoPlayerController = player;

      final setup = controller.setupDataSource(
        BetterPlayerDataSource.network(BetterPlayerTestUtils.forBiggerBlazesUrl),
      );
      controller.dispose(forceDispose: true);
      loading.complete();
      await setup;

      expect(player.trackSelections, 0);
    });
  });

  group('A constructor-started setup that fails', () {
    test('surfaces as one exception event and no unhandled error', () async {
      native.failInitialization = true;
      final events = <BetterPlayerEventType>[];

      final controller = BetterPlayerController(
        const BetterPlayerConfiguration(),
        betterPlayerDataSource: BetterPlayerDataSource.network(BetterPlayerTestUtils.forBiggerBlazesUrl),
      );
      controller.addEventsListener((event) => events.add(event.betterPlayerEventType));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(events.where((type) => type == BetterPlayerEventType.exception).length, 1);
      controller.dispose(forceDispose: true);
    });
  });
}
