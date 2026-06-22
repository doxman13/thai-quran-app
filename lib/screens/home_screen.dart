import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../data/quran_repository.dart';
import '../providers/local_reading_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/supabase_provider.dart';
import '../providers/notes_provider.dart';
import '../shared/shared.dart';
import '../theme/app_theme.dart';
import 'bookmarks_screen.dart';
import 'notes_screen.dart';
import 'profile_screen.dart';
import 'reading_screen.dart';

class HomeScreen extends StatefulWidget {
  final QuranRepository repository;

  const HomeScreen({Key? key, required this.repository}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  final TextEditingController _searchController = TextEditingController();
  bool _isInit = false;
  int _pageIndex = 0;
  String _browseMode = 'surah';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _triggerAutoSync();
    }
  }

  Future<void> _triggerAutoSync() async {
    final supabaseProv = Provider.of<SupabaseProvider>(context, listen: false);
    if (supabaseProv.isLoggedIn) {
      final userId = supabaseProv.userId;
      final readingProv = Provider.of<LocalReadingProvider>(context, listen: false);
      final notesProv = Provider.of<NotesProvider>(context, listen: false);
      try {
        await readingProv.syncBookmarksAndProfilesWithSupabase(userId);
        await readingProv.syncReadingStateWithSupabase(userId);
        await notesProv.syncWithSupabase();
      } catch (e) {
        debugPrint('Auto-sync error: $e');
      }
    }
  }

  Future<void> _initApp() async {
    await widget.repository.init();
    if (mounted) {
      setState(() => _isInit = true);
    }
  }

  void _navigateToReading(
    BuildContext context,
    String surahId, {
    String? verseId,
    int? verseIndex,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReadingScreen(
          repository: widget.repository,
          initialSurah: surahId,
          initialVerseId: verseId,
          initialVerseIndex:
              verseIndex ?? ((int.tryParse(verseId ?? '1') ?? 1) - 1),
        ),
      ),
    );
  }

  Future<void> _navigateToBookmarks(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookmarksScreen(repository: widget.repository),
      ),
    );

    if (result != null && mounted) {
      _navigateToReading(
        context,
        result['surahId'],
        verseId: result['verseId']?.toString(),
        verseIndex: result['verseIndex'] as int?,
      );
    }
  }

  Future<void> _setPage(int index) async {
    setState(() => _pageIndex = index);
    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final colors = settings.getAppColors();

    if (!_isInit) {
      return Scaffold(
        backgroundColor: colors.background,
        body: Center(child: CircularProgressIndicator(color: colors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              colors: colors,
              pageIndex: _pageIndex,
              onWorkspace: () => _setPage(0),
              onBrowse: () => _setPage(1),
              onProfile: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ProfileScreen(repository: widget.repository),
                  ),
                );
              },
              onTheme: () => settings.toggleDarkMode(!settings.isDarkMode),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _pageIndex = index),
                children: [
                  _WorkspacePage(
                    repository: widget.repository,
                    colors: colors,
                    onContinue: _navigateToReading,
                    onBookmarks: _navigateToBookmarks,
                    onNotes: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              NotesScreen(repository: widget.repository),
                        ),
                      );
                    },
                    onCreateProfile: () => _showProfileDialog(context),
                    onEditProfile: (profile) =>
                        _showProfileDialog(context, profile: profile),
                  ),
                  _BrowsePage(
                    repository: widget.repository,
                    colors: colors,
                    mode: _browseMode,
                    searchController: _searchController,
                    onModeChanged: (mode) => setState(() => _browseMode = mode),
                    onOpen: (surahId, verseId) {
                      final localReading = Provider.of<LocalReadingProvider>(
                        context,
                        listen: false,
                      );
                      final freeRead = localReading.activeProfiles
                          .where(isFreeReadProfile)
                          .firstOrNull;
                      final active = localReading.activeProfile;
                      if (active != null &&
                          !_isRefInsideProfile(active, surahId, verseId) &&
                          freeRead != null) {
                        localReading.setActiveProfile(freeRead.id);
                      }
                      _navigateToReading(context, surahId, verseId: verseId);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isRefInsideProfile(
    LocalReadingProfile profile,
    String surahId,
    String verseId,
  ) {
    if (profile.target == null || isFreeReadProfile(profile)) return true;
    final ordinal = _verseOrdinal(surahId, verseId);
    return ordinal >=
            _verseOrdinal(profile.start.surahId, profile.start.verseId) &&
        ordinal <=
            _verseOrdinal(profile.target!.surahId, profile.target!.verseId);
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

  Future<void> _showProfileDialog(
    BuildContext context, {
    LocalReadingProfile? profile,
  }) async {
    final provider = Provider.of<LocalReadingProvider>(context, listen: false);
    final colors = Provider.of<SettingsProvider>(
      context,
      listen: false,
    ).getAppColors();
    final nameController = TextEditingController(text: profile?.name ?? '');
    var planMode = profile?.planMode ?? 'custom';
    var startSurah = profile?.start.surahId ?? '1';
    var startAyah = profile?.start.verseId ?? '1';
    var endSurah = profile?.target?.surahId ?? startSurah;
    var endAyah = profile?.target?.verseId ?? startAyah;
    var startJuz = profile?.startJuz ?? 1;
    var endJuz = profile?.targetJuz ?? startJuz;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final startAyahCount = widget.repository
                .getSurahVerses(startSurah)
                .length;
            final endAyahCount = widget.repository
                .getSurahVerses(endSurah)
                .length;
            startAyah = _clampAyah(startAyah, startAyahCount);
            endAyah = _clampAyah(endAyah, endAyahCount);

            return AlertDialog(
              backgroundColor: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                side: BorderSide(color: colors.borderSoft),
              ),
              title: Text(
                profile == null
                    ? 'Create Reading Profile'
                    : 'Edit Reading Profile',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  color: colors.textStrong,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Profile name',
                        hintText: 'Ramadan 2026',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: planMode,
                      decoration: const InputDecoration(labelText: 'Plan type'),
                      items: const [
                        DropdownMenuItem(
                          value: 'by_juz',
                          child: Text('By Juz'),
                        ),
                        DropdownMenuItem(
                          value: 'by_ayat',
                          child: Text('By Ayat'),
                        ),
                        DropdownMenuItem(
                          value: 'by_surah',
                          child: Text('By Surah'),
                        ),
                        DropdownMenuItem(
                          value: 'custom',
                          child: Text('Custom'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null)
                          setDialogState(() => planMode = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    if (planMode == 'by_juz')
                      Row(
                        children: [
                          Expanded(
                            child: _numberDropdown(
                              label: 'Start Juz',
                              value: startJuz,
                              max: 30,
                              onChanged: (value) {
                                setDialogState(() {
                                  startJuz = value;
                                  if (endJuz < startJuz) endJuz = startJuz;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _numberDropdown(
                              label: 'End Juz',
                              value: endJuz,
                              min: startJuz,
                              max: 30,
                              onChanged: (value) =>
                                  setDialogState(() => endJuz = value),
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _surahDropdown(
                        label: 'Start Surah',
                        value: startSurah,
                        onChanged: (value) {
                          setDialogState(() {
                            startSurah = value;
                            if (int.parse(endSurah) <
                                int.parse(startSurah)) {
                              endSurah = startSurah;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      _surahDropdown(
                        label: 'End Surah',
                        value: endSurah,
                        min: int.parse(startSurah),
                        onChanged: (value) =>
                            setDialogState(() => endSurah = value),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _ayahDropdown(
                              label: 'Start Ayah',
                              value: planMode == 'by_surah' ? '1' : startAyah,
                              max: startAyahCount,
                              enabled: planMode != 'by_surah',
                              onChanged: (value) =>
                                  setDialogState(() => startAyah = value),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ayahDropdown(
                              label: 'End Ayah',
                              value: planMode == 'by_surah'
                                  ? endAyahCount.toString()
                                  : endAyah,
                              max: endAyahCount,
                              enabled: planMode != 'by_surah',
                              onChanged: (value) =>
                                  setDialogState(() => endAyah = value),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        error!,
                        style: GoogleFonts.inter(
                          color: Colors.red.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                  ),
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      setDialogState(
                        () => error = 'Enter a profile name first.',
                      );
                      return;
                    }

                    final start = planMode == 'by_juz'
                        ? _juzStartRef(startJuz)
                        : toVerseRef(
                            startSurah,
                            planMode == 'by_surah' ? 1 : startAyah,
                          );
                    final target = planMode == 'by_juz'
                        ? _juzEndRef(endJuz)
                        : toVerseRef(
                            endSurah,
                            planMode == 'by_surah'
                                ? widget.repository
                                      .getSurahVerses(endSurah)
                                      .length
                                : endAyah,
                          );

                    if (_verseOrdinal(target.surahId, target.verseId) <
                        _verseOrdinal(start.surahId, start.verseId)) {
                      setDialogState(
                        () => error =
                            'End position must be after the start position.',
                      );
                      return;
                    }

                    Navigator.pop(dialogContext);

                    if (profile == null) {
                      provider.createProfile(
                        name: name,
                        planMode: planMode,
                        startJuz: planMode == 'by_juz' ? startJuz : null,
                        targetJuz: planMode == 'by_juz' ? endJuz : null,
                        start: start,
                        target: target,
                        context: context,
                      );
                    } else {
                      provider.updateProfile(
                        profileId: profile.id,
                        name: name,
                        planMode: planMode,
                        startJuz: planMode == 'by_juz' ? startJuz : null,
                        targetJuz: planMode == 'by_juz' ? endJuz : null,
                        start: start,
                        target: target,
                      );
                    }
                  },
                  child: Text(profile == null ? 'Create' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
  }

  Widget _numberDropdown({
    required String label,
    required int value,
    required int max,
    int min = 1,
    required ValueChanged<int> onChanged,
  }) {
    final safe = value.clamp(min, max);
    return DropdownButtonFormField<int>(
      value: safe,
      decoration: InputDecoration(labelText: label),
      items: [
        for (var number = min; number <= max; number++)
          DropdownMenuItem(value: number, child: Text(number.toString())),
      ],
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }

  Widget _surahDropdown({
    required String label,
    required String value,
    int min = 1,
    required ValueChanged<String> onChanged,
  }) {
    final parsed = int.tryParse(value) ?? min;
    final safe = parsed.clamp(min, 114);
    return DropdownButtonFormField<String>(
      value: safe.toString(),
      decoration: InputDecoration(labelText: label),
      items: [
        for (var surah = min; surah <= 114; surah++)
          DropdownMenuItem(
            value: surah.toString(),
            child: Text(widget.repository.getSurahName(surah.toString())),
          ),
      ],
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }

  Widget _ayahDropdown({
    required String label,
    required String value,
    required int max,
    required ValueChanged<String> onChanged,
    bool enabled = true,
  }) {
    final safe = _clampAyah(value, max);
    return DropdownButtonFormField<String>(
      value: safe,
      decoration: InputDecoration(labelText: label),
      items: [
        for (var ayah = 1; ayah <= max; ayah++)
          DropdownMenuItem(
            value: ayah.toString(),
            child: Text(ayah.toString()),
          ),
      ],
      onChanged: enabled
          ? (next) {
              if (next != null) onChanged(next);
            }
          : null,
    );
  }

  String _clampAyah(String value, int max) {
    final ayah = int.tryParse(value) ?? 1;
    return ayah.clamp(1, max < 1 ? 1 : max).toString();
  }

  VerseRef _juzStartRef(int juz) {
    final start = _juzStarts[(juz - 1).clamp(0, _juzStarts.length - 1)];
    return toVerseRef(start[0], start[1]);
  }

  VerseRef _juzEndRef(int juz) {
    if (juz >= _juzStarts.length) {
      final lastCount = widget.repository.getSurahVerses('114').length;
      return toVerseRef(114, lastCount);
    }
    final nextStart = _juzStarts[juz];
    var surah = nextStart[0];
    var ayah = nextStart[1] - 1;
    if (ayah < 1) {
      surah -= 1;
      ayah = widget.repository.getSurahVerses(surah.toString()).length;
    }
    return toVerseRef(surah, ayah);
  }
}

class _Header extends StatelessWidget {
  final AppThemeColors colors;
  final int pageIndex;
  final VoidCallback onWorkspace;
  final VoidCallback onBrowse;
  final VoidCallback onProfile;
  final VoidCallback onTheme;

  const _Header({
    required this.colors,
    required this.pageIndex,
    required this.onWorkspace,
    required this.onBrowse,
    required this.onProfile,
    required this.onTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        border: Border(bottom: BorderSide(color: colors.borderSoft)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                child: Image.asset(
                  'assets/icons/playstore-icon.png',
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thai Quran Reader',
                      style: GoogleFonts.inter(
                        color: colors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'อ่าน - Quran Readers Workspace',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: colors.textStrong,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Profile',
                onPressed: onProfile,
                icon: Icon(
                  Icons.account_circle_outlined,
                  color: colors.primary,
                ),
              ),
              IconButton(
                tooltip: 'Theme',
                onPressed: onTheme,
                icon: Icon(Icons.brightness_6_outlined, color: colors.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TabButton(
                  label: 'Workspace',
                  selected: pageIndex == 0,
                  colors: colors,
                  onTap: onWorkspace,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TabButton(
                  label: 'Surah / Juz',
                  selected: pageIndex == 1,
                  colors: colors,
                  onTap: onBrowse,
                ),
              ),
            ],
          ),
        ],
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

class _WorkspacePage extends StatelessWidget {
  final QuranRepository repository;
  final AppThemeColors colors;
  final void Function(BuildContext, String, {String? verseId, int? verseIndex})
  onContinue;
  final Future<void> Function(BuildContext) onBookmarks;
  final VoidCallback onNotes;
  final VoidCallback onCreateProfile;
  final ValueChanged<LocalReadingProfile> onEditProfile;

  const _WorkspacePage({
    required this.repository,
    required this.colors,
    required this.onContinue,
    required this.onBookmarks,
    required this.onNotes,
    required this.onCreateProfile,
    required this.onEditProfile,
  });

  @override
  Widget build(BuildContext context) {
    final progress = Provider.of<ProgressProvider>(context);
    final localReading = Provider.of<LocalReadingProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final active = localReading.activeProfile;
    final continueSurah = active?.current.surahId ?? progress.currentSurahId;
    final continueVerse =
        active?.current.verseId ?? (progress.lastVerseIndex + 1).toString();

    // Fetch the verse translation for the active card
    final verses = repository.getSurahVerses(continueSurah);
    String translationText = '';
    if (verses.isNotEmpty) {
      final verseObj = verses.firstWhere(
        (v) => v.id == continueVerse,
        orElse: () => verses.first,
      );
      if (settings.primaryTranslationId == 'thai_v2') {
        translationText = verseObj.thaiV2;
      } else if (settings.primaryTranslationId == 'english') {
        translationText = verseObj.english;
      } else {
        translationText = verseObj.thaiV3;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Outstanding Active Profile Card with Gradient
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colors.primary, colors.primaryHover],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radius * 1.5),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withOpacity(0.35),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.textInverse.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_stories,
                          size: 12,
                          color: colors.textInverse.withOpacity(0.9),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          (active?.name ?? 'Free Read').toUpperCase(),
                          style: GoogleFonts.inter(
                            color: colors.textInverse.withOpacity(0.9),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                repository.getSurahName(continueSurah),
                style: GoogleFonts.inter(
                  color: colors.textInverse,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Current ayah $continueSurah:$continueVerse',
                style: GoogleFonts.inter(
                  color: colors.textInverse.withOpacity(0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (translationText.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.textInverse.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    border: Border(
                      left: BorderSide(
                        color: colors.accent,
                        width: 3.5,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TRANSLATION',
                        style: GoogleFonts.inter(
                          color: colors.textInverse.withOpacity(0.6),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        translationText,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: colors.textInverse.withOpacity(0.95),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.textInverse,
                    foregroundColor: colors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                  onPressed: () =>
                      onContinue(context, continueSurah, verseId: continueVerse),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Continue Reading',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                colors: colors,
                icon: Icons.bookmarks_outlined,
                label: 'Bookmarks',
                onTap: () => onBookmarks(context),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                colors: colors,
                icon: Icons.edit_note_outlined,
                label: 'Tadabbur',
                onTap: onNotes,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                'Reading Profiles',
                style: GoogleFonts.inter(
                  color: colors.textStrong,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '${localReading.activeProfiles.length}/$maxActiveReadingProfiles',
              style: GoogleFonts.inter(
                color: colors.foreground,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: localReading.canCreateProfile ? onCreateProfile : null,
              child: const Text('Create'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...localReading.activeProfiles.map(
          (profile) => _ProfileCard(
            repository: repository,
            profile: profile,
            colors: colors,
            selected: profile.id == localReading.activeProfileId,
            onSelect: () => localReading.setActiveProfile(profile.id),
            onContinue: () {
              localReading.setActiveProfile(profile.id);
              onContinue(
                context,
                profile.current.surahId,
                verseId: profile.current.verseId,
              );
            },
            onEdit: isFreeReadProfile(profile)
                ? null
                : () => onEditProfile(profile),
            onArchive: isFreeReadProfile(profile)
                ? null
                : () => localReading.archiveProfile(profile.id),
            onDelete: isFreeReadProfile(profile)
                ? null
                : () => localReading.deleteProfile(profile.id),
          ),
        ),
        if (localReading.archivedProfiles.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            'Archived Profiles',
            style: GoogleFonts.inter(
              color: colors.textStrong,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          ...localReading.archivedProfiles.map(
            (profile) => _ArchivedProfileCard(
              profile: profile,
              colors: colors,
              onRestore: () => localReading.restoreProfile(profile.id),
              onDelete: () => localReading.deleteProfile(profile.id),
            ),
          ),
        ],
        if (localReading.recentReadings.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            'Recent Readings',
            style: GoogleFonts.inter(
              color: colors.textStrong,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          ...localReading.recentReadings
              .take(5)
              .map(
                (reading) => _SimpleLinkRow(
                  colors: colors,
                  title: repository.getSurahName(reading.verse.surahId),
                  subtitle:
                      'Ayah ${reading.verse.surahId}:${reading.verse.verseId}',
                  icon: Icons.history,
                  onTap: () => onContinue(
                    context,
                    reading.verse.surahId,
                    verseId: reading.verse.verseId,
                  ),
                ),
              ),
        ],
      ],
    );
  }
}

class _BrowsePage extends StatefulWidget {
  final QuranRepository repository;
  final AppThemeColors colors;
  final String mode;
  final TextEditingController searchController;
  final ValueChanged<String> onModeChanged;
  final void Function(String surahId, String verseId) onOpen;

  const _BrowsePage({
    required this.repository,
    required this.colors,
    required this.mode,
    required this.searchController,
    required this.onModeChanged,
    required this.onOpen,
  });

  @override
  State<_BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends State<_BrowsePage> {
  @override
  Widget build(BuildContext context) {
    final query = widget.searchController.text.toLowerCase();
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
            index < _HomeScreenState._juzStarts.length;
            index++
          )
            (
              id: index + 1,
              startSurah: _HomeScreenState._juzStarts[index][0].toString(),
              startAyah: _HomeScreenState._juzStarts[index][1].toString(),
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: widget.searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search Surah or Juz',
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
        Row(
          children: [
            Expanded(
              child: _TabButton(
                label: 'Surah',
                selected: widget.mode == 'surah',
                colors: widget.colors,
                onTap: () => widget.onModeChanged('surah'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TabButton(
                label: 'Juz',
                selected: widget.mode == 'juz',
                colors: widget.colors,
                onTap: () => widget.onModeChanged('juz'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.mode == 'surah')
          ...surahs.map(
            (surah) => _SimpleLinkRow(
              colors: widget.colors,
              title: surah.name,
              subtitle: '${surah.count} ayat',
              icon: Icons.menu_book_outlined,
              onTap: () => widget.onOpen(surah.id, '1'),
            ),
          )
        else
          ...juz.map(
            (item) => _SimpleLinkRow(
              colors: widget.colors,
              title: 'Juz ${item.id}',
              subtitle:
                  '${widget.repository.getSurahName(item.startSurah)}:${item.startAyah}',
              icon: Icons.view_week_outlined,
              onTap: () => widget.onOpen(item.startSurah, item.startAyah),
            ),
          ),
      ],
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


class _ActionButton extends StatelessWidget {
  final AppThemeColors colors;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.colors,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        backgroundColor: colors.surface,
        foregroundColor: colors.textStrong,
        side: BorderSide(color: colors.borderSoft),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      onPressed: onTap,
      icon: Icon(icon, color: colors.primary),
      label: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final QuranRepository repository;
  final LocalReadingProfile profile;
  final AppThemeColors colors;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onContinue;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;

  const _ProfileCard({
    required this.repository,
    required this.profile,
    required this.colors,
    required this.selected,
    required this.onSelect,
    required this.onContinue,
    this.onEdit,
    this.onArchive,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        onTap: onSelect,
        child: _SectionCard(
          colors: selected
              ? AppThemeColors(
                  background: colors.background,
                  surface: colors.primaryLight,
                  surfaceMuted: colors.surfaceMuted,
                  borderSoft: colors.primary,
                  foreground: colors.foreground,
                  textStrong: colors.textStrong,
                  textInverse: colors.textInverse,
                  primary: colors.primary,
                  primaryHover: colors.primaryHover,
                  primaryLight: colors.primaryLight,
                  primaryLightBorder: colors.primaryLightBorder,
                  accent: colors.accent,
                )
              : colors,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      profile.name,
                      style: GoogleFonts.inter(
                        color: colors.textStrong,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.textInverse,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: onContinue,
                    child: const Text('Continue'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Start ${profile.start.surahId}:${profile.start.verseId}'
                '${profile.target == null ? '' : ' - End ${profile.target!.surahId}:${profile.target!.verseId}'}',
                style: GoogleFonts.inter(
                  color: colors.foreground,
                  fontSize: 12,
                ),
              ),
              Text(
                'Current ${profile.current.surahId}:${profile.current.verseId}',
                style: GoogleFonts.inter(
                  color: colors.foreground,
                  fontSize: 12,
                ),
              ),
              if (onEdit != null || onArchive != null || onDelete != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  children: [
                    if (onEdit != null)
                      _TextAction(
                        label: 'Edit',
                        colors: colors,
                        onTap: onEdit!,
                      ),
                    if (onArchive != null)
                      _TextAction(
                        label: 'Archive',
                        colors: colors,
                        onTap: onArchive!,
                      ),
                    if (onDelete != null)
                      _TextAction(
                        label: 'Delete',
                        colors: colors,
                        danger: true,
                        onTap: onDelete!,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ArchivedProfileCard extends StatelessWidget {
  final LocalReadingProfile profile;
  final AppThemeColors colors;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const _ArchivedProfileCard({
    required this.profile,
    required this.colors,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _SectionCard(
        colors: colors,
        child: Row(
          children: [
            Expanded(
              child: Text(
                profile.name,
                style: GoogleFonts.inter(
                  color: colors.textStrong,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(onPressed: onRestore, child: const Text('Restore')),
            TextButton(
              onPressed: onDelete,
              child: Text(
                'Delete',
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SimpleLinkRow extends StatelessWidget {
  final AppThemeColors colors;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _SimpleLinkRow({
    required this.colors,
    required this.title,
    required this.subtitle,
    required this.icon,
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
              Icon(Icons.chevron_right, color: colors.foreground),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextAction extends StatelessWidget {
  final String label;
  final AppThemeColors colors;
  final bool danger;
  final VoidCallback onTap;

  const _TextAction({
    required this.label,
    required this.colors,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: danger ? Colors.red.shade700 : colors.primary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
