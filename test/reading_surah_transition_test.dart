import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thai_quran_app/data/offline_surah_names.dart';
import 'package:thai_quran_app/data/quran_repository.dart';
import 'package:thai_quran_app/models/verse.dart';
import 'package:thai_quran_app/providers/local_reading_provider.dart';
import 'package:thai_quran_app/providers/mushaf_audio_provider.dart';
import 'package:thai_quran_app/providers/notes_provider.dart';
import 'package:thai_quran_app/providers/progress_provider.dart';
import 'package:thai_quran_app/providers/settings_provider.dart';
import 'package:thai_quran_app/providers/stats_provider.dart';
import 'package:thai_quran_app/providers/supabase_provider.dart';
import 'package:thai_quran_app/providers/thai_text_protection_provider.dart';
import 'package:thai_quran_app/providers/translation_manager_provider.dart';
import 'package:thai_quran_app/screens/reading_screen.dart';
import 'package:thai_quran_app/widgets/verse_card.dart';

class _FakeReadingQuranRepository extends QuranRepository {
  static final Map<String, int> _verseCounts = {
    '1': 7,
    '2': 5,
    '114': 6,
  };

  @override
  Future<void> init() async {}

  @override
  List<Verse> getSurahVerses(String surahId) {
    final count = _verseCounts[surahId] ?? 3;
    return List.generate(
      count,
      (i) => Verse(
        id: '${i + 1}',
        surahId: surahId,
        thaiV3: 'คำแปลไทย ซูเราะฮฺ $surahId อายะฮฺ ${i + 1}',
        thaiV2: 'คำแปลไทย ซูเราะฮฺ $surahId อายะฮฺ ${i + 1}',
        english: 'English translation $surahId:${i + 1}',
        arabic: 'بِسْمِ اللَّهِ $surahId:${i + 1}',
      ),
    );
  }

  @override
  Verse? getVerse(String surahId, String verseId) {
    final verses = getSurahVerses(surahId);
    for (final v in verses) {
      if (v.id == verseId) return v;
    }
    return null;
  }

  @override
  Future<String> fetchArabicVerse(String surahId, String verseId) async {
    return 'بِسْمِ اللَّهِ $surahId:$verseId';
  }

  @override
  String getSurahName(String surahId, {bool? isThai}) {
    return surahDisplayName(surahId, isThai: isThai ?? true);
  }
}

class _FakeBuildContext extends Fake implements BuildContext {}

class _NestedHorizontalOverscrollNotification extends OverscrollNotification {
  final int customDepth;

  _NestedHorizontalOverscrollNotification({
    required super.metrics,
    required super.context,
    required super.overscroll,
    required this.customDepth,
  });

  @override
  int get depth => customDepth;
}

FixedScrollMetrics _metrics(Axis axis) {
  return FixedScrollMetrics(
    minScrollExtent: 0,
    maxScrollExtent: 400,
    pixels: 0,
    viewportDimension: 400,
    axisDirection: axis == Axis.horizontal ? AxisDirection.right : AxisDirection.down,
    devicePixelRatio: 1.0,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'keepAwake': false});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
      'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
      (message) async => const StandardMessageCodec().encodeMessage(<Object?>[]),
    );
    try {
      await Supabase.initialize(
        url: 'https://example.supabase.co',
        publishableKey: 'test-anon-key',
        authOptions: const FlutterAuthClientOptions(
          localStorage: EmptyLocalStorage(),
        ),
      );
    } catch (_) {
      // Ignore if already initialized in test isolate.
    }
  });

  group('detectHorizontalSurahOverscrollDirection unit tests', () {
    test('ignores vertical and nested overscroll notifications', () {
      final ctx = _FakeBuildContext();

      final verticalAtStart = OverscrollNotification(
        metrics: _metrics(Axis.vertical),
        context: ctx,
        overscroll: -55,
      );
      expect(
        detectHorizontalSurahOverscrollDirection(
          verticalAtStart,
          currentIndex: 0,
          verseCount: 7,
        ),
        0,
      );

      final verticalAtEnd = OverscrollNotification(
        metrics: _metrics(Axis.vertical),
        context: ctx,
        overscroll: 55,
      );
      expect(
        detectHorizontalSurahOverscrollDirection(
          verticalAtEnd,
          currentIndex: 6,
          verseCount: 7,
        ),
        0,
      );

      final nestedHorizontal = _NestedHorizontalOverscrollNotification(
        metrics: _metrics(Axis.horizontal),
        context: ctx,
        overscroll: -55,
        customDepth: 1,
      );
      expect(nestedHorizontal.depth, greaterThan(0));
      expect(
        detectHorizontalSurahOverscrollDirection(
          nestedHorizontal,
          currentIndex: 0,
          verseCount: 7,
        ),
        0,
      );
    });

    test('detects root horizontal overscroll only beyond threshold at boundaries', () {
      final ctx = _FakeBuildContext();

      final smallLeft = OverscrollNotification(
        metrics: _metrics(Axis.horizontal),
        context: ctx,
        overscroll: -20,
      );
      expect(
        detectHorizontalSurahOverscrollDirection(
          smallLeft,
          currentIndex: 0,
          verseCount: 7,
        ),
        0,
      );

      final bigLeftAtStart = OverscrollNotification(
        metrics: _metrics(Axis.horizontal),
        context: ctx,
        overscroll: -45,
      );
      expect(
        detectHorizontalSurahOverscrollDirection(
          bigLeftAtStart,
          currentIndex: 0,
          verseCount: 7,
        ),
        -1,
      );

      final bigRightAtLast = OverscrollNotification(
        metrics: _metrics(Axis.horizontal),
        context: ctx,
        overscroll: 45,
      );
      expect(
        detectHorizontalSurahOverscrollDirection(
          bigRightAtLast,
          currentIndex: 6,
          verseCount: 7,
        ),
        1,
      );
    });
  });

  group('ReadingScreen surah transition widget tests', () {
    Widget buildHarness({
      required String initialSurah,
      int initialVerseIndex = 0,
      String languageCode = 'th',
    }) {
      SharedPreferences.setMockInitialValues({
        'languageCode': languageCode,
        'keepAwake': false,
      });
      final settings = SettingsProvider();
      final progress = ProgressProvider();
      final localReading = LocalReadingProvider();
      final transManager = TranslationManagerProvider();
      final thaiProtection = ThaiTextProtectionProvider();
      final audio = MushafAudioProvider();
      final notes = NotesProvider();
      final supabase = SupabaseProvider();
      final stats = StatsProvider();

      return MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<ProgressProvider>.value(value: progress),
          ChangeNotifierProvider<LocalReadingProvider>.value(value: localReading),
          ChangeNotifierProvider<TranslationManagerProvider>.value(
            value: transManager,
          ),
          ChangeNotifierProvider<ThaiTextProtectionProvider>.value(
            value: thaiProtection,
          ),
          ChangeNotifierProvider<MushafAudioProvider>.value(value: audio),
          ChangeNotifierProvider<NotesProvider>.value(value: notes),
          ChangeNotifierProvider<SupabaseProvider>.value(value: supabase),
          ChangeNotifierProvider<StatsProvider>.value(value: stats),
        ],
        child: MaterialApp(
          home: ReadingScreen(
            repository: _FakeReadingQuranRepository(),
            initialSurah: initialSurah,
            initialVerseIndex: initialVerseIndex,
            saveToFreeReadOnly: true,
          ),
        ),
      );
    }

    Future<void> pumpPastSurahLoad(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
    }

    testWidgets(
      'vertical swipe down on Surah 2 Info Page and Verse 1 stays on Surah 2 and does not jump to Surah 1',
      (tester) async {
        await tester.pumpWidget(
          buildHarness(initialSurah: '2', initialVerseIndex: 0),
        );
        await pumpPastSurahLoad(tester);

        expect(find.text('อัลบะเกาะเราะฮฺ'), findsWidgets);
        expect(find.text('ซูเราะฮฺที่ 2 · 5 อายะฮฺ · มะดะนียะฮฺ'), findsOneWidget);
        expect(find.text('เริ่มอ่าน'), findsOneWidget);

        // Downward vertical swipe on Info Page does not jump to Surah 1
        final pageFinder = find.byType(PageView);
        expect(pageFinder, findsOneWidget);
        await tester.drag(pageFinder, const Offset(0, 420));
        await pumpPastSurahLoad(tester);

        expect(find.text('ซูเราะฮฺที่ 2 · 5 อายะฮฺ · มะดะนียะฮฺ'), findsOneWidget);
        expect(find.byKey(const ValueKey('1_7')), findsNothing);

        // Tap Start Reading -> enters Surah 2 Verse 1
        final startBtn1 = find.text('เริ่มอ่าน');
        await tester.ensureVisible(startBtn1);
        await tester.pump();
        await tester.tap(startBtn1);
        await pumpPastSurahLoad(tester);
        expect(find.byKey(const ValueKey('2_1')), findsOneWidget);

        // Downward vertical swipe on Verse 1 stays on Verse 1 (no jump to Surah 1)
        await tester.drag(pageFinder, const Offset(0, 420));
        await pumpPastSurahLoad(tester);

        expect(find.byKey(const ValueKey('2_1')), findsOneWidget);
        expect(find.byKey(const ValueKey('1_7')), findsNothing);
      },
    );

    testWidgets(
      'swiping horizontally past last verse of Surah 1 transitions straight to Surah 2 Info Page and Start Reading enters Verse 1',
      (tester) async {
        await tester.pumpWidget(
          buildHarness(initialSurah: '1', initialVerseIndex: 6),
        );
        await pumpPastSurahLoad(tester);

        expect(find.byKey(const ValueKey('1_7')), findsOneWidget);

        // Swipe left past verse 7 (index 6 -> page 7) into sentinel slot (page 8).
        final pageFinder = find.byType(PageView);
        await tester.drag(pageFinder, const Offset(-500, 0));
        await pumpPastSurahLoad(tester);

        // Immediately opens Surah 2 Info Page with no End-of-Surah chooser or celebration dialog.
        expect(find.text('ซูเราะฮฺที่ 2 · 5 อายะฮฺ · มะดะนียะฮฺ'), findsOneWidget);
        expect(find.text('เริ่มอ่าน'), findsOneWidget);
        expect(find.text('สิ้นสุดซูเราะฮฺแล้ว'), findsNothing);
        expect(find.text('End of Surah'), findsNothing);
        expect(find.text('อ่านสูเราะฮ์จบแล้ว'), findsNothing);
        expect(find.text('Surah completed'), findsNothing);
        expect(find.textContaining('ซูเราะฮฺก่อนหน้า'), findsNothing);
        expect(find.textContaining('Previous Surah'), findsNothing);

        final startBtn2 = find.text('เริ่มอ่าน');
        await tester.ensureVisible(startBtn2);
        await tester.pump();
        await tester.tap(startBtn2);
        await pumpPastSurahLoad(tester);
        expect(find.byKey(const ValueKey('2_1')), findsOneWidget);
      },
    );

    testWidgets(
      'last verse of Surah 114 has no extra completion page and stays cleanly on Surah 114',
      (tester) async {
        await tester.pumpWidget(
          buildHarness(initialSurah: '114', initialVerseIndex: 5),
        );
        await pumpPastSurahLoad(tester);

        expect(find.byKey(const ValueKey('114_6')), findsOneWidget);

        final pageView = tester.widget<PageView>(find.byType(PageView));
        // 1 Intro page + 6 verse pages = 7 (no extra completion page)
        expect(pageView.childrenDelegate.estimatedChildCount, 7);

        await tester.drag(find.byType(PageView), const Offset(-450, 0));
        await pumpPastSurahLoad(tester);

        expect(find.byKey(const ValueKey('114_6')), findsOneWidget);
        expect(find.text('สิ้นสุดซูเราะฮฺแล้ว'), findsNothing);
        expect(find.text('End of Surah'), findsNothing);
      },
    );

    testWidgets(
      'Info Page separates Bismillah/metadata from Verse 1 and hides duplicate Surah name when menu is visible (360x780 TH)',
      (tester) async {
        final overflowErrors = <FlutterErrorDetails>[];
        final previousOnError = FlutterError.onError;
        tester.view.physicalSize = const Size(360, 780);
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

        try {
          await tester.pumpWidget(
            buildHarness(
              initialSurah: '1',
              initialVerseIndex: 0,
              languageCode: 'th',
            ),
          );
          await pumpPastSurahLoad(tester);

          // Page 0: Intro Page only (no VerseCard yet), and menu visible hides main-content header row
          expect(find.text('บทนำ'), findsOneWidget);
          expect(find.text('ซูเราะฮฺที่ 1 · 7 อายะฮฺ · มักกียะฮฺ'), findsOneWidget);
          expect(find.text('เริ่มอ่าน'), findsOneWidget);
          expect(find.byType(VerseCard), findsNothing);
          expect(find.text('อัลฟาติหะฮฺ : 1/7'), findsNothing);
          expect(find.text('เมนู'), findsNothing);

          // Tap Start Reading -> moves cleanly to Page 1 (Verse 1); page change auto-hides menu
          await tester.tap(find.text('เริ่มอ่าน'));
          await pumpPastSurahLoad(tester);

          expect(find.byKey(const ValueKey('1_1')), findsOneWidget);
          // With menu hidden after page change, collapsed main-content header & Menu pill show
          expect(find.text('อัลฟาติหะฮฺ : 1/7'), findsOneWidget);
          expect(find.text('เมนู'), findsOneWidget);

          // Tap Menu pill to restore top/bottom menu -> duplicate main-content Surah header disappears
          await tester.tap(find.text('เมนู'));
          await pumpPastSurahLoad(tester);
          expect(find.text('อัลฟาติหะฮฺ : 1/7'), findsNothing);
          expect(find.text('เมนู'), findsNothing);
          expect(find.text('อัลฟาติหะฮฺ'), findsOneWidget);
        } finally {
          FlutterError.onError = previousOnError;
        }

        expect(overflowErrors, isEmpty);
      },
    );

    testWidgets(
      'English Info Page renders cleanly on 360x780 with zero overflow and navigates to Verse 1',
      (tester) async {
        final overflowErrors = <FlutterErrorDetails>[];
        final previousOnError = FlutterError.onError;
        tester.view.physicalSize = const Size(360, 780);
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

        try {
          await tester.pumpWidget(
            buildHarness(
              initialSurah: '1',
              initialVerseIndex: 0,
              languageCode: 'en',
            ),
          );
          await pumpPastSurahLoad(tester);

          expect(find.text('Intro'), findsOneWidget);
          expect(find.text('Al-Fatihah'), findsWidgets);
          expect(find.text('Surah 1 · 7 Verses · Meccan'), findsOneWidget);
          expect(find.text('Start Reading'), findsOneWidget);
          expect(find.byType(VerseCard), findsNothing);

          await tester.tap(find.text('Start Reading'));
          await pumpPastSurahLoad(tester);

          expect(find.byKey(const ValueKey('1_1')), findsOneWidget);
          expect(find.text('Intro'), findsNothing);
        } finally {
          FlutterError.onError = previousOnError;
        }

        expect(overflowErrors, isEmpty);
      },
    );
  });
}
