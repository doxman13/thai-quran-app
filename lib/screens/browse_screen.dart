import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../data/quran_repository.dart';
import '../providers/local_reading_provider.dart';
import '../theme/app_theme.dart';
import '../shared/quran_contract.dart';

class BrowseScreen extends StatefulWidget {
  final QuranRepository repository;
  final AppThemeColors colors;
  
  
  
  final void Function(String surahId, String verseId) onOpen;
  final ValueChanged<int> onOpenPage;

  const BrowseScreen({
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
    final query = _searchController.text.toLowerCase();
    final completedSurahs = _completedSurahs(
      context.watch<LocalReadingProvider>(),
    );
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search Surah, Juz, or Page',
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
                selected: _mode == 'surah',
                colors: widget.colors,
                onTap: () => _setMode('surah'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TabButton(
                label: 'Juz',
                selected: _mode == 'juz',
                colors: widget.colors,
                onTap: () => _setMode('juz'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TabButton(
                label: 'Page',
                selected: _mode == 'page',
                colors: widget.colors,
                onTap: () => _setMode('page'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_mode == 'surah')
          ...surahs.map(
            (surah) => _SimpleLinkRow(
              colors: widget.colors,
              title: surah.name,
              subtitle: '${surah.count} ayat',
              icon: Icons.menu_book_outlined,
              completed: completedSurahs.contains(surah.id),
              onTap: () => widget.onOpen(surah.id, '1'),
            ),
          )
        else if (_mode == 'juz')
          ...juz.map(
            (item) => _SimpleLinkRow(
              colors: widget.colors,
              title: 'Juz ${item.id}',
              subtitle:
                  '${widget.repository.getSurahName(item.startSurah)}:${item.startAyah}',
              icon: Icons.view_week_outlined,
              onTap: () => widget.onOpen(item.startSurah, item.startAyah),
            ),
          )
        else
          _PageNumberGrid(
            colors: widget.colors,
            pages: pages,
            onOpenPage: widget.onOpenPage,
          ),
      ],
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
            'Page $page',
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

