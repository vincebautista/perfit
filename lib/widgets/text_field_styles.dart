import 'package:flutter/material.dart';

class TextFieldStyles {
  static InputDecoration primary({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(label: Text(label), suffixIcon: Icon(icon));
  }
}
