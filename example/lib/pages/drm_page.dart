import 'package:xstream_player/xstream_player.dart';
import 'package:better_player_example/constants.dart';
import 'package:flutter/material.dart';

class DrmPage extends StatefulWidget {
  const DrmPage({super.key});

  @override
  State<DrmPage> createState() => _DrmPageState();
}

class _DrmPageState extends State<DrmPage> {
  late BetterPlayerController _tokenController;
  late BetterPlayerController _widevineController;
  late BetterPlayerController _fairplayController;

  @override
  void initState() {
    const BetterPlayerConfiguration betterPlayerConfiguration = BetterPlayerConfiguration(
      aspectRatio: 16 / 9,
      fit: BoxFit.contain,
    );
    final BetterPlayerDataSource tokenDataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      Constants.tokenEncodedHlsUrl,
      videoFormat: BetterPlayerVideoFormat.hls,
      drmConfiguration: BetterPlayerDrmConfiguration(
        drmType: BetterPlayerDrmType.token,
        token: Constants.tokenEncodedHlsToken,
      ),
    );
    _tokenController = BetterPlayerController(betterPlayerConfiguration);
    _tokenController.setupDataSource(tokenDataSource);

    _widevineController = BetterPlayerController(betterPlayerConfiguration);
    final BetterPlayerDataSource widevineDataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      Constants.widevineVideoUrl,
      drmConfiguration: BetterPlayerDrmConfiguration(
        drmType: BetterPlayerDrmType.widevine,
        licenseUrl: Constants.widevineLicenseUrl,
        headers: {'Test': 'Test2'},
      ),
    );
    _widevineController.setupDataSource(widevineDataSource);

    _fairplayController = BetterPlayerController(betterPlayerConfiguration);
    final BetterPlayerDataSource fairplayDataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      Constants.fairplayHlsUrl,
      drmConfiguration: BetterPlayerDrmConfiguration(
        drmType: BetterPlayerDrmType.fairplay,
        certificateUrl: Constants.fairplayCertificateUrl,
        licenseUrl: Constants.fairplayLicenseUrl,
      ),
    );
    _fairplayController.setupDataSource(fairplayDataSource);

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("DRM player"),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Auth token based DRM.",
                style: TextStyle(fontSize: 16),
              ),
            ),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: BetterPlayer(controller: _tokenController),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Widevine - license url based DRM. Works only for Android.",
                style: TextStyle(fontSize: 16),
              ),
            ),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: BetterPlayer(controller: _widevineController),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Fairplay - certificate url based EZDRM. Works only for iOS.",
                style: TextStyle(fontSize: 16),
              ),
            ),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: BetterPlayer(controller: _fairplayController),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}
