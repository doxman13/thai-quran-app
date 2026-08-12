import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/quran_repository.dart';
import '../providers/settings_provider.dart';
import '../services/remote_content_service.dart';
import '../widgets/translation_manager_section.dart';
import '../shared/shared.dart';

class SettingsScreen extends StatefulWidget {
  final QuranRepository? repository;

  const SettingsScreen({super.key, this.repository});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isCheckingContentUpdates = false;

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final colors = settings.getAppColors();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr('settings'),
          style: GoogleFonts.notoSansThai(
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurface,
          ),
        ),
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
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
                  activeThumbColor: colorScheme.primary,
                ),
                Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                  thickness: 1,
                ),
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
                  activeThumbColor: colorScheme.primary,
                ),
                Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                  thickness: 1,
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: DropdownButtonFormField<String>(
                    initialValue: settings.languageCode,
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
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'th',
                        child: Text('ภาษาไทย (Thai)'),
                      ),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                    ],
                    selectedItemBuilder: (context) {
                      return [
                        Text(
                          'ภาษาไทย',
                          style: GoogleFonts.notoSansThai(
                            color: colorScheme.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'English',
                          style: GoogleFonts.notoSansThai(
                            color: colorScheme.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ];
                    },
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
                      overlayColor: colorScheme.primary.withValues(alpha: 0.1),
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
                      overlayColor: colorScheme.primary.withValues(alpha: 0.1),
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
          TranslationManagerSection(colors: colors),
          const SizedBox(height: 24),
          _buildContentUpdateSection(colorScheme),
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

  Future<void> _checkContentUpdates() async {
    setState(() => _isCheckingContentUpdates = true);
    try {
      final result = await RemoteContentService.instance.updateAll();
      if (result.updated > 0) {
        await widget.repository?.reloadRemoteContent();
      }
      final isThai = Provider.of<SettingsProvider>(context, listen: false).languageCode == 'th';
      final message = result.hasFailures
          ? (isThai 
              ? 'อัปเดตแล้ว ${result.updated}/${result.checked} รายการ ล้มเหลว: ${result.failedKeys.join(', ')}'
              : 'Updated ${result.updated}/${result.checked}. Failed: ${result.failedKeys.join(', ')}')
          : result.updated > 0
          ? (isThai
              ? 'อัปเดตข้อมูลแล้ว ${result.updated} แพ็ก'
              : 'Updated ${result.updated} content pack(s).')
          : (isThai
              ? 'เนื้อหาทั้งหมดเป็นเวอร์ชันล่าสุดแล้ว'
              : 'All content is already up to date.');

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) return;
      final isThai = Provider.of<SettingsProvider>(context, listen: false).languageCode == 'th';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isThai ? 'ไม่สามารถตรวจสอบการอัปเดตเนื้อหาได้' : 'Could not check content updates.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCheckingContentUpdates = false);
      }
    }
  }

  Widget _buildContentUpdateSection(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(colorScheme, context.tr('content_updates')),
        const SizedBox(height: 8),
        _SettingsCard(
          colorScheme: colorScheme,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('remote_quran_content'),
                  style: GoogleFonts.notoSansThai(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('content_updates_desc'),
                  style: GoogleFonts.notoSansThai(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isCheckingContentUpdates
                        ? null
                        : _checkContentUpdates,
                    icon: _isCheckingContentUpdates
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.system_update_alt_rounded),
                    label: Text(
                      _isCheckingContentUpdates
                          ? context.tr('checking_updates')
                          : context.tr('check_now'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A minimal flat M3-styled settings group container.
class _SettingsCard extends StatelessWidget {
  final ColorScheme colorScheme;
  final Widget child;
  const _SettingsCard({required this.colorScheme, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: child,
      ),
    );
  }
}
