import 'package:flutter/material.dart';

class ValidationUtils {
  static String? required({required String field, required String value}) {
    if (value.trim().isEmpty) {
      return "$field is required.";
    }

    return null;
  }

  static void snackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("${message}")));
  }
}
