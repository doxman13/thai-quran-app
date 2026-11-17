import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:thai_quran_app/services/ctc_matcher.dart';
import 'package:thai_quran_app/services/recitation_engine.dart';

Uint8List _makeSearchSinePcm(int numSamples, double amplitude, {double freqHz = 400.0}) {
  final byteData = ByteData(numSamples * 2);
  for (int i = 0; i < numSamples; i++) {
    final sample =
        (amplitude * math.sin(2 * math.pi * freqHz * i / 16000.0)).clamp(-1.0, 1.0);
    final intVal = (sample * 32767.0).round().clamp(-32768, 32767);
    byteData.setInt16(i * 2, intVal, Endian.little);
  }
  return byteData.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final engine = RecitationEngine();
  late CtcMatcher matcher;

  setUpAll(() async {
    matcher = await CtcMatcher.load();
  });

  tearDown(() async {
    await engine.stopListening();
  });

  group('RecitationEngine iOS voice search capture & lifecycle', () {
    test(
      'preserves quiet iOS onset in search mode, emits audio levels, and waits 550ms trailing silence',
      () {
        final levels = <double>[];
        engine.setSearchModeForTest(
          matcher: matcher,
          isIosProfile: true,
          onAudioLevel: levels.add,
        );

        // Soft pre-speech consonant onset (under threshold -> buffered)
        engine.processAudioChunkForTest(
          _makeSearchSinePcm(1600, 0.003),
          isIosProfile: true,
        );
        expect(engine.isSpeechActiveForTest, isFalse);
        expect(engine.preSpeechBufferSampleCountForTest, 1600);

        // Quiet iOS voiced onset
        engine.processAudioChunkForTest(
          _makeSearchSinePcm(800, 0.007),
          isIosProfile: true,
        );
        expect(engine.isSpeechActiveForTest, isTrue);
        // 1600 pre-speech + 800 voiced = 2400 samples -> (2400 - 400)/160 + 1 = 13 frames.
        expect(engine.fbankFrames, greaterThanOrEqualTo(12));

        // Normal spoken continuation before user pauses (~0.06 raw amp)
        engine.processAudioChunkForTest(
          _makeSearchSinePcm(1600, 0.06),
          isIosProfile: true,
        );

        // 500ms pause (8000 samples < 8800 search target) keeps search active & updates audio levels
        for (int i = 0; i < 5; i++) {
          engine.processAudioChunkForTest(
            _makeSearchSinePcm(1600, 0.005),
            isIosProfile: true,
          );
        }
        expect(engine.isSpeechActiveForTest, isTrue);
        expect(levels.length, greaterThanOrEqualTo(6));

        // Crossing 550ms trailing pause (1 more chunk => 9600 >= 8800) ends speech window
        // even when boosted room ambient noise (~0.005 raw) is present.
        engine.processAudioChunkForTest(
          _makeSearchSinePcm(1600, 0.005),
          isIosProfile: true,
        );
        expect(engine.isSpeechActiveForTest, isFalse);
      },
    );

    test(
      'short 4-token query is evaluated rather than discarded and no-match clears stale tokens for retry',
      () async {
        final matchedBatches = <List<VerseSearchResult>>[];
        final noMatchTexts = <String>[];

        engine.setSearchModeForTest(
          matcher: matcher,
          isIosProfile: true,
          onResults: (results, _) => matchedBatches.add(results),
          onNoMatch: noMatchTexts.add,
        );

        // 1. Short <4-phoneme flush clears accumulated tokens instead of sticking
        final shortTokens = matcher.getTargetTokens(112, 1)!.take(3).toList();
        await engine.processSearchTokensForTest(shortTokens, isFlush: true);
        expect(engine.accumulatedTokenCountForTest, 0);

        // 2. 4-token query ("قُله") is evaluated instead of skipped by <5 guard
        final qTokens = matcher.getTargetTokens(112, 1)!.take(4).toList();
        await engine.processSearchTokensForTest(qTokens, isFlush: true);
        // Should either match or clear stale buffer via noMatch without staying stuck dirty
        if (matchedBatches.where((b) => b.isNotEmpty).isEmpty) {
          expect(engine.accumulatedTokenCountForTest, 0);
        }

        // 3. No-match >=4-phoneme cluster clears stale buffer so next recitation matches 112:1
        matchedBatches.clear();
        noMatchTexts.clear();
        engine.setSearchModeForTest(
          matcher: matcher,
          isIosProfile: true,
          onResults: (results, _) => matchedBatches.add(results),
          onNoMatch: noMatchTexts.add,
        );
        final impossibleCluster = [
          for (final ch in ['ض', 'ظ', 'ض', 'ظ', 'ض', 'ظ']) CtcMatcher.tokenToId[ch]!,
        ];
        await engine.processSearchTokensForTest(impossibleCluster, isFlush: true);
        expect(noMatchTexts, isNotEmpty);
        expect(engine.accumulatedTokenCountForTest, 0);

        final v112_1 = matcher.getTargetTokens(112, 1)!;
        await engine.processSearchTokensForTest(v112_1, isFlush: true);
        final finalMatch = matchedBatches.lastWhere((b) => b.isNotEmpty, orElse: () => []);
        expect(finalMatch, isNotEmpty);
        expect(finalMatch.first.surah, 112);
        expect(finalMatch.first.ayah, 1);
      },
    );

    test(
      'finishVoiceSearch flushes accumulated partial search tokens instead of discarding them',
      () async {
        List<VerseSearchResult> finalResults = const [];
        String finalText = '';

        engine.setSearchModeForTest(
          matcher: matcher,
          isIosProfile: true,
          onResults: (results, text) {
            finalResults = results;
            finalText = text;
          },
        );

        // Partial emission before user pauses 650ms
        final v1_2 = matcher.getTargetTokens(1, 2)!;
        await engine.processSearchTokensForTest(v1_2, isFlush: false);
        expect(finalResults, isEmpty);
        expect(finalText, isNotEmpty);

        // User manually taps Stop / Search button
        await engine.finishVoiceSearch();

        expect(finalResults, isNotEmpty);
        expect(finalResults.first.surah, 1);
        expect(finalResults.first.ayah, 2);
        expect(engine.isListening, isFalse);
      },
    );

    test('stopListening bumps operation sequence cleanly to cancel concurrent start requests', () async {
      final before = engine.listenOpSeqForTest;
      await engine.stopListening();
      expect(engine.listenOpSeqForTest, greaterThan(before));
      expect(engine.isListening, isFalse);
    });
  });
}
