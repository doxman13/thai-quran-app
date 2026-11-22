import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thai_quran_app/data/quran_repository.dart';
import 'package:thai_quran_app/data/tadabbur_repository.dart';
import 'package:thai_quran_app/models/tadabbur_note.dart';
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
import 'package:thai_quran_app/screens/notes_screen.dart';
import 'package:thai_quran_app/screens/tadabbur_community_screen.dart';
import 'package:thai_quran_app/screens/tadabbur_private_screen.dart';
import 'package:thai_quran_app/services/footnote_service.dart';
import 'package:thai_quran_app/shared/quran_translation_helper.dart';
import 'package:thai_quran_app/shared/share_formatter.dart';
import 'package:thai_quran_app/widgets/tadabbur_panel.dart';
import 'package:thai_quran_app/widgets/verse_card.dart';
import 'package:thai_quran_app/widgets/verse_share_sheet.dart';

class _FakeQuranRepository extends QuranRepository {
  @override
  Verse? getVerse(String surahId, String verseId) {
    return Verse(
      id: verseId,
      surahId: surahId,
      thaiV3: 'คำแปลตัวอย่างของซูเราะฮฺ $surahId อายะฮฺ $verseId',
      thaiV2: 'คำแปลตัวอย่างของซูเราะฮฺ $surahId อายะฮฺ $verseId',
      english: 'Sample English translation for $surahId:$verseId',
      arabic: 'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ',
      shortTafsir: 'คำอธิบายตัฟซีรฉบับย่อสำหรับ $surahId:$verseId',
      shortTafsirSource: 'QuranEnc Thai Mokhtasar',
    );
  }

  @override
  Future<String> fetchArabicVerse(String surahId, String verseId) async {
    final raw =
        'قَالُوا\u06DF لَا\u06DF تَأۡمَ\u06EBنَّا ٱلۡمُص\u06E3يۡطِرُونَ | $verseId';
    return sanitizeUthmanicText(raw);
  }

  @override
  List<Verse> getSurahVerses(String surahId) {
    return [getVerse(surahId, '1')!];
  }
}

class _FakeLoggedInSupabaseProvider extends SupabaseProvider {
  @override
  bool get isLoggedIn => true;

  @override
  String get userId => 'test-user-1';
}

class _FakeTadabburRepository extends TadabburRepository {
  final List<TadabburNote> thaiNotes;

  _FakeTadabburRepository(this.thaiNotes);

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
    return (reflections: const <TadabburNote>[], hasMore: false);
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

    final fontBytes = File('assets/fonts/UthmanicHafs.ttf').readAsBytesSync();
    final fontLoader = FontLoader('UthmanicHafs')
      ..addFont(Future.value(ByteData.view(fontBytes.buffer)));
    await fontLoader.load();
  });

  group('Uthmanic sanitization and share caption formatting', () {
    test(
      'sanitizeUthmanicText and formatArabicAyahText eliminate black-circle glyphs, pipes, and 06DD',
      () {
        const dirty =
            'قَالُوا\u06DF لَا تَأۡمَ\u06EBنَّا \u25CC ٱلۡمُص\u06E3يۡطِرُونَ '
            'رِجَالً\u06EDا نَفۡسٍ\u06E2 هُدً\u06E2ى ءَايَةٍ\u06ED \u06DD | ١١';

        final sanitized = sanitizeUthmanicText(dirty);
        expect(sanitized.contains('\u06DF'), isFalse);
        expect(sanitized.contains('\u06E3'), isFalse);
        expect(sanitized.contains('\u06EB'), isFalse);
        expect(sanitized.contains('\u25CC'), isFalse);
        expect(sanitized.contains('\u0652'), isTrue);
        expect(sanitized.contains('\u06DC'), isTrue);
        // Tanween pseudo-marks and Iqlab replacements
        expect(sanitized.contains('\u064B\u06ED'), isFalse);
        expect(sanitized.contains('\u064D\u06E2'), isFalse);
        expect(sanitized.contains('\u064E\u06E2'), isTrue);
        expect(sanitized.contains('\u0650\u06ED'), isTrue);

        final formatted = formatArabicAyahText(dirty, verseNumber: '11');
        expect(formatted.contains('\u06DF'), isFalse);
        expect(formatted.contains('\u06E3'), isFalse);
        expect(formatted.contains('\u06EB'), isFalse);
        expect(formatted.contains('\u25CC'), isFalse);
        expect(formatted.contains('|'), isFalse);
        expect(formatted.contains('\u06DD'), isFalse);
        expect(formatted.contains('۝'), isFalse);
        expect(formatted.endsWith(' ١١'), isTrue);
      },
    );

    test(
      'all 6,236 bundled verses in assets/quran_arabic.json format cleanly with zero problematic glyphs',
      () {
        final rawList =
            json.decode(File('assets/quran_arabic.json').readAsStringSync())
                as List<dynamic>;
        expect(rawList.length, 6236);

        for (final entry in rawList) {
          final map = entry as Map<String, dynamic>;
          final verseId = map['ayah_number'];
          final formatted = formatArabicAyahText(
            map['uthmani_text'] as String,
            verseNumber: verseId,
          );
          expect(formatted.contains('\u06DF'), isFalse);
          expect(formatted.contains('\u06E3'), isFalse);
          expect(formatted.contains('\u06EB'), isFalse);
          expect(formatted.contains('\u25CC'), isFalse);
          expect(formatted.contains('|'), isFalse);
          expect(formatted.contains('\u06DD'), isFalse);
          expect(formatted.contains('۝'), isFalse);
          expect(formatted.endsWith(' ${toArabicDigits(verseId)}'), isTrue);
        }
      },
    );

    test('formatImageShareCaption returns canonical verse:url caption', () {
      expect(
        formatImageShareCaption(
          '2',
          '255',
          'https://quran-th.com/surah/2#v-255',
        ),
        '2:255\nhttps://quran-th.com/surah/2#v-255',
      );
    });
  });

  group('UthmanicHafs real verses rendering', () {
    testWidgets(
      'renders 1:1, 2:5, 11:41, 12:11, 52:37, 2:258 cleanly on Canvas and in RTL Text widgets',
      (tester) async {
        final rawList =
            json.decode(File('assets/quran_arabic.json').readAsStringSync())
                as List<dynamic>;
        String verseText(int s, int v) {
          final item = rawList.firstWhere(
            (e) => e['surah_id'] == s && e['ayah_number'] == v,
          );
          return formatArabicAyahText(
            item['uthmani_text'] as String,
            verseNumber: v,
          );
        }

        final targetVerses = <String, String>{
          '1:1': verseText(1, 1),
          '2:5': verseText(2, 5),
          '11:41': verseText(11, 41),
          // Include raw black-circle variants for 12:11 and 52:37 to confirm sanitization + rendering
          '12:11': formatArabicAyahText(
            '${verseText(12, 11)} تَأۡمَ\u06EBنَّا',
            verseNumber: 11,
          ),
          '52:37': formatArabicAyahText(
            '${verseText(52, 37)} ٱلۡمُص\u06E3يۡطِرُونَ',
            verseNumber: 37,
          ),
          '2:258': verseText(2, 258),
        };

        // Canvas paint check with UthmanicHafs + ar locale
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        double y = 12;
        for (final entry in targetVerses.entries) {
          final painter = TextPainter(
            text: TextSpan(
              text: entry.value,
              style: const TextStyle(
                fontFamily: 'UthmanicHafs',
                fontWeight: FontWeight.w400,
                fontSize: 24,
                height: 2.0,
                color: Color(0xFF1C2520),
              ),
            ),
            textDirection: TextDirection.rtl,
            locale: const Locale('ar'),
          )..layout(maxWidth: 680);
          expect(painter.width, greaterThan(0), reason: entry.key);
          expect(painter.height, greaterThan(0), reason: entry.key);
          painter.paint(canvas, Offset(700 - painter.width, y));
          y += painter.height + 12;
        }
        final picture = recorder.endRecording();
        final pngBytes = await tester.runAsync(() async {
          final img = await picture.toImage(720, y.ceil().clamp(100, 1400));
          return img.toByteData(format: ui.ImageByteFormat.png);
        });
        expect(pngBytes, isNotNull);
        expect(pngBytes!.lengthInBytes, greaterThan(1000));

        // Widget tree verification
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final entry in targetVerses.entries)
                      Text(
                        entry.value,
                        key: ValueKey('uthmanic_${entry.key}'),
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        locale: const Locale('ar'),
                        style: const TextStyle(
                          fontFamily: 'UthmanicHafs',
                          fontWeight: FontWeight.w400,
                          fontSize: 20,
                          height: 2.0,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        for (final key in targetVerses.keys) {
          final textWidget = tester.widget<Text>(
            find.byKey(ValueKey('uthmanic_$key')),
          );
          expect(textWidget.textDirection, TextDirection.rtl);
          expect(textWidget.locale, const Locale('ar'));
          expect(textWidget.style?.fontFamily, 'UthmanicHafs');
          expect(textWidget.data, isNot(contains('\u06DF')));
          expect(textWidget.data, isNot(contains('\u06E3')));
          expect(textWidget.data, isNot(contains('\u06EB')));
          expect(textWidget.data, isNot(contains('|')));
          expect(textWidget.data, isNot(contains('\u06DD')));
        }
      },
    );
  });

  group('VerseShareSheet Studio widget tests', () {
    Widget buildSheetHost({
      required String languageCode,
      required Widget Function(BuildContext) triggerBuilder,
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
          home: Scaffold(
            body: Builder(builder: triggerBuilder),
          ),
        ),
      );
    }

    testWidgets(
      'Verse Share mode renders 390px vertical card, 4 themes, toggle chips, watermark, copy text, and zero overflow on 360x640',
      (tester) async {
        final overflowErrors = <FlutterErrorDetails>[];
        final previousOnError = FlutterError.onError;
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        String? copiedText;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<dynamic, dynamic>;
            copiedText = args['text'] as String?;
          }
          return null;
        });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null);
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
            buildSheetHost(
              languageCode: 'th',
              triggerBuilder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    VerseShareSheet.show(
                      ctx,
                      surahId: '2',
                      verseId: '255',
                      surahName: 'อัลบะเกาะเราะฮฺ',
                      arabicText: 'ٱللَّهُ لَا\u06DF إِلَٰهَ إِلَّا هُوَ | ٢٥٥',
                      translationText:
                          'อัลลอฮฺนั้น ไม่มีผู้ใดที่ควรได้รับการเคารพภักดีโดยเที่ยงแท้นอกจากพระองค์',
                      translationLabel: 'ไทย - King Fahd (ปรับปรุง)',
                      shortTafsir: 'อายะฮฺอัลกุรซีย์คืออายะฮฺที่ยิ่งใหญ่ที่สุด',
                      shortTafsirSource: 'QuranEnc Thai Mokhtasar',
                      footnotes: [
                        FootnoteItem(
                          id: 1,
                          origId: 1,
                          text: 'หมายถึงผู้ทรงดำรงอยู่ด้วยพระองค์เอง',
                        ),
                      ],
                      wbwWords: const [
                        {
                          'text_uthmani': 'ٱللَّهُ',
                          'translation_th': 'อัลลอฮฺ',
                        },
                        {
                          'text_uthmani': 'لَا\u06DF',
                          'translation_th': 'ไม่มี',
                        },
                      ],
                      isThai: true,
                    );
                  },
                  child: const Text('Open Share'),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.tap(find.text('Open Share'));
          await tester.pumpAndSettle();

          // Header, watermark, and fixed 390px vertical card inside RepaintBoundary
          expect(find.text('แชร์อายะฮฺ'), findsOneWidget);
          expect(find.text('Thai Quran • quran-th.com'), findsOneWidget);
          expect(find.text('2:255'), findsOneWidget);

          final cardFinder = find.byKey(const ValueKey('verse_share_card'));
          expect(cardFinder, findsOneWidget);
          expect(tester.getSize(cardFinder).width, 390.0);

          final boundaryFinder = find.ancestor(
            of: cardFinder,
            matching: find.byType(RepaintBoundary),
          );
          expect(boundaryFinder, findsWidgets);

          // Verify Arabic inside card is sanitized and has no black-circle or pipe
          final cardArabic = tester.widget<Text>(
            find.descendant(
              of: cardFinder,
              matching: find.textContaining('ٱللَّهُ'),
            ).first,
          );
          expect(cardArabic.data, isNot(contains('\u06DF')));
          expect(cardArabic.data, isNot(contains('|')));
          expect(cardArabic.textDirection, TextDirection.rtl);
          expect(cardArabic.locale, const Locale('ar'));

          // Toggle WBW, Short Tafsir, Footnotes ON
          await tester.tap(find.text('คำต่อคำ (WBW)'));
          await tester.pumpAndSettle();
          expect(
            find.descendant(of: cardFinder, matching: find.text('อัลลอฮฺ')),
            findsOneWidget,
          );

          await tester.tap(find.text('ตัฟซีรสั้น'));
          await tester.pumpAndSettle();
          expect(
            find.descendant(
              of: cardFinder,
              matching: find.text('อายะฮฺอัลกุรซีย์คืออายะฮฺที่ยิ่งใหญ่ที่สุด'),
            ),
            findsOneWidget,
          );

          await tester.tap(find.text('เชิงอรรถ (1)'));
          await tester.pumpAndSettle();
          expect(
            find.descendant(
              of: cardFinder,
              matching: find.text('[1] หมายถึงผู้ทรงดำรงอยู่ด้วยพระองค์เอง'),
            ),
            findsOneWidget,
          );

          // Switch across all 4 themes and verify exact background colors
          Color? cardColor() {
            final container = tester.widget<Container>(cardFinder);
            return (container.decoration as BoxDecoration?)?.color;
          }

          expect(cardColor(), const Color(0xFFFDFBF7));

          await tester.tap(find.text('ครีมทอง'));
          await tester.pumpAndSettle();
          expect(cardColor(), const Color(0xFFFAF6EE));

          await tester.tap(find.text('ราตรี'));
          await tester.pumpAndSettle();
          expect(cardColor(), const Color(0xFF0B131E));

          await tester.tap(find.text('มินิมอล'));
          await tester.pumpAndSettle();
          expect(cardColor(), const Color(0xFFFFFFFF));

          await tester.tap(find.text('มรกต'));
          await tester.pumpAndSettle();
          expect(cardColor(), const Color(0xFFFDFBF7));

          // 4-button action bar includes Copy Text, Copy Image, Save Image, and Share
          expect(find.text('คัดลอกข้อความ'), findsOneWidget);
          expect(find.text('คัดลอกรูป'), findsOneWidget);
          expect(find.text('บันทึกภาพ'), findsOneWidget);
          expect(find.text('แชร์'), findsOneWidget);

          // Copy text button copies formatted payload and displays feedback
          await tester.tap(find.text('คัดลอกข้อความ'));
          await tester.pump();
          expect(copiedText, isNotNull);
          expect(copiedText, contains('อัลบะเกาะเราะฮฺ (2:255)'));
          expect(copiedText, contains('https://quran-th.com/surah/2#v-255'));
          expect(find.text('คัดลอกข้อความแล้ว'), findsOneWidget);
        } finally {
          FlutterError.onError = previousOnError;
        }

        expect(overflowErrors, isEmpty);
      },
    );

    testWidgets(
      'VerseShareSheet 4-button bottom bar invokes copyImage and saveImage via media_share channel',
      (tester) async {
        final previousOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.exceptionAsString().contains('allowRuntimeFetching')) {
            return;
          }
          previousOnError?.call(details);
        };

        const mediaShareChannel = MethodChannel(
          'com.thaiquran.app/media_share',
        );
        final mediaCalls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(mediaShareChannel, (call) async {
          mediaCalls.add(call);
          return true;
        });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(mediaShareChannel, null);
        });

        try {
          await tester.pumpWidget(
            buildSheetHost(
              languageCode: 'th',
              triggerBuilder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    VerseShareSheet.show(
                      ctx,
                      surahId: '2',
                      verseId: '255',
                      surahName: 'อัลบะเกาะเราะฮฺ',
                      arabicText: 'ٱللَّهُ لَا إِلَٰهَ إِلَّا هُوَ',
                      translationText:
                          'อัลลอฮฺนั้น ไม่มีผู้ใดที่ควรได้รับการเคารพภักดีนอกจากพระองค์',
                      isThai: true,
                    );
                  },
                  child: const Text('Open Share'),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.tap(find.text('Open Share'));
          await tester.pumpAndSettle();

          await tester.tap(find.text('คัดลอกรูป'));
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 150)),
          );
          await tester.pump();
          expect(mediaCalls.any((c) => c.method == 'copyImage'), isTrue);
          final copyCall = mediaCalls.firstWhere((c) => c.method == 'copyImage');
          expect(
            (copyCall.arguments as Map)['fileName'],
            'quran_2_255.png',
          );
          expect(
            ((copyCall.arguments as Map)['bytes'] as Uint8List).isNotEmpty,
            isTrue,
          );
          expect(find.text('คัดลอกรูปภาพแล้ว กดวางได้เลย'), findsOneWidget);

          await tester.tap(find.text('บันทึกภาพ'));
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 150)),
          );
          await tester.pump();
          expect(mediaCalls.any((c) => c.method == 'saveImage'), isTrue);
          expect(find.text('บันทึกรูปภาพลงอัลบั้มสำเร็จ'), findsOneWidget);
        } finally {
          FlutterError.onError = previousOnError;
        }
      },
    );

    testWidgets(
      'Tadabbur Reflection Share mode shows reflection + author toggles and hides cleanly on 360x640',
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

        try {
          await tester.pumpWidget(
            buildSheetHost(
              languageCode: 'th',
              triggerBuilder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    VerseShareSheet.show(
                      ctx,
                      surahId: '18',
                      verseId: '10',
                      surahName: 'อัลกะฮฺฟฺ',
                      arabicText: 'رَبَّنَا\u06DF ءَاتِنَا مِن لَّدُنكَ رَحۡمَةٗ',
                      translationText:
                          'ข้าแต่พระเจ้าของเรา โปรดประทานความเมตตาจากพระองค์แก่พวกเรา',
                      reflectionText:
                          'ดุอาอฺของชาวถ้ำสอนให้เรายึดมั่นในความเมตตาและการชี้นำจากอัลลอฮฺ',
                      reflectionAuthor: 'Ahmad',
                      shareUrlOverride:
                          'https://quran-th.com/tadabbur/community?surah=18&ayah=10',
                      isThai: true,
                    );
                  },
                  child: const Text('Share Tadabbur'),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.tap(find.text('Share Tadabbur'));
          await tester.pumpAndSettle();

          final cardFinder = find.byKey(const ValueKey('verse_share_card'));
          expect(find.text('แชร์ข้อคิดตะดับบุร'), findsOneWidget);
          expect(
            find.descendant(
              of: cardFinder,
              matching: find.text('ข้อคิดตะดับบุร • Tadabbur'),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: cardFinder,
              matching: find.text('— Ahmad'),
            ),
            findsOneWidget,
          );

          // Toggle Author OFF -> hidden from card
          await tester.tap(find.text('ผู้เขียน'));
          await tester.pumpAndSettle();
          expect(
            find.descendant(
              of: cardFinder,
              matching: find.text('— Ahmad'),
            ),
            findsNothing,
          );

          // Toggle Reflection OFF -> reflection box hidden from card
          await tester.tap(find.text('ข้อคิดตะดับบุร'));
          await tester.pumpAndSettle();
          expect(
            find.descendant(
              of: cardFinder,
              matching: find.text('ข้อคิดตะดับบุร • Tadabbur'),
            ),
            findsNothing,
          );
        } finally {
          FlutterError.onError = previousOnError;
        }

        expect(overflowErrors, isEmpty);
      },
    );
  });

  group('Screen & VerseCard Share Studio integration', () {
    testWidgets(
      'VerseCard header has Share icon that opens VerseShareSheet',
      (tester) async {
        SharedPreferences.setMockInitialValues({'languageCode': 'th'});
        final settings = SettingsProvider();
        final progress = ProgressProvider();
        final localReading = LocalReadingProvider();
        final transManager = TranslationManagerProvider();
        final thaiProtection = ThaiTextProtectionProvider();
        final audio = MushafAudioProvider();
        final notes = NotesProvider();
        final supabase = SupabaseProvider();
        final stats = StatsProvider();
        final repo = _FakeQuranRepository();
        final verse = Verse(
          id: '255',
          surahId: '2',
          thaiV3: 'อัลลอฮฺนั้น ไม่มีผู้ใดที่ควรได้รับการเคารพภักดีนอกจากพระองค์',
          thaiV2: 'อัลลอฮฺนั้น ไม่มีผู้ใดที่ควรได้รับการเคารพภักดีนอกจากพระองค์',
          english: 'Allah - there is no deity except Him.',
          arabic: 'ٱللَّهُ لَا\u06DF إِلَٰهَ إِلَّا هُوَ | ٢٥٥',
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<SettingsProvider>.value(value: settings),
              ChangeNotifierProvider<ProgressProvider>.value(value: progress),
              ChangeNotifierProvider<LocalReadingProvider>.value(
                value: localReading,
              ),
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
              builder: (context, child) {
                return MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(0.5)),
                  child: child!,
                );
              },
              home: Scaffold(
                body: SingleChildScrollView(
                  child: VerseCard(
                    verse: verse,
                    repository: repo,
                    index: 0,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));

        final shareIcon = find.byIcon(Icons.share_outlined);
        expect(shareIcon, findsOneWidget);

        await tester.tap(shareIcon);
        await tester.pumpAndSettle();

        expect(find.byType(VerseShareSheet), findsOneWidget);
        expect(find.text('Thai Quran • quran-th.com'), findsOneWidget);
        await tester.pump(const Duration(seconds: 2));
      },
    );

    testWidgets(
      'TadabburCommunityScreen Compose sheet renders sanitized live Arabic preview and Share opens VerseShareSheet',
      (tester) async {
        SharedPreferences.setMockInitialValues({'languageCode': 'th'});
        final settings = SettingsProvider();
        final transManager = TranslationManagerProvider();
        final now = DateTime.now().subtract(const Duration(minutes: 10));
        final note = TadabburNote(
          id: 'note-52-37',
          userId: 'user-1',
          surahId: '52',
          verseId: '37',
          noteText: 'ข้อคิดอันงดงามจากซูเราะฮฺอัตตูร',
          isPublic: true,
          isAnonymous: false,
          likesCount: 5,
          language: 'th',
          createdAt: now,
          updatedAt: now,
          userEmail: 'tester@example.com',
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<SettingsProvider>.value(value: settings),
              ChangeNotifierProvider<TranslationManagerProvider>.value(
                value: transManager,
              ),
            ],
            child: MaterialApp(
              home: TadabburCommunityScreen(
                repository: _FakeQuranRepository(),
                tadabburRepository: _FakeTadabburRepository([note]),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // Open Compose panel and verify live Arabic Ayah preview is sanitized
        await tester.tap(find.text('เขียนข้อคิด'));
        await tester.pumpAndSettle();
        expect(find.textContaining('ตัวอย่างอายะฮฺ'), findsOneWidget);
        expect(find.textContaining('\u06DF'), findsNothing);
        expect(find.textContaining('\u06E3'), findsNothing);
        expect(find.textContaining('\u06EB'), findsNothing);

        // Close Compose panel, then tap Share on the community note card
        await tester.tap(find.text('ปิด'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('แชร์'));
        await tester.tap(find.text('แชร์'));
        await tester.pumpAndSettle();

        expect(find.byType(VerseShareSheet), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('verse_share_card')),
            matching: find.text('ข้อคิดอันงดงามจากซูเราะฮฺอัตตูร'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'TadabburPrivateScreen renders sanitized Arabic Ayah and Share button opens VerseShareSheet on 360x640',
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

        try {
          SharedPreferences.setMockInitialValues({'languageCode': 'th'});
          final settings = SettingsProvider();
          final transManager = TranslationManagerProvider();
          final notesProv = NotesProvider();
          await notesProv.saveNote(
            surahId: '12',
            verseId: '11',
            noteText: 'บันทึกส่วนตัวเกี่ยวกับการไว้วางใจ',
            isPublic: false,
          );

          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<SettingsProvider>.value(value: settings),
                ChangeNotifierProvider<TranslationManagerProvider>.value(
                  value: transManager,
                ),
                ChangeNotifierProvider<NotesProvider>.value(value: notesProv),
              ],
              child: MaterialApp(
                home: TadabburPrivateScreen(
                  repository: _FakeQuranRepository(),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pumpAndSettle();

          expect(
            find.text('บันทึกส่วนตัวเกี่ยวกับการไว้วางใจ'),
            findsOneWidget,
          );
          // Verify sanitized Uthmanic Arabic Ayah with Arabic-Indic verse marker ١١
          final ayahWidget = tester.widget<Text>(
            find.textContaining('١١').first,
          );
          expect(ayahWidget.textDirection, TextDirection.rtl);
          expect(ayahWidget.locale, const Locale('ar'));
          expect(ayahWidget.style?.fontFamily, 'UthmanicHafs');
          expect(ayahWidget.data, isNot(contains('\u06DF')));
          expect(ayahWidget.data, isNot(contains('\u06E3')));
          expect(ayahWidget.data, isNot(contains('\u06EB')));
          expect(ayahWidget.data, isNot(contains('|')));

          final shareBtn = find.byIcon(Icons.share_outlined);
          expect(shareBtn, findsOneWidget);

          await tester.ensureVisible(shareBtn);
          await tester.pumpAndSettle();
          await tester.tap(shareBtn);
          await tester.pumpAndSettle();

          expect(find.byType(VerseShareSheet), findsOneWidget);
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('verse_share_card')),
              matching: find.text('บันทึกส่วนตัวเกี่ยวกับการไว้วางใจ'),
            ),
            findsOneWidget,
          );
        } finally {
          FlutterError.onError = previousOnError;
        }
        expect(overflowErrors, isEmpty);
      },
    );

    testWidgets(
      'NotesScreen renders sanitized Uthmanic Arabic preview and Share opens VerseShareSheet',
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

        try {
          SharedPreferences.setMockInitialValues({'languageCode': 'th'});
          final settings = SettingsProvider();
          final transManager = TranslationManagerProvider();
          final notesProv = NotesProvider();
          await notesProv.saveNote(
            surahId: '52',
            verseId: '37',
            noteText: 'ข้อคิดในสมุดบันทึกส่วนตัว',
            isPublic: false,
          );

          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<SettingsProvider>.value(value: settings),
                ChangeNotifierProvider<TranslationManagerProvider>.value(
                  value: transManager,
                ),
                ChangeNotifierProvider<NotesProvider>.value(value: notesProv),
              ],
              child: MaterialApp(
                home: NotesScreen(repository: _FakeQuranRepository()),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pumpAndSettle();

          expect(find.text('ข้อคิดในสมุดบันทึกส่วนตัว'), findsOneWidget);
          final ayahWidget = tester.widget<Text>(
            find.textContaining('٣٧').first,
          );
          expect(ayahWidget.textDirection, TextDirection.rtl);
          expect(ayahWidget.locale, const Locale('ar'));
          expect(ayahWidget.style?.fontFamily, 'UthmanicHafs');
          expect(ayahWidget.data, isNot(contains('\u06DF')));
          expect(ayahWidget.data, isNot(contains('\u06E3')));
          expect(ayahWidget.data, isNot(contains('\u06EB')));

          final shareBtn = find.byIcon(Icons.share_outlined);
          expect(shareBtn, findsOneWidget);
          await tester.tap(shareBtn);
          await tester.pumpAndSettle();

          expect(find.byType(VerseShareSheet), findsOneWidget);
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('verse_share_card')),
              matching: find.text('ข้อคิดในสมุดบันทึกส่วนตัว'),
            ),
            findsOneWidget,
          );
        } finally {
          FlutterError.onError = previousOnError;
        }
        expect(overflowErrors, isEmpty);
      },
    );

    testWidgets(
      'VerseCard shows Note pill, Favorite dialog with Tadabbur action, and openTadabbur controller hook',
      (tester) async {
        SharedPreferences.setMockInitialValues({'languageCode': 'th'});
        final settings = SettingsProvider();
        final progress = ProgressProvider();
        final localReading = LocalReadingProvider();
        final transManager = TranslationManagerProvider();
        final thaiProtection = ThaiTextProtectionProvider();
        final audio = MushafAudioProvider();
        final notes = NotesProvider();
        final supabase = _FakeLoggedInSupabaseProvider();
        final stats = StatsProvider();
        final repo = _FakeQuranRepository();
        final controller = VerseCardController();
        addTearDown(controller.dispose);
        final verse = Verse(
          id: '255',
          surahId: '2',
          thaiV3: 'อัลลอฮฺนั้น ไม่มีผู้ใดที่ควรได้รับการเคารพภักดีนอกจากพระองค์',
          thaiV2: 'อัลลอฮฺนั้น ไม่มีผู้ใดที่ควรได้รับการเคารพภักดีนอกจากพระองค์',
          english: 'Allah - there is no deity except Him.',
          arabic: 'ٱللَّهُ لَا إِلَٰهَ إِلَّا هُوَ',
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<SettingsProvider>.value(value: settings),
              ChangeNotifierProvider<ProgressProvider>.value(value: progress),
              ChangeNotifierProvider<LocalReadingProvider>.value(
                value: localReading,
              ),
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
              builder: (context, child) {
                return MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(0.5)),
                  child: child!,
                );
              },
              home: Scaffold(
                body: SingleChildScrollView(
                  child: VerseCard(
                    verse: verse,
                    repository: repo,
                    index: 0,
                    controller: controller,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initially no Note badge
        expect(find.text('โน้ต'), findsNothing);
        expect(controller.openTadabbur, isNotNull);

        // Tap Heart on un-favorited verse -> saves favorite & opens dialog
        await tester.ensureVisible(find.byIcon(Icons.favorite_border_rounded));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.favorite_border_rounded));
        await tester.pumpAndSettle();
        expect(find.text('รายการโปรด: อายะฮฺ 2:255'), findsOneWidget);
        expect(find.text('เขียนโน้ต / ตะดับบุร'), findsOneWidget);
        expect(find.text('ลบรายการโปรด'), findsOneWidget);
        expect(find.text('เรียบร้อย'), findsOneWidget);

        // Close dialog with เรียบร้อย -> heart remains favorited
        await tester.tap(find.text('เรียบร้อย'));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

        // Save a non-empty Tadabbur note -> Note pill appears in header
        await notes.saveNote(
          surahId: '2',
          verseId: '255',
          noteText: 'ข้อคิดเตือนใจเรื่องการพึ่งพาอัลลอฮฺ',
        );
        await tester.pumpAndSettle();
        expect(find.text('โน้ต'), findsOneWidget);

        // Tapping Heart when note exists shows View / Edit Note option
        await tester.ensureVisible(find.byIcon(Icons.favorite_rounded));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.favorite_rounded));
        await tester.pumpAndSettle();
        expect(find.text('ดู / แก้ไขโน้ตของฉัน'), findsOneWidget);
        await tester.tap(find.text('ดู / แก้ไขโน้ตของฉัน'));
        await tester.pumpAndSettle();
        expect(find.byType(TadabburPanel), findsOneWidget);

        // Close TadabburPanel, then verify controller.openTadabbur opens it too
        Navigator.of(tester.element(find.byType(TadabburPanel))).pop();
        await tester.pumpAndSettle();
        expect(find.byType(TadabburPanel), findsNothing);

        controller.openTadabbur!.call();
        await tester.pumpAndSettle();
        expect(find.byType(TadabburPanel), findsOneWidget);
      },
    );
  });
}
