import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thai_quran_app/data/medina_mushaf_pages.dart';
import 'package:thai_quran_app/models/mushaf_models.dart';
import 'package:thai_quran_app/providers/local_reading_provider.dart';
import 'package:thai_quran_app/providers/mushaf_reading_provider.dart';
import 'package:thai_quran_app/shared/shared.dart';

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

  group('Metro Shortcuts & Goal Routing Tests', () {
    test('isFreeReadProfile correctly distinguishes free-read vs goal profile', () {
      final goalProfile = LocalReadingProfile(
        id: 'goal-123',
        userId: 'test-user',
        name: 'เป้าหมาย: คอตัม 30 วัน',
        slug: 'khatam-30-days',
        start: toVerseRef('1', '1'),
        target: toVerseRef('114', '6'),
        current: toVerseRef('2', '255'),
        sortOrder: 0,
        isArchived: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final freeReadProfile = LocalReadingProfile(
        id: 'free-read-default',
        userId: 'test-user',
        name: 'Free Read',
        slug: 'free-read',
        start: toVerseRef('1', '1'),
        target: null,
        current: toVerseRef('2', '1'),
        sortOrder: 999,
        isArchived: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(isFreeReadProfile(goalProfile), isFalse);
      expect(isFreeReadProfile(freeReadProfile), isTrue);
    });

    test('MushafProfile isFreeRead distinguishes free-read vs goal profile', () {
      final mushafGoal = MushafProfile(
        id: 'mushaf-goal-1',
        userId: 'test-user',
        name: 'คอตัมมุศหัฟรอมฎอน',
        slug: 'ramadan-khatam',
        mushafId: 1,
        planMode: 'khatam',
        startPage: 1,
        targetPage: 604,
        currentPage: 250,
        sortOrder: 0,
        isArchived: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final mushafFreeRead = MushafProfile(
        id: 'mushaf-free-1',
        userId: 'test-user',
        name: 'อ่านมุศหัฟอิสระ',
        slug: mushafFreeReadSlug,
        mushafId: 1,
        planMode: 'free',
        startPage: 1,
        targetPage: 604,
        currentPage: 50,
        sortOrder: 999,
        isArchived: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(mushafGoal.isFreeRead, isFalse);
      expect(mushafFreeRead.isFreeRead, isTrue);
    });

    test('Archived goals are prevented from active goal routing', () {
      final archivedGoal = LocalReadingProfile(
        id: 'archived-goal',
        userId: 'test-user',
        name: 'เป้าหมายเก่าที่เสร็จแล้ว',
        slug: 'old-goal',
        start: toVerseRef('1', '1'),
        target: toVerseRef('2', '100'),
        current: toVerseRef('2', '100'),
        sortOrder: 0,
        isArchived: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final isGoalCandidate = !archivedGoal.isArchived && !isFreeReadProfile(archivedGoal);
      expect(isGoalCandidate, isFalse, reason: 'Archived goals must not be resumed as active goals');
    });

    test('Metro tile source labels format correctly for goal vs free read', () {
      String getGoalSourceLabel(bool isThai, String goalName) =>
          isThai ? 'เป้าหมาย: $goalName' : 'Goal: $goalName';
      String getGoalBadge(bool isThai) =>
          isThai ? '🎯 เป้าหมาย' : '🎯 Goal';
      String getFreeReadSourceLabel(bool isThai) =>
          isThai ? 'โหมดอ่านอิสระ' : 'Free Read';
      String getFreeReadBadge(bool isThai) =>
          isThai ? 'อ่านอิสระ' : 'Free Read';

      // Thai case
      expect(getGoalSourceLabel(true, 'คอตัม 30 วัน'), 'เป้าหมาย: คอตัม 30 วัน');
      expect(getGoalBadge(true), '🎯 เป้าหมาย');
      expect(getFreeReadSourceLabel(true), 'โหมดอ่านอิสระ');
      expect(getFreeReadBadge(true), 'อ่านอิสระ');

      // English case
      expect(getGoalSourceLabel(false, 'Khatam 30 Days'), 'Goal: Khatam 30 Days');
      expect(getGoalBadge(false), '🎯 Goal');
      expect(getFreeReadSourceLabel(false), 'Free Read');
      expect(getFreeReadBadge(false), 'Free Read');
    });
  });

  group('Surah Shortcuts No-Fake-Goal & Per-Surah Recent Read Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('shortcut guards reject legacy phantom ids, slugs, and names', () {
      expect(
        isShortcutProfileMeta(
          id: shortcutMulkId,
          name: 'Custom Name',
          slug: 'custom',
        ),
        isTrue,
      );
      expect(
        isShortcutProfileMeta(
          id: 'abc-123',
          name: 'Surah Yasin',
          slug: 'shortcut_yasin',
        ),
        isTrue,
      );
      expect(
        isShortcutProfileMeta(
          id: 'abc-456',
          name: 'Al-Mulk Shortcut',
          slug: 'mulk_custom',
        ),
        isTrue,
      );
      expect(
        isShortcutProfileMeta(
          id: 'goal-uuid',
          name: 'Al-Mulk Daily',
          slug: 'al_mulk_daily',
        ),
        isFalse,
      );
    });

    test('Medina page-to-surah range helpers handle shared boundary pages', () {
      final kahfRange = getMedinaSurahPageRange(18);
      expect(kahfRange.startPage, 293);
      expect(kahfRange.endPage, 304);

      final mulkRange = getMedinaSurahPageRange(67);
      expect(mulkRange.startPage, 562);
      expect(mulkRange.endPage, 564);

      // Page 564 contains both end of Al-Mulk (67) and start of Al-Qalam (68).
      expect(getPrimarySurahOnMedinaPage(564, preferredSurahId: 67), 67);
      // Advancing to page 565 leaves Al-Mulk and enters Al-Qalam.
      expect(getPrimarySurahOnMedinaPage(565, preferredSurahId: 67), 68);
    });

    test('MushafReadingProvider deduplicates Free Read recents per Surah', () async {
      final provider = MushafReadingProvider();
      // Wait for initial load
      while (!provider.isLoaded) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      final freeProfile = provider.freeReadProfileForMushaf(1);
      await provider.updateProgress(
        profileId: freeProfile.id,
        pageNumber: 296,
        surahId: 18,
      );
      await provider.updateProgress(
        profileId: freeProfile.id,
        pageNumber: 563,
        surahId: 67,
      );

      // Both Surahs remain available independently even after reading another Surah.
      final kahfRecent = provider.latestRecentForSurah(18);
      final mulkRecent = provider.latestRecentForSurah(67);
      expect(kahfRecent?.pageNumber, 296);
      expect(kahfRecent?.recentKey, 'free:surah:18');
      expect(mulkRecent?.pageNumber, 563);
      expect(mulkRecent?.recentKey, 'free:surah:67');

      // Start Over resets Al-Kahf to startPage (293), hiding resume prompt for Al-Kahf
      // while leaving Al-Mulk intact.
      await provider.recordFreeReadPage(
        pageNumber: 293,
        mushafId: 1,
        surahId: 18,
      );
      expect(provider.latestRecentForSurah(18), isNull);
      expect(provider.latestRecentForSurah(67)?.pageNumber, 563);

      provider.dispose();
    });

    test('MushafReadingProvider excludes non-604p IndoPak mushafs from Medina lookup', () async {
      SharedPreferences.setMockInitialValues({
        mushafStoreKey: jsonEncode({
          'profiles': [],
          'pageBookmarks': [],
          'verseBookmarks': [],
          'recentReadings': [
            {
              'mushafId': 6,
              'pageNumber': 296,
              'profileId': 'mushaf-free-6',
              'surahId': 18,
              'recentKey': 'free:surah:18',
              'updatedAt': DateTime.now().toIso8601String(),
            },
          ],
          'deletedPageBookmarkKeys': [],
          'deletedVerseBookmarkKeys': [],
        }),
      });
      final provider = MushafReadingProvider();
      while (!provider.isLoaded) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      expect(provider.latestRecentForSurah(18), isNull);
      provider.dispose();
    });

    test('LocalReadingProvider strips legacy shortcut profiles and phantom recents on load', () async {
      final now = DateTime.now().toIso8601String();
      SharedPreferences.setMockInitialValues({
        'thai_quran_local_reading_store_v1': jsonEncode({
          'profiles': [
            {
              'id': shortcutKahfId,
              'userId': 'local',
              'name': 'Al-Kahf Shortcut',
              'slug': 'shortcut_kahf',
              'startSurahId': '18',
              'startVerseId': '1',
              'targetSurahId': '18',
              'targetVerseId': '110',
              'currentSurahId': '18',
              'currentVerseId': '98',
              'lastViewedSurahId': '18',
              'lastViewedVerseId': '98',
              'sortOrder': 1001,
              'isArchived': false,
              'createdAt': now,
              'updatedAt': now,
            },
            {
              'id': 'real-goal-1',
              'userId': 'local',
              'name': 'Daily Khatam',
              'slug': 'daily_khatam',
              'startSurahId': '1',
              'startVerseId': '1',
              'targetSurahId': '114',
              'targetVerseId': '6',
              'currentSurahId': '2',
              'currentVerseId': '10',
              'lastViewedSurahId': '2',
              'lastViewedVerseId': '10',
              'sortOrder': 1,
              'isArchived': false,
              'createdAt': now,
              'updatedAt': now,
            },
          ],
          'categories': [],
          'bookmarks': [],
          'recentReadings': [
            {
              'id': 'phantom-recent',
              'userId': 'local',
              'surahId': '18',
              'verseId': '98',
              'profileId': shortcutKahfId,
              'readAt': now,
            },
          ],
        }),
      });

      final provider = LocalReadingProvider();
      // Wait for load() to finish by triggering an async call guarded by _loadCompleter.
      await provider.addRecentReading(
        verse: toVerseRef('67', '12'),
        forceFreeRead: true,
      );

      expect(
        provider.profiles.any((p) => p.id == shortcutKahfId),
        isFalse,
      );
      expect(
        provider.profiles.any((p) => p.id == 'real-goal-1'),
        isTrue,
      );
      expect(provider.latestRecentForSurah(18), isNull);
      expect(provider.latestRecentForSurah(67)?.verse.verseId, '12');

      // Start Over resets Meaning recent to Ayah 1 -> hides resume prompt
      await provider.addRecentReading(
        verse: toVerseRef('67', '1'),
        forceFreeRead: true,
      );
      expect(provider.latestRecentForSurah(67), isNull);

      provider.dispose();
    });

    test('UTC serialization and future-timestamp clamping prevent stale overrides', () async {
      final localTime = DateTime(2026, 11, 13, 12, 28);
      final recentRow = MushafRecentReading(
        mushafId: 2,
        pageNumber: 297,
        profileId: 'mushaf-free-2',
        surahId: 18,
        recentKey: 'free:surah:18',
        updatedAt: localTime,
      );
      expect(recentRow.toJson()['updatedAt'].toString().endsWith('Z'), isTrue);

      final recentInput = RecentReadingInput(
        userId: 'user-1',
        surahId: '18',
        verseId: '50',
        verseKey: '18:50',
        updatedAt: localTime,
      );
      expect(recentInput.toDbRow()['read_at'].toString().endsWith('Z'), isTrue);

      final futureBogus = DateTime.now().toUtc().add(const Duration(hours: 7));
      final currentReal = DateTime.now().toUtc();
      SharedPreferences.setMockInitialValues({
        mushafStoreKey: jsonEncode({
          'profiles': [],
          'pageBookmarks': [],
          'verseBookmarks': [],
          'recentReadings': [
            {
              'mushafId': 1,
              'pageNumber': 296,
              'profileId': 'mushaf-free-1',
              'surahId': 18,
              'recentKey': 'free:surah:18',
              'updatedAt': futureBogus.toIso8601String(),
            },
            {
              'mushafId': 2,
              'pageNumber': 297,
              'profileId': 'mushaf-free-2',
              'surahId': 18,
              'recentKey': 'free:surah:18',
              'updatedAt': currentReal.toIso8601String(),
            },
          ],
          'deletedPageBookmarkKeys': [],
          'deletedVerseBookmarkKeys': [],
        }),
      });

      final mushafProvider = MushafReadingProvider();
      while (!mushafProvider.isLoaded) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      // Clamping the 7-hour future row allows the real current page 297 to win.
      expect(mushafProvider.latestRecentForSurah(18)?.pageNumber, 297);
      mushafProvider.dispose();
    });
  });
}
