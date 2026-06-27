// lib/screens/reading_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../providers/progress_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/local_reading_provider.dart';
import '../models/verse.dart';
import '../widgets/verse_card.dart';
import '../data/quran_repository.dart';
import '../theme/app_theme.dart';
import '../shared/shared.dart';

class ReadingScreen extends StatefulWidget {
  final QuranRepository repository;
  final String? initialSurah;
  final int? initialVerseIndex;
  final String? initialVerseId;
  final bool openSettingsPanel;

  const ReadingScreen({
    Key? key,
    required this.repository,
    this.initialSurah,
    this.initialVerseIndex,
    this.initialVerseId,
    this.openSettingsPanel = false,
  }) : super(key: key);

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  List<Verse> verses = [];
  String _currentSurah = '1';
  bool _isLoading = true;
  Map<int, Map<int, _ThaiThemeSection>> _themeSectionsBySurah = {};
  Map<String, _SurahObjective> _surahObjectives = {};

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await Future.wait([
      widget.repository.init(),
      _loadThemeSections(),
      _loadSurahObjectives(),
    ]);

    if (widget.initialSurah != null) {
      _loadSurah(
        widget.initialSurah!,
        jumpToIndex: widget.initialVerseIndex ?? 0,
        jumpToVerseId: widget.initialVerseId,
      );

      if (widget.openSettingsPanel) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showSettingsSheet();
        });
      }
    } else {
      final localReading = Provider.of<LocalReadingProvider>(
        context,
        listen: false,
      );
      final activeProfile = localReading.activeProfile;
      if (activeProfile != null) {
        _loadSurah(
          activeProfile.current.surahId,
          jumpToVerseId: activeProfile.current.verseId,
        );
        return;
      }

      final provider = Provider.of<ProgressProvider>(context, listen: false);
      while (!provider.isInitialized) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      _loadSurah(provider.currentSurahId, jumpToIndex: provider.lastVerseIndex);
    }
  }

  Future<void> _loadThemeSections() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/reconciled_thai_quran_themes.json',
      );
      final decoded = jsonDecode(jsonString);
      if (decoded is! List) return;

      final sectionsBySurah = <int, Map<int, _ThaiThemeSection>>{};
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) continue;

        final surah = _parseFlexibleInt(item['surah']);
        final verseRange = item['verse_range']?.toString().trim();
        final themeTh = item['theme_th']?.toString().trim();
        if (surah == null ||
            verseRange == null ||
            verseRange.isEmpty ||
            themeTh == null ||
            themeTh.isEmpty) {
          continue;
        }

        final startVerse = _parseThemeStartVerse(verseRange);
        if (startVerse == null) continue;

        sectionsBySurah.putIfAbsent(surah, () => {})[startVerse] =
            _ThaiThemeSection(themeTh: themeTh, verseRange: verseRange);
      }

      _themeSectionsBySurah = sectionsBySurah;
    } catch (error) {
      debugPrint('Unable to load Thai Quran theme sections: $error');
    }
  }

  Future<void> _loadSurahObjectives() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/surah_summary_th_exact.json',
      );
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) return;

      final objectives = <String, _SurahObjective>{};
      decoded.forEach((surahId, value) {
        if (value is! Map<String, dynamic>) return;

        final text = value['text']?.toString().trim();
        final source = value['source']?.toString().trim();
        if (text == null || text.isEmpty || source == null || source.isEmpty) {
          return;
        }

        objectives[surahId] = _SurahObjective(text: text, source: source);
      });

      _surahObjectives = objectives;
    } catch (error) {
      debugPrint('Unable to load Thai surah objectives: $error');
    }
  }

  int? _parseFlexibleInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  int? _parseThemeStartVerse(String verseRange) {
    final match = RegExp(r'\d+').firstMatch(verseRange);
    return match == null ? null : int.tryParse(match.group(0)!);
  }

  bool shouldShowHeader(int verseNumber) {
    final surah = int.tryParse(_currentSurah);
    if (surah == null) return false;
    return _themeSectionsBySurah[surah]?.containsKey(verseNumber) ?? false;
  }

  String getHeaderTitle(int verseNumber) {
    final surah = int.tryParse(_currentSurah);
    final section = surah == null
        ? null
        : _themeSectionsBySurah[surah]?[verseNumber];
    if (section == null) return '';
    return '${section.themeTh} (อายะห์ ${section.verseRange})';
  }

  Future<void> _loadSurah(
    String surahId, {
    int jumpToIndex = 0,
    String? jumpToVerseId,
  }) async {
    final provider = Provider.of<ProgressProvider>(context, listen: false);
    final localReading = Provider.of<LocalReadingProvider>(
      context,
      listen: false,
    );
    provider.setChangingSurah(true); // Disable listener

    setState(() {
      _isLoading = true;
      _currentSurah = surahId;
    });

    provider.setCurrentSurah(surahId);

    final allSurahVerses = widget.repository.getSurahVerses(surahId);
    final requestedVerseId =
        jumpToVerseId ??
        _defaultVisibleVerseIdForSurah(surahId, localReading.activeProfile) ??
        ((jumpToIndex >= 0 && jumpToIndex < allSurahVerses.length)
            ? allSurahVerses[jumpToIndex].id
            : allSurahVerses.firstOrNull?.id ?? '1');

    await localReading.switchToFreeReadIfOutside(surahId, requestedVerseId);
    if (!mounted) return;

    final loadedVerses = _visibleVersesForActiveProfile(
      surahId,
      allSurahVerses,
    );
    final targetIndex = jumpToVerseId == null
        ? loadedVerses.indexWhere((verse) => verse.id == requestedVerseId)
        : loadedVerses.indexWhere((verse) => verse.id == jumpToVerseId);
    final safeTargetIndex = targetIndex < 0
        ? 0
        : targetIndex.clamp(
            0,
            loadedVerses.isEmpty ? 0 : loadedVerses.length - 1,
          );
    provider.setTotalVerses(loadedVerses.length);

    setState(() {
      verses = loadedVerses;
      _isLoading = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (verses.isNotEmpty && provider.itemScrollController.isAttached) {
          provider.setVerseIndexAndScroll(safeTargetIndex);
        }
        // Safely re-enable listener after jump finishes
        Future.delayed(const Duration(milliseconds: 420), () {
          provider.setChangingSurah(false);
        });
      });
    });
  }

  List<Verse> _visibleVersesForActiveProfile(
    String surahId,
    List<Verse> allSurahVerses,
  ) {
    final localReading = Provider.of<LocalReadingProvider>(
      context,
      listen: false,
    );
    final profile = localReading.activeProfile;
    if (profile == null ||
        profile.target == null ||
        isFreeReadProfile(profile)) {
      return allSurahVerses;
    }

    final visible = allSurahVerses
        .where(
          (verse) => localReading.isVerseInsideProfile(
            profile,
            verse.surahId,
            verse.id,
          ),
        )
        .toList();
    return visible.isEmpty ? allSurahVerses : visible;
  }

  String? _defaultVisibleVerseIdForSurah(
    String surahId,
    LocalReadingProfile? profile,
  ) {
    if (profile == null ||
        profile.target == null ||
        isFreeReadProfile(profile)) {
      return null;
    }

    final surah = int.tryParse(surahId);
    final startSurah = int.tryParse(profile.start.surahId);
    final targetSurah = int.tryParse(profile.target!.surahId);
    if (surah == null || startSurah == null || targetSurah == null) {
      return null;
    }
    if (surah < startSurah || surah > targetSurah) return null;
    if (surah == startSurah) return profile.start.verseId;
    return '1';
  }

  bool _activeProfileHasVisibleVersesInSurah(String surahId) {
    final allVerses = widget.repository.getSurahVerses(surahId);
    if (allVerses.isEmpty) return false;

    final localReading = Provider.of<LocalReadingProvider>(
      context,
      listen: false,
    );
    final profile = localReading.activeProfile;
    if (profile == null ||
        profile.target == null ||
        isFreeReadProfile(profile)) {
      return true;
    }

    return allVerses.any(
      (verse) =>
          localReading.isVerseInsideProfile(profile, verse.surahId, verse.id),
    );
  }

  void _selectVerseIndex(int index) {
    final provider = Provider.of<ProgressProvider>(context, listen: false);
    provider.setVerseIndexAndScroll(index);
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (context) {
        return Consumer<SettingsProvider>(
          builder: (context, settings, child) {
            final isDark = settings.isDarkMode;
            final primaryColor = settings.getPrimaryColor();
            final colors = settings.getAppColors();

            return Container(
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  top: 24.0,
                  left: 24.0,
                  right: 24.0,
                  bottom: 24.0 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Display Settings',
                        style: GoogleFonts.prompt(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Dark Mode Toggle
                      SwitchListTile(
                        title: Text(
                          'Dark Mode',
                          style: GoogleFonts.prompt(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        value: settings.isDarkMode,
                        activeColor: primaryColor,
                        onChanged: (val) => settings.toggleDarkMode(val),
                      ),

                      // Arabic Display Toggle
                      SwitchListTile(
                        title: Text(
                          'Always Show Arabic Text',
                          style: GoogleFonts.prompt(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          'If unchecked, click the eye icon to reveal.',
                          style: GoogleFonts.prompt(fontSize: 12),
                        ),
                        value: settings.alwaysShowArabic,
                        activeColor: primaryColor,
                        onChanged: (val) =>
                            settings.toggleAlwaysShowArabic(val),
                      ),

                      SwitchListTile(
                        title: Text(
                          'Always Show Translation',
                          style: GoogleFonts.prompt(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          'Hide all translations for Arabic-only reading.',
                          style: GoogleFonts.prompt(fontSize: 12),
                        ),
                        value: settings.alwaysShowTranslation,
                        activeColor: primaryColor,
                        onChanged: (val) =>
                            settings.toggleAlwaysShowTranslation(val),
                      ),

                      const Divider(height: 24),
                      Text(
                        'Primary Translation',
                        style: GoogleFonts.prompt(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTranslationChip(
                              context,
                              label: 'Thai 3',
                              sublabel: 'Society of Institutes',
                              slotId: 'thai_v3',
                              isPrimary:
                                  settings.primaryTranslationId == 'thai_v3',
                              isInSecondary:
                                  settings.secondaryTranslationId == 'thai_v3',
                              primaryColor: primaryColor,
                              isDark: isDark,
                              onSelectPrimary: () {
                                if (settings.primaryTranslationId !=
                                    'thai_v3') {
                                  settings.updateTranslationSlot(
                                    'primary',
                                    'thai_v3',
                                  );
                                }
                              },
                              onToggleSecondary: () {
                                final isInSec =
                                    settings.secondaryTranslationId ==
                                    'thai_v3';
                                settings.updateTranslationSlot(
                                  'secondary',
                                  isInSec ? null : 'thai_v3',
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildTranslationChip(
                              context,
                              label: 'Thai 2',
                              sublabel: 'Society of Institutes',
                              slotId: 'thai_v2',
                              isPrimary:
                                  settings.primaryTranslationId == 'thai_v2',
                              isInSecondary:
                                  settings.secondaryTranslationId == 'thai_v2',
                              primaryColor: primaryColor,
                              isDark: isDark,
                              onSelectPrimary: () {
                                if (settings.primaryTranslationId !=
                                    'thai_v2') {
                                  settings.updateTranslationSlot(
                                    'primary',
                                    'thai_v2',
                                  );
                                }
                              },
                              onToggleSecondary: () {
                                final isInSec =
                                    settings.secondaryTranslationId ==
                                    'thai_v2';
                                settings.updateTranslationSlot(
                                  'secondary',
                                  isInSec ? null : 'thai_v2',
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildTranslationChip(
                              context,
                              label: 'English',
                              sublabel: 'Saheeh International',
                              slotId: 'english',
                              isPrimary:
                                  settings.primaryTranslationId == 'english',
                              isInSecondary:
                                  settings.secondaryTranslationId == 'english',
                              primaryColor: primaryColor,
                              isDark: isDark,
                              onSelectPrimary: () {
                                if (settings.primaryTranslationId !=
                                    'english') {
                                  settings.updateTranslationSlot(
                                    'primary',
                                    'english',
                                  );
                                }
                              },
                              onToggleSecondary: () {
                                final isInSec =
                                    settings.secondaryTranslationId ==
                                    'english';
                                settings.updateTranslationSlot(
                                  'secondary',
                                  isInSec ? null : 'english',
                                );
                              },
                            ),
                          ),
                        ],
                      ),

                      const Divider(height: 32),

                      // Arabic Font Family Choice
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Arabic Font Style',
                            style: GoogleFonts.prompt(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          DropdownButton<String>(
                            value: settings.arabicFontFamily,
                            dropdownColor: colors.surface,
                            style: GoogleFonts.prompt(
                              color: colors.textStrong,
                              fontWeight: FontWeight.w500,
                            ),
                            underline: Container(),
                            items: const [
                              DropdownMenuItem(
                                value: 'UthmanicHafs',
                                child: Text('Uthmanic Hafs'),
                              ),
                              DropdownMenuItem(
                                value: 'AmiriQuran',
                                child: Text('Amiri Quran'),
                              ),
                              DropdownMenuItem(
                                value: 'ScheherazadeNew',
                                child: Text('Scheherazade New'),
                              ),
                              DropdownMenuItem(
                                value: 'Amiri',
                                child: Text('Amiri Regular'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null)
                                settings.setArabicFontFamily(val);
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Arabic Font Size Choice
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Arabic Font Size',
                                style: GoogleFonts.prompt(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${settings.arabicFontSize.round()} px',
                                style: GoogleFonts.prompt(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: settings.arabicFontSize,
                            min: 20.0,
                            max: 48.0,
                            divisions: 14,
                            activeColor: primaryColor,
                            inactiveColor: primaryColor.withOpacity(0.2),
                            onChanged: (val) => settings.setArabicFontSize(val),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Translation Font Size Choice
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Translation Font Size',
                                style: GoogleFonts.prompt(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${settings.translationFontSize.round()} px',
                                style: GoogleFonts.prompt(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: settings.translationFontSize,
                            min: 12.0,
                            max: 24.0,
                            divisions: 12,
                            activeColor: primaryColor,
                            inactiveColor: primaryColor.withOpacity(0.2),
                            onChanged: (val) =>
                                settings.setTranslationFontSize(val),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTranslationChip(
    BuildContext context, {
    required String label,
    required String sublabel,
    required String slotId,
    required bool isPrimary,
    required bool isInSecondary,
    required Color primaryColor,
    required bool isDark,
    required VoidCallback onSelectPrimary,
    required VoidCallback onToggleSecondary,
  }) {
    final isActive = isPrimary || isInSecondary;
    return GestureDetector(
      onTap: onSelectPrimary,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: isPrimary
              ? primaryColor.withOpacity(0.12)
              : isInSecondary
              ? Colors.blue.withOpacity(0.08)
              : isDark
              ? const Color(0xFF1E293B)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isPrimary
                ? primaryColor.withOpacity(0.5)
                : isInSecondary
                ? Colors.blue.withOpacity(0.3)
                : isDark
                ? Colors.blueGrey.shade700
                : Colors.grey.shade300,
            width: isPrimary ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.prompt(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isPrimary
                    ? primaryColor
                    : isInSecondary
                    ? Colors.blue.shade700
                    : isDark
                    ? Colors.blueGrey.shade300
                    : Colors.blueGrey.shade600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              isPrimary
                  ? 'Primary'
                  : isInSecondary
                  ? 'Secondary'
                  : sublabel,
              style: GoogleFonts.prompt(
                fontSize: 9,
                color: isActive
                    ? (isPrimary ? primaryColor : Colors.blue.shade600)
                    : isDark
                    ? Colors.blueGrey.shade500
                    : Colors.blueGrey.shade400,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBismillahBanner(SettingsProvider settings, bool isDark) {
    final colors = settings.getAppColors();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceMuted.withOpacity(0.5)
            : colors.primaryLight.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Center(
        child: SvgPicture.asset(
          'assets/Bismillah_Calligraphy6.svg',
          height: 60,
          colorFilter: ColorFilter.mode(colors.textStrong, BlendMode.srcIn),
        ),
      ),
    );
  }

  Widget _buildObjectivesBanner(
    String surahId,
    SettingsProvider settings,
    bool isDark,
  ) {
    final objective = _surahObjectives[surahId];
    if (objective == null) return const SizedBox.shrink();

    final colors = settings.getAppColors();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceMuted.withOpacity(0.7)
            : colors.primaryLight.withOpacity(0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_rounded, color: colors.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'เป้าหมายหลักของซูเราะฮ์',
                  style: GoogleFonts.prompt(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            objective.text,
            style: GoogleFonts.prompt(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.45,
              color: colors.textStrong,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'ที่มา: ${objective.source}',
            style: GoogleFonts.prompt(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: colors.foreground.withOpacity(0.72),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeHeader(
    SettingsProvider settings,
    bool isDark,
    int verseNumber,
  ) {
    final colors = settings.getAppColors();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceMuted.withOpacity(0.85) : colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Text(
        getHeaderTitle(verseNumber),
        style: GoogleFonts.prompt(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          height: 1.45,
          color: colors.textStrong,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ProgressProvider>(context, listen: false);
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = settings.getPrimaryColor();
    final colors = settings.getAppColors();
    final surahIds = List.generate(114, (index) => (index + 1).toString());

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colors.surfaceMuted,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.textStrong),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.repository.getSurahName(_currentSurah),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: colors.textStrong,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            Consumer2<LocalReadingProvider, ProgressProvider>(
              builder: (context, localReading, progressProv, child) {
                final activeProfile = localReading.activeProfile;
                final profileName = activeProfile?.name ?? 'Free Read';
                final activeVerseId =
                    (progressProv.lastVerseIndex >= 0 &&
                        progressProv.lastVerseIndex < verses.length)
                    ? verses[progressProv.lastVerseIndex].id
                    : '1';
                return Text(
                  '$profileName - $_currentSurah:$activeVerseId',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: colors.foreground,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_rounded, color: colors.primary),
            tooltip: 'Settings',
            onPressed: _showSettingsSheet,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colors.borderSoft)),
            ),
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border.all(color: colors.borderSoft),
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _currentSurah,
                        isExpanded: true,
                        dropdownColor: colors.surface,
                        iconEnabledColor: colors.primary,
                        style: GoogleFonts.inter(
                          color: colors.textStrong,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                        items: surahIds
                            .map(
                              (id) => DropdownMenuItem(
                                value: id,
                                child: Text(
                                  widget.repository.getSurahName(id),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (surahId) {
                          if (surahId != null && surahId != _currentSurah) {
                            _loadSurah(surahId);
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 96,
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border.all(color: colors.borderSoft),
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                    ),
                    child: Consumer<ProgressProvider>(
                      builder: (context, progressProv, child) {
                        final currentIndex = progressProv.lastVerseIndex;
                        final safeIndex = verses.isEmpty
                            ? 0
                            : currentIndex.clamp(0, verses.length - 1);
                        return DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: verses.isEmpty ? null : safeIndex,
                            isExpanded: true,
                            dropdownColor: colors.surface,
                            iconEnabledColor: colors.primary,
                            style: GoogleFonts.inter(
                              color: colors.textStrong,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                            hint: const Text('Ayah'),
                            items: List.generate(
                              verses.length,
                              (index) => DropdownMenuItem(
                                value: index,
                                child: Text(verses[index].id),
                              ),
                            ),
                            onChanged: (index) {
                              if (index != null) _selectVerseIndex(index);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : ScrollablePositionedList.builder(
              itemCount: verses.length + 1,
              itemBuilder: (context, index) {
                if (index == verses.length) {
                  return _buildCompletionCard(
                    context,
                    provider,
                    settings,
                    isDark,
                  );
                }

                final card = VerseCard(
                  key: ValueKey('${verses[index].surahId}_${verses[index].id}'),
                  verse: verses[index],
                  repository: widget.repository,
                  index: index,
                );
                final verseNumber = int.tryParse(verses[index].id);
                final showThemeHeader =
                    verseNumber != null && shouldShowHeader(verseNumber);

                if (index == 0) {
                  return Column(
                    children: [
                      if (_currentSurah != '9')
                        _buildBismillahBanner(settings, isDark),
                      _buildObjectivesBanner(_currentSurah, settings, isDark),
                      if (showThemeHeader)
                        _buildThemeHeader(settings, isDark, verseNumber),
                      card,
                    ],
                  );
                }

                if (showThemeHeader) {
                  return Column(
                    children: [
                      if (showThemeHeader)
                        _buildThemeHeader(settings, isDark, verseNumber),
                      card,
                    ],
                  );
                }
                return card;
              },
              itemScrollController: provider.itemScrollController,
              itemPositionsListener: provider.itemPositionsListener,
              padding: const EdgeInsets.only(top: 12, bottom: 100),
            ),
      bottomNavigationBar: _isLoading
          ? null
          : Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 10,
                bottom: MediaQuery.of(context).padding.bottom + 10,
              ),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? Colors.blueGrey.shade800.withOpacity(0.4)
                        : Colors.grey.shade200,
                    width: 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Consumer2<LocalReadingProvider, ProgressProvider>(
                builder: (context, localReading, progressProv, child) {
                  final currentIndex = progressProv.lastVerseIndex;
                  final totalCount = verses.length;
                  final hasPrev = currentIndex > 0;
                  final hasNext = currentIndex < totalCount - 1;

                  return Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: hasPrev
                            ? () {
                                progressProv.setVerseIndexAndScroll(
                                  currentIndex - 1,
                                );
                              }
                            : null,
                        icon: const Icon(Icons.chevron_left_rounded),
                        tooltip: 'Previous ayah',
                        style: IconButton.styleFrom(
                          foregroundColor: primaryColor,
                          disabledForegroundColor: colors.foreground
                              .withOpacity(0.35),
                          backgroundColor: colors.primaryLight,
                          disabledBackgroundColor: colors.surfaceMuted,
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: colors.textInverse,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              elevation: 0,
                            ),
                            onPressed: () async {
                              final activeProfile = localReading.activeProfile;
                              final currentIndex = progressProv.lastVerseIndex;
                              if (activeProfile != null &&
                                  currentIndex >= 0 &&
                                  currentIndex < verses.length) {
                                final currentVerse = verses[currentIndex];
                                final verseRef = toVerseRef(
                                  currentVerse.surahId,
                                  currentVerse.id,
                                );

                                await localReading.updateProfileProgress(
                                  activeProfile.id,
                                  verseRef,
                                  context: context,
                                );
                                await localReading.addRecentReading(
                                  verse: verseRef,
                                  profileId: activeProfile.id,
                                );
                              }
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            },
                            icon: const Icon(
                              Icons.pause_circle_outline_rounded,
                              size: 18,
                            ),
                            label: Text(
                              'Take a break',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: hasNext
                            ? () {
                                progressProv.setVerseIndexAndScroll(
                                  currentIndex + 1,
                                );
                              }
                            : null,
                        icon: const Icon(Icons.chevron_right_rounded),
                        tooltip: 'Next ayah',
                        style: IconButton.styleFrom(
                          foregroundColor: primaryColor,
                          disabledForegroundColor: colors.foreground
                              .withOpacity(0.35),
                          backgroundColor: colors.primaryLight,
                          disabledBackgroundColor: colors.surfaceMuted,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }

  Widget _buildCompletionCard(
    BuildContext context,
    ProgressProvider progressProv,
    SettingsProvider settingsProv,
    bool isDark,
  ) {
    final primaryColor = settingsProv.getPrimaryColor();
    final colors = settingsProv.getAppColors();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.blueGrey.shade800.withOpacity(0.5)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '🎉 สิ้นสุดซูเราะฮฺแล้ว',
            style: GoogleFonts.prompt(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.textStrong,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'คุณอ่านมาถึงอายะฮฺสุดท้ายของซูเราะฮฺ $_currentSurah แล้ว ทำเครื่องหมายเพื่อบันทึกสถิติของคุณ',
            textAlign: TextAlign.center,
            style: GoogleFonts.prompt(
              fontSize: 13,
              color: isDark ? Colors.blueGrey.shade300 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                progressProv.incrementCompletedRead();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'บันทึกการอ่านซูเราะฮฺที่จบแล้ว!',
                      style: GoogleFonts.prompt(color: Colors.white),
                    ),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
              child: Text(
                '📖 อ่านจบแล้ว',
                style: GoogleFonts.prompt(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              final int currentSurahInt = int.tryParse(_currentSurah) ?? 1;
              final prevSurahId = (currentSurahInt - 1).toString();
              final nextSurahId = (currentSurahInt + 1).toString();
              final bool hasPrevSurah =
                  currentSurahInt > 1 &&
                  _activeProfileHasVisibleVersesInSurah(prevSurahId);
              final bool hasNextSurah =
                  currentSurahInt < 114 &&
                  _activeProfileHasVisibleVersesInSurah(nextSurahId);

              if (!hasPrevSurah && !hasNextSurah)
                return const SizedBox.shrink();

              return Row(
                children: [
                  if (hasPrevSurah)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _loadSurah(prevSurahId),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: BorderSide(
                            color: primaryColor.withOpacity(0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          '⬅️ ซูเราะฮฺก่อนหน้า',
                          style: GoogleFonts.prompt(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (hasPrevSurah && hasNextSurah) const SizedBox(width: 12),
                  if (hasNextSurah)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _loadSurah(nextSurahId),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: BorderSide(
                            color: primaryColor.withOpacity(0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'ซูเราะฮฺถัดไป ➡️',
                          style: GoogleFonts.prompt(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ThaiThemeSection {
  final String themeTh;
  final String verseRange;

  const _ThaiThemeSection({required this.themeTh, required this.verseRange});
}

class _SurahObjective {
  final String text;
  final String source;

  const _SurahObjective({required this.text, required this.source});
}
