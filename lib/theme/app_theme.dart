import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Clean, modern Material 3 design system tokens matching thai-quran-web (iQra Foundation).
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
  final Color success;
  final Color warning;
  final Color danger;

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
    required this.success,
    required this.warning,
    required this.danger,
  });

  /// Official Teal palette (iQra foundation: warm paper, deep teal, and quiet gold).
  factory AppThemeColors.teal({required bool isDark}) {
    if (isDark) {
      return const AppThemeColors(
        background: Color(0xFF0D0D0D),
        surface: Color(0xFF161616),
        surfaceMuted: Color(0xFF1C1C1C),
        borderSoft: Color(0xFF2C2C2C),
        foreground: Color(0xFFD1D5DB),
        textStrong: Color(0xFFFFFFFF),
        textInverse: Color(0xFF0D0D0D),
        primary: Color(0xFF529665),
        primaryHover: Color(0xFF407D51),
        primaryLight: Color(0xFF122016),
        primaryLightBorder: Color(0xFF1E3625),
        accent: Color(0xFF78BD8C),
        success: Color(0xFF78BD8C),
        warning: Color(0xFFE2A65C),
        danger: Color(0xFFE68585),
      );
    }
    return const AppThemeColors(
      background: Color(0xFFF5F4EE),
      surface: Color(0xFFFFFDF9),
      surfaceMuted: Color(0xFFEEEEE7),
      borderSoft: Color(0xFFD9DDD4),
      foreground: Color(0xFF3F4F4A),
      textStrong: Color(0xFF123B3C),
      textInverse: Color(0xFFFFFDF9),
      primary: Color(0xFF0E5B59),
      primaryHover: Color(0xFF084645),
      primaryLight: Color(0xFFE3EFEB),
      primaryLightBorder: Color(0xFFC3D9D1),
      accent: Color(0xFFC59A52),
      success: Color(0xFF2F8877),
      warning: Color(0xFFB77C32),
      danger: Color(0xFFB55454),
    );
  }
}

class AppTheme {
  /// Standard geometry radius for soft modern M3 containers (20.0px)
  static const radius = 20.0;

  static Future<void> prewarmFonts() async {
    try {
      final fontLoader = FontLoader('UthmanicHafs');
      fontLoader.addFont(rootBundle.load('assets/fonts/UthmanicHafs.ttf'));
      await fontLoader.load();
    } catch (e) {
      debugPrint('Error pre-warming UthmanicHafs font: $e');
    }
  }

  /// Returns the theme color tokens. Forced to Teal (the web app active theme).
  static AppThemeColors colors({
    required bool isDark,
    String palette = 'teal',
  }) {
    return AppThemeColors.teal(isDark: isDark);
  }

  /// Builds Material 3 ThemeData bridge using web theme tokens and language-appropriate typography.
  static ThemeData toThemeData({
    required bool isDark,
    String palette = 'teal',
    String languageCode = 'th',
  }) {
    final c = colors(isDark: isDark, palette: palette);
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
    );
    final isThai = languageCode == 'th';
    final textTheme = (isThai
            ? GoogleFonts.notoSansThaiTextTheme(baseTheme.textTheme)
            : GoogleFonts.notoSansTextTheme(baseTheme.textTheme))
        .apply(bodyColor: c.textStrong, displayColor: c.textStrong);

    final defaultFontFamily = isThai
        ? GoogleFonts.notoSansThai().fontFamily
        : GoogleFonts.notoSans().fontFamily;

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: c.background,
      fontFamily: defaultFontFamily,
      textTheme: textTheme,
      primaryTextTheme: textTheme,

      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: c.primary,
        onPrimary: c.textInverse,
        primaryContainer: c.primaryLight,
        onPrimaryContainer: c.primary,
        secondary: c.accent,
        onSecondary: c.textStrong,
        surface: c.surface,
        onSurface: c.textStrong,
        surfaceContainerLow: c.surfaceMuted,
        onSurfaceVariant: c.foreground,
        outline: c.borderSoft,
        error: c.danger,
        onError: Colors.white,
      ),

      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide.none,
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: c.textStrong),
        titleTextStyle: isThai
            ? GoogleFonts.notoSansThai(
                color: c.textStrong,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              )
            : GoogleFonts.notoSans(
                color: c.textStrong,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide.none,
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.primary,
        disabledColor: c.surfaceMuted,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        labelStyle: TextStyle(color: c.textStrong, fontWeight: FontWeight.w500),
        secondaryLabelStyle: TextStyle(color: c.textInverse, fontWeight: FontWeight.w600),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.background,
        elevation: 0,
        indicatorColor: c.primaryLight,
        surfaceTintColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: c.primary, size: 24);
          }
          return IconThemeData(color: c.foreground, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          final color = isSelected ? c.primary : c.foreground;
          final weight = isSelected ? FontWeight.w700 : FontWeight.w500;
          return isThai
              ? GoogleFonts.notoSansThai(
                  color: color,
                  fontWeight: weight,
                  fontSize: 12,
                )
              : GoogleFonts.notoSans(
                  color: color,
                  fontWeight: weight,
                  fontSize: 12,
                );
        }),
      ),

      dividerTheme: DividerThemeData(
        color: isDark ? const Color(0xFF262626) : const Color(0x0F000000),
        space: 1,
        thickness: 1,
      ),
    );
  }
}

extension BuildContextThemeExt on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  AppThemeColors get appColors => AppTheme.colors(
    isDark: Theme.of(this).brightness == Brightness.dark,
    palette: 'teal',
  );
}
