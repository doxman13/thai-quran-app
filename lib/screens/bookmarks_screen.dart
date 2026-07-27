// lib/screens/bookmarks_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qcf_quran/qcf_quran.dart' as qcf;

import '../providers/local_reading_provider.dart';
import '../providers/mushaf_reading_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../data/quran_repository.dart';
import '../data/quran_foundation_repository.dart';
import '../theme/app_theme.dart';
import 'mushaf_reader_screen.dart';
import '../models/mushaf_models.dart';
import 'reading_screen.dart';
import 'tadabbur_community_screen.dart';
import '../shared/shared.dart';

class BookmarksScreen extends StatefulWidget {
  final QuranRepository repository;
  final VoidCallback? onBackToHome;
  const BookmarksScreen({super.key, required this.repository, this.onBackToHome});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  final QuranFoundationRepository _foundationRepository =
      QuranFoundationRepository();
  static const int _displayLimit = 3;
  int _selectedMenuIndex = 0;

  void _openReading({
    required String surahId,
    String? verseId,
    int? verseIndex,
    bool saveToFreeReadOnly = false,
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
          saveToFreeReadOnly: saveToFreeReadOnly,
        ),
      ),
    );
  }

  void _openMushaf(
    String? profileId,
    int mushafId, {
    int? pageNumber,
    String? highlightedVerseKey,
  }) async {
    final provider = context.read<MushafReadingProvider>();
    String targetProfileId = profileId ?? '';

    final isFreeReadId =
        targetProfileId.startsWith('free-read') ||
        targetProfileId.startsWith('mushaf-free');
    if (targetProfileId.isEmpty || isFreeReadId) {
      final profile = await provider.openUnifiedFreeRead();
      targetProfileId = profile.id;
    } else if (provider.profileById(targetProfileId) != null) {
      await provider.setActiveProfile(targetProfileId);
    } else {
      final profile = await provider.openUnifiedFreeRead();
      targetProfileId = profile.id;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MushafReaderScreen(
          quranRepository: widget.repository,
          foundationRepository: _foundationRepository,
          profileId: targetProfileId,
          initialPage: pageNumber,
          initialHighlightVerseKey: highlightedVerseKey,
        ),
      ),
    );
  }

  void _handleMushafRecentTap(
    MushafRecentReading reading,
    MushafReadingProvider provider,
  ) {
    if (reading.profileId != null &&
        provider.profileById(reading.profileId!) != null) {
      _openMushaf(
        reading.profileId,
        reading.mushafId,
        pageNumber: reading.pageNumber,
      );
      return;
    }
    _openMushaf(null, reading.mushafId, pageNumber: reading.pageNumber);
  }

  void _handleVerseRecentTap(
    dynamic reading,
    LocalReadingProvider provider,
  ) async {
    final surahId =
        (reading is Map ? reading['surahId'] : reading.verse.surahId)
            ?.toString();
    final verseId = reading is Map
        ? reading['verseId']?.toString()
        : reading.verse.verseId;
    final profileId = reading is Map ? null : reading.profileId;
    final verseIndex = reading is Map ? reading['verseIndex'] : null;
    if (surahId == null || surahId.isEmpty) return;

    final hasProfile =
        profileId != null &&
        profileId.isNotEmpty &&
        provider.profiles.any((profile) => profile.id == profileId);
    if (hasProfile) {
      await provider.setActiveProfile(profileId);
      if (!mounted) return;
      _openReading(surahId: surahId, verseId: verseId, verseIndex: verseIndex);
      return;
    }

    _openReading(
      surahId: surahId,
      verseId: verseId,
      verseIndex: verseIndex,
      saveToFreeReadOnly: true,
    );
  }

  void _showSeeMoreDialog(
    String title,
    List<Widget> items,
    ColorScheme colorScheme,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: colorScheme.surface,
          surfaceTintColor: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.notoSansThai(
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
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      thickness: 0.5,
                      color: colorScheme.outline.withValues(alpha: 0.3),
                    ),
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
        style: GoogleFonts.notoSansThai(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSeeMoreButton(
    String title,
    List<Widget> allItems,
    ColorScheme colorScheme,
  ) {
    if (allItems.length <= _displayLimit) return const SizedBox.shrink();
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
          context.tr('see_more'),
          style: GoogleFonts.notoSansThai(fontWeight: FontWeight.w700, fontSize: 13),
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
        style: GoogleFonts.notoSansThai(
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
              style: GoogleFonts.notoSansThai(
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
                style: GoogleFonts.notoSansThai(
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
      trailing:
          trailing ??
          Icon(
            Icons.chevron_right,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
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
              Divider(
                height: 1,
                thickness: 0.5,
                color: colorScheme.outline.withValues(alpha: 0.3),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme, bool isThai) {
    final canPop = Navigator.canPop(context);
    final hasBackAction = canPop || widget.onBackToHome != null;

    final String titleText = _selectedMenuIndex == 2
        ? (isThai ? 'บันทึกส่วนตัว' : 'Personal Notes')
        : context.tr('bookmarks');
    final String subtitleText = _selectedMenuIndex == 2
        ? (isThai ? 'บันทึกและความคิดเห็นของคุณ' : 'Your personal notes and thoughts')
        : context.tr('reading_progress');
    final IconData headerIcon = _selectedMenuIndex == 2
        ? Icons.edit_note_rounded
        : Icons.bookmark;

    return Container(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 24, 24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: colorScheme.outline, width: 1),
        ),
      ),
      child: Row(
        children: [
          if (hasBackAction) ...[
            IconButton(
              icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
              onPressed: () {
                if (canPop) {
                  Navigator.pop(context);
                } else if (widget.onBackToHome != null) {
                  widget.onBackToHome!();
                }
              },
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleText,
                  style: GoogleFonts.notoSansThai(
                    color: colorScheme.primary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitleText,
                  style: GoogleFonts.notoSansThai(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Icon(
            headerIcon,
            color: colorScheme.primary,
            size: 36,
          ),
        ],
      ),
    );
  }

  Widget _buildCapsuleSelector(ColorScheme colorScheme, bool isThai) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildCapsuleOption(
              label: context.tr('meaningful_read'),
              isSelected: _selectedMenuIndex == 0,
              onTap: () => setState(() => _selectedMenuIndex = 0),
              colorScheme: colorScheme,
            ),
          ),
          Expanded(
            child: _buildCapsuleOption(
              label: context.tr('mushaf_read'),
              isSelected: _selectedMenuIndex == 1,
              onTap: () => setState(() => _selectedMenuIndex = 1),
              colorScheme: colorScheme,
            ),
          ),
          Expanded(
            child: _buildCapsuleOption(
              label: isThai ? 'บันทึก' : 'Notes',
              isSelected: _selectedMenuIndex == 2,
              onTap: () => setState(() => _selectedMenuIndex = 2),
              colorScheme: colorScheme,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapsuleOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withAlpha(50),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.notoSansThai(
              color: isSelected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = Provider.of<ProgressProvider>(context);
    final localReading = Provider.of<LocalReadingProvider>(context);
    final mushafReading = Provider.of<MushafReadingProvider>(context);
    final notesProv = Provider.of<NotesProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final isThai = settings.languageCode == 'th';
    final primaryColor = settings.getPrimaryColor();

    final verseRecentItems = <Widget>[
      _buildVerseItem(
        colorScheme,
        icon: Icons.history,
        title: widget.repository.getSurahName(progress.currentSurahId),
        subtitle: 'อายะฮฺที่: ${progress.lastVerseIndex}',
        onTap: () => _handleVerseRecentTap({
          'surahId': progress.currentSurahId,
          'verseIndex': progress.lastVerseIndex,
        }, localReading),
      ),
    ];

    if (localReading.recentReadings.isNotEmpty) {
      verseRecentItems.addAll(
        localReading.recentReadings.map((reading) {
          final profile = reading.profileId != null
              ? localReading.profiles
                    .where((p) => p.id == reading.profileId)
                    .firstOrNull
              : null;
          return _buildVerseItem(
            colorScheme,
            icon: Icons.history,
            title: widget.repository.getSurahName(reading.verse.surahId),
            subtitle: context.tr(
              'ayah_number',
              args: {
                'number': '${reading.verse.surahId}:${reading.verse.verseId}',
              },
            ),
            badgeText: profile?.name,
            onTap: () => _handleVerseRecentTap(reading, localReading),
          );
        }),
      );
    }

    final mushafRecentItems = mushafReading.recentReadings.map((reading) {
      final surahName = getSurahNameForPage(
        reading.pageNumber,
        widget.repository,
      );
      final profile = reading.profileId != null
          ? mushafReading.profileById(reading.profileId!)
          : null;

      return _buildVerseItem(
        colorScheme,
        icon: Icons.import_contacts,
        title: 'Mushaf (${context.tr('page')} ${reading.pageNumber})',
        subtitle: surahName,
        badgeText: profile?.name,
        onTap: () => _handleMushafRecentTap(reading, mushafReading),
      );
    }).toList();

    final verseBookmarkItems = localReading.bookmarks.map((bookmark) {
      final rawSurahId = int.parse(bookmark.verse.surahId).toString();
      final rawVerseId = bookmark.verse.verseId;
      final sId = int.tryParse(rawSurahId) ?? 1;
      final vId = int.tryParse(rawVerseId) ?? 1;
      final pageNumber = qcf.getPageNumber(sId, vId);

      return _buildVerseItem(
        colorScheme,
        icon: Icons.bookmark,
        title:
            '${widget.repository.getSurahName(rawSurahId)}, ${context.tr('ayah_number', args: {'number': rawVerseId})}',
        subtitle:
            '${context.tr('surah_number', args: {'number': rawSurahId})}, ${context.tr('ayah_number', args: {'number': rawVerseId})}',
        onTap: () {
          if (_selectedMenuIndex == 1) {
            _openMushaf(
              null,
              2,
              pageNumber: pageNumber,
              highlightedVerseKey: '$rawSurahId:$rawVerseId',
            );
          } else {
            _openReading(
              surahId: rawSurahId,
              verseId: rawVerseId,
              saveToFreeReadOnly: true,
            );
          }
        },
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => _openMushaf(
                null,
                2,
                pageNumber: pageNumber,
                highlightedVerseKey: '$rawSurahId:$rawVerseId',
              ),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.import_contacts, size: 12, color: colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      'มุศหัฟ',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: colorScheme.error, size: 22),
              onPressed: () => localReading.removeBookmark(bookmark.id),
            ),
          ],
        ),
      );
    }).toList();

    final mushafBookmarkItems = mushafReading.pageBookmarks.map((bookmark) {
      final surahName = getSurahNameForPage(
        bookmark.pageNumber,
        widget.repository,
      );
      return _buildVerseItem(
        colorScheme,
        icon: Icons.bookmark_border,
        title: '${context.tr('page')} ${bookmark.pageNumber}',
        subtitle: surahName,
        onTap: () => _openMushaf(
          null,
          bookmark.mushafId,
          pageNumber: bookmark.pageNumber,
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: colorScheme.error, size: 24),
          onPressed: () => mushafReading.togglePageBookmark(
            bookmark.mushafId,
            bookmark.pageNumber,
          ),
        ),
      );
    }).toList();

    final mushafVerseBookmarkItems = mushafReading.verseBookmarks.map((bookmark) {
      final parts = bookmark.verseKey.split(':');
      final surahId = parts.isNotEmpty ? parts[0] : '';
      final verseId = parts.length > 1 ? parts[1] : '';
      final formattedSurahName = widget.repository.getSurahName(surahId);

      return _buildVerseItem(
        colorScheme,
        icon: Icons.bookmark_border,
        title: '$formattedSurahName, ${context.tr('ayah_number', args: {'number': verseId})}',
        subtitle: '${context.tr('page')} ${bookmark.pageNumber}',
        onTap: () => _openMushaf(
          null,
          bookmark.mushafId,
          pageNumber: bookmark.pageNumber,
          highlightedVerseKey: bookmark.verseKey,
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: colorScheme.error, size: 24),
          onPressed: () => mushafReading.toggleVerseBookmark(
            mushafId: bookmark.mushafId,
            pageNumber: bookmark.pageNumber,
            verseKey: bookmark.verseKey,
          ),
        ),
      );
    }).toList();

    // Notes Entries
    final noteEntries = notesProv.personalNotes.entries.toList()
      ..sort((a, b) {
        final aParts = a.key.split(':');
        final bParts = b.key.split(':');
        final aSurah = int.tryParse(aParts[0]) ?? 0;
        final bSurah = int.tryParse(bParts[0]) ?? 0;
        if (aSurah != bSurah) return aSurah.compareTo(bSurah);
        final aVerse = int.tryParse(aParts[1]) ?? 0;
        final bVerse = int.tryParse(bParts[1]) ?? 0;
        return aVerse.compareTo(bVerse);
      });

    // Helper functions for Note Cards & Community banner
    Widget buildCommunityLinkCard() {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.primary,
              colorScheme.primary.withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TadabburCommunityScreen(
                    repository: widget.repository,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.forum_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isThai ? 'แบ่งปันตดับบุรในชุมชน' : 'Share Tadabbur in Community',
                          style: GoogleFonts.notoSansThai(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isThai
                              ? 'อ่านบันทึกและแบ่งปันความคิดร่วมกับพี่น้องในชุมชน'
                              : 'Read and share reflections with the community',
                          style: GoogleFonts.notoSansThai(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    Widget buildNoteCard(
      String surahName,
      String surahId,
      String verseId,
      String noteContent,
      VoidCallback onTap,
      VoidCallback onDelete,
    ) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_note_rounded,
                              size: 14, color: colorScheme.onPrimaryContainer),
                          const SizedBox(width: 6),
                          Text(
                            '$surahName $surahId:$verseId',
                            style: GoogleFonts.notoSansThai(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.delete_outline_rounded,
                          color: colorScheme.error, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: onDelete,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border(
                      left: BorderSide(color: primaryColor, width: 3),
                    ),
                  ),
                  child: Text(
                    noteContent,
                    style: GoogleFonts.notoSansThai(
                      fontSize: 14,
                      color: colorScheme.onSurface,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      isThai ? 'แตะเพื่อเปิดอ่านอายะฮ์' : 'Tap to read verse',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 11,
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded,
                        size: 12, color: colorScheme.primary),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Column(
        children: [
          _buildHeader(colorScheme, isThai),
          _buildCapsuleSelector(colorScheme, isThai),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 32),
              children: [
                if (_selectedMenuIndex == 0) ...[
                  if (verseRecentItems.isNotEmpty) ...[
                    _buildSectionTitle(context.tr('recent_verse'), colorScheme),
                    _buildListGroup(
                      verseRecentItems.take(_displayLimit).toList(),
                      colorScheme,
                    ),
                    _buildSeeMoreButton(
                      context.tr('recent_verse'),
                      verseRecentItems,
                      colorScheme,
                    ),
                  ],
                  _buildSectionTitle(context.tr('saved_verses'), colorScheme),
                  if (verseBookmarkItems.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Text(
                        context.tr('no_saved_verses'),
                        style: GoogleFonts.notoSansThai(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    )
                  else ...[
                    _buildListGroup(
                      verseBookmarkItems.take(_displayLimit).toList(),
                      colorScheme,
                    ),
                    _buildSeeMoreButton(
                      context.tr('saved_verses'),
                      verseBookmarkItems,
                      colorScheme,
                    ),
                  ],
                ] else if (_selectedMenuIndex == 1) ...[
                  if (mushafRecentItems.isNotEmpty) ...[
                    _buildSectionTitle(context.tr('recent_mushaf'), colorScheme),
                    _buildListGroup(
                      mushafRecentItems.take(_displayLimit).toList(),
                      colorScheme,
                    ),
                    _buildSeeMoreButton(
                      context.tr('recent_mushaf'),
                      mushafRecentItems,
                      colorScheme,
                    ),
                  ],

                  if (mushafBookmarkItems.isEmpty && mushafVerseBookmarkItems.isEmpty) ...[
                    _buildSectionTitle(context.tr('saved_mushaf'), colorScheme),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Text(
                        context.tr('no_bookmarks'),
                        style: GoogleFonts.notoSansThai(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ] else ...[
                    if (mushafBookmarkItems.isNotEmpty) ...[
                      _buildSectionTitle(context.tr('saved_mushaf'), colorScheme),
                      _buildListGroup(
                        mushafBookmarkItems.take(_displayLimit).toList(),
                        colorScheme,
                      ),
                      _buildSeeMoreButton(
                        context.tr('saved_mushaf'),
                        mushafBookmarkItems,
                        colorScheme,
                      ),
                    ],

                    if (mushafVerseBookmarkItems.isNotEmpty) ...[
                      _buildSectionTitle(context.tr('saved_verses'), colorScheme),
                      _buildListGroup(
                        mushafVerseBookmarkItems.take(_displayLimit).toList(),
                        colorScheme,
                      ),
                      _buildSeeMoreButton(
                        context.tr('saved_verses'),
                        mushafVerseBookmarkItems,
                        colorScheme,
                      ),
                    ],
                  ],
                ] else if (_selectedMenuIndex == 2) ...[
                  // Community Link Banner
                  buildCommunityLinkCard(),
                  
                  // Section Title
                  _buildSectionTitle(isThai ? 'บันทึกส่วนตัวของฉัน' : 'My Personal Notes', colorScheme),

                  if (noteEntries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 24,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.edit_note_rounded,
                            size: 48,
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isThai ? 'ยังไม่มีบันทึกส่วนตัว' : 'No personal notes yet.',
                            style: GoogleFonts.notoSansThai(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isThai
                                ? 'คุณสามารถเพิ่มบันทึกในอายะฮ์ต่าง ๆ ขณะอ่านอัลกุรอาน'
                                : 'You can add notes to any verse while reading the Quran.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.notoSansThai(
                              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...noteEntries.map((entry) {
                      final keyParts = entry.key.split(':');
                      final surahId = keyParts[0];
                      final verseId = keyParts[1];
                      final noteContent = entry.value.noteText;
                      final surahName = widget.repository.getSurahName(surahId);

                      return buildNoteCard(
                        surahName,
                        surahId,
                        verseId,
                        noteContent,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ReadingScreen(
                                repository: widget.repository,
                                initialSurah: surahId,
                                initialVerseId: verseId,
                              ),
                            ),
                          );
                        },
                        () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: colorScheme.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: colorScheme.outlineVariant),
                              ),
                              title: Text(
                                isThai ? 'ลบบันทึก?' : 'Delete Note?',
                                style: GoogleFonts.notoSansThai(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              content: Text(
                                isThai
                                    ? 'คุณแน่ใจหรือไม่ว่าต้องการลบบันทึกส่วนตัวนี้?'
                                    : 'Are you sure you want to delete this personal note?',
                                style: GoogleFonts.notoSansThai(color: colorScheme.onSurfaceVariant),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: Text(isThai ? 'ยกเลิก' : 'Cancel'),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: colorScheme.error,
                                    foregroundColor: colorScheme.onError,
                                  ),
                                  onPressed: () {
                                    notesProv.deleteNote(surahId, verseId);
                                    Navigator.pop(ctx);
                                  },
                                  child: Text(isThai ? 'ลบ' : 'Delete'),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
