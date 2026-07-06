import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
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
  late final PageController _versePageController;
  bool _isProgrammaticPageMove = false;
  double _edgeOverscroll = 0;

  @override
  void initState() {
    super.initState();
    _versePageController = PageController();
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
    _versePageController.dispose();
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

  _ThaiThemeSection? _getActiveTheme(int verseNumber) {
    final surah = int.tryParse(_currentSurah);
    if (surah == null) return null;

    final themes = _themeSectionsBySurah[surah];
    if (themes == null || themes.isEmpty) return null;

    int activeStartVerse = -1;
    for (final startVerse in themes.keys) {
      if (startVerse <= verseNumber && startVerse > activeStartVerse) {
        activeStartVerse = startVerse;
      }
    }

    if (activeStartVerse == -1) return null;
    final activeTheme = themes[activeStartVerse]!;

    // Ensure verseNumber is within the end verse of this theme
    final rangeParts = activeTheme.verseRange.split('-');
    if (rangeParts.isNotEmpty) {
      final endVerseStr = rangeParts.length > 1 ? rangeParts[1] : rangeParts[0];
      final endVerse =
          int.tryParse(endVerseStr.trim().replaceAll(RegExp(r'[^0-9]'), '')) ??
          9999;
      if (verseNumber > endVerse) return null;
    }

    return activeTheme;
  }

  bool shouldShowHeader(int verseNumber) {
    return _getActiveTheme(verseNumber) != null;
  }

  String getHeaderTitle(int verseNumber) {
    final section = _getActiveTheme(verseNumber);
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
        if (!mounted || verses.isEmpty) return;
        _isProgrammaticPageMove = true;
        if (_versePageController.hasClients) {
          _versePageController.jumpToPage(safeTargetIndex);
        }
        _isProgrammaticPageMove = false;
        provider.setVerseIndexAndScroll(safeTargetIndex);
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

  String? _adjacentVisibleSurahId(int direction) {
    final currentSurahInt = int.tryParse(_currentSurah);
    if (currentSurahInt == null || direction == 0) return null;

    var candidate = currentSurahInt + direction.sign;
    while (candidate >= 1 && candidate <= 114) {
      final surahId = candidate.toString();
      if (_activeProfileHasVisibleVersesInSurah(surahId)) return surahId;
      candidate += direction.sign;
    }
    return null;
  }

  Future<void> _goToAdjacentSurah(int direction) async {
    final surahId = _adjacentVisibleSurahId(direction);
    if (surahId == null) return;

    final completedSurahId = _currentSurah;
    final completedSurahName = widget.repository.getSurahName(_currentSurah);
    final targetVerses = _visibleVersesForActiveProfile(
      surahId,
      widget.repository.getSurahVerses(surahId),
    );
    final targetVerseId = direction.isNegative && targetVerses.isNotEmpty
        ? targetVerses.last.id
        : null;

    await _loadSurah(surahId, jumpToVerseId: targetVerseId);
    if (!mounted) return;

    final surahName = widget.repository.getSurahName(surahId);
    final ayahCount = widget.repository.getSurahVerses(surahId).length;
    if (direction > 0) {
      _showSurahCompletionDialog(
        completedSurahId: completedSurahId,
        completedSurahName: completedSurahName,
        nextSurahId: surahId,
        nextSurahName: surahName,
        nextAyahCount: ayahCount,
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Surah $surahId: $surahName - $ayahCount ayat'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showSurahCompletionDialog({
    required String completedSurahId,
    required String completedSurahName,
    required String nextSurahId,
    required String nextSurahName,
    required int nextAyahCount,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return _SurahCompletionDialog(
          completedSurahId: completedSurahId,
          completedSurahName: completedSurahName,
          nextSurahId: nextSurahId,
          nextSurahName: nextSurahName,
          nextAyahCount: nextAyahCount,
        );
      },
    );
  }

  void _selectVerseIndex(int index) {
    _goToVerseIndex(index);
  }

  Future<void> _goToVerseIndex(int index) async {
    if (verses.isEmpty) return;
    final provider = Provider.of<ProgressProvider>(context, listen: false);
    final targetIndex = index.clamp(0, verses.length - 1).toInt();

    _isProgrammaticPageMove = true;
    try {
      await provider.setVerseIndexAndScroll(targetIndex);
      if (_versePageController.hasClients) {
        await _versePageController.animateToPage(
          targetIndex,
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeInOutCubic,
        );
      }
    } finally {
      _isProgrammaticPageMove = false;
    }
  }

  void _handleVersePageChanged(int index, ProgressProvider provider) {
    if (_isProgrammaticPageMove || provider.isChangingSurah) return;
    if (index >= verses.length) return;

    final currentIndex = provider.lastVerseIndex;
    final delta = index - currentIndex;
    final targetIndex = delta.abs() <= 1
        ? index
        : (currentIndex + delta.sign).clamp(0, verses.length - 1).toInt();

    provider.setVerseIndexAndScroll(targetIndex);
    if (targetIndex != index && _versePageController.hasClients) {
      _isProgrammaticPageMove = true;
      _versePageController
          .animateToPage(
            targetIndex,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() => _isProgrammaticPageMove = false);
    }
  }

  bool _handleVerseEdgeScroll(ScrollNotification notification, int index) {
    if (_isProgrammaticPageMove || index >= verses.length) return false;

    if (notification is ScrollStartNotification) {
      _edgeOverscroll = 0;
      return false;
    }

    if (notification is OverscrollNotification) {
      _edgeOverscroll += notification.overscroll;
      return false;
    }

    if (notification is ScrollEndNotification) {
      const threshold = 48.0;
      final currentIndex = Provider.of<ProgressProvider>(
        context,
        listen: false,
      ).lastVerseIndex;
      final shouldGoNext =
          _edgeOverscroll > threshold && currentIndex < verses.length - 1;
      final shouldGoNextSurah =
          _edgeOverscroll > threshold &&
          currentIndex == verses.length - 1 &&
          _adjacentVisibleSurahId(1) != null;
      final shouldGoPrevious = _edgeOverscroll < -threshold && currentIndex > 0;
      final shouldGoPreviousSurah =
          _edgeOverscroll < -threshold &&
          currentIndex == 0 &&
          _adjacentVisibleSurahId(-1) != null;

      _edgeOverscroll = 0;
      if (shouldGoNext) {
        _goToVerseIndex(currentIndex + 1);
      } else if (shouldGoNextSurah) {
        _goToAdjacentSurah(1);
      } else if (shouldGoPrevious) {
        _goToVerseIndex(currentIndex - 1);
      } else if (shouldGoPreviousSurah) {
        _goToAdjacentSurah(-1);
      }
    }

    return false;
  }

  Widget _buildFocusedVersePage({
    required int index,
    required ProgressProvider provider,
    required SettingsProvider settings,
    required bool isDark,
  }) {
    if (index == verses.length) {
      return NotificationListener<ScrollNotification>(
        onNotification: (notification) =>
            _handleVerseEdgeScroll(notification, index),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 48).clamp(
                    0.0,
                    double.infinity,
                  ),
                ),
                child: Align(
                  alignment: const Alignment(0.0, -0.7),
                  child: _buildCompletionCard(
                    context,
                    provider,
                    settings,
                    isDark,
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    final localReading = Provider.of<LocalReadingProvider>(
      context,
      listen: false,
    );
    final progressProfile = _progressProfile(localReading);
    final currentVerse = verses[index];
    final verseNumber = int.tryParse(currentVerse.id);
    final showThemeHeader =
        verseNumber != null && shouldShowHeader(verseNumber);

    final card = VerseCard(
      key: ValueKey('${currentVerse.surahId}_${currentVerse.id}'),
      verse: currentVerse,
      repository: widget.repository,
      index: index,
      progressProfileId: progressProfile?.id,
      useExplicitProgressProfile: true,
    );

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) =>
          _handleVerseEdgeScroll(notification, index),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 48).clamp(
                  0.0,
                  double.infinity,
                ),
              ),
              child: Align(
                alignment: const Alignment(0.0, -0.7),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (index == 0 && _currentSurah != '9')
                      _buildBismillahBanner(settings, isDark),
                    if (index == 0)
                      _buildObjectivesBanner(_currentSurah, settings, isDark),
                    if (showThemeHeader)
                      _buildThemeHeader(settings, isDark, verseNumber),
                    card,
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
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
                        context.tr('display_settings'),
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Dark Mode Toggle
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        title: Text(
                          context.tr('dark_mode'),
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
                        context.tr('reading_mode'),
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
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius,
                            ),
                            borderSide: BorderSide(
                              color: colorScheme.outline,
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius,
                            ),
                            borderSide: BorderSide(
                              color: colorScheme.outline,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius,
                            ),
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
                              style: GoogleFonts.inter(
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: SettingsProvider.translationOnlyMode,
                            child: Text(
                              context.tr('translation_only'),
                              style: GoogleFonts.inter(
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: SettingsProvider.quranTranslationMode,
                            child: Text(
                              context.tr('quran_translation'),
                              style: GoogleFonts.inter(
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) settings.setReadingDisplayMode(val);
                        },
                      ),

                      const Divider(height: 32),
                      Text(
                        context.tr('translations'),
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
                          border: Border.all(
                            color: colorScheme.outline,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildTranslationCheckbox(
                              context,
                              settings,
                              'thai_v3',
                              context.tr('thai_v3'),
                              colorScheme,
                            ),
                            Divider(height: 1, color: colorScheme.outline),
                            _buildTranslationCheckbox(
                              context,
                              settings,
                              'thai_v2',
                              context.tr('thai_v2'),
                              colorScheme,
                            ),
                            Divider(height: 1, color: colorScheme.outline),
                            _buildTranslationCheckbox(
                              context,
                              settings,
                              'english',
                              context.tr('english'),
                              colorScheme,
                            ),

                            ...transManager.downloadedTranslations.map((t) {
                              final idStr = t['id'].toString();
                              return Column(
                                children: [
                                  Divider(
                                    height: 1,
                                    color: colorScheme.outline,
                                  ),
                                  _buildTranslationCheckbox(
                                    context,
                                    settings,
                                    idStr,
                                    t['name'],
                                    colorScheme,
                                    subtitleText:
                                        '${t['language']} - ${t['author']}',
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
                                context.tr('arabic_font_size'),
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
                              overlayColor: colorScheme.primary.withOpacity(
                                0.1,
                              ),
                            ),
                            child: Slider(
                              value: settings.arabicFontSize,
                              min: 18.0,
                              max: 48.0,
                              onChanged: (val) =>
                                  settings.setArabicFontSize(val),
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
                                context.tr('translation_font_size'),
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
                              overlayColor: colorScheme.primary.withOpacity(
                                0.1,
                              ),
                            ),
                            child: Slider(
                              value: settings.translationFontSize,
                              min: 12.0,
                              max: 32.0,
                              onChanged: (val) =>
                                  settings.setTranslationFontSize(val),
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
            ? context.tr('primary')
            : isSecondary
            ? context.tr('secondary')
            : (subtitleText ?? ''),
        style: GoogleFonts.inter(
          color: isPrimary
              ? colorScheme.primary
              : isSecondary
              ? Colors.blue
              : colorScheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: (isPrimary || isSecondary)
              ? FontWeight.bold
              : FontWeight.normal,
        ),
      ),
      value: isChecked,
      activeColor: colorScheme.primary,
      onChanged: (val) {
        if (val == true) {
          if (settings.secondaryTranslationId == null &&
              settings.primaryTranslationId != id) {
            settings.updateTranslationSlot('secondary', id);
          } else {
            settings.updateTranslationSlot('secondary', id);
          }
        } else {
          if (isPrimary) {
            if (settings.secondaryTranslationId != null) {
              settings.updateTranslationSlot(
                'primary',
                settings.secondaryTranslationId,
              );
              settings.updateTranslationSlot('secondary', null);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.tr('at_least_one_active'))),
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
                  style: GoogleFonts.notoSansThai(
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
            style: GoogleFonts.notoSansThai(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.45,
              color: colors.textStrong,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'ที่มา: ${objective.source}',
            style: GoogleFonts.notoSansThai(
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
        style: GoogleFonts.notoSansThai(
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
                final surahAyahCount = widget.repository
                    .getSurahVerses(_currentSurah)
                    .length;
                final surahProgressLabel = surahAyahCount > 0
                    ? '$activeVerseId/$surahAyahCount'
                    : activeVerseId;
                return Text(
                  '$profileName - $_currentSurah:$activeVerseId - $surahProgressLabel',
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
          : PageView.builder(
              controller: _versePageController,
              scrollDirection: Axis.vertical,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: verses.length + 1,
              onPageChanged: (index) =>
                  _handleVersePageChanged(index, provider),
              itemBuilder: (context, index) => _buildFocusedVersePage(
                index: index,
                provider: provider,
                settings: settings,
                isDark: isDark,
              ),
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
                  final hasPrevSurah =
                      !hasPrev && _adjacentVisibleSurahId(-1) != null;
                  final hasNextSurah =
                      !hasNext && _adjacentVisibleSurahId(1) != null;

                  return Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _VerseReaderActionButton(
                          icon: Icons.keyboard_arrow_down_rounded,
                          label: context.tr('previous_ayah'),
                          compact: true,
                          onPressed: hasPrev
                              ? () {
                                  _goToVerseIndex(currentIndex - 1);
                                }
                              : hasPrevSurah
                              ? () {
                                  _goToAdjacentSurah(-1);
                                }
                              : null,
                          backgroundColor: colors.primaryLight,
                          foregroundColor: primaryColor,
                          disabledBackgroundColor: colors.surfaceMuted,
                          disabledForegroundColor: colors.foreground.withValues(
                            alpha: 0.35,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 5,
                        child: _VerseReaderActionButton(
                          icon: Icons.save_outlined,
                          label: context.tr('save_progress'),
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
                              await localReading
                                  .flushPendingRecentReadingSync();
                              await localReading.flushPendingReadingStateSync();
                              await localReading.flushPendingProfileSyncs();
                            }
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          },
                          backgroundColor: primaryColor,
                          foregroundColor: colors.textInverse,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: _VerseReaderActionButton(
                          icon: Icons.keyboard_arrow_up_rounded,
                          label: context.tr('next_ayah'),
                          compact: true,
                          onPressed: hasNext
                              ? () {
                                  _goToVerseIndex(currentIndex + 1);
                                }
                              : hasNextSurah
                              ? () {
                                  _goToAdjacentSurah(1);
                                }
                              : null,
                          backgroundColor: colors.primaryLight,
                          foregroundColor: primaryColor,
                          disabledBackgroundColor: colors.surfaceMuted,
                          disabledForegroundColor: colors.foreground.withValues(
                            alpha: 0.35,
                          ),
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
            style: GoogleFonts.notoSansThai(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.textStrong,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'คุณอ่านมาถึงอายะฮฺสุดท้ายของซูเราะฮฺ $_currentSurah แล้ว ทำเครื่องหมายเพื่อบันทึกสถิติของคุณ',
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSansThai(
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
                      style: GoogleFonts.notoSansThai(color: Colors.white),
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
                style: GoogleFonts.notoSansThai(
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
                          style: GoogleFonts.notoSansThai(
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
                          style: GoogleFonts.notoSansThai(
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

class _VerseReaderActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? disabledBackgroundColor;
  final Color? disabledForegroundColor;
  final bool compact;

  const _VerseReaderActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
    this.disabledBackgroundColor,
    this.disabledForegroundColor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 16.0 : 18.0;
    final fontSize = compact ? 10.0 : 11.0;
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        disabledBackgroundColor: disabledBackgroundColor,
        disabledForegroundColor: disabledForegroundColor,
        elevation: 0,
        minimumSize: const Size(0, 44),
        padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: Icon(icon, size: iconSize),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SurahCompletionDialog extends StatefulWidget {
  final String completedSurahId;
  final String completedSurahName;
  final String nextSurahId;
  final String nextSurahName;
  final int nextAyahCount;

  const _SurahCompletionDialog({
    required this.completedSurahId,
    required this.completedSurahName,
    required this.nextSurahId,
    required this.nextSurahName,
    required this.nextAyahCount,
  });

  @override
  State<_SurahCompletionDialog> createState() => _SurahCompletionDialogState();
}

class _SurahCompletionDialogState extends State<_SurahCompletionDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ribbonColors = [
      colorScheme.primary,
      colorScheme.secondary,
      colorScheme.tertiary,
      colorScheme.primaryContainer,
      colorScheme.secondaryContainer,
    ];

    return Dialog(
      elevation: 0,
      backgroundColor: colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _RibbonFallPainter(
                      progress: _controller.value,
                      colors: ribbonColors,
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: colorScheme.onPrimaryContainer,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Surah completed',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Congratulations, you completed Surah ${widget.completedSurahId}: ${widget.completedSurahName}.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Now reading',
                          style: textTheme.labelLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Surah ${widget.nextSurahId}: ${widget.nextSurahName}',
                          textAlign: TextAlign.center,
                          style: textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.nextAyahCount} ayat',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Continue'),
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
}

class _RibbonFallPainter extends CustomPainter {
  final double progress;
  final List<Color> colors;

  const _RibbonFallPainter({required this.progress, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    if (colors.isEmpty || size.isEmpty) return;

    for (var index = 0; index < 28; index++) {
      final lane = (index * 37) % 100 / 100;
      final speed = 0.55 + ((index * 11) % 40) / 100;
      final phase = (progress * speed + index * 0.071) % 1.0;
      final xWave = math.sin((progress * math.pi * 2) + index) * 16;
      final x = (lane * size.width) + xWave;
      final y = (phase * (size.height + 96)) - 64;
      final width = 6.0 + (index % 3) * 2;
      final height = 16.0 + (index % 4) * 4;
      final angle = progress * math.pi * 2 + index;
      final color = colors[index % colors.length].withValues(alpha: 0.68);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: width, height: height),
        const Radius.circular(2),
      );
      canvas.drawRRect(rect, Paint()..color = color);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _RibbonFallPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.colors != colors;
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
