import 'dart:convert';
import 'dart:math' as math;
import 'dart:async';

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
import '../providers/thai_text_protection_provider.dart';
import '../models/verse.dart';
import '../models/tadabbur_note.dart';
import '../services/remote_content_service.dart';
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
  final String? shortcutId;

  const ReadingScreen({
    super.key,
    required this.repository,
    this.initialSurah,
    this.initialVerseIndex,
    this.initialVerseId,
    this.openSettingsPanel = false,
    this.saveToFreeReadOnly = false,
    this.shortcutId,
  });

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _TranslationOption {
  final String id;
  final int? apiId;
  final String name;
  final String? nameTh;
  final String author;
  final String language;

  const _TranslationOption({
    required this.id,
    required this.apiId,
    required this.name,
    this.nameTh,
    required this.author,
    required this.language,
  });

  String displayName(String appLanguage) {
    if (appLanguage == 'th' && nameTh != null && nameTh!.isNotEmpty) {
      return nameTh!;
    }
    return name;
  }
}

class _ReadingScreenState extends State<ReadingScreen> {
  List<Verse> verses = [];
  String _currentSurah = '1';
  bool _isLoading = true;
  bool _isMenuVisible = true;
  Map<int, Map<int, _ThaiThemeSection>> _themeSectionsBySurah = {};
  Map<String, _SurahObjective> _surahObjectives = {};
  Map<String, _SurahObjective> _surahObjectivesEn = {};
  late final PageController _versePageController;
  late final VerseCardController _verseCardController;
  bool _isProgrammaticPageMove = false;
  Timer? _menuAutoHideTimer;

  void _startAutoHideTimer() {
    _menuAutoHideTimer?.cancel();
    _menuAutoHideTimer = Timer(const Duration(seconds: 7), () {
      if (mounted && _isMenuVisible) {
        setState(() {
          _isMenuVisible = false;
        });
      }
    });
  }

  void _cancelAutoHideTimer() {
    _menuAutoHideTimer?.cancel();
  }

  @override
  void initState() {
    super.initState();
    _verseCardController = VerseCardController();
    _versePageController = PageController();
    _initData();

    _startAutoHideTimer();

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
    _verseCardController.dispose();
    _versePageController.dispose();
    _menuAutoHideTimer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  Map<String, String>? _currentReadingResult() {
    if (verses.isEmpty) return null;
    final provider = Provider.of<ProgressProvider>(context, listen: false);
    final localReading = Provider.of<LocalReadingProvider>(
      context,
      listen: false,
    );
    final progressProfile = _progressProfile(localReading);
    final index = provider.lastVerseIndex.clamp(0, verses.length - 1);
    final verse = verses[index];
    return {
      'surahId': verse.surahId,
      'verseId': verse.id,
      if (progressProfile != null) 'profileId': progressProfile.id,
    };
  }

  void _closeReader() {
    Navigator.pop(context, _currentReadingResult());
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
      final jsonString = await RemoteContentService.instance.loadString(
        contentKey: RemoteContentKey.quranThemes,
        bundledAssetPath: 'assets/reconciled_thai_quran_themes.json',
      );
      final decoded = jsonDecode(jsonString);
      if (decoded is! List) return;

      final sectionsBySurah = <int, Map<int, _ThaiThemeSection>>{};
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) continue;

        final surah = _parseFlexibleInt(item['surah']);
        final verseRange = item['verse_range']?.toString().trim();
        final themeTh = item['theme_th']?.toString().trim();
        final themeEn = item['theme_en']?.toString().trim();
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
            _ThaiThemeSection(themeTh: themeTh, themeEn: themeEn, verseRange: verseRange);
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

    try {
      final jsonStringEn = await rootBundle.loadString(
        'assets/surah_summary_en_exact.json',
      );
      final decodedEn = jsonDecode(jsonStringEn);
      if (decodedEn is! Map<String, dynamic>) return;

      final objectivesEn = <String, _SurahObjective>{};
      decodedEn.forEach((surahId, value) {
        if (value is! Map<String, dynamic>) return;

        final text = value['text']?.toString().trim();
        final source = value['source']?.toString().trim();
        if (text == null || text.isEmpty || source == null || source.isEmpty) {
          return;
        }

        objectivesEn[surahId] = _SurahObjective(text: text, source: source);
      });

      _surahObjectivesEn = objectivesEn;
    } catch (error) {
      debugPrint('Unable to load English surah objectives: $error');
    }
  }

  bool _isNonThaiPrimary(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context, listen: true);
    final primaryId = settings.primaryTranslationId;
    if (primaryId == 'thai_v3' || primaryId == 'thai_v2') return false;
    
    final transManager = Provider.of<TranslationManagerProvider>(context, listen: false);
    final customId = int.tryParse(primaryId);
    if (customId != null) {
      final translation = transManager.downloadedTranslations.firstWhere(
        (t) => t['id'] == customId,
        orElse: () => <String, dynamic>{},
      );
      final lang = translation['language']?.toString().toLowerCase();
      if (lang == 'th' || lang == 'thai') {
        return false;
      }
    }
    return true;
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

  String getHeaderTitle(BuildContext context, int verseNumber) {
    final section = _getActiveTheme(verseNumber);
    if (section == null) return '';
    final isNonThai = _isNonThaiPrimary(context);
    final themeText = (isNonThai && section.themeEn != null && section.themeEn!.isNotEmpty) 
        ? section.themeEn! 
        : section.themeTh;
    final protectedTheme = Provider.of<ThaiTextProtectionProvider>(
      context,
      listen: false,
    ).protect(themeText);
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final ayahLabel = settings.languageCode == 'th' ? 'อายะฮฺ' : 'Ayah';
    return '$protectedTheme ($ayahLabel ${section.verseRange})';
  }

  Future<void> _loadSurah(
    String surahId, {
    int jumpToIndex = 0,
    String? jumpToVerseId,
  }) async {
    _verseCardController.stopAudio?.call();
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
    final isThai = !_isNonThaiPrimary(context);
    final completedSurahName = widget.repository.getSurahName(_currentSurah, isThai: isThai);
    final targetVerses = _visibleVersesForActiveProfile(
      surahId,
      widget.repository.getSurahVerses(surahId),
    );
    final targetVerseId = direction.isNegative && targetVerses.isNotEmpty
        ? targetVerses.last.id
        : null;

    await _loadSurah(surahId, jumpToVerseId: targetVerseId);
    if (!mounted) return;

    final surahName = widget.repository.getSurahName(surahId, isThai: isThai);
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

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final isThaiLang = settings.languageCode == 'th';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isThaiLang
              ? 'สูเราะฮ์ $surahId: ${surahName.replaceFirst(RegExp(r'^\d+\.\s*'), '')} - $ayahCount อายะฮ์'
              : 'Surah $surahId: ${surahName.replaceFirst(RegExp(r'^\d+\.\s*'), '')} - $ayahCount verses',
        ),
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
    _verseCardController.stopAudio?.call();
    final provider = Provider.of<ProgressProvider>(context, listen: false);
    final targetIndex = index.clamp(0, verses.length).toInt();

    _isProgrammaticPageMove = true;
    try {
      await provider.setVerseIndexAndScroll(targetIndex);
      if (_versePageController.hasClients) {
        await _versePageController.animateToPage(
          targetIndex,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOutCubic,
        );
      }
    } finally {
      _isProgrammaticPageMove = false;
    }
  }

  void _handleVersePageChanged(int index, ProgressProvider provider) {
    _verseCardController.stopAudio?.call();
    if (index == verses.length) {
      _verseCardController.updateState(
        isAudioPlaying: false,
        isAudioLoading: false,
        showTafsirBox: false,
        showAuditBox: false,
        hasTafsir: false,
        hasCommunityNotes: false,
        communityNotesFuture: null,
      );
    }
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
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeInOutCubic,
          )
          .whenComplete(() => _isProgrammaticPageMove = false);
    }
  }

  bool _handleVerseEdgeScroll(ScrollNotification notification, int index) {
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
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
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

    final card = VerseCard(
      key: ValueKey('${currentVerse.surahId}_${currentVerse.id}'),
      verse: currentVerse,
      repository: widget.repository,
      index: index,
      progressProfileId: progressProfile?.id,
      useExplicitProgressProfile: true,
      controller: _verseCardController,
    );

    final verseNumber = int.tryParse(currentVerse.id) ?? -1;
    final showThemeHeader =
        shouldShowHeader(verseNumber);

    final pageScrollableBody = NotificationListener<ScrollNotification>(
      onNotification: (notification) =>
          _handleVerseEdgeScroll(notification, index),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
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
                    card,
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    return Column(
      children: [
        if (showThemeHeader)
          Padding(
            padding: const EdgeInsets.only(left: 32, right: 32, top: 12),
            child: AnimatedBuilder(
              animation: _versePageController,
              builder: (context, child) {
                double page = _versePageController.hasClients
                    ? _versePageController.page ?? index.toDouble()
                    : index.toDouble();
                double width = MediaQuery.of(context).size.width;
                double offsetX = 0.0;

                int leftPage = page.floor();
                int rightPage = page.ceil();

                String getThemeForIndex(int i) {
                  if (i < 0 || i >= verses.length) return '';
                  final v = verses[i];
                  final vNum = int.tryParse(v.id);
                  if (vNum != null && shouldShowHeader(vNum)) {
                    return getHeaderTitle(context, vNum);
                  }
                  return '';
                }

                String themeLeft = getThemeForIndex(leftPage);
                String themeRight = getThemeForIndex(rightPage);

                // If both transitioning pages share the exact same theme range,
                // counteract horizontal page sliding completely so it stays pinned.
                if (themeLeft.isNotEmpty && themeLeft == themeRight) {
                  offsetX = -(index.toDouble() - page) * width;
                }

                return Transform.translate(
                  offset: Offset(offsetX, 0.0),
                  child: _buildThemeHeader(settings, isDark, verseNumber),
                );
              },
            ),
          ),
        Expanded(child: pageScrollableBody),
      ],
    );
  }

  LocalReadingProfile? _progressProfile(LocalReadingProvider localReading) {
    if (widget.shortcutId != null) {
      return localReading.profileById(widget.shortcutId!);
    }
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
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (settings.languageCode == 'th') {
      return 'เหลืออีก $count อายะฮ์';
    }
    return count == 1 ? '1 ayah left' : '$count ayahs left';
  }

  void _showSettingsSheet() {
    _cancelAutoHideTimer();
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
                        style: GoogleFonts.notoSansThai(
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
                          style: GoogleFonts.notoSansThai(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        value: settings.isDarkMode,
                        activeThumbColor: colorScheme.primary,
                        onChanged: (val) => settings.toggleDarkMode(val),
                      ),
                      const SizedBox(height: 8),

                      // Word-by-Word Toggle
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        title: Text(
                          'แปลคำต่อคำ (Word by Word)',
                          style: GoogleFonts.notoSansThai(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          'แสดงความหมายทีละคำพร้อมแตะฟังเสียงอ่าน',
                          style: GoogleFonts.notoSansThai(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        value: settings.showWordByWord,
                        activeThumbColor: colorScheme.primary,
                        onChanged: (val) => settings.toggleShowWordByWord(val),
                      ),
                      const SizedBox(height: 8),



                      const Divider(height: 32),
                      Text(
                        context.tr('translations'),
                        style: GoogleFonts.notoSansThai(
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
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('primary'),
                                style: GoogleFonts.notoSansThai(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: settings.primaryTranslationId,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: colorScheme.surfaceContainerLow,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: colorScheme.outline, width: 1),
                                  ),
                                ),
                                items: _availableTranslationOptions(transManager).map((opt) {
                                  return DropdownMenuItem<String>(
                                    value: opt.id,
                                    child: Text(opt.displayName(settings.languageCode)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    settings.updateTranslationSlot('primary', val);
                                  }
                                },
                              ),
                              const SizedBox(height: 12),
                              Text(
                                context.tr('secondary'),
                                style: GoogleFonts.notoSansThai(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: settings.secondaryTranslationId ?? '',
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: colorScheme.surfaceContainerLow,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: colorScheme.outline, width: 1),
                                  ),
                                ),
                                items: [
                                  DropdownMenuItem<String>(
                                    value: '',
                                    child: Text(settings.languageCode == 'th' ? 'ไม่เลือก' : 'None'),
                                  ),
                                  ..._availableTranslationOptions(transManager).map((opt) {
                                    return DropdownMenuItem<String>(
                                      value: opt.id,
                                      child: Text(opt.displayName(settings.languageCode)),
                                    );
                                  }),
                                ],
                                onChanged: (val) {
                                  if (val == null || val.isEmpty) {
                                    settings.updateTranslationSlot('secondary', null);
                                  } else if (val != settings.primaryTranslationId) {
                                    settings.updateTranslationSlot('secondary', val);
                                  }
                                },
                              ),
                            ],
                          ),
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
                                style: GoogleFonts.notoSansThai(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                '${settings.arabicFontSize.round()} px',
                                style: GoogleFonts.notoSansThai(
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
                              overlayColor: colorScheme.primary.withValues(
                                alpha: 0.1,
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
                                style: GoogleFonts.notoSansThai(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                '${settings.translationFontSize.round()} px',
                                style: GoogleFonts.notoSansThai(
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
                              overlayColor: colorScheme.primary.withValues(
                                alpha: 0.1,
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
    ).then((_) {
      if (mounted && _isMenuVisible) {
        _startAutoHideTimer();
      }
    });
  }

  List<_TranslationOption> _availableTranslationOptions(TranslationManagerProvider transManager) {
    final downloaded = transManager.downloadedTranslations;

    final builtIns = <_TranslationOption>[
      _TranslationOption(
        id: 'thai_v3',
        apiId: null,
        name: 'ภาษาไทย',
        nameTh: 'ภาษาไทย',
        author: 'Society of Institutes and Universities',
        language: 'thai',
      ),
    ];

    final result = <String, _TranslationOption>{};
    for (final opt in builtIns) {
      result[opt.id] = opt;
    }
    for (final item in downloaded) {
      final id = item['id'].toString();
      result[id] = _TranslationOption(
        id: id,
        apiId: int.tryParse(id),
        name: item['name']?.toString() ?? 'Downloaded translation',
        author: item['author_name']?.toString() ?? '',
        language: item['language_name']?.toString() ?? '',
      );
    }

    final list = result.values.toList();
    list.sort((a, b) {
      final langCompare = _languageSortOrder(a.language).compareTo(_languageSortOrder(b.language));
      if (langCompare != 0) return langCompare;
      return a.name.compareTo(b.name);
    });
    return list;
  }

  int _languageSortOrder(String language) {
    return switch (language.toLowerCase()) {
      'thai' => 0,
      'english' => 1,
      'malay' => 2,
      _ => 99,
    };
  }

  Widget _buildBismillahBanner(SettingsProvider settings, bool isDark) {
    final colors = settings.getAppColors();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceMuted.withValues(alpha: 0.5)
            : colors.primaryLight.withValues(alpha: 0.5),
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
    final isNonThai = _isNonThaiPrimary(context);
    final objective = isNonThai ? _surahObjectivesEn[surahId] : _surahObjectives[surahId];
    if (objective == null) return const SizedBox.shrink();

    final colors = settings.getAppColors();
    final title = isNonThai ? "Surah's Objective" : 'เป้าหมายหลักของซูเราะฮ์';
    final sourceLabel = isNonThai ? 'Source: ' : 'ที่มา: ';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceMuted.withValues(alpha: 0.7)
            : colors.primaryLight.withValues(alpha: 0.55),
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
                  title,
                  locale: isNonThai ? null : const Locale('th', 'TH'),
                  style: isNonThai 
                    ? GoogleFonts.notoSansThai(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      )
                    : GoogleFonts.notoSansThai(
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
            locale: isNonThai ? null : const Locale('th', 'TH'),
            style: isNonThai
              ? GoogleFonts.notoSansThai(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                  color: colors.textStrong,
                )
              : GoogleFonts.notoSansThai(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                  color: colors.textStrong,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            '$sourceLabel${objective.source}',
            locale: isNonThai ? null : const Locale('th', 'TH'),
            style: isNonThai
              ? GoogleFonts.notoSansThai(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: colors.foreground.withValues(alpha: 0.72),
                )
              : GoogleFonts.notoSansThai(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: colors.foreground.withValues(alpha: 0.72),
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
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          colors.primary.withValues(alpha: isDark ? 0.12 : 0.06),
          colors.background,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Text(
        getHeaderTitle(context, verseNumber),
        locale: const Locale('th', 'TH'),
        style: GoogleFonts.notoSansThai(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          height: 1.45,
          color: colors.textStrong,
        ),
      ),
    );
  }

  Widget _buildAppBarTitle(
    BuildContext context,
    AppThemeColors colors,
    ProgressProvider progressProv,
    LocalReadingProfile? progressProfile,
  ) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final hasGoal = _isBoundedCreatedProfile(progressProfile);

    if (hasGoal) {
      final profile = progressProfile!;
      final currentIndex = progressProv.lastVerseIndex;
      final currentVerse = currentIndex >= 0 && currentIndex < verses.length
          ? toVerseRef(verses[currentIndex].surahId, verses[currentIndex].id)
          : profile.current;
      final totalAyahs = _profileTotalAyahs(profile);
      final readPosition = _profileReadPosition(profile, currentVerse);
      final remaining = totalAyahs <= 0
          ? 0
          : (totalAyahs - readPosition + 1).clamp(1, totalAyahs).toInt();

      final progressPercent = totalAyahs > 0
          ? ((readPosition / totalAyahs) * 100).clamp(0.0, 100.0).toInt()
          : 0;

      final theme = Theme.of(context);

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.gps_fixed, // target icon
              color: theme.colorScheme.primary,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    profile.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSansThai(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${profile.start.verseKey}-${profile.target!.verseKey} • ${_ayahLeftLabel(remaining)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSansThai(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$progressPercent%',
              style: GoogleFonts.notoSansThai(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w900,
                fontSize: 20, // covers two lines in height
                height: 1.0,
              ),
            ),
          ],
        ),
      );
    } else {
      final currentIndex = progressProv.lastVerseIndex;
      final safeIndex = verses.isEmpty
          ? 0
          : currentIndex.clamp(0, verses.length - 1).toInt();
      final surahIds = List.generate(114, (index) => (index + 1).toString());

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Theme(
            data: Theme.of(
              context,
            ).copyWith(canvasColor: Theme.of(context).colorScheme.surface),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _currentSurah,
                dropdownColor: Theme.of(context).colorScheme.surface,
                icon: Icon(
                  Icons.arrow_drop_down,
                  color: colors.primary,
                  size: 18,
                ),
                style: GoogleFonts.notoSansThai(
                  color: colors.textStrong,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
                items: surahIds
                    .map(
                      (id) => DropdownMenuItem(
                        value: id,
                        child: Text(widget.repository.getSurahName(id, isThai: !_isNonThaiPrimary(context))),
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
          Text(
            ' :',
            style: GoogleFonts.notoSansThai(
              color: colors.foreground.withValues(alpha: 0.5),
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 4),
          Theme(
            data: Theme.of(
              context,
            ).copyWith(canvasColor: Theme.of(context).colorScheme.surface),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: verses.isEmpty ? null : safeIndex,
                dropdownColor: Theme.of(context).colorScheme.surface,
                icon: Icon(
                  Icons.arrow_drop_down,
                  color: colors.primary,
                  size: 18,
                ),
                style: GoogleFonts.notoSansThai(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
                hint: Text(settings.languageCode == 'th' ? 'อายะฮ์' : 'Ayah', style: GoogleFonts.notoSansThai(fontSize: 15)),
                items: List.generate(
                  verses.length,
                  (index) => DropdownMenuItem(
                    value: index,
                    child: Text('${verses[index].id}'),
                  ),
                ),
                onChanged: (index) {
                  if (index != null) _selectVerseIndex(index);
                },
              ),
            ),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ProgressProvider>(context, listen: false);
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = settings.getPrimaryColor();
    final colors = settings.getAppColors();

    final localReading = Provider.of<LocalReadingProvider>(context);
    final progressProfile = _progressProfile(localReading);
    final hasGoal = _isBoundedCreatedProfile(progressProfile);
    final topMenuHeight = hasGoal ? 72.0 : 56.0;

    final systemUiOverlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiOverlayStyle,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _closeReader();
        },
        child: Scaffold(
          backgroundColor: colors.background,
          appBar: null,
          bottomNavigationBar: null,
          body: _isLoading
              ? Center(child: CircularProgressIndicator(color: primaryColor))
              : Listener(
                  onPointerDown: (_) {
                    if (_isMenuVisible) {
                      _startAutoHideTimer();
                    }
                  },
                  child: Stack(
                    children: [
                      // 1. Full Screen Reading Area
                      Positioned.fill(
                        child: SafeArea(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () {
                              setState(() {
                                _isMenuVisible = !_isMenuVisible;
                                if (_isMenuVisible) {
                                  _startAutoHideTimer();
                                } else {
                                  _cancelAutoHideTimer();
                                }
                              });
                            },
                            onHorizontalDragEnd: (details) {
                              final velocity = details.primaryVelocity;
                              if (velocity != null) {
                                final currentIndex = provider.lastVerseIndex;
                                final totalCount = verses.length;
                                final hasPrev = currentIndex > 0;
                                final hasNext = currentIndex < totalCount - 1;
                                final hasPrevSurah =
                                    !hasPrev &&
                                    _adjacentVisibleSurahId(-1) != null;
                                final hasNextSurah =
                                    !hasNext &&
                                    _adjacentVisibleSurahId(1) != null;

                                // Swiped left (velocity < 0) -> Next Ayah / Surah
                                if (velocity < -200) {
                                  if (hasNext) {
                                    _goToVerseIndex(currentIndex + 1);
                                    if (_isMenuVisible) {
                                      setState(() {
                                        _isMenuVisible = false;
                                      });
                                      _cancelAutoHideTimer();
                                    }
                                  } else if (hasNextSurah) {
                                    _goToAdjacentSurah(1);
                                    if (_isMenuVisible) {
                                      setState(() {
                                        _isMenuVisible = false;
                                      });
                                      _cancelAutoHideTimer();
                                    }
                                  }
                                }
                                // Swiped right (velocity > 0) -> Previous Ayah / Surah
                                else if (velocity > 200) {
                                  if (hasPrev) {
                                    _goToVerseIndex(currentIndex - 1);
                                    if (_isMenuVisible) {
                                      setState(() {
                                        _isMenuVisible = false;
                                      });
                                      _cancelAutoHideTimer();
                                    }
                                  } else if (hasPrevSurah) {
                                    _goToAdjacentSurah(-1);
                                    if (_isMenuVisible) {
                                      setState(() {
                                        _isMenuVisible = false;
                                      });
                                      _cancelAutoHideTimer();
                                    }
                                  }
                                }
                              }
                            },
                            child: AnimatedPadding(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              padding: EdgeInsets.only(
                                top: _isMenuVisible ? topMenuHeight : 0,
                                bottom: _isMenuVisible ? 128 : 64,
                              ),
                              child: Column(
                                children: [
                                  Consumer<ProgressProvider>(
                                    builder: (context, progressProv, child) {
                                      final currentIndex =
                                          progressProv.lastVerseIndex;
                                      if (currentIndex >= verses.length) {
                                        return const SizedBox.shrink();
                                      }
                                      final activeVerseId =
                                          (currentIndex >= 0 &&
                                              currentIndex < verses.length)
                                          ? verses[currentIndex].id
                                          : '1';
                                      final surahAyahCount = widget.repository
                                          .getSurahVerses(_currentSurah)
                                          .length;
                                      final surahName = widget.repository
                                          .getSurahName(_currentSurah, isThai: !_isNonThaiPrimary(context));
                                      final theme = Theme.of(context);

                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          left: 32,
                                          right: 32,
                                          top: 12,
                                          bottom: 4,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.menu_book_rounded,
                                              color: theme.colorScheme.primary,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '$surahName : $activeVerseId/$surahAyahCount',
                                              style: GoogleFonts.notoSansThai(
                                                color:
                                                    theme.colorScheme.onSurface,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  Expanded(
                                    child: PageView.builder(
                                      controller: _versePageController,
                                      scrollDirection: Axis.horizontal,
                                      reverse: false,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: verses.length + 1,
                                      onPageChanged: (index) =>
                                          _handleVersePageChanged(
                                            index,
                                            provider,
                                          ),
                                      itemBuilder: (context, index) =>
                                          _buildFocusedVersePage(
                                            index: index,
                                            provider: provider,
                                            settings: settings,
                                            isDark: isDark,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // 2. Animated Custom AppBar Container
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: IgnorePointer(
                          ignoring: !_isMenuVisible,
                          child: AnimatedSlide(
                            offset: _isMenuVisible
                                ? Offset.zero
                                : const Offset(0, -1),
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            child: Container(
                              color: colors.surfaceMuted,
                              child: SafeArea(
                                bottom: false,
                                child: AppBar(
                                  primary: false,
                                  backgroundColor: Colors.transparent,
                                  elevation: 0,
                                  toolbarHeight: topMenuHeight,
                                  centerTitle: false,
                                  leading: IconButton(
                                    icon: Icon(
                                      Icons.arrow_back,
                                      color: colors.textStrong,
                                    ),
                                    onPressed: _closeReader,
                                  ),
                                  title:
                                      Consumer2<
                                        LocalReadingProvider,
                                        ProgressProvider
                                      >(
                                        builder:
                                            (
                                              context,
                                              localReading,
                                              progressProv,
                                              child,
                                            ) {
                                              final progressProfile =
                                                  _progressProfile(
                                                    localReading,
                                                  );
                                              return _buildAppBarTitle(
                                                context,
                                                colors,
                                                progressProv,
                                                progressProfile,
                                              );
                                            },
                                      ),
                                  actions: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.settings_rounded,
                                        color: colors.primary,
                                      ),
                                      tooltip: 'Settings',
                                      onPressed: _showSettingsSheet,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // 3. Animated Bottom Bar Container (Previous, Save Progress, Next)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: IgnorePointer(
                          ignoring: !_isMenuVisible,
                          child: AnimatedSlide(
                            offset: _isMenuVisible
                                ? Offset.zero
                                : const Offset(0, 1),
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            child: Container(
                              color: colors.background,
                              child: SafeArea(
                                top: false,
                                child: Container(
                                  padding: const EdgeInsets.only(
                                    left: 16,
                                    right: 16,
                                    top: 10,
                                    bottom: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline
                                            .withValues(alpha: 0.2),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: Consumer2<LocalReadingProvider, ProgressProvider>(
                                    builder: (context, localReading, progressProv, child) {
                                      final currentIndex =
                                          progressProv.lastVerseIndex;
                                      final totalCount = verses.length;
                                      final hasPrev = currentIndex > 0;
                                      final hasNext =
                                          currentIndex < totalCount - 1;
                                      final hasPrevSurah =
                                          !hasPrev &&
                                          _adjacentVisibleSurahId(-1) != null;
                                      final hasNextSurah =
                                          !hasNext &&
                                          _adjacentVisibleSurahId(1) != null;
                                      final theme = Theme.of(context);

                                      return Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: _VerseReaderActionButton(
                                              icon: Icons
                                                  .keyboard_arrow_left_rounded,
                                              label: context.tr(
                                                'previous_ayah',
                                              ),
                                              compact: true,
                                              onPressed: hasPrev
                                                  ? () {
                                                      _goToVerseIndex(
                                                        currentIndex - 1,
                                                      );
                                                    }
                                                  : hasPrevSurah
                                                  ? () {
                                                      _goToAdjacentSurah(-1);
                                                    }
                                                  : null,
                                              backgroundColor: theme
                                                  .colorScheme
                                                  .surfaceContainerLow,
                                              foregroundColor:
                                                  theme.colorScheme.primary,
                                              disabledBackgroundColor: theme
                                                  .colorScheme
                                                  .surfaceContainerLow
                                                  .withValues(alpha: 0.5),
                                              disabledForegroundColor: theme
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.3),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            flex: 5,
                                            child: _VerseReaderActionButton(
                                              icon: Icons.save_outlined,
                                              label: context.tr(
                                                'save_progress',
                                              ),
                                              onPressed: () async {
                                                var progressProfile =
                                                     _progressProfile(
                                                       localReading,
                                                     );
                                                 final currentIndex =
                                                     progressProv.lastVerseIndex;
                                                 if (progressProfile != null &&
                                                     isShortcutProfile(progressProfile)) {
                                                   if (currentIndex >= 0 &&
                                                       currentIndex <
                                                           verses.length) {
                                                     final currentVerse =
                                                         verses[currentIndex];
                                                     if (currentVerse.surahId !=
                                                         progressProfile
                                                             .start.surahId) {
                                                       progressProfile = null;
                                                     }
                                                   }
                                                 }
                                                 if (progressProfile != null &&
                                                    currentIndex >= 0 &&
                                                    currentIndex <
                                                        verses.length) {
                                                  final currentVerse =
                                                      verses[currentIndex];
                                                  final verseRef = toVerseRef(
                                                    currentVerse.surahId,
                                                    currentVerse.id,
                                                  );

                                                  await localReading
                                                      .updateProfileProgress(
                                                        progressProfile.id,
                                                        verseRef,
                                                        context: context,
                                                      );
                                                  await localReading
                                                      .addRecentReading(
                                                        verse: verseRef,
                                                        profileId:
                                                            progressProfile.id,
                                                      );
                                                  await localReading
                                                      .flushPendingRecentReadingSync();
                                                  await localReading
                                                      .flushPendingReadingStateSync();
                                                  await localReading
                                                      .flushPendingProfileSyncs();
                                                }
                                                if (context.mounted) {
                                                  Navigator.pop(
                                                    context,
                                                    _currentReadingResult(),
                                                  );
                                                }
                                              },
                                              backgroundColor:
                                                  theme.colorScheme.primary,
                                              foregroundColor:
                                                  theme.colorScheme.onPrimary,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            flex: 2,
                                            child: _VerseReaderActionButton(
                                              icon: Icons
                                                  .keyboard_arrow_right_rounded,
                                              label: context.tr('next_ayah'),
                                              compact: true,
                                              iconOnRight: true,
                                              onPressed: hasNext
                                                  ? () {
                                                      _goToVerseIndex(
                                                        currentIndex + 1,
                                                      );
                                                    }
                                                  : hasNextSurah
                                                  ? () {
                                                      _goToAdjacentSurah(1);
                                                    }
                                                  : null,
                                              backgroundColor: theme
                                                  .colorScheme
                                                  .surfaceContainerLow,
                                              foregroundColor:
                                                  theme.colorScheme.primary,
                                              disabledBackgroundColor: theme
                                                  .colorScheme
                                                  .surfaceContainerLow
                                                  .withValues(alpha: 0.5),
                                              disabledForegroundColor: theme
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.3),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // 4. Floating Verse Action Menu (always visible, floats at bottom)
                      Consumer<ProgressProvider>(
                        builder: (context, progressProv, child) {
                          final currentIndex = progressProv.lastVerseIndex;
                          final hasActiveVerse =
                              currentIndex >= 0 && currentIndex < verses.length;

                          return AnimatedPositioned(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            bottom: hasActiveVerse
                                ? (_isMenuVisible ? 74 : 10)
                                : -100,
                            left: 16,
                            right: 16,
                            child: SafeArea(
                              top: false,
                              child: IgnorePointer(
                                ignoring: !hasActiveVerse,
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 200),
                                  opacity: hasActiveVerse ? 1.0 : 0.0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.background,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.blueGrey.shade800
                                                  .withValues(alpha: 0.4)
                                            : Colors.grey.shade200,
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: isDark ? 0.3 : 0.05,
                                          ),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: _buildFixedActionMenu(
                                      context,
                                      colors,
                                      isDark,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
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
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.blueGrey.shade800.withValues(alpha: 0.5)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
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
            locale: const Locale('th', 'TH'),
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
            locale: const Locale('th', 'TH'),
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
                      locale: const Locale('th', 'TH'),
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
                locale: const Locale('th', 'TH'),
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

              if (!hasPrevSurah && !hasNextSurah) {
                return const SizedBox.shrink();
              }

              return Row(
                children: [
                  if (hasPrevSurah)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _loadSurah(prevSurahId),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: BorderSide(
                            color: primaryColor.withValues(alpha: 0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          '⬅️ ซูเราะฮฺก่อนหน้า',
                          locale: const Locale('th', 'TH'),
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
                            color: primaryColor.withValues(alpha: 0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'ซูเราะฮฺถัดไป ➡️',
                          locale: const Locale('th', 'TH'),
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

  Widget _buildFixedActionMenu(
    BuildContext context,
    AppThemeColors colors,
    bool isDark,
  ) {
    return AnimatedBuilder(
      animation: _verseCardController,
      builder: (context, _) {
        final isThaiLang = Provider.of<SettingsProvider>(context, listen: false).languageCode == 'th';
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildMenuActionIcon(
              context: context,
              tooltip: isThaiLang ? 'คำอธิบายอย่างย่อ' : 'Short tafsir',
              icon: Icons.menu_book_outlined,
              active: _verseCardController.showTafsirBox,
              onPressed: _verseCardController.hasTafsir
                  ? _verseCardController.toggleTafsir
                  : null,
            ),
            _buildCommunityNotesMenuAction(context, _verseCardController),
            _buildMenuActionIcon(
              context: context,
              tooltip: isThaiLang ? 'คัดลอกข้อความอายะฮ์' : 'Copy verse text',
              icon: Icons.content_copy_rounded,
              active: false,
              onPressed: _verseCardController.copyText,
            ),
            _buildMenuActionIcon(
              context: context,
              tooltip: isThaiLang ? 'แชร์รูปภาพอายะฮ์' : 'Share verse image',
              icon: Icons.ios_share_rounded,
              active: false,
              onPressed: _verseCardController.shareImage,
            ),
            _buildMenuActionIcon(
              context: context,
              tooltip: isThaiLang ? 'รายงานข้อผิดพลาด' : 'Report error',
              icon: Icons.report_problem_outlined,
              active: _verseCardController.showAuditBox,
              onPressed: _verseCardController.toggleAudit,
            ),
            _buildMenuActionIcon(
              context: context,
              tooltip: _verseCardController.isAudioPlaying
                  ? (isThaiLang ? 'หยุดเล่นเสียงอายะฮ์' : 'Stop ayah audio')
                  : (isThaiLang ? 'เล่นเสียงอายะฮ์' : 'Play ayah audio'),
              icon: _verseCardController.isAudioLoading
                  ? Icons.hourglass_empty_rounded
                  : _verseCardController.isAudioPlaying
                  ? Icons.stop_circle_outlined
                  : Icons.play_arrow_rounded,
              active:
                  _verseCardController.isAudioPlaying ||
                  _verseCardController.isAudioLoading,
              onPressed: _verseCardController.playAudio,
            ),
          ],
        );
      },
    );
  }

  Widget _buildCommunityNotesMenuAction(
    BuildContext context,
    VerseCardController controller,
  ) {
    final isThaiLang = Provider.of<SettingsProvider>(context, listen: false).languageCode == 'th';
    if (controller.communityNotesFuture == null) {
      return _buildMenuActionIcon(
        context: context,
        tooltip: isThaiLang ? 'ไม่มีบันทึกจากชุมชน' : 'No community notes',
        icon: Icons.forum_outlined,
        onPressed: null,
      );
    }

    return FutureBuilder<List<TadabburNote>>(
      future: controller.communityNotesFuture,
      builder: (context, snapshot) {
        final notes = snapshot.data ?? const <TadabburNote>[];
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final hasNotes = notes.isNotEmpty;

        return _buildMenuActionIcon(
          context: context,
          tooltip: isLoading
              ? (isThaiLang ? 'กำลังโหลดบันทึก...' : 'Loading notes...')
              : (hasNotes
                    ? (isThaiLang ? 'ดูบันทึกจากชุมชน' : 'View community notes')
                    : (isThaiLang ? 'ไม่มีบันทึกจากชุมชนสำหรับอายะฮ์นี้' : 'No community notes for this ayah')),
          icon: isLoading
              ? Icons.hourglass_empty_rounded
              : Icons.forum_outlined,
          active: hasNotes,
          onPressed: hasNotes && !isLoading
              ? controller.showCommunityNotes
              : null,
        );
      },
    );
  }

  Widget _buildMenuActionIcon({
    required BuildContext context,
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
    bool active = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disabled = onPressed == null;

    return IconButton(
      tooltip: tooltip,
      iconSize: 22,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        backgroundColor: active && !disabled
            ? colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.08)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: active && !disabled
                ? colorScheme.primary.withValues(alpha: isDark ? 0.3 : 0.15)
                : Colors.transparent,
            width: 1,
          ),
        ),
      ),
      icon: Icon(
        icon,
        color: disabled
            ? colorScheme.onSurfaceVariant.withValues(alpha: 0.2)
            : active
            ? colorScheme.primary
            : colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
      ),
      onPressed: onPressed,
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
  final bool iconOnRight;

  const _VerseReaderActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
    this.disabledBackgroundColor,
    this.disabledForegroundColor,
    this.compact = false,
    this.iconOnRight = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 16.0 : 18.0;
    final fontSize = compact ? 10.0 : 11.0;

    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!iconOnRight) ...[
          Icon(icon, size: iconSize),
          SizedBox(width: compact ? 2 : 4),
        ],
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: GoogleFonts.notoSansThai(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (iconOnRight) ...[
          SizedBox(width: compact ? 2 : 4),
          Icon(icon, size: iconSize),
        ],
      ],
    );

    return FilledButton(
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
      child: child,
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

    final isThai = Provider.of<SettingsProvider>(context, listen: false).languageCode == 'th';

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
                    isThai ? 'อ่านสูเราะฮ์จบแล้ว' : 'Surah completed',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isThai
                        ? 'ขอแสดงความยินดี คุณอ่านสูเราะฮ์ ${widget.completedSurahId}: ${widget.completedSurahName.replaceFirst(RegExp(r'^\d+\.\s*'), '')} จบแล้ว'
                        : 'Congratulations, you completed Surah ${widget.completedSurahId}: ${widget.completedSurahName.replaceFirst(RegExp(r'^\d+\.\s*'), '')}.',
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
                          isThai ? 'กำลังอ่าน' : 'Now reading',
                          style: textTheme.labelLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isThai
                              ? 'สูเราะฮ์ ${widget.nextSurahId}: ${widget.nextSurahName.replaceFirst(RegExp(r'^\d+\.\s*'), '')}'
                              : 'Surah ${widget.nextSurahId}: ${widget.nextSurahName.replaceFirst(RegExp(r'^\d+\.\s*'), '')}',
                          textAlign: TextAlign.center,
                          style: textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isThai ? '${widget.nextAyahCount} อายะฮ์' : '${widget.nextAyahCount} verses',
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
                      child: Text(isThai ? 'อ่านต่อ' : 'Continue'),
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
  final String? themeEn;
  final String verseRange;

  const _ThaiThemeSection({required this.themeTh, this.themeEn, required this.verseRange});
}

class _SurahObjective {
  final String text;
  final String source;

  const _SurahObjective({required this.text, required this.source});
}
