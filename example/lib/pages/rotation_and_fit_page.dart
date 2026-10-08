import 'package:better_player_example/constants.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:material_ui/material_ui.dart';

class RotationAndFitPage extends StatefulWidget {
  const RotationAndFitPage({super.key});

  @override
  State<RotationAndFitPage> createState() => _RotationAndFitPageState();
}

class _RotationAndFitPageState extends State<RotationAndFitPage> {
  late BetterPlayerController _betterPlayerController;

  @override
  void initState() {
    const BetterPlayerConfiguration betterPlayerConfiguration = BetterPlayerConfiguration(aspectRatio: 1, rotation: 90);
    final BetterPlayerDataSource dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      Constants.forBiggerBlazesUrl,
    );
    _betterPlayerController = BetterPlayerController(betterPlayerConfiguration);
    _betterPlayerController.setupDataSource(dataSource);
    super.initState();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Rotation and fit')),
    body: Column(
      children: [
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('Player with different rotation and fit.', style: TextStyle(fontSize: 16)),
        ),
        AspectRatio(aspectRatio: 1, child: BetterPlayer(controller: _betterPlayerController)),
      ],
    ),
  );
}
