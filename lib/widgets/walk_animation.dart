import 'package:flutter/material.dart';

class WalkAnimation extends StatelessWidget {
  final double width;
  final double height;

  const WalkAnimation({super.key, this.width = 300, this.height = 300});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/videos/loading/walk.gif',
      width: width,
      height: height,
      fit: BoxFit.contain,
    );
  }
}
