// lib/screens/hifz_landing_screen.dart
//
// Landing page for Hifz (Memorization) Mode.
// Aligned with thai-quran-web's HifzLanding.tsx:
// 1. Active Session Resume Banner (with Resume & Discard)
// 2. Deep Emerald Takrar Hero Banner with [New Verses] and [Review] CTAs
// 3. 3 Interactive Stat/Control Pills (Mastered / 114, In Progress / 114, Input Mode -> Settings)
// 4. Embedded 114-Surah Mastery List with Filter Chips & Search

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:qcf_quran/qcf_quran.dart' as qcf;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/offline_surah_names.dart';
import '../data/quran_foundation_repository.dart';
import '../data/quran_repository.dart';
import '../database/hifz_repository.dart';
import '../models/hifz_session_config.dart';
import '../providers/settings_provider.dart';
import 'hifz_guide_screen.dart';
import 'hifz_history_screen.dart';
import 'hifz_memorize_screen.dart';
import 'hifz_wizard_setup_screen.dart';
import 'settings_screen.dart';

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

enum _MasteryFilter { all, inProgress, mastered, juz29And30 }

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
    with SingleTickerProviderStateMixin {
  int _masteredCount = 0;
  int _inProgressCount = 0;
  bool _hasActiveSession = false;
  ActiveSessionSnapshot? _activeSessionSnapshot;
  Map<int, SurahCompletionRecord> _completionMap = {};
  bool _loading = true;
  _MasteryFilter _filterMode = _MasteryFilter.all;
  String _searchQuery = '';

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _loadStats();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final repo = HifzRepository();
    final records = await repo.getAllCompletionRecords();
    final activeSession = await repo.loadActiveSession();
    final map = <int, SurahCompletionRecord>{};
    for (final r in records) {
      map[r.surahNumber] = r;
    }
    if (!mounted) return;
    setState(() {
      _completionMap = map;
      _masteredCount = records
          .where((r) => r.newVersesCompleted && r.reviewCount >= 3)
          .length;
      _inProgressCount = records
          .where((r) => r.newVersesCompleted || r.reviewCount > 0)
          .length;
      _activeSessionSnapshot = activeSession;
      _hasActiveSession = activeSession != null;
      _loading = false;
    });
    _animController.forward();
  }

  Future<void> _openNewVerses({int? surahNum}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final targetSurah = surahNum ?? (prefs.getInt('hifz_nv_surah') ?? 67);
    final verseCount = qcf.getVerseCount(targetSurah);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HifzWizardSetupScreen(
          quranRepository: widget.quranRepository,
          foundationRepository: widget.foundationRepository,
          initialMode: HifzSessionType.newVerses,
          initialSurah: targetSurah,
          initialStartVerse: surahNum != null
              ? 1
              : (prefs.getInt('hifz_nv_start_verse') ?? 1),
          initialEndVerse: surahNum != null
              ? math.min(5, verseCount)
              : (prefs.getInt('hifz_nv_end_verse') ?? 5),
          initialRepeatStart: prefs.getInt('hifz_nv_repeat_start') ?? 1,
          initialStep: 1,
        ),
      ),
    );
    if (mounted) {
      _loadStats();
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
      _loadStats();
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SettingsScreen(
          initialCategory: SettingsCategoryTab.hifz,
        ),
      ),
    );
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
      _loadStats();
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
      _MasteryFilter.mastered => all.where((s) {
          final r = _completionMap[s];
          return r != null && r.newVersesCompleted && r.reviewCount >= 3;
        }).toList(),
      _MasteryFilter.inProgress => all.where((s) {
          final r = _completionMap[s];
          return r != null && (r.newVersesCompleted || r.reviewCount > 0);
        }).toList(),
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
                style: GoogleFonts.notoSansThai(fontWeight: FontWeight.w800),
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
        onRefresh: _loadStats,
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isThai
                                  ? 'ท่องจำอัลกุรอาน (Hifz)'
                                  : 'Hifz Memorization',
                              style: GoogleFonts.notoSansThai(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              isThai
                                  ? 'ระบบตัครอร 10x ดู + 5x ซ่อน • ทบทวน 2x/2x'
                                  : '10x Visible + 5x Hidden Takrar • 2x/2x Review',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
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

            // ── 3. Three Interactive Stat & Control Pills ──────────────────
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: _buildStatAndControlPills(
                  colorScheme,
                  textTheme,
                  settings,
                  isThai,
                ),
              ),
            ),

            // ── 4. 114-Surah Mastery Header + Filter Chips + Search ────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isThai
                              ? 'ความคืบหน้าทั้ง 114 ซูเราะฮฺ'
                              : 'Surah Mastery (114 Surahs)',
                          style: GoogleFonts.notoSansThai(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          isThai
                              ? 'แตะซูเราะฮฺเพื่อเริ่มท่อง/ทบทวน'
                              : 'Tap any surah to start',
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
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
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: colorScheme.outlineVariant
                                .withValues(alpha: 0.35),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
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
                              isThai ? 'ทั้งหมด (114)' : 'All (114)',
                            _MasteryFilter.inProgress => isThai
                                ? 'กำลังท่อง ($_inProgressCount)'
                                : 'In Progress ($_inProgressCount)',
                            _MasteryFilter.mastered => isThai
                                ? 'จำขึ้นใจแล้ว ($_masteredCount)'
                                : 'Mastered ($_masteredCount)',
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
                                borderRadius: BorderRadius.circular(20),
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
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final surahNum = filteredSurahs[index];
                    final record = _completionMap[surahNum];
                    final surahName = isThai
                        ? (offlineSurahNamesTh[surahNum.toString()] ??
                            widget.quranRepository
                                .getSurahName(surahNum.toString()))
                        : (offlineSurahNamesEn[surahNum.toString()] ??
                            widget.quranRepository
                                .getSurahName(surahNum.toString()));
                    final verseCount = qcf.getVerseCount(surahNum);
                    final juz = _juzOfSurah(surahNum);

                    return _EmbeddedSurahMasteryCard(
                      surahNumber: surahNum,
                      surahName: surahName,
                      verseCount: verseCount,
                      juz: juz,
                      record: record,
                      isThai: isThai,
                      colorScheme: colorScheme,
                      textTheme: textTheme,
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
        borderRadius: BorderRadius.circular(18),
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
              borderRadius: BorderRadius.circular(12),
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
                    fontWeight: FontWeight.w800,
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
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(isThai ? 'ท่องต่อ' : 'Resume'),
          ),
        ],
      ),
    );
  }

  String _getResumeSessionSubtitle(ActiveSessionSnapshot snap, bool isThai) {
    if (snap.sessionType == HifzSessionType.newVerses) {
      final surah = snap.nvSurahNumber ?? 1;
      final start = snap.nvStartVerse ?? 1;
      final end = snap.nvEndVerse ?? 1;
      final task = snap.currentStepIndex + 1;
      final surahName = isThai
          ? (offlineSurahNamesTh[surah.toString()] ?? 'ซูเราะฮฺ $surah')
          : (offlineSurahNamesEn[surah.toString()] ?? 'Surah $surah');
      return isThai
          ? '$surahName ($surah:$start-$end) • ขั้นที่ $task'
          : '$surahName ($surah:$start-$end) • Step $task';
    } else {
      final gran = snap.reviewGranularity ?? ReviewGranularity.bySurah;
      final step = snap.currentStepIndex + 1;
      if (gran == ReviewGranularity.bySurah) {
        final surah = snap.reviewTargetParams?.startSurah ?? 1;
        return isThai
            ? 'ทบทวนซูเราะฮฺ $surah • ขั้นที่ $step'
            : 'Review Surah $surah • Step $step';
      } else if (gran == ReviewGranularity.byVerses) {
        final surah = snap.reviewTargetParams?.surahNumber ?? 1;
        final start = snap.reviewTargetParams?.startVerse ?? 1;
        final end = snap.reviewTargetParams?.endVerse ?? 1;
        return isThai
            ? 'ทบทวน $surah:$start-$end • ขั้นที่ $step'
            : 'Review $surah:$start-$end • Step $step';
      } else {
        final page = snap.reviewTargetParams?.startPage ?? 1;
        return isThai
            ? 'ทบทวนหน้า $page • ขั้นที่ $step'
            : 'Review Page $page • Step $step';
      }
    }
  }

  // ── 2. Deep Emerald Takrar Hero Card ────────────────────────────────────────
  Widget _buildHeroCard(
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isThai,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF062C2B), Color(0xFF0E5A4A)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF062C2B).withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4A853).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
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
              const Spacer(),
              InkWell(
                onTap: _openGuide,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.school_outlined,
                        size: 14,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isThai ? 'วิธีท่องจำ' : 'How it works',
                        style: GoogleFonts.notoSansThai(
                          fontSize: 11,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isThai
                ? 'ท่องจำอายะฮฺใหม่ & ทบทวนความจำ'
                : 'Memorize New Verses & Protect Retention',
            style: GoogleFonts.notoSansThai(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isThai
                ? 'อ่านเปิดหน้า 10 รอบ + ทดสอบซ่อนอายะฮฺ 5 รอบ พร้อมเชื่อมโยงลำดับอายะฮฺอัตโนมัติ'
                : '10x visible reading + 5x hidden active recall with cumulative verse linking.',
            style: GoogleFonts.notoSansThai(
              fontSize: 12.5,
              color: Colors.white.withValues(alpha: 0.8),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openNewVerses(),
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: Text(
                    isThai ? 'เริ่มท่องอายะฮฺใหม่' : 'New Verses',
                    style: GoogleFonts.notoSansThai(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD4A853),
                    foregroundColor: const Color(0xFF1E1608),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openReview(),
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: Text(
                    isThai ? 'ทบทวนความจำ' : 'Review Mode',
                    style: GoogleFonts.notoSansThai(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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

  // ── 3. Three Interactive Stat & Control Pills ───────────────────────────────
  Widget _buildStatAndControlPills(
    ColorScheme colorScheme,
    TextTheme textTheme,
    SettingsProvider settings,
    bool isThai,
  ) {
    final inputModeLabel = switch (settings.hifzInputMode) {
      HifzInputMode.inAppTally => isThai ? 'ปุ่มบนจอ' : 'On-Screen',
      HifzInputMode.bluetoothShutter => isThai ? 'รีโมทบลูทูธ' : 'BT Shutter',
      HifzInputMode.bleSmartRing => isThai ? 'แหวน Smart Ring' : 'Smart Ring',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _CompactInfoCard(
              icon: Icons.verified_rounded,
              iconColor: const Color(0xFF15803D),
              title: '$_masteredCount / 114',
              subtitle: isThai ? 'จำขึ้นใจแล้ว' : 'Mastered',
              onTap: () =>
                  setState(() => _filterMode = _MasteryFilter.mastered),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _CompactInfoCard(
              icon: Icons.trending_up_rounded,
              iconColor: const Color(0xFFB45309),
              title: '$_inProgressCount / 114',
              subtitle: isThai ? 'กำลังท่องจำ' : 'In Progress',
              onTap: () =>
                  setState(() => _filterMode = _MasteryFilter.inProgress),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _CompactInfoCard(
              icon: settings.hifzInputMode == HifzInputMode.bleSmartRing
                  ? Icons.watch_rounded
                  : (settings.hifzInputMode == HifzInputMode.bluetoothShutter
                      ? Icons.bluetooth_searching_rounded
                      : Icons.touch_app_rounded),
              iconColor: colorScheme.primary,
              title: inputModeLabel,
              subtitle: isThai ? 'วิธีเลื่อนอายะฮฺ ⚙' : 'Input Mode ⚙',
              onTap: _openHifzSettings,
            ),
          ),
        ],
      ),
    );
  }

  void _showSurahActionSheet(BuildContext context, int surahNum) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isThai =
        Provider.of<SettingsProvider>(context, listen: false).languageCode ==
            'th';
    final record = _completionMap[surahNum];
    final isCompleted = record?.newVersesCompleted == true;
    final reviewCount = record?.reviewCount ?? 0;
    final surahTh = offlineSurahNamesTh[surahNum.toString()] ??
        widget.quranRepository.getSurahName(surahNum.toString());
    final surahEn = offlineSurahNamesEn[surahNum.toString()] ??
        widget.quranRepository.getSurahName(surahNum.toString());
    final verseCount = qcf.getVerseCount(surahNum);
    final juz = _juzOfSurah(surahNum);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$surahNum',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
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
                            isThai ? surahTh : surahEn,
                            style: GoogleFonts.notoSansThai(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '$verseCount ${isThai ? 'อายะฮฺ' : 'verses'} • Juz $juz${reviewCount > 0 ? ' • ${isThai ? 'ทบทวนแล้ว $reviewCount ครั้ง' : 'Reviewed ×$reviewCount'}' : ''}',
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
                          color: const Color(0xFF15803D).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isThai ? 'สำเร็จแล้ว' : 'Completed',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
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
                        ? 'ท่องจำอายะฮฺใหม่ (Takrar)'
                        : 'Memorize New Verses (Takrar)',
                    style: GoogleFonts.notoSansThai(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    isThai
                        ? 'เริ่มที่อายะฮฺ 1–${math.min(5, verseCount)} (ปรับช่วงได้)'
                        : 'Starts at verses 1–${math.min(5, verseCount)} (customizable)',
                    style: textTheme.bodySmall,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _openNewVerses(surahNum: surahNum);
                  },
                ),
                const SizedBox(height: 10),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
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

class _CompactInfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CompactInfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.notoSansThai(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.notoSansThai(
                  fontSize: 10.5,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmbeddedSurahMasteryCard extends StatelessWidget {
  final int surahNumber;
  final String surahName;
  final int verseCount;
  final int juz;
  final SurahCompletionRecord? record;
  final bool isThai;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback onTap;

  const _EmbeddedSurahMasteryCard({
    required this.surahNumber,
    required this.surahName,
    required this.verseCount,
    required this.juz,
    required this.record,
    required this.isThai,
    required this.colorScheme,
    required this.textTheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isMastered =
        record?.newVersesCompleted == true && (record?.reviewCount ?? 0) >= 3;
    final isInProgress = !isMastered &&
        (record?.newVersesCompleted == true || (record?.reviewCount ?? 0) > 0);
    final reviewCount = record?.reviewCount ?? 0;

    final Color statusColor = isMastered
        ? const Color(0xFF15803D)
        : (isInProgress ? const Color(0xFFB45309) : colorScheme.onSurfaceVariant);

    final String statusLabel = isMastered
        ? (isThai ? 'จำขึ้นใจแล้ว' : 'Mastered')
        : (isInProgress
            ? (isThai ? 'กำลังท่อง' : 'In Progress')
            : (isThai ? 'เริ่มท่อง' : 'Start'));

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isMastered
                  ? const Color(0xFF15803D).withValues(alpha: 0.4)
                  : (isInProgress
                      ? const Color(0xFFD97706).withValues(alpha: 0.4)
                      : colorScheme.outlineVariant.withValues(alpha: 0.3)),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$surahNumber',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      surahName,
                      style: GoogleFonts.notoSansThai(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '$verseCount ${isThai ? 'อายะฮฺ' : 'verses'} • ${isThai ? 'ญุซอ์' : 'Juz'} $juz${reviewCount > 0 ? ' • ${isThai ? 'ทบทวน $reviewCount รอบ' : 'Reviewed ×$reviewCount'}' : ''}',
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 11.5,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.notoSansThai(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
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
    );
  }
}
