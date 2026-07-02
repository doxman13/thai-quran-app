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
  // 1. Upgrade radius from 8.0 to 16.0 for a softer, premium, modern feel
  static const radius = 16.0; 

  static Future<void> prewarmFonts() async {
    try {
      final fontLoader = FontLoader('UthmanicHafs');
      fontLoader.addFont(rootBundle.load('assets/fonts/UthmanicHafs.ttf'));
      await fontLoader.load();
    } catch (e) {
      debugPrint('Error pre-warming UthmanicHafs font: $e');
    }
  }

  static AppThemeColors colors({required bool isDark, required String palette}) {
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

  // 2. NEW: Native ThemeData bridge generator so your AI and Flutter Widgets recognize your styles instantly
  static ThemeData toThemeData({required bool isDark, String palette = 'default'}) {
    final c = colors(isDark: isDark, palette: palette);
    
    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: c.background,
      
      // Map your clean color variables directly into Flutter's native system
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: c.primary,
        onPrimary: c.textInverse,
        secondary: c.accent,
        onSecondary: c.textStrong,
        surface: c.surface,
        onSurface: c.textStrong,
        surfaceContainerLow: c.surfaceMuted, // Perfect for list backdrops
        outline: c.borderSoft,
        error: Colors.redAccent,
        onError: Colors.white,
      ),

      // Set clean, standard component defaults based on your radius
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: c.borderSoft, width: 1),
        ),
      ),
      
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: c.textStrong),
        titleTextStyle: TextStyle(color: c.textStrong, fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// Add this at the absolute bottom of app_theme.dart
extension BuildContextThemeExt on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  
  // This lets you call your custom palette from anywhere instantly!
  AppThemeColors get appColors => AppTheme.colors(
        isDark: Theme.of(this).brightness == Brightness.dark,
        palette: 'default',
      );
}