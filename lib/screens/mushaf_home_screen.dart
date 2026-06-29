import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../data/quran_foundation_repository.dart';
import '../data/quran_repository.dart';
import '../models/mushaf_models.dart';
import '../providers/mushaf_reading_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import 'mushaf_reader_screen.dart';

class MushafHomeScreen extends StatefulWidget {
  final QuranRepository quranRepository;

  const MushafHomeScreen({Key? key, required this.quranRepository})
    : super(key: key);

  @override
  State<MushafHomeScreen> createState() => _MushafHomeScreenState();
}

class _MushafHomeScreenState extends State<MushafHomeScreen> {
  final QuranFoundationRepository _foundationRepository =
      QuranFoundationRepository();

  Future<void> _openProfile(String profileId) async {
    await context.read<MushafReadingProvider>().setActiveProfile(profileId);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MushafReaderScreen(
          quranRepository: widget.quranRepository,
          foundationRepository: _foundationRepository,
          profileId: profileId,
        ),
      ),
    );
  }

  Future<void> _openFreeRead(int mushafId) async {
    final profile = await context.read<MushafReadingProvider>().openFreeRead(
      mushafId,
    );
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MushafReaderScreen(
          quranRepository: widget.quranRepository,
          foundationRepository: _foundationRepository,
          profileId: profile.id,
        ),
      ),
    );
  }

  Future<void> _openFreeReadPage(int mushafId, int pageNumber) async {
    final provider = context.read<MushafReadingProvider>();
    final profile = await provider.openFreeRead(mushafId);
    await provider.updateProgress(
      profileId: profile.id,
      pageNumber: pageNumber,
    );
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MushafReaderScreen(
          quranRepository: widget.quranRepository,
          foundationRepository: _foundationRepository,
          profileId: profile.id,
        ),
      ),
    );
  }

  Future<void> _showCreateProfileDialog() async {
    final provider = context.read<MushafReadingProvider>();
    final colors = context.read<SettingsProvider>().getAppColors();
    if (!provider.canCreateProfile) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only 3 active Mushaf profiles allowed.')),
      );
      return;
    }

    final nameController = TextEditingController();
    final mushafId = provider.displayMushafId; // Use active mushaf silently
    var mode = 'page_range';
    var startPage = 1;
    var endPage = 10;
    var startSurah = 1;
    var endSurah = 1;
    var startJuz = 1;
    var endJuz = 1;
    String? error;
    var isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final type = mushafTypeById(mushafId);
            startPage = _clampInt(startPage, 1, type.pageCount);
            endPage = _clampInt(endPage, startPage, type.pageCount);

            Future<void> save() async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                setDialogState(() => error = 'Enter a profile name first.');
                return;
              }
              setDialogState(() {
                error = null;
                isSaving = true;
              });
              try {
                int finalStart = 1;
                int finalEnd = 10;

                if (mode == 'page_range') {
                  finalStart = startPage;
                  finalEnd = endPage;
                } else if (mode == 'by_surah') {
                  finalStart = getStartPageForSurah(startSurah);
                  finalEnd = _endPageForSurah(endSurah, type.pageCount);
                } else if (mode == 'by_juz') {
                  finalStart = _startPageForJuz(startJuz);
                  finalEnd = _endPageForJuz(endJuz, type.pageCount);
                } else {
                  finalStart = 1;
                  finalEnd = type.pageCount;
                }

                await provider.createPageRangeProfile(
                  name: name,
                  mushafId: mushafId,
                  startPage: finalStart,
                  targetPage: finalEnd,
                  planMode: mode == 'complete' ? 'complete' : mode,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (saveError) {
                setDialogState(() {
                  error = saveError.toString();
                  isSaving = false;
                });
              }
            }

            return AlertDialog(
              backgroundColor: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                side: BorderSide(color: colors.borderSoft),
              ),
              title: Text(
                'Create by...',
                style: GoogleFonts.inter(fontWeight: FontWeight.w900),
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
                        hintText: 'Qiyam',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: mode,
                      decoration: const InputDecoration(labelText: 'Create by'),
                      items: const [
                        DropdownMenuItem(
                          value: 'page_range',
                          child: Text('Page Range'),
                        ),
                        DropdownMenuItem(
                          value: 'by_surah',
                          child: Text('Surah (range)'),
                        ),
                        DropdownMenuItem(
                          value: 'by_juz',
                          child: Text('Juz (range)'),
                        ),
                        DropdownMenuItem(
                          value: 'complete',
                          child: Text('Complete Quran'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setDialogState(() => mode = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    if (mode == 'page_range')
                      Row(
                        children: [
                          Expanded(
                            child: _numberField(
                              label: 'Start page',
                              initialValue: startPage,
                              max: type.pageCount,
                              onChanged: (value) {
                                setDialogState(() {
                                  startPage = value;
                                  if (endPage < startPage) endPage = startPage;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _numberField(
                              label: 'End page',
                              initialValue: endPage,
                              min: startPage,
                              max: type.pageCount,
                              onChanged: (value) =>
                                  setDialogState(() => endPage = value),
                            ),
                          ),
                        ],
                      )
                    else if (mode == 'by_surah')
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: startSurah,
                              decoration: const InputDecoration(
                                labelText: 'Start Surah',
                              ),
                              items: List.generate(114, (index) {
                                final id = index + 1;
                                return DropdownMenuItem(
                                  value: id,
                                  child: Text(
                                    widget.quranRepository.getSurahName('$id'),
                                  ),
                                );
                              }),
                              onChanged: (value) {
                                if (value != null) {
                                  setDialogState(() {
                                    startSurah = value;
                                    if (endSurah < startSurah) {
                                      endSurah = startSurah;
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: endSurah,
                              decoration: const InputDecoration(
                                labelText: 'End Surah',
                              ),
                              items: List.generate(114, (index) {
                                final id = index + 1;
                                return DropdownMenuItem(
                                  value: id,
                                  enabled: id >= startSurah,
                                  child: Text(
                                    widget.quranRepository.getSurahName('$id'),
                                  ),
                                );
                              }),
                              onChanged: (value) {
                                if (value != null) {
                                  setDialogState(() => endSurah = value);
                                }
                              },
                            ),
                          ),
                        ],
                      )
                    else if (mode == 'by_juz')
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: startJuz,
                              decoration: const InputDecoration(
                                labelText: 'Start Juz',
                              ),
                              items: List.generate(30, (index) {
                                final id = index + 1;
                                return DropdownMenuItem(
                                  value: id,
                                  child: Text('Juz $id'),
                                );
                              }),
                              onChanged: (value) {
                                if (value != null) {
                                  setDialogState(() {
                                    startJuz = value;
                                    if (endJuz < startJuz) endJuz = startJuz;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: endJuz,
                              decoration: const InputDecoration(
                                labelText: 'End Juz',
                              ),
                              items: List.generate(30, (index) {
                                final id = index + 1;
                                return DropdownMenuItem(
                                  value: id,
                                  enabled: id >= startJuz,
                                  child: Text('Juz $id'),
                                );
                              }),
                              onChanged: (value) {
                                if (value != null) {
                                  setDialogState(() => endJuz = value);
                                }
                              },
                            ),
                          ),
                        ],
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Target: Complete Quran (1 - ${type.pageCount} pages)',
                          style: GoogleFonts.inter(
                            color: colors.foreground,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
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
                  onPressed: isSaving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSaving ? null : save,
                  child: Text(isSaving ? 'Creating...' : 'Create'),
                ),
              ],
            );
          },
        );
      },
    );
    nameController.dispose();
  }

  Widget _numberField({
    required String label,
    required int initialValue,
    int min = 1,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return TextFormField(
      initialValue: initialValue.toString(),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      onChanged: (value) {
        final parsed = int.tryParse(value);
        if (parsed == null) return;
        onChanged(_clampInt(parsed, min, max));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final colors = settings.getAppColors();
    final provider = Provider.of<MushafReadingProvider>(context);

    if (!provider.isLoaded) {
      return Center(child: CircularProgressIndicator(color: colors.primary));
    }

    final active = provider.activeProfile;
    final profiles = provider.activeCustomProfiles;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Mushaf Read',
                style: GoogleFonts.inter(
                  color: colors.textStrong,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: provider.canCreateProfile
                  ? _showCreateProfileDialog
                  : null,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Profile'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Continue your Mushaf reading, return to saved pages, or keep a dedicated page-range profile.',
          style: GoogleFonts.inter(
            color: colors.foreground,
            fontSize: 13,
            height: 1.45,
          ),
        ),
        if (active != null) ...[
          const SizedBox(height: 16),
          _ContinueCard(
            colors: colors,
            profile: active,
            onTap: () => _openProfile(active.id),
            quranRepository: widget.quranRepository,
          ),
        ],
        if (profiles.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            'Mushaf Profiles',
            style: GoogleFonts.inter(
              color: colors.textStrong,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          ...profiles.map(
            (profile) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ProfileCard(
                colors: colors,
                profile: profile,
                selected: profile.id == active?.id,
                onContinue: () => _openProfile(profile.id),
                onArchive: () => provider.archiveProfile(profile.id),
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _openFreeRead(active?.mushafId ?? 1),
                icon: const Icon(Icons.menu_book_outlined, size: 18),
                label: const Text('Just Read'),
              ),
            ),
          ],
        ),
        if (provider.pageBookmarks.isNotEmpty) ...[
          const SizedBox(height: 18),
          _SectionTitle(colors: colors, title: 'Page Bookmarks'),
          const SizedBox(height: 10),
          ...provider.pageBookmarks
              .take(6)
              .map(
                (bookmark) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ReadingListTile(
                    colors: colors,
                    icon: Icons.bookmark,
                    title: getSurahNameForPage(
                      bookmark.pageNumber,
                      widget.quranRepository,
                    ),
                    subtitle: 'Page ${bookmark.pageNumber}',
                    onTap: () => _openFreeReadPage(
                      bookmark.mushafId,
                      bookmark.pageNumber,
                    ),
                  ),
                ),
              ),
        ],
        if (provider.verseBookmarks.isNotEmpty) ...[
          const SizedBox(height: 18),
          _SectionTitle(colors: colors, title: 'Verse Bookmarks'),
          const SizedBox(height: 10),
          ...provider.verseBookmarks
              .take(6)
              .map(
                (bookmark) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Builder(
                    builder: (context) {
                      final parts = bookmark.verseKey.split(':');
                      final sName = parts.length == 2
                          ? widget.quranRepository.getSurahName(parts[0])
                          : 'Surah';
                      final vNum = parts.length == 2 ? parts[1] : '';
                      return _ReadingListTile(
                        colors: colors,
                        icon: Icons.bookmark_border,
                        title: '$sName, Ayah $vNum',
                        subtitle: 'Page ${bookmark.pageNumber}',
                        onTap: () => _openFreeReadPage(
                          bookmark.mushafId,
                          bookmark.pageNumber,
                        ),
                      );
                    },
                  ),
                ),
              ),
        ],
        if (provider.recentReadings.isNotEmpty) ...[
          const SizedBox(height: 18),
          _SectionTitle(colors: colors, title: 'Recent Reads'),
          const SizedBox(height: 10),
          ...provider.recentReadings
              .take(6)
              .map(
                (reading) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Builder(
                    builder: (context) {
                      final sName = getSurahNameForPage(
                        reading.pageNumber,
                        widget.quranRepository,
                      );
                      final profName = reading.profileId == null
                          ? 'Free Read'
                          : provider.profileById(reading.profileId)?.name ??
                                'Mushaf';
                      return _ReadingListTile(
                        colors: colors,
                        icon: Icons.history,
                        title: sName,
                        subtitle: 'Page ${reading.pageNumber} • $profName',
                        onTap: () => _openFreeReadPage(
                          reading.mushafId,
                          reading.pageNumber,
                        ),
                      );
                    },
                  ),
                ),
              ),
        ],
      ],
    );
  }
}

int _clampInt(int value, int min, int max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

int _endPageForSurah(int surahNumber, int pageCount) {
  if (surahNumber >= 114) return pageCount;
  return _clampInt(getStartPageForSurah(surahNumber + 1) - 1, 1, pageCount);
}

int _startPageForJuz(int juzNumber) {
  const juzStartPages = [
    1,
    22,
    42,
    62,
    82,
    102,
    121,
    142,
    162,
    182,
    201,
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
  if (juzNumber < 1 || juzNumber > 30) return 1;
  return juzStartPages[juzNumber - 1];
}

int _endPageForJuz(int juzNumber, int pageCount) {
  if (juzNumber >= 30) return pageCount;
  return _clampInt(_startPageForJuz(juzNumber + 1) - 1, 1, pageCount);
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
    507,
    511,
    515,
    518,
    520,
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
    587,
    589,
    590,
    591,
    591,
    592,
    593,
    594,
    595,
    595,
    596,
    596,
    597,
    597,
    598,
    598,
    599,
    599,
    600,
    600,
    601,
    601,
    601,
    602,
    602,
    602,
    603,
    603,
    603,
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

class _ContinueCard extends StatelessWidget {
  final AppThemeColors colors;
  final MushafProfile profile;
  final VoidCallback onTap;
  final QuranRepository quranRepository;

  const _ContinueCard({
    required this.colors,
    required this.profile,
    required this.onTap,
    required this.quranRepository,
  });

  @override
  Widget build(BuildContext context) {
    final surahName = getSurahNameForPage(profile.currentPage, quranRepository);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      profile.name.toUpperCase(),
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
            surahName,
            style: GoogleFonts.inter(
              color: colors.textInverse,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Page ${profile.currentPage}',
            style: GoogleFonts.inter(
              color: colors.textInverse.withOpacity(0.85),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
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
              onPressed: onTap,
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
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final AppThemeColors colors;
  final MushafProfile profile;
  final bool selected;
  final VoidCallback onContinue;
  final VoidCallback onArchive;

  const _ProfileCard({
    required this.colors,
    required this.profile,
    required this.selected,
    required this.onContinue,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    final total = profile.targetPage - profile.startPage + 1;
    final done = profile.currentPage - profile.startPage + 1;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(
          color: selected ? colors.primary : colors.borderSoft,
          width: selected ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: GoogleFonts.inter(
                    color: colors.textStrong,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pages ${profile.startPage}-${profile.targetPage} - $done / $total',
                  style: GoogleFonts.inter(
                    color: colors.foreground,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Archive',
            onPressed: onArchive,
            icon: const Icon(Icons.archive_outlined),
          ),
          FilledButton(onPressed: onContinue, child: const Text('Continue')),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final AppThemeColors colors;
  final String title;

  const _SectionTitle({required this.colors, required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.inter(
        color: colors.textStrong,
        fontSize: 15,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _ReadingListTile extends StatelessWidget {
  final AppThemeColors colors;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ReadingListTile({
    required this.colors,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.borderSoft),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: colors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: colors.textStrong,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: colors.foreground,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
