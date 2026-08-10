import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF4255D4);
  static const secondary = Color(0xFF546179);
  static const tertiary = Color(0xFF7A4FA3);
  static const success = Color(0xFF17845B);
  static const warning = Color(0xFFAA6600);
  static const error = Color(0xFFBA1A1A);
  static const lightSurface = Color(0xFFF9F9FF);
  static const darkSurface = Color(0xFF111318);

  static ColorScheme lightScheme() => ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        surface: lightSurface,
      );

  static ColorScheme darkScheme() => ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.dark,
        surface: darkSurface,
      );
}
