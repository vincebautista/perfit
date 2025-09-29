import 'package:perfit/core/constants/sizes.dart';
import 'package:flutter/material.dart';

class ButtonStyles {
  static ButtonStyle customButton = ButtonStyle(
    minimumSize: WidgetStatePropertyAll(Size(1, AppSizes.buttonLarge)),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.roundedRadius),
      ),
    ),
  );
}
