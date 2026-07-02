// lib/screens/reading_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../providers/progress_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/local_reading_provider.dart';
import '../providers/translation_manager_provider.dart';
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
  final bool saveToFreeReadOnly;

  const ReadingScreen({
    Key? key,
    required this.repository,
    this.initialSurah,
    this.initialVerseIndex,
    this.initialVerseId,
    this.openSettingsPanel = false,
    this.saveToFreeReadOnly = false,
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

    // Enable Wakelock if keepAwake setting is true
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final settings = Provider.of<SettingsProvider>(context, listen: false);
        if (settings.keepAwake) {
          WakelockPlus.enable();
        }
      }
    });
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
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
      final progressProfile = _progressProfile(localReading);
      if (progressProfile != null) {
        _loadSurah(
          progressProfile.current.surahId,
          jumpToVerseId: progressProfile.current.verseId,
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
    final progressProfile = _progressProfile(localReading);
    final requestedVerseId =
        jumpToVerseId ??
        _defaultVisibleVerseIdForSurah(surahId, progressProfile) ??
        ((jumpToIndex >= 0 && jumpToIndex < allSurahVerses.length)
            ? allSurahVerses[jumpToIndex].id
            : allSurahVerses.firstOrNull?.id ?? '1');

    if (!widget.saveToFreeReadOnly) {
      await localReading.switchToFreeReadIfOutside(surahId, requestedVerseId);
    }
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
    final profile = _progressProfile(localReading);
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
    final profile = _progressProfile(localReading);
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

  LocalReadingProfile? _progressProfile(LocalReadingProvider localReading) {
    if (widget.saveToFreeReadOnly) {
      return localReading.freeReadProfile;
    }
    return localReading.activeProfile;
  }

  bool _isBoundedCreatedProfile(LocalReadingProfile? profile) {
    return profile != null &&
        profile.target != null &&
        !isFreeReadProfile(profile);
  }

  int _verseOrdinal(String surahId, String verseId) {
    var ordinal = 0;
    for (var surah = 1; surah <= 114; surah++) {
      final id = surah.toString();
      final count = widget.repository.getSurahVerses(id).length;
      if (id == surahId) return ordinal + (int.tryParse(verseId) ?? 1);
      ordinal += count;
    }
    return ordinal;
  }

  int _profileTotalAyahs(LocalReadingProfile profile) {
    if (profile.target == null) return verses.length;
    final start = _verseOrdinal(profile.start.surahId, profile.start.verseId);
    final target = _verseOrdinal(
      profile.target!.surahId,
      profile.target!.verseId,
    );
    return (target - start + 1).clamp(0, 6236).toInt();
  }

  int _profileReadPosition(LocalReadingProfile profile, VerseRef current) {
    final totalAyahs = _profileTotalAyahs(profile);
    if (totalAyahs <= 0) return 0;
    final start = _verseOrdinal(profile.start.surahId, profile.start.verseId);
    final currentOrdinal = _verseOrdinal(current.surahId, current.verseId);
    return (currentOrdinal - start + 1).clamp(1, totalAyahs).toInt();
  }

  String _ayahLeftLabel(int count) {
    return count == 1 ? '1 ayah left' : '$count ayahs left';
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (context) {
        return Consumer2<SettingsProvider, TranslationManagerProvider>(
          builder: (context, settings, transManager, child) {
            final colorScheme = Theme.of(context).colorScheme;

            return Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppTheme.radius),
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
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Dark Mode Toggle
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        title: Text(
                          'Dark Mode',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        value: settings.isDarkMode,
                        activeColor: colorScheme.primary,
                        onChanged: (val) => settings.toggleDarkMode(val),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Reading Mode',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: settings.readingDisplayMode,
                        dropdownColor: colorScheme.surfaceContainerLow,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: colorScheme.surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radius),
                            borderSide: BorderSide(color: colorScheme.outline, width: 1),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radius),
                            borderSide: BorderSide(color: colorScheme.outline, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radius),
                            borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
                          ),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: SettingsProvider.quranOnlyMode,
                            child: Text('Quran Only', style: GoogleFonts.inter(color: colorScheme.onSurface)),
                          ),
                          DropdownMenuItem(
                            value: SettingsProvider.translationOnlyMode,
                            child: Text('Translation Only', style: GoogleFonts.inter(color: colorScheme.onSurface)),
                          ),
                          DropdownMenuItem(
                            value: SettingsProvider.quranTranslationMode,
                            child: Text('Quran & Translation', style: GoogleFonts.inter(color: colorScheme.onSurface)),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) settings.setReadingDisplayMode(val);
                        },
                      ),

                      const Divider(height: 32),
                      Text(
                        'Translations',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                          border: Border.all(color: colorScheme.outline, width: 1),
                        ),
                        child: Column(
                          children: [
                            _buildTranslationCheckbox(context, settings, 'thai_v3', 'Thai (V3)', colorScheme),
                            Divider(height: 1, color: colorScheme.outline),
                            _buildTranslationCheckbox(context, settings, 'thai_v2', 'Thai (V2)', colorScheme),
                            Divider(height: 1, color: colorScheme.outline),
                            _buildTranslationCheckbox(context, settings, 'english', 'English (MHE)', colorScheme),
                            
                            ...transManager.downloadedTranslations.map((t) {
                              final idStr = t['id'].toString();
                              return Column(
                                children: [
                                  Divider(height: 1, color: colorScheme.outline),
                                  _buildTranslationCheckbox(
                                    context,
                                    settings,
                                    idStr,
                                    t['name'],
                                    colorScheme,
                                    subtitleText: '${t['language']} - ${t['author']}',
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),

                      const Divider(height: 32),

                      // Arabic Font Size Choice
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Arabic Font Size',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                '${settings.arabicFontSize.round()} px',
                                style: GoogleFonts.inter(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
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
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                '${settings.translationFontSize.round()} px',
                                style: GoogleFonts.inter(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
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

  Widget _buildTranslationCheckbox(
    BuildContext context,
    SettingsProvider settings,
    String id,
    String label,
    ColorScheme colorScheme, {
    String? subtitleText,
  }) {
    final isPrimary = settings.primaryTranslationId == id;
    final isSecondary = settings.secondaryTranslationId == id;
    final isChecked = isPrimary || isSecondary;

    return CheckboxListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        label,
        style: GoogleFonts.inter(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        isPrimary 
            ? 'Primary' 
            : isSecondary 
                ? 'Secondary' 
                : (subtitleText ?? ''),
        style: GoogleFonts.inter(
          color: isPrimary 
              ? colorScheme.primary 
              : isSecondary 
                  ? Colors.blue 
                  : colorScheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: (isPrimary || isSecondary) ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      value: isChecked,
      activeColor: colorScheme.primary,
      onChanged: (val) {
        if (val == true) {
          if (settings.secondaryTranslationId == null && settings.primaryTranslationId != id) {
            settings.updateTranslationSlot('secondary', id);
          } else {
            settings.updateTranslationSlot('secondary', id);
          }
        } else {
          if (isPrimary) {
            if (settings.secondaryTranslationId != null) {
              settings.updateTranslationSlot('primary', settings.secondaryTranslationId);
              settings.updateTranslationSlot('secondary', null);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('At least one translation must be active.')),
              );
            }
          } else {
            settings.updateTranslationSlot('secondary', null);
          }
        }
      },
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

  Widget _buildSelectorBar(AppThemeColors colors, List<String> surahIds) {
    return Container(
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
                      : currentIndex.clamp(0, verses.length - 1).toInt();
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
    );
  }

  Widget _buildProfileCountdownBar(
    AppThemeColors colors,
    LocalReadingProfile profile,
    ProgressProvider progressProv,
  ) {
    final currentIndex = progressProv.lastVerseIndex;
    final currentVerse = currentIndex >= 0 && currentIndex < verses.length
        ? toVerseRef(verses[currentIndex].surahId, verses[currentIndex].id)
        : profile.current;
    final totalAyahs = _profileTotalAyahs(profile);
    final readPosition = _profileReadPosition(profile, currentVerse);
    final remaining = totalAyahs <= 0
        ? 0
        : (totalAyahs - readPosition + 1).clamp(1, totalAyahs).toInt();

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.borderSoft)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.borderSoft),
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        child: Row(
          children: [
            Icon(
              Icons.hourglass_bottom_rounded,
              color: colors.primary,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${profile.name} - ${profile.start.verseKey} to ${profile.target!.verseKey}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: colors.textStrong,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${_ayahLeftLabel(remaining)} - $readPosition / $totalAyahs',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: colors.foreground,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
                final progressProfile = _progressProfile(localReading);
                final profileName = progressProfile?.name ?? 'Free Read';
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
          child: Consumer2<LocalReadingProvider, ProgressProvider>(
            builder: (context, localReading, progressProv, child) {
              final progressProfile = _progressProfile(localReading);
              if (_isBoundedCreatedProfile(progressProfile)) {
                return _buildProfileCountdownBar(
                  colors,
                  progressProfile!,
                  progressProv,
                );
              }
              return _buildSelectorBar(colors, surahIds);
            },
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

                final localReading = Provider.of<LocalReadingProvider>(
                  context,
                  listen: false,
                );
                final progressProfile = _progressProfile(localReading);
                final card = VerseCard(
                  key: ValueKey('${verses[index].surahId}_${verses[index].id}'),
                  verse: verses[index],
                  repository: widget.repository,
                  index: index,
                  progressProfileId: progressProfile?.id,
                  useExplicitProgressProfile: true,
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
                              final progressProfile = _progressProfile(
                                localReading,
                              );
                              final currentIndex = progressProv.lastVerseIndex;
                              if (progressProfile != null &&
                                  currentIndex >= 0 &&
                                  currentIndex < verses.length) {
                                final currentVerse = verses[currentIndex];
                                final verseRef = toVerseRef(
                                  currentVerse.surahId,
                                  currentVerse.id,
                                );

                                await localReading.updateProfileProgress(
                                  progressProfile.id,
                                  verseRef,
                                  context: context,
                                );
                                await localReading.addRecentReading(
                                  verse: verseRef,
                                  profileId: progressProfile.id,
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
