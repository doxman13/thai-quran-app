import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thai_quran_app/providers/settings_provider.dart';
import 'package:thai_quran_app/providers/translation_manager_provider.dart';
import 'package:thai_quran_app/shared/translation_constants.dart';
import 'package:thai_quran_app/utils/html_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TranslationConstants Tests', () {
    test('Alias resolution maps correctly', () {
      expect(TranslationConstants.resolveTranslationId('en_saheeh'), '20');
      expect(TranslationConstants.resolveTranslationId('en_hilali_khan'), '203');
      expect(TranslationConstants.resolveTranslationId('en_bridges'), '149');
      expect(TranslationConstants.resolveTranslationId('thai_orig'), '230');
      expect(TranslationConstants.resolveTranslationId('thai_v3'), 'thai_v3');
      expect(TranslationConstants.resolveTranslationId('en_usmani'), 'en_usmani');
      expect(TranslationConstants.resolveTranslationId('ms_basmeih'), 'ms_basmeih');
    });

    test('ApiId resolution maps correctly', () {
      expect(TranslationConstants.resolveApiId('en_saheeh'), 20);
      expect(TranslationConstants.resolveApiId('20'), 20);
      expect(TranslationConstants.resolveApiId('en_bridges'), 149);
      expect(TranslationConstants.resolveApiId('149'), 149);
      expect(TranslationConstants.resolveApiId('thai_v3'), isNull);
      expect(TranslationConstants.resolveApiId('en_usmani'), isNull);
    });

    test('isBuiltIn returns true only for offline database translations', () {
      expect(TranslationConstants.isBuiltIn('thai_v3'), isTrue);
      expect(TranslationConstants.isBuiltIn('en_usmani'), isTrue);
      expect(TranslationConstants.isBuiltIn('ms_basmeih'), isTrue);
      expect(TranslationConstants.isBuiltIn('en_saheeh'), isFalse);
      expect(TranslationConstants.isBuiltIn('20'), isFalse);
      expect(TranslationConstants.isBuiltIn('149'), isFalse);
    });

    test('getAllOptions provides unified and consistently sorted translations', () {
      final options = TranslationConstants.getAllOptions();
      // First must be thai_v3
      expect(options.first.id, equals('thai_v3'));
      // All 3 built-ins and 6 downloadable translations must be present
      final ids = options.map((o) => o.id).toList();
      expect(ids, containsAll(['thai_v3', 'en_usmani', 'ms_basmeih', '20', '203', '149', '85', '230', '51']));
      expect(options.length, equals(9));
    });
  });

  group('Bridges HTML Parsing & Floating Superscript Tests', () {
    testWidgets('Parses Bridges <a class="sup"><sup>sg </sup></a> into floating ˢᵍ', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();

      late BuildContext capturedContext;

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: settings,
          child: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox();
            },
          ),
        ),
      );

      const rawBridgesText = 'So if they debate with you<a class="sup"><sup>sg </sup></a>, then say...';
      final spans = HtmlParser.parseTranslationText(
        capturedContext,
        rawBridgesText,
        const TextStyle(fontSize: 16, color: Colors.black),
        Colors.blue,
      );

      final fullText = spans.map((s) => s.text).join();
      expect(fullText, contains('youˢᵍ, then say...'));
      expect(fullText, isNot(contains('<a')));
      expect(fullText, isNot(contains('class=')));
      expect(fullText, isNot(contains('<sup>')));
    });

    testWidgets('Parses raw Bridges <a class=sub>pl</a> and unquoted classes into floating ᵖˡ', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();

      late BuildContext capturedContext;

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: settings,
          child: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox();
            },
          ),
        ),
      );

      const rawText = 'you<a class=sub>pl</a> and they<a class="sub">dl</a> went';
      final spans = HtmlParser.parseTranslationText(
        capturedContext,
        rawText,
        const TextStyle(fontSize: 16, color: Colors.black),
        Colors.blue,
      );

      final fullText = spans.map((s) => s.text).join();
      expect(fullText, equals('youᵖˡ and theyᵈˡ went'));
      expect(fullText, isNot(contains('<a')));
      expect(fullText, isNot(contains('class=sub')));
    });

    testWidgets('Cleans formatting tags and preserves footnote links', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();

      late BuildContext capturedContext;

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: settings,
          child: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox();
            },
          ),
        ),
      );

      const rawText = '<span class="h">Master<sup foot_note="79577" class="qiraat">1</sup> </span>of the Day, not those who incurred<i class="s">(Your) </i>wrath';
      final spans = HtmlParser.parseTranslationText(
        capturedContext,
        rawText,
        const TextStyle(fontSize: 16, color: Colors.black),
        Colors.blue,
      );

      final fullText = spans.map((s) => s.text).join();
      expect(fullText, contains('Master[1] of the Day, not those who incurred(Your) wrath'));
      expect(fullText, isNot(contains('<span')));
      expect(fullText, isNot(contains('<i class=')));
    });
  });
}
