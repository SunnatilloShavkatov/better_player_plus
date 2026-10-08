import 'package:better_player_plus/better_player_plus.dart';
import 'package:material_ui/material_ui.dart';

class CustomControlsWidget extends StatefulWidget {
  const CustomControlsWidget({super.key, this.controller, this.onControlsVisibilityChanged});
  final BetterPlayerController? controller;
  final Function(bool visbility)? onControlsVisibilityChanged;

  @override
  State<CustomControlsWidget> createState() => _CustomControlsWidgetState();
}

class _CustomControlsWidgetState extends State<CustomControlsWidget> {
  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: InkWell(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    widget.controller!.isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              onTap: () => setState(() {
                if (widget.controller!.isFullScreen) {
                  widget.controller!.exitFullScreen();
                } else {
                  widget.controller!.enterFullScreen();
                }
              }),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    InkWell(
                      onTap: () async {
                        final Duration? videoDuration = await widget.controller!.videoPlayerController!.position;
                        setState(() {
                          if (widget.controller!.isPlaying()!) {
                            final Duration rewindDuration = Duration(seconds: videoDuration!.inSeconds - 2);
                            if (rewindDuration < widget.controller!.videoPlayerController!.value.duration!) {
                              widget.controller!.seekTo(Duration.zero);
                            } else {
                              widget.controller!.seekTo(rewindDuration);
                            }
                          }
                        });
                      },
                      child: const Icon(Icons.fast_rewind, color: Colors.white),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          if (widget.controller!.isPlaying()!) {
                            widget.controller!.pause();
                          } else {
                            widget.controller!.play();
                          }
                        });
                      },
                      child: Icon(
                        widget.controller!.isPlaying()! ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                      ),
                    ),
                    InkWell(
                      onTap: () async {
                        final Duration? videoDuration = await widget.controller!.videoPlayerController!.position;
                        setState(() {
                          if (widget.controller!.isPlaying()!) {
                            final Duration forwardDuration = Duration(seconds: videoDuration!.inSeconds + 2);
                            if (forwardDuration > widget.controller!.videoPlayerController!.value.duration!) {
                              widget.controller!.seekTo(Duration.zero);
                              widget.controller!.pause();
                            } else {
                              widget.controller!.seekTo(forwardDuration);
                            }
                          }
                        });
                      },
                      child: const Icon(Icons.fast_forward, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
