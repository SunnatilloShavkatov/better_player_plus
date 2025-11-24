import 'package:xstream_player/xstream_player.dart';
import 'package:better_player_example/constants.dart';
import 'package:flutter/material.dart';

class AutoFullscreenOrientationPage extends StatefulWidget {
  const AutoFullscreenOrientationPage({super.key});

  @override
  State<AutoFullscreenOrientationPage> createState() => _AutoFullscreenOrientationPageState();
}

class _AutoFullscreenOrientationPageState extends State<AutoFullscreenOrientationPage> {
  late BetterPlayerController _betterPlayerController;

  @override
  void initState() {
    const BetterPlayerConfiguration betterPlayerConfiguration = BetterPlayerConfiguration(
      aspectRatio: 16 / 9,
      fit: BoxFit.contain,
      autoDetectFullscreenDeviceOrientation: true,
    );
    final BetterPlayerDataSource dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      Constants.forBiggerBlazesUrl,
    );
    _betterPlayerController = BetterPlayerController(betterPlayerConfiguration);
    _betterPlayerController.setupDataSource(dataSource);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Auto full screen orientation"),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Aspect ratio and device orientation on full screen will be "
              "managed by the BetterPlayer. Click on the fullscreen option.",
              style: TextStyle(fontSize: 16),
            ),
          ),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: BetterPlayer(controller: _betterPlayerController),
          ),
          ElevatedButton(
            child: Text("Play horizontal video"),
            onPressed: () {
              BetterPlayerDataSource dataSource =
                  BetterPlayerDataSource(BetterPlayerDataSourceType.network, Constants.forBiggerBlazesUrl);
              _betterPlayerController.setupDataSource(dataSource);
            },
          ),
          ElevatedButton(
            child: Text("Play vertical video"),
            onPressed: () async {
              BetterPlayerDataSource dataSource =
                  BetterPlayerDataSource(BetterPlayerDataSourceType.network, Constants.verticalVideoUrl);
              _betterPlayerController.setupDataSource(dataSource);
            },
          ),
        ],
      ),
    );
  }
}
