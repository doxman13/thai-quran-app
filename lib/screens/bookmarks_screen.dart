// lib/screens/bookmarks_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/settings_provider.dart';
import '../providers/local_reading_provider.dart';
import '../providers/mushaf_reading_provider.dart';
import '../providers/progress_provider.dart';
import '../data/quran_repository.dart';
import '../data/quran_foundation_repository.dart';
import '../theme/app_theme.dart';
import 'mushaf_reader_screen.dart';
import '../models/mushaf_models.dart';
import 'settings_screen.dart';

class BookmarksScreen extends StatefulWidget {
  final QuranRepository repository;
  const BookmarksScreen({Key? key, required this.repository}) : super(key: key);

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  final QuranFoundationRepository _foundationRepository = QuranFoundationRepository();

  void _openMushaf(String? profileId, int mushafId, {int? pageNumber}) async {
    final provider = context.read<MushafReadingProvider>();
    String targetProfileId = profileId ?? '';
    
    if (targetProfileId.isEmpty || targetProfileId.startsWith('free-read')) {
      final profile = await provider.openFreeRead(mushafId);
      targetProfileId = profile.id;
    } else {
      await provider.setActiveProfile(targetProfileId);
    }
    
    if (pageNumber != null) {
      await provider.updateProgress(profileId: targetProfileId, pageNumber: pageNumber);
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MushafReaderScreen(
          quranRepository: widget.repository,
          foundationRepository: _foundationRepository,
          profileId: targetProfileId,
        ),
      ),
    );
  }

  void _handleMushafRecentTap(MushafRecentReading reading, MushafReadingProvider provider, bool matchesGoal) {
    if (matchesGoal && reading.profileId != null) {
      _openMushaf(reading.profileId, reading.mushafId, pageNumber: reading.pageNumber);
      return;
    }
    _openMushaf(null, reading.mushafId, pageNumber: reading.pageNumber);
  }

  void _handleVerseRecentTap(dynamic reading, LocalReadingProvider provider, bool matchesGoal) {
    final surahId = reading is Map ? reading['surahId'] : reading.verse.surahId;
    final verseId = reading is Map ? reading['verseId']?.toString() : reading.verse.verseId;
    final profileId = reading is Map ? null : reading.profileId;
    final verseIndex = reading is Map ? reading['verseIndex'] : null;
    
    if (matchesGoal && profileId != null && profileId.isNotEmpty) {
      provider.setActiveProfile(profileId).then((_) {
        if (!mounted) return;
        Navigator.pop(context, {
          'surahId': surahId,
          'verseId': verseId,
          'verseIndex': verseIndex,
          'useActiveProfile': true,
        });
      });
      return;
    }
    
    Navigator.pop(context, {
      'surahId': surahId,
      'verseId': verseId,
      'verseIndex': verseIndex,
    });
  }

  void _showSeeMoreDialog(String title, List<Widget> items, ColorScheme colorScheme) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: colorScheme.surface,
          surfaceTintColor: colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radius)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          color: colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: colorScheme.onSurface),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => Divider(height: 1, thickness: 0.5, color: colorScheme.outline.withOpacity(0.3)),
                    itemBuilder: (context, index) => items[index],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSeeMoreButton(String title, List<Widget> allItems, ColorScheme colorScheme) {
    if (allItems.length <= 3) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: OutlinedButton(
        onPressed: () => _showSeeMoreDialog(title, allItems, colorScheme),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: colorScheme.outline, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.primary,
        ),
        child: Text(
          'See more',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildVerseItem(
    ColorScheme colorScheme, {
    required IconData icon,
    required String title,
    required String subtitle,
    String? badgeText,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -4),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      leading: Icon(icon, color: colorScheme.primary, size: 20),
      title: Text(
        title,
        style: GoogleFonts.prompt(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              subtitle,
              style: GoogleFonts.prompt(
                color: colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ),
          if (badgeText != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badgeText,
                style: GoogleFonts.inter(
                  color: colorScheme.onPrimaryContainer,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      onTap: onTap,
      trailing: trailing ?? Icon(Icons.chevron_right, size: 16, color: colorScheme.onSurfaceVariant),
    );
  }

  Widget _buildListGroup(List<Widget> items, ColorScheme colorScheme) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: colorScheme.outline, width: 1),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            items[i],
            if (i < items.length - 1)
              Divider(height: 1, thickness: 0.5, color: colorScheme.outline.withOpacity(0.3)),
          ],
        ],
      ),
    );
  }
  
  Widget _buildHeader(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: colorScheme.outline, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.menu_book, color: colorScheme.onPrimaryContainer, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bookmarks',
                        style: GoogleFonts.inter(
                          color: colorScheme.onSurface,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your reading progress',
                        style: GoogleFonts.inter(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: colorScheme.onSurfaceVariant),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = Provider.of<ProgressProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final localReading = Provider.of<LocalReadingProvider>(context);
    final mushafReading = Provider.of<MushafReadingProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;

    final verseRecentItems = <Widget>[
      _buildVerseItem(
        colorScheme,
        icon: Icons.history,
        title: widget.repository.getSurahName(progress.currentSurahId),
        subtitle: 'อายะฮฺที่: ${progress.lastVerseIndex}',
        onTap: () => _handleVerseRecentTap({
          'surahId': progress.currentSurahId,
          'verseIndex': progress.lastVerseIndex,
        }, localReading, false),
      ),
    ];
    
    if (localReading.recentReadings.isNotEmpty) {
      verseRecentItems.addAll(localReading.recentReadings.map((reading) {
        final profile = reading.profileId != null ? localReading.profiles.where((p) => p.id == reading.profileId).firstOrNull : null;
        bool matchesGoal = false;
        if (profile != null) {
          matchesGoal = (profile.current.surahId == reading.verse.surahId && profile.current.verseId == reading.verse.verseId);
        }

        return _buildVerseItem(
          colorScheme,
          icon: Icons.history,
          title: widget.repository.getSurahName(reading.verse.surahId),
          subtitle: 'อายะฮฺที่ ${reading.verse.surahId}:${reading.verse.verseId}',
          badgeText: matchesGoal ? profile?.name : null,
          onTap: () => _handleVerseRecentTap(reading, localReading, matchesGoal),
        );
      }));
    }

    final mushafRecentItems = mushafReading.recentReadings.map((reading) {
      final surahName = getSurahNameForPage(reading.pageNumber, widget.repository);
      final profile = reading.profileId != null ? mushafReading.profileById(reading.profileId!) : null;
      
      bool matchesGoal = false;
      if (profile != null && profile.currentPage == reading.pageNumber) {
        matchesGoal = true;
      }

      return _buildVerseItem(
        colorScheme,
        icon: Icons.import_contacts,
        title: 'Mushaf (Page ${reading.pageNumber})',
        subtitle: surahName,
        badgeText: matchesGoal ? profile?.name : null,
        onTap: () => _handleMushafRecentTap(reading, mushafReading, matchesGoal),
      );
    }).toList();

    final verseBookmarkItems = localReading.bookmarks.map((bookmark) {
      final rawSurahId = int.parse(bookmark.verse.surahId).toString();
      final rawVerseId = bookmark.verse.verseId;
      return _buildVerseItem(
        colorScheme,
        icon: Icons.bookmark,
        title: '${widget.repository.getSurahName(rawSurahId)}, อายะฮฺที่ $rawVerseId',
        subtitle: 'Surah $rawSurahId, Verse $rawVerseId',
        onTap: () {
          Navigator.pop(context, {
            'surahId': rawSurahId,
            'verseId': rawVerseId,
          });
        },
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: colorScheme.error, size: 24),
          onPressed: () => localReading.removeBookmark(bookmark.id),
        ),
      );
    }).toList();

    final mushafBookmarkItems = mushafReading.pageBookmarks.map((bookmark) {
      final surahName = getSurahNameForPage(bookmark.pageNumber, widget.repository);
      return _buildVerseItem(
        colorScheme,
        icon: Icons.bookmark_border,
        title: 'Page ${bookmark.pageNumber}',
        subtitle: surahName,
        onTap: () => _openMushaf(null, bookmark.mushafId, pageNumber: bookmark.pageNumber),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: colorScheme.error, size: 24),
          onPressed: () => mushafReading.togglePageBookmark(bookmark.mushafId, bookmark.pageNumber),
        ),
      );
    }).toList();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Column(
        children: [
          _buildHeader(colorScheme),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 32),
              children: [
                if (verseRecentItems.isNotEmpty) ...[
                  _buildSectionTitle('Recent Verse-by-Verse', colorScheme),
                  _buildListGroup(verseRecentItems.take(3).toList(), colorScheme),
                  _buildSeeMoreButton('Recent Verse-by-Verse', verseRecentItems, colorScheme),
                ],
                
                if (mushafRecentItems.isNotEmpty) ...[
                  _buildSectionTitle('Recent Mushaf Pages', colorScheme),
                  _buildListGroup(mushafRecentItems.take(3).toList(), colorScheme),
                  _buildSeeMoreButton('Recent Mushaf Pages', mushafRecentItems, colorScheme),
                ],

                _buildSectionTitle('Saved Verses (Verse-by-Verse)', colorScheme),
                if (verseBookmarkItems.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Text(
                      'No saved verses yet.',
                      style: GoogleFonts.inter(color: colorScheme.onSurfaceVariant, fontSize: 14),
                    ),
                  )
                else ...[
                  _buildListGroup(verseBookmarkItems.take(3).toList(), colorScheme),
                  _buildSeeMoreButton('Saved Verses', verseBookmarkItems, colorScheme),
                ],

                if (mushafBookmarkItems.isNotEmpty) ...[
                  _buildSectionTitle('Saved Mushaf Pages', colorScheme),
                  _buildListGroup(mushafBookmarkItems.take(3).toList(), colorScheme),
                  _buildSeeMoreButton('Saved Mushaf Pages', mushafBookmarkItems, colorScheme),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
