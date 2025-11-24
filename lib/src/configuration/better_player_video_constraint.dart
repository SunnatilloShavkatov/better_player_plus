class BetterPlayerVideoConstraint {
  const BetterPlayerVideoConstraint({this.width, this.height, this.bitrate});
  final int? width;
  final int? height;
  final int? bitrate;

  Map<String, int> toMap() => {'width': width ?? 0, 'height': height ?? 0, 'bitrate': bitrate ?? 0};
}
