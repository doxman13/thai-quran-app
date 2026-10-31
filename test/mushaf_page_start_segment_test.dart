import 'package:flutter_test/flutter_test.dart';
import 'package:qcf_quran/qcf_quran.dart' as qcf;
import 'package:thai_quran_app/data/medina_mushaf_pages.dart';

void main() {
  group('Mushaf page start segment', () {
    test('uses the first Surah segment for a boundary page', () {
      // Page 106 contains 4:176 followed by 5:1-2. Hifz range editors are
      // single-Surah, so they must not combine 4:176 with an end verse of 2.
      final segment = getMedinaMushafPageStartSegment(106);

      expect(segment, isNotNull);
      expect(segment!.surah, 4);
      expect(segment.start, 176);
      expect(segment.end, 176);
    });

    test('every page segment is valid and inside its Surah', () {
      for (var page = 1; page <= 604; page++) {
        final segment = getMedinaMushafPageStartSegment(page);
        expect(segment, isNotNull, reason: 'page $page should have data');
        expect(
          segment!.surah,
          inInclusiveRange(1, 114),
          reason: 'page $page Surah',
        );
        expect(
          segment.start,
          inInclusiveRange(1, segment.end),
          reason: 'page $page start',
        );
        expect(
          segment.end,
          lessThanOrEqualTo(qcf.getVerseCount(segment.surah)),
          reason: 'page $page end must stay inside Surah ${segment.surah}',
        );
      }
    });

    test('returns null for an out-of-range page', () {
      expect(getMedinaMushafPageStartSegment(0), isNull);
      expect(getMedinaMushafPageStartSegment(605), isNull);
    });
  });
}
