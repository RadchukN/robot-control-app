import 'package:flutter/material.dart';

abstract final class AppTypography {
  static TextTheme textTheme(Brightness brightness) {
    final color = brightness == Brightness.light ? Colors.black87 : Colors.white;
    return TextTheme(
      displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: color),
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: color),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: color),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: color),
      bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: color),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color),
    );
  }
}
