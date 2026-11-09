import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thai_quran_app/providers/settings_provider.dart';
import 'package:thai_quran_app/services/in_app_purchase_service.dart';
import 'package:thai_quran_app/shared/localization.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InAppPurchaseService Constants', () {
    test('Product IDs match standard store identifiers', () {
      expect(InAppPurchaseService.tipSmall, equals('tip_small'));
      expect(InAppPurchaseService.tipMedium, equals('tip_medium'));
      expect(InAppPurchaseService.tipLarge, equals('tip_large'));
      expect(
        InAppPurchaseService.productIds,
        containsAll(['tip_small', 'tip_medium', 'tip_large']),
      );
    });

    test('Singleton instance initializes consistently', () {
      final service1 = InAppPurchaseService();
      final service2 = InAppPurchaseService();
      expect(identical(service1, service2), isTrue);
    });
  });

  group('Support & Donation Localization Tests', () {
    testWidgets('Thai localization returns correct donation labels', (tester) async {
      SharedPreferences.setMockInitialValues({'languageCode': 'th'});
      final settings = SettingsProvider();
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: Builder(
            builder: (context) {
              expect(context.tr('support_developer'), contains('สนับสนุนโครงการ'));
              expect(context.tr('support_desc'), isNotEmpty);
              expect(context.tr('support_thank_you'), contains('ขอบคุณ'));
              expect(context.tr('support_web_btn'), contains('quran-th.com'));
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('English localization returns correct donation labels', (tester) async {
      SharedPreferences.setMockInitialValues({'languageCode': 'en'});
      final settings = SettingsProvider();
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: Builder(
            builder: (context) {
              expect(context.tr('support_developer'), 'Support the Project');
              expect(context.tr('support_desc'), isNotEmpty);
              expect(context.tr('support_thank_you'), contains('Thank you'));
              expect(context.tr('support_web_btn'), contains('quran-th.com'));
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('Malay localization returns correct donation labels', (tester) async {
      SharedPreferences.setMockInitialValues({'languageCode': 'ms'});
      final settings = SettingsProvider();
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: Builder(
            builder: (context) {
              expect(context.tr('support_developer'), 'Sokong Projek Al-Quran');
              expect(context.tr('support_desc'), isNotEmpty);
              expect(context.tr('support_thank_you'), contains('Terima kasih'));
              expect(context.tr('support_web_btn'), contains('quran-th.com'));
              return const SizedBox();
            },
          ),
        ),
      );
    });
  });
}
