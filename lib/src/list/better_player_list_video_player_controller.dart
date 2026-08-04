import 'package:better_player_plus/better_player_plus.dart';
import 'package:better_player_plus/src/video_player/video_player.dart';

///Controller of Better Player List Video Player.
class BetterPlayerListVideoPlayerController {
  BetterPlayerController? innerBetterPlayerController;

  void setVolume(double volume) {
    innerBetterPlayerController?.setVolume(volume);
  }

  void pause() {
    innerBetterPlayerController?.pause();
  }

  void play() {
    innerBetterPlayerController?.play();
  }

  void seekTo(Duration duration) {
    innerBetterPlayerController?.seekTo(duration);
  }

  // Kept as a method (not a setter) to maintain a consistent API with the rest of the controller
  // ignore: use_setters_to_change_properties
  void setBetterPlayerController(BetterPlayerController? betterPlayerController) {
    innerBetterPlayerController = betterPlayerController;
  }

  void setMixWithOthers(bool mixWithOthers) {
    innerBetterPlayerController?.setMixWithOthers(mixWithOthers);
  }
}
