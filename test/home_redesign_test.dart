import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thai_quran_app/data/quran_repository.dart';
import 'package:thai_quran_app/models/hifz_session_config.dart';
import 'package:thai_quran_app/models/tadabbur_note.dart';
import 'package:thai_quran_app/providers/local_reading_provider.dart';
import 'package:thai_quran_app/providers/mushaf_reading_provider.dart';
import 'package:thai_quran_app/providers/notes_provider.dart';
import 'package:thai_quran_app/providers/settings_provider.dart';
import 'package:thai_quran_app/providers/stats_provider.dart';
import 'package:thai_quran_app/providers/supabase_provider.dart';
import 'package:thai_quran_app/providers/translation_manager_provider.dart';
import 'package:thai_quran_app/screens/home_screen.dart';
import 'package:thai_quran_app/theme/app_theme.dart';
import 'package:thai_quran_app/widgets/home/home_community_preview.dart';
import 'package:thai_quran_app/widgets/home/home_continue_hero.dart';
import 'package:thai_quran_app/widgets/home/home_goals_snapshot.dart';
import 'package:thai_quran_app/widgets/home/home_header_strip.dart';
import 'package:thai_quran_app/widgets/home/home_hifz_resume_banner.dart';

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

  final lightColors = AppThemeColors.teal(isDark: false);

  Widget wrap(Widget child, {double textScale = 1.0}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
  }

  group('Modular Home Widgets', () {
    testWidgets('HomeHeaderStrip shows filled/outline flame without weekday dots',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          HomeHeaderStrip(
            displayName: 'Abdullah',
            streakCount: 7,
            hasReadToday: true,
            isThai: true,
            appColors: lightColors,
          ),
        ),
      );
      expect(find.text('ยินดีต้อนรับ, Abdullah'), findsOneWidget);
      expect(find.text('7 วัน'), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);

      await tester.pumpWidget(
        wrap(
          HomeHeaderStrip(
            displayName: 'Abdullah',
            streakCount: 7,
            hasReadToday: false,
            isThai: true,
            appColors: lightColors,
          ),
        ),
      );
      expect(find.byIcon(Icons.local_fire_department_outlined), findsOneWidget);
    });

    testWidgets('HomeContinueHero shows clean initial CTA + guest sync nudge',
        (tester) async {
      var signInTapped = false;
      await tester.pumpWidget(
        wrap(
          HomeContinueHero(
            hasHistory: false,
            isMushaf: false,
            modeBadge: 'เริ่มต้นอ่านอัลกุรอาน',
            mainTitle: 'อัลฟาติหะฮฺ · อายะฮฺที่ 1',
            subDetail: '7 อายะฮฺ · หน้าที่ 1',
            isSignedIn: false,
            isThai: true,
            onContinue: () {},
            onStartMeaning: () {},
            onStartMushaf: () {},
            onSignInTap: () => signInTapped = true,
          ),
        ),
      );
      expect(find.text('อ่านแบบความหมาย'), findsOneWidget);
      expect(find.text('เปิดมุศหัฟ'), findsOneWidget);
      await tester.tap(find.text('เข้าสู่ระบบเพื่อซิงก์การอ่านข้ามอุปกรณ์'));
      expect(signInTapped, isTrue);
    });

    testWidgets('HomeHifzResumeBanner renders active progress & handles actions',
        (tester) async {
      var resumed = false;
      var discarded = false;
      final snap = ActiveSessionSnapshot(
        sessionId: 'hifz-67',
        sessionType: HifzSessionType.newVerses,
        nvSurahNumber: 67,
        nvRepeatStart: 1,
        nvStartVerse: 1,
        nvEndVerse: 5,
        currentVerse: 2,
        totalSteps: 54,
        currentStepIndex: 6,
        currentMode: 'visible',
        currentTally: 4,
        targetTally: 10,
        lastUpdatedTimestamp: 1700000000000,
      );

      await tester.pumpWidget(
        wrap(
          HomeHifzResumeBanner(
            snapshot: snap,
            isThai: true,
            appColors: lightColors,
            onResume: () => resumed = true,
            onDiscard: () => discarded = true,
          ),
        ),
      );

      expect(find.text('ท่องจำอายะฮฺค้างอยู่'), findsOneWidget);
      expect(find.textContaining('อายะฮฺที่ 2'), findsOneWidget);
      await tester.tap(find.text('ท่องต่อ'));
      expect(resumed, isTrue);
      await tester.tap(find.byIcon(Icons.close_rounded));
      expect(discarded, isTrue);
    });

    testWidgets('HomeGoalsSnapshot caps visible items at 2 and displays +N more',
        (tester) async {
      final items = List.generate(
        4,
        (i) => HomeGoalSnapshotItem(
          modeLabel: 'ความหมาย',
          isMushaf: false,
          title: 'Goal ${i + 1}',
          subtitle: 'Subtitle ${i + 1}',
          progress: 0.25 * (i + 1),
          onTap: () {},
        ),
      );

      await tester.pumpWidget(
        wrap(
          HomeGoalsSnapshot(
            items: items,
            totalActiveCount: 4,
            isThai: true,
            appColors: lightColors,
            onManageTap: () {},
          ),
        ),
      );

      expect(find.text('Goal 1'), findsOneWidget);
      expect(find.text('Goal 2'), findsOneWidget);
      expect(find.text('Goal 3'), findsNothing);
      expect(find.text('+2 ทั้งหมด'), findsOneWidget);
    });

    testWidgets('HomeCommunityPreview renders single card without Shuffle',
        (tester) async {
      final note = TadabburNote(
        id: 'n1',
        userId: 'u1',
        surahId: '67',
        verseId: '2',
        noteText: 'Reflection text here',
        isPublic: true,
        isAnonymous: false,
        likesCount: 5,
        language: 'th',
        createdAt: DateTime.utc(2026, 11, 20),
        updatedAt: DateTime.utc(2026, 11, 20),
      );

      await tester.pumpWidget(
        wrap(
          HomeCommunityPreview(
            featuredNote: note,
            translationText: 'The one who created death and life',
            authorName: 'Reader',
            loading: false,
            isThai: true,
            appColors: lightColors,
            onViewAll: () {},
            onOpenNote: (_) {},
          ),
        ),
      );

      expect(find.byIcon(Icons.shuffle_rounded), findsNothing);
      expect(find.text('ดูทั้งหมด'), findsOneWidget);
      expect(find.text('Reflection text here'), findsOneWidget);
    });
  });

  group('HomeScreen AppBar & Small Screen Layout', () {
    testWidgets(
      'AppBar replaces dark mode toggle with search + voice mic & zero overflow on 360x640 at 1.3x',
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

        try {
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<SettingsProvider>.value(value: settings),
                ChangeNotifierProvider<LocalReadingProvider>.value(
                  value: LocalReadingProvider(),
                ),
                ChangeNotifierProvider<MushafReadingProvider>.value(
                  value: MushafReadingProvider(),
                ),
                ChangeNotifierProvider<StatsProvider>.value(
                  value: StatsProvider(),
                ),
                ChangeNotifierProvider<SupabaseProvider>.value(
                  value: SupabaseProvider(),
                ),
                ChangeNotifierProvider<NotesProvider>.value(
                  value: NotesProvider(),
                ),
                ChangeNotifierProvider<TranslationManagerProvider>.value(
                  value: TranslationManagerProvider(),
                ),
              ],
              child: MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(1.3)),
                  child: child!,
                ),
                home: HomeScreen(
                  repository: QuranRepository(),
                  repositoryReady: true,
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));
          await tester.scrollUntilVisible(
            find.text('Powered by quran-th.com'),
            250,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pump(const Duration(milliseconds: 50));
        } finally {
          FlutterError.onError = previousOnError;
        }

        expect(find.byIcon(Icons.dark_mode_outlined), findsNothing);
        expect(find.byIcon(Icons.light_mode_outlined), findsNothing);
        expect(find.byIcon(Icons.search_rounded), findsOneWidget);
        expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
        expect(overflowErrors, isEmpty);
      },
    );
  });
}
