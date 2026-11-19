import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thai_quran_app/data/quran_repository.dart';
import 'package:thai_quran_app/models/verse.dart';
import 'package:thai_quran_app/providers/local_reading_provider.dart';
import 'package:thai_quran_app/providers/mushaf_reading_provider.dart';
import 'package:thai_quran_app/providers/settings_provider.dart';
import 'package:thai_quran_app/screens/browse_screen.dart';
import 'package:thai_quran_app/theme/app_theme.dart';
import 'package:thai_quran_app/widgets/surah_picker_sheet.dart';

class _FakeBrowseQuranRepository extends QuranRepository {
  @override
  List<Verse> getSurahVerses(String surahId) {
    final count = surahId == '1' ? 7 : (surahId == '2' ? 286 : 5);
    return List.generate(
      count,
      (i) => Verse(
        id: '${i + 1}',
        surahId: surahId,
        thaiV3: 'คำแปล $surahId:${i + 1}',
        thaiV2: 'คำแปล $surahId:${i + 1}',
        english: 'English $surahId:${i + 1}',
        arabic: 'بِسْمِ اللَّهِ',
      ),
    );
  }
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
    } catch (_) {
      // Ignore if already initialized in test isolate.
    }
  });

  Widget buildBrowseHarness({required String languageCode}) {
    SharedPreferences.setMockInitialValues({'languageCode': languageCode});
    final settings = SettingsProvider();
    final localReading = LocalReadingProvider();
    final mushafReading = MushafReadingProvider();
    final colors = AppThemeColors.teal(isDark: false);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider<LocalReadingProvider>.value(value: localReading),
        ChangeNotifierProvider<MushafReadingProvider>.value(
          value: mushafReading,
        ),
      ],
      child: MaterialApp(
        home: BrowseScreen(
          repository: _FakeBrowseQuranRepository(),
          colors: colors,
          onOpen: (_, _) {},
          onOpenPage: (_) {},
        ),
      ),
    );
  }

  Widget buildPickerHarness({required String languageCode}) {
    SharedPreferences.setMockInitialValues({'languageCode': languageCode});
    final settings = SettingsProvider();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SurahPickerSheet(selectedSurah: 1),
        ),
      ),
    );
  }

  group('Surah list cleanup tests', () {
    testWidgets(
      'BrowseScreen in Thai mode omits Makkiyah/Madaniyah and English subtitles, including modal',
      (tester) async {
        await tester.pumpWidget(buildBrowseHarness(languageCode: 'th'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('อัลฟาติหะฮฺ'), findsOneWidget);
        expect(find.text('อัลบะเกาะเราะฮฺ'), findsOneWidget);
        expect(find.text('7 อายะฮฺ · หน้า 1'), findsOneWidget);

        expect(find.textContaining('Al-Fatihah'), findsNothing);
        expect(find.textContaining('Al-Baqarah'), findsNothing);
        expect(find.textContaining('มักกียะฮฺ'), findsNothing);
        expect(find.textContaining('มะดะนียะฮฺ'), findsNothing);
        expect(find.textContaining('Meccan'), findsNothing);
        expect(find.textContaining('Medinan'), findsNothing);

        await tester.tap(find.text('อัลฟาติหะฮฺ'));
        await tester.pumpAndSettle();

        expect(find.text('7 อายะฮฺ · หน้า 1'), findsNWidgets(2));
        expect(find.textContaining('Al-Fatihah'), findsNothing);
        expect(find.textContaining('มักกียะฮฺ'), findsNothing);
        expect(find.textContaining('มะดะนียะฮฺ'), findsNothing);
        expect(find.textContaining('Meccan'), findsNothing);
        expect(find.textContaining('Medinan'), findsNothing);
      },
    );

    testWidgets(
      'BrowseScreen in English mode omits Meccan/Medinan and Thai subtitles, including modal',
      (tester) async {
        await tester.pumpWidget(buildBrowseHarness(languageCode: 'en'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('Al-Fatihah'), findsOneWidget);
        expect(find.text('Al-Baqarah'), findsOneWidget);
        expect(find.text('7 verses · Page 1'), findsOneWidget);

        expect(find.textContaining('Meccan'), findsNothing);
        expect(find.textContaining('Medinan'), findsNothing);
        expect(find.textContaining('มักกียะฮฺ'), findsNothing);
        expect(find.textContaining('มะดะนียะฮฺ'), findsNothing);
        expect(find.textContaining('อัลฟาติหะฮฺ'), findsNothing);
        expect(find.textContaining('อัลบะเกาะเราะฮฺ'), findsNothing);

        await tester.tap(find.text('Al-Fatihah'));
        await tester.pumpAndSettle();

        expect(find.text('7 verses · Page 1'), findsNWidgets(2));
        expect(find.textContaining('Meccan'), findsNothing);
        expect(find.textContaining('Medinan'), findsNothing);
        expect(find.textContaining('อัลฟาติหะฮฺ'), findsNothing);
      },
    );

    testWidgets(
      'SurahPickerSheet in Thai mode omits English subtitle while keeping bilingual search',
      (tester) async {
        await tester.pumpWidget(buildPickerHarness(languageCode: 'th'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('อัลฟาติหะฮฺ'), findsOneWidget);
        expect(find.text('7 อายะฮฺ'), findsOneWidget);
        expect(find.textContaining('Al-Fatihah'), findsNothing);

        await tester.enterText(find.byType(TextField), 'Fatihah');
        await tester.pump();

        expect(find.text('อัลฟาติหะฮฺ'), findsOneWidget);
        expect(find.text('7 อายะฮฺ'), findsOneWidget);
        expect(find.text('อัลบะเกาะเราะฮฺ'), findsNothing);
      },
    );
  });
}
