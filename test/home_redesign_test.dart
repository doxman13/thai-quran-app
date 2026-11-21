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
import 'package:thai_quran_app/providers/thai_text_protection_provider.dart';
import 'package:thai_quran_app/providers/translation_manager_provider.dart';
import 'package:thai_quran_app/screens/home_screen.dart';
import 'package:thai_quran_app/theme/app_theme.dart';
import 'package:thai_quran_app/widgets/home/home_community_preview.dart';
import 'package:thai_quran_app/widgets/home/home_continue_hero.dart';
import 'package:thai_quran_app/widgets/home/home_goals_snapshot.dart';
import 'package:thai_quran_app/widgets/home/home_header_strip.dart';
import 'package:thai_quran_app/widgets/home/home_hifz_resume_banner.dart';
import 'package:thai_quran_app/widgets/home/home_quick_surahs.dart';
import 'package:thai_quran_app/widgets/home/home_study_hub_grid.dart';

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
  final darkColors = AppThemeColors.teal(isDark: true);

  Widget wrap(Widget child, {double textScale = 1.0, bool isDark = false}) {
    return MaterialApp(
      theme: isDark
          ? ThemeData.dark(useMaterial3: true)
          : ThemeData.light(useMaterial3: true),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          backgroundColor: isDark ? darkColors.background : lightColors.background,
          body: SingleChildScrollView(child: child),
        ),
      ),
    );
  }

  Widget buildHomeHarness({
    required double width,
    required double height,
    double textScale = 1.0,
    bool isDark = false,
    String languageCode = 'th',
  }) {
    SharedPreferences.setMockInitialValues({
      'languageCode': languageCode,
      'isDarkMode': isDark,
    });
    final settings = SettingsProvider();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider<LocalReadingProvider>.value(
          value: LocalReadingProvider(),
        ),
        ChangeNotifierProvider<MushafReadingProvider>.value(
          value: MushafReadingProvider(),
        ),
        ChangeNotifierProvider<StatsProvider>.value(value: StatsProvider()),
        ChangeNotifierProvider<SupabaseProvider>.value(value: SupabaseProvider()),
        ChangeNotifierProvider<NotesProvider>.value(value: NotesProvider()),
        ChangeNotifierProvider<TranslationManagerProvider>.value(
          value: TranslationManagerProvider(),
        ),
      ],
      child: MaterialApp(
        theme: isDark
            ? ThemeData.dark(useMaterial3: true)
            : ThemeData.light(useMaterial3: true),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: HomeScreen(
          repository: QuranRepository(),
          repositoryReady: true,
        ),
      ),
    );
  }

  group('Modular Home Widgets', () {
    testWidgets('HomeHeaderStrip shows Today title & clean streak pill',
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
      expect(find.text('วันนี้ของคุณ'), findsOneWidget);
      expect(find.text('7 วันต่อเนื่อง'), findsOneWidget);
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
      expect(find.byIcon(Icons.auto_awesome_outlined), findsOneWidget);
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
            contextTag: 'หน้า 1 จาก 604',
            mainTitle: 'อัลฟาติหะฮฺ · อายะฮฺที่ 1',
            subDetail: '7 อายะฮฺ · พร้อมคำแปลและตัฟซีรย่อ',
            arabicSurahName: 'سورة الفَاتِـحَة',
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
      expect(find.text('سورة الفَاتِـحَة'), findsOneWidget);
      await tester.tap(find.text('เข้าสู่ระบบเพื่อซิงก์การอ่านข้ามอุปกรณ์'));
      expect(signInTapped, isTrue);
    });

    testWidgets('HomeContinueHero shows Mushaf history + slim progress + switch CTA cleanly',
        (tester) async {
      var continued = false;
      var switched = false;
      await tester.pumpWidget(
        wrap(
          HomeContinueHero(
            hasHistory: true,
            isMushaf: true,
            modeBadge: 'อ่านต่อจากเดิม',
            contextTag: 'โหมดอิสระ',
            mainTitle: 'หน้า 296',
            subDetail: 'จาก 604 หน้า · 3 ชม.ที่แล้ว',
            arabicSurahName: 'سورة الكَهْف',
            surahNameLabel: 'อัลกะฮฺฟฺ',
            progressFraction: 296 / 604,
            isSignedIn: true,
            isThai: true,
            onContinue: () => continued = true,
            onStartMeaning: () {},
            onStartMushaf: () {},
            onSwitchMode: () => switched = true,
          ),
        ),
      );
      expect(find.text('หน้า 296 · อัลกะฮฺฟฺ'), findsOneWidget);
      expect(find.text('سورة الكَهْف'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.tap(find.text('หน้า 296 · อัลกะฮฺฟฺ'));
      expect(continued, isTrue);
      await tester.tap(find.text('สลับเป็นความหมาย'));
      expect(switched, isTrue);
    });

    testWidgets('HomeStudyHubGrid displays 4 minimal icon+title shortcuts without subtitles',
        (tester) async {
      var opened = '';
      await tester.pumpWidget(
        wrap(
          HomeStudyHubGrid(
            isThai: true,
            appColors: lightColors,
            onOpenMeaning: () => opened = 'meaning',
            onOpenMushaf: () => opened = 'mushaf',
            onOpenHifz: () => opened = 'hifz',
            onOpenGoals: () => opened = 'goals',
          ),
        ),
      );
      expect(find.text('ความหมาย'), findsOneWidget);
      expect(find.text('มุศหัฟ'), findsOneWidget);
      expect(find.text('ท่องจำ'), findsOneWidget);
      expect(find.text('เป้าหมาย'), findsOneWidget);
      expect(find.text('หัวข้อ'), findsNothing);
      expect(find.text('โหมดการศึกษา'), findsNothing);
      await tester.tap(find.text('เป้าหมาย'));
      expect(opened, 'goals');
    });

    testWidgets('HomeHifzResumeBanner renders warm sand strip & handles actions',
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

      expect(find.text('ท่องจำต่อ · อัลมุลก์'), findsOneWidget);
      expect(find.textContaining('อายะฮฺที่ 2'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
      expect(resumed, isTrue);
      await tester.tap(find.byIcon(Icons.close_rounded));
      expect(discarded, isTrue);
    });

    testWidgets('HomeGoalsSnapshot caps visible items at 2 and displays view-all +N',
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
      expect(find.text('ทั้งหมด +2'), findsOneWidget);
      expect(find.text('ความหมาย'), findsNWidgets(2));
      expect(find.text('Subtitle 1'), findsNothing);
      expect(find.text('25%'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('HomeQuickSurahs shows only surah number, Arabic name, and Thai name without tag clutter',
        (tester) async {
      var manageTapped = false;
      await tester.pumpWidget(
        wrap(
          HomeQuickSurahs(
            items: const [
              HomeQuickSurahItem(
                id: 'mulk',
                surahNumber: 67,
                label: 'ก่อนนอน',
                isLocked: true,
              ),
              HomeQuickSurahItem(
                id: 'custom',
                surahNumber: 36,
                label: 'อ่านวันศุกร์',
                isLocked: false,
              ),
            ],
            canPinMore: true,
            isThai: true,
            appColors: lightColors,
            onPinTap: () {},
            onManageTap: () => manageTapped = true,
            onItemTap: (_) {},
          ),
        ),
      );

      expect(find.text('ซูเราะฮฺที่ปักหมุด'), findsOneWidget);
      expect(find.text('67'), findsOneWidget);
      expect(find.text('36'), findsOneWidget);
      expect(find.text('อัลมุลก์'), findsOneWidget);
      expect(find.text('ยาซีน'), findsOneWidget);
      expect(find.text('แตะเพื่อเปิดอ่าน'), findsNothing);
      expect(find.text('ก่อนนอน'), findsNothing);
      expect(find.text('อ่านวันศุกร์'), findsNothing);
      expect(find.text('ซุนนะฮฺวันศุกร์'), findsNothing);
      await tester.tap(find.text('จัดการ'));
      expect(manageTapped, isTrue);
    });

    testWidgets('HomeCommunityPreview renders compact reflection block without redundant translation preview',
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
      expect(find.text('The one who created death and life'), findsNothing);
      expect(find.text('โดย Reader'), findsOneWidget);
      expect(find.text('อ่านต่อ'), findsOneWidget);
    });
  });

  group('HomeScreen Editorial Responsive Layout', () {
    Future<void> verifyViewport(
      WidgetTester tester, {
      required Size size,
      double textScale = 1.0,
      bool isDark = false,
    }) async {
      final overflowErrors = <FlutterErrorDetails>[];
      final previousOnError = FlutterError.onError;
      tester.view.physicalSize = size;
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
          buildHomeHarness(
            width: size.width,
            height: size.height,
            textScale: textScale,
            isDark: isDark,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('อัสสลามุอะลัยกุม'), findsOneWidget);
        expect(find.text('อายะฮฺประจำวัน'), findsNothing);
        expect(find.textContaining('อ่านอายะฮฺนี้'), findsNothing);
        expect(find.text('แตะเพื่ออ่านต่อ'), findsNothing);
        expect(find.text('ซูเราะฮฺ'), findsOneWidget);
        expect(find.text('ที่คั่นหน้า'), findsOneWidget);
        expect(find.text('สารบัญ'), findsNothing);
        expect(find.byIcon(Icons.dark_mode_outlined), findsNothing);
        expect(find.byIcon(Icons.light_mode_outlined), findsNothing);
        expect(find.byIcon(Icons.search_rounded), findsOneWidget);
        expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('Powered by quran-th.com'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump(const Duration(milliseconds: 50));
      } finally {
        FlutterError.onError = previousOnError;
      }

      expect(overflowErrors, isEmpty);
    }

    testWidgets('Manage Pinned Surahs sheet lists pinned items and allows removing custom pin',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'languageCode': 'th',
        'custom_quick_links_v2_guest':
            '[{"id":"custom_qaf","surahNumber":50,"label":"ศุกร์","isLocked":false}]',
      });
      final settings = SettingsProvider();
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
            ChangeNotifierProvider<StatsProvider>.value(value: StatsProvider()),
            ChangeNotifierProvider<SupabaseProvider>.value(
              value: SupabaseProvider(),
            ),
            ChangeNotifierProvider<NotesProvider>.value(value: NotesProvider()),
            ChangeNotifierProvider<TranslationManagerProvider>.value(
              value: TranslationManagerProvider(),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData.light(useMaterial3: true),
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
        find.text('จัดการ'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('จัดการ'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byIcon(Icons.delete_outline_rounded),
        120,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
    });

    testWidgets('Continue Reading displays Thai Mushaf label instead of raw Free Read',
        (tester) async {
      final now = DateTime.now();
      final recentAt =
          now.subtract(const Duration(minutes: 50)).toUtc().toIso8601String();
      SharedPreferences.setMockInitialValues({
        'languageCode': 'th',
        'thai_quran_mushaf_store_v1':
            '{"profiles":[{"id":"mushaf_free_1","userId":"local","name":"Free Read","slug":"mushaf_free_read","mushafId":1,"startPage":1,"targetPage":604,"currentPage":441,"furthestUnreadPage":441,"lastViewedPage":441,"sortOrder":0,"isArchived":false,"createdAt":"$recentAt","updatedAt":"$recentAt"}],"recentReadings":[{"mushafId":1,"pageNumber":441,"profileId":"mushaf_free_1","surahId":36,"updatedAt":"$recentAt"}],"pageBookmarks":[],"verseBookmarks":[]}',
      });
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsProvider>.value(
              value: SettingsProvider(),
            ),
            ChangeNotifierProvider<LocalReadingProvider>.value(
              value: LocalReadingProvider(),
            ),
            ChangeNotifierProvider<MushafReadingProvider>.value(
              value: MushafReadingProvider(),
            ),
            ChangeNotifierProvider<StatsProvider>.value(value: StatsProvider()),
            ChangeNotifierProvider<SupabaseProvider>.value(
              value: SupabaseProvider(),
            ),
            ChangeNotifierProvider<NotesProvider>.value(value: NotesProvider()),
            ChangeNotifierProvider<TranslationManagerProvider>.value(
              value: TranslationManagerProvider(),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData.light(useMaterial3: true),
            home: HomeScreen(
              repository: QuranRepository(),
              repositoryReady: true,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      // Allow SharedPreferences microtask from MushafReadingProvider.load() to settle
      await tester.pumpAndSettle();

      final hero = tester.widget<HomeContinueHero>(find.byType(HomeContinueHero));
      expect('${hero.mainTitle} · ${hero.surahNameLabel}', 'หน้า 441 · ยาซีน');
      expect(hero.contextTag, 'มุศหัฟ');
      expect(find.text('หน้า 441 · ยาซีน'), findsOneWidget);
      expect(find.text('Free Read'), findsNothing);
      expect(find.text('มุศหัฟ'), findsWidgets);
    });

    testWidgets('360x640 at 1.3x text scale renders cleanly with zero overflow',
        (tester) async {
      await verifyViewport(
        tester,
        size: const Size(360, 640),
        textScale: 1.3,
      );
    });

    testWidgets('393x852 dark mode renders cleanly with zero overflow',
        (tester) async {
      await verifyViewport(
        tester,
        size: const Size(393, 852),
        isDark: true,
      );
    });

    testWidgets('840x1180 tablet layout centers content cleanly with zero overflow',
        (tester) async {
      await verifyViewport(
        tester,
        size: const Size(840, 1180),
      );
    });
  });

  group('Thai Word-Break Protection & Global Locale', () {
    test('protectWithTerms keeps protected words joined with U+2060 and respects punctuation',
        () {
      const sample = '“การสรรเสริญทั้งหลายนั้นเป็นสิทธิของอัลลอฮฺ”';
      final protected = ThaiTextProtectionProvider.protectWithTerms(
        sample,
        ThaiTextProtectionProvider.seedTerms,
      );

      // Word joiners keep 'อัลลอฮฺ' connected internally without splitting syllables
      expect(protected.contains('\u2060'), isTrue);
      // Clean word boundary BEFORE 'อัลลอฮฺ' so ICU breaks cleanly before the word
      // Note: 'อั' stays joined together; U+2060 is placed before 'ล', not before combining mark 'ั'
      expect(protected.contains('ของ\u200Bอั\u2060ล'), isTrue);
      // Closing quotation mark remains glued to the protected term (no trailing ZWSP)
      expect(protected.contains('\u200B”'), isFalse);
      expect(protected.contains('“\u200B'), isFalse);
    });

    test('AppTheme.applyTextLocale propagates Locale(th, TH) globally for Thai word breaking',
        () {
      final lightTextTheme = AppTheme.applyTextLocale(
        ThemeData.light().textTheme,
        ThaiTextProtectionProvider.thaiLocale,
      );
      expect(lightTextTheme.bodyMedium?.locale, const Locale('th', 'TH'));
      expect(lightTextTheme.bodyLarge?.locale, const Locale('th', 'TH'));
      expect(lightTextTheme.titleMedium?.locale, const Locale('th', 'TH'));

      final darkTextTheme = AppTheme.applyTextLocale(
        ThemeData.dark().textTheme,
        ThaiTextProtectionProvider.thaiLocale,
      );
      expect(darkTextTheme.bodyMedium?.locale, const Locale('th', 'TH'));
      expect(darkTextTheme.labelSmall?.locale, const Locale('th', 'TH'));
    });

    testWidgets('HomeScreen Daily Verse assigns Locale(th, TH) and protectSafe protects even without ancestor provider',
        (tester) async {
      await tester.pumpWidget(
        buildHomeHarness(width: 360, height: 640, textScale: 1.15),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final quoteTexts = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => (t.data ?? '').contains('“') && (t.data ?? '').contains('”'))
          .toList();
      expect(quoteTexts, isNotEmpty);
      expect(quoteTexts.first.locale, const Locale('th', 'TH'));

      final ctx = tester.element(find.byType(HomeScreen));
      final protectedFallback = ThaiTextProtectionProvider.protectSafe(
        ctx,
        'แท้จริงสิทธิของอัลลอฮฺและอัลกุรอาน',
      );
      expect(protectedFallback.contains('\u2060'), isTrue);
      expect(protectedFallback.contains('ของ\u200Bอั\u2060ล'), isTrue);
    });
  });
}
