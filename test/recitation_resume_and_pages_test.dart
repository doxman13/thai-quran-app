import 'package:flutter_test/flutter_test.dart';
import 'package:thai_quran_app/data/medina_mushaf_pages.dart';
import 'package:thai_quran_app/services/ctc_matcher.dart';

List<int> _tokensForWordSlice(CtcMatcher matcher, int surah, int ayah, int takeWords) {
  final data = matcher.ayahsByKey['$surah:$ayah']!;
  final endOff = takeWords < data.offsets.length ? data.offsets[takeWords] : data.phonemes.length;
  final slice = data.phonemes.substring(0, endOff);
  final tokens = <int>[];
  for (int i = 0; i < slice.length; i++) {
    final id = CtcMatcher.tokenToId[slice[i]];
    if (id != null) tokens.add(id);
  }
  return tokens;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Authoritative Medina Mushaf Page Boundaries', () {
    test('Surah 80 (Abasa) end of surah boundary: verses 41 and 42 are on Page 585', () {
      // In flawed qcf_quran 0.0.5, verses 41-42 were mapped to Page 586,
      // which caused premature page turn when reciting verse 40!
      expect(getMedinaMushafPageNumber(80, 40), 585);
      expect(getMedinaMushafPageNumber(80, 41), 585);
      expect(getMedinaMushafPageNumber(80, 42), 585);
      expect(getMedinaMushafPageNumber(81, 1), 586);
    });

    test('Surah 86/87 and 87/88 page boundaries', () {
      expect(getMedinaMushafPageNumber(86, 17), 591);
      expect(getMedinaMushafPageNumber(87, 15), 591);
      expect(getMedinaMushafPageNumber(87, 16), 592);
      expect(getMedinaMushafPageNumber(88, 26), 592);
      expect(getMedinaMushafPageNumber(89, 1), 593);
    });

    test('Surah 82/83 and 83/84 page boundaries', () {
      expect(getMedinaMushafPageNumber(82, 19), 587);
      expect(getMedinaMushafPageNumber(83, 6), 587);
      expect(getMedinaMushafPageNumber(83, 7), 588);
      expect(getMedinaMushafPageNumber(83, 34), 588);
      expect(getMedinaMushafPageNumber(83, 35), 589);
      expect(getMedinaMushafPageNumber(84, 25), 589);
      expect(getMedinaMushafPageNumber(85, 1), 590);
    });
  });

  group('Mid-Session Resume & Isti\'naf (Previous Verse) Matching', () {
    late CtcMatcher matcher;

    setUpAll(() async {
      matcher = await CtcMatcher.load();
    });

    test('matchSlidingWindow matches previous verse (isti\'naf) with isSkip = false', () {
      // Surah Al-Fatihah (1):
      // Verse 1: "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ"
      // Verse 2: "الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ"
      // Verse 3: "الرَّحْمَٰنِ الرَّحِيمِ"
      // Verse 4: "مَالِكِ يَوْمِ الدِّينِ"

      // Scenario: User had recited verses 1 and 2, and paused.
      // Now resuming: expectedAyah is 3.
      // User repeats verse 2 before continuing.
      const verse2Text = 'الحمد لله رب العالمين';
      final v2Tokens = matcher.getTargetTokens(1, 2) ?? [];

      final matchV2 = matcher.matchSlidingWindow(
        surah: 1,
        expectedAyah: 3,
        candidateTokens: v2Tokens,
        candidateText: verse2Text,
        windowAhead: 2,
        windowBehind: 1,
        minAyah: 1,
        maxAyah: 7,
      );

      expect(matchV2, isNotNull);
      expect(matchV2!.detectedAyah, 2, reason: 'Must recognize previous verse (2)');
      expect(matchV2.isSkip, false, reason: 'Isti\'naf (previous verse) is NOT a skip');
    });

    test('matchSlidingWindow matches current expected verse normally', () {
      const verse3Text = 'الرحمن الرحيم';
      final v3Tokens = matcher.getTargetTokens(1, 3) ?? [];

      final matchV3 = matcher.matchSlidingWindow(
        surah: 1,
        expectedAyah: 3,
        candidateTokens: v3Tokens,
        candidateText: verse3Text,
        windowAhead: 2,
        windowBehind: 1,
        minAyah: 1,
        maxAyah: 7,
      );

      expect(matchV3, isNotNull);
      expect(matchV3!.detectedAyah, 3);
      expect(matchV3.isSkip, false);
    });

    test('matchSlidingWindow detects skip ahead when jumping past expected verse', () {
      const verse4Text = 'مالك يوم الدين';
      final v4Tokens = matcher.getTargetTokens(1, 4) ?? [];

      final matchV4 = matcher.matchSlidingWindow(
        surah: 1,
        expectedAyah: 3,
        candidateTokens: v4Tokens,
        candidateText: verse4Text,
        windowAhead: 2,
        windowBehind: 1,
        minAyah: 1,
        maxAyah: 7,
      );

      expect(matchV4, isNotNull);
      expect(matchV4!.detectedAyah, 4);
      expect(matchV4.isSkip, true, reason: 'Jumping to verse 4 while expecting 3 is a skip');
    });
  });

  group('Long-verse final-word policy', () {
    late CtcMatcher matcher;

    setUpAll(() async {
      matcher = await CtcMatcher.load();
    });

    test('accepts a long verse missing only the final word when gate is disabled', () async {
      final variants = matcher.getTargetTextVariants(1, 7);
      expect(variants, isNotEmpty, reason: 'Surah 1:7 text variants must be available');

      final targetWords = variants.first.split(' ').where((w) => w.isNotEmpty).toList();
      expect(targetWords.length, greaterThanOrEqualTo(6));
      final partialText = targetWords.take(targetWords.length - 1).join(' ');

      final match = matcher.matchSlidingWindow(
        surah: 1,
        expectedAyah: 7,
        candidateTokens: const [],
        candidateText: partialText,
        minAyah: 1,
        maxAyah: 7,
        requireLastWord: false,
      );

      expect(match, isNotNull,
          reason: 'A long verse at >=85% word recall should not stick on the final word');
      expect(match!.detectedAyah, 7);
      expect(match.isSkip, false);
      expect(match.wordsConsumed, targetWords.length - 1,
          reason: 'The accepted partial candidate must be fully consumed for a clean next-ayah start');
    });

    test('still requires the final word when the gate is enabled', () async {
      final variants = matcher.getTargetTextVariants(1, 7);
      final targetWords = variants.first.split(' ').where((w) => w.isNotEmpty).toList();
      final partialText = targetWords.take(targetWords.length - 1).join(' ');

      final match = matcher.matchSlidingWindow(
        surah: 1,
        expectedAyah: 7,
        candidateTokens: const [],
        candidateText: partialText,
        minAyah: 1,
        maxAyah: 7,
        requireLastWord: true,
      );

      expect(match, isNull);
    });

    test('does not accept a long verse that stops halfway', () async {
      final variants = matcher.getTargetTextVariants(1, 7);
      final targetWords = variants.first.split(' ').where((w) => w.isNotEmpty).toList();
      final halfText = targetWords.take((targetWords.length / 2).floor()).join(' ');

      final match = matcher.matchSlidingWindow(
        surah: 1,
        expectedAyah: 7,
        candidateTokens: const [],
        candidateText: halfText,
        minAyah: 1,
        maxAyah: 7,
        requireLastWord: false,
      );

      expect(match, isNull);
    });

    test('does not accept a short fragment or single word as a verse match', () async {
      final v1Tokens = matcher.getTargetTokens(1, 1)!;
      final firstWordTokens = v1Tokens.take(5).toList();

      final match = matcher.matchSlidingWindow(
        surah: 1,
        expectedAyah: 1,
        candidateTokens: firstWordTokens,
        minAyah: 1,
        maxAyah: 7,
        requireLastWord: false,
      );

      expect(match, isNull, reason: 'First word alone must not trigger a verse match');
    });

    test('stopping 2 words before the end does not match even with requireLastWord: false', () async {
      final variants = matcher.getTargetTextVariants(1, 7);
      final targetWords = variants.first.split(' ').where((w) => w.isNotEmpty).toList();
      final twoWordsShortText = targetWords.take(targetWords.length - 2).join(' ');

      final match = matcher.matchSlidingWindow(
        surah: 1,
        expectedAyah: 7,
        candidateTokens: const [],
        candidateText: twoWordsShortText,
        minAyah: 1,
        maxAyah: 7,
        requireLastWord: false,
      );

      expect(match, isNull, reason: 'Stopping 2 words before the end must not trigger match');
    });

    test('short verse (< 6 words) requires last word even when requireLastWord: false is passed', () async {
      final v2Tokens = matcher.getTargetTokens(1, 2)!;
      // Drop the last word's tokens (e.g. drop 8 tokens)
      final withoutLastWord = v2Tokens.take(v2Tokens.length - 8).toList();

      final match = matcher.matchSlidingWindow(
        surah: 1,
        expectedAyah: 2,
        candidateTokens: withoutLastWord,
        minAyah: 1,
        maxAyah: 7,
        requireLastWord: false,
      );

      expect(match, isNull, reason: 'Short verse missing last word must never match');
    });
  });

  group('Prefix-repeat, next-verse bleed, Wasl & noise guards', () {
    late CtcMatcher matcher;

    setUpAll(() async {
      matcher = await CtcMatcher.load();
    });

    test('rejects repeating first words of 112:3 instead of completing full verse', () {
      final d112_3 = matcher.ayahsByKey['112:3']!;
      final firstTwoWords = _tokensForWordSlice(matcher, 112, 3, 2);
      final repeatedObs = matcher.tokensToPhonemes([...firstTwoWords, ...firstTwoWords]);

      expect(
        matcher.alignAyahToObs(
          d112_3,
          repeatedObs,
          requireLastWord: true,
          effectiveRecall: 0.76,
          effectiveScore: 0.68,
        ),
        isNull,
      );
      expect(
        matcher.alignAyahToObs(
          d112_3,
          repeatedObs,
          requireLastWord: false,
          effectiveRecall: 0.76,
          effectiveScore: 0.68,
        ),
        isNull,
      );
    });

    test('prevents starting next verse from prematurely revealing an incomplete previous verse', () {
      final m112_1 = matcher.matchSlidingWindow(
        surah: 112,
        expectedAyah: 1,
        candidateTokens: [
          ..._tokensForWordSlice(matcher, 112, 1, 2),
          ..._tokensForWordSlice(matcher, 112, 2, 2),
        ],
        minAyah: 1,
        maxAyah: 4,
        requireLastWord: false,
      );
      expect(m112_1?.detectedAyah, isNot(1));

      final m2_14 = matcher.matchSlidingWindow(
        surah: 2,
        expectedAyah: 14,
        candidateTokens: [
          ..._tokensForWordSlice(matcher, 2, 14, 15),
          ..._tokensForWordSlice(matcher, 2, 15, 2),
        ],
        minAyah: 1,
        maxAyah: 20,
        requireLastWord: false,
      );
      expect(m2_14?.detectedAyah, isNot(14));
    });

    test('allows authentic connected Wasl without borrowing next verse tokens', () {
      final full2_14 = matcher.getTargetTokens(2, 14)!;
      final open2_15 = _tokensForWordSlice(matcher, 2, 15, 2);
      final match = matcher.matchSlidingWindow(
        surah: 2,
        expectedAyah: 14,
        candidateTokens: [...full2_14, ...open2_15],
        minAyah: 1,
        maxAyah: 20,
        requireLastWord: true,
      );
      expect(match, isNotNull);
      expect(match!.detectedAyah, 14);
      expect(match.isSkip, false);
      expect(match.tokensConsumed, lessThanOrEqualTo(full2_14.length));
    });

    test('detects restart index and distinguishes off-passage chatter', () {
      final partial = _tokensForWordSlice(matcher, 1, 2, 2);
      final noise = matcher.getTargetTokens(112, 4)!.take(10).toList();
      final combined = [...noise, ...partial];
      final restartIdx = matcher.findExpectedAyahRestartIndex(
        surah: 1,
        expectedAyah: 2,
        candidateTokens: combined,
      );
      expect(restartIdx, isNotNull);
      expect(
        matcher.hasPrefixProgress(
          surah: 1,
          expectedAyah: 2,
          candidateTokens: noise,
        ),
        isFalse,
      );
      expect(
        matcher.hasPrefixProgress(
          surah: 1,
          expectedAyah: 2,
          candidateTokens: _tokensForWordSlice(matcher, 1, 2, 3),
        ),
        isTrue,
      );
    });
  });
}
