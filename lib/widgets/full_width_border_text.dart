import 'package:flutter/material.dart';
import 'package:perfit/core/constants/colors.dart';
import 'package:perfit/core/constants/sizes.dart';

class FullWidthBorderText extends StatelessWidget {
  final String text;
  final double borderWidth;
  final double padding;
  final TextStyle? style;

  const FullWidthBorderText({
    required this.text,
    this.borderWidth = 1.5,
    this.padding = 12.0,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.white, width: borderWidth),
        borderRadius: BorderRadius.circular(AppSizes.roundedRadius),
      ),
      child: Text(
        text,
        style: style ?? const TextStyle(color: AppColors.white, fontSize: 16),
      ),
    );
  }
}
