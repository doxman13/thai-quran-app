import 'package:flutter_test/flutter_test.dart';
import 'package:thai_quran_app/data/offline_surah_names.dart';
import 'package:thai_quran_app/data/quran_repository.dart';

void main() {
  group('Surah name resolver', () {
    test('surahDisplayName returns the chosen UI language', () {
      expect(
        surahDisplayName('2', isThai: true),
        offlineSurahNamesTh['2'],
      );
      expect(surahDisplayName('2', isThai: false), 'Al-Baqarah');
    });

    test('surahNamePair exposes both languages', () {
      final names = surahNamePair('36');
      expect(names.th, offlineSurahNamesTh['36']);
      expect(names.en, offlineSurahNamesEn['36']);
    });

    test('unknown surah ids fall back without throwing', () {
      expect(surahDisplayName('999', isThai: true), contains('999'));
      expect(surahDisplayName('999', isThai: false), contains('999'));
      expect(surahNamePair('999').en, contains('999'));
    });

    test('getSurahName delegates to the resolver and keeps the number prefix',
        () {
      final repository = QuranRepository();
      expect(
        repository.getSurahName('2', isThai: true),
        '2. ${offlineSurahNamesTh['2']}',
      );
      expect(repository.getSurahName('2', isThai: false), '2. Al-Baqarah');
    });
  });
}
