import 'package:flutter_test/flutter_test.dart';
import 'package:thai_quran_app/models/hifz_session_config.dart';
import 'package:thai_quran_app/widgets/surah_mastery_card.dart';

void main() {
  group('SurahMasteryCard status rules', () {
    test('requires completed new verses and at least 3 reviews', () {
      final mastered = SurahCompletionRecord(
        surahNumber: 67,
        newVersesCompleted: true,
        reviewCount: SurahMasteryCard.masteredReviewThreshold,
      );
      final notEnoughReviews = SurahCompletionRecord(
        surahNumber: 67,
        newVersesCompleted: true,
        reviewCount: SurahMasteryCard.masteredReviewThreshold - 1,
      );

      expect(SurahMasteryCard.isMasteredRecord(mastered), isTrue);
      expect(SurahMasteryCard.isMasteredRecord(notEnoughReviews), isFalse);
      expect(SurahMasteryCard.isInProgressRecord(notEnoughReviews), isTrue);
    });

    test('reviewed-only and completed-only records are in progress', () {
      expect(
        SurahMasteryCard.isInProgressRecord(
          const SurahCompletionRecord(
            surahNumber: 36,
            newVersesCompleted: false,
            reviewCount: 1,
          ),
        ),
        isTrue,
      );
      expect(
        SurahMasteryCard.isInProgressRecord(
          const SurahCompletionRecord(
            surahNumber: 36,
            newVersesCompleted: true,
            reviewCount: 0,
          ),
        ),
        isTrue,
      );
    });

    test('mastered records are not counted as in progress', () {
      final mastered = SurahCompletionRecord(
        surahNumber: 112,
        newVersesCompleted: true,
        reviewCount: SurahMasteryCard.masteredReviewThreshold,
      );

      expect(SurahMasteryCard.isInProgressRecord(mastered), isFalse);
    });

    test('missing records are neither mastered nor in progress', () {
      expect(SurahMasteryCard.isMasteredRecord(null), isFalse);
      expect(SurahMasteryCard.isInProgressRecord(null), isFalse);
    });
  });
}
