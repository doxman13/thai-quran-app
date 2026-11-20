import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thai_quran_app/widgets/tajweed_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Render exact comparison of shayan bug vs fix', () async {
    final fontData = File('assets/Tajweed/DigitalKhattQuranicV1.otf').readAsBytesSync();
    final fontLoader = FontLoader('Tajweed');
    fontLoader.addFont(Future.value(ByteData.view(fontData.buffer)));
    await fontLoader.load();

    final testCases = <String, TextSpan>{
      'A. Current Bug in App (Hamza drowned on baseline):\n   شَيۡـ + ـًٔا': const TextSpan(
        children: [
          TextSpan(text: 'شَيۡـ', style: TextStyle(fontFamily: 'Tajweed', fontSize: 44, color: Colors.black)),
          TextSpan(text: 'ـًٔا', style: TextStyle(fontFamily: 'Tajweed', fontSize: 44, color: Color(0xFF169200))),
        ],
      ),
      'B. The Clean Fix (Hamza on tooth, Tanween colored):\n   شَيۡـٔ + ـًا': const TextSpan(
        children: [
          TextSpan(text: 'شَيۡـٔ', style: TextStyle(fontFamily: 'Tajweed', fontSize: 44, color: Colors.black)),
          TextSpan(text: 'ـًا', style: TextStyle(fontFamily: 'Tajweed', fontSize: 44, color: Color(0xFF169200))),
        ],
      ),
      'C. Full phrase: جِئۡتَ شَيۡـًٔا نُّكۡرًا (with fix)': const TextSpan(
        children: [
          TextSpan(text: 'جِئۡتَ شَيۡـٔ', style: TextStyle(fontFamily: 'Tajweed', fontSize: 38, color: Colors.black)),
          TextSpan(text: 'ـًا', style: TextStyle(fontFamily: 'Tajweed', fontSize: 38, color: Color(0xFF169200))),
          TextSpan(text: ' ', style: TextStyle(fontFamily: 'Tajweed', fontSize: 38, color: Colors.black)),
          TextSpan(text: 'ن', style: TextStyle(fontFamily: 'Tajweed', fontSize: 38, color: Color(0xFF169200))),
          TextSpan(text: 'ُّكۡرًا', style: TextStyle(fontFamily: 'Tajweed', fontSize: 38, color: Colors.black)),
        ],
      ),
    };

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 950, 600));
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(const Rect.fromLTWH(0, 0, 950, 600), bgPaint);

    double y = 40.0;
    for (final entry in testCases.entries) {
      final labelPainter = TextPainter(
        text: TextSpan(
          text: entry.key,
          style: const TextStyle(color: Colors.black87, fontSize: 16, fontFamily: 'Arial', height: 1.4),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(canvas, Offset(30, y));

      final arabicPainter = TextPainter(
        text: entry.value,
        textDirection: TextDirection.rtl,
      )..layout();
      arabicPainter.paint(canvas, Offset(560, y + 10));

      y += 180.0;
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(950, 600);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    final tempDir = Directory.systemTemp.createTempSync('tajweed_render');
    final outFile = File('${tempDir.path}/rendered_shayan_fix_clear.png');
    outFile.writeAsBytesSync(pngBytes);
    print("Rendered clear comparison successfully to ${outFile.path}!");
  });

  group('TajweedText verse end circular mark', () {
    test('ensureVerseEndMark prefixes U+06DD before trailing verse digits', () {
      expect(
        TajweedText.ensureVerseEndMark(
          'قُلۡ هُوَ <rule class=ham_wasl>ٱ</rule>للَّهُ أَحَ<rule class=qalaqah>دٌ</rule> ١',
        ),
        'قُلۡ هُوَ <rule class=ham_wasl>ٱ</rule>للَّهُ أَحَ<rule class=qalaqah>دٌ</rule> \u06DD١',
      );

      expect(
        TajweedText.ensureVerseEndMark('فَٱنصُرۡنَا ٢٨٦'),
        'فَٱنصُرۡنَا \u06DD٢٨٦',
      );

      // Idempotent if U+06DD is already present
      expect(
        TajweedText.ensureVerseEndMark('قُلۡ \u06DD١٩'),
        'قُلۡ \u06DD١٩',
      );

      // Fallback when verseNumber is supplied separately
      expect(
        TajweedText.ensureVerseEndMark('بِسۡمِ ٱللَّهِ', verseNumber: '12'),
        'بِسۡمِ ٱللَّهِ \u06DD١٢',
      );
    });

    testWidgets('TajweedText renders RichText with U+06DD circle marker',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TajweedText(
              text:
                  'قُلۡ هُوَ <rule class=ham_wasl>ٱ</rule>للَّهُ أَحَ<rule class=qalaqah>دٌ</rule> ١',
              verseNumber: '1',
            ),
          ),
        ),
      );

      final richText = tester.widget<RichText>(find.byType(RichText));
      final plainText = richText.text.toPlainText();
      expect(plainText, contains('\u06DD١'));
      expect(plainText, isNot(contains('\u06DD\u06DD')));
    });
  });
}
