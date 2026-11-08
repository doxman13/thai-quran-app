import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thai_quran_app/providers/settings_provider.dart';
import 'package:thai_quran_app/shared/localization.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Apple Login Localization Tests', () {
    testWidgets('Thai Apple login strings', (tester) async {
      SharedPreferences.setMockInitialValues({'languageCode': 'th'});
      final settings = SettingsProvider();
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: Builder(
            builder: (context) {
              expect(context.tr('sign_in_with_apple'), 'ลงชื่อเข้าใช้ด้วย Apple');
              expect(context.tr('connecting_to_apple'), 'กำลังเชื่อมต่อกับ Apple...');
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('English Apple login strings', (tester) async {
      SharedPreferences.setMockInitialValues({'languageCode': 'en'});
      final settings = SettingsProvider();
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: Builder(
            builder: (context) {
              expect(context.tr('sign_in_with_apple'), 'Sign in with Apple');
              expect(context.tr('connecting_to_apple'), 'Connecting to Apple...');
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('Malay Apple login strings (falls back to en or ms dictionary)', (tester) async {
      SharedPreferences.setMockInitialValues({'languageCode': 'ms'});
      final settings = SettingsProvider();
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: Builder(
            builder: (context) {
              expect(context.tr('sign_in_with_apple'), isNotEmpty);
              expect(context.tr('connecting_to_apple'), isNotEmpty);
              return const SizedBox();
            },
          ),
        ),
      );
    });
  });
}
