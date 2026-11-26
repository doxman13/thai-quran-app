import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thai_quran_app/data/quran_foundation_repository.dart';
import 'package:thai_quran_app/data/quran_repository.dart';
import 'package:thai_quran_app/providers/local_reading_provider.dart';
import 'package:thai_quran_app/providers/mushaf_reading_provider.dart';
import 'package:thai_quran_app/providers/settings_provider.dart';
import 'package:thai_quran_app/providers/supabase_provider.dart';
import 'package:thai_quran_app/screens/goals_screen.dart';
import 'package:thai_quran_app/shared/shared.dart';

class _LoggedInSupabaseProvider extends SupabaseProvider {
  @override
  bool get isLoggedIn => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

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
    } catch (_) {}
  });

  Widget buildGoalsHarness({
    required LocalReadingProvider localReading,
    required MushafReadingProvider mushafReading,
    required SettingsProvider settings,
    SupabaseProvider? supabase,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider<LocalReadingProvider>.value(value: localReading),
        ChangeNotifierProvider<MushafReadingProvider>.value(
          value: mushafReading,
        ),
        ChangeNotifierProvider<SupabaseProvider>.value(
          value: supabase ?? SupabaseProvider(),
        ),
      ],
      child: MaterialApp(
        home: GoalsScreen(
          repository: QuranRepository(),
          foundationRepository: QuranFoundationRepository(),
        ),
      ),
    );
  }

  group('GoalsScreen Free-Read Cleanup', () {
    testWidgets(
      'omits continue-reading and free-read cards when active goals exist alongside Free Read',
      (tester) async {
        final overflowErrors = <FlutterErrorDetails>[];
        final previousOnError = FlutterError.onError;
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        FlutterError.onError = (details) {
          if (details.exceptionAsString().contains('RenderFlex overflowed')) {
            overflowErrors.add(details);
          } else {
            previousOnError?.call(details);
          }
        };

        SharedPreferences.setMockInitialValues({'languageCode': 'th'});
        final settings = SettingsProvider();
        final localReading = LocalReadingProvider();
        final mushafReading = MushafReadingProvider();

        try {
          await tester.pumpWidget(
            buildGoalsHarness(
              localReading: localReading,
              mushafReading: mushafReading,
              settings: settings,
              supabase: _LoggedInSupabaseProvider(),
            ),
          );
          await tester.pump(const Duration(milliseconds: 50));

          await localReading.createProfile(
            name: 'My Meaning Khatam',
            start: const VerseRef(surahId: '1', verseId: '1', verseKey: '1:1'),
            target: const VerseRef(
              surahId: '2',
              verseId: '286',
              verseKey: '2:286',
            ),
          );
          await mushafReading.createPageRangeProfile(
            name: 'My Mushaf Plan',
            mushafId: 1,
            startPage: 1,
            targetPage: 604,
            planMode: 'page_range',
          );
          // Switch active profiles back to Free Read to reproduce the old bug.
          final freeMeaning = localReading.freeReadProfile;
          if (freeMeaning != null) {
            await localReading.setActiveProfile(freeMeaning.id);
          }
          await mushafReading.openUnifiedFreeRead();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));

          // Goals should appear cleanly without any top Continue/Free-Read card.
          expect(find.text('เป้าหมายล่าสุด (มุศหัฟ)'), findsNothing);
          expect(find.text('เป้าหมายล่าสุด (แปลความหมาย)'), findsNothing);
          expect(find.text('เริ่มต้นอ่านต่อวันนี้'), findsNothing);
          expect(find.text('อ่านอิสระ'), findsNothing);
          expect(find.text('เปิดมุศหัฟ 604 หน้า'), findsNothing);

          await tester.scrollUntilVisible(
            find.text('My Meaning Khatam'),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text('My Meaning Khatam'), findsOneWidget);

          await tester.scrollUntilVisible(
            find.text('My Mushaf Plan'),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text('My Mushaf Plan'), findsOneWidget);
        } finally {
          FlutterError.onError = previousOnError;
        }

        expect(overflowErrors, isEmpty);
      },
    );

    testWidgets(
      'decluttered goal creation modal uses segmented toggle and collapses preset range on 360px phone',
      (tester) async {
        final overflowErrors = <FlutterErrorDetails>[];
        final previousOnError = FlutterError.onError;
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        FlutterError.onError = (details) {
          if (details.exceptionAsString().contains('RenderFlex overflowed')) {
            overflowErrors.add(details);
          } else {
            previousOnError?.call(details);
          }
        };

        SharedPreferences.setMockInitialValues({'languageCode': 'th'});
        final settings = SettingsProvider();
        final localReading = LocalReadingProvider();
        final mushafReading = MushafReadingProvider();

        try {
          await tester.pumpWidget(
            buildGoalsHarness(
              localReading: localReading,
              mushafReading: mushafReading,
              settings: settings,
              supabase: _LoggedInSupabaseProvider(),
            ),
          );
          await tester.pump(const Duration(milliseconds: 50));

          await tester.tap(find.text('ตั้งเป้าหมายใหม่').first);
          await tester.pumpAndSettle();

          // Numbered prefixes & header subtitle removed; segmented mode labels visible
          expect(find.text('รูปแบบการอ่าน'), findsOneWidget);
          expect(find.text('ฉบับแปลความหมาย'), findsOneWidget);
          expect(find.text('มุศหัฟ 604 หน้า'), findsOneWidget);
          expect(find.text('1. เลือกรูปแบบการอ่าน'), findsNothing);

          // Switch to Mushaf mode via segmented toggle
          await tester.tap(find.text('มุศหัฟ 604 หน้า'));
          await tester.pumpAndSettle();

          // Tap Mushaf preset -> custom range collapses to summary row
          await tester.tap(find.text('ค็อตม์มุศหัฟ 604 หน้า').last);
          await tester.pumpAndSettle();
          expect(find.text('ขอบเขต: หน้า 1 – 604'), findsOneWidget);
          expect(find.text('รูปแบบการคำนวณหน้ามุศหัฟ'), findsNothing);

          // Expand custom range via 'ปรับเอง'
          await tester.tap(find.text('ปรับเอง'));
          await tester.pumpAndSettle();
          expect(find.text('รูปแบบการคำนวณหน้ามุศหัฟ'), findsOneWidget);
        } finally {
          FlutterError.onError = previousOnError;
        }

        expect(overflowErrors, isEmpty);
      },
    );
  });
}
