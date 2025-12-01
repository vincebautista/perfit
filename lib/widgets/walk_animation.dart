import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class WalkAnimation extends StatefulWidget {
  final double width;
  final double height;

  const WalkAnimation({super.key, this.width = 300, this.height = 100});

  @override
  State<WalkAnimation> createState() => _WalkAnimationState();
}

class _WalkAnimationState extends State<WalkAnimation> {
  late VideoPlayerController _controller;
  late ChewieController _chewieController;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(
        'assets/videos/loading/walk_animation.mov', // convert to mp4 for Android
      )
      ..initialize().then((_) {
        _controller.setLooping(true);
        _controller.play();

        _chewieController = ChewieController(
          videoPlayerController: _controller,
          autoPlay: true,
          looping: true,
          showControls: false,
          aspectRatio: 1, // square animation
        );

        setState(() {}); // rebuild to show the animation
      });
  }

  @override
  void dispose() {
    _chewieController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      // fallback while video loads
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    return SizedBox(
      width: 300,
      height: 100,
      child: Chewie(controller: _chewieController),
    );
  }
}
