import 'package:perfit/core/constants/colors.dart';
import 'package:flutter/material.dart';

class AssessmentProgressBar extends StatelessWidget {
  final int currentValue;

  const AssessmentProgressBar({super.key, required this.currentValue});

  @override
  Widget build(BuildContext context) {
    final percent = currentValue / 12;

    return LinearProgressIndicator(
      value: percent.clamp(0.0, 1.0),
      backgroundColor: Colors.grey[800],
      color: AppColors.primary,
      minHeight: 6,
      borderRadius: BorderRadius.circular(4),
    );
  }
}
