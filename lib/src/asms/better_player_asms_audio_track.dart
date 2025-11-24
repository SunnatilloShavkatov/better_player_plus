import 'package:equatable/equatable.dart';

///Representation of HLS / DASH audio track
class BetterPlayerAsmsAudioTrack extends Equatable {
  const BetterPlayerAsmsAudioTrack({
    this.id,
    this.segmentAlignment,
    this.label,
    this.language,
    this.url,
    this.mimeType,
    this.audioGroupId,
  });

  ///Audio index in DASH xml or Id of track inside HLS playlist
  final int? id;

  ///segmentAlignment
  final bool? segmentAlignment;

  ///Description of the audio
  final String? label;

  ///Language code
  final String? language;

  ///Url of audio track
  final String? url;

  ///mimeType of the audio track
  final String? mimeType;

  ///group id
  final String? audioGroupId;

  @override
  List<Object?> get props => [id, segmentAlignment, label, language, url, mimeType, audioGroupId];
}
