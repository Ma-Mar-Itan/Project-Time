import 'package:flutter/material.dart';

/// Google Tasks-inspired palette. These are the raw brand colors; the
/// [ColorScheme]s are assembled in `app_theme.dart`.
class AppColors {
  const AppColors._();

  // Light brand
  static const Color primaryBlue = Color(0xFF1A73E8);
  static const Color primaryBlueAlt = Color(0xFF4285F4);
  static const Color textPrimary = Color(0xFF202124);
  static const Color textSecondary = Color(0xFF5F6368);
  static const Color background = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF8F9FA);
  static const Color border = Color(0xFFDADCE0);
  static const Color borderSubtle = Color(0xFFE8EAED);

  // Dark brand
  static const Color darkBackground = Color(0xFF202124);
  static const Color darkSurface = Color(0xFF292A2D);
  static const Color darkSurfaceRaised = Color(0xFF303134);
  static const Color darkTextPrimary = Color(0xFFE8EAED);
  static const Color darkTextSecondary = Color(0xFFBDC1C6);
  static const Color darkPrimaryBlue = Color(0xFF8AB4F8);
  static const Color darkBorder = Color(0xFF3C4043);

  // Semantic status colors (used in both themes, with status text too).
  static const Color running = Color(0xFF188038);
  static const Color paused = Color(0xFFF9AB00);
  static const Color destructive = Color(0xFFD93025);

  static const Color runningDark = Color(0xFF81C995);
  static const Color pausedDark = Color(0xFFFDD663);
  static const Color destructiveDark = Color(0xFFF28B82);

  /// Predefined selectable project colors (label -> color).
  static const Map<String, Color> projectPalette = {
    'Blue': Color(0xFF1A73E8),
    'Green': Color(0xFF188038),
    'Yellow': Color(0xFFF9AB00),
    'Orange': Color(0xFFE8710A),
    'Red': Color(0xFFD93025),
    'Purple': Color(0xFF9334E6),
    'Teal': Color(0xFF12A4AF),
    'Gray': Color(0xFF5F6368),
  };

  static Color defaultProjectColor() => projectPalette['Blue']!;
}
