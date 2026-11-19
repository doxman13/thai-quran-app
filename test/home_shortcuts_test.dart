import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thai_quran_app/data/quran_repository.dart';
import 'package:thai_quran_app/providers/local_reading_provider.dart';
import 'package:thai_quran_app/providers/mushaf_reading_provider.dart';
import 'package:thai_quran_app/providers/notes_provider.dart';
import 'package:thai_quran_app/providers/settings_provider.dart';
import 'package:thai_quran_app/providers/stats_provider.dart';
import 'package:thai_quran_app/providers/supabase_provider.dart';
import 'package:thai_quran_app/providers/translation_manager_provider.dart';
import 'package:thai_quran_app/screens/home_screen.dart';

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
    } catch (_) {
      // Ignore if already initialized in test isolate.
    }
  });

  Future<Widget> buildTestHome({
    required String languageCode,
    double textScale = 1.0,
  }) async {
    SharedPreferences.setMockInitialValues({'languageCode': languageCode});
    final settings = SettingsProvider();
    final localReading = LocalReadingProvider();
    final mushafReading = MushafReadingProvider();
    final stats = StatsProvider();
    final supabase = SupabaseProvider();
    final notes = NotesProvider();
    final transManager = TranslationManagerProvider();
    final repo = QuranRepository();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider<LocalReadingProvider>.value(value: localReading),
        ChangeNotifierProvider<MushafReadingProvider>.value(
          value: mushafReading,
        ),
        ChangeNotifierProvider<StatsProvider>.value(value: stats),
        ChangeNotifierProvider<SupabaseProvider>.value(value: supabase),
        ChangeNotifierProvider<NotesProvider>.value(value: notes),
        ChangeNotifierProvider<TranslationManagerProvider>.value(
          value: transManager,
        ),
      ],
      child: MaterialApp(
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          );
        },
        home: HomeScreen(
          repository: repo,
          repositoryReady: true,
        ),
      ),
    );
  }

  group('HomeScreen Quick Surahs / Shortcuts tests', () {
    testWidgets(
      'renders Quick Surahs header, default shortcut cards, and Pin button immediately on startup (EN)',
      (tester) async {
        await tester.pumpWidget(await buildTestHome(languageCode: 'en'));
        // Frame 0 + initial layout without waiting for network calls
        await tester.pump();
        await tester.scrollUntilVisible(
          find.text('Quick Surahs'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();

        expect(find.text('Quick Surahs'), findsOneWidget);
        expect(find.text('Pin'), findsOneWidget);
        expect(find.text('Al-Mulk'), findsOneWidget);
        expect(find.text('Al-Kahf'), findsOneWidget);
        expect(find.text('Meaning'), findsWidgets);
        expect(find.text('Mushaf'), findsWidgets);
      },
    );

    testWidgets(
      'renders Thai header, default shortcut cards, and เพิ่มทางลัด button with zero overflow at 1.25x text scale',
      (tester) async {
        final overflowErrors = <FlutterErrorDetails>[];
        final previousOnError = FlutterError.onError;
        tester.view.physicalSize = const Size(390, 844);
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
            await buildTestHome(languageCode: 'th', textScale: 1.25),
          );
          await tester.pump();
          await tester.drag(
            find.byType(ListView).first,
            const Offset(0, -450),
          );
          await tester.pump(const Duration(milliseconds: 50));
        } finally {
          FlutterError.onError = previousOnError;
        }

        expect(find.text('ทางลัดซูเราะฮฺยอดนิยม'), findsOneWidget);
        expect(find.text('เพิ่มทางลัด'), findsOneWidget);
        expect(find.text('อัลมุลก์'), findsOneWidget);
        expect(find.text('อัลกะฮฺฟฺ'), findsOneWidget);
        expect(overflowErrors, isEmpty);
      },
    );

    test('CustomQuickLink.tryFromJson and tryFromSupabase safely coerce valid rows and skip malformed/out-of-range items', () {
      // Mixed valid types
      final intJson = CustomQuickLink.tryFromJson({
        'id': 'ql_1',
        'surahNumber': 18,
        'label': 'Friday',
        'isLocked': false,
      });
      expect(intJson, isNotNull);
      expect(intJson!.surahNumber, 18);
      expect(intJson.label, 'Friday');

      final numJson = CustomQuickLink.tryFromJson({
        'id': 'ql_2',
        'surahNumber': 36.0,
        'label': 'Yasin',
      });
      expect(numJson, isNotNull);
      expect(numJson!.surahNumber, 36);

      final strJson = CustomQuickLink.tryFromJson({
        'id': 'ql_3',
        'surahNumber': ' 67 ',
        'label': 'Night',
      });
      expect(strJson, isNotNull);
      expect(strJson!.surahNumber, 67);

      // Out-of-range / invalid JSON items return null rather than throwing
      expect(CustomQuickLink.tryFromJson({'surahNumber': 0}), isNull);
      expect(CustomQuickLink.tryFromJson({'surahNumber': 115}), isNull);
      expect(CustomQuickLink.tryFromJson({'surahNumber': 'abc'}), isNull);
      expect(CustomQuickLink.tryFromJson({'surahNumber': null}), isNull);

      // Supabase rows with mixed surah_number types & invalid rows
      final sbValid = CustomQuickLink.tryFromSupabase({
        'id': 'sb_1',
        'surah_number': '55',
        'label': 'Mercy',
      });
      expect(sbValid, isNotNull);
      expect(sbValid!.id, 'sb_1');
      expect(sbValid.surahNumber, 55);

      expect(
        CustomQuickLink.tryFromSupabase({'id': '', 'surah_number': 1}),
        isNull,
      );
      expect(
        CustomQuickLink.tryFromSupabase({'id': 'sb_bad', 'surah_number': 999}),
        isNull,
      );
      expect(
        CustomQuickLink.tryFromSupabase({'id': 'sb_bad2', 'surah_number': 'x'}),
        isNull,
      );

      // Verify decoding a mixed JSON list keeps valid entries and drops invalid ones
      final rawList = jsonEncode([
        {'id': 'ok_1', 'surahNumber': 1, 'label': 'Fatihah'},
        {'id': 'bad_range', 'surahNumber': 200, 'label': 'Invalid'},
        {'id': 'bad_type', 'surahNumber': 'invalid', 'label': 'Invalid'},
        {'id': 'ok_2', 'surahNumber': '114', 'label': 'Nas'},
      ]);
      final decoded = (jsonDecode(rawList) as List<dynamic>)
          .whereType<Map>()
          .map((e) => CustomQuickLink.tryFromJson(Map<String, dynamic>.from(e)))
          .whereType<CustomQuickLink>()
          .toList();
      expect(decoded.length, 2);
      expect(decoded.map((e) => e.surahNumber).toList(), [1, 114]);
    });
  });
}
