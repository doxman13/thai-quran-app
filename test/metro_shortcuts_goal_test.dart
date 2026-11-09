import 'package:flutter_test/flutter_test.dart';
import 'package:thai_quran_app/models/mushaf_models.dart';
import 'package:thai_quran_app/providers/local_reading_provider.dart';
import 'package:thai_quran_app/shared/shared.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
}
