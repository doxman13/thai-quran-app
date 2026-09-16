import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/quran_repository.dart';
import '../providers/settings_provider.dart';
import '../services/remote_content_service.dart';
import '../widgets/flexcil_settings_widgets.dart';
import '../widgets/tajweed_color_guide_sheet.dart';
import '../widgets/translation_manager_section.dart';
import '../shared/shared.dart';
import 'hifz_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  final QuranRepository? repository;

  const SettingsScreen({super.key, this.repository});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedTabIndex = 0;
  bool _isCheckingContentUpdates = false;

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final colors = settings.getAppColors();
    final colorScheme = Theme.of(context).colorScheme;
    final isThai = settings.languageCode == 'th';

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
      body: Column(
        children: [
          // 🔝 Flexcil-Style Segmented Top Tab Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: FlexcilSegmentedPills<int>(
              items: [
                FlexcilPillItem<int>(
                  value: 0,
                  label: isThai ? 'การอ่านและฟอนต์' : 'Typography',
                  icon: Icons.format_size_rounded,
                ),
                FlexcilPillItem<int>(
                  value: 1,
                  label: isThai ? 'คำแปลและเนื้อหา' : 'Translations',
                  icon: Icons.auto_stories_rounded,
                ),
                FlexcilPillItem<int>(
                  value: 2,
                  label: isThai ? 'ธีมและระบบ' : 'Theme & System',
                  icon: Icons.tune_rounded,
                ),
              ],
              selectedValue: _selectedTabIndex,
              onSelected: (idx) {
                setState(() => _selectedTabIndex = idx);
              },
            ),
          ),

          // 📜 Tab Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                if (_selectedTabIndex == 0) ..._buildTypographyTab(settings, colors, colorScheme, isThai),
                if (_selectedTabIndex == 1) ..._buildTranslationsTab(colors, colorScheme, isThai),
                if (_selectedTabIndex == 2) ..._buildSystemTab(settings, colorScheme, isThai),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 🔤 TAB 0: TYPOGRAPHY & READING EXPERIENCE
  // ─────────────────────────────────────────────────────────────
  List<Widget> _buildTypographyTab(
    SettingsProvider settings,
    dynamic colors,
    ColorScheme colorScheme,
    bool isThai,
  ) {
    return [
      // 👁️ Interactive Live Reading Preview
      FlexcilLivePreview(
        arabicFontSize: settings.arabicFontSize,
        translationFontSize: settings.translationFontSize,
        readingDisplayMode: settings.readingDisplayMode,
        isThai: isThai,
      ),
      const SizedBox(height: 16),

      // 📏 Font Sizing Steppers
      FlexcilSectionHeader(
        title: isThai ? 'ขนาดตัวอักษร' : 'Font Sizing',
        subtitle: isThai
            ? 'ปรับขนาดฟอนต์ภาษาอาหรับและคำแปลให้เหมาะกับสายตา'
            : 'Adjust Arabic and translation sizes for comfortable reading',
      ),
      FlexcilCard(
        child: Column(
          children: [
            FlexcilStepper(
              title: isThai ? 'ขนาดตัวบทภาษาอาหรับ' : 'Arabic Script Size',
              value: settings.arabicFontSize,
              min: 18.0,
              max: 48.0,
              step: 2.0,
              onChanged: (val) => settings.setArabicFontSize(val),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(
                height: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.25),
              ),
            ),
            FlexcilStepper(
              title: isThai ? 'ขนาดฟอนต์คำแปล' : 'Translation Size',
              value: settings.translationFontSize,
              min: 12.0,
              max: 32.0,
              step: 1.0,
              onChanged: (val) => settings.setTranslationFontSize(val),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),

      // 📖 Reading Display Mode Selector
      FlexcilSectionHeader(
        title: isThai ? 'โหมดการแสดงผลตัวบท' : 'Reading Display Mode',
        subtitle: isThai
            ? 'เลือกให้แสดงคู่คำแปล หรือแสดงเฉพาะภาษาอาหรับล้วน'
            : 'Choose between side-by-side, Arabic only, or translation only',
      ),
      FlexcilCard(
        padding: const EdgeInsets.all(12),
        child: FlexcilSegmentedPills<String>(
          items: [
            FlexcilPillItem<String>(
              value: SettingsProvider.quranTranslationMode,
              label: isThai ? 'อาหรับ + คำแปล' : 'Both',
              icon: Icons.auto_stories_rounded,
            ),
            FlexcilPillItem<String>(
              value: SettingsProvider.quranOnlyMode,
              label: isThai ? 'อาหรับล้วน' : 'Arabic Only',
              icon: Icons.menu_book_rounded,
            ),
            FlexcilPillItem<String>(
              value: SettingsProvider.translationOnlyMode,
              label: isThai ? 'คำแปลล้วน' : 'Trans Only',
              icon: Icons.article_rounded,
            ),
          ],
          selectedValue: settings.readingDisplayMode,
          onSelected: (mode) => settings.setReadingDisplayMode(mode),
        ),
      ),
      const SizedBox(height: 20),

      // 🔍 Word-by-Word & Footnotes Group
      FlexcilSectionHeader(
        title: isThai ? 'การเรียนรู้และคำต่อคำ' : 'Word-by-Word & Commentary',
        subtitle: isThai
            ? 'กำหนดภาษาคำต่อคำ และการแสดงตัวเลขเชิงอรรถ'
            : 'Configure word-by-word meanings and footnote commentary',
      ),
      FlexcilCard(
        child: Column(
          children: [
            FlexcilToggleTile(
              icon: Icons.translate_rounded,
              title: isThai ? 'แสดงความหมายคำต่อคำ (WBW)' : 'Word-by-Word Meanings',
              subtitle: isThai
                  ? 'แสดงความหมายแยกทีละคำใต้ตัวบทภาษาอาหรับ'
                  : 'Display word-for-word translation below Arabic words',
              value: settings.showWordByWord,
              onChanged: (val) => settings.toggleShowWordByWord(val),
            ),
            if (settings.showWordByWord) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isThai ? 'ภาษาคำต่อคำ' : 'Word-by-Word Language',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FlexcilSegmentedPills<String>(
                      items: const [
                        FlexcilPillItem<String>(
                          value: 'th',
                          label: 'ภาษาไทย',
                        ),
                        FlexcilPillItem<String>(
                          value: 'ms',
                          label: 'Bahasa Melayu',
                        ),
                        FlexcilPillItem<String>(
                          value: 'en',
                          label: 'English',
                        ),
                      ],
                      selectedValue: settings.wordByWordLanguage,
                      onSelected: (lang) => settings.setWordByWordLanguage(lang),
                    ),
                  ],
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Divider(
                height: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.25),
              ),
            ),
            FlexcilToggleTile(
              icon: Icons.bookmark_border_rounded,
              title: isThai ? 'แสดงเชิงอรรถ (Footnotes)' : 'Footnotes & Commentary',
              subtitle: isThai
                  ? 'แสดงตัวเลขเชิงอรรถ [1] และคำอธิบายใต้บทแปล'
                  : 'Show footnote numbers [1] and commentary under translations',
              value: settings.showFootnotes,
              onChanged: (val) => settings.setShowFootnotes(val),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Divider(
                height: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.25),
              ),
            ),
            InkWell(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: colors.surface,
                  showDragHandle: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (ctx) => TajweedColorGuideSheet(colors: colors),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.palette_outlined, color: colorScheme.primary, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('tajweed_guide_title'),
                            style: GoogleFonts.notoSansThai(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.tr('tajweed_guide_desc'),
                            style: GoogleFonts.notoSansThai(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  // ─────────────────────────────────────────────────────────────
  // 📚 TAB 1: TRANSLATIONS & UPDATES
  // ─────────────────────────────────────────────────────────────
  List<Widget> _buildTranslationsTab(
    dynamic colors,
    ColorScheme colorScheme,
    bool isThai,
  ) {
    return [
      FlexcilSectionHeader(
        title: isThai ? 'การจัดการคำแปล' : 'Translation Manager',
        subtitle: isThai
            ? 'เลือกคำแปลหลัก คำแปลเสริม หรือดาวน์โหลดภาษาเพิ่มเติม'
            : 'Configure primary and secondary translations or download offline packs',
      ),
      TranslationManagerSection(colors: colors),
      const SizedBox(height: 24),
      _buildContentUpdateSection(colorScheme),
    ];
  }

  // ─────────────────────────────────────────────────────────────
  // ⚙️ TAB 2: THEME & SYSTEM
  // ─────────────────────────────────────────────────────────────
  List<Widget> _buildSystemTab(
    SettingsProvider settings,
    ColorScheme colorScheme,
    bool isThai,
  ) {
    return [
      // 🎨 Theme & Screen Wake
      FlexcilSectionHeader(
        title: isThai ? 'การแสดงผลและหน้าจอ' : 'Appearance & Screen',
        subtitle: isThai
            ? 'ปรับธีมสีสว่าง/มืด และการเปิดหน้าจอค้าง'
            : 'Light/dark theme mode and screen wake behavior',
      ),
      FlexcilCard(
        child: Column(
          children: [
            FlexcilSegmentedPills<bool>(
              items: [
                FlexcilPillItem<bool>(
                  value: false,
                  label: isThai ? 'สว่าง (Light)' : 'Light',
                  icon: Icons.wb_sunny_rounded,
                ),
                FlexcilPillItem<bool>(
                  value: true,
                  label: isThai ? 'มืด (Dark)' : 'Dark',
                  icon: Icons.nightlight_round,
                ),
              ],
              selectedValue: settings.isDarkMode,
              onSelected: (dark) => settings.toggleDarkMode(dark),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Divider(
                height: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.25),
              ),
            ),
            FlexcilToggleTile(
              icon: Icons.lightbulb_outline_rounded,
              title: context.tr('keep_screen_awake'),
              subtitle: context.tr('keep_screen_awake_desc'),
              value: settings.keepAwake,
              onChanged: settings.toggleKeepAwake,
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),

      // 🌐 Interface Language
      FlexcilSectionHeader(
        title: isThai ? 'ภาษาของระบบ' : 'Interface Language',
        subtitle: isThai
            ? 'เปลี่ยนภาษาเมนูและการใช้งานในแอป'
            : 'Choose UI language for buttons and navigation',
      ),
      FlexcilCard(
        padding: const EdgeInsets.all(12),
        child: FlexcilSegmentedPills<String>(
          items: const [
            FlexcilPillItem<String>(
              value: 'th',
              label: 'ภาษาไทย (Thai)',
              icon: Icons.language_rounded,
            ),
            FlexcilPillItem<String>(
              value: 'en',
              label: 'English',
              icon: Icons.language_rounded,
            ),
          ],
          selectedValue: settings.languageCode,
          onSelected: (lang) => settings.setLanguageCode(lang),
        ),
      ),
      const SizedBox(height: 20),

      // 🧠 Shortcut to Hifz / Hardware Settings
      FlexcilSectionHeader(
        title: isThai ? 'โหมดท่องจำและอุปกรณ์' : 'Hifz & Hardware',
        subtitle: isThai
            ? 'เชื่อมต่ออุปกรณ์เลื่อนอายะห์ รีโมตบลูทูธ และ AI'
            : 'Manage BLE Smart Ring, shutter remote, and AI voice recitation',
      ),
      FlexcilCard(
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const HifzSettingsScreen(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.psychology_rounded,
                    color: colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isThai ? 'การตั้งค่าท่องจำและอุปกรณ์' : 'Hifz & Hardware Settings',
                        style: GoogleFonts.notoSansThai(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isThai
                            ? 'แหวนบลูทูธ (Smart Ring), รีโมตชัตเตอร์ และระบบตรวจจับเสียงอ่าน'
                            : 'BLE Smart Ring, remote shutter, and voice recitation tracking',
                        style: GoogleFonts.notoSansThai(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  // ─────────────────────────────────────────────────────────────
  // 🔄 CONTENT UPDATES SECTION
  // ─────────────────────────────────────────────────────────────
  Widget _buildContentUpdateSection(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FlexcilSectionHeader(
          title: context.tr('content_updates'),
          subtitle: context.tr('content_updates_desc'),
        ),
        FlexcilCard(
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
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isCheckingContentUpdates ? null : _checkContentUpdates,
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
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
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _checkContentUpdates() async {
    setState(() => _isCheckingContentUpdates = true);
    try {
      final result = await RemoteContentService.instance.updateAll();
      if (result.updated > 0) {
        await widget.repository?.reloadRemoteContent();
      }
      if (!mounted) return;
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

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
}
