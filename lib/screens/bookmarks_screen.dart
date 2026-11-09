// lib/screens/bookmarks_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/local_reading_provider.dart';
import '../providers/mushaf_reading_provider.dart';
import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/supabase_provider.dart';
import '../widgets/auth_bottom_sheet.dart';
import '../data/quran_repository.dart';
import '../data/quran_foundation_repository.dart';
import '../theme/app_theme.dart';
import 'mushaf_reader_screen.dart';
import '../models/mushaf_models.dart';
import '../models/tadabbur_note.dart';
import 'reading_screen.dart';
import 'tadabbur_community_screen.dart';
import '../shared/shared.dart';
import '../data/offline_surah_names.dart';
import '../data/medina_mushaf_pages.dart';

class _UnifiedItem {
  final DateTime timestamp;
  final String title;
  final String subtitle;
  final String mode; // 'meaning' or 'mushaf'
  final Widget widget;
  _UnifiedItem({
    required this.timestamp,
    required this.title,
    required this.subtitle,
    required this.mode,
    required this.widget,
  });
}

class BookmarksScreen extends StatefulWidget {
  final QuranRepository repository;
  final VoidCallback? onBackToHome;
  final int initialTab;
  const BookmarksScreen({
    super.key,
    required this.repository,
    this.onBackToHome,
    this.initialTab = 0,
  });

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  final QuranFoundationRepository _foundationRepository =
      QuranFoundationRepository();
  late int _selectedMenuIndex;
  String _recentFilter = 'all'; // 'all', 'meaning', 'mushaf'
  String _bookmarkFilter = 'all'; // 'all', 'meaning', 'mushaf'
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedMenuIndex = widget.initialTab.clamp(0, 2);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

  String _getVerseSnippet(String surahId, String verseId, SettingsProvider settings) {
    try {
      final verses = widget.repository.getSurahVerses(surahId);
      final verse = verses.where((v) => v.id == verseId).firstOrNull;
      if (verse != null) {
        final text = resolveVerseTranslationText(
          context: context,
          verseKey: '$surahId:$verseId',
          verse: verse,
          settings: settings,
        );
        if (text.isNotEmpty) return text;
        if (verse.thaiV3.isNotEmpty) return verse.thaiV3;
        return verse.english;
      }
    } catch (_) {}
    return '';
  }

  Widget _buildSectionTitle(String title, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Text(
        title,
        style: GoogleFonts.notoSansThai(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: colorScheme.primary,
          letterSpacing: 0.5,
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
    String? arabicTitle,
    String? meaningSnippet,
    DateTime? timestamp,
    String? badgeText,
    required String readModeLabel,
    required bool isMushaf,
    required VoidCallback onTap,
    VoidCallback? onOpenMushaf,
    Widget? trailing,
    bool isThai = true,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isMushaf
                            ? const Color(0xFFF6EFE3)
                            : const Color(0xFFEAF2EE),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isMushaf
                              ? const Color(0xFFD7C299)
                              : const Color(0xFFB7D4C7),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        readModeLabel,
                        style: GoogleFonts.notoSansThai(
                          color: isMushaf
                              ? const Color(0xFF8A6530)
                              : const Color(0xFF0E5A4A),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.notoSansThai(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (arabicTitle != null && arabicTitle.isNotEmpty)
                      Text(
                        arabicTitle,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          fontFamily: 'UthmanicHafs',
                          fontSize: 16,
                          color: Color(0xFF0E5A4A),
                        ),
                      ),
                  ],
                ),
                if (meaningSnippet != null && meaningSnippet.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    meaningSnippet,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSansThai(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          timestamp != null
                              ? '$subtitle • ${_formatTimestamp(timestamp, isThai)}'
                              : subtitle,
                          style: GoogleFonts.notoSansThai(
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                            fontSize: 11,
                          ),
                        ),
                        if (badgeText != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(4),
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onOpenMushaf != null) ...[
                          InkWell(
                            onTap: onOpenMushaf,
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF6EFE3),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFD7C299), width: 0.5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.import_contacts_outlined, size: 10.5, color: Color(0xFF8A6530)),
                                  const SizedBox(width: 3),
                                  Text(
                                    'มุศหัฟ',
                                    style: GoogleFonts.notoSansThai(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF8A6530),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        if (trailing != null)
                          trailing
                        else
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme, bool isThai) {
    final canPop = Navigator.canPop(context);
    final hasBackAction = canPop || widget.onBackToHome != null;

    final String titleText = _selectedMenuIndex == 2
        ? (isThai ? 'บันทึกส่วนตัว' : 'My Notes')
        : context.tr('bookmarks');
    final String subtitleText = _selectedMenuIndex == 2
        ? (isThai
              ? 'บันทึกข้อคิดและบทเรียนจากอัลกุรอาน'
              : 'Your personal reflections and notes')
        : context.tr('reading_progress');
    final IconData headerIcon = _selectedMenuIndex == 2
        ? Icons.edit_note_rounded
        : Icons.bookmark_border_rounded;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 8,
        24,
        16,
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
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitleText,
                  style: GoogleFonts.notoSansThai(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(headerIcon, color: colorScheme.primary, size: 32),
        ],
      ),
    );
  }

  Widget _buildCapsuleSelector(
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isThai, {
    required int recentCount,
    required int bookmarkCount,
    required int notesCount,
  }) {
    final tabs = [
      {
        'title': isThai ? 'อ่านล่าสุด' : 'Recent',
        'count': recentCount,
        'icon': Icons.history,
        'index': 0,
      },
      {
        'title': isThai ? 'บุ๊กมาร์ก' : 'Bookmarks',
        'count': bookmarkCount,
        'icon': Icons.bookmark_border_rounded,
        'index': 1,
      },
      {
        'title': isThai ? 'บันทึกส่วนตัว' : 'Notes',
        'count': notesCount,
        'icon': Icons.edit_note_rounded,
        'index': 2,
      },
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final tab = tabs[index];
          final tabIndex = tab['index'] as int;
          final isActive = _selectedMenuIndex == tabIndex;

          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _selectedMenuIndex = tabIndex),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF0E5A4A) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      tab['icon'] as IconData,
                      size: 16,
                      color: isActive ? Colors.white : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${tab['title']} (${tab['count']})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSansThai(
                          fontSize: 11.5,
                          color: isActive ? Colors.white : colorScheme.onSurfaceVariant,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
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

  Widget _buildFilterChips({
    required String activeFilter,
    required ValueChanged<String> onFilterChanged,
    required int totalCount,
    required int meaningCount,
    required int mushafCount,
    required bool isThai,
    required ColorScheme colorScheme,
  }) {
    final filters = [
      ('all', isThai ? 'ทั้งหมด' : 'All', totalCount),
      ('meaning', isThai ? 'ความหมาย' : 'Meaning', meaningCount),
      ('mushaf', isThai ? 'มุศหัฟ' : 'Mushaf', mushafCount),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: filters.map((f) {
          final isSelected = activeFilter == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => onFilterChanged(f.$1),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF0E5A4A) : colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF0E5A4A) : colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  '${f.$2} (${f.$3})',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchBar({
    required bool isThai,
    required ColorScheme colorScheme,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: isThai ? 'ค้นหาในรายการ (ชื่อซูเราะฮฺ, เลขหน้า, ข้อความ)...' : 'Filter by name, page, or text...',
            hintStyle: GoogleFonts.notoSansThai(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 11),
            prefixIcon: Icon(
              Icons.search,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  )
                : null,
          ),
          style: GoogleFonts.notoSansThai(
            fontSize: 13,
            color: colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildGuestRetentionNotice({
    required bool isThai,
    required ColorScheme colorScheme,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFFD97706),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isThai
                  ? 'ที่คั่นหน้าถูกเก็บในเครื่องนี้ (จะถูกล้างหากไม่ได้ใช้งานเกิน 30 วัน)'
                  : 'Bookmarks are stored on this device only (cleared after 30 days inactive).',
              style: GoogleFonts.notoSansThai(
                fontSize: 11.5,
                color: const Color(0xFF92400E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => AuthBottomSheet.show(context),
            child: Text(
              isThai ? 'เข้าสู่ระบบ' : 'Sign In',
              style: GoogleFonts.notoSansThai(
                fontSize: 11.5,
                color: const Color(0xFFB45309),
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String description,
    required bool isThai,
    required ColorScheme colorScheme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2EE),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFB7D4C7)),
              ),
              child: Icon(icon, color: const Color(0xFF0E5A4A), size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansThai(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansThai(
                fontSize: 12.5,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () => _openReading(surahId: '1', verseId: '1'),
                  icon: const Icon(Icons.menu_book, size: 14),
                  label: Text(
                    isThai ? 'อ่านฉบับแปล (อัลฟาติหะฮฺ)' : 'Read Meaning (Al-Fatihah)',
                    style: GoogleFonts.notoSansThai(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0E5A4A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    elevation: 0,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openMushaf(null, 1, pageNumber: 1),
                  icon: const Icon(Icons.import_contacts, size: 14),
                  label: Text(
                    isThai ? 'เปิดมุศหัฟ (หน้า 1)' : 'Open Mushaf (Page 1)',
                    style: GoogleFonts.notoSansThai(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF8A6530)),
                    foregroundColor: const Color(0xFF8A6530),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ],
            ),
          ],
        ),
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
    final query = _searchController.text.trim().toLowerCase();

    final meaningfulReadLabel = isThai ? 'ความหมาย' : 'Meaning';
    final mushafReadLabel = isThai ? 'มุศหัฟ' : 'Mushaf';

    // 1. Build Unified Recent Readings
    final rawRecent = <_UnifiedItem>[];

    if (localReading.recentReadings.isNotEmpty) {
      final seenRecentKeys = <String>{};
      final deduplicatedRecent = localReading.recentReadings.where((reading) {
        final key = '${reading.userId}-${reading.verse.surahId}-${reading.profileId}';
        return seenRecentKeys.add(key);
      }).toList();

      rawRecent.addAll(
        deduplicatedRecent.map((reading) {
          final profile = reading.profileId != null
              ? localReading.profileById(reading.profileId!)
              : null;
          final sName = widget.repository.getSurahName(reading.verse.surahId).replaceFirst(RegExp(r'^\d+\.\s*'), '');
          final sNum = int.tryParse(reading.verse.surahId) ?? 1;
          final vNum = int.tryParse(reading.verse.verseId) ?? 1;
          final pageNum = getMedinaMushafPageNumber(sNum, vNum);
          final arName = offlineSurahNamesAr[reading.verse.surahId] ?? '';
          final snippet = _getVerseSnippet(reading.verse.surahId, reading.verse.verseId, settings);

          return _UnifiedItem(
            timestamp: reading.readAt,
            title: isThai
                ? 'ซูเราะฮฺ$sName (${reading.verse.surahId}:${reading.verse.verseId})'
                : 'Surah $sName (${reading.verse.surahId}:${reading.verse.verseId})',
            subtitle: (profile != null && !isFreeReadProfile(profile))
                ? profile.name
                : (isThai ? 'ฉบับแปล' : 'Meaning'),
            mode: 'meaning',
            widget: _buildVerseItem(
              colorScheme,
              title: isThai
                  ? 'ซูเราะฮฺ$sName (${reading.verse.surahId}:${reading.verse.verseId})'
                  : 'Surah $sName (${reading.verse.surahId}:${reading.verse.verseId})',
              subtitle: (profile != null && !isFreeReadProfile(profile))
                  ? profile.name
                  : (isThai ? 'ฉบับแปล' : 'Meaning'),
              arabicTitle: arName,
              meaningSnippet: snippet,
              timestamp: reading.readAt,
              badgeText: (profile != null && !isFreeReadProfile(profile))
                  ? profile.name
                  : null,
              readModeLabel: meaningfulReadLabel,
              isMushaf: false,
              isThai: isThai,
              onTap: () => _handleVerseRecentTap(reading, localReading),
              onOpenMushaf: () => _openMushaf(null, 1, pageNumber: pageNum),
            ),
          );
        }),
      );
    }

    if (mushafReading.recentReadings.isNotEmpty) {
      rawRecent.addAll(
        mushafReading.recentReadings.map((reading) {
          final surahName = getSurahNameForPage(
            reading.pageNumber,
            widget.repository,
          );
          final profile = reading.profileId != null
              ? mushafReading.profileById(reading.profileId!)
              : null;
          var sId = '1';
          try {
            final pageSurah = medinaMushafPages[reading.pageNumber - 1].first['surah'];
            if (pageSurah != null) sId = pageSurah.toString();
          } catch (_) {}
          final arName = offlineSurahNamesAr[sId] ?? '';

          return _UnifiedItem(
            timestamp: reading.updatedAt,
            title: '${isThai ? 'หน้ามุศหัฟ' : 'Mushaf Page'} ${reading.pageNumber}',
            subtitle: surahName,
            mode: 'mushaf',
            widget: _buildVerseItem(
              colorScheme,
              title: '${isThai ? 'หน้ามุศหัฟ' : 'Mushaf Page'} ${reading.pageNumber}',
              subtitle: surahName,
              arabicTitle: arName,
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

    rawRecent.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final meaningRecentCount = rawRecent.where((e) => e.mode == 'meaning').length;
    final mushafRecentCount = rawRecent.where((e) => e.mode == 'mushaf').length;
    final totalRecentCount = rawRecent.length;

    final filteredRecent = rawRecent.where((item) {
      if (_recentFilter == 'meaning' && item.mode != 'meaning') return false;
      if (_recentFilter == 'mushaf' && item.mode != 'mushaf') return false;
      if (query.isNotEmpty) {
        return item.title.toLowerCase().contains(query) ||
            item.subtitle.toLowerCase().contains(query);
      }
      return true;
    }).toList();

    // 2. Build Unified Bookmarks
    final rawBookmarks = <_UnifiedItem>[];

    if (localReading.bookmarks.isNotEmpty) {
      rawBookmarks.addAll(
        localReading.bookmarks.map((bookmark) {
          final rawSurahId = int.parse(bookmark.verse.surahId).toString();
          final rawVerseId = bookmark.verse.verseId;
          final sName = widget.repository.getSurahName(rawSurahId).replaceFirst(RegExp(r'^\d+\.\s*'), '');
          final sNum = int.tryParse(rawSurahId) ?? 1;
          final vNum = int.tryParse(rawVerseId) ?? 1;
          final pageNum = getMedinaMushafPageNumber(sNum, vNum);
          final arName = offlineSurahNamesAr[rawSurahId] ?? '';
          final snippet = _getVerseSnippet(rawSurahId, rawVerseId, settings);

          return _UnifiedItem(
            timestamp: bookmark.createdAt,
            title: isThai
                ? 'ซูเราะฮฺ$sName ($rawSurahId:$rawVerseId)'
                : 'Surah $sName ($rawSurahId:$rawVerseId)',
            subtitle: isThai ? 'อายะฮฺที่บันทึกไว้' : 'Saved Ayah',
            mode: 'meaning',
            widget: _buildVerseItem(
              colorScheme,
              title: isThai
                  ? 'ซูเราะฮฺ$sName ($rawSurahId:$rawVerseId)'
                  : 'Surah $sName ($rawSurahId:$rawVerseId)',
              subtitle: isThai ? 'อายะฮฺที่บันทึกไว้' : 'Saved Ayah',
              arabicTitle: arName,
              meaningSnippet: snippet,
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
              onOpenMushaf: () => _openMushaf(null, 1, pageNumber: pageNum),
              trailing: IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: colorScheme.error,
                  size: 20,
                ),
                tooltip: isThai ? 'ลบที่คั่นหน้า' : 'Remove Bookmark',
                onPressed: () => localReading.removeBookmark(bookmark.id),
              ),
            ),
          );
        }),
      );
    }

    if (mushafReading.pageBookmarks.isNotEmpty) {
      rawBookmarks.addAll(
        mushafReading.pageBookmarks.map((bookmark) {
          final surahName = getSurahNameForPage(
            bookmark.pageNumber,
            widget.repository,
          );
          var sId = '1';
          try {
            final pageSurah = medinaMushafPages[bookmark.pageNumber - 1].first['surah'];
            if (pageSurah != null) sId = pageSurah.toString();
          } catch (_) {}
          final arName = offlineSurahNamesAr[sId] ?? '';

          return _UnifiedItem(
            timestamp: bookmark.createdAt,
            title: '${isThai ? 'หน้ามุศหัฟ' : 'Mushaf Page'} ${bookmark.pageNumber}',
            subtitle: surahName,
            mode: 'mushaf',
            widget: _buildVerseItem(
              colorScheme,
              title: '${isThai ? 'หน้ามุศหัฟ' : 'Mushaf Page'} ${bookmark.pageNumber}',
              subtitle: surahName,
              arabicTitle: arName,
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
                  size: 20,
                ),
                tooltip: isThai ? 'ลบที่คั่นหน้า' : 'Remove Bookmark',
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
      rawBookmarks.addAll(
        mushafReading.verseBookmarks.map((bookmark) {
          final parts = bookmark.verseKey.split(':');
          final surahId = parts.isNotEmpty ? parts[0] : '';
          final verseId = parts.length > 1 ? parts[1] : '';
          final formattedSurahName = widget.repository.getSurahName(surahId);
          final sName = formattedSurahName.replaceFirst(RegExp(r'^\d+\.\s*'), '');
          final arName = offlineSurahNamesAr[surahId] ?? '';
          final snippet = _getVerseSnippet(surahId, verseId, settings);

          return _UnifiedItem(
            timestamp: bookmark.createdAt,
            title: isThai
                ? 'ซูเราะฮฺ$sName ($surahId:$verseId)'
                : 'Surah $sName ($surahId:$verseId)',
            subtitle: '${isThai ? 'หน้ามุศหัฟ' : 'Mushaf Page'} ${bookmark.pageNumber}',
            mode: 'mushaf',
            widget: _buildVerseItem(
              colorScheme,
              title: isThai
                  ? 'ซูเราะฮฺ$sName ($surahId:$verseId)'
                  : 'Surah $sName ($surahId:$verseId)',
              subtitle: '${isThai ? 'หน้ามุศหัฟ' : 'Mushaf Page'} ${bookmark.pageNumber}',
              arabicTitle: arName,
              meaningSnippet: snippet,
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
                  size: 20,
                ),
                tooltip: isThai ? 'ลบที่คั่นหน้า' : 'Remove Bookmark',
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

    rawBookmarks.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final meaningBookmarkCount = rawBookmarks.where((e) => e.mode == 'meaning').length;
    final mushafBookmarkCount = rawBookmarks.where((e) => e.mode == 'mushaf').length;
    final totalBookmarkCount = rawBookmarks.length;

    final filteredBookmarks = rawBookmarks.where((item) {
      if (_bookmarkFilter == 'meaning' && item.mode != 'meaning') return false;
      if (_bookmarkFilter == 'mushaf' && item.mode != 'mushaf') return false;
      if (query.isNotEmpty) {
        return item.title.toLowerCase().contains(query) ||
            item.subtitle.toLowerCase().contains(query);
      }
      return true;
    }).toList();

    // 3. Notes Entries
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

    final filteredNoteEntries = noteEntries.where((entry) {
      if (query.isEmpty) return true;
      final keyParts = entry.key.split(':');
      final sName = widget.repository.getSurahName(keyParts[0]);
      return entry.key.contains(query) ||
          sName.toLowerCase().contains(query) ||
          entry.value.noteText.toLowerCase().contains(query);
    }).toList();

    final totalNotesAndFavsCount = noteEntries.length;

    // Helper functions for Note Cards & Community banner
    Widget buildCommunityLinkCard() {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF2EE),
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: const Color(0xFFB7D4C7)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radius),
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
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFB7D4C7), width: 0.5),
                    ),
                    child: const Icon(
                      Icons.forum_rounded,
                      color: Color(0xFF0E5A4A),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isThai
                              ? 'แบ่งปันตดับบุรในชุมชน'
                              : 'Share Tadabbur in Community',
                          style: GoogleFonts.notoSansThai(
                            color: const Color(0xFF0E5A4A),
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isThai
                              ? 'อ่านบันทึกและแบ่งปันความคิดร่วมกับพี่น้องในชุมชน'
                              : 'Read and share reflections with the community',
                          style: GoogleFonts.notoSansThai(
                            color: const Color(0xFF0E5A4A).withValues(alpha: 0.8),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF0E5A4A),
                    size: 20,
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
      final arName = offlineSurahNamesAr[surahId] ?? '';

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF2EE),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFB7D4C7), width: 0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.edit_note_rounded,
                            size: 14,
                            color: Color(0xFF0E5A4A),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${surahName.replaceFirst(RegExp(r'^\d+\.\s*'), '')} $surahId:$verseId',
                            style: GoogleFonts.notoSansThai(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: const Color(0xFF0E5A4A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: note.isPublic
                            ? colorScheme.tertiaryContainer.withValues(alpha: 0.6)
                            : colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            note.isPublic
                                ? Icons.public
                                : Icons.lock_outline_rounded,
                            size: 11,
                            color: note.isPublic
                                ? colorScheme.onTertiaryContainer
                                : colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            note.isPublic
                                ? (isThai ? 'สาธารณะ' : 'Public')
                                : (isThai ? 'ส่วนตัว' : 'Private'),
                            style: GoogleFonts.notoSansThai(
                              fontSize: 10.5,
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
                    if (arName.isNotEmpty)
                      Text(
                        arName,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          fontFamily: 'UthmanicHafs',
                          fontSize: 15,
                          color: Color(0xFF0E5A4A),
                        ),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.edit_outlined,
                        color: colorScheme.primary,
                        size: 18,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: isThai ? 'แก้ไข' : 'Edit',
                      onPressed: onEdit,
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: colorScheme.error,
                        size: 18,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: isThai ? 'ลบ' : 'Delete',
                      onPressed: onDelete,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                    border: const Border(
                      left: BorderSide(color: Color(0xFF0E5A4A), width: 3),
                    ),
                  ),
                  child: Text(
                    noteContent,
                    style: GoogleFonts.notoSansThai(
                      fontSize: 13.5,
                      color: colorScheme.onSurface,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      isThai ? 'เปิดอ่านอายะฮฺ' : 'Open Ayah',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 11,
                        color: const Color(0xFF0E5A4A),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 12,
                      color: Color(0xFF0E5A4A),
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
          _buildCapsuleSelector(
            colorScheme,
            textTheme,
            isThai,
            recentCount: totalRecentCount,
            bookmarkCount: totalBookmarkCount,
            notesCount: totalNotesAndFavsCount,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 4, bottom: 32),
              children: [
                if (_selectedMenuIndex == 0) ...[
                  _buildSearchBar(isThai: isThai, colorScheme: colorScheme),
                  _buildFilterChips(
                    activeFilter: _recentFilter,
                    onFilterChanged: (f) => setState(() => _recentFilter = f),
                    totalCount: totalRecentCount,
                    meaningCount: meaningRecentCount,
                    mushafCount: mushafRecentCount,
                    isThai: isThai,
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: 6),
                  if (filteredRecent.isEmpty)
                    _buildEmptyState(
                      icon: Icons.history,
                      title: isThai ? 'ไม่มีประวัติการอ่าน' : 'No Reading History',
                      description: isThai
                          ? 'เมื่อคุณเริ่มอ่านอัลกุรอาน หน้าและอายะฮฺที่อ่านล่าสุดจะแสดงที่นี่'
                          : 'Pages and ayahs you read will be recorded here.',
                      isThai: isThai,
                      colorScheme: colorScheme,
                    )
                  else
                    ...filteredRecent.map((e) => e.widget),
                ] else if (_selectedMenuIndex == 1) ...[
                  if (!context.watch<SupabaseProvider>().isLoggedIn)
                    _buildGuestRetentionNotice(
                      isThai: isThai,
                      colorScheme: colorScheme,
                    ),
                  _buildSearchBar(isThai: isThai, colorScheme: colorScheme),
                  _buildFilterChips(
                    activeFilter: _bookmarkFilter,
                    onFilterChanged: (f) => setState(() => _bookmarkFilter = f),
                    totalCount: totalBookmarkCount,
                    meaningCount: meaningBookmarkCount,
                    mushafCount: mushafBookmarkCount,
                    isThai: isThai,
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: 6),
                  if (filteredBookmarks.isEmpty)
                    _buildEmptyState(
                      icon: Icons.bookmark_border_rounded,
                      title: isThai ? 'ไม่มีที่คั่นหน้า' : 'No Bookmarks Saved',
                      description: isThai
                          ? 'แตะไอคอนที่คั่นหน้าขณะอ่าน เพื่อบันทึกอายะฮฺหรือหน้าที่ต้องการกลับมาอ่านซ้ำ'
                          : 'Tap the bookmark icon while reading to save verses or pages.',
                      isThai: isThai,
                      colorScheme: colorScheme,
                    )
                  else
                    ...filteredBookmarks.map((e) => e.widget),
                ] else if (_selectedMenuIndex == 2) ...[
                  buildCommunityLinkCard(),
                  _buildSectionTitle(
                    isThai ? 'บันทึกส่วนตัวของฉัน (${noteEntries.length})' : 'My Personal Notes (${noteEntries.length})',
                    colorScheme,
                  ),
                  if (noteEntries.length > 3)
                    _buildSearchBar(isThai: isThai, colorScheme: colorScheme),
                  if (filteredNoteEntries.isEmpty)
                    _buildEmptyState(
                      icon: Icons.edit_note_rounded,
                      title: isThai ? 'ยังไม่มีบันทึกส่วนตัว' : 'No Personal Notes Yet',
                      description: isThai
                          ? 'คุณสามารถเพิ่มบันทึกตดับบุรในอายะฮฺต่าง ๆ ขณะอ่านอัลกุรอานเพื่อทบทวนบทเรียนชีวิต'
                          : 'You can reflect and save personal notes on any verse while reading.',
                      isThai: isThai,
                      colorScheme: colorScheme,
                    )
                  else
                    ...filteredNoteEntries.map((entry) {
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
