import 'package:xstream_player/xstream_player.dart';
import 'package:better_player_example/constants.dart';
import 'package:better_player_example/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PlaylistPage extends StatefulWidget {
  const PlaylistPage({super.key});

  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  _PlaylistPageState() {
    _betterPlayerConfiguration = const BetterPlayerConfiguration(
      aspectRatio: 1,
      fit: BoxFit.cover,
      showPlaceholderUntilPlay: true,
      subtitlesConfiguration: BetterPlayerSubtitlesConfiguration(fontSize: 10),
      deviceOrientationsAfterFullScreen: [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
    );
    _betterPlayerPlaylistConfiguration = const BetterPlayerPlaylistConfiguration();
  }
  final GlobalKey<BetterPlayerPlaylistState> _betterPlayerPlaylistStateKey = GlobalKey();
  final List<BetterPlayerDataSource> _dataSourceList = [];
  late BetterPlayerConfiguration _betterPlayerConfiguration;
  late BetterPlayerPlaylistConfiguration _betterPlayerPlaylistConfiguration;

  Future<List<BetterPlayerDataSource>> setupData() async {
    _dataSourceList.add(
      BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        Constants.forBiggerBlazesUrl,
        subtitles: BetterPlayerSubtitlesSource.single(
          type: BetterPlayerSubtitlesSourceType.file,
          url: await Utils.getFileUrl(Constants.fileExampleSubtitlesUrl),
        ),
        placeholder: Image.network(Constants.catImageUrl, fit: BoxFit.cover),
      ),
    );

    _dataSourceList.add(
      BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        Constants.bugBuckBunnyVideoUrl,
        placeholder: Image.network(Constants.catImageUrl, fit: BoxFit.cover),
      ),
    );
    _dataSourceList.add(
      BetterPlayerDataSource(BetterPlayerDataSourceType.network, Constants.forBiggerJoyridesVideoUrl),
    );

    return _dataSourceList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Playlist")),
      body: FutureBuilder<List<BetterPlayerDataSource>>(
        future: setupData(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Text("Building!");
          } else {
            return ListView(
              children: [
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    "Playlist widget will load automatically next video once current "
                    "finishes. User can't use player controls when video is changing.",
                  ),
                ),
                AspectRatio(
                  aspectRatio: 1,
                  child: BetterPlayerPlaylist(
                    key: _betterPlayerPlaylistStateKey,
                    betterPlayerConfiguration: _betterPlayerConfiguration,
                    betterPlayerPlaylistConfiguration: _betterPlayerPlaylistConfiguration,
                    betterPlayerDataSourceList: snapshot.data!,
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    _betterPlayerPlaylistController!.setupDataSource(0);
                  },
                  child: Text("Change to first data source"),
                ),
                ElevatedButton(
                  onPressed: () {
                    _betterPlayerPlaylistController!.setupDataSource(2);
                  },
                  child: Text("Change to last source"),
                ),
                ElevatedButton(
                  onPressed: () {
                    debugPrint("Currently playing video: ${_betterPlayerPlaylistController!.currentDataSourceIndex}");
                  },
                  child: Text("Check currently playing video index"),
                ),
                ElevatedButton(
                  onPressed: () {
                    _betterPlayerPlaylistController!.betterPlayerController!.pause();
                  },
                  child: Text("Pause current video with BetterPlayerController"),
                ),
                ElevatedButton(
                  onPressed: () {
                    var list = [
                      BetterPlayerDataSource(
                        BetterPlayerDataSourceType.network,
                        Constants.bugBuckBunnyVideoUrl,
                        placeholder: Image.network(Constants.catImageUrl, fit: BoxFit.cover),
                      ),
                    ];
                    _betterPlayerPlaylistController?.setupDataSourceList(list);
                  },
                  child: Text("Setup new data source list"),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  BetterPlayerPlaylistController? get _betterPlayerPlaylistController =>
      _betterPlayerPlaylistStateKey.currentState!.betterPlayerPlaylistController;
}
