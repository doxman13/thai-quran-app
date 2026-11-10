// lib/screens/browse_screen.dart
//
// Modern Material 3 Quran Index / Browse screen.
// Allows browsing by Surah (1-114), Juz (1-30), Topics, and Page (1-604),
// with instant search, translation lookups, voice search, and seamless
// access to Verse-by-Verse (Meaning), Mushaf reading, and Hifz memorization.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:qcf_quran/qcf_quran.dart' as qcf;

import '../data/medina_mushaf_pages.dart';
import '../data/offline_surah_names.dart';
import '../data/quran_foundation_repository.dart';
import '../data/quran_repository.dart';
import '../models/hifz_session_config.dart';
import '../providers/local_reading_provider.dart';
import '../providers/mushaf_reading_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../shared/shared.dart';
import '../widgets/voice_search_sheet.dart';
import '../services/offline_quran_database_service.dart';
import 'hifz_wizard_setup_screen.dart';
import 'topic_verses_screen.dart';
import 'mushaf_reader_screen.dart';
import 'topics_screen.dart';

class BrowseScreen extends StatefulWidget {
  final QuranRepository repository;
  final QuranFoundationRepository? foundationRepository;
  final AppThemeColors colors;
  final void Function(String surahId, String verseId) onOpen;
  final void Function(String surahId, String verseId)? onOpenMeaning;
  final ValueChanged<int> onOpenPage;
  final void Function(int page, {String? highlightVerseKey})? onOpenMushafPage;

  const BrowseScreen({
    super.key,
    required this.repository,
    this.foundationRepository,
    required this.colors,
    required this.onOpen,
    this.onOpenMeaning,
    required this.onOpenPage,
    this.onOpenMushafPage,
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

  static const Set<int> _medinanSurahs = {
    2, 3, 4, 5, 8, 9, 13, 22, 24, 33, 47, 48, 49, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 76, 98, 110,
  };
  String _mode = 'surah';
  String _surahFilter = 'all'; // 'all', 'fav', 'juz'

  final TextEditingController _searchController = TextEditingController();
  late final QuranFoundationRepository _foundationRepo;
  QuranSearchResult? _apiSearchResult;
  bool _isApiSearching = false;
  List<Map<String, dynamic>> _topicSearchResults = [];
  Timer? _debounceTimer;

  QuranDirectRef? _directRef;
  QuranPageRef? _directPageRef;
  List<Map<String, dynamic>> _offlineVerseResults = [];
  bool _isOfflineSearching = false;

  @override
  void initState() {
    super.initState();
    _foundationRepo =
        widget.foundationRepository ?? QuranFoundationRepository();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _openMushafPage(int pageNumber) {
    if (widget.onOpenMushafPage != null) {
      widget.onOpenMushafPage!(pageNumber);
      return;
    }
    final mushafProvider = context.read<MushafReadingProvider>();
    final profile = mushafProvider.freeReadProfileForMushaf(1);
    unawaited(mushafProvider.openUnifiedFreeRead());
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MushafReaderScreen(
          quranRepository: widget.repository,
          foundationRepository: _foundationRepo,
          profileId: profile.id,
          initialPage: pageNumber,
        ),
      ),
    );
  }

  void _onSearchQueryChanged(String query) {
    final trimmed = query.trim();

    // Direct reference and page reference evaluated immediately
    final dRef = parseQuranReference(trimmed);
    final pRef = dRef == null ? parsePageReference(trimmed) : null;

    setState(() {
      _directRef = dRef;
      _directPageRef = pRef;
    });

    _debounceTimer?.cancel();
    if (trimmed.length < 2) {
      setState(() {
        _topicSearchResults = [];
        _offlineVerseResults = [];
        _isOfflineSearching = false;
        _apiSearchResult = null;
        _isApiSearching = false;
      });
      return;
    }

    setState(() {
      _isOfflineSearching = true;
      _isApiSearching = true;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 180), () async {
      final topicsFuture = OfflineQuranDatabaseService.searchTopics(trimmed);
      final versesFuture =
          OfflineQuranDatabaseService.searchVerses(trimmed, limit: 35);
      final apiFuture = _foundationRepo.searchQuran(query: trimmed);

      final results = await Future.wait([topicsFuture, versesFuture]);
      if (mounted && _searchController.text.trim() == trimmed) {
        setState(() {
          _topicSearchResults = results[0];
          _offlineVerseResults = results[1];
          _isOfflineSearching = false;
        });
      }

      try {
        final apiRes = await apiFuture;
        if (mounted && _searchController.text.trim() == trimmed) {
          setState(() {
            _apiSearchResult = apiRes;
            _isApiSearching = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _isApiSearching = false;
          });
        }
      }
    });
  }

  Widget _buildDirectVerseJumpCard(
    BuildContext context,
    QuranDirectRef ref,
    bool isThai,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: widget.colors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: const Color(0xFF0E5A4A),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF0E5A4A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                    '⚡',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isThai ? 'ตรงกับอายะฮฺที่ระบุทันที' : 'DIRECT AYAH MATCH',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0E5A4A),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${ref.surahNameThai} (${ref.surahId}:${ref.verseId})',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: widget.colors.textStrong,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF8A6530).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isThai ? 'หน้า ${ref.pageNumber}' : 'Page ${ref.pageNumber}',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF8A6530),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: _buildVerseActionButtons(
              context: context,
              surahId: ref.surahId.toString(),
              verseId: ref.verseId.toString(),
              isThai: isThai,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectPageJumpCard(
    BuildContext context,
    QuranPageRef pageRef,
    bool isThai,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: widget.colors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: const Color(0xFF8A6530),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF8A6530),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                    '📄',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isThai ? 'ไปยังหน้ามุศหัฟทันที' : 'DIRECT MUSHAF PAGE JUMP',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8A6530),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      isThai
                          ? 'หน้า ${pageRef.page} · ${pageRef.surahNameThai} (ญุซอ์ ${pageRef.juzNumber})'
                          : 'Page ${pageRef.page} · ${pageRef.surahNameEn} (Juz ${pageRef.juzNumber})',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: widget.colors.textStrong,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton.icon(
                onPressed: () {
                  if (widget.onOpenMushafPage != null) {
                    widget.onOpenMushafPage!(pageRef.page);
                  } else {
                    widget.onOpenPage(pageRef.page);
                  }
                },
                icon: const Icon(Icons.import_contacts, size: 14),
                label: Text(
                  isThai
                      ? 'เปิดหน้า ${pageRef.page} ในมุศหัฟ'
                      : 'Open Page ${pageRef.page} in Mushaf',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  minimumSize: const Size(0, 32),
                  backgroundColor: const Color(0xFF8A6530),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openMushafForVerse(String surahId, String verseId) {
    final sId = int.tryParse(surahId) ?? 1;
    final vId = int.tryParse(verseId) ?? 1;
    final pageNumber = getMedinaMushafPageNumber(sId, vId);

    if (widget.onOpenMushafPage != null) {
      widget.onOpenMushafPage!(pageNumber, highlightVerseKey: '$sId:$vId');
      return;
    }

    final mushafProvider = context.read<MushafReadingProvider>();
    final profile = mushafProvider.freeReadProfileForMushaf(1);
    unawaited(mushafProvider.openUnifiedFreeRead());
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
  }

  void _openHifzForVerse(String surahId, String verseId) {
    final sId = int.tryParse(surahId) ?? 1;
    final vId = int.tryParse(verseId) ?? 1;
    final totalVerses = qcf.getVerseCount(sId);
    final endVerse = math.min(vId + 4, totalVerses);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HifzWizardSetupScreen(
          quranRepository: widget.repository,
          foundationRepository: _foundationRepo,
          initialMode: HifzSessionType.newVerses,
          initialSurah: sId,
          initialStartVerse: vId,
          initialEndVerse: endVerse,
          initialStep: 1,
        ),
      ),
    );
  }

  Widget _buildVerseActionButtons({
    required BuildContext context,
    required String surahId,
    required String verseId,
    required bool isThai,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: WrapAlignment.end,
      children: [
        _buildModePill(
          icon: Icons.menu_book_rounded,
          label: isThai ? 'ฉบับแปล' : 'Meaning',
          color: const Color(0xFF0E5A4A),
          onTap: () {
            if (widget.onOpenMeaning != null) {
              widget.onOpenMeaning!(surahId, verseId);
            } else {
              widget.onOpen(surahId, verseId);
            }
          },
        ),
        _buildModePill(
          icon: Icons.auto_stories_rounded,
          label: isThai ? 'มุศหัฟ' : 'Mushaf',
          color: const Color(0xFF8A6530),
          onTap: () => _openMushafForVerse(surahId, verseId),
        ),
        _buildModePill(
          icon: Icons.psychology_rounded,
          label: isThai ? 'ท่องจำ' : 'Hifz',
          color: const Color(0xFF2D6A4F),
          onTap: () => _openHifzForVerse(surahId, verseId),
        ),
      ],
    );
  }

  Widget _buildModePill({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withValues(alpha: 0.28),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.notoSansThai(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSurahReadOptionsModal({
    required BuildContext context,
    required String surahId,
    required String surahName,
    required String surahNameEn,
    required String arabicTitle,
    required int verseCount,
    required int startPage,
    required bool isMedinan,
    required bool isCompleted,
  }) {
    final settings = context.read<SettingsProvider>();
    final isThai = settings.languageCode == 'th';
    final colors = settings.getAppColors();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.borderSoft,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        surahId,
                        style: GoogleFonts.notoSansThai(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  surahName,
                                  style: GoogleFonts.notoSansThai(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: colors.textStrong,
                                  ),
                                ),
                              ),
                              if (isCompleted) ...[
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 15,
                                  color: Color(0xFF0E5A4A),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$surahNameEn · $verseCount ${isThai ? "อายะฮฺ" : "verses"} · ${isMedinan ? (isThai ? "มะดะนียะฮฺ" : "Medinan") : (isThai ? "มักกียะฮฺ" : "Meccan")} · ${isThai ? "หน้า" : "Page"} $startPage',
                            style: GoogleFonts.notoSansThai(
                              fontSize: 12,
                              color: colors.foreground.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (arabicTitle.isNotEmpty)
                      Text(
                        arabicTitle,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          fontFamily: 'UthmanicHafs',
                          fontSize: 24,
                          color: Color(0xFF0E5A4A),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: colors.borderSoft),
                const SizedBox(height: 12),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    onTap: () {
                      Navigator.pop(modalCtx);
                      if (widget.onOpenMeaning != null) {
                        widget.onOpenMeaning!(surahId, '1');
                      } else {
                        widget.onOpen(surahId, '1');
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E5A4A).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                        border: Border.all(
                          color: const Color(0xFF0E5A4A).withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0E5A4A),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.menu_book_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isThai ? 'อ่านฉบับแปลความหมาย' : 'Meaning Reader (Verse-by-Verse)',
                                  style: GoogleFonts.notoSansThai(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    color: colors.textStrong,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isThai
                                      ? 'แปลไทยพร้อมตัฟซีร, คำแปลศัพท์ & เสียงอ่าน'
                                      : 'Thai & English translation, tafsir & audio',
                                  style: GoogleFonts.notoSansThai(
                                    fontSize: 12,
                                    color: colors.foreground.withValues(alpha: 0.65),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: colors.foreground.withValues(alpha: 0.4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    onTap: () {
                      Navigator.pop(modalCtx);
                      _openMushafPage(startPage);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8A6530).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                        border: Border.all(
                          color: const Color(0xFF8A6530).withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8A6530),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.auto_stories_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isThai ? 'อ่านมุศหัฟมะดีนะฮฺ' : 'Medina Mushaf (Page View)',
                                  style: GoogleFonts.notoSansThai(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    color: colors.textStrong,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isThai
                                      ? 'เปิดอ่าน 15 บรรทัดมาตรฐาน (หน้าที่ $startPage)'
                                      : 'Standard 15-line Medina Mushaf (Page $startPage)',
                                  style: GoogleFonts.notoSansThai(
                                    fontSize: 12,
                                    color: colors.foreground.withValues(alpha: 0.65),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: colors.foreground.withValues(alpha: 0.4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    onTap: () {
                      Navigator.pop(modalCtx);
                      final sId = int.tryParse(surahId) ?? 1;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HifzWizardSetupScreen(
                            quranRepository: widget.repository,
                            foundationRepository: _foundationRepo,
                            initialMode: HifzSessionType.newVerses,
                            initialSurah: sId,
                            initialStartVerse: 1,
                            initialEndVerse: math.min(5, verseCount),
                            initialStep: 1,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D6A4F).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                        border: Border.all(
                          color: const Color(0xFF2D6A4F).withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2D6A4F),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.psychology_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isThai ? 'ท่องจำฮิฟซ์' : 'Hifz Memorize',
                                  style: GoogleFonts.notoSansThai(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    color: colors.textStrong,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isThai
                                      ? 'ฝึกท่องจำซูเราะฮฺนี้ด้วยระบบตักราร (Takrar)'
                                      : 'Memorize and review using spaced Takrar system',
                                  style: GoogleFonts.notoSansThai(
                                    fontSize: 12,
                                    color: colors.foreground.withValues(alpha: 0.65),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: colors.foreground.withValues(alpha: 0.4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showJuzReadOptionsModal({
    required BuildContext context,
    required int juzNumber,
    required String startSurahName,
    required String startSurahId,
    required String startAyah,
    required String endSurahName,
    required String endSurahId,
    required String endAyah,
    required int startPage,
    required int endPage,
  }) {
    final settings = context.read<SettingsProvider>();
    final isThai = settings.languageCode == 'th';
    final colors = settings.getAppColors();

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.borderSoft,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isThai ? 'ญุซอ์ที่ $juzNumber' : 'Juz $juzNumber',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.textStrong,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  endAyah.isNotEmpty
                      ? '$startSurahName ($startSurahId:$startAyah) ถึง $endSurahName ($endSurahId:$endAyah) · หน้า $startPage-$endPage'
                      : '$startSurahName ($startSurahId:$startAyah) ถึง $endSurahName · หน้า $startPage-$endPage',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 12.5,
                    color: colors.foreground.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: colors.borderSoft),
                const SizedBox(height: 12),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    onTap: () {
                      Navigator.pop(modalCtx);
                      if (widget.onOpenMeaning != null) {
                        widget.onOpenMeaning!(startSurahId, startAyah);
                      } else {
                        widget.onOpen(startSurahId, startAyah);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E5A4A).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                        border: Border.all(color: const Color(0xFF0E5A4A).withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0E5A4A),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.menu_book_rounded, size: 20, color: Colors.white),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isThai ? 'อ่านฉบับแปลความหมาย' : 'Meaning Reader',
                                  style: GoogleFonts.notoSansThai(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    color: colors.textStrong,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$startSurahName อายะฮฺที่ $startAyah',
                                  style: GoogleFonts.notoSansThai(
                                    fontSize: 12,
                                    color: colors.foreground.withValues(alpha: 0.65),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: colors.foreground.withValues(alpha: 0.4)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    onTap: () {
                      Navigator.pop(modalCtx);
                      _openMushafPage(startPage);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8A6530).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                        border: Border.all(color: const Color(0xFF8A6530).withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8A6530),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.auto_stories_rounded, size: 20, color: Colors.white),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isThai ? 'อ่านมุศหัฟมะดีนะฮฺ' : 'Medina Mushaf',
                                  style: GoogleFonts.notoSansThai(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    color: colors.textStrong,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isThai ? 'เปิดหน้าที่ $startPage' : 'Open page $startPage',
                                  style: GoogleFonts.notoSansThai(
                                    fontSize: 12,
                                    color: colors.foreground.withValues(alpha: 0.65),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: colors.foreground.withValues(alpha: 0.4)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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

  Widget _buildQuickFilterButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0E5A4A) : widget.colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? const Color(0xFF0E5A4A)
                : widget.colors.borderSoft,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: GoogleFonts.notoSansThai(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? Colors.white : widget.colors.foreground,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final settings = context.watch<SettingsProvider>();
    final isThai = settings.languageCode == 'th';
    final query = _searchController.text.toLowerCase();
    final isSearching = query.isNotEmpty;
    final readingProvider = context.watch<LocalReadingProvider>();
    final completedSurahs = _completedSurahs(readingProvider);
    final favoriteSurahIds = readingProvider.bookmarks
        .map((bookmark) => int.tryParse(bookmark.verse.surahId))
        .whereType<int>()
        .toSet();

    // Build surah list with optional translation search and filter
    final surahs = [
      for (var id = 1; id <= 114; id++)
        (
          id: id.toString(),
          num: id,
          name: surahDisplayName(id.toString(), isThai: isThai),
          nameEn: offlineSurahNamesEn[id.toString()] ?? '',
          arabic: offlineSurahNamesAr[id.toString()] ?? '',
          count: widget.repository.getSurahVerses(id.toString()).length,
          startPage: getMedinaMushafPageNumber(id, 1),
          isMedinan: _medinanSurahs.contains(id),
        ),
    ].where((surah) {
      if (isSearching) {
        return matchesSurahQuery(surah.id, query);
      }
      if (_surahFilter == 'fav') return favoriteSurahIds.contains(surah.num);
      return true;
    }).toList();

    final juz = [
      for (
        var index = 0;
        index < BrowseScreenState._juzStarts.length;
        index++
      )
        () {
          final sSurah = BrowseScreenState._juzStarts[index][0];
          final sAyah = BrowseScreenState._juzStarts[index][1];
          final end = BrowseScreenState.getJuzEnd(index);
          final eSurah = end != null ? end[0] : 114;
          final eAyah = end != null ? end[1] : 6;
          final startPage = getMedinaMushafPageNumber(sSurah, sAyah);
          final endPage = index < 29
              ? getMedinaMushafPageNumber(BrowseScreenState._juzStarts[index + 1][0], BrowseScreenState._juzStarts[index + 1][1]) - 1
              : 604;
          return (
            id: index + 1,
            startSurah: sSurah.toString(),
            startAyah: sAyah.toString(),
            startSurahName: widget.repository.getSurahName(sSurah.toString()).replaceFirst(RegExp(r'^\d+\.\s*'), ''),
            endSurah: eSurah.toString(),
            endAyah: eAyah == 9999 ? '' : eAyah.toString(),
            endSurahName: widget.repository.getSurahName(eSurah.toString()).replaceFirst(RegExp(r'^\d+\.\s*'), ''),
            startPage: startPage,
            endPage: endPage >= startPage ? endPage : startPage,
          );
        }(),
    ].where((item) {
      return query.isEmpty ||
          item.id.toString().contains(query) ||
          'juz ${item.id}'.contains(query) ||
          'ญุซอ์ ${item.id}'.contains(query) ||
          matchesSurahQuery(item.startSurah, query) ||
          matchesSurahQuery(item.endSurah, query);
    }).toList();

    return Scaffold(
      backgroundColor: widget.colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Search Field ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: widget.colors.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  border: Border.all(color: widget.colors.borderSoft),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchQueryChanged,
                  decoration: InputDecoration(
                    hintText: context.tr('search_hint'),
                    hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 14.0, right: 8.0),
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
                        : Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: IconButton(
                              icon: Icon(
                                Icons.mic_rounded,
                                color: colorScheme.primary,
                                size: 20,
                              ),
                              tooltip: isThai
                                  ? 'ค้นหาด้วยเสียง (อัลกุรอานภาษาอาหรับ)'
                                  : 'Voice Search (Arabic Quran)',
                              onPressed: () {
                                VoiceSearchSheet.show(
                                  context,
                                  repository: widget.repository,
                                  onOpenPage: (page, {highlightVerseKey}) {
                                    if (widget.onOpenMushafPage != null) {
                                      widget.onOpenMushafPage!(
                                        page,
                                        highlightVerseKey: highlightVerseKey,
                                      );
                                    } else {
                                      widget.onOpenPage(page);
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                  ),
                ),
              ),
            ),

            // ── Fixed quick filters (no horizontal hiding) ──────────────────
            if (!isSearching) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildQuickFilterButton(
                        label: isThai ? 'ทั้งหมด' : 'All',
                        selected: _surahFilter == 'all' && _mode == 'surah',
                        onTap: () => setState(() {
                          _surahFilter = 'all';
                          _mode = 'surah';
                        }),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildQuickFilterButton(
                        label: isThai ? 'ญุซอ์' : 'Juz',
                        selected: _mode == 'juz',
                        onTap: () => setState(() {
                          _surahFilter = 'juz';
                          _mode = 'juz';
                        }),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildQuickFilterButton(
                        label: isThai ? 'โปรด' : 'Fav',
                        selected: _surahFilter == 'fav',
                        onTap: () => setState(() {
                          _surahFilter = 'fav';
                          _mode = 'surah';
                        }),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildQuickFilterButton(
                        label: isThai ? 'หัวข้อ' : 'Topics',
                        selected: false,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TopicsScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

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
                      // Direct Reference Jump Card (e.g. 2:255, 72:1, ญิน 1, jin 1)
                      if (_directRef != null) ...[
                        _buildDirectVerseJumpCard(context, _directRef!, isThai),
                        const SizedBox(height: 14),
                      ],
                      // Direct Mushaf Page Jump Card (e.g. p 293, หน้า 293, 293)
                      if (_directPageRef != null && _directRef == null) ...[
                        _buildDirectPageJumpCard(context, _directPageRef!, isThai),
                        const SizedBox(height: 14),
                      ],
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
                            index: surah.id,
                            title: surah.name.replaceFirst(RegExp(r'^\d+\.\s*'), ''),
                            arabicTitle: surah.arabic,
                            subtitle: context.tr(
                              'ayat_count',
                              args: {'count': '${surah.count}'},
                            ),
                            icon: Icons.menu_book_outlined,
                            completed: completedSurahs.contains(surah.id),
                            onTap: () => _showSurahReadOptionsModal(
                              context: context,
                              surahId: surah.id,
                              surahName: surah.name.replaceFirst(RegExp(r'^\d+\.\s*'), ''),
                              surahNameEn: surah.nameEn,
                              arabicTitle: surah.arabic,
                              verseCount: surah.count,
                              startPage: surah.startPage,
                              isMedinan: surah.isMedinan,
                              isCompleted: completedSurahs.contains(surah.id),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Topic matches
                      if (_topicSearchResults.isNotEmpty) ...[
                        Text(
                          'หัวข้ออัลกุรอาน (${_topicSearchResults.length})',
                          style: textTheme.labelLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._topicSearchResults.map((t) {
                          final topicId = t['id'] as int;
                          final titleTh = t['title_th'] as String? ?? '';
                          final titleEn = t['title_en'] as String? ?? '';
                          final catTitle = t['category_title_th'] as String? ?? '';
                          final versesCount = t['verses_count'] as int? ?? 0;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(AppTheme.radius),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TopicVersesScreen(
                                        topicId: topicId,
                                        topicTitleTh: titleTh,
                                        topicTitleEn: titleEn,
                                        versesCount: versesCount,
                                      ),
                                    ),
                                  );
                                },
                                child: _SectionCard(
                                  colors: widget.colors,
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primary.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.topic_rounded,
                                          color: colorScheme.primary,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              titleTh,
                                              style: GoogleFonts.notoSansThai(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w700,
                                                color: colorScheme.onSurface,
                                              ),
                                            ),
                                            Text(
                                              '$titleEn • $catTitle',
                                              style: GoogleFonts.notoSans(
                                                fontSize: 12,
                                                color: colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: colorScheme.secondaryContainer.withValues(alpha: 0.7),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '$versesCount อายะฮฺ',
                                          style: GoogleFonts.notoSansThai(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: colorScheme.onSecondaryContainer,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        size: 18,
                                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 16),
                      ],
                      // Offline verse & translation matches (cross-language, bilingual, and exact)
                      if (_offlineVerseResults.isNotEmpty) ...[
                        Text(
                          isThai
                              ? 'อายะฮฺและคำแปลที่พบ (${_offlineVerseResults.length})'
                              : 'Verses & Translations (${_offlineVerseResults.length})',
                          style: textTheme.labelLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._offlineVerseResults.map((verse) {
                          final sId = verse['surah_id'].toString();
                          final vId = verse['verse_id'].toString();
                          final vKey = verse['verse_key'] as String? ?? '$sId:$vId';
                          final thText = verse['translation_th'] as String? ?? '';
                          final enText = verse['translation_en'] as String? ?? '';
                          final arText = verse['text_uthmani'] as String? ?? '';
                          final surahName = surahDisplayName(sId, isThai: isThai);

                          final isLatin = RegExp(r'^[a-zA-Z0-9\s]+$').hasMatch(_searchController.text.trim());
                          final displayText = (isLatin && enText.isNotEmpty && thText.isNotEmpty)
                              ? '$thText ($enText)'
                              : (thText.isNotEmpty ? thText : enText);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AppTheme.radius),
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
                                            isThai
                                                ? 'ซูเราะฮฺ $surahName ($vKey)'
                                                : 'Surah $surahName ($vKey)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme.onPrimaryContainer,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (arText.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          arText,
                                          textDirection: TextDirection.rtl,
                                          style: GoogleFonts.amiri(
                                            fontSize: 16,
                                            height: 1.8,
                                            color: widget.colors.textStrong,
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    Text(
                                      displayText,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: widget.colors.foreground,
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: _buildVerseActionButtons(
                                        context: context,
                                        surahId: sId,
                                        verseId: vId,
                                        isThai: isThai,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 16),
                      ],
                      // Loading indicator
                      if ((_isOfflineSearching || _isApiSearching) && _offlineVerseResults.isEmpty)
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
                                            context.read<SettingsProvider>().languageCode == 'th'
                                                ? 'ซูเราะฮฺ ${widget.repository.getSurahName(item.surahId).replaceFirst(RegExp(r'^\d+\.\s*'), '')} (${item.verseKey})'
                                                : 'Surah ${widget.repository.getSurahName(item.surahId).replaceFirst(RegExp(r'^\d+\.\s*'), '')} (${item.verseKey})',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme.onPrimaryContainer,
                                            ),
                                          ),
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
                                    const SizedBox(height: 10),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: _buildVerseActionButtons(
                                        context: context,
                                        surahId: item.surahId,
                                        verseId: item.verseId,
                                        isThai: context.read<SettingsProvider>().languageCode == 'th',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (surahs.isEmpty &&
                          _topicSearchResults.isEmpty &&
                          _offlineVerseResults.isEmpty &&
                          (_apiSearchResult == null ||
                              _apiSearchResult!.items.isEmpty) &&
                          _directRef == null &&
                          _directPageRef == null &&
                          !_isOfflineSearching &&
                          !_isApiSearching)
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
                      if (_surahFilter == 'juz' || _mode == 'juz')
                        ...juz.map(
                          (item) => _JuzCard(
                            colors: widget.colors,
                            juzNumber: item.id,
                            startSurahName: item.startSurahName,
                            startSurahId: item.startSurah,
                            startAyah: item.startAyah,
                            endSurahName: item.endSurahName,
                            endSurahId: item.endSurah,
                            endAyah: item.endAyah,
                            startPage: item.startPage,
                            endPage: item.endPage,
                            onTap: () => _showJuzReadOptionsModal(
                              context: context,
                              juzNumber: item.id,
                              startSurahName: item.startSurahName,
                              startSurahId: item.startSurah,
                              startAyah: item.startAyah,
                              endSurahName: item.endSurahName,
                              endSurahId: item.endSurah,
                              endAyah: item.endAyah,
                              startPage: item.startPage,
                              endPage: item.endPage,
                            ),
                          ),
                        )
                      else if (surahs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 48,
                          ),
                          child: Center(
                            child: Text(
                              isThai
                                  ? 'ยังไม่มีซูเราะฮ์ที่บันทึกไว้'
                                  : 'No bookmarked surahs yet.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.notoSansThai(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        )
                      else
                        ...surahs.map(
                          (surah) => _SurahCard(
                            colors: widget.colors,
                            id: surah.id,
                            title: surah.name.replaceFirst(RegExp(r'^\d+\.\s*'), ''),
                            englishTitle: surah.nameEn,
                            arabicTitle: surah.arabic,
                            count: surah.count,
                            startPage: surah.startPage,
                            isMedinan: surah.isMedinan,
                            completed: completedSurahs.contains(surah.id),
                            onTap: () => _showSurahReadOptionsModal(
                              context: context,
                              surahId: surah.id,
                              surahName: surah.name.replaceFirst(RegExp(r'^\d+\.\s*'), ''),
                              surahNameEn: surah.nameEn,
                              arabicTitle: surah.arabic,
                              verseCount: surah.count,
                              startPage: surah.startPage,
                              isMedinan: surah.isMedinan,
                              isCompleted: completedSurahs.contains(surah.id),
                            ),
                          ),
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

class _SurahCard extends StatelessWidget {
  final AppThemeColors colors;
  final String id;
  final String title;
  final String englishTitle;
  final String arabicTitle;
  final int count;
  final int startPage;
  final bool isMedinan;
  final bool completed;
  final VoidCallback onTap;

  const _SurahCard({
    required this.colors,
    required this.id,
    required this.title,
    required this.englishTitle,
    required this.arabicTitle,
    required this.count,
    required this.startPage,
    required this.isMedinan,
    required this.completed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: colors.borderSoft),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Surah Number Badge
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.surfaceMuted,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.borderSoft),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    id,
                    style: GoogleFonts.notoSansThai(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: colors.textStrong,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Surah Name & Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.notoSansThai(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: colors.textStrong,
                              ),
                            ),
                          ),
                          if (completed) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF2EE),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_rounded,
                                      size: 10.5, color: Color(0xFF0E5A4A)),
                                  const SizedBox(width: 2),
                                  Text(
                                    'อ่านจบ',
                                    style: GoogleFonts.notoSansThai(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0E5A4A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4.5, vertical: 1),
                            decoration: BoxDecoration(
                              color: isMedinan
                                  ? const Color(0xFFEAF2EE)
                                  : const Color(0xFFF6EFE3),
                              borderRadius: BorderRadius.circular(3.5),
                              border: Border.all(
                                color: isMedinan
                                    ? const Color(0xFFB7D4C7)
                                    : const Color(0xFFD7C299),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              isMedinan ? 'มะดะนียะฮฺ' : 'มักกียะฮฺ',
                              style: GoogleFonts.notoSansThai(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: isMedinan
                                    ? const Color(0xFF0E5A4A)
                                    : const Color(0xFF8A6530),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '$count อายะฮฺ · หน้า $startPage · $englishTitle',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.notoSans(
                                fontSize: 11,
                                color: colors.foreground.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Arabic Name + Arrow
                if (arabicTitle.isNotEmpty) ...[
                  Text(
                    arabicTitle,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      fontFamily: 'UthmanicHafs',
                      fontSize: 18,
                      color: Color(0xFF0E5A4A),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: colors.foreground.withValues(alpha: 0.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _JuzCard extends StatelessWidget {
  final AppThemeColors colors;
  final int juzNumber;
  final String startSurahName;
  final String startSurahId;
  final String startAyah;
  final String endSurahName;
  final String endSurahId;
  final String endAyah;
  final int startPage;
  final int endPage;
  final VoidCallback onTap;

  const _JuzCard({
    required this.colors,
    required this.juzNumber,
    required this.startSurahName,
    required this.startSurahId,
    required this.startAyah,
    required this.endSurahName,
    required this.endSurahId,
    required this.endAyah,
    required this.startPage,
    required this.endPage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: colors.borderSoft),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.surfaceMuted,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.borderSoft),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$juzNumber',
                    style: GoogleFonts.notoSansThai(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: colors.textStrong,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ญุซอ์ที่ $juzNumber',
                        style: GoogleFonts.notoSansThai(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: colors.textStrong,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        endAyah.isNotEmpty
                            ? '$startSurahName ($startSurahId:$startAyah) ถึง $endSurahName ($endSurahId:$endAyah)'
                            : '$startSurahName ($startSurahId:$startAyah) ถึง $endSurahName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSansThai(
                          fontSize: 11.5,
                          color: colors.foreground.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'หน้า $startPage-$endPage',
                  style: GoogleFonts.notoSans(
                    fontSize: 11,
                    color: colors.foreground.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: colors.foreground.withValues(alpha: 0.35),
                ),
              ],
            ),
          ),
        ),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
  final String? index;
  final String title;
  final String? arabicTitle;
  final String subtitle;
  final IconData icon;
  final bool completed;
  final VoidCallback onTap;

  const _SimpleLinkRow({
    required this.colors,
    this.index,
    required this.title,
    this.arabicTitle,
    required this.subtitle,
    required this.icon,
    this.completed = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: colors.borderSoft),
            ),
            child: Row(
              children: [
                if (index != null) ...[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colors.surfaceMuted,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.borderSoft),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      index!,
                      style: GoogleFonts.notoSansThai(
                        color: colors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ] else ...[
                  Icon(icon, color: colors.primary),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSansThai(
                          color: colors.textStrong,
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.notoSansThai(
                          color: colors.foreground.withValues(alpha: 0.7),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (arabicTitle != null && arabicTitle!.isNotEmpty) ...[
                  Text(
                    arabicTitle!,
                    style: const TextStyle(
                      fontFamily: 'UthmanicHafs',
                      fontSize: 17,
                      color: Color(0xFF0E5A4A),
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(width: 8),
                ],
                if (completed) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF0E5A4A),
                    size: 18,
                  ),
                ],
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.foreground.withValues(alpha: 0.5),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
