import 'package:xstream_player/xstream_player.dart';
import 'package:xstream_player/src/core/better_player_utils.dart';

// Flutter imports:
import 'package:flutter/material.dart';

///Special version of Better Player used to play videos in playlist.
class BetterPlayerPlaylist extends StatefulWidget {
  const BetterPlayerPlaylist({
    super.key,
    required this.betterPlayerDataSourceList,
    required this.betterPlayerConfiguration,
    required this.betterPlayerPlaylistConfiguration,
  });
  final List<BetterPlayerDataSource> betterPlayerDataSourceList;
  final BetterPlayerConfiguration betterPlayerConfiguration;
  final BetterPlayerPlaylistConfiguration betterPlayerPlaylistConfiguration;

  @override
  BetterPlayerPlaylistState createState() => BetterPlayerPlaylistState();
}

///State of BetterPlayerPlaylist, used to access BetterPlayerPlaylistController.
class BetterPlayerPlaylistState extends State<BetterPlayerPlaylist> {
  BetterPlayerPlaylistController? _betterPlayerPlaylistController;

  BetterPlayerController? get _betterPlayerController => _betterPlayerPlaylistController!.betterPlayerController;

  ///Get BetterPlayerPlaylistController
  BetterPlayerPlaylistController? get betterPlayerPlaylistController => _betterPlayerPlaylistController;

  @override
  void initState() {
    _betterPlayerPlaylistController = BetterPlayerPlaylistController(
      widget.betterPlayerDataSourceList,
      betterPlayerConfiguration: widget.betterPlayerConfiguration,
      betterPlayerPlaylistConfiguration: widget.betterPlayerPlaylistConfiguration,
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: _betterPlayerController!.getAspectRatio() ?? BetterPlayerUtils.calculateAspectRatio(context),
    child: BetterPlayer(controller: _betterPlayerController!),
  );

  @override
  void dispose() {
    _betterPlayerPlaylistController!.dispose();
    super.dispose();
  }
}
