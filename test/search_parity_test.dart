import 'package:flutter_test/flutter_test.dart';
import 'package:thai_quran_app/data/offline_surah_names.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cross-Language Surah Search', () {
    test('matches Surah 72 Al-Jinn for Thai, English, and transliterations', () {
      expect(matchesSurahQuery('72', 'ญิน'), isTrue);
      expect(matchesSurahQuery('72', 'jin'), isTrue);
      expect(matchesSurahQuery('72', 'jinn'), isTrue);
      expect(matchesSurahQuery('72', 'al-jinn'), isTrue);
      expect(matchesSurahQuery('72', 'ยิน'), isTrue);
      expect(matchesSurahQuery('72', 'อัลญิน'), isTrue);
    });

    test('matches other popular Surahs across Thai and English aliases', () {
      expect(matchesSurahQuery('36', 'yasin'), isTrue);
      expect(matchesSurahQuery('36', 'ยาซีน'), isTrue);
      expect(matchesSurahQuery('18', 'kahf'), isTrue);
      expect(matchesSurahQuery('18', 'กะฮฟ'), isTrue);
      expect(matchesSurahQuery('18', 'ถ้ำ'), isTrue);
      expect(matchesSurahQuery('2', 'baqarah'), isTrue);
      expect(matchesSurahQuery('2', 'บะเกาะเราะฮฺ'), isTrue);
      expect(matchesSurahQuery('2', 'วัว'), isTrue);
      expect(matchesSurahQuery('67', 'mulk'), isTrue);
      expect(matchesSurahQuery('67', 'มุลก์'), isTrue);
    });
  });

  group('Direct Verse Reference Parser', () {
    test('parses numerical references', () {
      final ref1 = parseQuranReference('2:255');
      expect(ref1, isNotNull);
      expect(ref1!.surahId, equals(2));
      expect(ref1.verseId, equals(255));
      expect(ref1.pageNumber, equals(42));

      final ref2 = parseQuranReference('72:1');
      expect(ref2, isNotNull);
      expect(ref2!.surahId, equals(72));
      expect(ref2.verseId, equals(1));
      expect(ref2.pageNumber, equals(572));
    });

    test('parses Surah Name + Ayah references in Thai and English', () {
      final ref1 = parseQuranReference('ญิน 1');
      expect(ref1, isNotNull);
      expect(ref1!.surahId, equals(72));
      expect(ref1.verseId, equals(1));
      expect(ref1.pageNumber, equals(572));

      final ref2 = parseQuranReference('jin 1');
      expect(ref2, isNotNull);
      expect(ref2, isNotNull);
      expect(ref2!.surahId, equals(72));
      expect(ref2.verseId, equals(1));
      expect(ref2.pageNumber, equals(572));

      final ref3 = parseQuranReference('yasin 1');
      expect(ref3, isNotNull);
      expect(ref3!.surahId, equals(36));
      expect(ref3.verseId, equals(1));
      expect(ref3.pageNumber, equals(440));

      final ref4 = parseQuranReference('กะฮฟ 1');
      expect(ref4, isNotNull);
      expect(ref4!.surahId, equals(18));
      expect(ref4.verseId, equals(1));
      expect(ref4.pageNumber, equals(293));
    });
  });

  group('Direct Mushaf Page Reference Parser', () {
    test('parses p 293, page 50, หน้า 293, and standalone 293', () {
      final p1 = parsePageReference('p 293');
      expect(p1, isNotNull);
      expect(p1!.page, equals(293));
      expect(p1.juzNumber, equals(15));
      expect(p1.surahId, equals(18)); // Al-Kahf begins on p. 293

      final p2 = parsePageReference('หน้า 293');
      expect(p2, isNotNull);
      expect(p2!.page, equals(293));

      final p3 = parsePageReference('293');
      expect(p3, isNotNull);
      expect(p3!.page, equals(293));

      final p4 = parsePageReference('page 50');
      expect(p4, isNotNull);
      expect(p4!.page, equals(50));
      expect(p4.surahId, equals(3)); // Ali 'Imran

      final p5 = parsePageReference('604');
      expect(p5, isNotNull);
      expect(p5!.page, equals(604));
      expect(p5.juzNumber, equals(30));
    });
  });
}
