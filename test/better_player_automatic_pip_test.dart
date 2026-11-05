import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'better_player_test_utils.dart';
import 'mock_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final MockMethodChannel mockMethodChannel = MockMethodChannel();
  final List<MethodCall> calls = [];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      mockMethodChannel.channel,
      (MethodCall call) {
        calls.add(call);
        return mockMethodChannel.handle(call);
      },
    );
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  Future<List<Object?>> automaticPipCalls(BetterPlayerControlsConfiguration controlsConfiguration) async {
    final controller = BetterPlayerController(BetterPlayerConfiguration(controlsConfiguration: controlsConfiguration));
    await controller.setupDataSource(BetterPlayerDataSource.network(BetterPlayerTestUtils.forBiggerBlazesUrl));

    return calls
        .where((call) => call.method == 'setAutomaticPictureInPicture')
        .map((call) => (call.arguments as Map<Object?, Object?>)['enabled'])
        .toList();
  }

  test('disables automatic PiP on iOS when enablePip is false', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    expect(await automaticPipCalls(const BetterPlayerControlsConfiguration(enablePip: false)), [false]);
  });

  test('enables automatic PiP on iOS when enablePip is true', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    expect(await automaticPipCalls(const BetterPlayerControlsConfiguration()), [true]);
  });

  test('does not configure automatic PiP on Android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    expect(await automaticPipCalls(const BetterPlayerControlsConfiguration(enablePip: false)), isEmpty);
  });
}
