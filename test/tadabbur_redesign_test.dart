import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thai_quran_app/data/quran_repository.dart';
import 'package:thai_quran_app/data/tadabbur_repository.dart';
import 'package:thai_quran_app/models/tadabbur_note.dart';
import 'package:thai_quran_app/models/verse.dart';
import 'package:thai_quran_app/providers/settings_provider.dart';
import 'package:thai_quran_app/providers/translation_manager_provider.dart';
import 'package:thai_quran_app/screens/home_screen.dart';
import 'package:thai_quran_app/screens/tadabbur_community_screen.dart';

class _FakeQuranRepository extends QuranRepository {
  @override
  Verse? getVerse(String surahId, String verseId) {
    return Verse(
      id: verseId,
      surahId: surahId,
      thaiV3: 'คำแปลตัวอย่างของซูเราะฮฺ $surahId อายะฮฺ $verseId',
      thaiV2: 'คำแปลตัวอย่างของซูเราะฮฺ $surahId อายะฮฺ $verseId',
      english: 'Sample English translation for $surahId:$verseId',
      arabic: 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
    );
  }

  @override
  Future<String> fetchArabicVerse(String surahId, String verseId) async {
    return 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';
  }

  @override
  List<Verse> getSurahVerses(String surahId) {
    return [getVerse(surahId, '1')!];
  }
}

class _FakeTadabburRepository extends TadabburRepository {
  final List<TadabburNote> thaiNotes;
  final List<TadabburNote> qrNotes;

  _FakeTadabburRepository({
    required this.thaiNotes,
    required this.qrNotes,
  });

  @override
  Future<Set<String>> getBlockedUserIds() async => <String>{};

  @override
  Future<List<TadabburNote>> fetchCommunityNotes(
    String surahId,
    String verseId, {
    int? limit,
  }) async {
    return thaiNotes;
  }

  @override
  Future<({List<TadabburNote> reflections, bool hasMore})>
      fetchQuranReflectNotesWithMeta({
    String? surahId,
    String? verseId,
    int page = 1,
    int limit = 50,
  }) async {
    return (reflections: qrNotes, hasMore: false);
  }
}

TadabburNote _makeNote({
  required String id,
  required String surahId,
  required String verseId,
  required String noteText,
  String language = 'th',
  String? source,
  String? userEmail,
  int likesCount = 3,
}) {
  final now = DateTime.now().subtract(const Duration(hours: 2));
  return TadabburNote(
    id: id,
    userId: 'user-$id',
    surahId: surahId,
    verseId: verseId,
    noteText: noteText,
    isPublic: true,
    isAnonymous: source == null,
    likesCount: likesCount,
    language: language,
    createdAt: now,
    updatedAt: now,
    userEmail: userEmail,
    source: source,
  );
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

  Widget buildCommunityScreen({
    required _FakeTadabburRepository tadabburRepo,
    required String languageCode,
    double textScale = 1.0,
  }) {
    SharedPreferences.setMockInitialValues({'languageCode': languageCode});
    final settings = SettingsProvider();
    final transManager = TranslationManagerProvider();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
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
        home: TadabburCommunityScreen(
          repository: _FakeQuranRepository(),
          tadabburRepository: tadabburRepo,
        ),
      ),
    );
  }

  group('Homepage community preview selection', () {
    test('returns only Thai notes when Thai notes exist (never mixes English)', () {
      final thai1 = _makeNote(
        id: 'th-1',
        surahId: '1',
        verseId: '1',
        noteText: 'ข้อคิดภาษาไทย',
      );
      final qr1 = _makeNote(
        id: 'qr-1',
        surahId: '2',
        verseId: '255',
        noteText: 'English reflection',
        language: 'en',
        source: 'quranreflect',
        userEmail: 'Dalia Mogahed',
      );

      final result = selectHomepageCommunityNotes(
        thaiNotes: [thai1],
        englishFallbackNotes: [qr1],
      );

      expect(result, hasLength(1));
      expect(result.first.id, 'th-1');
      expect(result.any((n) => n.isQuranReflect), isFalse);
    });

    test('falls back to English notes when Thai notes are empty or blank', () {
      final blankThai = _makeNote(
        id: 'th-blank',
        surahId: '1',
        verseId: '1',
        noteText: '   ',
      );
      final qr1 = _makeNote(
        id: 'qr-1',
        surahId: '2',
        verseId: '255',
        noteText: 'English reflection fallback',
        language: 'en',
        source: 'quranreflect',
        userEmail: 'Dalia Mogahed',
      );

      final emptyResult = selectHomepageCommunityNotes(
        thaiNotes: const [],
        englishFallbackNotes: [qr1],
      );
      expect(emptyResult.map((e) => e.id).toList(), ['qr-1']);

      final blankResult = selectHomepageCommunityNotes(
        thaiNotes: [blankThai],
        englishFallbackNotes: [qr1],
      );
      expect(blankResult.map((e) => e.id).toList(), ['qr-1']);
    });
  });

  group('TadabburCommunityScreen unified filter & social feed', () {
    testWidgets(
      'auto-falls back to EN when Thai feed is empty and lists only active Surahs',
      (tester) async {
        final qr1 = _makeNote(
          id: 'qr-101',
          surahId: '2',
          verseId: '255',
          noteText: 'Ayat al-Kursi anchors the heart in Allah.',
          language: 'en',
          source: 'quranreflect',
          userEmail: 'Dalia Mogahed',
        );

        await tester.pumpWidget(
          buildCommunityScreen(
            tadabburRepo: _FakeTadabburRepository(
              thaiNotes: const [],
              qrNotes: [qr1],
            ),
            languageCode: 'en',
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pumpAndSettle();

        expect(find.text('Dalia Mogahed'), findsOneWidget);
        expect(
          find.text('Ayat al-Kursi anchors the heart in Allah.'),
          findsOneWidget,
        );
        expect(find.text('All Surahs (1)'), findsOneWidget);
        expect(find.text('QuranReflect'), findsOneWidget);
      },
    );

    testWidgets(
      'defaults to Thai, resets missing Surah cleanly on source switch, and renders social cards with zero overflow',
      (tester) async {
        final longThaiText =
            'ข้อคิดภาษาไทยที่มีความยาวมากเพื่อทดสอบปุ่มอ่านเพิ่มเติมบนการ์ดแบบโซเชียลมีเดีย '
            '${'อัลลอฮฺทรงเมตตาบ่าวของพระองค์เสมอ '.repeat(12)}';
        final thai1 = _makeNote(
          id: 'th-18',
          surahId: '18',
          verseId: '10',
          noteText: longThaiText,
        );
        final qr1 = _makeNote(
          id: 'qr-2',
          surahId: '2',
          verseId: '286',
          noteText: 'Allah never burdens a soul beyond its capacity.',
          language: 'en',
          source: 'quranreflect',
          userEmail: 'Omar Suleiman',
        );

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
            buildCommunityScreen(
              tadabburRepo: _FakeTadabburRepository(
                thaiNotes: [thai1],
                qrNotes: [qr1],
              ),
              languageCode: 'th',
              textScale: 1.2,
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));
          await tester.pumpAndSettle();

          // Starts on Thai filter with Surah 18 post visible
          expect(find.text('ทุกซูเราะฮฺ (1)'), findsOneWidget);
          expect(find.text('อ่านเพิ่มเติม'), findsOneWidget);
          expect(find.text('Omar Suleiman'), findsNothing);

          // Expand long reflection text
          await tester.ensureVisible(find.text('อ่านเพิ่มเติม'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('อ่านเพิ่มเติม'));
          await tester.pumpAndSettle();
          expect(find.text('ย่อข้อความ'), findsOneWidget);

          // Open Surah dropdown -> should only list All Surahs (1) and 18. อัลกะฮฺฟฺ (1)
          await tester.tap(find.byType(DropdownButton<String?>));
          await tester.pumpAndSettle();
          expect(find.text('18. อัลกะฮฺฟฺ (1)'), findsOneWidget);
          expect(find.text('2. อัลบะเกาะเราะฮฺ (1)'), findsNothing);

          // Select Surah 18
          await tester.tap(find.text('18. อัลกะฮฺฟฺ (1)').last);
          await tester.pumpAndSettle();

          // Switch to EN where Surah 18 does not exist -> must not throw DropdownButton assertion
          await tester.tap(find.text('EN'));
          await tester.pumpAndSettle();

          expect(find.text('Omar Suleiman'), findsOneWidget);
          expect(find.text('ทุกซูเราะฮฺ (1)'), findsOneWidget);
          expect(find.text('แชร์'), findsOneWidget);
          expect(find.text('อ่านฉบับแปล'), findsOneWidget);
          expect(find.text('มุศหัฟ'), findsOneWidget);

          // Switch to All -> dropdown includes both active Surahs (2 and 18)
          await tester.tap(find.text('ทั้งหมด'));
          await tester.pumpAndSettle();
          expect(find.text('ทุกซูเราะฮฺ (2)'), findsOneWidget);
        } finally {
          FlutterError.onError = previousOnError;
        }

        expect(overflowErrors, isEmpty);
      },
    );

    testWidgets(
      'compose Post button enables immediately on typing and renders cleanly in English',
      (tester) async {
        final thai1 = _makeNote(
          id: 'th-1',
          surahId: '1',
          verseId: '1',
          noteText: 'ข้อคิดเริ่มต้น',
        );

        await tester.pumpWidget(
          buildCommunityScreen(
            tadabburRepo: _FakeTadabburRepository(
              thaiNotes: [thai1],
              qrNotes: const [],
            ),
            languageCode: 'en',
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Write'));
        await tester.pumpAndSettle();

        final postButtonBefore = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Post Reflection'),
        );
        expect(postButtonBefore.onPressed, isNull);

        await tester.enterText(
          find.byType(TextField),
          'Sincere reflection on Surah Al-Fatihah',
        );
        await tester.pump();

        final postButtonAfter = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Post Reflection'),
        );
        expect(postButtonAfter.onPressed, isNotNull);
      },
    );
  });
}

extension on String {
  String repeat(int count) => List.filled(count, this).join();
}
