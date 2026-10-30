import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../data/quran_repository.dart';
import '../providers/mushaf_audio_provider.dart';
import '../providers/settings_provider.dart';
import '../services/remote_content_service.dart';
import '../shared/shared.dart';
import '../theme/app_theme.dart';
import '../widgets/tajweed_color_guide_sheet.dart';
import '../widgets/translation_manager_section.dart';
import 'hifz_settings_screen.dart' show BleDeviceManagementUI;

enum SettingsCategoryTab {
  appearance,
  reading,
  translations,
  hifz,
}

class SettingsScreen extends StatefulWidget {
  final QuranRepository? repository;
  final SettingsCategoryTab initialCategory;

  const SettingsScreen({
    super.key,
    this.repository,
    this.initialCategory = SettingsCategoryTab.appearance,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late SettingsCategoryTab _activeCategory;
  bool _isCheckingContentUpdates = false;

  @override
  void initState() {
    super.initState();
    _activeCategory = widget.initialCategory;
  }

  Future<void> _checkContentUpdates() async {
    setState(() => _isCheckingContentUpdates = true);
    try {
      final result = await RemoteContentService.instance.updateAll();
      if (result.updated > 0) {
        await widget.repository?.reloadRemoteContent();
      }
      if (!mounted) return;
      final isThai =
          Provider.of<SettingsProvider>(context, listen: false).languageCode ==
          'th';
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
      final isThai =
          Provider.of<SettingsProvider>(context, listen: false).languageCode ==
          'th';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isThai
                ? 'ไม่สามารถตรวจสอบการอัปเดตเนื้อหาได้'
                : 'Could not check content updates.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCheckingContentUpdates = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final colors = settings.getAppColors();
    final colorScheme = Theme.of(context).colorScheme;
    final isThai = settings.languageCode == 'th';

    final categories = [
      (
        SettingsCategoryTab.appearance,
        Icons.wb_sunny_outlined,
        isThai ? 'การแสดงผล & ภาษา' : 'Appearance',
      ),
      (
        SettingsCategoryTab.reading,
        Icons.menu_book_rounded,
        isThai ? 'การอ่าน & ตัวอักษร' : 'Quran Reader',
      ),
      (
        SettingsCategoryTab.translations,
        Icons.translate_rounded,
        isThai ? 'บทแปล & ออฟไลน์' : 'Translations',
      ),
      (
        SettingsCategoryTab.hifz,
        Icons.psychology_rounded,
        isThai ? 'ฮิฟซ์ & รีโมท' : 'Hifz & Controls',
      ),
    ];

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          isThai ? 'การตั้งค่าและปรับแต่ง' : 'Settings & Preferences',
          style: GoogleFonts.notoSansThai(
            fontWeight: FontWeight.w800,
            fontSize: 19,
            color: colorScheme.onSurface,
          ),
        ),
      ),
      body: Column(
        children: [
          // Horizontal Category Pills Bar (matches Web's categorized Settings)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            decoration: BoxDecoration(
              color: colors.background,
              border: Border(
                bottom: BorderSide(color: colors.borderSoft),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories.map((cat) {
                  final isSelected = _activeCategory == cat.$1;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => setState(() => _activeCategory = cat.$1),
                      borderRadius: BorderRadius.circular(14),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colorScheme.primary
                              : colors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? colorScheme.primary
                                : colors.borderSoft,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              cat.$2,
                              size: 16,
                              color: isSelected
                                  ? Colors.white
                                  : colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              cat.$3,
                              style: GoogleFonts.notoSansThai(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isSelected
                                    ? Colors.white
                                    : colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Category Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
              children: [
                if (_activeCategory == SettingsCategoryTab.appearance)
                  _buildAppearanceSection(
                    context,
                    settings,
                    colors,
                    colorScheme,
                    isThai,
                  )
                else if (_activeCategory == SettingsCategoryTab.reading)
                  _buildReadingSection(
                    context,
                    settings,
                    colors,
                    colorScheme,
                    isThai,
                  )
                else if (_activeCategory == SettingsCategoryTab.translations)
                  _buildTranslationsSection(
                    context,
                    settings,
                    colors,
                    colorScheme,
                    isThai,
                  )
                else
                  _buildHifzControlsSection(
                    context,
                    settings,
                    colors,
                    colorScheme,
                    isThai,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceSection(
    BuildContext context,
    SettingsProvider settings,
    AppThemeColors colors,
    ColorScheme colorScheme,
    bool isThai,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          colorScheme,
          isThai ? 'ธีมและการแสดงผลหน้าจอ' : 'DISPLAY & THEME',
        ),
        const SizedBox(height: 8),
        _SettingsCard(
          colors: colors,
          child: Column(
            children: [
              // Theme Mode Segmented Row
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        settings.isDarkMode
                            ? Icons.dark_mode_rounded
                            : Icons.light_mode_rounded,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('dark_mode'),
                            style: GoogleFonts.notoSansThai(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            isThai
                                ? 'สลับระหว่างโหมดสว่างและโหมดมืดถนอมสายตา'
                                : 'Switch between warm paper light and dark themes',
                            style: GoogleFonts.notoSansThai(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: settings.isDarkMode,
                      activeThumbColor: colorScheme.primary,
                      onChanged: (val) => settings.toggleDarkMode(val),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: colors.borderSoft),

              // Keep Screen Awake
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.screen_lock_portrait_rounded,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('keep_screen_awake'),
                            style: GoogleFonts.notoSansThai(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            context.tr('keep_screen_awake_desc'),
                            style: GoogleFonts.notoSansThai(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: settings.keepAwake,
                      activeThumbColor: colorScheme.primary,
                      onChanged: settings.toggleKeepAwake,
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: colors.borderSoft),

              // App Language Selector
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.language_rounded,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('language'),
                            style: GoogleFonts.notoSansThai(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            isThai
                                ? 'ภาษาของเมนูและส่วนติดต่อผู้ใช้'
                                : 'Interface and menu language',
                            style: GoogleFonts.notoSansThai(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: colors.surfaceMuted,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.borderSoft),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _SmallSegmentButton(
                            label: 'ไทย',
                            isSelected: settings.languageCode == 'th',
                            colorScheme: colorScheme,
                            onTap: () => settings.setLanguageCode('th'),
                          ),
                          _SmallSegmentButton(
                            label: 'EN',
                            isSelected: settings.languageCode == 'en',
                            colorScheme: colorScheme,
                            onTap: () => settings.setLanguageCode('en'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReadingSection(
    BuildContext context,
    SettingsProvider settings,
    AppThemeColors colors,
    ColorScheme colorScheme,
    bool isThai,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Live Typography Preview Card (matches Web's Live Preview Box)
        _buildSectionHeader(
          colorScheme,
          isThai ? 'ตัวอย่างการแสดงผลตัวอักษร' : 'LIVE TYPOGRAPHY PREVIEW',
        ),
        const SizedBox(height: 8),
        _SettingsCard(
          colors: colors,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'UthmanicHafs',
                    fontSize: settings.arabicFontSize,
                    color: colorScheme.onSurface,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isThai
                      ? 'ด้วยพระนามของอัลลอฮฺ ผู้ทรงกรุณาปรานี ผู้ทรงเมตตาเสมอ'
                      : 'In the name of Allah, the Entirely Merciful, the Especially Merciful.',
                  style: GoogleFonts.notoSansThai(
                    fontSize: settings.translationFontSize,
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        _buildSectionHeader(
          colorScheme,
          context.tr('reading_experience'),
        ),
        const SizedBox(height: 8),
        _SettingsCard(
          colors: colors,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.tr('arabic_font_size'),
                      style: GoogleFonts.notoSansThai(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${settings.arabicFontSize.toInt()} px',
                      style: GoogleFonts.notoSansThai(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.primary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: settings.arabicFontSize.clamp(18.0, 48.0),
                  min: 18.0,
                  max: 48.0,
                  activeColor: colorScheme.primary,
                  onChanged: (val) => settings.setArabicFontSize(val),
                ),
                Divider(height: 16, color: colors.borderSoft),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.tr('translation_font_size'),
                      style: GoogleFonts.notoSansThai(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${settings.translationFontSize.toInt()} px',
                      style: GoogleFonts.notoSansThai(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.primary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: settings.translationFontSize.clamp(12.0, 32.0),
                  min: 12.0,
                  max: 32.0,
                  activeColor: colorScheme.primary,
                  onChanged: (val) => settings.setTranslationFontSize(val),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Word by Word, Footnotes, Tajweed Guide
        _SettingsCard(
          colors: colors,
          child: Column(
            children: [
              SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.spellcheck_rounded,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                ),
                title: Text(
                  isThai
                      ? 'แสดงคำแปลคำต่อคำ (Word-by-Word)'
                      : 'Word-by-Word Breakdown',
                  style: GoogleFonts.notoSansThai(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  isThai
                      ? 'แสดงความหมายแยกทีละคำศัพท์ใต้ภาษาอาหรับ'
                      : 'Show word-by-word meanings under Arabic words',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                value: settings.showWordByWord,
                activeThumbColor: colorScheme.primary,
                onChanged: (val) => settings.toggleShowWordByWord(val),
              ),
              Divider(height: 1, color: colors.borderSoft),
              SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                ),
                title: Text(
                  isThai
                      ? 'แสดงเชิงอรรถ (Footnotes)'
                      : 'Footnotes & Commentary',
                  style: GoogleFonts.notoSansThai(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  isThai
                      ? 'แสดงตัวเลขเชิงอรรถ [1] และคำอธิบายใต้บทแปล'
                      : 'Show footnote markers [1] and commentary under verses',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                value: settings.showFootnotes,
                activeThumbColor: colorScheme.primary,
                onChanged: (val) => settings.setShowFootnotes(val),
              ),
              Divider(height: 1, color: colors.borderSoft),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.palette_outlined,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                ),
                title: Text(
                  context.tr('tajweed_guide_title'),
                  style: GoogleFonts.notoSansThai(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  context.tr('tajweed_guide_desc'),
                  style: GoogleFonts.notoSansThai(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: colors.surface,
                    showDragHandle: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    builder: (ctx) => TajweedColorGuideSheet(colors: colors),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTranslationsSection(
    BuildContext context,
    SettingsProvider settings,
    AppThemeColors colors,
    ColorScheme colorScheme,
    bool isThai,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TranslationManagerSection(colors: colors),
        const SizedBox(height: 20),
        _buildSectionHeader(colorScheme, context.tr('content_updates')),
        const SizedBox(height: 8),
        _SettingsCard(
          colors: colors,
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
                const SizedBox(height: 6),
                Text(
                  context.tr('content_updates_desc'),
                  style: GoogleFonts.notoSansThai(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
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
                        : const Icon(Icons.system_update_alt_rounded, size: 18),
                    label: Text(
                      _isCheckingContentUpdates
                          ? context.tr('checking_updates')
                          : context.tr('check_now'),
                      style: GoogleFonts.notoSansThai(
                        fontWeight: FontWeight.w800,
                      ),
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

  Widget _buildHifzControlsSection(
    BuildContext context,
    SettingsProvider settings,
    AppThemeColors colors,
    ColorScheme colorScheme,
    bool isThai,
  ) {
    final isBleSelected = settings.hifzInputMode == HifzInputMode.bleSmartRing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Input & Remote Mode
        _buildSectionHeader(
          colorScheme,
          isThai ? 'อุปกรณ์ควบคุมการเลื่อนอายะฮฺ' : 'HIFZ INPUT & REMOTE MODE',
        ),
        const SizedBox(height: 8),
        _HifzInputModeOptionTile(
          title: isThai ? 'ปุ่มนับบนหน้าจอ (In-App Tally)' : 'In-App Tally Button',
          subtitle: isThai
              ? 'แตะปุ่มนับด้านล่างหน้าจอเพื่อบันทึกและเลื่อนอายะฮฺ ไม่ต้องใช้อุปกรณ์เสริม'
              : 'Tap the on-screen tally button to count repetitions and advance.',
          icon: Icons.touch_app_rounded,
          isSelected: settings.hifzInputMode == HifzInputMode.inAppTally,
          colors: colors,
          colorScheme: colorScheme,
          onTap: () => settings.setHifzInputMode(HifzInputMode.inAppTally),
        ),
        const SizedBox(height: 10),
        _HifzInputModeOptionTile(
          title: isThai ? 'รีโมทบลูทูธ / ปุ่มชัตเตอร์' : 'Bluetooth Remote / Shutter',
          subtitle: isThai
              ? 'ใช้ปุ่มชัตเตอร์หรือปุ่มปรับเสียงเลื่อนอายะฮฺ สะดวกเมื่อวางมือถือบนแท่น'
              : 'Use a Bluetooth shutter or volume keys to advance through verses.',
          icon: Icons.bluetooth_searching_rounded,
          isSelected: settings.hifzInputMode == HifzInputMode.bluetoothShutter,
          colors: colors,
          colorScheme: colorScheme,
          onTap: () =>
              settings.setHifzInputMode(HifzInputMode.bluetoothShutter),
        ),
        const SizedBox(height: 10),
        _HifzInputModeOptionTile(
          title: isThai
              ? 'แหวนอัจฉริยะ (BLE Smart Ring)'
              : 'BLE Smart Tasbih Ring',
          subtitle: isThai
              ? 'เชื่อมต่อแหวน Smart Tasbih, Zikir Ring, iQibla เพื่อกดนับแบบไร้สาย'
              : 'Connect a BLE smart ring (Smart Tasbih, Zikir Ring, iQibla) for hands-free counting.',
          icon: Icons.watch_rounded,
          isSelected: isBleSelected,
          colors: colors,
          colorScheme: colorScheme,
          onTap: () => settings.setHifzInputMode(HifzInputMode.bleSmartRing),
        ),
        if (isBleSelected) ...[
          const SizedBox(height: 12),
          const BleDeviceManagementUI(),
        ],
        const SizedBox(height: 24),

        // 2. AI Voice Recitation Tracking
        _buildSectionHeader(
          colorScheme,
          isThai
              ? 'ระบบตรวจจับเสียงอ่าน (AI Recitation)'
              : 'AI VOICE RECITATION TRACKING',
        ),
        const SizedBox(height: 8),
        _SettingsCard(
          colors: colors,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.record_voice_over_rounded,
                        color: colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  isThai
                                      ? 'ตรวจจับเสียงอ่านอัตโนมัติ'
                                      : 'Voice Recitation Tracking',
                                  style: GoogleFonts.notoSansThai(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Offline AI',
                                  style: GoogleFonts.notoSansThai(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isThai
                                ? 'เปิดเผยอายะฮฺอัตโนมัติเมื่ออ่านถูกตามลำดับ และแจ้งเตือนเมื่ออ่านข้ามอายะฮฺ'
                                : 'Automatically reveals hidden verses as you recite and alerts if a verse is skipped.',
                            style: GoogleFonts.notoSansThai(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: settings.voiceRecitationEnabled,
                      activeThumbColor: colorScheme.primary,
                      onChanged: (val) =>
                          settings.setVoiceRecitationEnabled(val),
                    ),
                  ],
                ),
                if (settings.voiceRecitationEnabled) ...[
                  const SizedBox(height: 12),
                  Divider(height: 1, color: colors.borderSoft),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.graphic_eq_rounded,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isThai
                                  ? 'กรองเสียงรบกวนอัตโนมัติ (Adaptive Noise)'
                                  : 'Adaptive Noise Filter',
                              style: GoogleFonts.notoSansThai(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              isThai
                                  ? 'ช่วยตัดเสียงพัดลมหรือแอร์ขณะท่องจำ'
                                  : 'Filters out ambient fan or AC background noise',
                              style: GoogleFonts.notoSansThai(
                                fontSize: 11,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: settings.voiceRecitationAdaptiveNoise,
                        activeThumbColor: colorScheme.primary,
                        onChanged: (val) =>
                            settings.setVoiceRecitationAdaptiveNoise(val),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // 3. In-App Reciter Volume
        _buildSectionHeader(
          colorScheme,
          isThai ? 'ระดับเสียงผู้อ่านอัลกุรอาน' : 'RECITER AUDIO VOLUME',
        ),
        const SizedBox(height: 8),
        Consumer<MushafAudioProvider>(
          builder: (context, audioProvider, _) {
            final volume = audioProvider.volume;
            final pct = (volume * 100).round();
            return _SettingsCard(
              colors: colors,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            isThai
                                ? 'ความดังเสียงอ่านในแอป'
                                : 'In-App Playback Volume',
                            style: GoogleFonts.notoSansThai(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Text(
                          '$pct%',
                          style: GoogleFonts.notoSansThai(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.volume_mute_rounded,
                          size: 18,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        Expanded(
                          child: Slider(
                            value: volume,
                            min: 0.0,
                            max: 1.0,
                            activeColor: colorScheme.primary,
                            onChanged: (val) => audioProvider.setVolume(val),
                          ),
                        ),
                        Icon(
                          Icons.volume_up_rounded,
                          size: 18,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSectionHeader(ColorScheme colorScheme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.notoSansThai(
          color: colorScheme.primary,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final AppThemeColors colors;
  final Widget child;
  const _SettingsCard({required this.colors, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.borderSoft),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: child,
      ),
    );
  }
}

class _SmallSegmentButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _SmallSegmentButton({
    required this.label,
    required this.isSelected,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: GoogleFonts.notoSansThai(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isSelected ? Colors.white : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _HifzInputModeOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final AppThemeColors colors;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _HifzInputModeOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.colors,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.08)
              : colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? colorScheme.primary : colors.borderSoft,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.primary.withValues(alpha: 0.15)
                    : colors.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.notoSansThai(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.notoSansThai(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
