import 'dart:async';

import 'package:xstream_player/xstream_player.dart';
import 'package:better_player_example/constants.dart';
import 'package:flutter/material.dart';

class FadePlaceholderPage extends StatefulWidget {
  const FadePlaceholderPage({super.key});

  @override
  State<FadePlaceholderPage> createState() => _FadePlaceholderPageState();
}

class _FadePlaceholderPageState extends State<FadePlaceholderPage> {
  late BetterPlayerController _betterPlayerController;
  final StreamController<bool> _playController = StreamController.broadcast();

  @override
  void initState() {
    final BetterPlayerConfiguration betterPlayerConfiguration = BetterPlayerConfiguration(
      aspectRatio: 16 / 9,
      fit: BoxFit.contain,
      placeholder: _buildPlaceholder(),
      showPlaceholderUntilPlay: true,
      placeholderOnTop: false,
    );
    final BetterPlayerDataSource dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      Constants.forBiggerBlazesUrl,
    );
    _betterPlayerController = BetterPlayerController(betterPlayerConfiguration);
    _betterPlayerController.setupDataSource(dataSource);
    _betterPlayerController.addEventsListener((event) {
      if (event.betterPlayerEventType == BetterPlayerEventType.play) {
        _playController.add(false);
      }
    });
    super.initState();
  }

  Widget _buildPlaceholder() {
    return StreamBuilder<bool>(
      stream: _playController.stream,
      builder: (context, snapshot) {
        bool showPlaceholder = snapshot.data ?? true;
        return AnimatedOpacity(
          duration: Duration(milliseconds: 500),
          opacity: showPlaceholder ? 1.0 : 0.0,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.network(
              Constants.catImageUrl,
              fit: BoxFit.fill,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Fade placeholder player"),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Normal player with placeholder which fade.",
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
