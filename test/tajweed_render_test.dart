import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Test al-ayat rendering', () async {
    final fontData = File('assets/Tajweed/DigitalKhattQuranicV1.otf').readAsBytesSync();
    final fontLoader = FontLoader('Tajweed');
    fontLoader.addFont(Future.value(ByteData.view(fontData.buffer)));
    await fontLoader.load();

    final testCases = <String, String>{
      '1. U+0623 + Maddah: ٱلۡأٓيَٰتِ': '\u0671\u0644\u06e1\u0623\u0653\u064a\u064e\u0670\u062a\u0650',
      '2. Tatweel + Hamza + Dagger: ٱلۡـَٰٔيَٰتِ': '\u0671\u0644\u06e1\u0640\u0654\u0670\u064a\u064e\u0670\u062a\u0650',
      '3. Tatweel + Hamza + Fatha + Dagger: ٱلۡـَٰٔيَٰتِ': '\u0671\u0644\u06e1\u0640\u0654\u064e\u0670\u064a\u064e\u0670\u062a\u0650',
    };

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 800, 400));
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(const Rect.fromLTWH(0, 0, 800, 400), bgPaint);

    double y = 40.0;
    for (final entry in testCases.entries) {
      final labelPainter = TextPainter(
        text: TextSpan(
          text: entry.key,
          style: const TextStyle(color: Colors.black, fontSize: 16, fontFamily: 'Arial'),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(canvas, Offset(20, y));

      final arabicPainter = TextPainter(
        text: TextSpan(
          text: entry.value,
          style: const TextStyle(
            fontFamily: 'Tajweed',
            fontSize: 34,
            color: Colors.black,
          ),
        ),
        textDirection: TextDirection.rtl,
      )..layout();
      arabicPainter.paint(canvas, Offset(450, y - 5));

      y += 100.0;
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(800, 400);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    final outFile = File('C:/Users/E/.gemini/antigravity-cli/brain/c09a8df2-682b-4ce3-ba34-f609d8b6ae49/scratch/rendered_ayat_test.png');
    outFile.writeAsBytesSync(pngBytes);
  });
}
