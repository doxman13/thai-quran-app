import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../data/medina_mushaf_pages.dart';
import '../data/quran_foundation_repository.dart';
import '../data/quran_repository.dart';
import '../models/mushaf_models.dart';
import '../providers/local_reading_provider.dart';
import '../providers/mushaf_reading_provider.dart';
import '../providers/settings_provider.dart';
import '../shared/shared.dart';
import '../theme/app_theme.dart';
import 'mushaf_reader_screen.dart';
import 'reading_screen.dart';

enum GoalFilterTab { all, meaning, mushaf }

class _GoalPreset {
  final String id;
  final String kind; // 'meaning' | 'mushaf'
  final String titleTh;
  final String titleEn;
  final String descTh;
  final String descEn;
  final String badgeTh;
  final String badgeEn;
  final IconData icon;

  // Meaning config
  final String? meaningPlanMode;
  final int? startJuz;
  final int? targetJuz;
  final String? startSurah;
  final String? targetSurah;

  // Mushaf config
  final String? mushafPlanMode; // 'page_range' | 'juz_range' | 'surah_range'
  final int? startPage;
  final int? targetPage;

  const _GoalPreset({
    required this.id,
    required this.kind,
    required this.titleTh,
    required this.titleEn,
    required this.descTh,
    required this.descEn,
    required this.badgeTh,
    required this.badgeEn,
    required this.icon,
    this.meaningPlanMode,
    this.startJuz,
    this.targetJuz,
    this.startSurah,
    this.targetSurah,
    this.mushafPlanMode,
    this.startPage,
    this.targetPage,
  });
}

const List<_GoalPreset> _goalPresets = [
  _GoalPreset(
    id: 'ramadan_khatam_meaning',
    kind: 'meaning',
    titleTh: 'ค็อตม์เดือนรอมฎอน (30 ญุซอ์)',
    titleEn: 'Ramadan Khatam (30 Juz)',
    descTh: 'อ่านคำแปลไทยจบทั้งเล่ม 30 ญุซอ์ (วันละ 1 ญุซอ์)',
    descEn: 'Complete the entire Quran meaning across 30 Juz.',
    badgeTh: '30 วัน • 1 ญุซอ์/วัน',
    badgeEn: '30 Days • 1 Juz/day',
    icon: Icons.nightlight_round,
    meaningPlanMode: 'by_juz',
    startJuz: 1,
    targetJuz: 30,
  ),
  _GoalPreset(
    id: 'ramadan_khatam_mushaf',
    kind: 'mushaf',
    titleTh: 'ค็อตม์มุศหัฟ 604 หน้า',
    titleEn: '604-Page Mushaf Khatam',
    descTh: 'อ่านหน้ามุศหัฟจริงตั้งแต่หน้า 1 ถึง 604 (วันละ 20 หน้า)',
    descEn: 'Read authentic Madinah Mushaf from page 1 to 604.',
    badgeTh: '604 หน้า • 20 หน้า/วัน',
    badgeEn: '604 Pages • 20p/day',
    icon: Icons.import_contacts_rounded,
    mushafPlanMode: 'page_range',
    startPage: 1,
    targetPage: 604,
  ),
  _GoalPreset(
    id: 'full_khatam_meaning',
    kind: 'meaning',
    titleTh: 'อ่านเข้าใจความหมายทั้งเล่ม (114 ซูเราะฮฺ)',
    titleEn: 'Full Quran Meaning (114 Surahs)',
    descTh: 'เริ่มจากอัลฟาติหะฮฺ ถึง อันนาส อย่างต่อเนื่อง',
    descEn: 'Read from Al-Fatihah to An-Nas at your own pace.',
    badgeTh: '6,236 อายะฮฺ',
    badgeEn: '6,236 Ayahs',
    icon: Icons.menu_book_rounded,
    meaningPlanMode: 'by_surah',
    startSurah: '1',
    targetSurah: '114',
  ),
  _GoalPreset(
    id: 'deep_study_baqarah',
    kind: 'meaning',
    titleTh: 'ศึกษาเจาะลึกอัลบะเกาะเราะฮฺ',
    titleEn: 'Study Surah Al-Baqarah',
    descTh: 'อ่านและใคร่ครวญซูเราะฮฺที่ยาวที่สุด (286 อายะฮฺ)',
    descEn: 'Reflect deeply on the longest Surah (286 Ayahs).',
    badgeTh: '286 อายะฮฺ',
    badgeEn: '286 Ayahs',
    icon: Icons.auto_stories_rounded,
    meaningPlanMode: 'by_surah',
    startSurah: '2',
    targetSurah: '2',
  ),
  _GoalPreset(
    id: 'juz_amma_meaning',
    kind: 'meaning',
    titleTh: 'ศึกษาญุซอ์อัมมะฮฺ (ญุซอ์ที่ 30)',
    titleEn: 'Juz Amma Meaning (Juz 30)',
    descTh: 'เข้าใจความหมายของซูเราะฮฺสั้นที่ใช้ในละหมาด',
    descEn: 'Understand the short Surahs recited in daily prayers.',
    badgeTh: 'ญุซอ์ 30',
    badgeEn: 'Juz 30',
    icon: Icons.wb_sunny_outlined,
    meaningPlanMode: 'by_juz',
    startJuz: 30,
    targetJuz: 30,
  ),
  _GoalPreset(
    id: 'daily_habit_mulk',
    kind: 'meaning',
    titleTh: 'อ่านซูเราะฮฺอัลมุลก์ทุกคืน',
    titleEn: 'Surah Al-Mulk Nightly Habit',
    descTh: 'สร้างวินัยการอ่านอัลมุลก์ 30 อายะฮฺก่อนนอน',
    descEn: 'Build a nightly habit of reading 30 Ayahs of Al-Mulk.',
    badgeTh: '30 อายะฮฺ',
    badgeEn: '30 Ayahs',
    icon: Icons.shield_outlined,
    meaningPlanMode: 'by_surah',
    startSurah: '67',
    targetSurah: '67',
  ),
  _GoalPreset(
    id: 'mushaf_habit_2pages',
    kind: 'mushaf',
    titleTh: 'ฝึกอ่านมุศหัฟ 60 หน้าแรก',
    titleEn: 'First 60 Pages Mushaf Habit',
    descTh: 'อ่านมุศหัฟวันละ 2 หน้า ต่อเนื่อง 30 วัน (หน้า 1–60)',
    descEn: 'Read 2 Mushaf pages daily for 30 days (Pages 1–60).',
    badgeTh: '60 หน้า • 2 หน้า/วัน',
    badgeEn: '60 Pages • 2p/day',
    icon: Icons.bookmark_added_outlined,
    mushafPlanMode: 'page_range',
    startPage: 1,
    targetPage: 60,
  ),
  _GoalPreset(
    id: 'mushaf_juz_amma',
    kind: 'mushaf',
    titleTh: 'มุศหัฟญุซอ์ 30 (หน้า 582–604)',
    titleEn: 'Mushaf Juz 30 (Pages 582–604)',
    descTh: 'อ่านและทบทวนหน้ามุศหัฟเฉพาะญุซอ์อัมมา 23 หน้า',
    descEn: 'Read and review the 23 pages of Juz Amma in Mushaf.',
    badgeTh: '23 หน้า',
    badgeEn: '23 Pages',
    icon: Icons.stars_rounded,
    mushafPlanMode: 'juz_range',
    startJuz: 30,
    targetJuz: 30,
    startPage: 582,
    targetPage: 604,
  ),
];

class GoalsScreen extends StatefulWidget {
  final QuranRepository repository;
  final QuranFoundationRepository foundationRepository;
  final bool isEmbedded;

  const GoalsScreen({
    super.key,
    required this.repository,
    required this.foundationRepository,
    this.isEmbedded = false,
  });

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  GoalFilterTab _filterTab = GoalFilterTab.all;
  bool _showPresets = true;

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

  static const List<int> _mushafJuzStarts = [
    1, 22, 42, 62, 82, 102, 121, 142, 162, 182,
    201, 222, 242, 262, 282, 302, 322, 342, 362, 382,
    402, 422, 442, 462, 482, 502, 522, 542, 562, 582,
  ];

  VerseRef _juzStartRef(int juz) {
    final s = _juzStarts[(juz - 1).clamp(0, _juzStarts.length - 1)];
    return toVerseRef(s[0], s[1]);
  }

  VerseRef _juzEndRef(int juz) {
    if (juz >= _juzStarts.length) {
      final lastCount = widget.repository.getSurahVerses('114').length;
      return toVerseRef(114, lastCount > 0 ? lastCount : 6);
    }
    final nextStart = _juzStarts[juz];
    var surah = nextStart[0];
    var ayah = nextStart[1] - 1;
    if (ayah < 1) {
      surah -= 1;
      final c = widget.repository.getSurahVerses(surah.toString()).length;
      ayah = c > 0 ? c : 1;
    }
    return toVerseRef(surah, ayah);
  }

  int _mushafJuzStartPage(int juz) {
    return _mushafJuzStarts[(juz - 1).clamp(0, _mushafJuzStarts.length - 1)];
  }

  int _mushafJuzEndPage(int juz, int maxPages) {
    if (juz >= 30) return maxPages;
    return (_mushafJuzStartPage(juz + 1) - 1).clamp(1, maxPages);
  }

  int _surahStartPage(int surah) {
    return getMedinaMushafPageNumber(surah.clamp(1, 114), 1);
  }

  int _surahEndPage(int surah, int maxPages) {
    if (surah >= 114) return maxPages;
    return (_surahStartPage(surah + 1) - 1).clamp(1, maxPages);
  }

  int _inferMushafJuzForPage(int pageNumber) {
    for (int i = _mushafJuzStarts.length - 1; i >= 0; i--) {
      if (pageNumber >= _mushafJuzStarts[i]) {
        return i + 1;
      }
    }
    return 1;
  }

  int _inferMushafSurahForPage(int pageNumber) {
    for (int s = 114; s >= 1; s--) {
      if (pageNumber >= _surahStartPage(s)) {
        return s;
      }
    }
    return 1;
  }

  ({int done, int total, int percent}) _calculateMeaningProgress(
    LocalReadingProfile profile,
  ) {
    final startIdx = absoluteVerseIndex(profile.start);
    final endIdx = profile.target != null
        ? absoluteVerseIndex(profile.target!)
        : 6236;
    final currIdx = profile.furthestUnreadIndex;
    final total = (endIdx - startIdx + 1).clamp(1, 6236);
    final done = (currIdx - startIdx + 1).clamp(0, total);
    final percent = ((done / total) * 100).round().clamp(0, 100);
    return (done: done, total: total, percent: percent);
  }

  ({int done, int total, int percent}) _calculateMushafProgress(
    MushafProfile profile,
  ) {
    final total = (profile.targetPage - profile.startPage + 1).clamp(1, 604);
    final done = (profile.furthestUnreadPage - profile.startPage + 1).clamp(
      0,
      total,
    );
    final percent = ((done / total) * 100).round().clamp(0, 100);
    return (done: done, total: total, percent: percent);
  }

  Future<void> _openMeaningGoal(LocalReadingProfile profile) async {
    final readingProv = context.read<LocalReadingProvider>();
    await readingProv.setActiveProfile(profile.id);
    if (!mounted) return;
    final resume = profile.furthestUnread;
    final verses = widget.repository.getSurahVerses(resume.surahId);
    int vIdx = verses.indexWhere((v) => v.id == resume.verseId);
    if (vIdx == -1) vIdx = 0;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReadingScreen(
          repository: widget.repository,
          initialSurah: resume.surahId,
          initialVerseIndex: vIdx,
          initialVerseId: resume.verseId,
        ),
      ),
    );
    if (!mounted || result is! Map) return;
    final resultSurahId = result['surahId']?.toString();
    final resultVerseId = result['verseId']?.toString();
    if (resultSurahId != null && resultVerseId != null) {
      final resultProfileId = result['profileId']?.toString();
      var resolvedProfile = resultProfileId != null
          ? readingProv.profileById(resultProfileId)
          : null;
      if (resolvedProfile == null || isFreeReadProfile(resolvedProfile)) {
        resolvedProfile = readingProv.profileById(profile.id);
      }
      await readingProv.addRecentReading(
        verse: toVerseRef(resultSurahId, resultVerseId),
        profileId: resolvedProfile?.id,
      );
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _openMushafGoal(MushafProfile profile, {int? page}) async {
    final mushafProv = context.read<MushafReadingProvider>();
    await mushafProv.setActiveProfile(profile.id);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MushafReaderScreen(
          quranRepository: widget.repository,
          foundationRepository: widget.foundationRepository,
          profileId: profile.id,
          initialPage: page ?? profile.lastViewedPage,
        ),
      ),
    );
  }

  Future<void> _showUnifiedGoalModal({
    String initialKind = 'meaning',
    _GoalPreset? initialPreset,
    LocalReadingProfile? editingMeaningProfile,
    MushafProfile? editingMushafProfile,
  }) async {
    final isThai = context.read<SettingsProvider>().languageCode == 'th';
    final readingProv = context.read<LocalReadingProvider>();
    final mushafProv = context.read<MushafReadingProvider>();

    String selectedKind = editingMushafProfile != null
        ? 'mushaf'
        : editingMeaningProfile != null
            ? 'meaning'
            : (initialPreset?.kind ?? initialKind);

    String? selectedPresetId = initialPreset?.id;

    final nameController = TextEditingController(
      text: editingMeaningProfile?.name ??
          editingMushafProfile?.name ??
          (initialPreset != null
              ? (isThai ? initialPreset.titleTh : initialPreset.titleEn)
              : ''),
    );

    // Meaning fields
    String meaningPlanMode = editingMeaningProfile?.planMode ??
        initialPreset?.meaningPlanMode ??
        'by_juz';
    if (!['by_juz', 'by_surah', 'by_ayat', 'custom'].contains(meaningPlanMode)) {
      meaningPlanMode = 'by_juz';
    }
    int meaningStartJuz =
        editingMeaningProfile?.startJuz ?? initialPreset?.startJuz ?? 1;
    int meaningTargetJuz =
        editingMeaningProfile?.targetJuz ?? initialPreset?.targetJuz ?? 30;
    String meaningStartSurah = editingMeaningProfile?.start.surahId ??
        initialPreset?.startSurah ??
        '1';
    String meaningStartVerse = editingMeaningProfile?.start.verseId ?? '1';
    String meaningTargetSurah = editingMeaningProfile?.target?.surahId ??
        initialPreset?.targetSurah ??
        '114';
    String meaningTargetVerse = editingMeaningProfile?.target?.verseId ?? '6';
    int meaningAyatCount = 50;

    // Mushaf fields
    final int mushafId =
        editingMushafProfile?.mushafId ?? mushafProv.displayMushafId;
    final int maxPages = mushafTypeById(mushafId).pageCount;
    String mushafPlanMode = switch (editingMushafProfile?.planMode ??
        initialPreset?.mushafPlanMode) {
      'by_juz' || 'juz_range' => 'juz_range',
      'by_surah' || 'surah_range' => 'surah_range',
      _ => 'page_range',
    };
    int mushafStartPage =
        editingMushafProfile?.startPage ?? initialPreset?.startPage ?? 1;
    int mushafTargetPage = editingMushafProfile?.targetPage ??
        initialPreset?.targetPage ??
        maxPages;
    int mushafStartJuz = editingMushafProfile != null
        ? _inferMushafJuzForPage(editingMushafProfile.startPage)
        : (initialPreset?.startJuz ?? 1);
    int mushafTargetJuz = editingMushafProfile != null
        ? _inferMushafJuzForPage(editingMushafProfile.targetPage)
        : (initialPreset?.targetJuz ?? 30);
    String mushafStartSurah = editingMushafProfile != null
        ? _inferMushafSurahForPage(editingMushafProfile.startPage).toString()
        : (initialPreset?.startSurah ?? '1');
    String mushafTargetSurah = editingMushafProfile != null
        ? _inferMushafSurahForPage(editingMushafProfile.targetPage).toString()
        : (initialPreset?.targetSurah ?? '114');

    String? formError;
    bool isSaving = false;

    void applyPreset(_GoalPreset preset, StateSetter setModalState) {
      setModalState(() {
        selectedPresetId = preset.id;
        selectedKind = preset.kind;
        nameController.text = isThai ? preset.titleTh : preset.titleEn;
        formError = null;
        if (preset.kind == 'meaning') {
          meaningPlanMode = preset.meaningPlanMode ?? 'by_juz';
          if (preset.startJuz != null) meaningStartJuz = preset.startJuz!;
          if (preset.targetJuz != null) meaningTargetJuz = preset.targetJuz!;
          if (preset.startSurah != null) meaningStartSurah = preset.startSurah!;
          if (preset.targetSurah != null) {
            meaningTargetSurah = preset.targetSurah!;
          }
        } else {
          mushafPlanMode = preset.mushafPlanMode ?? 'page_range';
          if (preset.startPage != null) mushafStartPage = preset.startPage!;
          if (preset.targetPage != null) mushafTargetPage = preset.targetPage!;
          if (preset.startJuz != null) mushafStartJuz = preset.startJuz!;
          if (preset.targetJuz != null) mushafTargetJuz = preset.targetJuz!;
          if (preset.startSurah != null) mushafStartSurah = preset.startSurah!;
          if (preset.targetSurah != null) {
            mushafTargetSurah = preset.targetSurah!;
          }
        }
      });
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final colorScheme = Theme.of(context).colorScheme;
            final colors = context.read<SettingsProvider>().getAppColors();
            final isEditing =
                editingMeaningProfile != null || editingMushafProfile != null;
            final activeAccent = selectedKind == 'meaning'
                ? colorScheme.primary
                : const Color(0xFF8A6530);

            final currentKindPresets = _goalPresets
                .where((p) => p.kind == selectedKind)
                .toList();

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEditing
                                    ? (isThai
                                          ? 'แก้ไขเป้าหมายการอ่าน'
                                          : 'Edit Reading Goal')
                                    : (isThai
                                          ? 'ตั้งเป้าหมายการอ่านใหม่'
                                          : 'Set New Reading Goal'),
                                style: GoogleFonts.notoSansThai(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isThai
                                    ? 'เลือกโหมดที่ต้องการ แล้วเลือกแผนแนะนำหรือปรับแต่งขอบเขตตามใจคุณ'
                                    : 'Choose your reading mode, select a preset, or customize your range.',
                                style: GoogleFonts.notoSansThai(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(modalContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // STEP 1: Mode Selector (Meaning vs Mushaf)
                    if (!isEditing) ...[
                      Text(
                        isThai
                            ? '1. เลือกรูปแบบการอ่าน'
                            : '1. Select Reading Mode',
                        style: GoogleFonts.notoSansThai(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _ModeChoiceTile(
                              isSelected: selectedKind == 'meaning',
                              accentColor: colorScheme.primary,
                              icon: Icons.menu_book_rounded,
                              title: isThai
                                  ? 'ฉบับแปลความหมาย'
                                  : 'Meaning Mode',
                              subtitle: isThai
                                  ? 'คำแปลไทย + ตัฟซีร'
                                  : 'Thai & Tafsir',
                              onTap: () => setModalState(() {
                                selectedKind = 'meaning';
                                selectedPresetId = null;
                                formError = null;
                              }),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ModeChoiceTile(
                              isSelected: selectedKind == 'mushaf',
                              accentColor: const Color(0xFF8A6530),
                              icon: Icons.import_contacts_rounded,
                              title: isThai
                                  ? 'โหมดมุศหัฟ 604 หน้า'
                                  : 'Mushaf Mode',
                              subtitle: isThai
                                  ? 'ตามหน้าหนังสือจริง'
                                  : '604 Madinah Pages',
                              onTap: () => setModalState(() {
                                selectedKind = 'mushaf';
                                selectedPresetId = null;
                                formError = null;
                              }),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // STEP 2: Recommended Presets
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isThai
                                ? '2. แผนแนะนำยอดนิยม (กดเลือกได้ทันที)'
                                : '2. Recommended Presets',
                            style: GoogleFonts.notoSansThai(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            isThai ? 'หรือปรับเองด้านล่าง' : 'or customize',
                            style: GoogleFonts.notoSansThai(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 92,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: currentKindPresets.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final preset = currentKindPresets[index];
                            final isSelected = selectedPresetId == preset.id;
                            return InkWell(
                              onTap: () => applyPreset(preset, setModalState),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                width: 230,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? activeAccent.withValues(alpha: 0.08)
                                      : colors.surfaceMuted,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? activeAccent
                                        : colors.borderSoft,
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          preset.icon,
                                          size: 16,
                                          color: activeAccent,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            isThai
                                                ? preset.titleTh
                                                : preset.titleEn,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.notoSansThai(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: colorScheme.onSurface,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      isThai ? preset.descTh : preset.descEn,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.notoSansThai(
                                        fontSize: 11,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colorScheme.surface,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: colors.borderSoft,
                                        ),
                                      ),
                                      child: Text(
                                        isThai
                                            ? preset.badgeTh
                                            : preset.badgeEn,
                                        style: GoogleFonts.notoSansThai(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: activeAccent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // STEP 3: Goal Name
                    Text(
                      isThai ? '3. ชื่อเป้าหมาย' : '3. Goal Name',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      style: GoogleFonts.notoSansThai(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: selectedKind == 'meaning'
                            ? (isThai
                                  ? 'เช่น ค็อตม์เดือนรอมฎอน, อ่านซูเราะฮฺยาว'
                                  : 'e.g. Ramadan Khatam')
                            : (isThai
                                  ? 'เช่น ค็อตม์มุศหัฟ 604 หน้า'
                                  : 'e.g. 604 Pages Khatam'),
                        filled: true,
                        fillColor: colors.surfaceMuted,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: colors.borderSoft),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: colors.borderSoft),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: activeAccent,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // STEP 4: Scope & Range Settings
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.surfaceMuted,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: colors.borderSoft),
                      ),
                      child: selectedKind == 'meaning'
                          ? _buildMeaningScopeControls(
                              isThai: isThai,
                              colorScheme: colorScheme,
                              activeAccent: activeAccent,
                              meaningPlanMode: meaningPlanMode,
                              meaningStartJuz: meaningStartJuz,
                              meaningTargetJuz: meaningTargetJuz,
                              meaningStartSurah: meaningStartSurah,
                              meaningStartVerse: meaningStartVerse,
                              meaningTargetSurah: meaningTargetSurah,
                              meaningTargetVerse: meaningTargetVerse,
                              meaningAyatCount: meaningAyatCount,
                              onModeChanged: (mode) => setModalState(() {
                                meaningPlanMode = mode;
                                formError = null;
                              }),
                              onStartJuzChanged: (v) => setModalState(() {
                                meaningStartJuz = v;
                                if (meaningTargetJuz < v) meaningTargetJuz = v;
                              }),
                              onTargetJuzChanged: (v) => setModalState(() {
                                meaningTargetJuz = v;
                              }),
                              onStartSurahChanged: (v) => setModalState(() {
                                meaningStartSurah = v;
                                meaningStartVerse = '1';
                                if (int.parse(meaningTargetSurah) <
                                    int.parse(v)) {
                                  meaningTargetSurah = v;
                                }
                              }),
                              onStartVerseChanged: (v) => setModalState(() {
                                meaningStartVerse = v;
                              }),
                              onTargetSurahChanged: (v) => setModalState(() {
                                meaningTargetSurah = v;
                                final maxV = widget.repository
                                    .getSurahVerses(v)
                                    .length;
                                meaningTargetVerse =
                                    (maxV > 0 ? maxV : 1).toString();
                              }),
                              onTargetVerseChanged: (v) => setModalState(() {
                                meaningTargetVerse = v;
                              }),
                              onAyatCountChanged: (v) => setModalState(() {
                                meaningAyatCount = v;
                              }),
                            )
                          : _buildMushafScopeControls(
                              isThai: isThai,
                              colorScheme: colorScheme,
                              activeAccent: activeAccent,
                              maxPages: maxPages,
                              mushafPlanMode: mushafPlanMode,
                              mushafStartPage: mushafStartPage,
                              mushafTargetPage: mushafTargetPage,
                              mushafStartJuz: mushafStartJuz,
                              mushafTargetJuz: mushafTargetJuz,
                              mushafStartSurah: mushafStartSurah,
                              mushafTargetSurah: mushafTargetSurah,
                              onModeChanged: (mode) => setModalState(() {
                                mushafPlanMode = mode;
                                formError = null;
                              }),
                              onStartPageChanged: (v) => setModalState(() {
                                mushafStartPage = v;
                                if (mushafTargetPage < v) mushafTargetPage = v;
                              }),
                              onTargetPageChanged: (v) => setModalState(() {
                                mushafTargetPage = v;
                              }),
                              onStartJuzChanged: (v) => setModalState(() {
                                mushafStartJuz = v;
                                if (mushafTargetJuz < v) mushafTargetJuz = v;
                              }),
                              onTargetJuzChanged: (v) => setModalState(() {
                                mushafTargetJuz = v;
                              }),
                              onStartSurahChanged: (v) => setModalState(() {
                                mushafStartSurah = v;
                                if (int.parse(mushafTargetSurah) <
                                    int.parse(v)) {
                                  mushafTargetSurah = v;
                                }
                              }),
                              onTargetSurahChanged: (v) => setModalState(() {
                                mushafTargetSurah = v;
                              }),
                            ),
                    ),

                    if (formError != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          formError!,
                          style: GoogleFonts.notoSansThai(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSaving
                                ? null
                                : () => Navigator.pop(modalContext),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              isThai ? 'ยกเลิก' : 'Cancel',
                              style: GoogleFonts.notoSansThai(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    final name = nameController.text.trim();
                                    if (name.isEmpty) {
                                      setModalState(() {
                                        formError = isThai
                                            ? 'กรุณาระบุชื่อเป้าหมาย'
                                            : 'Please enter a goal name';
                                      });
                                      return;
                                    }

                                    setModalState(() {
                                      isSaving = true;
                                      formError = null;
                                    });

                                    try {
                                      if (selectedKind == 'meaning') {
                                        late VerseRef startRef;
                                        late VerseRef targetRef;
                                        if (meaningPlanMode == 'by_juz') {
                                          startRef =
                                              _juzStartRef(meaningStartJuz);
                                          targetRef =
                                              _juzEndRef(meaningTargetJuz);
                                        } else if (meaningPlanMode ==
                                            'by_surah') {
                                          startRef = toVerseRef(
                                            meaningStartSurah,
                                            1,
                                          );
                                          final endCount = widget.repository
                                              .getSurahVerses(
                                                meaningTargetSurah,
                                              )
                                              .length;
                                          targetRef = toVerseRef(
                                            meaningTargetSurah,
                                            endCount > 0 ? endCount : 1,
                                          );
                                        } else if (meaningPlanMode ==
                                            'by_ayat') {
                                          startRef = toVerseRef(
                                            meaningStartSurah,
                                            meaningStartVerse,
                                          );
                                          final startIdx =
                                              absoluteVerseIndex(startRef);
                                          final endIdx = (startIdx +
                                                  meaningAyatCount -
                                                  1)
                                              .clamp(startIdx, 6236);
                                          targetRef =
                                              verseRefFromAbsoluteIndex(endIdx);
                                        } else {
                                          startRef = toVerseRef(
                                            meaningStartSurah,
                                            meaningStartVerse,
                                          );
                                          targetRef = toVerseRef(
                                            meaningTargetSurah,
                                            meaningTargetVerse,
                                          );
                                        }

                                        if (absoluteVerseIndex(targetRef) <
                                            absoluteVerseIndex(startRef)) {
                                          setModalState(() {
                                            isSaving = false;
                                            formError = isThai
                                                ? 'จุดสิ้นสุดต้องอยู่หลังจุดเริ่มต้น'
                                                : 'End verse must be after start verse.';
                                          });
                                          return;
                                        }

                                        if (editingMeaningProfile != null) {
                                          await readingProv.updateProfile(
                                            profileId:
                                                editingMeaningProfile.id,
                                            name: name,
                                            planMode: meaningPlanMode,
                                            startJuz:
                                                meaningPlanMode == 'by_juz'
                                                    ? meaningStartJuz
                                                    : null,
                                            targetJuz:
                                                meaningPlanMode == 'by_juz'
                                                    ? meaningTargetJuz
                                                    : null,
                                            start: startRef,
                                            target: targetRef,
                                          );
                                        } else {
                                          await readingProv.createProfile(
                                            name: name,
                                            planMode: meaningPlanMode,
                                            startJuz:
                                                meaningPlanMode == 'by_juz'
                                                    ? meaningStartJuz
                                                    : null,
                                            targetJuz:
                                                meaningPlanMode == 'by_juz'
                                                    ? meaningTargetJuz
                                                    : null,
                                            start: startRef,
                                            target: targetRef,
                                            context: context,
                                          );
                                        }
                                      } else {
                                        late int resolvedStart;
                                        late int resolvedTarget;
                                        late String storedPlanMode;
                                        if (mushafPlanMode == 'juz_range') {
                                          resolvedStart =
                                              _mushafJuzStartPage(mushafStartJuz);
                                          resolvedTarget = _mushafJuzEndPage(
                                            mushafTargetJuz,
                                            maxPages,
                                          );
                                          storedPlanMode = 'by_juz';
                                        } else if (mushafPlanMode ==
                                            'surah_range') {
                                          resolvedStart = _surahStartPage(
                                            int.parse(mushafStartSurah),
                                          );
                                          resolvedTarget = _surahEndPage(
                                            int.parse(mushafTargetSurah),
                                            maxPages,
                                          );
                                          storedPlanMode = 'by_surah';
                                        } else {
                                          resolvedStart = mushafStartPage.clamp(
                                            1,
                                            maxPages,
                                          );
                                          resolvedTarget = mushafTargetPage
                                              .clamp(resolvedStart, maxPages);
                                          storedPlanMode = 'page_range';
                                        }

                                        if (editingMushafProfile != null) {
                                          await mushafProv.updateProfileRange(
                                            profileId: editingMushafProfile.id,
                                            name: name,
                                            planMode: storedPlanMode,
                                            startPage: resolvedStart,
                                            targetPage: resolvedTarget,
                                          );
                                        } else {
                                          await mushafProv
                                              .createPageRangeProfile(
                                                name: name,
                                                mushafId: mushafId,
                                                startPage: resolvedStart,
                                                targetPage: resolvedTarget,
                                                planMode: storedPlanMode,
                                              );
                                        }
                                      }

                                      if (modalContext.mounted) {
                                        Navigator.pop(modalContext);
                                      }
                                    } catch (e) {
                                      if (!modalContext.mounted) return;
                                      setModalState(() {
                                        isSaving = false;
                                        formError = e.toString();
                                      });
                                    }
                                  },
                            style: FilledButton.styleFrom(
                              backgroundColor: activeAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              isSaving
                                  ? (isThai ? 'กำลังบันทึก...' : 'Saving...')
                                  : isEditing
                                      ? (isThai
                                            ? 'บันทึกการแก้ไข'
                                            : 'Save Changes')
                                      : (isThai
                                            ? 'สร้างเป้าหมายการอ่าน'
                                            : 'Create Reading Goal'),
                              style: GoogleFonts.notoSansThai(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMeaningScopeControls({
    required bool isThai,
    required ColorScheme colorScheme,
    required Color activeAccent,
    required String meaningPlanMode,
    required int meaningStartJuz,
    required int meaningTargetJuz,
    required String meaningStartSurah,
    required String meaningStartVerse,
    required String meaningTargetSurah,
    required String meaningTargetVerse,
    required int meaningAyatCount,
    required ValueChanged<String> onModeChanged,
    required ValueChanged<int> onStartJuzChanged,
    required ValueChanged<int> onTargetJuzChanged,
    required ValueChanged<String> onStartSurahChanged,
    required ValueChanged<String> onStartVerseChanged,
    required ValueChanged<String> onTargetSurahChanged,
    required ValueChanged<String> onTargetVerseChanged,
    required ValueChanged<int> onAyatCountChanged,
  }) {
    final modes = [
      ('by_juz', isThai ? 'ตามญุซอ์' : 'By Juz'),
      ('by_surah', isThai ? 'ตามซูเราะฮฺ' : 'By Surah'),
      ('by_ayat', isThai ? 'จำนวนอายะฮฺ' : 'By Ayahs'),
      ('custom', isThai ? 'กำหนดเอง' : 'Custom'),
    ];

    final startSurahMaxVerse = widget.repository
        .getSurahVerses(meaningStartSurah)
        .length
        .clamp(1, 286);
    final targetSurahMaxVerse = widget.repository
        .getSurahVerses(meaningTargetSurah)
        .length
        .clamp(1, 286);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          isThai ? '4. รูปแบบการคำนวณขอบเขต' : '4. Range Calculation Method',
          style: GoogleFonts.notoSansThai(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: modes.map((m) {
            final isSelected = meaningPlanMode == m.$1;
            return ChoiceChip(
              label: Text(
                m.$2,
                style: GoogleFonts.notoSansThai(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : colorScheme.onSurface,
                ),
              ),
              selected: isSelected,
              selectedColor: activeAccent,
              onSelected: (_) => onModeChanged(m.$1),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        if (meaningPlanMode == 'by_juz')
          Row(
            children: [
              Expanded(
                child: _buildIntDropdown(
                  label: isThai ? 'ญุซอ์เริ่มต้น' : 'Start Juz',
                  value: meaningStartJuz,
                  min: 1,
                  max: 30,
                  itemLabel: (v) => isThai ? 'ญุซอ์ที่ $v' : 'Juz $v',
                  onChanged: onStartJuzChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildIntDropdown(
                  label: isThai ? 'ญุซอ์เป้าหมาย' : 'Target Juz',
                  value: meaningTargetJuz.clamp(meaningStartJuz, 30),
                  min: meaningStartJuz,
                  max: 30,
                  itemLabel: (v) => isThai ? 'ญุซอ์ที่ $v' : 'Juz $v',
                  onChanged: onTargetJuzChanged,
                ),
              ),
            ],
          )
        else if (meaningPlanMode == 'by_surah')
          Column(
            children: [
              _buildSurahDropdown(
                label: isThai ? 'ซูเราะฮฺเริ่มต้น' : 'Start Surah',
                value: meaningStartSurah,
                minSurah: 1,
                onChanged: onStartSurahChanged,
              ),
              const SizedBox(height: 10),
              _buildSurahDropdown(
                label: isThai ? 'ซูเราะฮฺสิ้นสุด' : 'End Surah',
                value: meaningTargetSurah,
                minSurah: int.tryParse(meaningStartSurah) ?? 1,
                onChanged: onTargetSurahChanged,
              ),
            ],
          )
        else if (meaningPlanMode == 'by_ayat')
          Column(
            children: [
              _buildSurahDropdown(
                label: isThai ? 'ซูเราะฮฺเริ่มต้น' : 'Start Surah',
                value: meaningStartSurah,
                minSurah: 1,
                onChanged: onStartSurahChanged,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildIntDropdown(
                      label: isThai ? 'อายะฮฺเริ่มต้น' : 'Start Ayah',
                      value: (int.tryParse(meaningStartVerse) ?? 1).clamp(
                        1,
                        startSurahMaxVerse,
                      ),
                      min: 1,
                      max: startSurahMaxVerse,
                      itemLabel: (v) => '$v',
                      onChanged: (v) => onStartVerseChanged(v.toString()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildIntDropdown(
                      label: isThai ? 'จำนวนอายะฮฺ' : 'Ayah Count',
                      value: meaningAyatCount.clamp(1, 300),
                      min: 1,
                      max: 300,
                      itemLabel: (v) =>
                          isThai ? '$v อายะฮฺ' : '$v Ayahs',
                      onChanged: onAyatCountChanged,
                    ),
                  ),
                ],
              ),
            ],
          )
        else
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildSurahDropdown(
                      label: isThai ? 'ซูเราะฮฺเริ่มต้น' : 'Start Surah',
                      value: meaningStartSurah,
                      minSurah: 1,
                      onChanged: onStartSurahChanged,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildIntDropdown(
                      label: isThai ? 'อายะฮฺเริ่ม' : 'Start Ayah',
                      value: (int.tryParse(meaningStartVerse) ?? 1).clamp(
                        1,
                        startSurahMaxVerse,
                      ),
                      min: 1,
                      max: startSurahMaxVerse,
                      itemLabel: (v) => '$v',
                      onChanged: (v) => onStartVerseChanged(v.toString()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildSurahDropdown(
                      label: isThai ? 'ซูเราะฮฺสิ้นสุด' : 'End Surah',
                      value: meaningTargetSurah,
                      minSurah: int.tryParse(meaningStartSurah) ?? 1,
                      onChanged: onTargetSurahChanged,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildIntDropdown(
                      label: isThai ? 'อายะฮฺสิ้นสุด' : 'End Ayah',
                      value: (int.tryParse(meaningTargetVerse) ?? 1).clamp(
                        1,
                        targetSurahMaxVerse,
                      ),
                      min: 1,
                      max: targetSurahMaxVerse,
                      itemLabel: (v) => '$v',
                      onChanged: (v) => onTargetVerseChanged(v.toString()),
                    ),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildMushafScopeControls({
    required bool isThai,
    required ColorScheme colorScheme,
    required Color activeAccent,
    required int maxPages,
    required String mushafPlanMode,
    required int mushafStartPage,
    required int mushafTargetPage,
    required int mushafStartJuz,
    required int mushafTargetJuz,
    required String mushafStartSurah,
    required String mushafTargetSurah,
    required ValueChanged<String> onModeChanged,
    required ValueChanged<int> onStartPageChanged,
    required ValueChanged<int> onTargetPageChanged,
    required ValueChanged<int> onStartJuzChanged,
    required ValueChanged<int> onTargetJuzChanged,
    required ValueChanged<String> onStartSurahChanged,
    required ValueChanged<String> onTargetSurahChanged,
  }) {
    final modes = [
      ('page_range', isThai ? 'ช่วงหน้า (1-604)' : 'Page Range'),
      ('juz_range', isThai ? 'ตามญุซอ์' : 'By Juz'),
      ('surah_range', isThai ? 'ตามซูเราะฮฺ' : 'By Surah'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          isThai
              ? '4. รูปแบบการคำนวณหน้ามุศหัฟ'
              : '4. Mushaf Range Calculation',
          style: GoogleFonts.notoSansThai(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: modes.map((m) {
            final isSelected = mushafPlanMode == m.$1;
            return ChoiceChip(
              label: Text(
                m.$2,
                style: GoogleFonts.notoSansThai(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : colorScheme.onSurface,
                ),
              ),
              selected: isSelected,
              selectedColor: activeAccent,
              onSelected: (_) => onModeChanged(m.$1),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        if (mushafPlanMode == 'page_range')
          Row(
            children: [
              Expanded(
                child: _buildIntDropdown(
                  label: isThai ? 'หน้าเริ่มต้น' : 'Start Page',
                  value: mushafStartPage.clamp(1, maxPages),
                  min: 1,
                  max: maxPages,
                  itemLabel: (v) => isThai ? 'หน้า $v' : 'Page $v',
                  onChanged: onStartPageChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildIntDropdown(
                  label: isThai ? 'หน้าสิ้นสุด' : 'End Page',
                  value: mushafTargetPage.clamp(mushafStartPage, maxPages),
                  min: mushafStartPage,
                  max: maxPages,
                  itemLabel: (v) => isThai ? 'หน้า $v' : 'Page $v',
                  onChanged: onTargetPageChanged,
                ),
              ),
            ],
          )
        else if (mushafPlanMode == 'juz_range')
          Row(
            children: [
              Expanded(
                child: _buildIntDropdown(
                  label: isThai ? 'ญุซอ์เริ่มต้น' : 'Start Juz',
                  value: mushafStartJuz,
                  min: 1,
                  max: 30,
                  itemLabel: (v) => isThai ? 'ญุซอ์ที่ $v' : 'Juz $v',
                  onChanged: onStartJuzChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildIntDropdown(
                  label: isThai ? 'ญุซอ์เป้าหมาย' : 'Target Juz',
                  value: mushafTargetJuz.clamp(mushafStartJuz, 30),
                  min: mushafStartJuz,
                  max: 30,
                  itemLabel: (v) => isThai ? 'ญุซอ์ที่ $v' : 'Juz $v',
                  onChanged: onTargetJuzChanged,
                ),
              ),
            ],
          )
        else
          Column(
            children: [
              _buildSurahDropdown(
                label: isThai ? 'ซูเราะฮฺเริ่มต้น' : 'Start Surah',
                value: mushafStartSurah,
                minSurah: 1,
                onChanged: onStartSurahChanged,
              ),
              const SizedBox(height: 10),
              _buildSurahDropdown(
                label: isThai ? 'ซูเราะฮฺสิ้นสุด' : 'End Surah',
                value: mushafTargetSurah,
                minSurah: int.tryParse(mushafStartSurah) ?? 1,
                onChanged: onTargetSurahChanged,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildIntDropdown({
    required String label,
    required int value,
    required int min,
    required int max,
    required String Function(int) itemLabel,
    required ValueChanged<int> onChanged,
  }) {
    final safeVal = value.clamp(min, max);
    return DropdownButtonFormField<int>(
      initialValue: safeVal,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      items: [
        for (int i = min; i <= max; i++)
          DropdownMenuItem(
            value: i,
            child: Text(
              itemLabel(i),
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.notoSansThai(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  Widget _buildSurahDropdown({
    required String label,
    required String value,
    required int minSurah,
    required ValueChanged<String> onChanged,
  }) {
    final parsed = (int.tryParse(value) ?? minSurah).clamp(minSurah, 114);
    return DropdownButtonFormField<String>(
      initialValue: parsed.toString(),
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      items: [
        for (int s = minSurah; s <= 114; s++)
          DropdownMenuItem(
            value: s.toString(),
            child: Text(
              widget.repository.getSurahName(s.toString()),
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.notoSansThai(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final readingProv = Provider.of<LocalReadingProvider>(context);
    final mushafProv = Provider.of<MushafReadingProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final colors = settings.getAppColors();
    final isThai = settings.languageCode == 'th';

    final meaningGoals = readingProv.activeProfiles
        .where((p) => !isFreeReadProfile(p) && !isShortcutProfile(p))
        .toList();
    final mushafGoals = mushafProv.activeCustomProfiles;

    final archivedMeaning = readingProv.archivedProfiles
        .where((p) => !isShortcutProfile(p))
        .toList();
    final archivedMushaf = mushafProv.archivedCustomProfiles;

    final totalActive = meaningGoals.length + mushafGoals.length;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              backgroundColor: colors.background,
              foregroundColor: colorScheme.onSurface,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: Text(
                isThai ? 'เป้าหมายการอ่าน' : 'Reading Goals',
                style: GoogleFonts.notoSansThai(
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FilledButton.icon(
                    onPressed: () => _showUnifiedGoalModal(),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(
                      isThai ? 'ตั้งเป้าหมายใหม่' : 'New Goal',
                      style: GoogleFonts.notoSansThai(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Header Section (when embedded as a tab)
                if (widget.isEmbedded) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isThai
                                  ? 'การวางแผนและติดตามการอ่าน'
                                  : 'READING GOALS & PLANS',
                              style: GoogleFonts.notoSansThai(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isThai
                                  ? 'เป้าหมายการอ่านอัลกุรอาน'
                                  : 'Quran Reading Goals',
                              style: GoogleFonts.notoSansThai(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => _showUnifiedGoalModal(),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(
                          isThai ? 'ตั้งเป้าหมายใหม่' : 'New Goal',
                          style: GoogleFonts.notoSansThai(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                ],

                // 1. Recommended Presets Strip
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: colors.borderSoft),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () =>
                            setState(() => _showPresets = !_showPresets),
                        borderRadius: BorderRadius.circular(12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.auto_awesome_rounded,
                                size: 16,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isThai
                                        ? 'แผนแนะนำยอดนิยม (1-Click Presets)'
                                        : 'Recommended Goal Presets',
                                    style: GoogleFonts.notoSansThai(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  Text(
                                    isThai
                                        ? 'แตะเลือกแผนด้านล่างเพื่อเริ่มตั้งเป้าหมายได้ทันที'
                                        : 'Tap any preset below to start a goal in seconds',
                                    style: GoogleFonts.notoSansThai(
                                      fontSize: 11,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              _showPresets
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                      if (_showPresets) ...[
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 108,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _goalPresets.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, index) {
                              final preset = _goalPresets[index];
                              final isMeaning = preset.kind == 'meaning';
                              final badgeColor = isMeaning
                                  ? colorScheme.primary
                                  : const Color(0xFF8A6530);

                              return InkWell(
                                onTap: () => _showUnifiedGoalModal(
                                  initialKind: preset.kind,
                                  initialPreset: preset,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                child: Container(
                                  width: 240,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceMuted,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: colors.borderSoft,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: badgeColor.withValues(
                                                alpha: 0.12,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              isMeaning
                                                  ? (isThai
                                                        ? 'ความหมาย'
                                                        : 'Meaning')
                                                  : (isThai
                                                        ? 'มุศหัฟ'
                                                        : 'Mushaf'),
                                              style: GoogleFonts.notoSansThai(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: badgeColor,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            isThai
                                                ? preset.badgeTh
                                                : preset.badgeEn,
                                            style: GoogleFonts.notoSansThai(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        isThai
                                            ? preset.titleTh
                                            : preset.titleEn,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.notoSansThai(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      Text(
                                        isThai ? preset.descTh : preset.descEn,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.notoSansThai(
                                          fontSize: 11,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 2. Filter Tabs (All / Meaning / Mushaf)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colors.surfaceMuted,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.borderSoft),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _FilterTabPill(
                          label: isThai
                              ? 'ทั้งหมด ($totalActive)'
                              : 'All ($totalActive)',
                          isSelected: _filterTab == GoalFilterTab.all,
                          activeColor: colorScheme.primary,
                          onTap: () =>
                              setState(() => _filterTab = GoalFilterTab.all),
                        ),
                      ),
                      Expanded(
                        child: _FilterTabPill(
                          label: isThai
                              ? 'ความหมาย (${meaningGoals.length})'
                              : 'Meaning (${meaningGoals.length})',
                          isSelected: _filterTab == GoalFilterTab.meaning,
                          activeColor: colorScheme.primary,
                          onTap: () => setState(
                            () => _filterTab = GoalFilterTab.meaning,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _FilterTabPill(
                          label: isThai
                              ? 'มุศหัฟ (${mushafGoals.length})'
                              : 'Mushaf (${mushafGoals.length})',
                          isSelected: _filterTab == GoalFilterTab.mushaf,
                          activeColor: const Color(0xFF8A6530),
                          onTap: () =>
                              setState(() => _filterTab = GoalFilterTab.mushaf),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 3. Meaning Goals List
                if (_filterTab == GoalFilterTab.all ||
                    _filterTab == GoalFilterTab.meaning) ...[
                  _buildSectionHeader(
                    icon: Icons.menu_book_rounded,
                    accentColor: colorScheme.primary,
                    title: isThai
                        ? 'เป้าหมายโหมดแปลความหมาย'
                        : 'Meaning Reading Goals',
                    countLabel: isThai
                        ? '${meaningGoals.length} เป้าหมาย'
                        : '${meaningGoals.length} active',
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: 12),
                  if (meaningGoals.isEmpty)
                    _buildEmptyGoalCard(
                      isThai: isThai,
                      isMeaning: true,
                      colorScheme: colorScheme,
                      colors: colors,
                      onAddTap: () => _showUnifiedGoalModal(
                        initialKind: 'meaning',
                        initialPreset: _goalPresets.first,
                      ),
                    )
                  else
                    ...meaningGoals.map(
                      (profile) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _buildMeaningGoalCard(
                          profile: profile,
                          isActive: readingProv.activeProfile?.id == profile.id,
                          isThai: isThai,
                          colorScheme: colorScheme,
                          colors: colors,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],

                // 4. Mushaf Goals List
                if (_filterTab == GoalFilterTab.all ||
                    _filterTab == GoalFilterTab.mushaf) ...[
                  _buildSectionHeader(
                    icon: Icons.import_contacts_rounded,
                    accentColor: const Color(0xFF8A6530),
                    title: isThai
                        ? 'เป้าหมายโหมดมุศหัฟ 604 หน้า'
                        : 'Mushaf Reading Goals',
                    countLabel: isThai
                        ? '${mushafGoals.length} เป้าหมาย'
                        : '${mushafGoals.length} active',
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: 12),
                  if (mushafGoals.isEmpty)
                    _buildEmptyGoalCard(
                      isThai: isThai,
                      isMeaning: false,
                      colorScheme: colorScheme,
                      colors: colors,
                      onAddTap: () => _showUnifiedGoalModal(
                        initialKind: 'mushaf',
                        initialPreset: _goalPresets[1],
                      ),
                    )
                  else
                    ...mushafGoals.map(
                      (profile) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _buildMushafGoalCard(
                          profile: profile,
                          isThai: isThai,
                          colorScheme: colorScheme,
                          colors: colors,
                        ),
                      ),
                    ),
                ],

                // 5. Archived Goals Drawer
                if (archivedMeaning.isNotEmpty ||
                    archivedMushaf.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildArchivedGoalsCard(
                    archivedMeaning: archivedMeaning,
                    archivedMushaf: archivedMushaf,
                    readingProv: readingProv,
                    mushafProv: mushafProv,
                    isThai: isThai,
                    colorScheme: colorScheme,
                    colors: colors,
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required Color accentColor,
    required String title,
    required String countLabel,
    required ColorScheme colorScheme,
  }) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: accentColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.notoSansThai(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            countLabel,
            style: GoogleFonts.notoSansThai(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyGoalCard({
    required bool isThai,
    required bool isMeaning,
    required ColorScheme colorScheme,
    required AppThemeColors colors,
    required VoidCallback onAddTap,
  }) {
    final accent = isMeaning ? colorScheme.primary : const Color(0xFF8A6530);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isMeaning
                  ? Icons.menu_book_rounded
                  : Icons.import_contacts_rounded,
              color: accent,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isMeaning
                ? (isThai
                      ? 'ยังไม่มีเป้าหมายโหมดแปลความหมาย'
                      : 'No Meaning reading goals yet')
                : (isThai
                      ? 'ยังไม่มีเป้าหมายโหมดมุศหัฟ 604 หน้า'
                      : 'No Mushaf reading goals yet'),
            style: GoogleFonts.notoSansThai(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isMeaning
                ? (isThai
                      ? 'เริ่มต้นตั้งเป้าหมายการอ่านคำแปลรายญุซอ์ หรือรายซูเราะฮฺ'
                      : 'Track your Quran meaning reading by Juz, Surah, or Ayahs.')
                : (isThai
                      ? 'เริ่มต้นวางแผนการอ่านมุศหัฟตามหน้าจริง (1–604 หน้า)'
                      : 'Plan your Madinah Mushaf reading across 604 pages.'),
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSansThai(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAddTap,
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text(
              isMeaning
                  ? (isThai ? 'เริ่มค็อตม์ 30 ญุซอ์' : 'Start 30 Juz Khatam')
                  : (isThai
                        ? 'เริ่มตั้งเป้าหมาย 604 หน้า'
                        : 'Start 604 Pages Khatam'),
              style: GoogleFonts.notoSansThai(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeaningGoalCard({
    required LocalReadingProfile profile,
    required bool isActive,
    required bool isThai,
    required ColorScheme colorScheme,
    required AppThemeColors colors,
  }) {
    final progress = _calculateMeaningProgress(profile);
    final resume = profile.furthestUnread;
    final startSurahName = widget.repository.getSurahName(
      profile.start.surahId,
    );
    final targetSurahName = profile.target != null
        ? widget.repository.getSurahName(profile.target!.surahId)
        : '';
    final resumeSurahName = widget.repository.getSurahName(resume.surahId);
    final emerald = colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isActive
              ? emerald.withValues(alpha: 0.45)
              : colors.borderSoft,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top badges
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isThai ? 'ความหมาย' : 'Meaning',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: emerald,
                  ),
                ),
              ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceMuted,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.borderSoft),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: emerald,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isThai ? 'กำลังอ่านอยู่' : 'Active',
                        style: GoogleFonts.notoSansThai(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Title & Range
          Text(
            profile.name,
            style: GoogleFonts.notoSansThai(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            profile.target != null
                ? '$startSurahName (${profile.start.verseKey})  →  $targetSurahName (${profile.target!.verseKey})'
                : '$startSurahName (${profile.start.verseKey})',
            style: GoogleFonts.notoSansThai(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (progress.percent / 100).clamp(0.03, 1.0),
              minHeight: 8,
              backgroundColor: colors.surfaceMuted,
              valueColor: AlwaysStoppedAnimation<Color>(emerald),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${progress.percent}% ${isThai ? 'เสร็จสิ้น' : 'complete'}',
                style: GoogleFonts.notoSansThai(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: emerald,
                ),
              ),
              Text(
                '${progress.done} / ${progress.total} ${isThai ? 'อายะฮฺ' : 'ayahs'}',
                style: GoogleFonts.notoSansThai(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Currently Reading At Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.borderSoft),
            ),
            child: Row(
              children: [
                Icon(Icons.bookmark_rounded, size: 18, color: emerald),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isThai
                            ? 'อ่านค้างไว้ที่ล่าสุด'
                            : 'CURRENTLY READING AT',
                        style: GoogleFonts.notoSansThai(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '$resumeSurahName (${resume.verseKey})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSansThai(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.borderSoft),
                  ),
                  child: Text(
                    '${isThai ? 'อายะฮฺที่' : 'Ayah'} ${resume.verseId}',
                    style: GoogleFonts.notoSansThai(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Actions Footer
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _showUnifiedGoalModal(
                  editingMeaningProfile: profile,
                ),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.onSurfaceVariant,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.edit_outlined, size: 15),
                label: Text(
                  isThai ? 'แก้ไข' : 'Edit',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => context
                    .read<LocalReadingProvider>()
                    .archiveProfile(profile.id),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.error,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.archive_outlined, size: 15),
                label: Text(
                  isThai ? 'จัดเก็บ' : 'Archive',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _openMeaningGoal(profile),
                style: FilledButton.styleFrom(
                  backgroundColor: emerald,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                label: Text(
                  isThai
                      ? 'อ่านต่อ (${resume.verseKey})'
                      : 'Continue (${resume.verseKey})',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 15),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMushafGoalCard({
    required MushafProfile profile,
    required bool isThai,
    required ColorScheme colorScheme,
    required AppThemeColors colors,
  }) {
    final progress = _calculateMushafProgress(profile);
    const amber = Color(0xFF8A6530);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isThai ? 'มุศหัฟ 604 หน้า' : 'Mushaf Pages',
              style: GoogleFonts.notoSansThai(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: amber,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Title & Range
          Text(
            profile.name,
            style: GoogleFonts.notoSansThai(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${isThai ? 'หน้า' : 'Pages'} ${profile.startPage} – ${profile.targetPage} (${progress.total} ${isThai ? 'หน้า' : 'pages'})',
            style: GoogleFonts.notoSansThai(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (progress.percent / 100).clamp(0.03, 1.0),
              minHeight: 8,
              backgroundColor: colors.surfaceMuted,
              valueColor: const AlwaysStoppedAnimation<Color>(amber),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${progress.percent}% ${isThai ? 'เสร็จสิ้น' : 'complete'}',
                style: GoogleFonts.notoSansThai(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: amber,
                ),
              ),
              Text(
                '${progress.done} / ${progress.total} ${isThai ? 'หน้า' : 'pages'}',
                style: GoogleFonts.notoSansThai(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Currently Reading At Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.borderSoft),
            ),
            child: Row(
              children: [
                const Icon(Icons.bookmark_rounded, size: 18, color: amber),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isThai
                            ? 'อ่านค้างไว้ที่ล่าสุด'
                            : 'CURRENTLY READING AT',
                        style: GoogleFonts.notoSansThai(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '${isThai ? 'หน้ามุศหัฟที่' : 'Mushaf Page'} ${profile.lastViewedPage}',
                        style: GoogleFonts.notoSansThai(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.borderSoft),
                  ),
                  child: Text(
                    '${isThai ? 'หน้า' : 'P.'} ${profile.lastViewedPage} / ${profile.targetPage}',
                    style: GoogleFonts.notoSansThai(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Actions Footer
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _showUnifiedGoalModal(
                  editingMushafProfile: profile,
                ),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.onSurfaceVariant,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.edit_outlined, size: 15),
                label: Text(
                  isThai ? 'แก้ไข' : 'Edit',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => context
                    .read<MushafReadingProvider>()
                    .archiveProfile(profile.id),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.error,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.archive_outlined, size: 15),
                label: Text(
                  isThai ? 'จัดเก็บ' : 'Archive',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _openMushafGoal(profile),
                style: FilledButton.styleFrom(
                  backgroundColor: amber,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                label: Text(
                  isThai
                      ? 'เปิดอ่านหน้า ${profile.lastViewedPage}'
                      : 'Continue P.${profile.lastViewedPage}',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 15),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildArchivedGoalsCard({
    required List<LocalReadingProfile> archivedMeaning,
    required List<MushafProfile> archivedMushaf,
    required LocalReadingProvider readingProv,
    required MushafReadingProvider mushafProv,
    required bool isThai,
    required ColorScheme colorScheme,
    required AppThemeColors colors,
  }) {
    final totalArchived = archivedMeaning.length + archivedMushaf.length;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.archive_outlined,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isThai
                        ? 'เป้าหมายที่เก็บถาวร (Archived Goals)'
                        : 'Archived Goals',
                    style: GoogleFonts.notoSansThai(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              Text(
                '$totalArchived ${isThai ? 'รายการ' : 'items'}',
                style: GoogleFonts.notoSansThai(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...archivedMeaning.map(
            (profile) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.name,
                          style: GoogleFonts.notoSansThai(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          '${isThai ? 'ความหมาย' : 'Meaning'} • ${profile.start.verseKey} → ${profile.target?.verseKey ?? '114:6'}',
                          style: GoogleFonts.notoSansThai(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      try {
                        await readingProv.restoreProfile(profile.id);
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString())),
                          );
                        }
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      isThai ? 'กู้คืน' : 'Restore',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ...archivedMushaf.map(
            (profile) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.name,
                          style: GoogleFonts.notoSansThai(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          '${isThai ? 'มุศหัฟ' : 'Mushaf'} • ${isThai ? 'หน้า' : 'Pages'} ${profile.startPage}–${profile.targetPage}',
                          style: GoogleFonts.notoSansThai(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      try {
                        await mushafProv.restoreProfile(profile.id);
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString())),
                          );
                        }
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      isThai ? 'กู้คืน' : 'Restore',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChoiceTile extends StatelessWidget {
  final bool isSelected;
  final Color accentColor;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ModeChoiceTile({
    required this.isSelected,
    required this.accentColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.08)
              : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accentColor : colorScheme.outlineVariant,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? accentColor.withValues(alpha: 0.15)
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 18,
                color: isSelected ? accentColor : colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSansThai(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSansThai(
                      fontSize: 10,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterTabPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  const _FilterTabPill({
    required this.label,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.notoSansThai(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isSelected ? Colors.white : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
