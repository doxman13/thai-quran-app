import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
import 'package:thai_quran_app/screens/welcome_screen.dart';

class _StubQuranRepository extends QuranRepository {
  final Future<void> Function() onInit;
  _StubQuranRepository(this.onInit);

  @override
  Future<void> init() => onInit();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'languageCode': 'th'});
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

  Widget wrapWithProviders(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => LocalReadingProvider()),
        ChangeNotifierProvider(create: (_) => MushafReadingProvider()),
        ChangeNotifierProvider(create: (_) => StatsProvider()),
        ChangeNotifierProvider(create: (_) => SupabaseProvider()),
        ChangeNotifierProvider(create: (_) => NotesProvider()),
        ChangeNotifierProvider(create: (_) => TranslationManagerProvider()),
      ],
      child: MaterialApp(home: child),
    );
  }

  group('WelcomeScreen splash & loading flow', () {
    testWidgets(
      'renders full-bleed #0E5C59 backdrop with quran-th-logo-clean.svg without overflow on 360x640',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final boundaryKey = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: RepaintBoundary(
              key: boundaryKey,
              child: const WelcomeSplashCanvas(),
            ),
          ),
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.backgroundColor, const Color(0xFF0E5C59));
        expect(find.byType(SvgPicture), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        final logoCenter = tester.getCenter(find.byType(SvgPicture));
        expect(logoCenter.dy, lessThanOrEqualTo(320));

        // Verify the rendered SVG logo actually paints cream calligraphy (not a black fallback square)
        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1.0);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
          final data = bytes!.buffer.asUint8List();
          var blackCount = 0;
          var creamCount = 0;
          var tealCount = 0;
          for (var i = 0; i < data.length; i += 4) {
            final r = data[i];
            final g = data[i + 1];
            final b = data[i + 2];
            if (r < 5 && g < 5 && b < 5) blackCount++;
            if (r > 230 && g > 220 && b > 200) creamCount++;
            if (r == 14 && g == 92 && b == 89) tealCount++;
          }
          expect(blackCount, 0, reason: 'Logo SVG must not paint a black square');
          expect(creamCount, greaterThan(500), reason: 'Logo SVG must render cream calligraphy');
          expect(tealCount, greaterThan(1000), reason: 'Splash background must be brand teal');
        });
      },
    );

    testWidgets(
      'holds WelcomeSplashCanvas until both minimumDuration and repository.init finish',
      (tester) async {
        final initCompleter = Completer<void>();
        final repo = _StubQuranRepository(() => initCompleter.future);

        await tester.pumpWidget(
          wrapWithProviders(
            WelcomeScreen(
              repository: repo,
              minimumDuration: const Duration(seconds: 2),
            ),
          ),
        );
        await tester.pump();

        // Initially on splash screen
        expect(find.byType(WelcomeSplashCanvas), findsOneWidget);
        expect(find.byType(HomeScreen), findsNothing);

        // Even after minimum duration passes, still waits for slow repository.init()
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();
        expect(find.byType(WelcomeSplashCanvas), findsOneWidget);
        expect(find.byType(HomeScreen), findsNothing);

        // Once repository.init() completes, transitions cleanly into HomeScreen
        initCompleter.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.byType(WelcomeSplashCanvas), findsNothing);
      },
    );

    testWidgets(
      'waits for minimumDuration even when repository.init resolves immediately',
      (tester) async {
        final repo = _StubQuranRepository(() async {});

        await tester.pumpWidget(
          wrapWithProviders(
            WelcomeScreen(
              repository: repo,
              minimumDuration: const Duration(milliseconds: 2200),
            ),
          ),
        );
        await tester.pump();

        // Still on splash at 1.5s despite instant init()
        await tester.pump(const Duration(milliseconds: 1500));
        expect(find.byType(WelcomeSplashCanvas), findsOneWidget);
        expect(find.byType(HomeScreen), findsNothing);

        // Transitions after 2.2s minimum hold + fade
        await tester.pump(const Duration(milliseconds: 800));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(HomeScreen), findsOneWidget);
      },
    );
  });
}
