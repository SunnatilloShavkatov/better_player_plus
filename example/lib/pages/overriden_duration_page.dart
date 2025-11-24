import 'package:xstream_player/xstream_player.dart';
import 'package:better_player_example/constants.dart';
import 'package:flutter/material.dart';

class OverriddenDurationPage extends StatefulWidget {
  const OverriddenDurationPage({super.key});

  @override
  State<OverriddenDurationPage> createState() => _OverriddenDurationPageState();
}

class _OverriddenDurationPageState extends State<OverriddenDurationPage> {
  late BetterPlayerController _betterPlayerController;

  @override
  void initState() {
    const BetterPlayerConfiguration betterPlayerConfiguration = BetterPlayerConfiguration(
      aspectRatio: 16 / 9,
      fit: BoxFit.contain,
    );
    _betterPlayerController = BetterPlayerController(betterPlayerConfiguration);
    _setupDataSource();
    super.initState();
  }

  Future<void> _setupDataSource() async {
    final BetterPlayerDataSource dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      Constants.elephantDreamVideoUrl,

      ///Play only 10 seconds of this video.
      overriddenDuration: const Duration(seconds: 10),
    );
    _betterPlayerController.setupDataSource(dataSource);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Overridden duration"),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Duration of this video is overridden. Now this video will have"
              " 10 seconds only.",
              style: TextStyle(fontSize: 16),
            ),
          ),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: BetterPlayer(controller: _betterPlayerController),
          ),
        ],
      ),
    );
  }
}
