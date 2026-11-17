import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('better_player_channel');
  final List<MethodCall> calls = <MethodCall>[];

  Iterable<MethodCall> audioSessionCalls() => calls.where((MethodCall call) => call.method == 'setManagesAudioSession');

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      MethodCall call,
    ) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('handing the audio session to the app tells the platform', () async {
    await BetterPlayerController.setManagesAudioSession(false);

    expect(audioSessionCalls().single.arguments, <String, dynamic>{'managesAudioSession': false});
  });

  test('a call the platform rejects reaches the caller instead of being swallowed', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      MethodCall call,
    ) async {
      if (call.method == 'setManagesAudioSession') {
        throw PlatformException(code: 'INVALID_ARGUMENT');
      }
      return null;
    });

    await expectLater(
      BetterPlayerController.setManagesAudioSession(false),
      throwsA(isA<PlatformException>().having((PlatformException error) => error.code, 'code', 'INVALID_ARGUMENT')),
    );
  });

  test('taking the audio session back tells the platform', () async {
    await BetterPlayerController.setManagesAudioSession(true);

    expect(audioSessionCalls().single.arguments, <String, dynamic>{'managesAudioSession': true});
  });
}
