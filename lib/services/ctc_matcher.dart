import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/recitation_event.dart';

class AlignmentResult {
  final double score;
  final double recall;
  final double precision;
  final int endIndex;
  final int wordsConsumed;

  const AlignmentResult({
    required this.score,
    required this.recall,
    required this.precision,
    required this.endIndex,
    this.wordsConsumed = 0,
  });
}

class VerseSearchResult {
  final int surah;
  final int ayah;
  final double score;
  final String text;

  const VerseSearchResult({
    required this.surah,
    required this.ayah,
    required this.score,
    required this.text,
  });
}

class AyahRefData {
  final int surah;
  final int ayah;
  final List<String> words;
  final String phonemes;
  final List<int> offsets;
  final List<String> isolated;
  final List<int> tokenIds;
  final int globalStart;
  final int globalEnd;

  const AyahRefData({
    required this.surah,
    required this.ayah,
    required this.words,
    required this.phonemes,
    required this.offsets,
    required this.isolated,
    required this.tokenIds,
    required this.globalStart,
    required this.globalEnd,
  });

  bool isWordStart(int offsetInAyah) => offsets.contains(offsetInAyah);
}

class ReferenceWord {
  final int surah;
  final int ayah;
  final int word;
  final int start;
  final int end;
  final String text;
  final String isolated;

  const ReferenceWord({
    required this.surah,
    required this.ayah,
    required this.word,
    required this.start,
    required this.end,
    required this.text,
    required this.isolated,
  });
}

// --- Tilawa 1.0 Phonetic Model (fuzzy.ts) ---

const int kUnit = 10;
const int kLengthChange = 2;
const int kConfusableCost = 5;
const int kShortVowelCost = 5;
const double kEdit = 9.5367431640625e-7; // 2^-20
const int kMidWordStart = 10;

const Set<String> kMaddLetters = {'ا', 'ۦ', 'ۥ'};
const Set<String> kShortVowels = {'َ', 'ُ', 'ِ'};
const Set<String> kGhunnaRuns = {'ں', '۾'};
const Set<String> kGhunnaDoubled = {'ن', 'م'};

final Set<String> kConfusablePairs = () {
  const pairs = ['هح', 'عء', 'صس', 'ضد', 'طت', 'قك', 'ذز', 'ثس'];
  final set = <String>{};
  for (final p in pairs) {
    set.add(p);
    set.add('${p[1]}${p[0]}');
  }
  return set;
}();

final Set<String> kHeld = {...kMaddLetters, ...kGhunnaRuns};

int subCost(String ref, String obs) {
  if (ref == obs) return 0;
  if (kConfusablePairs.contains('$ref$obs')) return kConfusableCost;
  if (kShortVowels.contains(ref) && kShortVowels.contains(obs)) return kShortVowelCost;
  return kUnit;
}

bool isLengthening(String p, int run) {
  if (kMaddLetters.contains(p) || kGhunnaRuns.contains(p)) return run >= 2;
  if (kGhunnaDoubled.contains(p)) return run >= 3;
  return false;
}

List<String> collapseHeld(List<String> tokens) {
  final out = <String>[];
  for (int i = 0; i < tokens.length;) {
    int j = i;
    while (j < tokens.length && tokens[j] == tokens[i]) {
      j++;
    }
    final run = j - i;
    final token = tokens[i];
    final keep = kHeld.contains(token)
        ? 1
        : (kGhunnaDoubled.contains(token) && run >= 3 ? 2 : run);
    for (int k = 0; k < keep; k++) {
      out.add(token);
    }
    i = j;
  }
  return out;
}

int indelCost(String p, bool lengthening) {
  if (lengthening) return kLengthChange;
  if (kShortVowels.contains(p)) return kShortVowelCost;
  return kUnit;
}

int runAt(String s, int k) {
  final target = s[k];
  int a = k;
  int b = k;
  while (a > 0 && s[a - 1] == target) {
    a--;
  }
  while (b + 1 < s.length && s[b + 1] == target) {
    b++;
  }
  return b - a + 1;
}

int insertionCost(String ref, int at, String p, [int? end]) {
  final refEnd = end ?? ref.length;
  final before = (at > 0 && ref[at - 1] == p) ? runAt(ref, at - 1) : 0;
  final after = (at < refEnd && ref[at] == p) ? runAt(ref, at) : 0;
  final maxRun = math.max(before, after) + 1;
  return indelCost(p, isLengthening(p, maxRun));
}

int deletionCost(String ref, int at) {
  final p = ref[at];
  return indelCost(p, isLengthening(p, runAt(ref, at)));
}

class AlignmentOp {
  final String op;
  final String? ref;
  final String? obs;
  int refAt;
  final int? obsAt;

  AlignmentOp({
    required this.op,
    this.ref,
    this.obs,
    required this.refAt,
    this.obsAt,
  });
}

class SpanAlignment {
  final int start;
  final int end;
  final int cost;
  final double per;
  final List<AlignmentOp> path;

  SpanAlignment({
    required this.start,
    required this.end,
    required this.cost,
    required this.per,
    required this.path,
  });
}

SpanAlignment? alignSubstring(
  String ref,
  int lo,
  int hi,
  String obs,
  bool Function(int offset) isStart, {
  List<double>? conf,
  bool strictStart = false,
}) {
  final n = hi - lo;
  final m = obs.length;
  if (m == 0 || n < 0) return null;
  final w = m + 1;
  final d = Float64List((n + 1) * w);

  int at(int i, int j) => i * w + j;
  String r(int i) => ref[lo + i - 1];

  double startCost(int i) => isStart(lo + i)
      ? 0.0
      : (strictStart ? double.infinity : kMidWordStart.toDouble());

  final skip = Float64List(m + 1);
  skip.fillRange(0, m + 1, double.infinity);
  skip[0] = 0.0;
  if (conf != null) {
    for (int j = 1; j <= m; j++) {
      skip[j] = skip[j - 1] + (kUnit * conf[j - 1]).round() + kEdit;
    }
  }

  for (int i = 0; i <= n; i++) {
    final start = startCost(i);
    final row = i * w;
    d[row] = start;
    final del = i > 0 ? deletionCost(ref, lo + i - 1) + kEdit : double.infinity;
    for (int j = 1; j <= m; j++) {
      final ins = insertionCost(ref, lo + i, obs[j - 1], hi) + kEdit;
      double best = math.min(d[row + j - 1] + ins, start + skip[j]);
      if (i > 0) {
        final sub = (r(i) == obs[j - 1] ? 0.0 : subCost(r(i), obs[j - 1]) + kEdit);
        best = math.min(best, math.min(d[row - w + j - 1] + sub, d[row - w + j] + del));
      }
      d[row + j] = best;
    }
  }

  int endI = -1;
  for (int i = 0; i <= n; i++) {
    if (endI == -1 || d[at(i, m)] < d[at(endI, m)]) {
      endI = i;
    }
  }
  if (endI == -1 || d[at(endI, m)] >= double.infinity) return null;

  final ops = <AlignmentOp>[];
  int i = endI;
  int j = m;
  while (j > 0) {
    final here = d[at(i, j)];
    if ((here - (startCost(i) + skip[j])).abs() < 1e-9) {
      for (int k = j; k > 0; k--) {
        ops.add(AlignmentOp(op: 'ins', obs: obs[k - 1], refAt: -1, obsAt: k - 1));
      }
      break;
    }
    final subVal = i > 0 && j > 0 ? (r(i) == obs[j - 1] ? 0.0 : subCost(r(i), obs[j - 1]) + kEdit) : double.infinity;
    final delVal = i > 0 ? deletionCost(ref, lo + i - 1) + kEdit : double.infinity;
    if (i > 0 && j > 0 && (here - (d[at(i - 1, j - 1)] + subVal)).abs() < 1e-9) {
      ops.add(r(i) == obs[j - 1]
          ? AlignmentOp(op: 'match', ref: r(i), refAt: i - 1, obsAt: j - 1)
          : AlignmentOp(op: 'sub', ref: r(i), obs: obs[j - 1], refAt: i - 1, obsAt: j - 1));
      i--;
      j--;
    } else if (i > 0 && (here - (d[at(i - 1, j)] + delVal)).abs() < 1e-9) {
      ops.add(AlignmentOp(op: 'del', ref: r(i), refAt: i - 1));
      i--;
    } else {
      ops.add(AlignmentOp(op: 'ins', obs: obs[j - 1], refAt: -1, obsAt: j - 1));
      j--;
    }
  }
  final reversedOps = ops.reversed.toList();
  for (final o in reversedOps) {
    if (o.op != 'ins') o.refAt -= i;
  }

  final length = endI - i;
  final edits = reversedOps.where((o) => o.op != 'match').length;
  final per = length > 0 ? edits / length : (edits > 0 ? double.infinity : 0.0);
  return SpanAlignment(
    start: lo + i,
    end: lo + endI,
    cost: d[at(endI, m)].floor(),
    per: per,
    path: reversedOps,
  );
}

// --- CtcMatcher Implementation ---

class CtcMatcher {
  static const String tokens = "ءبتثجحخدذرزسشصضطظعغفقكلمنهوياۦۥَُِ۪ـٲڇں۾ؙۜ";
  static const int blankToken = 0;
  static const int gramSize = 4;

  static final Map<String, int> tokenToId = {
    for (int i = 0; i < tokens.length; i++) tokens[i]: i + 1,
  };
  static final Map<int, String> idToToken = {
    for (int i = 0; i < tokens.length; i++) i + 1: tokens[i],
  };

  final String globalPhonemes;
  final List<ReferenceWord> words;
  final Set<int> wordStarts;
  final Map<String, List<int>> grams;
  final Map<String, AyahRefData> ayahsByKey;
  final Map<int, List<AyahRefData>> ayahsBySurah;
  final String istiadhaPhonemes;
  final String basmalaPhonemes;

  final Map<String, List<int>> ctcTokens;
  final Map<int, String> vocab;
  final Map<String, List<String>> _textVariantsCache = {};

  static final RegExp _diacriticsRegex = RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED]');
  static final RegExp _alifRegex = RegExp(r'[إأآٱ]');
  static final RegExp _whitespaceRegex = RegExp(r'\s+');

  CtcMatcher({
    required this.globalPhonemes,
    required this.words,
    required this.wordStarts,
    required this.grams,
    required this.ayahsByKey,
    required this.ayahsBySurah,
    required this.istiadhaPhonemes,
    required this.basmalaPhonemes,
    required this.ctcTokens,
    required this.vocab,
  });

  /// Factory loader that reads ref-v2.json and phrases-v1.json and builds index in background compute.
  static Future<CtcMatcher> load({
    String refPath = 'assets/models/ref-v2.json',
    String phrasesPath = 'assets/models/phrases-v1.json',
    String? tokensPath,
    String? vocabPath,
  }) async {
    final effectiveRefPath = (tokensPath != null && tokensPath.contains('ref-v2'))
        ? tokensPath
        : refPath;

    String refJsonStr;
    String phrasesJsonStr;

    try {
      refJsonStr = await rootBundle.loadString(effectiveRefPath);
    } catch (_) {
      final refFile = File(effectiveRefPath);
      refJsonStr = await refFile.readAsString();
    }

    try {
      phrasesJsonStr = await rootBundle.loadString(phrasesPath);
    } catch (_) {
      final phrasesFile = File(phrasesPath);
      if (await phrasesFile.exists()) {
        phrasesJsonStr = await phrasesFile.readAsString();
      } else {
        phrasesJsonStr = '{}';
      }
    }

    return await compute(_parseMatcherData, (refJsonStr, phrasesJsonStr));
  }

  static CtcMatcher _parseMatcherData((String, String) inputs) {
    final (refJsonStr, phrasesJsonStr) = inputs;
    final rawRef = jsonDecode(refJsonStr) as Map<String, dynamic>;
    final rawAyahs = rawRef['ayahs'] as List;

    String istiadha = 'ءَعُۥۥذُبِللَااهِمِنَششَيطَاانِررَجِۦۦم';
    String basmala = 'بِسمِللَااهِررَحمَاانِررَحِۦۦم';

    try {
      final rawPhrases = jsonDecode(phrasesJsonStr) as Map<String, dynamic>;
      if (rawPhrases['phrases'] is List) {
        for (final p in rawPhrases['phrases'] as List) {
          if (p is Map) {
            if (p['name'] == 'istiadha' && p['p'] is String) istiadha = p['p'] as String;
            if (p['name'] == 'basmala' && p['p'] is String) basmala = p['p'] as String;
          }
        }
      }
    } catch (_) {}

    final ayahsByKey = <String, AyahRefData>{};
    final ayahsBySurah = <int, List<AyahRefData>>{};
    final words = <ReferenceWord>[];
    final wordStarts = <int>{};
    final ctcTokens = <String, List<int>>{};
    final buffer = StringBuffer();

    for (final item in rawAyahs) {
      final m = item as Map<String, dynamic>;
      final s = m['s'] as int;
      final a = m['a'] as int;
      final wList = (m['w'] as List).cast<String>();
      final p = m['p'] as String;
      final oList = (m['o'] as List).map((e) => (e as num).toInt()).toList();
      final isoList = (m['iso'] as List).cast<String>();

      final tokenIds = <int>[];
      for (int i = 0; i < p.length; i++) {
        final id = tokenToId[p[i]];
        if (id != null) tokenIds.add(id);
      }

      final globalStart = buffer.length;
      for (int i = 0; i < wList.length; i++) {
        final start = globalStart + oList[i];
        final end = globalStart + (i + 1 < oList.length ? oList[i + 1] : p.length);
        words.add(ReferenceWord(
          surah: s,
          ayah: a,
          word: i + 1,
          start: start,
          end: end,
          text: wList[i],
          isolated: i < isoList.length ? isoList[i] : '',
        ));
        wordStarts.add(start);
      }
      buffer.write(p);
      final globalEnd = buffer.length;

      final data = AyahRefData(
        surah: s,
        ayah: a,
        words: wList,
        phonemes: p,
        offsets: oList,
        isolated: isoList,
        tokenIds: tokenIds,
        globalStart: globalStart,
        globalEnd: globalEnd,
      );

      ayahsByKey['$s:$a'] = data;
      (ayahsBySurah[s] ??= []).add(data);
      ctcTokens['$s:$a:$a'] = tokenIds;
    }

    final globalPhonemes = buffer.toString();
    final grams = <String, List<int>>{};
    for (int i = 0; i + gramSize <= globalPhonemes.length; i++) {
      final g = globalPhonemes.substring(i, i + gramSize);
      (grams[g] ??= <int>[]).add(i);
    }

    final vocab = <int, String>{0: '<blank>'};
    for (int i = 0; i < tokens.length; i++) {
      vocab[i + 1] = tokens[i];
    }

    return CtcMatcher(
      globalPhonemes: globalPhonemes,
      words: words,
      wordStarts: wordStarts,
      grams: grams,
      ayahsByKey: ayahsByKey,
      ayahsBySurah: ayahsBySurah,
      istiadhaPhonemes: istiadha,
      basmalaPhonemes: basmala,
      ctcTokens: ctcTokens,
      vocab: vocab,
    );
  }

  /// Greedy CTC decoding: argmax over vocab dimension, collapse repeats, drop blank (0).
  List<int> greedyDecode(
    List<List<double>> logProbs, {
    int blankIndex = 0,
  }) {
    final tokens = <int>[];
    int prevToken = -1;

    for (final frame in logProbs) {
      int maxIdx = 0;
      double maxVal = frame.isNotEmpty ? frame[0] : -double.infinity;
      for (int i = 1; i < frame.length; i++) {
        if (frame[i] > maxVal) {
          maxVal = frame[i];
          maxIdx = i;
        }
      }

      if (maxIdx != blankIndex && maxIdx != prevToken) {
        tokens.add(maxIdx);
      }
      prevToken = maxIdx;
    }

    return tokens;
  }

  /// Converts token IDs 1..42 to phoneme string.
  String tokensToPhonemes(List<int> tokenIds) {
    final buffer = StringBuffer();
    for (final id in tokenIds) {
      if (id > 0 && id <= tokens.length) {
        buffer.write(tokens[id - 1]);
      }
    }
    return buffer.toString();
  }

  /// Converts CTC token IDs into string representation.
  String tokensToText(List<int> tokenIds) {
    return tokensToPhonemes(tokenIds);
  }

  /// Converts CTC token IDs into clean, readable Arabic text for UI display.
  String tokensToReadableText(List<int> tokenIds) {
    if (tokenIds.isEmpty) return '';
    final raw = tokensToPhonemes(tokenIds);
    if (raw.isEmpty) return '';

    final buffer = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      final ch = raw[i];
      switch (ch) {
        case 'ۦ': // small yaa
          buffer.write('ي');
          break;
        case 'ۥ': // small waw
          buffer.write('و');
          break;
        case 'ں': // noon ghunna
          buffer.write('ن');
          break;
        case '۾': // iqlab meem
          buffer.write('م');
          break;
        case 'ٲ': // alif
          buffer.write('ا');
          break;
        case 'ڇ': // che -> jeem
          buffer.write('ج');
          break;
        case 'ـ': // tatweel
        case '۪': // imala
        case 'ۜ': // small seen
        case 'ؙ': // small rounded zero
          break;
        default:
          buffer.write(ch);
          break;
      }
    }
    return buffer.toString().trim();
  }

  /// Normalizes Arabic text by removing tashkeel/diacritics and normalizing alifs/ya/taa marbutah.
  static String normalizeArabic(String text) {
    return text
        .replaceAll(_diacriticsRegex, '')
        .replaceAll(_alifRegex, 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll(_whitespaceRegex, ' ')
        .trim();
  }

  /// Retrieves base target phoneme token IDs for Surah [surah], Ayah [ayah].
  List<int>? getTargetTokens(int surah, int ayah) {
    return ayahsByKey['$surah:$ayah']?.tokenIds;
  }

  /// Retrieves target token variants.
  List<List<int>> getTargetVariants(int surah, int ayah) {
    final base = getTargetTokens(surah, ayah);
    if (base == null || base.isEmpty) return const [];
    return [base];
  }

  /// Retrieves normalized target Arabic text variants for Surah [surah], Ayah [ayah].
  List<String> getTargetTextVariants(int surah, int ayah) {
    final cacheKey = '$surah:$ayah';
    final cached = _textVariantsCache[cacheKey];
    if (cached != null) return cached;

    final data = ayahsByKey[cacheKey];
    if (data == null) return const [];

    final fullText = data.words.join(' ');
    final norm = normalizeArabic(fullText);
    final texts = <String>[norm];

    if (ayah == 1 && surah != 1 && surah != 9) {
      const basmalahText = 'بسم الله الرحمن الرحيم';
      final withBasmalah = normalizeArabic('$basmalahText $fullText');
      if (!texts.contains(withBasmalah)) {
        texts.add(withBasmalah);
      }
    }

    _textVariantsCache[cacheKey] = texts;
    return texts;
  }

  /// Word finding by global phoneme offset.
  int wordAt(int offset) {
    int lo = 0;
    int hi = words.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (words[mid].start <= offset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  AyahRefData? findAyahAtOffset(int offset) {
    final wIdx = wordAt(offset);
    final w = words[wIdx];
    return ayahsByKey['${w.surah}:${w.ayah}'];
  }

  /// Longest Common Subsequence on strings using two-row dynamic programming.
  static int longestCommonSubsequenceString(String a, String b) {
    final m = a.length;
    final n = b.length;
    if (m == 0 || n == 0) return 0;

    var prev = List<int>.filled(n + 1, 0);
    var curr = List<int>.filled(n + 1, 0);

    for (int i = 1; i <= m; i++) {
      final aCode = a.codeUnitAt(i - 1);
      for (int j = 1; j <= n; j++) {
        if (aCode == b.codeUnitAt(j - 1)) {
          curr[j] = prev[j - 1] + 1;
        } else {
          curr[j] = curr[j - 1] > prev[j] ? curr[j - 1] : prev[j];
        }
      }
      final temp = prev;
      prev = curr;
      curr = temp;
    }

    return prev[n];
  }

  /// Sequentially checks if candidate words reach and match the end of target words.
  static (bool, int) checkReachesEndOfVerseWithEnd(
    List<String> candWords,
    List<String> targetWords, {
    RecitationSensitivity sensitivity = RecitationSensitivity.balanced,
    bool requireLastWord = true,
  }) {
    if (targetWords.isEmpty) return (true, 0);
    if (candWords.isEmpty) return (false, 0);

    final matched = <int>[];
    int tIdx = 0;
    int lastCandIdx = 0;

    final double wordSimilarityCutoff;
    switch (sensitivity) {
      case RecitationSensitivity.quickRecap:
        wordSimilarityCutoff = 0.55;
        break;
      case RecitationSensitivity.strict:
        wordSimilarityCutoff = 0.72;
        break;
      case RecitationSensitivity.balanced:
        wordSimilarityCutoff = 0.65;
        break;
    }

    for (int cIdx = 0; cIdx < candWords.length && tIdx < targetWords.length; cIdx++) {
      final cw = candWords[cIdx];
      int bestMatchT = -1;
      for (int lookAhead = 0; lookAhead <= 2 && (tIdx + lookAhead) < targetWords.length; lookAhead++) {
        final tw = targetWords[tIdx + lookAhead];
        final l = longestCommonSubsequenceString(cw, tw);
        final maxLen = cw.length > tw.length ? cw.length : tw.length;
        if (maxLen > 0 && (l / maxLen) >= wordSimilarityCutoff) {
          bestMatchT = tIdx + lookAhead;
          break;
        }
      }

      if (bestMatchT != -1) {
        matched.add(bestMatchT);
        tIdx = bestMatchT + 1;
        lastCandIdx = cIdx;
      }
    }

    const int longVerseWordThreshold = 6;
    final int wordCount = targetWords.length;
    final bool isLongVerse = wordCount >= longVerseWordThreshold;
    final bool lastWordMatched = matched.contains(wordCount - 1);
    final int lastMatchedTarget = matched.isEmpty ? -1 : matched.last;

    final bool missingLastWordAllowed =
        !requireLastWord && isLongVerse && lastMatchedTarget >= wordCount - 2;

    final double wordRecall = matched.length / wordCount;

    final double requiredWordRecall;
    switch (sensitivity) {
      case RecitationSensitivity.quickRecap:
        requiredWordRecall = isLongVerse
            ? 0.70
            : (wordCount <= 2 ? 0.40 : (wordCount <= 4 ? 0.50 : 0.60));
        break;
      case RecitationSensitivity.strict:
        requiredWordRecall = isLongVerse
            ? 0.95
            : (wordCount <= 2 ? 0.60 : (wordCount <= 4 ? 0.75 : 0.85));
        break;
      case RecitationSensitivity.balanced:
        requiredWordRecall = isLongVerse
            ? 0.85
            : (wordCount <= 2 ? 0.50 : (wordCount <= 4 ? 0.65 : 0.75));
        break;
    }

    final bool reachedEnd = lastWordMatched || missingLastWordAllowed;
    final bool reached = reachedEnd && (wordRecall >= requiredWordRecall);

    final int consumedWords =
        (!lastWordMatched && missingLastWordAllowed) ? candWords.length : lastCandIdx + 1;

    return (reached, consumedWords);
  }

  static bool checkReachesEndOfVerse(
    List<String> candWords,
    List<String> targetWords, {
    RecitationSensitivity sensitivity = RecitationSensitivity.balanced,
    bool requireLastWord = true,
  }) {
    return checkReachesEndOfVerseWithEnd(
      candWords,
      targetWords,
      sensitivity: sensitivity,
      requireLastWord: requireLastWord,
    ).$1;
  }

  AlignmentResult findBestTextAlignment(
    String candidateRaw,
    String targetNormalized, {
    double recallThreshold = 0.82,
    double scoreThreshold = 0.70,
    RecitationSensitivity sensitivity = RecitationSensitivity.balanced,
    bool requireLastWord = true,
  }) {
    final candNorm = normalizeArabic(candidateRaw);
    if (candNorm.isEmpty || targetNormalized.isEmpty) {
      return const AlignmentResult(score: 0.0, recall: 0.0, precision: 0.0, endIndex: 0);
    }

    final candWords = candNorm.split(' ').where((w) => w.isNotEmpty).toList();
    final targetWords = targetNormalized.split(' ').where((w) => w.isNotEmpty).toList();
    if (candWords.isEmpty || targetWords.isEmpty) {
      return const AlignmentResult(score: 0.0, recall: 0.0, precision: 0.0, endIndex: 0);
    }

    final candClean = candWords.join();
    final targetClean = targetWords.join();
    final tLen = targetClean.length;

    final lFull = longestCommonSubsequenceString(candClean, targetClean);
    final recFull = lFull / tLen;
    final precFull = candClean.isNotEmpty ? lFull / candClean.length : 0.0;
    final f1Full = (recFull + precFull) > 0 ? (2 * recFull * precFull) / (recFull + precFull) : 0.0;

    final (reachesEndFull, consumedWordsFull) = checkReachesEndOfVerseWithEnd(
      candWords,
      targetWords,
      sensitivity: sensitivity,
      requireLastWord: requireLastWord,
    );

    if (recFull >= recallThreshold && f1Full >= scoreThreshold && reachesEndFull) {
      return AlignmentResult(
        score: f1Full,
        recall: recFull,
        precision: precFull,
        endIndex: candidateRaw.length,
        wordsConsumed: consumedWordsFull > 0 ? consumedWordsFull : candWords.length,
      );
    }

    double bestScore = 0.0;
    double bestRecall = 0.0;
    double bestPrecision = 0.0;
    int bestEnd = candidateRaw.length;
    int bestWordsConsumed = candWords.length;

    if (candWords.length > targetWords.length) {
      final numWords = candWords.length;
      final tNum = targetWords.length;
      final minStart = math.max(0, numWords - (tNum + 5));

      for (int startW = minStart; startW < numWords; startW++) {
        for (int endW = startW + math.max(1, tNum - 2);
            endW <= math.min(numWords, startW + tNum + 4);
            endW++) {
          final subWords = candWords.sublist(startW, endW);
          final subClean = subWords.join();
          if (subClean.isEmpty) continue;

          final (reachesEndSub, consumedInSub) = checkReachesEndOfVerseWithEnd(
            subWords,
            targetWords,
            sensitivity: sensitivity,
            requireLastWord: requireLastWord,
          );
          if (!reachesEndSub) continue;

          final l = longestCommonSubsequenceString(subClean, targetClean);
          final rec = l / tLen;
          final prec = l / subClean.length;
          final f1 = (rec + prec) > 0 ? (2 * rec * prec) / (rec + prec) : 0.0;

          if (rec >= recallThreshold && f1 > bestScore && f1 >= scoreThreshold) {
            bestScore = f1;
            bestRecall = rec;
            bestPrecision = prec;
            bestEnd = candidateRaw.length;
            bestWordsConsumed = startW + (consumedInSub > 0 ? consumedInSub : subWords.length);
          }
        }
      }
    }

    return AlignmentResult(
      score: bestScore,
      recall: bestRecall,
      precision: bestPrecision,
      endIndex: bestEnd,
      wordsConsumed: bestWordsConsumed,
    );
  }

  (double recallThreshold, double scoreThreshold) getAdaptiveThresholds(
    int surah,
    int ayah, {
    RecitationSensitivity sensitivity = RecitationSensitivity.balanced,
  }) {
    final texts = getTargetTextVariants(surah, ayah);
    final wordCount = texts.isNotEmpty
        ? texts.first.split(' ').where((w) => w.isNotEmpty).length
        : 10;
    final tokens = getTargetTokens(surah, ayah);
    final tokenCount = tokens?.length ?? 40;

    final bool isShort = texts.isNotEmpty ? wordCount <= 2 : tokenCount <= 8;
    final bool isMedium = texts.isNotEmpty ? wordCount <= 4 : tokenCount <= 22;

    switch (sensitivity) {
      case RecitationSensitivity.quickRecap:
        if (isShort) {
          return (0.62, 0.58);
        } else if (isMedium) {
          return (0.68, 0.62);
        } else {
          return (0.74, 0.64);
        }
      case RecitationSensitivity.strict:
        if (isShort) {
          return (0.78, 0.72);
        } else if (isMedium) {
          return (0.84, 0.75);
        } else {
          return (0.88, 0.78);
        }
      case RecitationSensitivity.balanced:
        if (isShort) {
          return (0.70, 0.65);
        } else if (isMedium) {
          return (0.76, 0.68);
        } else {
          return (0.82, 0.70);
        }
    }
  }

  /// Dedicated ayah-level phonetic alignment for Hifz recitation.
  /// Aligning reference [data.phonemes] against spoken stream [obs].
  /// Requires genuine coverage of the verse and returns the exact number of tokens consumed in [obs].
  AlignmentResult? alignAyahToObs(
    AyahRefData data,
    String obs, {
    required bool requireLastWord,
    double effectiveRecall = 0.70,
    double effectiveScore = 0.70,
  }) {
    final ref = data.phonemes;
    final n = ref.length;
    final m = obs.length;
    if (n == 0 || m == 0) return null;

    final w = m + 1;
    final d = Float64List((n + 1) * w);
    final startJ = Int32List((n + 1) * w);
    final op = Int8List((n + 1) * w);

    int at(int i, int j) => i * w + j;

    // Row 0: free start in obs
    for (int j = 0; j <= m; j++) {
      d[j] = 0.0;
      startJ[j] = j;
      op[j] = 0;
    }

    // Column 0: missing leading phonemes of the ayah MUST pay deletion cost + kEdit
    for (int i = 1; i <= n; i++) {
      d[i * w] = d[(i - 1) * w] + deletionCost(ref, i - 1) + kEdit;
      startJ[i * w] = 0;
      op[i * w] = 1;
    }

    // DP Fill
    for (int i = 1; i <= n; i++) {
      final rChar = ref[i - 1];
      final delCost = deletionCost(ref, i - 1) + kEdit;
      final row = i * w;
      final prevRow = (i - 1) * w;

      for (int j = 1; j <= m; j++) {
        final oChar = obs[j - 1];
        final insCost = insertionCost(ref, i, oChar, n) + kEdit;
        final sub = (rChar == oChar ? 0.0 : subCost(rChar, oChar) + kEdit);

        // 1. match/sub from (i-1, j-1)
        double best = d[prevRow + j - 1] + sub;
        int bestFrom = prevRow + j - 1;
        int bestOp = 0;

        // 2. deletion from (i-1, j)
        final delVal = d[prevRow + j] + delCost;
        if (delVal < best) {
          best = delVal;
          bestFrom = prevRow + j;
          bestOp = 1;
        }

        // 3. insertion from (i, j-1)
        final insVal = d[row + j - 1] + insCost;
        if (insVal < best) {
          best = insVal;
          bestFrom = row + j - 1;
          bestOp = 2;
        }

        d[row + j] = best;
        startJ[row + j] = startJ[bestFrom];
        op[row + j] = bestOp;
      }
    }

    // Determine the required ending range [minEndI .. n] in ref:
    final lastWordStart = data.offsets.isNotEmpty ? data.offsets.last : 0;
    final int lastWordMinEnd = lastWordStart + math.max<int>(1, ((n - lastWordStart) * 0.75).ceil());

    final int minEndI;
    if (requireLastWord || data.words.length < 6) {
      minEndI = lastWordMinEnd;
    } else {
      // For long verses (!requireLastWord && data.words.length >= 6):
      // allow reaching the start of the last word (end of penultimate word)
      minEndI = lastWordStart;
    }

    double bestF1 = 0.0;
    double bestRecall = 0.0;
    double bestAccuracy = 0.0;
    int bestEndI = -1;
    int bestEndJ = -1;

    for (int endI = minEndI; endI <= n; endI++) {
      for (int endJ = 1; endJ <= m; endJ++) {
        // Strict End-of-Verse Tail Gate: cell MUST be a match/sub transition, never a vertical deletion
        if (op[at(endI, endJ)] != 0) continue;

        final obsStart = startJ[at(endI, endJ)];
        final obsSpan = endJ - obsStart;
        if (obsSpan < (minEndI * 0.55).ceil()) continue;

        final weightedEdits = d[at(endI, endJ)] / kUnit;
        final accuracy = obsSpan > 0
            ? math.max(0.0, 1.0 - (weightedEdits / math.max(endI, obsSpan)))
            : 0.0;
        final recall = math.max(0.0, (endI - weightedEdits) / math.max(1, endI));
        final f1 = (recall + accuracy) > 0 ? (2 * recall * accuracy) / (recall + accuracy) : 0.0;

        if (recall < effectiveRecall || f1 < effectiveScore) continue;

        // Backtrack to verify word matching across the ayah and track half-way split
        int currI = endI;
        int currJ = endJ;
        final int? splitRef = data.words.length >= 2
            ? data.offsets[(data.words.length / 2).floor()]
            : null;
        int? splitJ;
        final matchedInWord = List<int>.filled(data.words.length, 0);

        while (currI > 0 && currJ > obsStart) {
          if (splitRef != null && splitJ == null && currI <= splitRef) {
            splitJ = currJ;
          }
          final cellOp = op[at(currI, currJ)];
          if (cellOp == 0) {
            final refIdx = currI - 1;
            final rChar = ref[refIdx];
            final oChar = obs[currJ - 1];
            if (rChar == oChar || subCost(rChar, oChar) <= kConfusableCost) {
              int w = data.offsets.length - 1;
              while (w > 0 && data.offsets[w] > refIdx) {
                w--;
              }
              if (w >= 0 && w < matchedInWord.length) {
                matchedInWord[w]++;
              }
            }
            currI--;
            currJ--;
          } else if (cellOp == 1) {
            currI--;
          } else {
            currJ--;
          }
        }
        if (splitRef != null && splitJ == null && currI <= splitRef) {
          splitJ = currJ;
        }

        // Reject repeated-opening false positives (e.g. repeating words 1-2 of 112:3):
        // if the trailing portion of obs fits the verse's OWN opening words clearly better
        // than it fits the verse's ending half, it is a restart/repeat, not completion.
        if (splitRef != null &&
            splitJ != null &&
            splitRef >= 3 &&
            endI - splitRef >= 3 &&
            splitJ > obsStart &&
            endJ - splitJ >= 4) {
          final double tailEdits = math.max(0.0, (d[at(endI, endJ)] - d[at(splitRef, splitJ)]) / kUnit);
          if (tailEdits >= 0.8) {
            final tailObs = obs.substring(splitJ, endJ);
            final openFit = alignSubstring(
              ref,
              0,
              splitRef,
              tailObs,
              (o) => o == 0,
              strictStart: true,
            );
            if (openFit != null) {
              final double openEdits = openFit.cost / kUnit;
              final double openPer = openEdits / splitRef;
              if (openPer <= 0.15 && openEdits + 0.8 <= tailEdits) {
                continue;
              }
            }
          }
        }

        // Check word-by-word matching
        int matchedWordsCount = 0;
        for (int w = 0; w < data.words.length; w++) {
          final wStart = data.offsets[w];
          final wEnd = (w + 1 < data.offsets.length) ? data.offsets[w + 1] : n;
          final wLen = math.max(1, wEnd - wStart);
          final wordMatchedRatio = matchedInWord[w] / wLen;
          if (wordMatchedRatio >= 0.58) {
            matchedWordsCount++;
          }
        }

        if (matchedWordsCount / data.words.length < effectiveRecall) continue;

        // End-of-verse gate
        final lastW = data.words.length - 1;
        final lastWordLen = math.max(1, n - lastWordStart);
        final lastWordMatchedRatio = matchedInWord[lastW] / lastWordLen;

        if (requireLastWord || data.words.length < 6) {
          if (lastWordMatchedRatio < 0.65 || endI < lastWordMinEnd) {
            continue;
          }
        } else {
          // !requireLastWord && data.words.length >= 6
          final penultW = data.words.length - 2;
          final penultWStart = data.offsets[penultW];
          final penultWEnd = lastWordStart;
          final penultWLen = math.max(1, penultWEnd - penultWStart);
          final penultMatchedRatio = matchedInWord[penultW] / penultWLen;

          if (penultMatchedRatio < 0.65 || endI < lastWordStart) {
            continue;
          }

          // If alignment reaches past penultimate word into last word, allow at most 2 trailing phoneme deletions
          if (endI > lastWordStart && (n - endI) > 2) {
            continue;
          }
        }

        if (f1 > bestF1 || (f1 == bestF1 && endI > bestEndI)) {
          bestF1 = f1;
          bestRecall = recall;
          bestAccuracy = accuracy;
          bestEndI = endI;
          bestEndJ = endJ;
        }
      }
    }

    if (bestEndI == -1 || bestEndJ == -1) return null;

    int consumedWords = data.words.length;
    for (int w = 0; w < data.offsets.length; w++) {
      if (data.offsets[w] >= bestEndI) {
        consumedWords = w;
        break;
      }
    }

    return AlignmentResult(
      score: bestF1,
      recall: bestRecall,
      precision: bestAccuracy,
      endIndex: bestEndJ,
      wordsConsumed: consumedWords > 0 ? consumedWords : data.words.length,
    );
  }

  /// Evaluates alignment for Surah [surah], Ayah [ayah] using Tilawa 1.0 phonetic model & text LCS.
  AlignmentResult evaluateAyahMatch(
    int surah,
    int ayah,
    List<int> candidateTokens, {
    String? candidateText,
    double? recallThreshold,
    double? scoreThreshold,
    RecitationSensitivity sensitivity = RecitationSensitivity.balanced,
    bool requireLastWord = true,
  }) {
    final (adaptiveRecall, adaptiveScore) = getAdaptiveThresholds(
      surah,
      ayah,
      sensitivity: sensitivity,
    );
    final effectiveRecall = recallThreshold ?? adaptiveRecall;
    final effectiveScore = scoreThreshold ?? adaptiveScore;

    final data = ayahsByKey['$surah:$ayah'];
    if (data == null) {
      return const AlignmentResult(score: 0.0, recall: 0.0, precision: 0.0, endIndex: 0);
    }

    double bestScore = 0.0;
    double bestRecall = 0.0;
    double bestPrecision = 0.0;
    int bestEnd = candidateTokens.length;
    int bestWordsConsumed = data.words.length;

    // 1. Evaluate Phonetic Alignment via Tilawa 1.0 alignAyahToObs
    if (candidateTokens.isNotEmpty) {
      final obs = tokensToPhonemes(candidateTokens);
      if (obs.isNotEmpty) {
        final align = alignAyahToObs(
          data,
          obs,
          requireLastWord: requireLastWord,
          effectiveRecall: effectiveRecall,
          effectiveScore: effectiveScore,
        );

        if (align != null) {
          bestScore = align.score;
          bestRecall = align.recall;
          bestPrecision = align.precision;
          bestEnd = align.endIndex;
          bestWordsConsumed = align.wordsConsumed;
        }
      }
    }

    // 2. Evaluate Text Alignment (supports text fallback & unit tests)
    final textVariants = getTargetTextVariants(surah, ayah);
    final candText = candidateText ?? (data.words.isNotEmpty ? data.words.join(' ') : '');
    if (candidateText != null && candidateText.isNotEmpty) {
      for (final textVariant in textVariants) {
        final align = findBestTextAlignment(
          candText,
          textVariant,
          recallThreshold: effectiveRecall,
          scoreThreshold: effectiveScore,
          sensitivity: sensitivity,
          requireLastWord: requireLastWord,
        );
        if (align.recall >= effectiveRecall && align.score > bestScore) {
          bestScore = align.score;
          bestRecall = align.recall;
          bestPrecision = align.precision;
          if (bestEnd == 0) bestEnd = candidateTokens.length;
          bestWordsConsumed = align.wordsConsumed;
        }
      }
    }

    return AlignmentResult(
      score: bestScore,
      recall: bestRecall,
      precision: bestPrecision,
      endIndex: bestEnd,
      wordsConsumed: bestWordsConsumed,
    );
  }

  /// Detects if the tail of [obs] cleanly starts [nextAyah]'s opening words, returning the
  /// character/token index in [obs] where [nextAyah] begins, or null if not found.
  /// Prevents [expectedAyah] from borrowing [nextAyah]'s opening phonemes to pass prematurely.
  int? _findNextAyahOpeningCut({
    required int surah,
    required int expectedAyah,
    required int nextAyah,
    required String obs,
  }) {
    final expData = ayahsByKey['$surah:$expectedAyah'];
    final nextData = ayahsByKey['$surah:$nextAyah'];
    if (expData == null || nextData == null || obs.length < 10) return null;

    // Build nextAyah opening slice: prefer first 2 words (or 1st word if >= 6 phonemes)
    final int openEnd;
    if (nextData.offsets.length >= 3) {
      openEnd = nextData.offsets[2];
    } else if (nextData.offsets.length >= 2 && nextData.offsets[1] >= 6) {
      openEnd = nextData.offsets[1];
    } else {
      openEnd = nextData.phonemes.length;
    }
    final openingSlice = nextData.phonemes.substring(0, math.min(openEnd, nextData.phonemes.length));
    if (openingSlice.length < 5) return null;

    // Also try 1-word opening slice if first word alone is long and distinctive (>= 6 phonemes),
    // e.g. user stopped expectedAyah 1 word short and started Allahu / first word of next verse
    final slices = <String>[openingSlice];
    if (nextData.offsets.length >= 2 && nextData.offsets[1] >= 6 && nextData.offsets[1] < openEnd) {
      slices.add(nextData.phonemes.substring(0, nextData.offsets[1]));
    }

    final int minSearchStart = math.max(3, (obs.length * 0.25).floor());
    if (minSearchStart >= obs.length - 4) return null;

    int? earliestCut;
    for (final slice in slices) {
      if (expData.phonemes.endsWith(slice)) continue;
      final fit = alignSubstring(
        obs,
        minSearchStart,
        obs.length,
        slice,
        (o) => true,
      );
      if (fit == null || fit.per > 0.16) continue;
      if (fit.end < obs.length - 2) {
        // Check if the remainder after fit.end continues matching nextAyah sequentially
        final tailObs = obs.substring(fit.start);
        final prefixMaxEnd = math.min(nextData.phonemes.length, tailObs.length + 6);
        final contFit = alignSubstring(
          nextData.phonemes,
          0,
          prefixMaxEnd,
          tailObs,
          (o) => o == 0,
          strictStart: true,
        );
        if (contFit == null || contFit.per > 0.20) continue;
      }
      if (earliestCut == null || fit.start < earliestCut) {
        earliestCut = fit.start;
      }
    }

    return earliestCut;
  }

  /// Checks whether [candidateTokens] begins making genuine progress on [expectedAyah]'s
  /// opening words (used to distinguish slow recitation from off-passage ambient chatter).
  bool hasPrefixProgress({
    required int surah,
    required int expectedAyah,
    required List<int> candidateTokens,
  }) {
    final data = ayahsByKey['$surah:$expectedAyah'];
    if (data == null || candidateTokens.length < 4) return false;
    final obs = tokensToPhonemes(candidateTokens);
    if (obs.length < 4) return false;

    final int openEnd = data.offsets.length >= 3
        ? data.offsets[2]
        : math.min(data.phonemes.length, 14);
    final prefix = data.phonemes.substring(0, math.min(openEnd, data.phonemes.length));
    if (prefix.length < 4) return true;

    final fit = alignSubstring(obs, 0, obs.length, prefix, (o) => true);
    return fit != null && fit.per <= 0.25;
  }

  /// If [candidateTokens] contains old junk/abandoned attempt followed by a clean restart of
  /// [expectedAyah]'s first 2 words near the tail, returns the start index of the restart; else null.
  int? findExpectedAyahRestartIndex({
    required int surah,
    required int expectedAyah,
    required List<int> candidateTokens,
  }) {
    final data = ayahsByKey['$surah:$expectedAyah'];
    if (data == null || data.words.length < 2 || candidateTokens.length < 12) return null;
    final obs = tokensToPhonemes(candidateTokens);
    final int openEnd = data.offsets.length >= 3
        ? data.offsets[2]
        : (data.offsets.length >= 2 ? data.offsets[1] : data.phonemes.length);
    final prefix = data.phonemes.substring(0, math.min(openEnd, data.phonemes.length));
    if (prefix.length < 6 || obs.length < prefix.length + 6) return null;

    final int searchFrom = (obs.length * 0.35).floor();
    final fit = alignSubstring(obs, searchFrom, obs.length, prefix, (o) => true);
    if (fit != null && fit.per <= 0.14 && fit.end >= obs.length - 3 && fit.start > 0) {
      return fit.start;
    }
    return null;
  }

  /// Matches [candidateTokens] / [candidateText] against a sliding window [expectedAyah .. expectedAyah + windowAhead].
  RecitationMatchResult? matchSlidingWindow({
    required int surah,
    required int expectedAyah,
    required List<int> candidateTokens,
    String? candidateText,
    int windowAhead = 2,
    int windowBehind = 1,
    int minAyah = 1,
    int maxAyah = 286,
    double? recallThreshold,
    double? scoreThreshold,
    RecitationSensitivity sensitivity = RecitationSensitivity.balanced,
    bool requireLastWord = true,
  }) {
    if (candidateTokens.isEmpty && (candidateText == null || candidateText.isEmpty)) {
      return null;
    }

    // 1. First priority: Check expectedAyah
    final (expRecall, expScore) = getAdaptiveThresholds(
      surah,
      expectedAyah,
      sensitivity: sensitivity,
    );
    final effectiveExpRecall = recallThreshold ?? expRecall;
    final effectiveExpScore = scoreThreshold ?? expScore;

    // Prevent expectedAyah from absorbing tokens belonging to expectedAyah + 1's opening:
    // if next ayah's opening appears at the tail of candidateTokens, trim candidateTokens
    // before nextAyah and require expectedAyah's last word to have actually completed there.
    int? nextOpeningCut;
    if (candidateTokens.isNotEmpty && expectedAyah + 1 <= maxAyah) {
      final fullObs = tokensToPhonemes(candidateTokens);
      nextOpeningCut = _findNextAyahOpeningCut(
        surah: surah,
        expectedAyah: expectedAyah,
        nextAyah: expectedAyah + 1,
        obs: fullObs,
      );
    }

    final List<int> expTokens = (nextOpeningCut != null && nextOpeningCut > 0)
        ? candidateTokens.sublist(0, math.min(nextOpeningCut, candidateTokens.length))
        : candidateTokens;
    final bool expRequireLastWord = nextOpeningCut != null ? true : requireLastWord;

    final expectedAlign = evaluateAyahMatch(
      surah,
      expectedAyah,
      expTokens,
      candidateText: nextOpeningCut != null ? null : candidateText,
      recallThreshold: effectiveExpRecall,
      scoreThreshold: effectiveExpScore,
      sensitivity: sensitivity,
      requireLastWord: expRequireLastWord,
    );

    if (expectedAlign.recall >= effectiveExpRecall && expectedAlign.score >= effectiveExpScore) {
      final data = ayahsByKey['$surah:$expectedAyah'];
      final wordsText = data != null ? data.words.join(' ') : candidateText;
      return RecitationMatchResult(
        surah: surah,
        expectedAyah: expectedAyah,
        detectedAyah: expectedAyah,
        confidence: expectedAlign.score,
        isSkip: false,
        matchedTokens: candidateTokens.sublist(
          0,
          math.min(expectedAlign.endIndex, candidateTokens.length),
        ),
        tokensConsumed: expectedAlign.endIndex,
        wordsConsumed: expectedAlign.wordsConsumed,
        decodedText: wordsText,
      );
    }

    // 2. Second priority: Check previous verse (isti'naf)
    if (windowBehind > 0) {
      final lowerLimit = math.max(minAyah, expectedAyah - windowBehind);
      for (int prevAyah = expectedAyah - 1; prevAyah >= lowerLimit; prevAyah--) {
        final (prevRecall, prevScore) = getAdaptiveThresholds(
          surah,
          prevAyah,
          sensitivity: sensitivity,
        );
        final effectivePrevRecall = recallThreshold ?? prevRecall;
        final effectivePrevScore = scoreThreshold ?? prevScore;

        final prevAlign = evaluateAyahMatch(
          surah,
          prevAyah,
          candidateTokens,
          candidateText: candidateText,
          recallThreshold: effectivePrevRecall,
          scoreThreshold: effectivePrevScore,
          sensitivity: sensitivity,
          requireLastWord: requireLastWord,
        );

        if (prevAlign.recall >= effectivePrevRecall && prevAlign.score >= effectivePrevScore) {
          final data = ayahsByKey['$surah:$prevAyah'];
          final wordsText = data != null ? data.words.join(' ') : candidateText;
          return RecitationMatchResult(
            surah: surah,
            expectedAyah: expectedAyah,
            detectedAyah: prevAyah,
            confidence: prevAlign.score,
            isSkip: false,
            matchedTokens: candidateTokens.sublist(
              0,
              math.min(prevAlign.endIndex, candidateTokens.length),
            ),
            tokensConsumed: prevAlign.endIndex,
            wordsConsumed: prevAlign.wordsConsumed,
            decodedText: wordsText,
          );
        }
      }
    }

    // 3. Third priority: Check if user skipped ahead
    final upperLimit = math.min(maxAyah, expectedAyah + windowAhead);
    for (int nextAyah = expectedAyah + 1; nextAyah <= upperLimit; nextAyah++) {
      final (skipRecall, skipScore) = getAdaptiveThresholds(
        surah,
        nextAyah,
        sensitivity: sensitivity,
      );
      final effectiveSkipRecall = recallThreshold ?? skipRecall;
      final effectiveSkipScore = scoreThreshold ?? skipScore;

      final skipAlign = evaluateAyahMatch(
        surah,
        nextAyah,
        candidateTokens,
        candidateText: candidateText,
        recallThreshold: effectiveSkipRecall,
        scoreThreshold: effectiveSkipScore,
        sensitivity: sensitivity,
        requireLastWord: requireLastWord,
      );

      if (skipAlign.recall >= effectiveSkipRecall && skipAlign.score >= effectiveSkipScore) {
        final data = ayahsByKey['$surah:$nextAyah'];
        final wordsText = data != null ? data.words.join(' ') : candidateText;
        return RecitationMatchResult(
          surah: surah,
          expectedAyah: expectedAyah,
          detectedAyah: nextAyah,
          confidence: skipAlign.score,
          isSkip: true,
          matchedTokens: candidateTokens.sublist(
            0,
            math.min(skipAlign.endIndex, candidateTokens.length),
          ),
          tokensConsumed: skipAlign.endIndex,
          wordsConsumed: skipAlign.wordsConsumed,
          decodedText: wordsText,
        );
      }
    }

    return null;
  }

  /// Searches the entire Quran for best matching Ayahs for [candidateTokens]
  /// using the 4-gram phoneme index and Tilawa 1.0 phonetic fuzzy alignment.
  List<VerseSearchResult> searchVerses(
    List<int> candidateTokens, {
    int limit = 5,
    double minScore = 0.35,
  }) {
    if (candidateTokens.isEmpty) return const [];

    String query = tokensToPhonemes(candidateTokens);
    if (query.isEmpty) return const [];

    // Strip leading Istiadha if reciter began with Ta'awwudh
    if (query.length >= istiadhaPhonemes.length ~/ 2) {
      final prefix = alignSubstring(
        query,
        0,
        query.length,
        istiadhaPhonemes,
        (o) => o == 0,
        strictStart: true,
      );
      if (prefix != null && prefix.per <= 0.25 && query.length - prefix.end >= gramSize) {
        query = query.substring(prefix.end);
      }
    }

    // Check Basmala
    String searchSuffix = '';
    if (query.length >= basmalaPhonemes.length ~/ 2) {
      final prefix = alignSubstring(
        query,
        0,
        query.length,
        basmalaPhonemes,
        (o) => o == 0,
        strictStart: true,
      );
      if (prefix != null && prefix.per <= 0.25 && query.length - prefix.end >= gramSize) {
        searchSuffix = query.substring(prefix.end);
      }
    }

    final queriesToSearch = <String>[];
    if (searchSuffix.isNotEmpty) {
      queriesToSearch.add(searchSuffix);
    }
    queriesToSearch.add(query);

    final candidatesByAyah = <String, VerseSearchResult>{};

    for (final q in queriesToSearch) {
      if (q.length < gramSize) {
        // Direct scan for short queries
        for (final entry in ayahsByKey.entries) {
          final data = entry.value;
          final align = alignSubstring(data.phonemes, 0, data.phonemes.length, q, data.isWordStart);
          if (align != null) {
            final score = math.max(0.0, 1.0 - align.per);
            if (score >= minScore) {
              final key = '${data.surah}:${data.ayah}';
              final existing = candidatesByAyah[key];
              if (existing == null || existing.score < score) {
                candidatesByAyah[key] = VerseSearchResult(
                  surah: data.surah,
                  ayah: data.ayah,
                  score: score,
                  text: data.words.join(' '),
                );
              }
            }
          }
        }
        continue;
      }

      // 4-gram voting
      final votes = <int, int>{};
      for (int i = 0; i + gramSize <= q.length; i++) {
        final g = q.substring(i, i + gramSize);
        final hits = grams[g];
        if (hits != null && hits.length <= 500) {
          for (final pos in hits) {
            final diag = math.max(0, pos - i);
            votes[diag] = (votes[diag] ?? 0) + 1;
          }
        }
      }

      if (votes.isEmpty) continue;

      final slack = math.max(4, (q.length * 0.25).ceil());
      final sortedDiags = votes.keys.toList()..sort();
      final prefixVotes = <int>[0];
      for (final d in sortedDiags) {
        prefixVotes.add(prefixVotes.last + votes[d]!);
      }

      int firstAtLeast(int x) {
        int a = 0;
        int b = sortedDiags.length;
        while (a < b) {
          final mid = (a + b) >> 1;
          if (sortedDiags[mid] < x) {
            a = mid + 1;
          } else {
            b = mid;
          }
        }
        return a;
      }

      final windowed = <Map<String, dynamic>>[];
      for (int k = 0; k < sortedDiags.length; k++) {
        final d = sortedDiags[k];
        final a = firstAtLeast(d - slack);
        final b = firstAtLeast(d + slack + 1);
        windowed.add({
          'centre': d,
          'lo': sortedDiags[a],
          'hi': sortedDiags[b - 1],
          'votes': prefixVotes[b] - prefixVotes[a],
        });
      }

      windowed.sort((a, b) => (b['votes'] as int).compareTo(a['votes'] as int));

      final bins = <Map<String, dynamic>>[];
      for (final c in windowed) {
        if (bins.length >= 25) break;
        final centre = c['centre'] as int;
        if (bins.any((b) => ((b['centre'] as int) - centre).abs() <= slack)) continue;
        bins.add(c);
      }

      for (final bin in bins) {
        final lo = math.max(0, (bin['lo'] as int) - slack);
        final hi = math.min(globalPhonemes.length, (bin['hi'] as int) + q.length + slack);
        final align = alignSubstring(
          globalPhonemes,
          lo,
          hi,
          q,
          (offset) => wordStarts.contains(offset),
        );

        if (align != null && align.per <= 0.40) {
          final ayahData = findAyahAtOffset(align.start);
          if (ayahData != null) {
            final score = math.max(0.0, 1.0 - align.per);
            if (score >= minScore) {
              final key = '${ayahData.surah}:${ayahData.ayah}';
              final existing = candidatesByAyah[key];
              if (existing == null || existing.score < score) {
                candidatesByAyah[key] = VerseSearchResult(
                  surah: ayahData.surah,
                  ayah: ayahData.ayah,
                  score: score,
                  text: ayahData.words.join(' '),
                );
              }
            }
          }
        }
      }
    }

    final results = candidatesByAyah.values.toList()
      ..sort((a, b) {
        if (searchSuffix.isNotEmpty) {
          if (a.surah == 1 && a.ayah == 1 && (b.surah != 1 || b.ayah != 1)) {
            return 1;
          }
          if (b.surah == 1 && b.ayah == 1 && (a.surah != 1 || a.ayah != 1)) {
            return -1;
          }
        }
        return b.score.compareTo(a.score);
      });

    if (results.length > limit) {
      return results.sublist(0, limit);
    }
    return results;
  }
}
