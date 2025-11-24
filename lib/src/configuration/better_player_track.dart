import 'package:equatable/equatable.dart';

enum TrackType { audio, video, subtitle, unknown }

class BetterPlayerTrack extends Equatable {
  const BetterPlayerTrack({
    required this.type,
    required this.width,
    required this.height,
    required this.bitrate,
    this.frameRate,
    this.isSupported,
    this.groupIndex,
    this.groupId,
    this.id,
    this.audioGroupId,
    this.mime,
    this.language,
    this.label,
  });
  factory BetterPlayerTrack.defaultTrack() => const BetterPlayerTrack(
    type: TrackType.unknown,
    width: -1,
    height: -1,
    bitrate: -1,
    frameRate: -1,
    isSupported: true,
  );
  factory BetterPlayerTrack.fromJson(Map<dynamic, dynamic> json) {
    if (json.isEmpty) {
      return BetterPlayerTrack.defaultTrack();
    }
    return BetterPlayerTrack(
      type: typeFromString(json['type']),
      groupId: json['groupId'],
      groupIndex: json['groupIndex'],
      id: json['id'],
      mime: json['mime'],
      language: json['language'],
      label: json['label'],
      width: json['width'],
      height: json['height'],
      bitrate: json['bitrate'],
      frameRate: json['frameRate'],
      isSupported: json['isSupported'],
      audioGroupId: json['audioGroupId'],
    );
  }
  final TrackType type;
  final String? id;
  final String? mime;
  final String? language;
  final String? label;
  final String? groupId;
  final double? frameRate;
  final String? audioGroupId;
  final int? groupIndex;
  final bool? isSupported;
  final int width;
  final int height;
  final int bitrate;

  @override
  List<Object?> get props => [
    type,
    groupId,
    id,
    mime,
    language,
    label,
    width,
    height,
    bitrate,
    frameRate,
    isSupported,
    audioGroupId,
  ];

  static List<BetterPlayerTrack> tracksFromJson(List<dynamic> json) {
    return json.map((e) => BetterPlayerTrack.fromJson(e)).toList();
  }

  static TrackType typeFromString(String type) {
    switch (type.toLowerCase()) {
      case 'video':
        return TrackType.video;
      case 'audio':
        return TrackType.audio;
      case 'subtitle':
        return TrackType.subtitle;
      default:
        return TrackType.unknown;
    }
  }

  @override
  String toString() {
    return "BetterPlayerTrack(type: $type, id: $id, mime: $mime, language: $language, label: $label, groupIndex: $groupIndex, width: $width, height: $height,bitrate: $bitrate, frameRate: $frameRate, isSupported: $isSupported, audioGroupId: $audioGroupId)";
  }
}
