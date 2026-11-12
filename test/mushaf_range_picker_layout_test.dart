import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thai_quran_app/data/quran_foundation_repository.dart';
import 'package:thai_quran_app/data/quran_repository.dart';
import 'package:thai_quran_app/models/mushaf_models.dart';
import 'package:thai_quran_app/providers/settings_provider.dart';
import 'package:thai_quran_app/screens/hifz_mushaf_range_picker_screen.dart';
import 'package:thai_quran_app/screens/mushaf_reader_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HifzMushafRangePicker Layout & Structure Tests', () {
    test('HifzMushafRangePickerResult stores selected range correctly', () {
      const result = HifzMushafRangePickerResult(
        surah: 2,
        startVerse: 1,
        endVerse: 5,
        page: 2,
      );

      expect(result.surah, 2);
      expect(result.startVerse, 1);
      expect(result.endVerse, 5);
      expect(result.page, 2);
    });

    testWidgets('Screen renders PageView inside Expanded and BottomBar below it without overlap', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();
      final quranRepo = QuranRepository();
      final foundationRepo = QuranFoundationRepository();

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: MaterialApp(
            home: HifzMushafRangePickerScreen(
              quranRepository: quranRepo,
              foundationRepository: foundationRepo,
              initialSurah: 1,
              initialStartVerse: 1,
              initialEndVerse: 7,
              initialPage: 1,
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify layout: Scaffold -> SafeArea -> Column -> [Expanded(PageView), BottomBar]
      final columnFinder = find.byType(Column);
      expect(columnFinder, findsWidgets);

      // Verify Expanded wraps PageView
      final expandedFinder = find.ancestor(
        of: find.byType(PageView),
        matching: find.byType(Expanded),
      );
      expect(expandedFinder, findsOneWidget);

      // Verify bottom bar exists and contains collapse chevron
      final collapseIconFinder = find.byIcon(Icons.keyboard_arrow_down_rounded);
      expect(collapseIconFinder, findsOneWidget);

      // Tap collapse button to minimize the bar
      await tester.tap(collapseIconFinder);
      await tester.pumpAndSettle();

      // Now expand chevron should be visible
      final expandIconFinder = find.byIcon(Icons.keyboard_arrow_up_rounded);
      expect(expandIconFinder, findsOneWidget);

      // Tap expand to restore
      await tester.tap(expandIconFinder);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    });

    testWidgets('MushafLine routes a short tap to onVerseTap (range selection)',
        (tester) async {
      const word = MushafWord(
        text: 'بِسْمِ',
        verseKey: '1:1',
        lineNumber: 1,
        position: 1,
      );
      String? tappedVerseKey;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: MushafLine(
                  line: const [word],
                  fontFamily: 'UthmanicHafs',
                  mushafId: 2,
                  pageNumber: 1,
                  lineWidth: 300,
                  lineHeight: 1.6,
                  lineVerticalPadding: 0,
                  wordPadding: 0,
                  verseEndWords: const {word},
                  surahStartsByLine: const {},
                  highlightedVerseKey: null,
                  enableVerseTap: true,
                  onVerseTap: (key) => tappedVerseKey = key,
                  onVerseLongPressStart: (_) {},
                  onVerseLongPress: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.descendant(
          of: find.byType(MushafLine),
          matching: find.byType(RichText),
        ),
      );
      await tester.pump();

      expect(tappedVerseKey, '1:1');
    });
  });
}
