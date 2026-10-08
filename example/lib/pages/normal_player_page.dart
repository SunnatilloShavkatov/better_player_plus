import 'package:better_player_example/constants.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

class NormalPlayerPage extends StatefulWidget {
  const NormalPlayerPage({super.key});

  @override
  State<NormalPlayerPage> createState() => _NormalPlayerPageState();
}

class _NormalPlayerPageState extends State<NormalPlayerPage> {
  late BetterPlayerController _betterPlayerController;
  late BetterPlayerDataSource _betterPlayerDataSource;

  @override
  void initState() {
    const BetterPlayerConfiguration betterPlayerConfiguration = BetterPlayerConfiguration(
      aspectRatio: 16 / 9,
      fit: BoxFit.contain,
      autoPlay: true,
      looping: true,
      deviceOrientationsAfterFullScreen: [DeviceOrientation.portraitDown, DeviceOrientation.portraitUp],
    );
    _betterPlayerDataSource = BetterPlayerDataSource(BetterPlayerDataSourceType.network, Constants.forBiggerBlazesUrl);
    _betterPlayerController = BetterPlayerController(betterPlayerConfiguration);
    _betterPlayerController.setupDataSource(_betterPlayerDataSource);
    super.initState();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Normal player page')),
    body: Column(
      children: [
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 16 / 9,
          child: BetterPlayer(controller: _betterPlayerController),
        ),
      ],
    ),
  );
}
