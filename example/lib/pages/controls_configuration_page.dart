import 'package:better_player_example/constants.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:material_ui/material_ui.dart';

class ControlsConfigurationPage extends StatefulWidget {
  const ControlsConfigurationPage({super.key});

  @override
  State<ControlsConfigurationPage> createState() => _ControlsConfigurationPageState();
}

class _ControlsConfigurationPageState extends State<ControlsConfigurationPage> {
  late BetterPlayerController _betterPlayerController;

  @override
  void initState() {
    final BetterPlayerControlsConfiguration controlsConfiguration = BetterPlayerControlsConfiguration(
      controlBarColor: Colors.indigoAccent.withAlpha(200),
      iconsColor: Colors.lightGreen,
      playIcon: Icons.forward,
      progressBarPlayedColor: Colors.grey,
      progressBarHandleColor: Colors.lightGreen,
      enableSkips: false,
      enableFullscreen: false,
      controlBarHeight: 60,
      loadingColor: Colors.red,
      overflowModalColor: Colors.indigo,
      overflowModalTextColor: Colors.white,
      overflowMenuIconsColor: Colors.white,
    );

    final BetterPlayerConfiguration betterPlayerConfiguration = BetterPlayerConfiguration(
      aspectRatio: 16 / 9,
      fit: BoxFit.contain,
      controlsConfiguration: controlsConfiguration,
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Controls configuration')),
    body: Column(
      children: [
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Player with customized controls via BetterPlayerControlsConfiguration.',
            style: TextStyle(fontSize: 16),
          ),
        ),
        AspectRatio(
          aspectRatio: 16 / 9,
          child: BetterPlayer(controller: _betterPlayerController),
        ),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _betterPlayerController.setBetterPlayerControlsConfiguration(
                const BetterPlayerControlsConfiguration(overflowModalColor: Colors.amberAccent),
              );
            });
          },
          child: const Text('Reset settings'),
        ),
      ],
    ),
  );
}
