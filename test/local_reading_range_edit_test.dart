import 'package:flutter_test/flutter_test.dart';
import 'package:thai_quran_app/providers/local_reading_provider.dart';
import 'package:thai_quran_app/shared/shared.dart';

void main() {
  group('Editing a reading goal keeps progress', () {
    test('keeps the current position when it is still inside the range', () {
      final current = toVerseRef(2, 50);
      final result = constrainVerseRefToRange(
        current,
        start: toVerseRef(1, 1),
        target: toVerseRef(2, 100),
      );

      expect(result.verseKey, current.verseKey);
    });

    test('clamps to the new start when the range moves forward', () {
      final result = constrainVerseRefToRange(
        toVerseRef(1, 7),
        start: toVerseRef(2, 1),
        target: toVerseRef(2, 100),
      );

      expect(result.verseKey, '2:1');
    });

    test('clamps to the new target instead of resetting to the start', () {
      final result = constrainVerseRefToRange(
        toVerseRef(5, 10),
        start: toVerseRef(1, 1),
        target: toVerseRef(4, 10),
      );

      expect(result.verseKey, '4:10');
    });

    test('only applies the start bound when there is no target', () {
      expect(
        constrainVerseRefToRange(
          toVerseRef(1, 1),
          start: toVerseRef(3, 1),
        ).verseKey,
        '3:1',
      );
      expect(
        constrainVerseRefToRange(
          toVerseRef(9, 1),
          start: toVerseRef(3, 1),
        ).verseKey,
        '9:1',
      );
    });
  });

  group('verseSpanInclusive', () {
    test('counts both ends of the range', () {
      expect(verseSpanInclusive(toVerseRef(1, 1), toVerseRef(1, 7)), 7);
      expect(verseSpanInclusive(toVerseRef(2, 255), toVerseRef(2, 255)), 1);
    });

    test('returns zero for a missing or inverted range', () {
      expect(verseSpanInclusive(toVerseRef(1, 1), null), 0);
      expect(verseSpanInclusive(toVerseRef(2, 10), toVerseRef(2, 1)), 0);
    });
  });

  group('compareQuranVerseRefs', () {
    test('orders by Surah then Ayah', () {
      expect(
        compareQuranVerseRefs(toVerseRef(2, 1), toVerseRef(1, 7)),
        greaterThan(0),
      );
      expect(
        compareQuranVerseRefs(toVerseRef(2, 1), toVerseRef(2, 2)),
        lessThan(0),
      );
      expect(compareQuranVerseRefs(toVerseRef(2, 2), toVerseRef(2, 2)), 0);
    });
  });
}
