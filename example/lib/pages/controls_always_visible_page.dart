import 'package:xstream_player/xstream_player.dart';
import 'package:better_player_example/constants.dart';
import 'package:flutter/material.dart';

class ControlsAlwaysVisiblePage extends StatefulWidget {
  const ControlsAlwaysVisiblePage({super.key});

  @override
  State<ControlsAlwaysVisiblePage> createState() => _ControlsAlwaysVisiblePageState();
}

class _ControlsAlwaysVisiblePageState extends State<ControlsAlwaysVisiblePage> {
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
    );
    _betterPlayerController.setupDataSource(dataSource);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Controls always visible"),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Controls are always visible. Click on button below to"
              " enable/disable this mode.",
              style: TextStyle(fontSize: 16),
            ),
          ),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: BetterPlayer(controller: _betterPlayerController),
          ),
          ElevatedButton(
              onPressed: () {
                _betterPlayerController.setControlsAlwaysVisible(!(_betterPlayerController.controlsAlwaysVisible));
              },
              child: Text("Toggle always visible controls"))
        ],
      ),
    );
  }
}
