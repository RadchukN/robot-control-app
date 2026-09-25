import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF8A2BE2);
  static const secondary = Color(0xFF546179);
  static const tertiary = Color(0xFF7A4FA3);
  static const success = Color(0xFF146C2E);
  static const info = Color(0xFF0061A4);
  static const warning = Color(0xFF7A5900);
  static const error = Color(0xFFBA1A1A);
  static const lightSurface = Color(0xFFF7FAFF);
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
