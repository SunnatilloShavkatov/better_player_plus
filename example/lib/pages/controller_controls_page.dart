import 'package:xstream_player/xstream_player.dart';
import 'package:better_player_example/constants.dart';
import 'package:flutter/material.dart';

class ControllerControlsPage extends StatefulWidget {
  const ControllerControlsPage({super.key});

  @override
  State<ControllerControlsPage> createState() => _ControllerControlsPageState();
}

class _ControllerControlsPageState extends State<ControllerControlsPage> {
  late BetterPlayerController _betterPlayerController;

  @override
  void initState() {
    const BetterPlayerConfiguration betterPlayerConfiguration = BetterPlayerConfiguration(
      aspectRatio: 16 / 9,
      fit: BoxFit.contain,
    );
    final BetterPlayerDataSource dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      Constants.elephantDreamVideoUrl,
    );
    _betterPlayerController = BetterPlayerController(betterPlayerConfiguration);
    _betterPlayerController.setupDataSource(dataSource);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Controller controls")),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Control player with BetterPlayerController. You can control all"
              "aspects of player without using UI of player.",
              style: TextStyle(fontSize: 16),
            ),
          ),
          AspectRatio(aspectRatio: 16 / 9, child: BetterPlayer(controller: _betterPlayerController)),
          Wrap(
            children: [
              TextButton(onPressed: _betterPlayerController.play, child: Text("Play")),
              TextButton(onPressed: _betterPlayerController.pause, child: Text("Pause")),
              TextButton(
                child: Text("Hide controls"),
                onPressed: () {
                  _betterPlayerController.setControlsVisibility(false);
                },
              ),
              TextButton(
                child: Text("Show controls"),
                onPressed: () {
                  _betterPlayerController.setControlsVisibility(true);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
