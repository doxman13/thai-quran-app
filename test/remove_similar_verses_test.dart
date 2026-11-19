import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
import 'package:thai_quran_app/widgets/verse_card.dart';

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

  Widget buildVerseCardHarness({
    required String languageCode,
    required bool splitLandscape,
  }) {
    SharedPreferences.setMockInitialValues({'languageCode': languageCode});
    final settings = SettingsProvider();
    final progress = ProgressProvider();
    final localReading = LocalReadingProvider();
    final transManager = TranslationManagerProvider();
    final thaiProtection = ThaiTextProtectionProvider();
    final audio = MushafAudioProvider();
    final notes = NotesProvider();
    final supabase = SupabaseProvider();
    final stats = StatsProvider();
    final repo = QuranRepository();
    final verse = Verse(
      id: '48',
      surahId: '2',
      thaiV3: 'และจงเกรงกลัววันหนึ่งซึ่งไม่มีชีวิตใดจะชดใช้อะไรแทนอีกชีวิตหนึ่งได้',
      thaiV2: 'และจงเกรงกลัววันหนึ่ง',
      english: 'And fear a Day when no soul will suffice for another soul at all.',
      arabic: 'وَاتَّقُوا يَوْمًا لَّا تَجْزِي نَفْسٌ عَن نَّفْسٍ شَيْئًا',
    );

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
        home: Scaffold(
          body: SingleChildScrollView(
            child: VerseCard(
              verse: verse,
              repository: repo,
              index: 47,
              splitLandscape: splitLandscape,
            ),
          ),
        ),
      ),
    );
  }

  group('Mutashabihat / Similar Verses removal regression tests', () {
    testWidgets(
      'VerseCard omits sync_alt_rounded and similar-verse labels in portrait Thai mode',
      (tester) async {
        await tester.pumpWidget(
          buildVerseCardHarness(languageCode: 'th', splitLandscape: false),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));

        expect(find.byType(VerseCard), findsOneWidget);
        expect(find.byIcon(Icons.sync_alt_rounded), findsNothing);
        expect(find.textContaining('มุตะชาบิฮาต'), findsNothing);
        expect(find.textContaining('คล้ายคลึงกัน'), findsNothing);
        expect(find.textContaining('Similar Verses'), findsNothing);
      },
    );

    testWidgets(
      'VerseCard omits sync_alt_rounded and similar-verse labels in landscape English mode',
      (tester) async {
        tester.view.physicalSize = const Size(900, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          buildVerseCardHarness(languageCode: 'en', splitLandscape: true),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));

        expect(find.byType(VerseCard), findsOneWidget);
        expect(find.byIcon(Icons.sync_alt_rounded), findsNothing);
        expect(find.textContaining('Mutashabihat'), findsNothing);
        expect(find.textContaining('Similar Verses'), findsNothing);
      },
    );
  });
}
