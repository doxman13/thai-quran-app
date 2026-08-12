// lib/screens/bookmarks_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/local_reading_provider.dart';
import '../providers/mushaf_reading_provider.dart';
import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../data/quran_repository.dart';
import '../data/quran_foundation_repository.dart';
import '../theme/app_theme.dart';
import 'mushaf_reader_screen.dart';
import '../models/mushaf_models.dart';
import '../models/tadabbur_note.dart';
import 'reading_screen.dart';
import 'tadabbur_community_screen.dart';
import '../shared/shared.dart';

class _UnifiedItem {
  final DateTime timestamp;
  final Widget widget;
  _UnifiedItem(this.timestamp, this.widget);
}

class BookmarksScreen extends StatefulWidget {
  final QuranRepository repository;
  final VoidCallback? onBackToHome;
  const BookmarksScreen({
    super.key,
    required this.repository,
    this.onBackToHome,
  });

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  final QuranFoundationRepository _foundationRepository =
      QuranFoundationRepository();
  static const int _displayLimit = 3;
  int _selectedMenuIndex = 0;

  Future<void> _openReading({
    required String surahId,
    String? verseId,
    int? verseIndex,
    bool saveToFreeReadOnly = false,
    bool recordRecentRead = true,
    // Preserve the original goal context even if activeProfile changes
    // during the session (e.g. switchToFreeReadIfOutside fires).
    String? fallbackProfileId,
  }) async {
    final result = await Navigator.push(
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
    if (!mounted || result is! Map) return;
    final resultSurahId = result['surahId']?.toString();
    final resultVerseId = result['verseId']?.toString();
    if (resultSurahId != null && resultVerseId != null) {
      final localReading = context.read<LocalReadingProvider>();
      final resultProfileId = result['profileId']?.toString();

      // Resolve which profile to tag this recent read with.
      // Prefer the result's profileId, but if it resolves to a free-read
      // profile (or is missing) and we had an explicit goal, use the fallback.
      LocalReadingProfile? profile = resultProfileId != null
          ? localReading.profileById(resultProfileId)
          : null;

      if ((profile == null || isFreeReadProfile(profile)) &&
          fallbackProfileId != null &&
          !saveToFreeReadOnly) {
        final fallback = localReading.profileById(fallbackProfileId);
        if (fallback != null && !isFreeReadProfile(fallback)) {
          profile = fallback;
        }
      }

      if (profile != null && isShortcutProfile(profile)) {
        if (resultSurahId != profile.start.surahId) {
          profile = null;
        }
      }

      profile ??= saveToFreeReadOnly
          ? localReading.freeReadProfile
          : localReading.activeProfile;

      if (recordRecentRead) {
        await localReading.addRecentReading(
          verse: toVerseRef(resultSurahId, resultVerseId),
          profileId: profile?.id,
        );
      }
    }
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

    final profile = (profileId != null && profileId.isNotEmpty)
        ? provider.profileById(profileId)
        : null;
    final isInside = profile != null &&
        (isShortcutProfile(profile)
            ? surahId == profile.start.surahId
            : (profile.target == null ||
                provider.isVerseInsideProfile(profile, surahId, verseId)));
    final hasProfile = profile != null && isInside;
    if (hasProfile) {
      await provider.setActiveProfile(profileId);
      if (!mounted) return;
      // Pass the original profileId as fallback so the goal is preserved
      // in the recent-read entry even if the session changes activeProfile.
      _openReading(
        surahId: surahId,
        verseId: verseId,
        verseIndex: verseIndex,
        fallbackProfileId: profileId,
      );
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
          style: GoogleFonts.notoSansThai(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt, bool isThai) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) {
      return isThai ? 'เมื่อสักครู่' : 'Just now';
    } else if (diff.inMinutes < 60) {
      return isThai ? '${diff.inMinutes} นาทีที่แล้ว' : '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return isThai ? '${diff.inHours} ชม.ที่แล้ว' : '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return isThai ? '${diff.inDays} วันที่แล้ว' : '${diff.inDays}d ago';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }

  Widget _buildVerseItem(
    ColorScheme colorScheme, {
    required String title,
    required String subtitle,
    DateTime? timestamp,
    String? badgeText,
    required String readModeLabel,
    required bool isMushaf,
    required VoidCallback onTap,
    Widget? trailing,
    bool isThai = true,
  }) {
    final leadingBg = isMushaf
        ? colorScheme.secondaryContainer.withValues(alpha: 0.5)
        : colorScheme.primaryContainer.withValues(alpha: 0.3);
    final leadingText = isMushaf
        ? colorScheme.onSecondaryContainer
        : colorScheme.primary;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: leadingBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            readModeLabel,
            style: GoogleFonts.notoSansThai(
              color: leadingText,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        title: Text(
          title,
          style: GoogleFonts.notoSansThai(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  timestamp != null
                      ? '$subtitle • ${_formatTimestamp(timestamp, isThai)}'
                      : subtitle,
                  style: GoogleFonts.notoSansThai(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badgeText != null) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeText,
                    style: GoogleFonts.notoSansThai(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        onTap: onTap,
        trailing:
            trailing ??
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
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
        ? (isThai
              ? 'บันทึกและความคิดเห็นของคุณ'
              : 'Your personal notes and thoughts')
        : context.tr('reading_progress');
    final IconData headerIcon = _selectedMenuIndex == 2
        ? Icons.edit_note_rounded
        : Icons.bookmark;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 8,
        24,
        24,
      ),
      color: colorScheme.surface,
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
          Icon(headerIcon, color: colorScheme.primary, size: 36),
        ],
      ),
    );
  }

  Widget _buildCapsuleSelector(
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isThai,
  ) {
    final tabs = [
      {
        'title': isThai ? 'อ่านล่าสุด' : 'Recent Read',
        'icon': Icons.history,
        'index': 0,
      },
      {
        'title': isThai ? 'บุ๊กมาร์ก' : 'Bookmarks',
        'icon': Icons.bookmark,
        'index': 1,
      },
      {
        'title': isThai ? 'รายการโปรด' : 'Favourites',
        'icon': Icons.favorite_rounded,
        'index': 2,
      },
    ];

    return Container(
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final tab = tabs[index];
          final tabIndex = tab['index'] as int;
          final isActive = _selectedMenuIndex == tabIndex;

          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() => _selectedMenuIndex = tabIndex),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isActive ? colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      tab['icon'] as IconData,
                      size: 18,
                      color: isActive
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        tab['title'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelLarge?.copyWith(
                          color: isActive
                              ? colorScheme.onPrimary
                              : colorScheme.onSurface.withValues(alpha: 0.55),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localReading = Provider.of<LocalReadingProvider>(context);
    final mushafReading = Provider.of<MushafReadingProvider>(context);
    final notesProv = Provider.of<NotesProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isThai = settings.languageCode == 'th';
    final primaryColor = settings.getPrimaryColor();

    final meaningfulReadLabel = isThai ? 'ความหมาย' : 'Meaning';
    final mushafReadLabel = isThai ? 'มุศหัฟ' : 'Mushaf';

    final unifiedRecent = <_UnifiedItem>[];

    if (localReading.recentReadings.isNotEmpty) {
      final seenRecentKeys = <String>{};
      final deduplicatedRecent = localReading.recentReadings.where((reading) {
        final key = '${reading.userId}-${reading.verse.surahId}-${reading.profileId}';
        return seenRecentKeys.add(key);
      }).toList();

      unifiedRecent.addAll(
        deduplicatedRecent.map((reading) {
          final profile = reading.profileId != null
              ? localReading.profileById(reading.profileId!)
              : null;
          return _UnifiedItem(
            reading.readAt,
            _buildVerseItem(
              colorScheme,
               title: widget.repository.getSurahName(reading.verse.surahId).replaceFirst(RegExp(r'^\d+\.\s*'), ''),
              subtitle: context.tr(
                'ayah_number',
                args: {
                  'number': '${reading.verse.surahId}:${reading.verse.verseId}',
                },
              ),
              timestamp: reading.readAt,
              badgeText: (profile != null &&
                      !isFreeReadProfile(profile) &&
                      (isShortcutProfile(profile)
                          ? reading.verse.surahId == profile.start.surahId
                          : (profile.target == null ||
                              localReading.isVerseInsideProfile(
                                profile,
                                reading.verse.surahId,
                                reading.verse.verseId,
                              ))))
                  ? profile.name
                  : null,
              readModeLabel: meaningfulReadLabel,
              isMushaf: false,
              isThai: isThai,
              onTap: () => _handleVerseRecentTap(reading, localReading),
            ),
          );
        }),
      );
    }

    if (mushafReading.recentReadings.isNotEmpty) {
      unifiedRecent.addAll(
        mushafReading.recentReadings.map((reading) {
          final surahName = getSurahNameForPage(
            reading.pageNumber,
            widget.repository,
          );
          final profile = reading.profileId != null
              ? mushafReading.profileById(reading.profileId!)
              : null;
          return _UnifiedItem(
            reading.updatedAt,
            _buildVerseItem(
              colorScheme,
              title: 'Mushaf (${context.tr('page')} ${reading.pageNumber})',
              subtitle: surahName,
              timestamp: reading.updatedAt,
              badgeText: (profile != null && !profile.isFreeRead)
                  ? profile.name
                  : null,
              readModeLabel: mushafReadLabel,
              isMushaf: true,
              isThai: isThai,
              onTap: () => _handleMushafRecentTap(reading, mushafReading),
            ),
          );
        }),
      );
    }

    // Sort recent by timestamp descending
    unifiedRecent.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final allRecentItems = unifiedRecent.map((e) => e.widget).toList();

    final unifiedBookmarks = <_UnifiedItem>[];

    if (localReading.bookmarks.isNotEmpty) {
      unifiedBookmarks.addAll(
        localReading.bookmarks.map((bookmark) {
          final rawSurahId = int.parse(bookmark.verse.surahId).toString();
          final rawVerseId = bookmark.verse.verseId;

          return _UnifiedItem(
            bookmark.createdAt,
            _buildVerseItem(
              colorScheme,
              title:
                  '${widget.repository.getSurahName(rawSurahId).replaceFirst(RegExp(r'^\d+\.\s*'), '')}, ${context.tr('ayah_number', args: {'number': rawVerseId})}',
              subtitle:
                  '${context.tr('surah_number', args: {'number': rawSurahId})}, ${context.tr('ayah_number', args: {'number': rawVerseId})}',
              timestamp: bookmark.createdAt,
              readModeLabel: meaningfulReadLabel,
              isMushaf: false,
              isThai: isThai,
              onTap: () {
                _openReading(
                  surahId: rawSurahId,
                  verseId: rawVerseId,
                  saveToFreeReadOnly: true,
                );
              },
              trailing: IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: colorScheme.error,
                  size: 22,
                ),
                onPressed: () => localReading.removeBookmark(bookmark.id),
              ),
            ),
          );
        }),
      );
    }

    if (mushafReading.pageBookmarks.isNotEmpty) {
      unifiedBookmarks.addAll(
        mushafReading.pageBookmarks.map((bookmark) {
          final surahName = getSurahNameForPage(
            bookmark.pageNumber,
            widget.repository,
          );
          return _UnifiedItem(
            bookmark.createdAt,
            _buildVerseItem(
              colorScheme,
              title: '${context.tr('page')} ${bookmark.pageNumber}',
              subtitle: surahName,
              timestamp: bookmark.createdAt,
              readModeLabel: mushafReadLabel,
              isMushaf: true,
              isThai: isThai,
              onTap: () => _openMushaf(
                null,
                bookmark.mushafId,
                pageNumber: bookmark.pageNumber,
              ),
              trailing: IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: colorScheme.error,
                  size: 24,
                ),
                onPressed: () => mushafReading.togglePageBookmark(
                  bookmark.mushafId,
                  bookmark.pageNumber,
                ),
              ),
            ),
          );
        }),
      );
    }

    if (mushafReading.verseBookmarks.isNotEmpty) {
      unifiedBookmarks.addAll(
        mushafReading.verseBookmarks.map((bookmark) {
          final parts = bookmark.verseKey.split(':');
          final surahId = parts.isNotEmpty ? parts[0] : '';
          final verseId = parts.length > 1 ? parts[1] : '';
          final formattedSurahName = widget.repository.getSurahName(surahId);

          return _UnifiedItem(
            bookmark.createdAt,
            _buildVerseItem(
              colorScheme,
              title:
                  '${formattedSurahName.replaceFirst(RegExp(r'^\d+\.\s*'), '')}, ${context.tr('ayah_number', args: {'number': verseId})}',
              subtitle: '${context.tr('page')} ${bookmark.pageNumber}',
              timestamp: bookmark.createdAt,
              readModeLabel: mushafReadLabel,
              isMushaf: true,
              isThai: isThai,
              onTap: () => _openMushaf(
                null,
                bookmark.mushafId,
                pageNumber: bookmark.pageNumber,
                highlightedVerseKey: bookmark.verseKey,
              ),
              trailing: IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: colorScheme.error,
                  size: 24,
                ),
                onPressed: () => mushafReading.toggleVerseBookmark(
                  mushafId: bookmark.mushafId,
                  pageNumber: bookmark.pageNumber,
                  verseKey: bookmark.verseKey,
                ),
              ),
            ),
          );
        }),
      );
    }

    // Sort bookmarks by timestamp descending
    unifiedBookmarks.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final allBookmarkItems = unifiedBookmarks.map((e) => e.widget).toList();



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
                  builder: (_) =>
                      TadabburCommunityScreen(repository: widget.repository),
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
                          isThai
                              ? 'แบ่งปันตดับบุรในชุมชน'
                              : 'Share Tadabbur in Community',
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

    void showEditNoteDialog(
      BuildContext context,
      TadabburNote note,
      NotesProvider notesProv,
      ColorScheme colorScheme,
      bool isThai,
    ) {
      final textController = TextEditingController(text: note.noteText);
      bool isPublic = note.isPublic;
      bool isAnonymous = note.isAnonymous;

      showDialog(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              return AlertDialog(
                backgroundColor: colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                title: Row(
                  children: [
                    Icon(Icons.edit_note_rounded, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      isThai ? 'แก้ไขบันทึกส่วนตัว' : 'Edit Note',
                      style: GoogleFonts.notoSansThai(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: textController,
                        maxLines: 4,
                        autofocus: true,
                        style: GoogleFonts.notoSansThai(
                          fontSize: 14,
                          color: colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: isThai
                              ? 'ข้อความบันทึกส่วนตัว...'
                              : 'Write your personal note...',
                          hintStyle: GoogleFonts.notoSansThai(
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerLow,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: colorScheme.outlineVariant,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: colorScheme.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                isThai
                                    ? 'สาธารณะ (แชร์ในชุมชน)'
                                    : 'Public (Share to Community)',
                                style: GoogleFonts.notoSansThai(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              subtitle: Text(
                                isThai
                                    ? 'ให้ผู้อื่นอ่านบทเรียนตดับบุรของคุณ'
                                    : 'Allow others to read your reflection',
                                style: GoogleFonts.notoSansThai(
                                  fontSize: 11,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              value: isPublic,
                              onChanged: (val) {
                                setDialogState(() {
                                  isPublic = val;
                                });
                              },
                            ),
                            if (isPublic) ...[
                              const Divider(height: 1),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  isThai
                                      ? 'โพสต์แบบไม่ระบุตัวตน'
                                      : 'Post Anonymously',
                                  style: GoogleFonts.notoSansThai(
                                    fontSize: 12,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                value: isAnonymous,
                                onChanged: (val) {
                                  setDialogState(() {
                                    isAnonymous = val ?? false;
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      isThai ? 'ยกเลิก' : 'Cancel',
                      style: GoogleFonts.notoSansThai(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: () async {
                      final newText = textController.text.trim();
                      if (newText.isEmpty) {
                        await notesProv.deleteNote(note.surahId, note.verseId);
                      } else {
                        await notesProv.saveNote(
                          surahId: note.surahId,
                          verseId: note.verseId,
                          noteText: newText,
                          isPublic: isPublic,
                          isAnonymous: isAnonymous,
                        );
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: Text(
                      isThai ? 'บันทึก' : 'Save',
                      style: GoogleFonts.notoSansThai(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    }

    Widget buildNoteCard({
      required String surahName,
      required TadabburNote note,
      required VoidCallback onTap,
      required VoidCallback onEdit,
      required VoidCallback onDelete,
    }) {
      final noteContent = note.noteText;
      final surahId = note.surahId;
      final verseId = note.verseId;

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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit_note_rounded,
                            size: 14,
                            color: colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${surahName.replaceFirst(RegExp(r'^\d+\.\s*'), '')} $surahId:$verseId',
                            style: GoogleFonts.notoSansThai(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: note.isPublic
                            ? colorScheme.tertiaryContainer.withValues(
                                alpha: 0.6,
                              )
                            : colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            note.isPublic
                                ? Icons.public
                                : Icons.lock_outline_rounded,
                            size: 12,
                            color: note.isPublic
                                ? colorScheme.onTertiaryContainer
                                : colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            note.isPublic
                                ? (isThai ? 'สาธารณะ' : 'Public')
                                : (isThai ? 'ส่วนตัว' : 'Private'),
                            style: GoogleFonts.notoSansThai(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: note.isPublic
                                  ? colorScheme.onTertiaryContainer
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.edit_outlined,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: isThai ? 'แก้ไข' : 'Edit',
                      onPressed: onEdit,
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: colorScheme.error,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: isThai ? 'ลบ' : 'Delete',
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
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 12,
                      color: colorScheme.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(colorScheme, isThai),
          _buildCapsuleSelector(colorScheme, textTheme, isThai),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 32),
              children: [
                if (_selectedMenuIndex == 0) ...[
                  _buildSectionTitle(
                    isThai ? 'อ่านล่าสุดทั้งหมด' : 'All Recent Reads',
                    colorScheme,
                  ),
                  if (allRecentItems.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Text(
                        isThai ? 'ไม่มีประวัติการอ่าน' : 'No reading history',
                        style: GoogleFonts.notoSansThai(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    )
                  else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: allRecentItems
                            .take(_displayLimit * 2)
                            .toList(),
                      ),
                    ),
                    _buildSeeMoreButton(
                      isThai ? 'อ่านล่าสุดทั้งหมด' : 'All Recent Reads',
                      allRecentItems,
                      colorScheme,
                    ),
                  ],
                ] else if (_selectedMenuIndex == 1) ...[
                  _buildSectionTitle(
                    isThai ? 'บุ๊กมาร์กทั้งหมด' : 'All Bookmarks',
                    colorScheme,
                  ),
                  if (allBookmarkItems.isEmpty)
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
                    )
                  else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: allBookmarkItems
                            .take(_displayLimit * 2)
                            .toList(),
                      ),
                    ),
                    _buildSeeMoreButton(
                      isThai ? 'บุ๊กมาร์กทั้งหมด' : 'All Bookmarks',
                      allBookmarkItems,
                      colorScheme,
                    ),
                  ],
                ] else if (_selectedMenuIndex == 2) ...[
                  // Community Link Banner
                  buildCommunityLinkCard(),

                  // Section Title
                  _buildSectionTitle(
                    isThai ? 'บันทึกส่วนตัวของฉัน' : 'My Personal Notes',
                    colorScheme,
                  ),

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
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isThai
                                ? 'ยังไม่มีบันทึกส่วนตัว'
                                : 'No personal notes yet.',
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
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.7,
                              ),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...noteEntries.map((entry) {
                      final note = entry.value;
                      final keyParts = entry.key.split(':');
                      final surahId = keyParts[0];
                      final verseId = keyParts[1];
                      final surahName = widget.repository.getSurahName(surahId);

                      return buildNoteCard(
                        surahName: surahName,
                        note: note,
                        onTap: () {
                          _openReading(
                            surahId: surahId,
                            verseId: verseId,
                            recordRecentRead: false,
                          );
                        },
                        onEdit: () {
                          showEditNoteDialog(
                            context,
                            note,
                            notesProv,
                            colorScheme,
                            isThai,
                          );
                        },
                        onDelete: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: colorScheme.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: colorScheme.outlineVariant,
                                ),
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
                                style: GoogleFonts.notoSansThai(
                                  color: colorScheme.onSurfaceVariant,
                                ),
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
