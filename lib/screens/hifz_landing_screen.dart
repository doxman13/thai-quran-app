// lib/screens/hifz_landing_screen.dart
//
// Landing page for Hifz (Memorization) Mode.
// Aligned with thai-quran-web's HifzLanding.tsx:
// 1. Active Session Resume Banner (with Resume & Discard)
// 2. Deep Emerald Takrar Hero Banner with [New Verses] and [Review] CTAs
// 3. 3 Interactive Stat/Control Pills (Mastered / 114, In Progress / 114, Input Mode -> Settings)
// 4. Embedded 114-Surah Mastery List with Filter Chips & Search

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:qcf_quran/qcf_quran.dart' as qcf;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/offline_surah_names.dart';
import '../data/quran_foundation_repository.dart';
import '../data/quran_repository.dart';
import '../database/hifz_repository.dart';
import '../models/hifz_session_config.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../utils/hifz_mastery_utils.dart';
import '../widgets/surah_mastery_card.dart';
import 'hifz_guide_screen.dart';
import 'hifz_history_screen.dart';
import 'hifz_memorize_screen.dart';
import 'hifz_settings_screen.dart';
import 'hifz_wizard_setup_screen.dart';

const _juzSurahStarts = <int>[
  1, 2, 2, 3, 4, 4, 5, 6, 7, 8, 9, 10, 11, 12, 15,
  17, 18, 19, 21, 22, 23, 25, 27, 29, 37, 46, 51, 58, 67, 78,
];

int _juzOfSurah(int surah) {
  int juz = 1;
  for (int i = _juzSurahStarts.length - 1; i >= 0; i--) {
    if (surah >= _juzSurahStarts[i]) {
      juz = i + 1;
      break;
    }
  }
  return juz;
}

enum _MasteryFilter { all, inProgress, mastered, notStarted, juz29And30 }

class HifzLandingScreen extends StatefulWidget {
  final QuranRepository quranRepository;
  final QuranFoundationRepository foundationRepository;
  final bool isEmbedded;

  const HifzLandingScreen({
    super.key,
    required this.quranRepository,
    required this.foundationRepository,
    this.isEmbedded = false,
  });

  @override
  State<HifzLandingScreen> createState() => _HifzLandingScreenState();
}

class _HifzLandingScreenState extends State<HifzLandingScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _masteredCount = 0;
  int _inProgressCount = 0;
  bool _hasActiveSession = false;
  ActiveSessionSnapshot? _activeSessionSnapshot;
  Map<int, SurahCompletionRecord> _completionMap = {};
  Map<int, SurahMasterySummary> _summaries = {};
  bool _loading = true;
  _MasteryFilter _filterMode = _MasteryFilter.all;
  String _searchQuery = '';

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _loadStats(syncCloud: true);
    try {
      _authSubscription =
          Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        if (!mounted) return;
        if (data.event == AuthChangeEvent.signedIn ||
            data.event == AuthChangeEvent.tokenRefreshed ||
            data.event == AuthChangeEvent.signedOut) {
          _loadStats(syncCloud: true);
        }
      });
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _loadStats(syncCloud: true);
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _animController.dispose();
    super.dispose();
  }

  String? _safeCurrentUserId() {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadStats({bool syncCloud = false}) async {
    final repo = HifzRepository();

    Future<void> applyLocalState() async {
      final records = await repo.getAllCompletionRecords();
      final history = await repo.getHistory(limit: 500);
      final activeSession = await repo.loadActiveSession();
      final map = <int, SurahCompletionRecord>{};
      for (final r in records) {
        map[r.surahNumber] = r;
      }
      final summaries = buildSurahMasterySummaries(
        records: records,
        history: history,
        activeSession: activeSession,
        masteredReviewThreshold: SurahMasteryCard.masteredReviewThreshold,
      );
      final masteredCount = summaries.values
          .where((s) => s.status == HifzMasteryStatus.mastered)
          .length;
      final inProgressCount = summaries.values
          .where((s) => s.status == HifzMasteryStatus.inProgress)
          .length;
      if (!mounted) return;
      setState(() {
        _completionMap = map;
        _summaries = summaries;
        _masteredCount = masteredCount;
        _inProgressCount = inProgressCount;
        _activeSessionSnapshot = activeSession;
        _hasActiveSession = activeSession != null;
        _loading = false;
      });
      _animController.forward();
    }

    await applyLocalState();

    if (syncCloud) {
      final userId = _safeCurrentUserId();
      if (userId != null) {
        await Future.wait([
          repo.syncWithSupabase(userId),
          repo.syncHistoryWithSupabase(),
        ]);
        await applyLocalState();
      }
    }
  }

  int get _notStartedCount =>
      math.max(0, 114 - _masteredCount - _inProgressCount);

  Future<void> _openNewVerses({
    int? surahNum,
    int? startVerse,
    int? endVerse,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final targetSurah = surahNum ?? (prefs.getInt('hifz_nv_surah') ?? 67);
    final verseCount = qcf.getVerseCount(targetSurah);
    final resolvedStart = startVerse ??
        (surahNum != null ? 1 : (prefs.getInt('hifz_nv_start_verse') ?? 1));
    final resolvedEnd = endVerse ??
        (surahNum != null
            ? math.min(5, verseCount)
            : (prefs.getInt('hifz_nv_end_verse') ?? 5));

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HifzWizardSetupScreen(
          quranRepository: widget.quranRepository,
          foundationRepository: widget.foundationRepository,
          initialMode: HifzSessionType.newVerses,
          initialSurah: targetSurah,
          initialStartVerse: resolvedStart.clamp(1, verseCount),
          initialEndVerse: resolvedEnd.clamp(resolvedStart.clamp(1, verseCount), verseCount),
          initialRepeatStart: surahNum != null
              ? resolvedStart.clamp(1, verseCount)
              : (prefs.getInt('hifz_nv_repeat_start') ?? 1),
          initialStep: 1,
        ),
      ),
    );
    if (mounted) {
      _loadStats(syncCloud: true);
    }
  }

  Future<void> _openReview({int? surahNum}) async {
    if (!mounted) return;
    final verseCount = surahNum != null ? qcf.getVerseCount(surahNum) : null;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HifzWizardSetupScreen(
          quranRepository: widget.quranRepository,
          foundationRepository: widget.foundationRepository,
          initialMode: HifzSessionType.review,
          initialSurah: surahNum,
          initialStartSurah: surahNum,
          initialEndSurah: surahNum,
          initialStartVerse: surahNum != null ? 1 : null,
          initialEndVerse: verseCount,
          initialStep: 1,
        ),
      ),
    );
    if (mounted) {
      _loadStats(syncCloud: true);
    }
  }

  void _openGuide() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HifzGuideScreen(
          onStartNewVerses: () => _openNewVerses(),
          onStartReview: () => _openReview(),
        ),
      ),
    );
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HifzHistoryScreen(
          quranRepository: widget.quranRepository,
          foundationRepository: widget.foundationRepository,
        ),
      ),
    );
  }

  void _openHifzSettings() {
    HifzControlsSheet.show(context);
  }

  Future<void> _resumeSession() async {
    final snap =
        _activeSessionSnapshot ?? await HifzRepository().loadActiveSession();
    if (snap == null || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HifzMemorizeScreen(
          quranRepository: widget.quranRepository,
          foundationRepository: widget.foundationRepository,
          resumeSessionSnapshot: snap,
        ),
      ),
    );
    if (mounted) {
      _loadStats(syncCloud: true);
    }
  }

  Future<void> _discardActiveSession() async {
    await HifzRepository().clearActiveSession(
      sessionId: _activeSessionSnapshot?.sessionId,
    );
    if (mounted) {
      _loadStats();
    }
  }

  List<int> _getFilteredSurahs(bool isThai) {
    final all = List.generate(114, (i) => i + 1);
    final byFilter = switch (_filterMode) {
      _MasteryFilter.mastered => all
          .where((s) => _summaries[s]?.status == HifzMasteryStatus.mastered)
          .toList(),
      _MasteryFilter.inProgress => all
          .where((s) => _summaries[s]?.status == HifzMasteryStatus.inProgress)
          .toList(),
      _MasteryFilter.notStarted => all
          .where(
            (s) =>
                (_summaries[s]?.status ?? HifzMasteryStatus.notStarted) ==
                HifzMasteryStatus.notStarted,
          )
          .toList(),
      _MasteryFilter.juz29And30 =>
        all.where((s) => _juzOfSurah(s) >= 29).toList(),
      _MasteryFilter.all => all,
    };

    final query = _searchQuery.trim();
    if (query.isEmpty) return byFilter;

    return byFilter.where((s) {
      return matchesSurahQuery(s.toString(), query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final settings = Provider.of<SettingsProvider>(context);
    final isThai = settings.languageCode == 'th';
    final filteredSurahs = _getFilteredSurahs(isThai);

    return Scaffold(
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              title: Text(
                isThai ? 'โหมดท่องจำ (Hifz)' : 'Hifz Memorization',
                style: GoogleFonts.notoSansThai(fontWeight: FontWeight.w700),
              ),
              centerTitle: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.help_outline_rounded),
                  tooltip: isThai ? 'คู่มือการท่องจำ' : 'How to Hifz Guide',
                  onPressed: _openGuide,
                ),
                IconButton(
                  icon: const Icon(Icons.history_rounded),
                  tooltip: isThai ? 'ประวัติการฝึกฝน' : 'Practice History',
                  onPressed: _openHistory,
                ),
                IconButton(
                  icon: const Icon(Icons.tune_rounded),
                  tooltip: isThai ? 'ตั้งค่าฮิฟซ์' : 'Hifz Controls',
                  onPressed: _openHifzSettings,
                ),
              ],
            ),
      body: RefreshIndicator(
        onRefresh: () => _loadStats(syncCloud: true),
        child: CustomScrollView(
          slivers: [
            // ── Top Bar when Embedded in Bottom Nav ────────────────────────
            if (widget.isEmbedded)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.psychology_alt_rounded,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isThai
                              ? 'ท่องจำอัลกุรอาน (Hifz)'
                              : 'Hifz Memorization',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.notoSansThai(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.help_outline_rounded, size: 20),
                        tooltip: isThai ? 'คู่มือการท่องจำ' : 'How to Hifz Guide',
                        onPressed: _openGuide,
                      ),
                      IconButton(
                        icon: const Icon(Icons.history_rounded, size: 20),
                        tooltip: isThai ? 'ประวัติการฝึกฝน' : 'Practice History',
                        onPressed: _openHistory,
                      ),
                      IconButton(
                        icon: const Icon(Icons.tune_rounded, size: 20),
                        tooltip: isThai ? 'ตั้งค่าอุปกรณ์ฮิฟซ์' : 'Hifz Controls',
                        onPressed: _openHifzSettings,
                      ),
                    ],
                  ),
                ),
              ),

            // ── 1. Active Session Resume Banner ────────────────────────────
            if (_hasActiveSession && !_loading)
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: _buildResumeBanner(colorScheme, textTheme, isThai),
                ),
              ),

            // ── 2. Deep Emerald Takrar Hero Card ───────────────────────────
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: _buildHeroCard(colorScheme, textTheme, isThai),
              ),
            ),

            // ── 3. 114-Surah Mastery Header + Input Mode + Search ──────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isThai
                                ? 'ความคืบหน้าทั้ง 114 ซูเราะฮฺ'
                                : 'Surah Mastery (114)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.notoSansThai(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildInputModePill(colorScheme, settings, isThai),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Search bar
                    TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: isThai
                            ? 'ค้นหาชื่อซูเราะฮฺ หรือลำดับที่ (1-114)...'
                            : 'Search surah name or number (1-114)...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 16),
                                onPressed: () =>
                                    setState(() => _searchQuery = ''),
                              )
                            : null,
                        isDense: true,
                        filled: true,
                        fillColor: colorScheme.surfaceContainerLow,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                          borderSide: BorderSide(
                            color: colorScheme.outlineVariant
                                .withValues(alpha: 0.35),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                          borderSide: BorderSide(
                            color: colorScheme.outlineVariant
                                .withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _MasteryFilter.values.map((mode) {
                          final selected = _filterMode == mode;
                          final label = switch (mode) {
                            _MasteryFilter.all =>
                              isThai ? 'ทั้งหมด 114' : 'All (114)',
                            _MasteryFilter.inProgress => isThai
                                ? 'กำลังท่อง ($_inProgressCount)'
                                : 'In Progress ($_inProgressCount)',
                            _MasteryFilter.mastered => isThai
                                ? 'จำขึ้นใจแล้ว ($_masteredCount)'
                                : 'Mastered ($_masteredCount)',
                            _MasteryFilter.notStarted => isThai
                                ? 'ยังไม่เริ่ม ($_notStartedCount)'
                                : 'Not Started ($_notStartedCount)',
                            _MasteryFilter.juz29And30 =>
                              isThai ? 'ญุซอ์ 29 & 30' : 'Juz 29 & 30',
                          };
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(label),
                              selected: selected,
                              onSelected: (_) =>
                                  setState(() => _filterMode = mode),
                              selectedColor: colorScheme.primary,
                              labelStyle: GoogleFonts.notoSansThai(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? colorScheme.onPrimary
                                    : colorScheme.onSurfaceVariant,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusSm),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── 5. Embedded Surah Mastery List ─────────────────────────────
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filteredSurahs.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.menu_book_outlined,
                        size: 40,
                        color: colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isThai
                            ? 'ยังไม่มีซูเราะฮฺในหมวดหมู่นี้'
                            : 'No surahs match this filter yet.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 36),
                sliver: SliverList.separated(
                  itemCount: filteredSurahs.length,
                  separatorBuilder: (context, _) => Container(
                    color: colorScheme.surfaceContainerLow,
                    child: Divider(
                      height: 1,
                      thickness: 0.7,
                      indent: 60,
                      endIndent: 14,
                      color:
                          colorScheme.outlineVariant.withValues(alpha: 0.35),
                    ),
                  ),
                  itemBuilder: (context, index) {
                    final surahNum = filteredSurahs[index];
                    final record = _completionMap[surahNum];
                    final surahName = surahDisplayName(
                      surahNum.toString(),
                      isThai: isThai,
                    );
                    final verseCount = qcf.getVerseCount(surahNum);
                    final juz = _juzOfSurah(surahNum);
                    final isFirst = index == 0;
                    final isLast = index == filteredSurahs.length - 1;
                    final groupedRadius = BorderRadius.vertical(
                      top: isFirst
                          ? const Radius.circular(AppTheme.radius)
                          : Radius.zero,
                      bottom: isLast
                          ? const Radius.circular(AppTheme.radius)
                          : Radius.zero,
                    );

                    return SurahMasteryCard(
                      surahNumber: surahNum,
                      surahName: surahName,
                      verseCount: verseCount,
                      juz: juz,
                      record: record,
                      summary: _summaries[surahNum],
                      isThai: isThai,
                      groupedRow: true,
                      groupedBorderRadius: groupedRadius,
                      onTap: () => _showSurahActionSheet(context, surahNum),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── 1. Active Session Resume Banner ─────────────────────────────────────────
  Widget _buildResumeBanner(
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isThai,
  ) {
    final snap = _activeSessionSnapshot;
    final subtitle = snap != null
        ? _getResumeSessionSubtitle(snap, isThai)
        : (isThai
            ? 'แตะเพื่อทำต่อจากจุดที่ค้างไว้'
            : 'Tap to resume where you left off');
    final isNewVerses = snap?.sessionType == HifzSessionType.newVerses;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EB),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: const Color(0xFFD4A853).withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFD4A853).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: const Icon(
              Icons.play_circle_fill_rounded,
              color: Color(0xFF9A6B16),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isThai
                      ? (isNewVerses
                          ? 'มีเซสชันท่องใหม่ค้างอยู่'
                          : 'มีเซสชันทบทวนค้างอยู่')
                      : (isNewVerses
                          ? 'Active New Verses Session'
                          : 'Active Review Session'),
                  style: GoogleFonts.notoSansThai(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF9A6B16),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.notoSansThai(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2B2110),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _discardActiveSession,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF7C5E24),
              visualDensity: VisualDensity.compact,
            ),
            child: Text(isThai ? 'ยกเลิก' : 'Discard'),
          ),
          const SizedBox(width: 4),
          FilledButton(
            onPressed: _resumeSession,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0E5A4A),
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
            ),
            child: Text(isThai ? 'ท่องต่อ' : 'Resume'),
          ),
        ],
      ),
    );
  }

  String _getResumeSessionSubtitle(ActiveSessionSnapshot snap, bool isThai) =>
      formatActiveSessionSubtitle(snap, isThai: isThai);

  // ── 2. Deep Emerald Takrar Hero Card ────────────────────────────────────────
  Widget _buildHeroCard(
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isThai,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0E5A4A),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: const Color(0xFF0A4437),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFD4A853).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(
                color: const Color(0xFFD4A853).withValues(alpha: 0.45),
              ),
            ),
            child: Text(
              isThai
                  ? 'ระบบตัครอร (Takrar Method)'
                  : 'Takrar Memorization System',
              style: GoogleFonts.notoSansThai(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFF3D28A),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isThai
                ? 'ท่องจำอายะฮฺใหม่ & ทบทวนความจำ'
                : 'Memorize New Verses & Protect Retention',
            style: GoogleFonts.notoSansThai(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isThai
                ? 'อ่านเปิด 10 รอบ + ซ่อนทบทวน 5 รอบ พร้อมเชื่อมโยงอายะฮฺ'
                : '10x visible + 5x hidden active recall with verse linking.',
            style: GoogleFonts.notoSansThai(
              fontSize: 12.5,
              color: Colors.white.withValues(alpha: 0.8),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openNewVerses(),
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: Text(
                    isThai ? 'เริ่มท่องอายะฮฺใหม่' : 'New Verses',
                    style: GoogleFonts.notoSansThai(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD4A853),
                    foregroundColor: const Color(0xFF1E1608),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openReview(),
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: Text(
                    isThai ? 'ทบทวนความจำ' : 'Review Mode',
                    style: GoogleFonts.notoSansThai(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFBF9F5),
                    foregroundColor: const Color(0xFF0E5A4A),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 3. Compact Input Mode Pill ──────────────────────────────────────────────
  Widget _buildInputModePill(
    ColorScheme colorScheme,
    SettingsProvider settings,
    bool isThai,
  ) {
    final colors = context.appColors;
    final inputModeLabel = switch (settings.hifzInputMode) {
      HifzInputMode.inAppTally => isThai ? 'ปุ่มบนจอ' : 'On-Screen',
      HifzInputMode.bluetoothShutter => isThai ? 'รีโมทบลูทูธ' : 'BT Shutter',
      HifzInputMode.bleSmartRing => isThai ? 'Smart Ring' : 'Smart Ring',
    };
    final inputModeIcon = switch (settings.hifzInputMode) {
      HifzInputMode.bleSmartRing => Icons.watch_rounded,
      HifzInputMode.bluetoothShutter => Icons.bluetooth_searching_rounded,
      HifzInputMode.inAppTally => Icons.touch_app_rounded,
    };

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: _openHifzSettings,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(inputModeIcon, size: 14, color: colors.primary),
              const SizedBox(width: 5),
              Text(
                inputModeLabel,
                style: GoogleFonts.notoSansThai(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 15,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSurahActionSheet(BuildContext context, int surahNum) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final colors = context.appColors;
    final isThai =
        Provider.of<SettingsProvider>(context, listen: false).languageCode ==
            'th';
    final record = _completionMap[surahNum];
    final summary = _summaries[surahNum];
    final isCompleted =
        summary?.newVersesCompleted ?? (record?.newVersesCompleted == true);
    final isInProgress = summary?.status == HifzMasteryStatus.inProgress;
    final hasActiveHere = summary?.hasActiveSession == true;
    final furthest = summary?.furthestCompletedVerse ?? 0;
    final reviewCount = summary?.reviewCount ?? (record?.reviewCount ?? 0);
    final names = surahNamePair(surahNum.toString());
    final verseCount = qcf.getVerseCount(surahNum);
    final juz = _juzOfSurah(surahNum);
    final hasPartialContinue =
        !isCompleted && furthest > 0 && furthest < verseCount;
    final nextStartVerse = hasPartialContinue ? furthest + 1 : 1;
    final nextEndVerse =
        math.min(nextStartVerse + 4, verseCount);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radius),
        ),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$surahNum',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isThai ? names.th : names.en,
                            style: GoogleFonts.notoSansThai(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '$verseCount ${isThai ? 'อายะฮฺ' : 'verses'} • Juz $juz${hasPartialContinue ? ' • ${isThai ? 'ถึงอายะฮฺ $furthest/$verseCount' : 'Up to $furthest/$verseCount'}' : ''}${reviewCount > 0 ? ' • ${isThai ? 'ทบทวนแล้ว $reviewCount ครั้ง' : 'Reviewed ×$reviewCount'}' : ''}',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isCompleted)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.success.withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        child: Text(
                          isThai ? 'สำเร็จแล้ว' : 'Completed',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colors.success,
                          ),
                        ),
                      )
                    else if (isInProgress)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.mushafGold.withValues(alpha: 0.14),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        child: Text(
                          isThai ? 'กำลังท่อง' : 'In Progress',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colors.mushafGold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                if (hasActiveHere && _activeSessionSnapshot != null) ...[
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                    ),
                    tileColor: const Color(0xFFFFF8EB),
                    leading: CircleAvatar(
                      backgroundColor:
                          const Color(0xFFD4A853).withValues(alpha: 0.22),
                      child: const Icon(
                        Icons.play_circle_fill_rounded,
                        color: Color(0xFF9A6B16),
                      ),
                    ),
                    title: Text(
                      isThai ? 'ท่องต่อจากที่ค้างไว้' : 'Resume Paused Session',
                      style: GoogleFonts.notoSansThai(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2B2110),
                      ),
                    ),
                    subtitle: Text(
                      formatActiveSessionSubtitle(_activeSessionSnapshot!,
                          isThai: isThai),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF7C5E24),
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _resumeSession();
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                  tileColor: colorScheme.surfaceContainerLow,
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: colorScheme.primary,
                    ),
                  ),
                  title: Text(
                    isThai
                        ? (hasPartialContinue
                            ? 'ท่องต่ออายะฮฺใหม่ (Takrar)'
                            : 'ท่องจำอายะฮฺใหม่ (Takrar)')
                        : (hasPartialContinue
                            ? 'Continue New Verses (Takrar)'
                            : 'Memorize New Verses (Takrar)'),
                    style: GoogleFonts.notoSansThai(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    isThai
                        ? 'เริ่มที่อายะฮฺ $nextStartVerse–$nextEndVerse (ปรับช่วงได้)'
                        : 'Starts at verses $nextStartVerse–$nextEndVerse (customizable)',
                    style: textTheme.bodySmall,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _openNewVerses(
                      surahNum: surahNum,
                      startVerse: nextStartVerse,
                      endVerse: nextEndVerse,
                    );
                  },
                ),
                const SizedBox(height: 10),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                  tileColor: colorScheme.surfaceContainerLow,
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.tertiaryContainer,
                    child: Icon(
                      Icons.replay_rounded,
                      color: colorScheme.tertiary,
                    ),
                  ),
                  title: Text(
                    isThai
                        ? 'ทบทวนซูเราะฮฺนี้ (Review)'
                        : 'Review This Surah',
                    style: GoogleFonts.notoSansThai(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    isThai
                        ? 'ทบทวนอายะฮฺ 1–$verseCount ด้วยวงจร 2x/2x'
                        : 'Review verses 1–$verseCount with 2x/2x cycle',
                    style: textTheme.bodySmall,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _openReview(surahNum: surahNum);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

