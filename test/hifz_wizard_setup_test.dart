import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thai_quran_app/data/quran_foundation_repository.dart';
import 'package:thai_quran_app/data/quran_repository.dart';
import 'package:thai_quran_app/models/hifz_session_config.dart';
import 'package:thai_quran_app/providers/settings_provider.dart';
import 'package:thai_quran_app/screens/hifz_wizard_setup_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HifzWizardSetupScreen Initialization', () {
    test('Constructor sets default parameters correctly', () {
      final quranRepo = QuranRepository();
      final foundationRepo = QuranFoundationRepository();

      final screen = HifzWizardSetupScreen(
        quranRepository: quranRepo,
        foundationRepository: foundationRepo,
      );

      expect(screen.initialStep, 0);
      expect(screen.initialMode, isNull);
      expect(screen.initialSurah, isNull);
    });

    test('Constructor accepts pre-configured parameters', () {
      final quranRepo = QuranRepository();
      final foundationRepo = QuranFoundationRepository();

      final screen = HifzWizardSetupScreen(
        quranRepository: quranRepo,
        foundationRepository: foundationRepo,
        initialMode: HifzSessionType.review,
        initialSurah: 67,
        initialStartVerse: 1,
        initialEndVerse: 10,
        initialRepeatStart: 1,
        initialStep: 1,
      );

      expect(screen.initialMode, HifzSessionType.review);
      expect(screen.initialSurah, 67);
      expect(screen.initialStartVerse, 1);
      expect(screen.initialEndVerse, 10);
      expect(screen.initialRepeatStart, 1);
      expect(screen.initialStep, 1);
    });

    test('Constructor accepts multi-surah review range parameters', () {
      final quranRepo = QuranRepository();
      final foundationRepo = QuranFoundationRepository();

      final screen = HifzWizardSetupScreen(
        quranRepository: quranRepo,
        foundationRepository: foundationRepo,
        initialMode: HifzSessionType.review,
        initialStartSurah: 78,
        initialEndSurah: 114,
        initialStep: 1,
      );

      expect(screen.initialMode, HifzSessionType.review);
      expect(screen.initialStartSurah, 78);
      expect(screen.initialEndSurah, 114);
      expect(screen.initialStep, 1);
    });

    test('Constructor accepts page range review parameters', () {
      final quranRepo = QuranRepository();
      final foundationRepo = QuranFoundationRepository();

      final screen = HifzWizardSetupScreen(
        quranRepository: quranRepo,
        foundationRepository: foundationRepo,
        initialMode: HifzSessionType.review,
        initialStartPage: 582,
        initialEndPage: 604,
        initialStep: 1,
      );

      expect(screen.initialMode, HifzSessionType.review);
      expect(screen.initialStartPage, 582);
      expect(screen.initialEndPage, 604);
      expect(screen.initialStep, 1);
    });

    test('Constructor accepts Surah list navigation parameters with initialStep: 0 and omitted initialMode', () {
      final quranRepo = QuranRepository();
      final foundationRepo = QuranFoundationRepository();

      final screen = HifzWizardSetupScreen(
        quranRepository: quranRepo,
        foundationRepository: foundationRepo,
        initialSurah: 36,
        initialStartVerse: 1,
        initialEndVerse: 5,
        initialStep: 0,
      );

      expect(screen.initialStep, 0);
      expect(screen.initialMode, isNull);
      expect(screen.initialSurah, 36);
      expect(screen.initialStartVerse, 1);
      expect(screen.initialEndVerse, 5);
    });

    testWidgets('opens directly to Portion selection without legacy Step 1 and switches modes inline', (tester) async {
      SharedPreferences.setMockInitialValues({'languageCode': 'en'});
      final settings = SettingsProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HifzWizardSetupScreen(
                            quranRepository: QuranRepository(),
                            foundationRepository: QuranFoundationRepository(),
                            initialMode: HifzSessionType.newVerses,
                            initialSurah: 67,
                            initialStartVerse: 1,
                            initialEndVerse: 5,
                            initialStep: 1,
                          ),
                        ),
                      );
                    },
                    child: const Text('Open Wizard'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Open Wizard'));
      await tester.pumpAndSettle();

      // Should land directly on Portion (no legacy '1. Goal' / 'What is your goal today?')
      expect(find.text('What is your goal today?'), findsNothing);
      expect(find.text('1. Portion'), findsOneWidget);
      expect(find.text('2. Confirm'), findsOneWidget);
      expect(find.text('Select Quran Portion'), findsOneWidget);

      // Can switch inline to Review without a separate step
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      expect(find.text('Select Review Scope'), findsOneWidget);

      // Next goes to Confirm; Back returns to Portion (never to removed Step 1)
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();
      expect(find.text('Back'), findsOneWidget);

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Select Review Scope'), findsOneWidget);
      expect(find.text('What is your goal today?'), findsNothing);

      // AppBar close button on Portion exits wizard cleanly
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Open Wizard'), findsOneWidget);
    });
  });
}
