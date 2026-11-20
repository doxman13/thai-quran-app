// lib/utils/hifz_mastery_utils.dart
//
// Shared pure helpers for Hifz partial-range mastery status, verse range
// coverage, active midway session detection, and resume summaries.

import 'package:qcf_quran/qcf_quran.dart' as qcf;

import '../data/offline_surah_names.dart';
import '../models/hifz_session_config.dart';

enum HifzMasteryStatus { mastered, inProgress, notStarted }

class VerseRange {
  final int startVerse;
  final int endVerse;

  const VerseRange({
    required this.startVerse,
    required this.endVerse,
  });
}

class SurahMasterySummary {
  final int surahNumber;
  final HifzMasteryStatus status;
  final bool newVersesCompleted;
  final int reviewCount;
  final bool hasPartialProgress;
  final bool hasActiveSession;
  final int furthestCompletedVerse;
  final ActiveSessionSnapshot? activeSession;

  const SurahMasterySummary({
    required this.surahNumber,
    required this.status,
    required this.newVersesCompleted,
    required this.reviewCount,
    required this.hasPartialProgress,
    required this.hasActiveSession,
    required this.furthestCompletedVerse,
    this.activeSession,
  });
}

/// Extracts a memorized verse range from a Hifz history record title.
/// Supports both English ("Surah 67:1-5 ...") and Thai ("ซูเราะฮฺที่ 67: 1–5 ...") formats.
VerseRange? parseHistoryVerseRange(String title, int surahNumber) {
  final totalVerses = qcf.getVerseCount(surahNumber);
  if (totalVerses <= 0) return null;

  final rangeMatch = RegExp(
    r'(?:ซูเราะฮฺที่|Surah)\s*\d+\s*:\s*(\d+)\s*[–-]\s*(\d+)',
    caseSensitive: false,
  ).firstMatch(title);
  if (rangeMatch != null) {
    final rawStart = int.tryParse(rangeMatch.group(1) ?? '');
    final rawEnd = int.tryParse(rangeMatch.group(2) ?? '');
    if (rawStart != null && rawEnd != null) {
      final start = rawStart.clamp(1, totalVerses);
      final end = rawEnd.clamp(start, totalVerses);
      return VerseRange(startVerse: start, endVerse: end);
    }
  }

  final fullSurahMatch = RegExp(
    '^(?:ซูเราะฮฺที่|Surah)\\s*$surahNumber\\b',
    caseSensitive: false,
  ).firstMatch(title.trim());
  if (fullSurahMatch != null && !title.contains(':')) {
    return VerseRange(startVerse: 1, endVerse: totalVerses);
  }

  return null;
}

/// Returns true if the union of [ranges] covers verses 1..totalVerses of [surahNumber].
bool areAllSurahVersesCovered(int surahNumber, List<VerseRange> ranges) {
  final totalVerses = qcf.getVerseCount(surahNumber);
  if (totalVerses <= 0 || ranges.isEmpty) return false;

  final normalized = ranges
      .map((r) {
        final s = r.startVerse <= r.endVerse ? r.startVerse : r.endVerse;
        final e = r.startVerse <= r.endVerse ? r.endVerse : r.startVerse;
        return VerseRange(
          startVerse: s < 1 ? 1 : s,
          endVerse: e > totalVerses ? totalVerses : e,
        );
      })
      .where((r) => r.startVerse <= totalVerses && r.endVerse >= 1)
      .toList()
    ..sort((a, b) => a.startVerse.compareTo(b.startVerse));

  int coveredThrough = 0;
  for (final r in normalized) {
    if (r.startVerse > coveredThrough + 1) return false;
    if (r.endVerse > coveredThrough) {
      coveredThrough = r.endVerse;
    }
    if (coveredThrough >= totalVerses) return true;
  }
  return coveredThrough >= totalVerses;
}

/// Checks whether completed New-Verses history records plus [extraRanges]
/// cover every verse 1..totalVerses of [surahNumber].
bool areAllSurahVersesCoveredFromHistory({
  required int surahNumber,
  required List<HifzHistoryRecord> history,
  List<VerseRange> extraRanges = const [],
}) {
  final ranges = <VerseRange>[...extraRanges];
  for (final item in history) {
    if (item.surahNumber == surahNumber &&
        item.sessionType == HifzSessionType.newVerses) {
      final parsed = parseHistoryVerseRange(item.title, surahNumber);
      if (parsed != null) ranges.add(parsed);
    }
  }
  return areAllSurahVersesCovered(surahNumber, ranges);
}

/// Returns the surah numbers currently touched by an active paused Hifz session.
List<int> getActiveSessionSurahNumbers(ActiveSessionSnapshot? snapshot) {
  if (snapshot == null) return const [];

  if (snapshot.sessionType == HifzSessionType.newVerses) {
    return snapshot.nvSurahNumber != null ? [snapshot.nvSurahNumber!] : const [];
  }

  if (snapshot.reviewGranularity == ReviewGranularity.byVerses) {
    final s = snapshot.reviewTargetParams?.surahNumber ?? snapshot.nvSurahNumber;
    return s != null ? [s] : const [];
  }

  if (snapshot.reviewGranularity == ReviewGranularity.bySurah) {
    final start = snapshot.reviewTargetParams?.startSurah ?? snapshot.nvSurahNumber;
    final current = snapshot.nvSurahNumber ?? start;
    if (start == null) return const [];
    final maxEnd = snapshot.reviewTargetParams?.endSurah ?? start;
    final end = (current ?? start).clamp(start, maxEnd);
    return [for (int s = start; s <= end; s++) s];
  }

  return snapshot.nvSurahNumber != null ? [snapshot.nvSurahNumber!] : const [];
}

/// Computes unified 114-surah mastery summaries combining full-surah records,
/// partial completed ranges in history, and any active midway session.
Map<int, SurahMasterySummary> buildSurahMasterySummaries({
  required List<SurahCompletionRecord> records,
  required List<HifzHistoryRecord> history,
  required ActiveSessionSnapshot? activeSession,
  int masteredReviewThreshold = 3,
}) {
  final recordMap = <int, SurahCompletionRecord>{
    for (final r in records) r.surahNumber: r,
  };

  final historyBySurah = <int, List<HifzHistoryRecord>>{};
  for (final h in history) {
    final sNum = h.surahNumber;
    if (sNum == null) continue;
    historyBySurah.putIfAbsent(sNum, () => []).add(h);
  }

  final activeSurahs = getActiveSessionSurahNumbers(activeSession).toSet();
  final summaries = <int, SurahMasterySummary>{};

  for (int sNum = 1; sNum <= 114; sNum++) {
    final record = recordMap[sNum];
    final newVersesCompleted = record?.newVersesCompleted ?? false;
    final reviewCount = record?.reviewCount ?? 0;
    final surahHistory = historyBySurah[sNum] ?? const [];
    final hasActive = activeSurahs.contains(sNum);

    int furthestCompletedVerse = 0;
    if (newVersesCompleted) {
      furthestCompletedVerse = qcf.getVerseCount(sNum);
    } else {
      for (final item in surahHistory) {
        if (item.sessionType == HifzSessionType.newVerses) {
          final parsed = parseHistoryVerseRange(item.title, sNum);
          if (parsed != null && parsed.endVerse > furthestCompletedVerse) {
            furthestCompletedVerse = parsed.endVerse;
          }
        }
      }
    }

    final hasPartialProgress = surahHistory.isNotEmpty || hasActive;
    final HifzMasteryStatus status;
    if (newVersesCompleted && reviewCount >= masteredReviewThreshold) {
      status = HifzMasteryStatus.mastered;
    } else if (newVersesCompleted || reviewCount > 0 || hasPartialProgress) {
      status = HifzMasteryStatus.inProgress;
    } else {
      status = HifzMasteryStatus.notStarted;
    }

    summaries[sNum] = SurahMasterySummary(
      surahNumber: sNum,
      status: status,
      newVersesCompleted: newVersesCompleted,
      reviewCount: reviewCount,
      hasPartialProgress: hasPartialProgress,
      hasActiveSession: hasActive,
      furthestCompletedVerse: furthestCompletedVerse,
      activeSession: hasActive ? activeSession : null,
    );
  }

  return summaries;
}

/// Formats a concise human-readable subtitle for an active paused session.
String formatActiveSessionSubtitle(
  ActiveSessionSnapshot snap, {
  required bool isThai,
}) {
  final stepNum = snap.totalSteps != null && snap.totalSteps! > 0
      ? (snap.currentStepIndex + 1).clamp(1, snap.totalSteps!)
      : snap.currentStepIndex + 1;
  final stepPart = snap.totalSteps != null && snap.totalSteps! > 0
      ? (isThai ? 'ขั้นตอน $stepNum/${snap.totalSteps}' : 'Step $stepNum/${snap.totalSteps}')
      : (isThai ? 'ขั้นที่ $stepNum' : 'Step $stepNum');
  final tallyPart = isThai
      ? 'รอบ ${snap.currentTally}/${snap.targetTally}'
      : '${snap.currentTally}/${snap.targetTally}';

  if (snap.sessionType == HifzSessionType.newVerses) {
    final surah = snap.nvSurahNumber ?? 1;
    final start = snap.nvStartVerse ?? 1;
    final end = snap.nvEndVerse ?? 1;
    final surahName = surahDisplayName(surah.toString(), isThai: isThai);
    final versePart = snap.currentVerse != null
        ? (isThai ? 'อายะฮฺที่ ${snap.currentVerse}' : 'Ayah ${snap.currentVerse}')
        : null;
    final parts = [
      '$surahName ($surah:$start–$end)',
      if (versePart != null) '$versePart ($stepPart)' else stepPart,
      tallyPart,
    ];
    return parts.join(' • ');
  }

  final gran = snap.reviewGranularity ?? ReviewGranularity.bySurah;
  final String reviewLabel;
  if (gran == ReviewGranularity.bySurah) {
    final start = snap.reviewTargetParams?.startSurah ?? snap.nvSurahNumber ?? 1;
    final end = snap.reviewTargetParams?.endSurah ?? start;
    reviewLabel = start == end
        ? (isThai ? 'ทบทวนซูเราะฮฺ $start' : 'Review Surah $start')
        : (isThai ? 'ทบทวนซูเราะฮฺ $start–$end' : 'Review Surahs $start–$end');
  } else if (gran == ReviewGranularity.byVerses) {
    final surah = snap.reviewTargetParams?.surahNumber ?? snap.nvSurahNumber ?? 1;
    final start = snap.reviewTargetParams?.startVerse ?? 1;
    final end = snap.reviewTargetParams?.endVerse ?? 1;
    reviewLabel = isThai ? 'ทบทวน $surah:$start–$end' : 'Review $surah:$start–$end';
  } else {
    final pStart = snap.reviewTargetParams?.startPage ?? 1;
    final pEnd = snap.reviewTargetParams?.endPage ?? pStart;
    reviewLabel = pStart == pEnd
        ? (isThai ? 'ทบทวนหน้า $pStart' : 'Review Page $pStart')
        : (isThai ? 'ทบทวนหน้า $pStart–$pEnd' : 'Review Pages $pStart–$pEnd');
  }

  return '$reviewLabel • $stepPart • $tallyPart';
}
