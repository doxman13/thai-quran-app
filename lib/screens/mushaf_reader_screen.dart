import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:qcf_quran/qcf_quran.dart';

import '../data/quran_foundation_repository.dart';
import '../data/quran_repository.dart';
import '../models/mushaf_models.dart';
import '../providers/mushaf_reading_provider.dart';
import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/tadabbur_panel.dart';

class MushafReaderScreen extends StatefulWidget {
  final QuranRepository quranRepository;
  final QuranFoundationRepository foundationRepository;
  final String profileId;

  const MushafReaderScreen({
    Key? key,
    required this.quranRepository,
    required this.foundationRepository,
    required this.profileId,
  }) : super(key: key);

  @override
  State<MushafReaderScreen> createState() => _MushafReaderScreenState();
}

class _MushafReaderScreenState extends State<MushafReaderScreen> {
  late int _pageNumber;
  late PageController _pageController;
  bool _completionShown = false;
  String? _highlightedVerseKey;
  String? _translationVerseKey;
  String? _translationText;
  bool _translationBookmarked = false;
  Timer? _translationTimer;
  Timer? _highlightTimer;

  @override
  void initState() {
    super.initState();
    final profile = context.read<MushafReadingProvider>().profileById(
      widget.profileId,
    );
    _pageNumber = profile?.currentPage ?? 1;
    _pageController = PageController(
      initialPage: _pageToIndex(profile, _pageNumber),
    );
  }

  @override
  void dispose() {
    _translationTimer?.cancel();
    _highlightTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  int _pageToIndex(MushafProfile? profile, int page) {
    if (profile == null) return 0;
    return _clampInt(page, profile.startPage, profile.targetPage) -
        profile.startPage;
  }

  int _indexToPage(MushafProfile profile, int index) {
    return _clampInt(
      profile.startPage + index,
      profile.startPage,
      profile.targetPage,
    );
  }

  Future<void> _handlePageChanged(MushafProfile profile, int page) async {
    _dismissTranslation();
    setState(() => _pageNumber = page);
    await context.read<MushafReadingProvider>().updateProgress(
      profileId: profile.id,
      pageNumber: page,
    );
    if (!profile.isFreeRead && page == profile.targetPage) {
      _showCompletionOnce();
    }
  }

  Future<void> _goToPage(int page) async {
    final profile = context.read<MushafReadingProvider>().profileById(
      widget.profileId,
    );
    if (profile == null) return;
    final safePage = _clampInt(page, profile.startPage, profile.targetPage);
    final index = _pageToIndex(profile, safePage);
    _dismissTranslation();
    if (_pageController.hasClients) {
      await _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    } else {
      await _handlePageChanged(profile, safePage);
    }
  }

  void _showCompletionOnce() {
    if (_completionShown || !mounted) return;
    _completionShown = true;
    setState(() {});
  }

  void _dismissTranslation() {
    _translationTimer?.cancel();
    _highlightTimer?.cancel();
    if (_translationText == null && _highlightedVerseKey == null) return;
    setState(() {
      _translationVerseKey = null;
      _translationText = null;
      _highlightedVerseKey = null;
      _translationBookmarked = false;
    });
  }

  void _beginVersePress(
    MushafProfile profile,
    String verseKey,
    int pageNumber,
  ) {
    _highlightTimer?.cancel();
    setState(() => _highlightedVerseKey = verseKey);
  }

  void _toggleVerseHighlight(String verseKey) {
    _highlightTimer?.cancel();
    setState(() {
      _highlightedVerseKey = _highlightedVerseKey == verseKey ? null : verseKey;
      if (_highlightedVerseKey == null) {
        _translationVerseKey = null;
      }
    });
  }

  Future<void> _showVerseTranslation(
    MushafProfile profile,
    String verseKey,
    int pageNumber,
  ) async {
    final parts = verseKey.split(':');
    if (parts.length != 2) return;
    final verse = widget.quranRepository.getVerse(parts[0], parts[1]);
    final translation = verse?.thaiV3 ?? 'Translation not found.';
    final isBookmarked = context
        .read<MushafReadingProvider>()
        .isVerseBookmarked(profile.mushafId, pageNumber, verseKey);

    _translationTimer?.cancel();
    setState(() {
      _highlightedVerseKey = verseKey;
      _translationVerseKey = verseKey;
      _translationText = translation;
      _translationBookmarked = isBookmarked;
    });
    _translationTimer = Timer(const Duration(seconds: 9), _dismissTranslation);
  }

  Future<void> _toggleCurrentVerseBookmark(MushafProfile profile) async {
    final verseKey = _translationVerseKey;
    if (verseKey == null) return;
    await context.read<MushafReadingProvider>().toggleVerseBookmark(
      mushafId: profile.mushafId,
      pageNumber: _pageNumber,
      verseKey: verseKey,
    );
    if (!mounted) return;
    setState(() {
      _translationBookmarked = context
          .read<MushafReadingProvider>()
          .isVerseBookmarked(profile.mushafId, _pageNumber, verseKey);
    });
  }

  Future<void> _openTadabburModalForVerse(
    String surahId,
    String verseId,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: TadabburPanel(
            surahId: surahId,
            verseId: verseId,
            onClose: () => Navigator.pop(ctx),
          ),
        );
      },
    );
  }

  Future<void> _askToAddNote(String surahId, String verseId) async {
    final addNote = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = context.read<SettingsProvider>().getAppColors();
        return AlertDialog(
          title: Text(
            'Add note?',
            style: GoogleFonts.inter(fontWeight: FontWeight.w900),
          ),
          content: Text(
            'Verse saved as favorite. Do you want to add a note now?',
            style: GoogleFonts.inter(color: colors.foreground),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Later',
                style: GoogleFonts.inter(fontWeight: FontWeight.w800),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Add note',
                style: GoogleFonts.inter(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
    );

    if (addNote == true && mounted) {
      await _openTadabburModalForVerse(surahId, verseId);
    }
  }

  Future<void> _toggleCurrentVerseFavorite({bool askForNote = false}) async {
    final verseKey = _translationVerseKey ?? _highlightedVerseKey;
    final parts = verseKey?.split(':') ?? const <String>[];
    if (parts.length != 2) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Tap an ayah first to favorite it.')),
        );
      return;
    }

    final notes = context.read<NotesProvider>();
    final existing = notes.getNoteObjectForVerse(parts[0], parts[1]);
    final hasNoteText = existing?.noteText.trim().isNotEmpty ?? false;
    if (existing == null) {
      await notes.saveNote(surahId: parts[0], verseId: parts[1], noteText: '');
      if (!mounted) return;
      if (askForNote) {
        await _askToAddNote(parts[0], parts[1]);
      } else {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Verse saved as favorite')),
          );
      }
      return;
    }

    if (!hasNoteText) {
      await notes.deleteNote(parts[0], parts[1]);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Removed from favorites')));
      return;
    }

    final remove = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = context.read<SettingsProvider>().getAppColors();
        return AlertDialog(
          title: Text(
            'Remove favorite?',
            style: GoogleFonts.inter(fontWeight: FontWeight.w900),
          ),
          content: Text(
            'This verse has a note. Removing it will delete the saved note too.',
            style: GoogleFonts.inter(color: colors.foreground),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(fontWeight: FontWeight.w800),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Remove',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  color: Colors.red.shade500,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (remove == true) {
      await notes.deleteNote(parts[0], parts[1]);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Removed from favorites')));
    }
  }

  Future<void> _showReaderSettings(MushafProfile profile) async {
    _dismissTranslation();
    final action = await showModalBottomSheet<_MushafSettingsAction>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return _MushafReaderSettingsSheet(
          displayMushafId: context
              .read<MushafReadingProvider>()
              .displayMushafId,
          currentPage: _pageNumber,
          profileName: profile.name,
          onDisplayMushafChanged: (mushafId) => context
              .read<MushafReadingProvider>()
              .setDisplayMushafId(mushafId),
          onSeeAllProfiles: () {
            Navigator.pop(sheetContext, _MushafSettingsAction.seeAllProfiles);
          },
        );
      },
    );
    if (!mounted) return;
    if (action == _MushafSettingsAction.seeAllProfiles) {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _showSurahSelector(
    BuildContext context,
    QuranRepository quranRepository,
  ) async {
    _dismissTranslation();
    final selectedSurah = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final colors = context.read<SettingsProvider>().getAppColors();
        return _SurahSelectorSheet(
          colors: colors,
          quranRepository: quranRepository,
        );
      },
    );
    if (selectedSurah != null) {
      _jumpToSurah(selectedSurah);
    }
  }

  Future<void> _jumpToSurah(int surahNumber) async {
    final provider = context.read<MushafReadingProvider>();
    final currentProfile = provider.profileById(widget.profileId);
    if (currentProfile == null) return;

    final startPage = getStartPageForSurah(surahNumber);
    final freeProfile = await provider.openFreeRead(currentProfile.mushafId);

    await provider.updateProgress(
      profileId: freeProfile.id,
      pageNumber: startPage,
    );
    await provider.setActiveProfile(freeProfile.id);

    if (!mounted) return;

    if (widget.profileId != freeProfile.id) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MushafReaderScreen(
            quranRepository: widget.quranRepository,
            foundationRepository: widget.foundationRepository,
            profileId: freeProfile.id,
          ),
        ),
      );
    } else {
      final index = startPage - freeProfile.startPage;
      _pageController.jumpToPage(index);
      setState(() {
        _pageNumber = startPage;
      });
    }
  }

  Future<bool> _handleBack() async {
    if (_translationText != null) {
      _dismissTranslation();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final colors = settings.getAppColors();
    final provider = Provider.of<MushafReadingProvider>(context);
    final profile = provider.profileById(widget.profileId);

    if (profile == null) {
      return Scaffold(
        backgroundColor: colors.background,
        body: const Center(child: Text('Mushaf profile not found.')),
      );
    }

    final displayMushafId = provider.displayMushafId;
    final type = mushafTypeById(displayMushafId);
    final pageCount = profile.targetPage - profile.startPage + 1;
    final favoriteVerseKey = _translationVerseKey ?? _highlightedVerseKey;
    final favoriteParts = favoriteVerseKey?.split(':') ?? const <String>[];
    final verseFavorited =
        favoriteParts.length == 2 &&
        context.watch<NotesProvider>().getNoteObjectForVerse(
              favoriteParts[0],
              favoriteParts[1],
            ) !=
            null;

    return WillPopScope(
      onWillPop: _handleBack,
      child: Scaffold(
        backgroundColor: _mushafPageColor(context),
        body: SafeArea(
          child: Column(
            children: [
              _ReaderTopBar(
                colors: colors,
                profile: profile,
                type: type,
                pageNumber: _pageNumber,
                pageBookmarked: provider.isPageBookmarked(
                  displayMushafId,
                  _pageNumber,
                ),
                onSettings: () => _showReaderSettings(profile),
                onBookmarkPage: () =>
                    provider.togglePageBookmark(displayMushafId, _pageNumber),
                verseFavorited: verseFavorited,
                onFavoriteVerse: () => _toggleCurrentVerseFavorite(),
                quranRepository: widget.quranRepository,
                onTitleTap: () =>
                    _showSurahSelector(context, widget.quranRepository),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    if (_translationText != null) {
                      _dismissTranslation();
                    }
                  },
                  child: Stack(
                    children: [
                      Directionality(
                        textDirection: TextDirection.rtl,
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: pageCount,
                          onPageChanged: (index) => _handlePageChanged(
                            profile,
                            _indexToPage(profile, index),
                          ),
                          itemBuilder: (context, index) {
                            final page = _indexToPage(profile, index);
                            final renderPage = _clampInt(
                              page,
                              1,
                              type.pageCount,
                            );
                            if (displayMushafId == qcfPackageMushafId) {
                              return _QcfPackagePageView(
                                colors: colors,
                                pageNumber: renderPage,
                                highlightedVerseKey: _highlightedVerseKey,
                                onVerseLongPressStart: (surah, verse) =>
                                    _beginVersePress(
                                      profile,
                                      '$surah:$verse',
                                      page,
                                    ),
                                onVerseLongPress: (surah, verse) =>
                                    _showVerseTranslation(
                                      profile,
                                      '$surah:$verse',
                                      page,
                                    ),
                              );
                            }
                            return _MushafRemotePageView(
                              colors: colors,
                              pageNumber: renderPage,
                              mushafId: displayMushafId,
                              repository: widget.foundationRepository,
                              highlightedVerseKey: _highlightedVerseKey,
                              onVerseTap: _toggleVerseHighlight,
                              onVerseLongPressStart: (verseKey) =>
                                  _beginVersePress(profile, verseKey, page),
                              onVerseLongPress: (verseKey) =>
                                  _showVerseTranslation(
                                    profile,
                                    verseKey,
                                    page,
                                  ),
                            );
                          },
                        ),
                      ),
                      if (!profile.isFreeRead &&
                          _pageNumber == profile.targetPage)
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: _translationText == null ? 12 : 178,
                          child: _CompletionCard(
                            colors: colors,
                            profile: profile,
                          ),
                        ),
                      if (_translationText != null)
                        Positioned(
                          left: 14,
                          right: 14,
                          bottom: 12,
                          child: _TranslationPanel(
                            colors: colors,
                            verseKey: _translationVerseKey ?? '',
                            translation: _translationText!,
                            bookmarked: _translationBookmarked,
                            favorited: verseFavorited,
                            onBookmark: () =>
                                _toggleCurrentVerseBookmark(profile),
                            onFavorite: () =>
                                _toggleCurrentVerseFavorite(askForNote: true),
                            onClose: _dismissTranslation,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              _ReaderBottomBar(
                colors: colors,
                onNext: _pageNumber < profile.targetPage
                    ? () => _goToPage(_pageNumber + 1)
                    : null,
                onDone: () => Navigator.pop(context),
                onPrevious: _pageNumber > profile.startPage
                    ? () => _goToPage(_pageNumber - 1)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

int _clampInt(int value, int min, int max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

Color _mushafPageColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF0B1120)
      : const Color(0xFFFFFBF0);
}

enum _MushafSettingsAction { seeAllProfiles }

class _MushafReaderSettingsSheet extends StatefulWidget {
  final int displayMushafId;
  final int currentPage;
  final String profileName;
  final ValueChanged<int> onDisplayMushafChanged;
  final VoidCallback onSeeAllProfiles;

  const _MushafReaderSettingsSheet({
    required this.displayMushafId,
    required this.currentPage,
    required this.profileName,
    required this.onDisplayMushafChanged,
    required this.onSeeAllProfiles,
  });

  @override
  State<_MushafReaderSettingsSheet> createState() =>
      _MushafReaderSettingsSheetState();
}

class _MushafReaderSettingsSheetState
    extends State<_MushafReaderSettingsSheet> {
  late int _mushafId;

  @override
  void initState() {
    super.initState();
    _mushafId = widget.displayMushafId;
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final colors = settings.getAppColors();
    final type = mushafTypeById(_mushafId);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mushaf Settings',
                style: GoogleFonts.inter(
                  color: colors.textStrong,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Current Profile Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: colors.primary.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Icon(Icons.person_outline, color: colors.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Current Profile',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: colors.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: widget.onSeeAllProfiles,
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 0,
                              ),
                              minimumSize: const Size(0, 28),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'See all',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.profileName,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: colors.textStrong,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Dark Mode Toggle Card
          Container(
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: colors.borderSoft),
            ),
            child: SwitchListTile(
              activeColor: colors.primary,
              secondary: Icon(
                settings.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                color: colors.primary,
              ),
              title: Text(
                'Dark Mode',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: colors.textStrong,
                ),
              ),
              subtitle: Text(
                'Optimize screen brightness for reading',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: colors.foreground,
                ),
              ),
              value: settings.isDarkMode,
              onChanged: (val) {
                settings.toggleDarkMode(val);
              },
            ),
          ),
          const SizedBox(height: 16),

          // Display Mushaf Selection Label
          Text(
            'Mushaf Font & Layout',
            style: GoogleFonts.inter(
              color: colors.textStrong,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),

          // Modern Styled Dropdown Container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: colors.borderSoft),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _mushafId,
                dropdownColor: colors.surface,
                icon: Icon(Icons.keyboard_arrow_down, color: colors.foreground),
                isExpanded: true,
                items: visibleMushafTypes
                    .map(
                      (type) => DropdownMenuItem(
                        value: type.id,
                        child: Text(
                          type.name,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors.textStrong,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null || value == _mushafId) return;
                  setState(() => _mushafId = value);
                  widget.onDisplayMushafChanged(value);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Current view: ${type.name} • Page ${widget.currentPage.clamp(1, type.pageCount)}',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: colors.foreground,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

String getSurahNameForPage(int pageNumber, QuranRepository quranRepository) {
  const List<int> surahStartPages = [
    1,
    2,
    50,
    77,
    106,
    128,
    151,
    177,
    187,
    208,
    221,
    235,
    249,
    255,
    262,
    267,
    282,
    293,
    305,
    312,
    322,
    332,
    342,
    350,
    359,
    367,
    377,
    385,
    396,
    404,
    411,
    415,
    418,
    428,
    434,
    440,
    446,
    453,
    458,
    467,
    477,
    483,
    489,
    496,
    499,
    502,
    506,
    511,
    515,
    518,
    521,
    523,
    526,
    528,
    531,
    534,
    537,
    542,
    545,
    549,
    551,
    553,
    554,
    556,
    558,
    560,
    562,
    564,
    566,
    568,
    570,
    572,
    574,
    575,
    577,
    578,
    580,
    582,
    583,
    585,
    586,
    587,
    589,
    590,
    591,
    592,
    593,
    594,
    595,
    596,
    596,
    597,
    598,
    598,
    599,
    599,
    600,
    601,
    601,
    602,
    602,
    603,
    603,
    604,
    604,
    604,
    604,
    604,
    604,
    604,
    604,
    604,
    604,
    604,
  ];

  int surahId = 1;
  for (int i = 0; i < surahStartPages.length; i++) {
    if (surahStartPages[i] <= pageNumber) {
      surahId = i + 1;
    } else {
      break;
    }
  }
  return quranRepository.getSurahName(surahId.toString());
}

class _ReaderTopBar extends StatelessWidget {
  final AppThemeColors colors;
  final MushafProfile profile;
  final MushafType type;
  final int pageNumber;
  final bool pageBookmarked;
  final VoidCallback onSettings;
  final VoidCallback onBookmarkPage;
  final bool verseFavorited;
  final VoidCallback onFavoriteVerse;
  final QuranRepository quranRepository;
  final VoidCallback onTitleTap;

  const _ReaderTopBar({
    required this.colors,
    required this.profile,
    required this.type,
    required this.pageNumber,
    required this.pageBookmarked,
    required this.onSettings,
    required this.onBookmarkPage,
    required this.verseFavorited,
    required this.onFavoriteVerse,
    required this.quranRepository,
    required this.onTitleTap,
  });

  @override
  Widget build(BuildContext context) {
    final surahName = getSurahNameForPage(pageNumber, quranRepository);
    final juz = getOfflineJuzForPage(pageNumber);
    final hizb = getOfflineHizbForPage(pageNumber);
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          IconButton(
            tooltip: pageBookmarked ? 'Remove page bookmark' : 'Bookmark page',
            onPressed: onBookmarkPage,
            iconSize: 20,
            visualDensity: VisualDensity.compact,
            icon: Icon(pageBookmarked ? Icons.bookmark : Icons.bookmark_border),
          ),
          IconButton(
            tooltip: verseFavorited ? 'Remove favorite' : 'Favorite ayah',
            onPressed: onFavoriteVerse,
            iconSize: 20,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              verseFavorited
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: verseFavorited ? Colors.redAccent : null,
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: onTitleTap,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '$surahName • Page $pageNumber • Juz $juz • Hizb $hizb',
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: colors.textStrong,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Mushaf settings',
            onPressed: onSettings,
            iconSize: 20,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
    );
  }
}

class _ReaderBottomBar extends StatelessWidget {
  final AppThemeColors colors;
  final VoidCallback? onNext;
  final VoidCallback onDone;
  final VoidCallback? onPrevious;

  const _ReaderBottomBar({
    required this.colors,
    required this.onNext,
    required this.onDone,
    required this.onPrevious,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 3, 12, 7),
        child: Row(
          children: [
            Expanded(
              child: _SmallReaderButton(
                icon: Icons.chevron_left,
                label: 'Next',
                onPressed: onNext,
                filled: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SmallReaderButton(
                icon: Icons.done,
                label: 'Done',
                onPressed: onDone,
                filled: false,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SmallReaderButton(
                icon: Icons.chevron_right,
                label: 'Previous',
                onPressed: onPrevious,
                filled: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallReaderButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool filled;

  const _SmallReaderButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
    final style = filled
        ? FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          )
        : OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
    return filled
        ? FilledButton(onPressed: onPressed, style: style, child: child)
        : OutlinedButton(onPressed: onPressed, style: style, child: child);
  }
}

class _QcfPackagePageView extends StatelessWidget {
  final AppThemeColors colors;
  final int pageNumber;
  final String? highlightedVerseKey;
  final void Function(int surahNumber, int verseNumber) onVerseLongPressStart;
  final void Function(int surahNumber, int verseNumber) onVerseLongPress;

  const _QcfPackagePageView({
    required this.colors,
    required this.pageNumber,
    required this.highlightedVerseKey,
    required this.onVerseLongPressStart,
    required this.onVerseLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF111827);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final qcfFontSize = (width / 18.8).clamp(17.0, 22.5);
        return ColoredBox(
          color: _mushafPageColor(context),
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(size: Size(constraints.maxWidth, constraints.maxHeight)),
            child: QcfPage(
              pageNumber: pageNumber,
              fontSize: qcfFontSize,
              sp: 1,
              h: 1,
              theme: QcfThemeData(
                pageBackgroundColor: _mushafPageColor(context),
                verseTextColor: textColor,
                verseNumberColor: colors.primary,
                basmalaColor: textColor,
                headerTextColor: textColor,
                headerBackgroundColor: Colors.transparent,
                customHeaderBuilder: (surahNumber) => _QcfSurahHeader(
                  surahNumber: surahNumber,
                  colors: colors,
                  showBismillahText: false,
                ),
              ),
              verseBackgroundColor: (surah, verse) {
                return highlightedVerseKey == '$surah:$verse'
                    ? colors.primaryLight.withValues(alpha: 0.75)
                    : null;
              },
              onLongPressDown: (surah, verse, LongPressStartDetails details) =>
                  onVerseLongPressStart(surah, verse),
              onLongPress: onVerseLongPress,
            ),
          ),
        );
      },
    );
  }
}

class _MushafRemotePageView extends StatefulWidget {
  final AppThemeColors colors;
  final int pageNumber;
  final int mushafId;
  final QuranFoundationRepository repository;
  final String? highlightedVerseKey;
  final ValueChanged<String> onVerseTap;
  final ValueChanged<String> onVerseLongPressStart;
  final ValueChanged<String> onVerseLongPress;

  const _MushafRemotePageView({
    required this.colors,
    required this.pageNumber,
    required this.mushafId,
    required this.repository,
    required this.highlightedVerseKey,
    required this.onVerseTap,
    required this.onVerseLongPressStart,
    required this.onVerseLongPress,
  });

  @override
  State<_MushafRemotePageView> createState() => _MushafRemotePageViewState();
}

class _MushafRemotePageViewState extends State<_MushafRemotePageView> {
  late Future<MushafPage> _future;

  @override
  void initState() {
    super.initState();
    _initFuture();
  }

  @override
  void didUpdateWidget(_MushafRemotePageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mushafId != widget.mushafId ||
        oldWidget.pageNumber != widget.pageNumber) {
      _initFuture();
    }
  }

  void _initFuture() {
    _future = widget.repository.fetchPage(
      mushafId: widget.mushafId,
      pageNumber: widget.pageNumber,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MushafPage>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(
            child: CircularProgressIndicator(color: widget.colors.primary),
          );
        }
        if (snapshot.hasError) {
          return _MushafError(
            colors: widget.colors,
            message: snapshot.error.toString(),
            onRetry: () {},
          );
        }
        final page = snapshot.data;
        if (page == null || page.lines.isEmpty) {
          return _MushafError(
            colors: widget.colors,
            message: 'No words found for this Mushaf page.',
            onRetry: () {},
          );
        }
        return _MushafPageView(
          colors: widget.colors,
          page: page,
          fontFamily: widget.repository.getFontFamily(
            widget.mushafId,
            widget.pageNumber,
          ),
          mushafId: widget.mushafId,
          highlightedVerseKey: widget.highlightedVerseKey,
          onVerseTap: widget.onVerseTap,
          onVerseLongPressStart: widget.onVerseLongPressStart,
          onVerseLongPress: widget.onVerseLongPress,
        );
      },
    );
  }
}

class _MushafPageView extends StatelessWidget {
  final AppThemeColors colors;
  final MushafPage page;
  final String fontFamily;
  final int mushafId;
  final String? highlightedVerseKey;
  final ValueChanged<String> onVerseTap;
  final ValueChanged<String> onVerseLongPressStart;
  final ValueChanged<String> onVerseLongPress;

  const _MushafPageView({
    required this.colors,
    required this.page,
    required this.fontFamily,
    required this.mushafId,
    required this.highlightedVerseKey,
    required this.onVerseTap,
    required this.onVerseLongPressStart,
    required this.onVerseLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final surahStartsByLine = _surahStartsByLine(page);
    final layout = _MushafLayoutProfile.forMushaf(mushafId);
    final verseEndWords = _verseEndWords(page);
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = SizedBox(
          width: layout.pageWidth,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final line in page.lines) ...[
                for (final surahId
                    in surahStartsByLine[line.first.lineNumber] ??
                        const <String>[])
                  _QcfSurahHeader(
                    surahNumber: int.tryParse(surahId) ?? 0,
                    colors: colors,
                  ),
                Builder(
                  builder: (context) {
                    return _MushafLine(
                      line: line,
                      fontFamily: fontFamily,
                      mushafId: mushafId,
                      pageNumber: page.pageNumber,
                      lineWidth: layout.lineWidth,
                      lineHeight: layout.lineHeight,
                      lineVerticalPadding: layout.lineVerticalPadding,
                      wordPadding: layout.wordPadding,
                      verseEndWords: verseEndWords,
                      surahStartsByLine: surahStartsByLine,
                      highlightedVerseKey: highlightedVerseKey,
                      onVerseTap: onVerseTap,
                      onVerseLongPressStart: onVerseLongPressStart,
                      onVerseLongPress: onVerseLongPress,
                    );
                  },
                ),
              ],
            ],
          ),
        );
        final availableWidth =
            (constraints.maxWidth - (layout.horizontalPadding * 2)).clamp(
              1.0,
              double.infinity,
            );
        final availableHeight = (constraints.maxHeight - 8).clamp(
          1.0,
          double.infinity,
        );

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: layout.horizontalPadding,
            vertical: 4,
          ),
          child: SizedBox(
            width: availableWidth,
            height: availableHeight,
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.center,
              child: content,
            ),
          ),
        );
      },
    );
  }

  Map<int, List<String>> _surahStartsByLine(MushafPage page) {
    final starts = <int, List<String>>{};
    for (final verse in page.verses) {
      if (verse.verseId != '1' || verse.words.isEmpty) continue;
      final lineNumber = verse.words.first.lineNumber;
      starts.putIfAbsent(lineNumber, () => []).add(verse.surahId);
    }
    return starts;
  }

  Set<MushafWord> _verseEndWords(MushafPage page) {
    final ends = <MushafWord>{};
    for (final verse in page.verses) {
      if (verse.words.isNotEmpty) {
        ends.add(verse.words.last);
      }
    }
    return ends;
  }
}

class _MushafLayoutProfile {
  final double pageWidth;
  final double lineWidth;
  final double lineHeight;
  final double lineVerticalPadding;
  final double horizontalPadding;
  final double wordPadding;

  const _MushafLayoutProfile({
    required this.pageWidth,
    required this.lineWidth,
    required this.lineHeight,
    required this.lineVerticalPadding,
    required this.horizontalPadding,
    required this.wordPadding,
  });

  factory _MushafLayoutProfile.forMushaf(int mushafId) {
    return switch (mushafId) {
      // QCF page fonts already carry their own spacing; keep padding at zero
      // and the canonical canvas tight so phone/tablet screens do not feel tiny.
      1 => const _MushafLayoutProfile(
        pageWidth: 410,
        lineWidth: 410,
        lineHeight: 1.7,
        lineVerticalPadding: 1.5,
        horizontalPadding: 16,
        wordPadding: 0,
      ),
      2 => const _MushafLayoutProfile(
        pageWidth: 412,
        lineWidth: 412,
        lineHeight: 1.6,
        lineVerticalPadding: 1.0,
        horizontalPadding: 16,
        wordPadding: 0,
      ),
      19 => const _MushafLayoutProfile(
        pageWidth: 410,
        lineWidth: 410,
        lineHeight: 1.7,
        lineVerticalPadding: 1.5,
        horizontalPadding: 16,
        wordPadding: 0,
      ),
      4 => const _MushafLayoutProfile(
        pageWidth: 390,
        lineWidth: 358,
        lineHeight: 1.8,
        lineVerticalPadding: 3,
        horizontalPadding: 16,
        wordPadding: 0.0,
      ),
      6 || 11 => const _MushafLayoutProfile(
        pageWidth: 390,
        lineWidth: 358,
        lineHeight: 1.7,
        lineVerticalPadding: 2,
        horizontalPadding: 16,
        wordPadding: 0.0,
      ),
      _ => const _MushafLayoutProfile(
        pageWidth: 390,
        lineWidth: 358,
        lineHeight: 1.7,
        lineVerticalPadding: 2,
        horizontalPadding: 16,
        wordPadding: 0.0,
      ),
    };
  }
}

class _QcfSurahHeader extends StatelessWidget {
  final int surahNumber;
  final AppThemeColors colors;
  final bool showBismillahText;

  const _QcfSurahHeader({
    required this.surahNumber,
    required this.colors,
    this.showBismillahText = true,
  });

  @override
  Widget build(BuildContext context) {
    if (surahNumber <= 0 || surahNumber > 114) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerTextColor = const Color(0xFF111827);
    final bismillahColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF111827);
    final showBismillah =
        showBismillahText && surahNumber != 1 && surahNumber != 9;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          ColorFiltered(
            colorFilter: isDark
                ? const ColorFilter.matrix([
                    -0.2126,
                    -0.7152,
                    -0.0722,
                    0,
                    255,
                    -0.2126,
                    -0.7152,
                    -0.0722,
                    0,
                    255,
                    -0.2126,
                    -0.7152,
                    -0.0722,
                    0,
                    255,
                    0,
                    0,
                    0,
                    1,
                    0,
                  ])
                : const ColorFilter.matrix([
                    0.2126,
                    0.7152,
                    0.0722,
                    0,
                    0,
                    0.2126,
                    0.7152,
                    0.0722,
                    0,
                    0,
                    0.2126,
                    0.7152,
                    0.0722,
                    0,
                    0,
                    0,
                    0,
                    0,
                    1,
                    0,
                  ]),
            child: Opacity(
              opacity: isDark ? 0.82 : 1,
              child: HeaderWidget(
                suraNumber: surahNumber,
                theme: QcfThemeData(
                  headerTextColor: headerTextColor,
                  headerBackgroundColor: Colors.transparent,
                  headerWidthSmall: 455,
                  headerWidthLarge: 400,
                  headerFontSizeSmall: 34,
                  headerFontSizeLarge: 22,
                ),
              ),
            ),
          ),
          if (showBismillah)
            Padding(
              padding: const EdgeInsets.only(top: 7, bottom: 2),
              child: Text(
                '\ufc41  \ufc42\ufc43\ufc44',
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'QCF_P001',
                  package: 'qcf_quran',
                  fontSize: 23,
                  height: 1.05,
                  color: bismillahColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MushafLine extends StatelessWidget {
  final List<MushafWord> line;
  final String fontFamily;
  final int mushafId;
  final int pageNumber;
  final double lineWidth;
  final double lineHeight;
  final double lineVerticalPadding;
  final double wordPadding;
  final Set<MushafWord> verseEndWords;
  final Map<int, List<String>> surahStartsByLine;
  final String? highlightedVerseKey;
  final ValueChanged<String> onVerseTap;
  final ValueChanged<String> onVerseLongPressStart;
  final ValueChanged<String> onVerseLongPress;

  const _MushafLine({
    required this.line,
    required this.fontFamily,
    required this.mushafId,
    required this.pageNumber,
    required this.lineWidth,
    required this.lineHeight,
    required this.lineVerticalPadding,
    required this.wordPadding,
    required this.verseEndWords,
    required this.surahStartsByLine,
    required this.highlightedVerseKey,
    required this.onVerseTap,
    required this.onVerseLongPressStart,
    required this.onVerseLongPress,
  });

  @override
  Widget build(BuildContext context) {
    bool isShortLine = false;
    
    if (line.isNotEmpty) {
      final isLastLineOfSurahOnPage = surahStartsByLine.containsKey(line.first.lineNumber + 1);
      
      if (pageNumber == 1 || pageNumber == 2) {
        isShortLine = true;
      } else if (pageNumber >= 582) { // Juz 30
        isShortLine = true;
      } else if (isLastLineOfSurahOnPage) {
        isShortLine = true;
      } else if (line.length < 4) {
        isShortLine = true;
      }
    }

    final fontSize = switch (mushafId) {
      1 => pageNumber <= 2 ? 34.0 : 25.2,
      2 => pageNumber <= 2 ? 38.0 : 30.5,
      4 || 99 => 23.5,
      6 => 25.0,
      11 => 22.0,
      19 => 25.2,
      _ => 22.5,
    };
    final bool isQcf = mushafId == 1 || mushafId == 2 || mushafId == 19;
    final baseStyle = TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      height: isQcf ? lineHeight : null,
      color: Theme.of(context).textTheme.bodyMedium?.color,
      fontWeight: FontWeight.w400,
    );
    final strutStyle = isQcf
        ? StrutStyle.fromTextStyle(
            baseStyle,
            forceStrutHeight: true,
          )
        : null;
    final textHeightBehavior = isQcf
        ? const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          )
        : null;

    final textSpans = <InlineSpan>[];
    for (int i = 0; i < line.length; i++) {
      final word = line[i];
      final isHighlighted = highlightedVerseKey == word.verseKey;
      final highlightColor = isHighlighted
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.16)
          : null;

      final recognizer = TapGestureRecognizer()
        ..onTap = () => onVerseTap(word.verseKey);

      if ((mushafId == 11 || mushafId == 99) && word.tajweedParts.isNotEmpty) {
        for (final part in word.tajweedParts) {
          textSpans.add(TextSpan(
            text: part.text,
            style: baseStyle.copyWith(
              color: _getTajweedColor(part.className, context),
              backgroundColor: highlightColor,
            ),
            recognizer: recognizer,
          ));
        }
        textSpans.add(TextSpan(text: ' ', style: baseStyle.copyWith(backgroundColor: highlightColor), recognizer: recognizer));
      } else {
        textSpans.add(TextSpan(
          text: '${word.text} ',
          style: baseStyle.copyWith(backgroundColor: highlightColor),
          recognizer: recognizer,
        ));
      }

      if (_shouldShowIndopakVerseMarker(word)) {
        final verseNumber = int.tryParse(word.verseKey.split(':').last) ?? 0;
        final marker = '${String.fromCharCode(0x06dd)}${_arabicIndicDigits(verseNumber)}';
        textSpans.add(TextSpan(
          text: marker,
          style: TextStyle(
            fontFamily: 'UthmanicHafs',
            fontSize: 13,
            height: 1,
            color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.78),
            backgroundColor: highlightColor,
          ),
          recognizer: recognizer,
        ));
      }
    }

    final richText = RichText(
      textAlign: isShortLine ? TextAlign.center : TextAlign.justify,
      textDirection: TextDirection.rtl,
      strutStyle: strutStyle,
      textHeightBehavior: textHeightBehavior,
      softWrap: false, // ensures it calculates width identically to Row without wrapping
      text: TextSpan(children: textSpans),
    );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: lineVerticalPadding),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPressStart: (_) {
          if (highlightedVerseKey != null) {
            onVerseLongPressStart(highlightedVerseKey!);
          }
        },
        onLongPress: () {
          if (highlightedVerseKey != null) {
            onVerseLongPress(highlightedVerseKey!);
          }
        },
        child: SizedBox(
          width: lineWidth,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: lineWidth),
              child: richText,
            ),
          ),
        ),
      ),
    );
  }

  bool _shouldShowIndopakVerseMarker(MushafWord word) {
    if (mushafId != 3 && mushafId != 6 && mushafId != 7) return false;
    if (!verseEndWords.contains(word)) return false;
    return !RegExp('[\u06dd\u06de\u0660-\u0669\u06f0-\u06f9\uf500-\uf8ff]').hasMatch(word.text);
  }

  Color? _getTajweedColor(String className, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (className.toLowerCase()) {
      case 'ghunnah':
      case 'ikhfa':
      case 'ikhafa': // From api.quran.com
      case 'ikhfa_shafawi':
      case 'ikhafa_shafawi': // From api.quran.com
      case 'idgham_ghunnah':
      case 'idgham_wo_ghunnah': // From api.quran.com
      case 'idgham_shafawi': // From api.quran.com
      case 'idgham_muthamaasilayn':
      case 'iqlab':
        return isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D);
      case 'qalqalah':
      case 'qalaqah': // From api.quran.com
        return isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8);
      case 'madda_normal':
      case 'madda_permissible':
      case 'madda_necessary':
      case 'madda_obligatory':
      case 'madda_obligatory_monfasel': // From api.quran.com
      case 'madda_obligatory_mottasel': // From api.quran.com
        return isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
      case 'ham_wasl':
      case 'laam_shamsiyah':
      case 'silent':
      case 'slnt': // From api.quran.com
        return const Color(0xFF94A3B8);
      default:
        return null;
    }
  }

  String _arabicIndicDigits(int value) {
    const digits = [
      0x0660,
      0x0661,
      0x0662,
      0x0663,
      0x0664,
      0x0665,
      0x0666,
      0x0667,
      0x0668,
      0x0669,
    ];
    return value
        .toString()
        .split('')
        .map((digit) => String.fromCharCode(digits[int.parse(digit)]))
        .join();
  }
}

class _VerseGestureTarget extends StatelessWidget {
  final String verseKey;
  final Widget child;
  final ValueChanged<String> onVerseTap;
  final ValueChanged<String> onVerseLongPressStart;
  final ValueChanged<String> onVerseLongPress;

  const _VerseGestureTarget({
    required this.verseKey,
    required this.child,
    required this.onVerseTap,
    required this.onVerseLongPressStart,
    required this.onVerseLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onVerseTap(verseKey),
      onLongPressStart: (_) => onVerseLongPressStart(verseKey),
      onLongPress: () => onVerseLongPress(verseKey),
      child: child,
    );
  }
}

class _TranslationPanel extends StatelessWidget {
  final AppThemeColors colors;
  final String verseKey;
  final String translation;
  final bool bookmarked;
  final bool favorited;
  final VoidCallback onBookmark;
  final VoidCallback onFavorite;
  final VoidCallback onClose;

  const _TranslationPanel({
    required this.colors,
    required this.verseKey,
    required this.translation,
    required this.bookmarked,
    required this.favorited,
    required this.onBookmark,
    required this.onFavorite,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.surface,
      elevation: 16,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 210),
        padding: const EdgeInsets.fromLTRB(16, 12, 10, 14),
        decoration: BoxDecoration(
          border: Border.all(color: colors.borderSoft),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    verseKey,
                    style: GoogleFonts.inter(
                      color: colors.textStrong,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: bookmarked ? 'Remove bookmark' : 'Bookmark verse',
                  onPressed: onBookmark,
                  icon: Icon(
                    bookmarked ? Icons.bookmark : Icons.bookmark_border,
                    color: colors.primary,
                  ),
                ),
                IconButton(
                  tooltip: favorited ? 'Remove favorite' : 'Favorite verse',
                  onPressed: onFavorite,
                  icon: Icon(
                    favorited
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: favorited ? Colors.redAccent : colors.primary,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Text(
                  translation,
                  locale: const Locale('th', 'TH'),
                  softWrap: true,
                  style: GoogleFonts.prompt(
                    color: colors.foreground,
                    height: 1.55,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletionCard extends StatelessWidget {
  final AppThemeColors colors;
  final MushafProfile profile;

  const _CompletionCard({required this.colors, required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.primaryLight,
        border: Border.all(color: colors.primaryLightBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.celebration_outlined, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${profile.name} complete',
              style: GoogleFonts.inter(
                color: colors.textStrong,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MushafError extends StatelessWidget {
  final AppThemeColors colors;
  final String message;
  final VoidCallback onRetry;

  const _MushafError({
    required this.colors,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, color: colors.primary, size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: colors.foreground, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

int getStartPageForSurah(int surahNumber) {
  const List<int> surahStartPages = [
    1,
    2,
    50,
    77,
    106,
    128,
    151,
    177,
    187,
    208,
    221,
    235,
    249,
    255,
    262,
    267,
    282,
    293,
    305,
    312,
    322,
    332,
    342,
    350,
    359,
    367,
    377,
    385,
    396,
    404,
    411,
    415,
    418,
    428,
    434,
    440,
    446,
    453,
    458,
    467,
    477,
    483,
    489,
    496,
    499,
    502,
    506,
    511,
    515,
    518,
    521,
    523,
    526,
    528,
    531,
    534,
    537,
    542,
    545,
    549,
    551,
    553,
    554,
    556,
    558,
    560,
    562,
    564,
    566,
    568,
    570,
    572,
    574,
    575,
    577,
    578,
    580,
    582,
    583,
    585,
    586,
    587,
    589,
    590,
    591,
    592,
    593,
    594,
    595,
    596,
    596,
    597,
    598,
    598,
    599,
    599,
    600,
    601,
    601,
    602,
    602,
    603,
    603,
    604,
    604,
    604,
    604,
    604,
    604,
    604,
    604,
    604,
    604,
    604,
  ];
  if (surahNumber < 1 || surahNumber > 114) return 1;
  return surahStartPages[surahNumber - 1];
}

class _SurahSelectorSheet extends StatefulWidget {
  final AppThemeColors colors;
  final QuranRepository quranRepository;

  const _SurahSelectorSheet({
    required this.colors,
    required this.quranRepository,
  });

  @override
  State<_SurahSelectorSheet> createState() => _SurahSelectorSheetState();
}

class _SurahSelectorSheetState extends State<_SurahSelectorSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surahs = List.generate(114, (index) => index + 1).where((
      surahNumber,
    ) {
      final name = widget.quranRepository
          .getSurahName(surahNumber.toString())
          .toLowerCase();
      return name.contains(_query.toLowerCase()) ||
          surahNumber.toString().contains(_query);
    }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Text(
            'Select Surah',
            style: GoogleFonts.inter(
              color: widget.colors.textStrong,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _query = val),
            decoration: InputDecoration(
              hintText: 'Search Surah...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: widget.colors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                borderSide: BorderSide(color: widget.colors.borderSoft),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                borderSide: BorderSide(color: widget.colors.borderSoft),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: surahs.length,
              itemBuilder: (context, index) {
                final surahNumber = surahs[index];
                final name = widget.quranRepository.getSurahName(
                  surahNumber.toString(),
                );
                return ListTile(
                  title: Text(
                    name,
                    style: GoogleFonts.inter(
                      color: widget.colors.textStrong,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: widget.colors.foreground,
                  ),
                  onTap: () => Navigator.pop(context, surahNumber),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

int getOfflineJuzForPage(int pageNumber) {
  const starts = [
    1,
    22,
    42,
    62,
    82,
    102,
    122,
    142,
    162,
    182,
    202,
    222,
    242,
    262,
    282,
    302,
    322,
    342,
    362,
    382,
    402,
    422,
    442,
    462,
    482,
    502,
    522,
    542,
    562,
    582,
  ];
  for (int i = starts.length - 1; i >= 0; i--) {
    if (pageNumber >= starts[i]) return i + 1;
  }
  return 1;
}

int getOfflineHizbForPage(int pageNumber) {
  final juz = getOfflineJuzForPage(pageNumber);
  const starts = [
    1,
    22,
    42,
    62,
    82,
    102,
    122,
    142,
    162,
    182,
    202,
    222,
    242,
    262,
    282,
    302,
    322,
    342,
    362,
    382,
    402,
    422,
    442,
    462,
    482,
    502,
    522,
    542,
    562,
    582,
  ];
  final juzIndex = juz - 1;
  final startPage = starts[juzIndex];
  final endPage = juzIndex < 29 ? starts[juzIndex + 1] - 1 : 604;
  final midPage = startPage + (endPage - startPage) ~/ 2;

  if (pageNumber > midPage) {
    return juz * 2;
  } else {
    return juz * 2 - 1;
  }
}
