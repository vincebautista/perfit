import 'package:flutter/material.dart';

class Circle extends StatelessWidget {
  final double height;
  final double width;
  final Color color;

  const Circle({
    super.key,
    required this.height,
    required this.width,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
