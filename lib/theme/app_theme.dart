import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

class AppThemeColors {
  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color borderSoft;
  final Color foreground;
  final Color textStrong;
  final Color textInverse;
  final Color primary;
  final Color primaryHover;
  final Color primaryLight;
  final Color primaryLightBorder;
  final Color accent;

  const AppThemeColors({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.borderSoft,
    required this.foreground,
    required this.textStrong,
    required this.textInverse,
    required this.primary,
    required this.primaryHover,
    required this.primaryLight,
    required this.primaryLightBorder,
    required this.accent,
  });
}

class AppTheme {
  static const radius = 8.0;

  static Future<void> prewarmFonts() async {
    try {
      final fontLoader = FontLoader('UthmanicHafs');
      fontLoader.addFont(rootBundle.load('assets/fonts/UthmanicHafs.ttf'));
      await fontLoader.load();
    } catch (e) {
      debugPrint('Error pre-warming UthmanicHafs font: $e');
    }
  }

  static AppThemeColors colors({
    required bool isDark,
    required String palette,
  }) {
    if (isDark) {
      return const AppThemeColors(
        background: Color(0xFF111827),
        surface: Color(0xFF172033),
        surfaceMuted: Color(0xFF1D293D),
        borderSoft: Color(0xFF334155),
        foreground: Color(0xFFB6C2D3),
        textStrong: Color(0xFFD7E0EA),
        textInverse: Color(0xFFF1F5F9),
        primary: Color(0xFF6E91C4),
        primaryHover: Color(0xFF5F82B5),
        primaryLight: Color(0xFF22324C),
        primaryLightBorder: Color(0xFF39506F),
        accent: Color(0xFF93B4E3),
      );
    }

    return const AppThemeColors(
      background: Color(0xFFF6F8FB),
      surface: Color(0xFFFFFFFF),
      surfaceMuted: Color(0xFFF0F4F8),
      borderSoft: Color(0xFFD8E1EC),
      foreground: Color(0xFF64748B),
      textStrong: Color(0xFF334155),
      textInverse: Color(0xFFF8FAFC),
      primary: Color(0xFF4F7FB8),
      primaryHover: Color(0xFF426FA4),
      primaryLight: Color(0xFFEAF2FB),
      primaryLightBorder: Color(0xFFC9DAEF),
      accent: Color(0xFF6C93C5),
    );
  }
}
