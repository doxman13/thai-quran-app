import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Anti-AI Editorial Manuscript design system tokens aligned 1:1 with thai-quran-web (iQra Foundation).
class AppThemeColors {
  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color borderSoft;
  final Color foreground;
  final Color textStrong;
  final Color textMuted;
  final Color textInverse;
  final Color primary;
  final Color primaryHover;
  final Color primaryLight;
  final Color primaryLightBorder;
  final Color accent;
  final Color mushafGold;
  final Color mushafGoldHover;
  final Color mushafGoldSoft;
  final Color mushafGoldBorder;
  final Color success;
  final Color warning;
  final Color danger;
  final Color dangerSoft;

  const AppThemeColors({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.borderSoft,
    required this.foreground,
    required this.textStrong,
    required this.textMuted,
    required this.textInverse,
    required this.primary,
    required this.primaryHover,
    required this.primaryLight,
    required this.primaryLightBorder,
    required this.accent,
    required this.mushafGold,
    required this.mushafGoldHover,
    required this.mushafGoldSoft,
    required this.mushafGoldBorder,
    required this.success,
    required this.warning,
    required this.danger,
    required this.dangerSoft,
  });

  /// Official iQra Editorial Manuscript palette (warm parchment, deep jade emerald, and manuscript gold).
  factory AppThemeColors.teal({required bool isDark}) {
    if (isDark) {
      return const AppThemeColors(
        background: Color(0xFF131210),
        surface: Color(0xFF1C1B18),
        surfaceMuted: Color(0xFF24231F),
        borderSoft: Color(0xFF2E2C27),
        foreground: Color(0xFFD8D4CD),
        textStrong: Color(0xFFFAF6EE),
        textMuted: Color(0xFF96928A),
        textInverse: Color(0xFF131210),
        primary: Color(0xFF4A9E89),
        primaryHover: Color(0xFF3B8270),
        primaryLight: Color(0xFF162420),
        primaryLightBorder: Color(0xFF233A33),
        accent: Color(0xFFCCA252),
        mushafGold: Color(0xFFCCA252),
        mushafGoldHover: Color(0xFFB88B39),
        mushafGoldSoft: Color(0xFF292013),
        mushafGoldBorder: Color(0xFF553D1E),
        success: Color(0xFF4A9E89),
        warning: Color(0xFFCCA252),
        danger: Color(0xFFD97777),
        dangerSoft: Color(0xFF321715),
      );
    }
    return const AppThemeColors(
      background: Color(0xFFFBF9F5),
      surface: Color(0xFFFFFFFF),
      surfaceMuted: Color(0xFFF7F5EE),
      borderSoft: Color(0xFFE8E3D7),
      foreground: Color(0xFF42524A),
      textStrong: Color(0xFF1C2520),
      textMuted: Color(0xFF708078),
      textInverse: Color(0xFFFFFFFF),
      primary: Color(0xFF0E5A4A),
      primaryHover: Color(0xFF0A4437),
      primaryLight: Color(0xFFEAF2EE),
      primaryLightBorder: Color(0xFFB7D4C7),
      accent: Color(0xFF8A6530),
      mushafGold: Color(0xFF8A6530),
      mushafGoldHover: Color(0xFF735424),
      mushafGoldSoft: Color(0xFFF6EFE3),
      mushafGoldBorder: Color(0xFFD7C299),
      success: Color(0xFF296455),
      warning: Color(0xFF8A6530),
      danger: Color(0xFFA34C43),
      dangerSoft: Color(0xFFFAF0EE),
    );
  }
}

/// Canonical 6-hue muted Tajweed palette matching `src/lib/tajweedService.ts` in thai-quran-web.
class TajweedPalette {
  static Color? getColor(String className, {required bool isDark}) {
    final sanitized = className
        .replaceAll("'", '')
        .replaceAll('"', '')
        .trim()
        .toLowerCase();
    switch (sanitized) {
      case 'ghunnah':
        return isDark ? const Color(0xFFD9AB63) : const Color(0xFF8A6530);
      case 'idgham':
      case 'idgham_ghunnah':
      case 'idgham_shafawi':
      case 'idgham_muthamaasilayn':
        return isDark ? const Color(0xFF6FB3A8) : const Color(0xFF2E6E6A);
      case 'ikhfa':
      case 'ikhafa':
      case 'ikhfa_shafawi':
      case 'ikhafa_shafawi':
        return isDark ? const Color(0xFF8FBF7F) : const Color(0xFF3F6B3A);
      case 'iqlab':
        return isDark ? const Color(0xFFC08FB4) : const Color(0xFF7A4A6B);
      case 'qalqalah':
      case 'qalaqah':
        return isDark ? const Color(0xFF9AA6C8) : const Color(0xFF4A5578);
      case 'madda_normal':
      case 'madda_permissible':
      case 'madda_obligatory':
      case 'madda_obligatory_monfasel':
      case 'madda_obligatory_mottasel':
      case 'madd':
        return isDark ? const Color(0xFFE08A8A) : const Color(0xFF9B3D3D);
      case 'madda_necessary':
        return isDark ? const Color(0xFFF0B4B4) : const Color(0xFF6E2A2A);
      case 'ham_wasl':
      case 'laam_shamsiyah':
      case 'silent':
      case 'slnt':
      case 'idgham_wo_ghunnah':
      case 'idgham_mutajanisayn':
      case 'idgham_mutaqaribayn':
        return isDark ? const Color(0xFFA8A49A) : const Color(0xFF8A857B);
      default:
        return null;
    }
  }
}

class AppTheme {
  /// Standard geometry radius for crisp editorial containers (`rounded-xl` = 12.0px)
  static const radius = 12.0;

  /// Compact badge / chip radius (`rounded-lg` = 8.0px)
  static const radiusSm = 8.0;

  /// Mushaf book spread outer frame radius (`rounded-2xl` = 16.0px)
  static const radiusLg = 16.0;

  static Future<void> prewarmFonts() async {
    try {
      final fontLoader = FontLoader('UthmanicHafs');
      fontLoader.addFont(rootBundle.load('assets/fonts/UthmanicHafs.ttf'));
      await fontLoader.load();
    } catch (e) {
      debugPrint('Error pre-warming UthmanicHafs font: $e');
    }
  }

  /// Returns the theme color tokens.
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
      primaryColor: c.primary,
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
        secondary: c.mushafGold,
        onSecondary: c.textInverse,
        secondaryContainer: c.mushafGoldSoft,
        onSecondaryContainer: c.mushafGold,
        tertiary: c.mushafGold,
        onTertiary: c.textInverse,
        surface: c.surface,
        onSurface: c.textStrong,
        surfaceContainerLow: c.surfaceMuted,
        onSurfaceVariant: c.foreground,
        outline: c.borderSoft,
        outlineVariant: c.borderSoft,
        error: c.danger,
        onError: Colors.white,
      ),

      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: c.borderSoft, width: 1),
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
                fontSize: 20,
                fontWeight: FontWeight.w700,
              )
            : GoogleFonts.notoSans(
                color: c.textStrong,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: c.borderSoft, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: c.borderSoft, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.primary,
        disabledColor: c.surfaceMuted,
        side: BorderSide(color: c.borderSoft, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        labelStyle: TextStyle(color: c.textStrong, fontWeight: FontWeight.w600),
        secondaryLabelStyle: TextStyle(color: c.textInverse, fontWeight: FontWeight.w600),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        elevation: 0,
        indicatorColor: c.primaryLight,
        surfaceTintColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: c.primary, size: 24);
          }
          return IconThemeData(color: c.textMuted, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          final color = isSelected ? c.primary : c.textMuted;
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
        color: c.borderSoft,
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
