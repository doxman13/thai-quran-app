import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/quran_repository.dart';
import '../providers/mushaf_audio_provider.dart';
import '../providers/settings_provider.dart';
import '../services/remote_content_service.dart';
import '../shared/shared.dart';
import '../theme/app_theme.dart';
import '../widgets/tajweed_color_guide_sheet.dart';
import '../widgets/translation_manager_section.dart';
import 'hifz_settings_screen.dart' show BleDeviceManagementUI;
import 'profile_screen.dart';

enum SettingsCategoryTab {
  profile,
  reading,
  translations,
  appearance,
  hifz,
}

class SettingsScreen extends StatefulWidget {
  final QuranRepository? repository;
  final SettingsCategoryTab initialCategory;

  const SettingsScreen({
    super.key,
    this.repository,
    this.initialCategory = SettingsCategoryTab.profile,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late SettingsCategoryTab _activeCategory;
  bool _isCheckingContentUpdates = false;

  static const String _previewArabic = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';
  static const Map<String, String> _previewTranslations = {
    'thai_v3': 'ด้วยพระนามของอัลลอฮฺ ผู้ทรงกรุณาปรานี ผู้ทรงเมตตาเสมอ',
    'thai_v2': 'ด้วยพระนามของอัลลอฮฺ ผู้ทรงกรุณาปราณี ผู้ทรงเมตตาเสมอ',
    'english':
        'In the name of Allah, the Entirely Merciful, the Especially Merciful.',
    'en_saheeh':
        'In the name of Allah, the Entirely Merciful, the Especially Merciful.',
    'en_hilali_khan':
        'In the Name of Allah, the Most Beneficent, the Most Merciful.',
    'en_bridges':
        'In the name of Allah, the All-Merciful, the Bestower of mercy',
    'en_abdelhaleem':
        'In the name of God, the Lord of Mercy, the Giver of Mercy!',
    'en_usmani': 'With the name of Allah, the All-Merciful, the Very-Merciful.',
    'ms_basmeih':
        'Dengan nama Allah, Yang Maha Pemurah, lagi Maha Mengasihani.',
  };

  static const Map<String, List<(String, String)>> _previewWbw = {
    'th': [
      ('بِسْمِ', 'ด้วยพระนาม'),
      ('ٱللَّهِ', 'ของอัลลอฮฺ'),
      ('ٱلرَّحْمَٰنِ', 'ผู้ทรงกรุณาปรานี'),
      ('ٱلرَّحِيمِ', 'ผู้ทรงเมตตาเสมอ'),
    ],
    'en': [
      ('بِسْمِ', 'In (the) name'),
      ('ٱللَّهِ', '(of) Allah'),
      ('ٱلرَّحْمَٰنِ', 'the Entirely Merciful'),
      ('ٱلرَّحِيمِ', 'the Especially Merciful'),
    ],
    'ms': [
      ('بِسْمِ', 'Dengan nama'),
      ('ٱللَّهِ', 'Allah'),
      ('ٱلرَّحْمَٰنِ', 'Yang Maha Pemurah'),
      ('ٱلرَّحِيمِ', 'lagi Maha Mengasihani'),
    ],
  };

  @override
  void initState() {
    super.initState();
    _activeCategory = widget.initialCategory;
  }

  Future<void> _confirmAndResetDefaults(
    BuildContext context,
    SettingsProvider settings,
    AppThemeColors colors,
    bool isThai,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          side: BorderSide(color: colors.borderSoft),
        ),
        title: Text(
          isThai
              ? 'คืนค่าเริ่มต้นทั้งหมด?'
              : 'Reset All Settings to Defaults?',
          style: GoogleFonts.notoSansThai(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: colors.textStrong,
          ),
        ),
        content: Text(
          isThai
              ? 'การตั้งค่าขนาดตัวอักษร โหมดการแสดงผล แปลคำต่อคำ และชุดคำแปลหลักจะถูกคืนเป็นค่ามาตรฐานดั้งเดิม (ไม่กระทบข้อมูลบุ๊กมาร์กหรือเป้าหมายการอ่าน)'
              : 'Typography sizes, display mode, word-by-word settings, and active translation slots will be restored to default values. Your bookmarks and reading goals will not be affected.',
          style: GoogleFonts.notoSansThai(
            fontSize: 13,
            color: colors.foreground,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              isThai ? 'ยกเลิก' : 'Cancel',
              style: GoogleFonts.notoSansThai(
                fontWeight: FontWeight.w600,
                color: colors.textMuted,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              isThai ? 'ยืนยันคืนค่าเริ่มต้น' : 'Reset Defaults',
              style: GoogleFonts.notoSansThai(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await settings.resetToDefaults();
      if (!mounted) return;
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(
          content: Text(
            isThai
                ? 'คืนค่าการตั้งค่าเริ่มต้นทั้งหมดเรียบร้อยแล้ว'
                : 'All settings have been restored to defaults.',
            style: GoogleFonts.notoSansThai(fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
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
        SettingsCategoryTab.profile,
        Icons.account_circle_outlined,
        isThai ? 'บัญชี & ซิงก์' : 'Account & Sync',
      ),
      (
        SettingsCategoryTab.reading,
        Icons.menu_book_rounded,
        isThai ? 'การอ่าน & ตัวอักษร' : 'Reading & Font',
      ),
      (
        SettingsCategoryTab.translations,
        Icons.translate_rounded,
        isThai ? 'บทแปล & ออฟไลน์' : 'Translations',
      ),
      (
        SettingsCategoryTab.appearance,
        Icons.palette_outlined,
        isThai ? 'การแสดงผล & ภาษา' : 'Appearance',
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
        automaticallyImplyLeading: Navigator.canPop(context),
        title: Text(
          isThai ? 'การตั้งค่า & บัญชี' : 'Settings & Account',
          style: GoogleFonts.notoSansThai(
            fontWeight: FontWeight.w700,
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
                      borderRadius: BorderRadius.circular(AppTheme.radius),
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
                          borderRadius: BorderRadius.circular(AppTheme.radius),
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
                                fontWeight: FontWeight.w600,
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
          if (_activeCategory == SettingsCategoryTab.profile)
            Expanded(
              child: ProfileScreen(
                repository: widget.repository,
                isEmbedded: true,
              ),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
                children: [
                  if (_activeCategory == SettingsCategoryTab.reading)
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
                  else if (_activeCategory == SettingsCategoryTab.appearance)
                    _buildAppearanceSection(
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
                  const SizedBox(height: 24),
                  _buildSystemAndResetSection(
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
                        borderRadius: BorderRadius.circular(AppTheme.radius),
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
                          const SizedBox(height: 2),
                          Text(
                            isThai
                                ? 'สลับระหว่างโหมดสว่างและโหมดมืดถนอมสายตา (บันทึกเฉพาะในอุปกรณ์นี้)'
                                : 'Switch between warm paper light and dark themes (saved locally on this device)',
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
                        borderRadius: BorderRadius.circular(AppTheme.radius),
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
                        borderRadius: BorderRadius.circular(AppTheme.radius),
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
                        borderRadius: BorderRadius.circular(AppTheme.radius),
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
    final currentMode = settings.readingMode;
    final wbwLang = settings.wordByWordLanguage;
    final wbwItems = _previewWbw[wbwLang] ?? _previewWbw['th']!;
    final primaryId = settings.primaryTranslationId;
    final secondaryId = settings.secondaryTranslationId;
    final primaryPreview =
        _previewTranslations[primaryId] ?? _previewTranslations['thai_v3']!;
    final secondaryPreview =
        secondaryId != null ? _previewTranslations[secondaryId] : null;

    final displayModes = [
      (
        SettingsProvider.quranTranslationMode,
        isThai ? 'อาหรับ + คำแปล' : 'Arabic + Trans',
        Icons.menu_book_rounded,
      ),
      (
        SettingsProvider.quranOnlyMode,
        isThai ? 'ภาษาอาหรับล้วน' : 'Arabic Only',
        Icons.mosque_outlined,
      ),
      (
        SettingsProvider.translationOnlyMode,
        isThai ? 'คำแปลล้วน' : 'Translation Only',
        Icons.subject_rounded,
      ),
    ];

    final wbwLanguages = [
      ('th', 'ไทย'),
      ('en', 'Eng'),
      ('ms', 'Melayu'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Live Bismillah Typography Preview Card
        _buildSectionHeader(
          colorScheme,
          isThai
              ? 'ตัวอย่างการอ่านจริง (LIVE PREVIEW)'
              : 'LIVE TYPOGRAPHY PREVIEW',
        ),
        const SizedBox(height: 8),
        _SettingsCard(
          colors: colors,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isThai
                          ? 'ตัวอย่างการแสดงผลตัวอักษร'
                          : 'Live Bismillah Preview',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: colors.mushafGold,
                      ),
                    ),
                    Text(
                      '1:1 Al-Fatihah',
                      style: GoogleFonts.notoSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    border: Border.all(color: colors.borderSoft),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (currentMode !=
                          SettingsProvider.translationOnlyMode) ...[
                        Text(
                          _previewArabic,
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontFamily: 'UthmanicHafs',
                            fontSize: settings.arabicFontSize,
                            color: colorScheme.onSurface,
                            height: 1.7,
                          ),
                        ),
                      ],
                      if (settings.showWordByWord) ...[
                        if (currentMode != SettingsProvider.translationOnlyMode)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Divider(height: 1, color: colors.borderSoft),
                          ),
                        Row(
                          children: [
                            Icon(
                              Icons.translate_rounded,
                              size: 13,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isThai
                                  ? 'ตัวอย่างคำต่อคำ (Word-by-Word Preview):'
                                  : 'Word-by-Word Preview:',
                              style: GoogleFonts.notoSansThai(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: colors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Directionality(
                          textDirection: TextDirection.rtl,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: wbwItems.map((item) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.surface,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusSm,
                                  ),
                                  border: Border.all(color: colors.borderSoft),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      item.$1,
                                      textDirection: TextDirection.rtl,
                                      style: TextStyle(
                                        fontFamily: 'UthmanicHafs',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.$2,
                                      textDirection: TextDirection.ltr,
                                      style: GoogleFonts.notoSansThai(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: colors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                      if (currentMode != SettingsProvider.quranOnlyMode) ...[
                        if (currentMode !=
                                SettingsProvider.translationOnlyMode ||
                            settings.showWordByWord)
                          const SizedBox(height: 12),
                        Text(
                          primaryPreview,
                          style: GoogleFonts.notoSansThai(
                            fontSize: settings.translationFontSize,
                            color: colorScheme.onSurface,
                            height: 1.55,
                          ),
                        ),
                        if (secondaryPreview != null) ...[
                          const SizedBox(height: 10),
                          Divider(height: 1, color: colors.borderSoft),
                          const SizedBox(height: 8),
                          Text(
                            isThai ? 'คำแปลรอง:' : 'Secondary Translation:',
                            style: GoogleFonts.notoSansThai(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: colors.mushafGold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            secondaryPreview,
                            style: GoogleFonts.notoSansThai(
                              fontSize: (settings.translationFontSize - 2)
                                  .clamp(12.0, 28.0),
                              color: colorScheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ],
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
                // Reading Display Mode 3-Button Selector
                Text(
                  isThai
                      ? 'โหมดการแสดงผลเนื้อหา (Display Mode)'
                      : 'Reading Display Mode',
                  style: GoogleFonts.notoSansThai(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isThai
                      ? 'เลือกแสดงภาษาอาหรับคู่บทแปล หรือแสดงเฉพาะอย่างใดอย่างหนึ่ง'
                      : 'Choose Arabic script and translation layout',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (int i = 0; i < displayModes.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () => settings.setReadingDisplayMode(
                            displayModes[i].$1,
                          ),
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: currentMode == displayModes[i].$1
                                  ? colors.primaryLight
                                  : colors.surfaceMuted,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radius,
                              ),
                              border: Border.all(
                                color: currentMode == displayModes[i].$1
                                    ? colors.primary
                                    : colors.borderSoft,
                                width:
                                    currentMode == displayModes[i].$1 ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  displayModes[i].$3,
                                  size: 16,
                                  color: currentMode == displayModes[i].$1
                                      ? colors.primary
                                      : colors.textMuted,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  displayModes[i].$2,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.notoSansThai(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: currentMode == displayModes[i].$1
                                        ? colors.primary
                                        : colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                Divider(height: 1, color: colors.borderSoft),
                const SizedBox(height: 14),

                // Arabic Font Size
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
                        fontWeight: FontWeight.w700,
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
                        fontWeight: FontWeight.w700,
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
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
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
              if (settings.showWordByWord) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isThai
                            ? 'ภาษาคำแปลคำต่อคำ (WBW Language)'
                            : 'Word-by-Word Language',
                        style: GoogleFonts.notoSansThai(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: colors.surfaceMuted,
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                          border: Border.all(color: colors.borderSoft),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: wbwLanguages.map((lang) {
                            return _SmallSegmentButton(
                              label: lang.$2,
                              isSelected: wbwLang == lang.$1,
                              colorScheme: colorScheme,
                              onTap: () =>
                                  settings.setWordByWordLanguage(lang.$1),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
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
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
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
                        top: Radius.circular(AppTheme.radiusLg),
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

  Widget _buildSystemAndResetSection(
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
          isThai ? 'ข้อมูลระบบและการคืนค่าเริ่มต้น' : 'SYSTEM & RESET',
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
                      isThai ? 'เวอร์ชันแอปพลิเคชัน' : 'App Version',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      'v3.0.0 Offline Ready',
                      style: GoogleFonts.notoSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Divider(height: 1, color: colors.borderSoft),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isThai ? 'ฐานข้อมูลคำแปลไทย' : 'Thai Translation',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        isThai
                            ? 'สมาคมนักเรียนเก่าอาหรับ (ฉบับปรับปรุงภาษา)'
                            : 'King Fahd Complex / Society of Arab Alumni',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.notoSansThai(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Divider(height: 1, color: colors.borderSoft),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isThai ? 'ข้อมูลมุศหัฟ' : 'Mushaf Data',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        'King Fahd Complex (Madinah 1405H)',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.notoSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Divider(height: 1, color: colors.borderSoft),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isThai ? 'เว็บไซต์ทางการ' : 'Official Platform',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    InkWell(
                      onTap: () async {
                        final uri = Uri.parse('https://quran-th.com');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'quran-th.com',
                              style: GoogleFonts.notoSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: colors.primary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.open_in_new_rounded,
                              size: 13,
                              color: colors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(height: 1, color: colors.borderSoft),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmAndResetDefaults(
                      context,
                      settings,
                      colors,
                      isThai,
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: colors.dangerSoft,
                      foregroundColor: colors.danger,
                      side: BorderSide(
                        color: colors.danger.withValues(alpha: 0.35),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                      ),
                    ),
                    icon: Icon(
                      Icons.restart_alt_rounded,
                      size: 18,
                      color: colors.danger,
                    ),
                    label: Text(
                      isThai
                          ? 'คืนค่าเริ่มต้นทั้งหมด (Reset All Settings to Defaults)'
                          : 'Reset All Settings to Defaults',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.danger,
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
                        fontWeight: FontWeight.w700,
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
                                    fontWeight: FontWeight.w700,
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
                                    fontWeight: FontWeight.w700,
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
                            fontWeight: FontWeight.w700,
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
          fontWeight: FontWeight.w700,
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
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: colors.borderSoft),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radius),
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
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: Text(
          label,
          style: GoogleFonts.notoSansThai(
            fontSize: 12,
            fontWeight: FontWeight.w600,
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
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.08)
              : colors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius),
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
                borderRadius: BorderRadius.circular(AppTheme.radius),
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
                      fontWeight: FontWeight.w700,
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
