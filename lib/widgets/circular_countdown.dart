import 'package:flutter/material.dart';
import 'package:perfit/core/constants/colors.dart';

class CircularCountdown extends StatelessWidget {
  final int secondsLeft;
  final int totalSeconds;
  final double width;
  final double height;

  const CircularCountdown({
    super.key,
    required this.secondsLeft,
    required this.totalSeconds,
    this.width = 120,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    double progress = secondsLeft / totalSeconds;

    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: width,
          height: height,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(seconds: 1),
            curve: Curves.linear,
            builder: (context, value, child) {
              return CircularProgressIndicator(
                value: value,
                strokeWidth: 10,
                backgroundColor: Colors.grey.shade300,
                color: AppColors.primary, // you can customize
              );
            },
          ),
        ),

        // Countdown number
        Text(
          "$secondsLeft",
          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
