import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/translation_manager_section.dart';
import '../shared/shared.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final colors = settings.getAppColors();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          context.tr('settings'),
          style: GoogleFonts.notoSansThai(
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurface,
          ),
        ),
        backgroundColor: colorScheme.surfaceContainerLow,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        shape: Border(bottom: BorderSide(color: colorScheme.outline, width: 1)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          _buildSectionHeader(colorScheme, context.tr('display')),
          const SizedBox(height: 8),
          _SettingsCard(
            colorScheme: colorScheme,
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  title: Text(
                    context.tr('dark_mode'),
                    style: GoogleFonts.notoSansThai(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  value: settings.isDarkMode,
                  onChanged: (val) => settings.toggleDarkMode(val),
                  activeColor: colorScheme.primary,
                ),
                Divider(height: 1, color: colorScheme.outline, thickness: 1),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  title: Text(
                    context.tr('keep_screen_awake'),
                    style: GoogleFonts.notoSansThai(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    context.tr('keep_screen_awake_desc'),
                    style: GoogleFonts.notoSansThai(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  value: settings.keepAwake,
                  onChanged: settings.toggleKeepAwake,
                  activeColor: colorScheme.primary,
                ),
                Divider(height: 1, color: colorScheme.outline, thickness: 1),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: DropdownButtonFormField<String>(
                    value: settings.languageCode,
                    dropdownColor: colorScheme.surfaceContainerLow,
                    decoration: InputDecoration(
                      labelText: context.tr('language'),
                      labelStyle: GoogleFonts.notoSansThai(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: colorScheme.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                        borderSide: BorderSide(
                          color: colorScheme.outline,
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                        borderSide: BorderSide(
                          color: colorScheme.outline,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                        borderSide: BorderSide(
                          color: colorScheme.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'th',
                        child: Text('ภาษาไทย (Thai)'),
                      ),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                    ],
                    onChanged: (val) {
                      if (val != null) settings.setLanguageCode(val);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(colorScheme, context.tr('reading_experience')),
          const SizedBox(height: 8),
          _SettingsCard(
            colorScheme: colorScheme,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('reading_mode'),
                    style: GoogleFonts.notoSansThai(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: settings.readingDisplayMode,
                    dropdownColor: colorScheme.surfaceContainerLow,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: colorScheme.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                        borderSide: BorderSide(
                          color: colorScheme.outline,
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                        borderSide: BorderSide(
                          color: colorScheme.outline,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                        borderSide: BorderSide(
                          color: colorScheme.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: SettingsProvider.quranOnlyMode,
                        child: Text(
                          context.tr('quran_only'),
                          style: GoogleFonts.notoSansThai(
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: SettingsProvider.translationOnlyMode,
                        child: Text(
                          context.tr('translation_only'),
                          style: GoogleFonts.notoSansThai(
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: SettingsProvider.quranTranslationMode,
                        child: Text(
                          context.tr('quran_translation'),
                          style: GoogleFonts.notoSansThai(
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) settings.setReadingDisplayMode(val);
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.tr('arabic_font_size'),
                        style: GoogleFonts.notoSansThai(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '${settings.arabicFontSize.toInt()} px',
                        style: GoogleFonts.notoSansThai(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: colorScheme.primary,
                      inactiveTrackColor: colorScheme.outline,
                      thumbColor: colorScheme.primary,
                      overlayColor: colorScheme.primary.withOpacity(0.1),
                    ),
                    child: Slider(
                      value: settings.arabicFontSize,
                      min: 18.0,
                      max: 48.0,
                      onChanged: (val) => settings.setArabicFontSize(val),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.tr('translation_font_size'),
                        style: GoogleFonts.notoSansThai(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '${settings.translationFontSize.toInt()} px',
                        style: GoogleFonts.notoSansThai(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: colorScheme.primary,
                      inactiveTrackColor: colorScheme.outline,
                      thumbColor: colorScheme.primary,
                      overlayColor: colorScheme.primary.withOpacity(0.1),
                    ),
                    child: Slider(
                      value: settings.translationFontSize,
                      min: 12.0,
                      max: 32.0,
                      onChanged: (val) => settings.setTranslationFontSize(val),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          TranslationManagerSection(colors: colors),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ColorScheme colorScheme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.notoSansThai(
          color: colorScheme.primary,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// A flat M3-styled settings group container.
class _SettingsCard extends StatelessWidget {
  final ColorScheme colorScheme;
  final Widget child;
  const _SettingsCard({required this.colorScheme, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: colorScheme.outline, width: 1),
      ),
      child: child,
    );
  }
}
