import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thai_quran_app/database/hifz_repository.dart';
import 'package:thai_quran_app/providers/local_reading_provider.dart';
import 'package:thai_quran_app/providers/notes_provider.dart';
import 'package:thai_quran_app/providers/stats_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'https://example.supabase.co',
        publishableKey: 'test-anon-key',
        authOptions: const FlutterAuthClientOptions(
          localStorage: EmptyLocalStorage(),
        ),
      );
    } catch (_) {
      // Ignore if already initialized in the test isolate.
    }
  });

  group('Phase 3 Sync & Account Deletion Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('HifzRepository singleton and instance getter are functional', () {
      final repo1 = HifzRepository.instance;
      final repo2 = HifzRepository();
      expect(repo1, same(repo2));
    });

    test('LocalReadingProvider completed surah tracking and tombstones', () async {
      final provider = LocalReadingProvider();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(provider.completedReadSurahs.contains('1'), isFalse);
      expect(provider.deletedCompletedReadSurahs.contains(1), isFalse);

      // Toggle surah 1 to completed
      await provider.toggleCompletedReadSurah('1');
      expect(provider.completedReadSurahs.contains('1'), isTrue);
      expect(provider.deletedCompletedReadSurahs.contains(1), isFalse);

      // Untoggle surah 1
      await provider.toggleCompletedReadSurah('1');
      expect(provider.completedReadSurahs.contains('1'), isFalse);
      expect(provider.deletedCompletedReadSurahs.contains(1), isTrue);

      // Increment count on surah 1 should restore and clear deletion tombstone
      await provider.incrementCompletedReadSurahCount('1');
      expect(provider.completedReadSurahs.contains('1'), isTrue);
      expect(provider.deletedCompletedReadSurahs.contains(1), isFalse);

      // Clear all local data
      await provider.clearAllLocal();
      expect(provider.completedReadSurahs.isEmpty, isTrue);
      expect(provider.deletedCompletedReadSurahs.isEmpty, isTrue);
    });

    test('StatsProvider clearAllLocal clears history and storage', () async {
      final stats = StatsProvider();
      await stats.logVerseRead('1', '1');
      expect(stats.totalVersesRead, greaterThan(0));

      await stats.clearAllLocal();
      expect(stats.totalVersesRead, equals(0));
    });

    test('NotesProvider deleteNote records tombstone and clearAllLocal resets', () async {
      final notes = NotesProvider();
      await notes.saveNote(
        surahId: '1',
        verseId: '1',
        noteText: 'Test reflection note',
      );
      expect(notes.getNoteForVerse('1', '1'), equals('Test reflection note'));

      await notes.deleteNote('1', '1');
      expect(notes.getNoteForVerse('1', '1'), isEmpty);
      expect(notes.deletedNoteKeys.contains('1:1'), isTrue);

      await notes.clearAllLocal();
      expect(notes.deletedNoteKeys.isEmpty, isTrue);
      expect(notes.personalNotes.isEmpty, isTrue);
    });
  });
}
