import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thai_quran_app/services/guest_lifecycle_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GuestLifecycleService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('isGuestInactiveExpired returns false and initializes on first run', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(GuestLifecycleService.guestLastActiveKey), isNull);

      final isExpired = await GuestLifecycleService.isGuestInactiveExpired(prefs);
      expect(isExpired, isFalse);
      expect(prefs.getString(GuestLifecycleService.guestLastActiveKey), isNotNull);
    });

    test('isGuestInactiveExpired returns false when active within 30 days', () async {
      final prefs = await SharedPreferences.getInstance();
      final tenDaysAgo = DateTime.now().subtract(const Duration(days: 10));
      await prefs.setString(
        GuestLifecycleService.guestLastActiveKey,
        tenDaysAgo.toIso8601String(),
      );

      final isExpired = await GuestLifecycleService.isGuestInactiveExpired(prefs);
      expect(isExpired, isFalse);
    });

    test('isGuestInactiveExpired returns true when inactive for >= 30 days', () async {
      final prefs = await SharedPreferences.getInstance();
      final thirtyOneDaysAgo = DateTime.now().subtract(const Duration(days: 31));
      await prefs.setString(
        GuestLifecycleService.guestLastActiveKey,
        thirtyOneDaysAgo.toIso8601String(),
      );

      final isExpired = await GuestLifecycleService.isGuestInactiveExpired(prefs);
      expect(isExpired, isTrue);
    });

    test('touchGuestActivity updates last active timestamp', () async {
      final prefs = await SharedPreferences.getInstance();
      final oldDate = DateTime.now().subtract(const Duration(days: 5));
      await prefs.setString(
        GuestLifecycleService.guestLastActiveKey,
        oldDate.toIso8601String(),
      );

      await GuestLifecycleService.touchGuestActivity(prefs);
      final updatedStr = prefs.getString(GuestLifecycleService.guestLastActiveKey);
      expect(updatedStr, isNotNull);
      final updatedDate = DateTime.parse(updatedStr!);
      expect(DateTime.now().difference(updatedDate).inMinutes, lessThan(1));
    });

    test('bookmark warning preference defaults to true and respects suppression', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await GuestLifecycleService.shouldPromptGuestBookmarkWarning(), isTrue);

      await GuestLifecycleService.setSuppressGuestBookmarkWarning(true);
      expect(await GuestLifecycleService.shouldPromptGuestBookmarkWarning(), isFalse);

      await GuestLifecycleService.setSuppressGuestBookmarkWarning(false);
      expect(await GuestLifecycleService.shouldPromptGuestBookmarkWarning(), isTrue);
    });
  });
}
