import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:qcf_quran/qcf_quran.dart' as qcf;

import '../data/quran_foundation_repository.dart';
import '../data/quran_repository.dart';
import '../providers/local_reading_provider.dart';
import '../providers/mushaf_reading_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../shared/shared.dart';
import 'mushaf_reader_screen.dart';
import 'settings_screen.dart';

class BrowseScreen extends StatefulWidget {
  final QuranRepository repository;
  final AppThemeColors colors;

  final void Function(String surahId, String verseId) onOpen;
  final ValueChanged<int> onOpenPage;

  const BrowseScreen({
    super.key,
    required this.repository,
    required this.colors,

    required this.onOpen,
    required this.onOpenPage,
  });

  @override
  State<BrowseScreen> createState() => BrowseScreenState();
}

class BrowseScreenState extends State<BrowseScreen> {
  static const List<List<int>> _juzStarts = [
    [1, 1],
    [2, 142],
    [2, 253],
    [3, 93],
    [4, 24],
    [4, 148],
    [5, 82],
    [6, 111],
    [7, 88],
    [8, 41],
    [9, 93],
    [11, 6],
    [12, 53],
    [15, 1],
    [17, 1],
    [18, 75],
    [21, 1],
    [23, 1],
    [25, 21],
    [27, 56],
    [29, 46],
    [33, 31],
    [36, 28],
    [39, 32],
    [41, 47],
    [46, 1],
    [51, 31],
    [58, 1],
    [67, 1],
    [78, 1],
  ];

  static List<int>? getJuzEnd(int juzIndex) {
    if (juzIndex < 29) {
      final nextJuz = _juzStarts[juzIndex + 1];
      if (nextJuz[1] == 1) {
        return [nextJuz[0] - 1, 9999]; // To the end of the previous surah
      }
      return [nextJuz[0], nextJuz[1] - 1];
    }
    return [114, 6];
  }

  String _mode = 'surah';
  final TextEditingController _searchController = TextEditingController();
  final QuranFoundationRepository _foundationRepo = QuranFoundationRepository();
  QuranSearchResult? _apiSearchResult;
  bool _isApiSearching = false;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchQueryChanged(String query) {
    setState(() {});

    _debounceTimer?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _apiSearchResult = null;
        _isApiSearching = false;
      });
      return;
    }

    setState(() {
      _isApiSearching = true;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      final res = await _foundationRepo.searchQuran(query: query.trim());
      if (mounted && _searchController.text.trim() == query.trim()) {
        setState(() {
          _apiSearchResult = res;
          _isApiSearching = false;
        });
      }
    });
  }

  void _openMushafForVerse(String surahId, String verseId) {
    final sId = int.tryParse(surahId) ?? 1;
    final vId = int.tryParse(verseId) ?? 1;
    final pageNumber = qcf.getPageNumber(sId, vId);

    final mushafProvider = context.read<MushafReadingProvider>();
    mushafProvider.openUnifiedFreeRead().then((profile) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MushafReaderScreen(
            quranRepository: widget.repository,
            foundationRepository: _foundationRepo,
            profileId: profile.id,
            initialPage: pageNumber,
            initialHighlightVerseKey: '$sId:$vId',
          ),
        ),
      );
    });
  }

  void _setMode(String mode) {
    setState(() {
      _mode = mode;
    });
  }

  int _compareRefs(VerseRef left, VerseRef right) {
    final leftSurah = int.tryParse(left.surahId) ?? 0;
    final rightSurah = int.tryParse(right.surahId) ?? 0;
    if (leftSurah != rightSurah) return leftSurah.compareTo(rightSurah);

    final leftVerse = int.tryParse(left.verseId) ?? 0;
    final rightVerse = int.tryParse(right.verseId) ?? 0;
    return leftVerse.compareTo(rightVerse);
  }

  Set<String> _completedSurahs(LocalReadingProvider provider) {
    final completed = <String>{};
    final profiles = [...provider.activeProfiles, ...provider.archivedProfiles];

    for (final profile in profiles) {
      final target = profile.target;
      if (target == null || isFreeReadProfile(profile)) continue;
      if (_compareRefs(profile.current, target) < 0) continue;

      final startSurah = int.tryParse(profile.start.surahId);
      final targetSurah = int.tryParse(target.surahId);
      if (startSurah == null || targetSurah == null) continue;

      for (var surah = startSurah; surah <= targetSurah; surah++) {
        completed.add(surah.toString());
      }
    }

    return completed;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final settings = context.watch<SettingsProvider>();
    final query = _searchController.text.toLowerCase();
    final isSearching = query.isNotEmpty;
    final completedSurahs = _completedSurahs(
      context.watch<LocalReadingProvider>(),
    );

    // Build surah list with optional translation search
    final surahs =
        [
          for (var id = 1; id <= 114; id++)
            (
              id: id.toString(),
              name: widget.repository.getSurahName(id.toString()),
              count: widget.repository.getSurahVerses(id.toString()).length,
            ),
        ].where((surah) {
          return query.isEmpty ||
              surah.id.contains(query) ||
              surah.name.toLowerCase().contains(query);
        }).toList();

    final juz =
        [
          for (
            var index = 0;
            index < BrowseScreenState._juzStarts.length;
            index++
          )
            (
              id: index + 1,
              startSurah: BrowseScreenState._juzStarts[index][0].toString(),
              startAyah: BrowseScreenState._juzStarts[index][1].toString(),
            ),
        ].where((item) {
          final name = widget.repository
              .getSurahName(item.startSurah)
              .toLowerCase();
          return query.isEmpty ||
              item.id.toString().contains(query) ||
              'juz ${item.id}'.contains(query) ||
              name.contains(query);
        }).toList();

    final cleanQuery = query.replaceAll(RegExp(r'\D'), '');
    final int? queriedPage = int.tryParse(cleanQuery);

    final pages = [for (var page = 1; page <= 604; page++) page].where((page) {
      if (query.isEmpty) return true;
      if (queriedPage != null && page == queriedPage) return true;
      return page.toString().contains(query) ||
          'page $page'.contains(query) ||
          'หน้า $page'.contains(query);
    }).toList();

    // Collect verse translation matches
    final List<
      ({
        String surahName,
        String surahId,
        String verseId,
        String translationText,
      })
    >
    verseMatches = [];
    if (isSearching && query.length >= 2) {
      outer:
      for (var id = 1; id <= 114; id++) {
        final verses = widget.repository.getSurahVerses(id.toString());
        for (var verse in verses) {
          String primaryTranslation;
          if (settings.primaryTranslationId == 'thai_v2') {
            primaryTranslation = verse.thaiV2;
          } else if (settings.primaryTranslationId == 'english') {
            primaryTranslation = verse.english;
          } else {
            primaryTranslation = verse.thaiV3;
          }
          if (primaryTranslation.toLowerCase().contains(query) ||
              verse.thaiV3.toLowerCase().contains(query) ||
              verse.thaiV2.toLowerCase().contains(query) ||
              verse.english.toLowerCase().contains(query)) {
            verseMatches.add((
              surahName: widget.repository.getSurahName(verse.surahId),
              surahId: verse.surahId,
              verseId: verse.id,
              translationText: primaryTranslation,
            ));
            if (verseMatches.length >= 30) break outer;
          }
        }
      }
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('choose_surah'),
                          style: textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.tr('which_surah_to_read'),
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            SettingsScreen(repository: widget.repository),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(24),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.settings,
                        color: colorScheme.onSurface,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchQueryChanged,
                  decoration: InputDecoration(
                    hintText: context.tr('search_hint'),
                    hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 16.0, right: 8.0),
                      child: Icon(
                        Icons.search,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    suffixIcon: query.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: IconButton(
                              icon: Icon(
                                Icons.close,
                                size: 18,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchQueryChanged('');
                              },
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Popular Search Chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    'ความเมตตา', 'ความอดทน', 'การละหมาด', 'สวรรค์', 'นรก', 'ศรัทธา'
                  ].map((chip) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () {
                        _searchController.text = chip;
                        _onSearchQueryChanged(chip);
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _searchController.text == chip
                              ? colorScheme.primary
                              : colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '🔍 $chip',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _searchController.text == chip
                                ? colorScheme.onPrimary
                                : colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  )).toList(),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Mode tabs (only when not searching) ─────────────────────────
            if (!isSearching)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: _TabButton(
                        label: context.tr('surah'),
                        selected: _mode == 'surah',
                        colors: widget.colors,
                        onTap: () => _setMode('surah'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _TabButton(
                        label: context.tr('juz'),
                        selected: _mode == 'juz',
                        colors: widget.colors,
                        onTap: () => _setMode('juz'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _TabButton(
                        label: context.tr('page'),
                        selected: _mode == 'page',
                        colors: widget.colors,
                        onTap: () => _setMode('page'),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            // ── Content List ────────────────────────────────────────────────
            Expanded(
              child: ClipRect(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 0,
                  ),
                  children: [
                    if (isSearching) ...[
                      // Surah matches
                      if (surahs.isNotEmpty) ...[
                        Text(
                          context.tr('surah'),
                          style: textTheme.labelLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...surahs.map(
                          (surah) => _SimpleLinkRow(
                            colors: widget.colors,
                            title: surah.name,
                            subtitle: context.tr(
                              'ayat_count',
                              args: {'count': '${surah.count}'},
                            ),
                            icon: Icons.menu_book_outlined,
                            completed: completedSurahs.contains(surah.id),
                            onTap: () => widget.onOpen(surah.id, '1'),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Verse / translation matches
                      if (verseMatches.isNotEmpty) ...[
                        Text(
                          context.tr('ayah_matches'),
                          style: textTheme.labelLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...verseMatches.map(
                          (m) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radius,
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radius,
                                ),
                                onTap: () =>
                                    widget.onOpen(m.surahId, m.verseId),
                                child: _SectionCard(
                                  colors: widget.colors,
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.menu_book_outlined,
                                        color: widget.colors.primary,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    '${m.surahName}, ${context.tr('ayah_number', args: {'number': m.verseId})}',
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: textTheme.titleSmall
                                                        ?.copyWith(
                                                          fontWeight: FontWeight.bold,
                                                          color: widget
                                                              .colors
                                                              .textStrong,
                                                        ),
                                                  ),
                                                ),
                                                InkWell(
                                                  onTap: () => _openMushafForVerse(m.surahId, m.verseId),
                                                  borderRadius: BorderRadius.circular(6),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: widget.colors.surfaceMuted,
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(color: widget.colors.borderSoft),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.import_contacts, size: 12, color: widget.colors.primary),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          'มุศหัฟ',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.bold,
                                                            color: widget.colors.primary,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              m.translationText,
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: widget.colors.foreground,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.chevron_right,
                                        color: widget.colors.foreground,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      // Live API search matches
                      if (_isApiSearching)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: widget.colors.primary,
                              ),
                            ),
                          ),
                        ),
                      if (_apiSearchResult != null && _apiSearchResult!.items.isNotEmpty) ...[
                        Text(
                          'ผลการค้นหาจากอัลกุรอาน (${_apiSearchResult!.items.length})',
                          style: textTheme.labelLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._apiSearchResult!.items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AppTheme.radius),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(AppTheme.radius),
                                onTap: () => widget.onOpen(item.surahId, item.verseId),
                                child: _SectionCard(
                                  colors: widget.colors,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: colorScheme.primaryContainer,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'ซูเราะฮฺ ${widget.repository.getSurahName(item.surahId)} (${item.verseKey})',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: colorScheme.onPrimaryContainer,
                                              ),
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              InkWell(
                                                onTap: () => _openMushafForVerse(item.surahId, item.verseId),
                                                borderRadius: BorderRadius.circular(6),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: widget.colors.surfaceMuted,
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: widget.colors.borderSoft),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.import_contacts, size: 12, color: widget.colors.primary),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'มุศหัฟ',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                          color: widget.colors.primary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Icon(
                                                Icons.chevron_right,
                                                color: widget.colors.foreground,
                                                size: 18,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      if (item.arabicText.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: Text(
                                            item.arabicText,
                                            textDirection: TextDirection.rtl,
                                            style: GoogleFonts.amiri(
                                              fontSize: 16,
                                              height: 1.8,
                                              color: widget.colors.textStrong,
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (item.translationText.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          item.translationText,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: widget.colors.foreground,
                                            fontSize: 12,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (surahs.isEmpty && verseMatches.isEmpty && (_apiSearchResult == null || _apiSearchResult!.items.isEmpty) && !_isApiSearching)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Center(
                            child: Text(
                              context.tr(
                                'no_results_for',
                                args: {'query': query},
                              ),
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                    ] else ...[
                      if (_mode == 'surah')
                        ...surahs.map(
                          (surah) => _SimpleLinkRow(
                            colors: widget.colors,
                            title: surah.name,
                            subtitle: context.tr(
                              'ayat_count',
                              args: {'count': '${surah.count}'},
                            ),
                            icon: Icons.menu_book_outlined,
                            completed: completedSurahs.contains(surah.id),
                            onTap: () => widget.onOpen(surah.id, '1'),
                          ),
                        )
                      else if (_mode == 'juz')
                        ...juz.map(
                          (item) => _SimpleLinkRow(
                            colors: widget.colors,
                            title: '${context.tr('juz')} ${item.id}',
                            subtitle:
                                '${widget.repository.getSurahName(item.startSurah)}:${item.startAyah}',
                            icon: Icons.view_week_outlined,
                            onTap: () =>
                                widget.onOpen(item.startSurah, item.startAyah),
                          ),
                        )
                      else
                        _PageNumberGrid(
                          colors: widget.colors,
                          pages: pages,
                          onOpenPage: widget.onOpenPage,
                        ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageNumberGrid extends StatelessWidget {
  final AppThemeColors colors;
  final List<int> pages;
  final ValueChanged<int> onOpenPage;

  const _PageNumberGrid({
    required this.colors,
    required this.pages,
    required this.onOpenPage,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: pages.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.6,
      ),
      itemBuilder: (context, index) {
        final page = pages[index];
        return OutlinedButton(
          onPressed: () => onOpenPage(page),
          style: OutlinedButton.styleFrom(
            backgroundColor: colors.surface,
            foregroundColor: colors.foreground,
            side: BorderSide(color: colors.borderSoft),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: Text(
            '${context.tr('page')} $page',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontWeight: FontWeight.w800),
          ),
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  final AppThemeColors colors;
  final Widget child;

  const _SectionCard({required this.colors, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: colors.borderSoft),
      ),
      child: child,
    );
  }
}

class _SimpleLinkRow extends StatelessWidget {
  final AppThemeColors colors;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool completed;
  final VoidCallback onTap;

  const _SimpleLinkRow({
    required this.colors,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.completed = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        onTap: onTap,
        child: _SectionCard(
          colors: colors,
          child: Row(
            children: [
              Icon(icon, color: colors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: colors.textStrong,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: colors.foreground,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (completed) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green,
                  size: 18,
                ),
              ],
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: colors.foreground),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final AppThemeColors colors;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? colors.primaryLight : colors.surface,
        foregroundColor: selected ? colors.primary : colors.foreground,
        side: BorderSide(color: selected ? colors.primary : colors.borderSoft),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
      ),
      onPressed: onTap,
      child: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
    );
  }
}
