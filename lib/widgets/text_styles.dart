import 'package:perfit/core/constants/colors.dart';
import 'package:perfit/core/constants/sizes.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TextStyles {
  static TextStyle heading = GoogleFonts.poppins(
    fontSize: AppSizes.fontSize28,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
  );

  static TextStyle title = GoogleFonts.poppins(
    fontSize: AppSizes.fontSize24,
    fontWeight: FontWeight.bold,
  );

  static TextStyle subtitle = GoogleFonts.poppins(
    fontSize: AppSizes.fontSize20,
    fontWeight: FontWeight.w300,
  );

  static TextStyle body = GoogleFonts.poppins(
    fontSize: AppSizes.fontSize16,
    fontWeight: FontWeight.normal,
  );

  static TextStyle label = GoogleFonts.poppins(
    fontSize: AppSizes.fontSize12,
    fontWeight: FontWeight.normal,
  );

  static TextStyle caption = GoogleFonts.poppins(
    fontSize: AppSizes.fontSize12,
    fontWeight: FontWeight.normal,
    color: AppColors.lightgrey,
  );

  static TextStyle buttonLarge = GoogleFonts.poppins(
    fontSize: AppSizes.fontSize16,
    fontWeight: FontWeight.normal,
  );

  static TextStyle buttonSmall = GoogleFonts.poppins(
    fontSize: AppSizes.fontSize12,
    fontWeight: FontWeight.normal,
  );
}
