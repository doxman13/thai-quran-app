import 'package:flutter_test/flutter_test.dart';
import 'package:thai_quran_app/database/hifz_repository.dart';
import 'package:thai_quran_app/models/hifz_session_config.dart';
import 'package:thai_quran_app/models/hifz_task.dart';
import 'package:thai_quran_app/models/hifz_verse_chunk.dart';
import 'package:thai_quran_app/providers/hifz_session_provider.dart';
import 'package:thai_quran_app/services/waqf_chunker_service.dart';
import 'package:thai_quran_app/utils/hifz_mastery_utils.dart';

class _MemoryHifzRepository implements HifzRepository {
  ActiveSessionSnapshot? lastSavedSnapshot;
  final List<HifzHistoryRecord> history = [];
  final Set<int> completedSurahs = {};
  int flushCount = 0;

  @override
  Future<void> saveActiveSession(ActiveSessionSnapshot snapshot) async {
    lastSavedSnapshot = snapshot;
  }

  @override
  Future<List<HifzHistoryRecord>> getHistory({int limit = 50}) async {
    return history.take(limit).toList();
  }

  @override
  Future<void> recordHistory(HifzSessionType type, String title,
      {int? surahNumber}) async {
    history.insert(
      0,
      HifzHistoryRecord(
        id: 'h_${history.length + 1}',
        sessionType: type,
        surahNumber: surahNumber,
        title: title,
        completedAt: DateTime.now().toUtc(),
      ),
    );
  }

  @override
  Future<void> markNewVersesCompleted(int surahNumber) async {
    completedSurahs.add(surahNumber);
  }

  @override
  Future<void> clearActiveSession({String? sessionId}) async {
    lastSavedSnapshot = null;
  }

  @override
  Future<void> flushPendingActiveSessionSync() async {
    flushCount++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Hifz Mastery Utils & Cross-Platform History Parsing', () {
    test('parseHistoryVerseRange supports both Thai and English titles', () {
      final thPartial = parseHistoryVerseRange(
          'ซูเราะฮฺที่ 67: 1–5 (ท่องอายะฮฺใหม่)', 67);
      expect(thPartial?.startVerse, 1);
      expect(thPartial?.endVerse, 5);

      final enPartial =
          parseHistoryVerseRange('Surah 67:6-10 (New Verses)', 67);
      expect(enPartial?.startVerse, 6);
      expect(enPartial?.endVerse, 10);

      final thFull =
          parseHistoryVerseRange('ซูเราะฮฺที่ 67 (ท่องอายะฮฺใหม่)', 67);
      expect(thFull?.startVerse, 1);
      expect(thFull?.endVerse, 30);

      final enFull = parseHistoryVerseRange('Surah 67 (New Verses)', 67);
      expect(enFull?.startVerse, 1);
      expect(enFull?.endVerse, 30);
    });

    test('areAllSurahVersesCoveredFromHistory detects cumulative coverage', () {
      final partialHistory = [
        HifzHistoryRecord(
          id: '1',
          sessionType: HifzSessionType.newVerses,
          surahNumber: 67,
          title: 'Surah 67:1-15 (New Verses)',
          completedAt: DateTime.utc(2026, 11, 20),
        ),
        HifzHistoryRecord(
          id: '2',
          sessionType: HifzSessionType.newVerses,
          surahNumber: 67,
          title: 'ซูเราะฮฺที่ 67: 16–25 (ท่องอายะฮฺใหม่)',
          completedAt: DateTime.utc(2026, 11, 20),
        ),
      ];

      expect(
        areAllSurahVersesCoveredFromHistory(
          surahNumber: 67,
          history: partialHistory,
        ),
        isFalse,
      );

      expect(
        areAllSurahVersesCoveredFromHistory(
          surahNumber: 67,
          history: partialHistory,
          extraRanges: [const VerseRange(startVerse: 26, endVerse: 30)],
        ),
        isTrue,
      );
    });

    test('buildSurahMasterySummaries counts active, partial, and mastered', () {
      final activeSnap = ActiveSessionSnapshot(
        sessionId: 'active-67',
        sessionType: HifzSessionType.newVerses,
        nvSurahNumber: 67,
        nvRepeatStart: 1,
        nvStartVerse: 1,
        nvEndVerse: 5,
        currentVerse: 2,
        totalSteps: 54,
        currentStepIndex: 6,
        currentMode: 'visible',
        currentTally: 4,
        targetTally: 10,
        lastUpdatedTimestamp: 1700000000000,
      );

      final summaries = buildSurahMasterySummaries(
        records: const [
          SurahCompletionRecord(
            surahNumber: 112,
            newVersesCompleted: true,
            reviewCount: 3,
          ),
        ],
        history: [
          HifzHistoryRecord(
            id: 'h1',
            sessionType: HifzSessionType.newVerses,
            surahNumber: 78,
            title: 'ซูเราะฮฺที่ 78: 1–10 (ท่องอายะฮฺใหม่)',
            completedAt: DateTime.utc(2026, 11, 20),
          ),
        ],
        activeSession: activeSnap,
      );

      expect(summaries[112]!.status, HifzMasteryStatus.mastered);
      expect(summaries[67]!.status, HifzMasteryStatus.inProgress);
      expect(summaries[67]!.hasActiveSession, isTrue);
      expect(summaries[78]!.status, HifzMasteryStatus.inProgress);
      expect(summaries[78]!.furthestCompletedVerse, 10);
      expect(summaries[2]!.status, HifzMasteryStatus.notStarted);

      final subtitleTh = formatActiveSessionSubtitle(activeSnap, isThai: true);
      expect(subtitleTh, contains('อายะฮฺที่ 2'));
      expect(subtitleTh, contains('7/54'));
      expect(subtitleTh, contains('4/10'));
    });
  });

  group('HifzSessionProvider Midway & Async Chunk Hydration', () {
    test('restoreFromSnapshot survives delayed setVerseChunks via currentTaskId',
        () async {
      const longVerse =
          'تَبَٰرَكَ ٱلَّذِى بِيَدِهِ ٱلۡمُلۡكُ وَهُوَ عَلَىٰ كُلِّ شَىۡءٍ قَدِيرٌ ١ ٱلَّذِى خَلَقَ ٱلۡمَوۡتَ وَٱلۡحَيَوٰةَ لِيَبۡلُوَكُمۡ أَيُّكُمۡ أَحۡسَنُ عَمَلًاۚ وَهُوَ ٱلۡعَزِيزُ ٱلۡغَفُورُ';
      final chunks = WaqfChunkerService.chunkVerse(
        surah: 2,
        verse: 255,
        verseText:
            'ٱللَّهُ لَآ إِلَٰهَ إِلَّا هُوَ ٱلۡحَىُّ ٱلۡقَيُّومُۚ لَا تَأۡخُذُهُۥ سِنَةٞ وَلَا نَوۡمٞۚ لَّهُۥ مَا فِى ٱلسَّمَٰوٰتِ وَمَا فِى ٱلۡأَرۡضِۗ مَن ذَا ٱلَّذِى يَشۡفَعُ عِندَهُۥٓ إِلَّا بِإِذۡنِهِۦۚ يَعۡلَمُ مَا بَيۡنَ أَيۡدِيهِمۡ وَمَا خَلۡفَهُمۡۖ وَلَا يُحِيطُونَ بِشَىۡءٖ مِّنۡ عِلۡمِهِۦٓ إِلَّا بِمَا شَآءَۚ وَسِعَ كُرۡسِيُّهُ ٱلسَّمَٰوٰتِ وَٱلۡأَرۡضَۖ وَلَا يَـُٔودُهُۥ حِفۡظُهُمَاۚ وَهُوَ ٱلۡعَلِىُّ ٱلۡعَظِيمُ',
      );
      expect(chunks.length, greaterThan(1));

      final chunksMap = <int, List<HifzVerseChunk>>{
        255: chunks,
        256: [
          const HifzVerseChunk(
            surah: 2,
            verse: 256,
            chunkIndex: 1,
            totalChunks: 1,
            text: longVerse,
            startWordPos: 1,
            endWordPos: 10,
            wordCount: 10,
          ),
        ],
      };

      final chunkedRoutine = generateHifzRoutine(
        255,
        255,
        256,
        verseChunksMap: chunksMap,
      );
      final targetIdx =
          chunkedRoutine.indexWhere((t) => t.id == 'verse_256_visible_r1');
      expect(targetIdx, greaterThan(0));

      final repo = _MemoryHifzRepository();
      final provider = HifzSessionProvider(
        repository: repo,
        surahNumber: 2,
        repeatStart: 255,
        startVerse: 255,
        endVerse: 256,
      );

      provider.restoreFromSnapshot(
        ActiveSessionSnapshot(
          sessionId: 'resume-chunk-1',
          sessionType: HifzSessionType.newVerses,
          nvSurahNumber: 2,
          nvRepeatStart: 255,
          nvStartVerse: 255,
          nvEndVerse: 256,
          nvChunkLongVerses: true,
          currentTaskId: 'verse_256_visible_r1',
          currentVerse: 256,
          totalSteps: chunkedRoutine.length,
          currentStepIndex: targetIdx,
          currentMode: 'visible',
          currentTally: 3,
          targetTally: 10,
          verseTallyMap: {255: 15, 256: 3},
          lastUpdatedTimestamp: 1700000001000,
        ),
      );

      // Simulate async chunk loading resolving right after restore
      provider.setVerseChunks(chunksMap, enable: true);

      expect(provider.currentTaskIndex, targetIdx);
      expect(provider.currentTask?.id, 'verse_256_visible_r1');
      expect(provider.currentTask?.currentProgress, 3);
      expect(provider.tasks[0].currentProgress,
          provider.tasks[0].targetRepetitions);
      expect(provider.verseTallyMap[255], 15);
      expect(provider.verseTallyMap[256], 3);
      await Future<void>.delayed(Duration.zero);
      expect(repo.lastSavedSnapshot?.currentTaskId, 'verse_256_visible_r1');
      expect(repo.lastSavedSnapshot?.currentTally, 3);
    });

    test('restoreFromSnapshot advances cleanly if saved at completed hold', () {
      final repo = _MemoryHifzRepository();
      final provider = HifzSessionProvider(
        repository: repo,
        surahNumber: 67,
        repeatStart: 1,
        startVerse: 1,
        endVerse: 2,
      );

      provider.restoreFromSnapshot(
        ActiveSessionSnapshot(
          sessionId: 'hold-step-0',
          sessionType: HifzSessionType.newVerses,
          nvSurahNumber: 67,
          nvRepeatStart: 1,
          nvStartVerse: 1,
          nvEndVerse: 2,
          currentTaskId: provider.tasks[0].id,
          currentStepIndex: 0,
          currentMode: 'visible',
          currentTally: 10,
          targetTally: 10,
          lastUpdatedTimestamp: 1700000002000,
        ),
      );

      expect(provider.currentTaskIndex, 1);
      expect(provider.currentTask?.currentProgress, 0);
    });

    test('live incrementProgress before setVerseChunks preserves user progress',
        () {
      final repo = _MemoryHifzRepository();
      final provider = HifzSessionProvider(
        repository: repo,
        surahNumber: 2,
        repeatStart: 255,
        startVerse: 255,
        endVerse: 255,
      );

      provider.incrementProgress();
      provider.incrementProgress();
      expect(provider.currentTask?.currentProgress, 2);

      // Delayed empty chunks map finishes loading
      provider.setVerseChunks({}, enable: true);
      expect(provider.currentTaskIndex, 0);
      expect(provider.currentTask?.currentProgress, 2);
    });
  });
}
