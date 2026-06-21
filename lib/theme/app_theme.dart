import 'package:flutter/material.dart';

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

  static AppThemeColors colors({
    required bool isDark,
    required String palette,
  }) {
    final base = isDark
        ? const AppThemeColors(
            background: Color(0xFF151711),
            surface: Color(0xFF1D1F19),
            surfaceMuted: Color(0xFF191B16),
            borderSoft: Color(0xFF33362D),
            foreground: Color(0xFFD7D0C5),
            textStrong: Color(0xFFEBE4D8),
            textInverse: Color(0xFFF4EFE6),
            primary: Color(0xFF607465),
            primaryHover: Color(0xFF53675A),
            primaryLight: Color(0xFF263129),
            primaryLightBorder: Color(0xFF3B493D),
            accent: Color(0xFF9AA58F),
          )
        : const AppThemeColors(
            background: Color(0xFFF8F7F2),
            surface: Color(0xFFFFFEFA),
            surfaceMuted: Color(0xFFF3F5EF),
            borderSoft: Color(0xFFE0E4D9),
            foreground: Color(0xFF4F554D),
            textStrong: Color(0xFF262C25),
            textInverse: Color(0xFFF8F7F2),
            primary: Color(0xFF607465),
            primaryHover: Color(0xFF53675A),
            primaryLight: Color(0xFFEEF3EC),
            primaryLightBorder: Color(0xFFD7DFD3),
            accent: Color(0xFF7A836F),
          );

    Color primary;
    Color hover;
    Color light;
    Color lightBorder;
    Color accent;

    switch (palette) {
      case 'emerald':
        primary = const Color(0xFF5F7664);
        hover = const Color(0xFF526858);
        light = isDark ? const Color(0xFF263328) : const Color(0xFFF1F4ED);
        lightBorder = isDark
            ? const Color(0xFF3B4B3C)
            : const Color(0xFFD4DDCE);
        accent = const Color(0xFF748667);
        break;
      case 'blue':
        primary = const Color(0xFF5D6F86);
        hover = const Color(0xFF516278);
        light = isDark ? const Color(0xFF242B36) : const Color(0xFFF0F2F5);
        lightBorder = isDark
            ? const Color(0xFF3A4350)
            : const Color(0xFFD4DBE4);
        accent = const Color(0xFF74849A);
        break;
      case 'purple':
        primary = const Color(0xFF766A80);
        hover = const Color(0xFF675C70);
        light = isDark ? const Color(0xFF302832) : const Color(0xFFF4F0F4);
        lightBorder = isDark
            ? const Color(0xFF493D4B)
            : const Color(0xFFDED5DF);
        accent = const Color(0xFF897B8B);
        break;
      case 'sepia':
        primary = const Color(0xFF7A6A55);
        hover = const Color(0xFF6B5D4A);
        light = isDark ? const Color(0xFF2C261E) : const Color(0xFFF6F0E6);
        lightBorder = isDark
            ? const Color(0xFF473E32)
            : const Color(0xFFE3D6C3);
        accent = const Color(0xFF9A876C);
        break;
      case 'sage':
      default:
        primary = base.primary;
        hover = base.primaryHover;
        light = base.primaryLight;
        lightBorder = base.primaryLightBorder;
        accent = base.accent;
    }

    return AppThemeColors(
      background: palette == 'sepia' && isDark
          ? const Color(0xFF171613)
          : base.background,
      surface: palette == 'sepia' && isDark
          ? const Color(0xFF201F1B)
          : base.surface,
      surfaceMuted: palette == 'sepia' && isDark
          ? const Color(0xFF1B1A17)
          : base.surfaceMuted,
      borderSoft: palette == 'sepia' && isDark
          ? const Color(0xFF373229)
          : base.borderSoft,
      foreground: base.foreground,
      textStrong: base.textStrong,
      textInverse: base.textInverse,
      primary: primary,
      primaryHover: hover,
      primaryLight: light,
      primaryLightBorder: lightBorder,
      accent: accent,
    );
  }
}
