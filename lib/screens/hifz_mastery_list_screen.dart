// lib/screens/hifz_mastery_list_screen.dart
//
// Surah Completion & Mastery overview screen.
// Reads from HifzRepository to display all 114 Surahs with status badges.
// Zero business logic — all reads go through HifzRepository.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qcf_quran/qcf_quran.dart' as qcf;
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
import 'hifz_memorize_screen.dart';
import 'hifz_wizard_setup_screen.dart';

// Juz-to-Surah ranges (standard 30 Juz divisions)
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

enum _FilterMode { all, mastered, inProgress, notStarted, juz29And30 }

class HifzMasteryListScreen extends StatefulWidget {
  final QuranRepository quranRepository;
  final QuranFoundationRepository? foundationRepository;

  const HifzMasteryListScreen({
    super.key,
    required this.quranRepository,
    this.foundationRepository,
  });

  @override
  State<HifzMasteryListScreen> createState() => _HifzMasteryListScreenState();
}

class _HifzMasteryListScreenState extends State<HifzMasteryListScreen> {
  final HifzRepository _repo = HifzRepository();
  Map<int, SurahCompletionRecord> _completionMap = {};
  Map<int, SurahMasterySummary> _summaries = {};
  ActiveSessionSnapshot? _activeSession;
  bool _loading = true;
  _FilterMode _filterMode = _FilterMode.all;

  QuranFoundationRepository get _foundationRepository =>
      widget.foundationRepository ?? QuranFoundationRepository();

  @override
  void initState() {
    super.initState();
    _load(syncCloud: true);
  }

  String? _safeCurrentUserId() {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  Future<void> _load({bool syncCloud = false}) async {
    Future<void> applyLocal() async {
      final records = await _repo.getAllCompletionRecords();
      final history = await _repo.getHistory(limit: 500);
      final activeSession = await _repo.loadActiveSession();
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
      if (mounted) {
        setState(() {
          _completionMap = map;
          _summaries = summaries;
          _activeSession = activeSession;
          _loading = false;
        });
      }
    }

    await applyLocal();

    if (syncCloud) {
      final userId = _safeCurrentUserId();
      if (userId != null) {
        await Future.wait([
          _repo.syncWithSupabase(userId),
          _repo.syncHistoryWithSupabase(),
        ]);
        await applyLocal();
      }
    }
  }

  List<int> get _filteredSurahs {
    final all = List.generate(114, (i) => i + 1);
    switch (_filterMode) {
      case _FilterMode.mastered:
        return all
            .where((s) => _summaries[s]?.status == HifzMasteryStatus.mastered)
            .toList();
      case _FilterMode.inProgress:
        return all
            .where((s) => _summaries[s]?.status == HifzMasteryStatus.inProgress)
            .toList();
      case _FilterMode.notStarted:
        return all
            .where(
              (s) =>
                  (_summaries[s]?.status ?? HifzMasteryStatus.notStarted) ==
                  HifzMasteryStatus.notStarted,
            )
            .toList();
      case _FilterMode.juz29And30:
        return all.where((s) => _juzOfSurah(s) >= 29).toList();
      case _FilterMode.all:
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isThai = context.watch<SettingsProvider>().languageCode == 'th';

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Hifz Mastery',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => _load(syncCloud: true),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- Filter chips ---
          _buildFilterBar(colorScheme, textTheme),
          // --- Stats summary ---
          _buildStatsSummary(colorScheme, textTheme),
          // --- Surah list ---
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(
                      color: colorScheme.primary,
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => _load(syncCloud: true),
                    child: _buildSurahList(colorScheme, textTheme, isThai),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      color: colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          spacing: 8,
          children: _FilterMode.values.map((mode) {
            final label = switch (mode) {
              _FilterMode.all => 'All (114)',
              _FilterMode.mastered => 'Mastered',
              _FilterMode.inProgress => 'In Progress',
              _FilterMode.notStarted => 'Not Started',
              _FilterMode.juz29And30 => "Juz' 29 & 30",
            };
            final selected = _filterMode == mode;
            return FilterChip(
              label: Text(label),
              selected: selected,
              onSelected: (_) => setState(() => _filterMode = mode),
              selectedColor: colorScheme.primaryContainer,
              labelStyle: textTheme.bodyMedium?.copyWith(
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              side: BorderSide(
                color: selected
                    ? colorScheme.primary
                    : colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatsSummary(ColorScheme colorScheme, TextTheme textTheme) {
    final total = 114;
    final mastered = _summaries.values
        .where((s) => s.status == HifzMasteryStatus.mastered)
        .length;
    final reviewed = _completionMap.values.where((r) => r.reviewCount > 0).length;
    final totalReviews = _completionMap.values.fold(0, (sum, r) => sum + r.reviewCount);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatPill(
            label: 'Mastered',
            value: '$mastered / $total',
            icon: Icons.verified_rounded,
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
          _StatPill(
            label: 'Reviewed',
            value: '$reviewed',
            icon: Icons.replay_rounded,
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
          _StatPill(
            label: 'Total Reviews',
            value: '$totalReviews',
            icon: Icons.bar_chart_rounded,
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
        ],
      ),
    );
  }

  Widget _buildSurahList(
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isThai,
  ) {
    final surahs = _filteredSurahs;
    if (surahs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded,
                  size: 56, color: colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                'No surahs found for this filter.',
                style: textTheme.bodyLarge
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: surahs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final surahNum = surahs[index];
        final record = _completionMap[surahNum];
        final surahName = surahDisplayName(
          surahNum.toString(),
          isThai: isThai,
        );
        final verseCount = qcf.getVerseCount(surahNum);
        final juz = _juzOfSurah(surahNum);

        return SurahMasteryCard(
          surahNumber: surahNum,
          surahName: surahName,
          verseCount: verseCount,
          juz: juz,
          record: record,
          summary: _summaries[surahNum],
          isThai: isThai,
          onTap: () => _showSurahActionSheet(context, surahNum),
        );
      },
    );
  }

  void _showSurahActionSheet(BuildContext context, int surahNum) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final colors = context.appColors;
    final isThai = Provider.of<SettingsProvider>(context, listen: false).languageCode == 'th';
    final record = _completionMap[surahNum];
    final summary = _summaries[surahNum];
    final isMastered = summary != null
        ? summary.status == HifzMasteryStatus.mastered
        : SurahMasteryCard.isMasteredRecord(record);
    final isInProgress = summary != null
        ? summary.status == HifzMasteryStatus.inProgress
        : SurahMasteryCard.isInProgressRecord(record);
    final hasActiveHere = summary?.hasActiveSession == true;
    final furthest = summary?.furthestCompletedVerse ?? 0;
    final isNewCompleted = summary?.newVersesCompleted ?? (record?.newVersesCompleted == true);
    final reviewCount = summary?.reviewCount ?? (record?.reviewCount ?? 0);
    final names = surahNamePair(surahNum.toString());
    final primaryName = isThai ? names.th : names.en;
    final otherName = isThai ? names.en : names.th;
    final secondaryName = otherName == primaryName ? '' : otherName;
    final verseCount = qcf.getVerseCount(surahNum);
    final juz = _juzOfSurah(surahNum);
    final hasPartialContinue =
        !isNewCompleted && furthest > 0 && furthest < verseCount;
    final nextStartVerse = hasPartialContinue ? furthest + 1 : 1;
    final nextEndVerse = math.min(nextStartVerse + 4, verseCount);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radius),
        ),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$surahNum',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
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
                              primaryName,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${secondaryName.isEmpty ? '' : '$secondaryName · '}$verseCount ${isThai ? 'อายะฮฺ' : 'verses'} · Juz $juz',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        String.fromCharCode(0xe000 + surahNum),
                        style: TextStyle(
                          fontFamily: 'QcfSurahName',
                          fontSize: 36,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Status Badge Row
                Row(
                  children: [
                    if (isMastered)
                      _Badge(isThai ? 'จำขึ้นใจแล้ว' : 'MASTERED', colors.success)
                    else if (isInProgress)
                      _Badge(isThai ? 'กำลังท่อง' : 'IN PROGRESS', colors.mushafGold)
                    else
                      _Badge(isThai ? 'ยังไม่ได้เริ่ม' : 'NOT STARTED', colorScheme.onSurfaceVariant),
                    if (reviewCount > 0) ...[
                      const SizedBox(width: 8),
                      _Badge(
                        isThai ? 'ทบทวนแล้ว $reviewCount ครั้ง' : 'REVIEWED ×$reviewCount',
                        colors.primary,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),

                // Option 0: Resume active paused session on this Surah
                if (hasActiveHere && _activeSession != null) ...[
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                    ),
                    tileColor: const Color(0xFFFFF8EB),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4A853).withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: const Icon(Icons.play_circle_fill_rounded, color: Color(0xFF9A6B16), size: 22),
                    ),
                    title: Text(
                      isThai ? 'ท่องต่อจากที่ค้างไว้' : 'Resume Paused Session',
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2B2110),
                      ),
                    ),
                    subtitle: Text(
                      formatActiveSessionSubtitle(_activeSession!, isThai: isThai),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(color: const Color(0xFF7C5E24)),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HifzMemorizeScreen(
                            quranRepository: widget.quranRepository,
                            foundationRepository: _foundationRepository,
                            resumeSessionSnapshot: _activeSession!,
                          ),
                        ),
                      ).then((_) {
                        if (mounted) _load();
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                ],

                // Option 1: Memorize New Verses
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                  tileColor: colorScheme.surfaceContainerLow,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Icon(Icons.menu_book_rounded, color: colorScheme.primary, size: 22),
                  ),
                  title: Text(
                    isThai
                        ? (hasPartialContinue ? 'ท่องต่ออายะฮฺใหม่ (Takrar)' : 'ท่องจำอายะฮฺใหม่ (Takrar)')
                        : (hasPartialContinue ? 'Continue New Verses' : 'Memorize New Verses'),
                    style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    isThai
                        ? 'อายะฮฺ $nextStartVerse–$nextEndVerse · เจาะลึก 15 รอบ'
                        : 'Verses $nextStartVerse–$nextEndVerse · 15 Repetitions',
                    style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HifzWizardSetupScreen(
                          quranRepository: widget.quranRepository,
                          foundationRepository: _foundationRepository,
                          initialMode: HifzSessionType.newVerses,
                          initialSurah: surahNum,
                          initialStartVerse: nextStartVerse,
                          initialEndVerse: nextEndVerse,
                          initialRepeatStart: nextStartVerse,
                          initialStep: 1,
                        ),
                      ),
                    ).then((_) {
                      if (mounted) _load();
                    });
                  },
                ),
                const SizedBox(height: 10),

                // Option 2: Review this Surah
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                  tileColor: colorScheme.surfaceContainerLow,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Icon(Icons.replay_circle_filled_rounded, color: colorScheme.tertiary, size: 22),
                  ),
                  title: Text(
                    isThai ? 'ทบทวนซูเราะฮฺนี้ (Review)' : 'Review This Surah',
                    style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    isThai
                        ? 'อายะฮฺ 1–$verseCount (ทั้งซูเราะฮฺ) · ตรวจจับด้วยเสียง'
                        : 'Verses 1–$verseCount (Full Surah) · Voice verified',
                    style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HifzWizardSetupScreen(
                          quranRepository: widget.quranRepository,
                          foundationRepository: _foundationRepository,
                          initialMode: HifzSessionType.review,
                          initialSurah: surahNum,
                          initialStartSurah: surahNum,
                          initialEndSurah: surahNum,
                          initialStartVerse: 1,
                          initialEndVerse: verseCount,
                          initialStep: 1,
                        ),
                      ),
                    ).then((_) {
                      if (mounted) _load();
                    });
                  },
                ),
                const SizedBox(height: 10),

                // Option 3: Custom Wizard Setup
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                  tileColor: colorScheme.surfaceContainerLow,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Icon(Icons.tune_rounded, color: colorScheme.onSurfaceVariant, size: 22),
                  ),
                  title: Text(
                    isThai ? 'เปิดวิซาร์ดตั้งค่าแบบกำหนดเอง' : 'Custom Wizard Setup',
                    style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    isThai
                        ? 'เลือกช่วงอายะฮฺ หรือหน้ามุศหัฟตามต้องการ'
                        : 'Customize verse range, chunking, and goals',
                    style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HifzWizardSetupScreen(
                          quranRepository: widget.quranRepository,
                          foundationRepository: _foundationRepository,
                          initialSurah: surahNum,
                          initialStep: 0,
                        ),
                      ),
                    ).then((_) {
                      if (mounted) _load();
                    });
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

// =============================================================================
// Sub-widgets
// =============================================================================

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _StatPill({
    required this.label,
    required this.value,
    required this.icon,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: colorScheme.primary, size: 22),
        const SizedBox(height: 4),
        Text(value,
            style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
        Text(label,
            style:
                textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
