import 'package:equatable/equatable.dart';

/// Represents HLS / DASH track which can be played within player
class BetterPlayerAsmsTrack extends Equatable {
  const BetterPlayerAsmsTrack(
    this.id,
    this.width,
    this.height,
    this.bitrate,
    this.frameRate,
    this.codecs,
    this.mimeType,
    this.audioGroupId,
  );

  factory BetterPlayerAsmsTrack.defaultTrack() => const BetterPlayerAsmsTrack('', 0, 0, 0, 0, '', '', '');

  ///Id of the track
  final String? id;

  ///Width in px of the track
  final int? width;

  ///Height in px of the track
  final int? height;

  ///Bitrate in px of the track
  final int? bitrate;

  ///Frame rate of the track
  final int? frameRate;

  ///Codecs of the track
  final String? codecs;

  ///mimeType of the video track
  final String? mimeType;

  ///audio group id of the video track
  final String? audioGroupId;

  @override
  List<Object?> get props => [id, width, height, bitrate, frameRate, codecs, mimeType, audioGroupId];
}
