import 'package:better_player_plus/src/asms/better_player_asms_data_holder.dart';
import 'package:better_player_plus/src/hls/better_player_hls_utils.dart';
import 'package:better_player_plus/src/hls/hls_parser/exception.dart';
import 'package:better_player_plus/src/hls/hls_parser/hls_playlist_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final Uri uri = Uri.parse('https://example.com/master.m3u8');

  group('HlsPlaylistParser given an empty master playlist', () {
    test('rejects an empty body as unrecognized input instead of a RangeError', () {
      expect(() => HlsPlaylistParser.create().parseString(uri, ''), throwsA(isA<UnrecognizedInputFormatException>()));
    });

    test('rejects a whitespace-only body the same way', () {
      expect(
        () => HlsPlaylistParser.create().parseString(uri, '\n   \n\t\n'),
        throwsA(isA<UnrecognizedInputFormatException>()),
      );
    });
  });

  group('BetterPlayerHlsUtils given an empty master playlist', () {
    test('yields no tracks, subtitles or audio tracks and does not throw', () async {
      final BetterPlayerAsmsDataHolder holder = await BetterPlayerHlsUtils.parse('', uri.toString());

      expect(holder.tracks, isEmpty);
      expect(holder.subtitles, isEmpty);
      expect(holder.audios, isEmpty);
    });
  });
}
