import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:thai_quran_app/services/recitation_engine.dart';

Uint8List _makeSinePcm(int numSamples, double amplitude, {double freqHz = 400.0}) {
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
  final engine = RecitationEngine();

  tearDown(() {
    engine.setListeningForTest(false);
  });

  group('RecitationEngine iOS first-word capture', () {
    test(
      'preserves pre-speech onset and amplifies quiet iOS first syllable without dropping it',
      () {
        engine.setListeningForTest(true, isIosProfile: true);
        engine.setAdaptiveNoise(true);

        // Two quiet ambient chunks (raw RMS ~0.0014, boosted RMS ~0.0035 < threshold ~0.0061)
        for (int i = 0; i < 2; i++) {
          engine.processAudioChunkForTest(
            _makeSinePcm(800, 0.002),
            isIosProfile: true,
          );
        }
        expect(engine.isSpeechActiveForTest, isFalse);
        expect(engine.preSpeechBufferSampleCountForTest, 1600);
        expect(engine.fbankFrames, 0);

        // Two soft consonant onset chunks before peak syllable (boosted RMS ~0.0053 < threshold)
        for (int i = 0; i < 2; i++) {
          engine.processAudioChunkForTest(
            _makeSinePcm(800, 0.003),
            isIosProfile: true,
          );
        }
        expect(engine.isSpeechActiveForTest, isFalse);
        expect(engine.preSpeechBufferSampleCountForTest, 3200);

        // First voiced syllable arrives quiet on raw iOS mic (amp 0.007 => raw RMS ~0.00495,
        // which would miss unboosted threshold, but boosted by iOS profile > threshold).
        engine.processAudioChunkForTest(
          _makeSinePcm(800, 0.007),
          isIosProfile: true,
        );

        expect(engine.isSpeechActiveForTest, isTrue);
        expect(engine.preSpeechBufferSampleCountForTest, 0);
        // 3200 pre-speech + 800 voiced = 4000 samples -> ~23 fbank frames preserved.
        expect(engine.fbankFrames, greaterThanOrEqualTo(20));
      },
    );

    test(
      'immediate speech at frame 0 stops calibration early and prepends lead-in silence',
      () {
        engine.setListeningForTest(true, isIosProfile: true);
        engine.setAdaptiveNoise(true);

        // Send loud speech on the very first chunk (no preceding silence chunks).
        engine.processAudioChunkForTest(
          _makeSinePcm(800, 0.025),
          isIosProfile: true,
        );
        expect(engine.isSpeechActiveForTest, isTrue);
        // Pre-speech was <1600, so lead-in silence brings total pushed to >=1600 + 800 = 2400 samples (>=13 frames).
        expect(engine.fbankFrames, greaterThanOrEqualTo(12));

        // Send additional chunks immediately during what would have been calibration.
        for (int i = 0; i < 4; i++) {
          engine.processAudioChunkForTest(
            _makeSinePcm(800, 0.025),
            isIosProfile: true,
          );
        }

        // Calibration stopped on first voice frame; ambient noise floor stayed low (~0.0035).
        expect(engine.ambientNoiseFloorForTest, closeTo(0.0035, 0.0005));
        expect(engine.effectiveThresholdForTest, lessThan(0.01));
      },
    );

    test(
      'caps rolling pre-speech ring buffer near 800ms during extended silence',
      () {
        engine.setListeningForTest(true, isIosProfile: true);

        // 20 chunks * 800 samples = 16000 samples (1000ms) of very soft background noise.
        for (int i = 0; i < 20; i++) {
          engine.processAudioChunkForTest(
            _makeSinePcm(800, 0.001),
            isIosProfile: true,
          );
        }

        expect(engine.isSpeechActiveForTest, isFalse);
        expect(engine.preSpeechBufferSampleCountForTest, lessThanOrEqualTo(12800));
        expect(engine.preSpeechBufferSampleCountForTest, greaterThanOrEqualTo(12000));
      },
    );

    test(
      'handles high-amplitude iOS speech safely and detects trailing silence by sample count',
      () {
        engine.setListeningForTest(true, isIosProfile: true);
        engine.setAdaptiveNoise(true);

        // High-amplitude chunk triggers anti-clipping gain reduction safely.
        engine.processAudioChunkForTest(
          _makeSinePcm(1600, 0.90),
          isIosProfile: true,
        );
        expect(engine.isSpeechActiveForTest, isTrue);
        expect(engine.fbankFrames, greaterThan(0));
        expect(engine.ambientNoiseFloorForTest, lessThanOrEqualTo(0.020));

        // 2 chunks of silence (3200 samples < 3840 target) keep speech active across pauses.
        engine.processAudioChunkForTest(_makeSinePcm(1600, 0.0), isIosProfile: true);
        engine.processAudioChunkForTest(_makeSinePcm(1600, 0.0), isIosProfile: true);
        expect(engine.isSpeechActiveForTest, isTrue);

        // 3rd silence chunk crosses 3840 samples (240ms) regardless of chunk size.
        engine.processAudioChunkForTest(_makeSinePcm(1600, 0.0), isIosProfile: true);
        expect(engine.isSpeechActiveForTest, isFalse);
      },
    );

    test(
      'detects end-of-verse pause cleanly on iOS even with steady room background noise',
      () {
        engine.setListeningForTest(true, isIosProfile: true);
        engine.setAdaptiveNoise(true);

        // User recites a verse (typical speech raw amp ~0.08 => boosted ~0.18).
        for (int i = 0; i < 6; i++) {
          engine.processAudioChunkForTest(
            _makeSinePcm(1600, 0.08),
            isIosProfile: true,
          );
        }
        expect(engine.isSpeechActiveForTest, isTrue);

        // User stops speaking at the last word; louder AC/hiss remains (~0.015 raw amp,
        // >0.030 boosted RMS, exceeding the old 0.020 linear clamp).
        for (int i = 0; i < 4; i++) {
          engine.processAudioChunkForTest(
            _makeSinePcm(1600, 0.015),
            isIosProfile: true,
          );
        }

        expect(engine.isSpeechActiveForTest, isFalse);
        expect(engine.flushCountForTest, greaterThanOrEqualTo(1));
      },
    );

    test(
      'triggers upstream no-token-progress flush within 550ms when tokens stall under loud ambient noise',
      () {
        engine.setListeningForTest(true, isIosProfile: true);
        engine.setAdaptiveNoise(true);

        // User recites a verse (~0.10 raw amp) and tokens have arrived.
        engine.processAudioChunkForTest(_makeSinePcm(1600, 0.10), isIosProfile: true);
        engine.seedAccumulatedTokensForTest([1, 2, 3, 4, 5, 6]);
        expect(engine.isSpeechActiveForTest, isTrue);
        expect(engine.flushCountForTest, 0);

        // Strong background noise (~0.030 raw amp, only ~10 dB below peak so Log-dB drop < 12 dB)
        // produces no new tokens across 600ms (6 * 1600 = 9600 >= 8800 samples).
        for (int i = 0; i < 6; i++) {
          engine.processAudioChunkForTest(
            _makeSinePcm(1600, 0.030),
            isIosProfile: true,
          );
        }

        expect(engine.flushCountForTest, greaterThanOrEqualTo(1));
        expect(engine.isSpeechActiveForTest, isFalse);
      },
    );
  });
}
