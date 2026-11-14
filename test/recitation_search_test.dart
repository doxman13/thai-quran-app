import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:thai_quran_app/services/ctc_matcher.dart';
import 'package:thai_quran_app/services/tilawa_fbank.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CtcMatcher matcher;

  setUpAll(() async {
    matcher = await CtcMatcher.load();
  });

  group('Tilawa 1.0 Global Verse Search (4-Gram Index + Phonetic DP)', () {
    test('searchVerses finds Al-Fatihah 1:2 from exact tokens', () {
      final v1_2Tokens = matcher.getTargetTokens(1, 2);
      expect(v1_2Tokens, isNotNull);
      expect(v1_2Tokens, isNotEmpty);

      final results = matcher.searchVerses(v1_2Tokens!);

      expect(results, isNotEmpty);
      final topMatch = results.first;
      expect(topMatch.surah, equals(1));
      expect(topMatch.ayah, equals(2));
      expect(topMatch.score, greaterThanOrEqualTo(0.95));
      expect(CtcMatcher.normalizeArabic(topMatch.text), contains('الحمد'));
    });

    test('searchVerses finds Al-Ikhlas 112:1 without Basmalah', () {
      final v112_1Tokens = matcher.getTargetTokens(112, 1);
      expect(v112_1Tokens, isNotNull);
      expect(v112_1Tokens, isNotEmpty);

      final results = matcher.searchVerses(v112_1Tokens!);

      expect(results, isNotEmpty);
      final topMatch = results.first;
      expect(topMatch.surah, equals(112));
      expect(topMatch.ayah, equals(1));
      expect(topMatch.score, greaterThanOrEqualTo(0.95));
      expect(CtcMatcher.normalizeArabic(topMatch.text), contains('قل هو الله احد'));
    });

    test('searchVerses finds Ayat al-Kursi from partial opening phrase', () {
      final v2_255Tokens = matcher.getTargetTokens(2, 255);
      expect(v2_255Tokens, isNotNull);
      // Opening phrase of Ayat al-Kursi (Allahu la ilaha illa huwal hayyul qayyum...)
      final openingTokens = v2_255Tokens!.take(25).toList();

      final results = matcher.searchVerses(openingTokens, limit: 5);

      expect(results, isNotEmpty);
      final matches = results.map((r) => '${r.surah}:${r.ayah}').toList();
      expect(matches.contains('2:255') || matches.contains('3:2'), isTrue);
    });

    test('searchVerses strips leading Isti\'adha and finds intended verse', () {
      final istiadhaTokens = <int>[];
      for (int i = 0; i < matcher.istiadhaPhonemes.length; i++) {
        final id = CtcMatcher.tokenToId[matcher.istiadhaPhonemes[i]];
        if (id != null) istiadhaTokens.add(id);
      }

      final v112_1Tokens = matcher.getTargetTokens(112, 1)!;
      final combined = [...istiadhaTokens, ...v112_1Tokens];

      final results = matcher.searchVerses(combined, limit: 5);

      expect(results, isNotEmpty);
      expect(results.any((r) => r.surah == 112 && r.ayah == 1), isTrue);
    });
  });

  group('TilawaFbank (Kaldi 80-bin 16kHz Streaming Log-Mel Spectrogram)', () {
    test('produces exact Kaldi mel filterbank features', () {
      final fb = TilawaFbank();
      final samples = Float32List(800);
      for (int i = 0; i < 800; i++) {
        samples[i] = math.sin(2 * math.pi * 440 * i / 16000) * 0.5;
      }

      final frames = fb.push(samples);
      expect(frames.length, equals(3));
      expect(frames[0].length, equals(80));

      // Numerical match against official Kaldi fbank / Tilawa 1.0 JS implementation
      expect(frames[0][20], closeTo(-6.87, 0.1));
      expect(frames[0][0], closeTo(-11.64, 0.1));
      expect(frames[0][79], closeTo(math.log(TilawaFbank.eps), 1e-4));
    });
  });

  group('Tilawa 1.0 Phonetic Fuzzy Alignment (fuzzy.ts)', () {
    test('scores acoustically confusable pairs with confusable cost (5)', () {
      expect(subCost('ح', 'ح'), equals(0));
      expect(subCost('ه', 'ح'), equals(5));
      expect(subCost('ح', 'ه'), equals(5));
      expect(subCost('ع', 'ء'), equals(5));
      expect(subCost('ص', 'س'), equals(5));
      expect(subCost('ض', 'د'), equals(5));
      expect(subCost('ط', 'ت'), equals(5));
      expect(subCost('ق', 'ك'), equals(5));
      expect(subCost('ذ', 'ز'), equals(5));
      expect(subCost('ث', 'س'), equals(5));
    });

    test('scores short vowels with vowel cost (5) and distinct consonants with unit cost (10)', () {
      expect(subCost('َ', 'ِ'), equals(5));
      expect(subCost('ُ', 'َ'), equals(5));
      expect(subCost('ب', 'ت'), equals(10));
    });

    test('collapseHeld reduces madd and ghunna runs', () {
      final collapsedMadd = collapseHeld(['ا', 'ا', 'ا', 'ا']);
      expect(collapsedMadd, equals(['ا']));

      final collapsedGhunna = collapseHeld(['ں', 'ں', 'ں']);
      expect(collapsedGhunna, equals(['ں']));

      final doubledNoon = collapseHeld(['ن', 'ن', 'ن', 'ن']);
      expect(doubledNoon, equals(['ن', 'ن']));
    });

    test('alignSubstring tolerates confusable phonetic substitutions with low PER', () {
      // 112:1 exact vs confusable substitution (ح -> ه)
      const ref = 'قُلهُوَللَااهُءَحَدڇ';
      const obsExact = 'قُلهُوَللَااهُءَحَدڇ';
      const obsConfusable = 'قُلهُوَللَااهُءَهَدڇ';

      final alignExact = alignSubstring(ref, 0, ref.length, obsExact, (o) => o == 0);
      expect(alignExact, isNotNull);
      expect(alignExact!.per, equals(0.0));
      expect(alignExact.cost, equals(0));

      final alignConf = alignSubstring(ref, 0, ref.length, obsConfusable, (o) => o == 0);
      expect(alignConf, isNotNull);
      expect(alignConf!.per, lessThanOrEqualTo(0.10));
      expect(alignConf.cost, equals(5));
    });
  });
}
