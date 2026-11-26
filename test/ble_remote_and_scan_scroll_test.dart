import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thai_quran_app/data/quran_foundation_repository.dart';
import 'package:thai_quran_app/data/quran_repository.dart';
import 'package:thai_quran_app/models/hifz_session_config.dart';
import 'package:thai_quran_app/providers/ble_remote_provider.dart';
import 'package:thai_quran_app/providers/local_reading_provider.dart';
import 'package:thai_quran_app/providers/mushaf_audio_provider.dart';
import 'package:thai_quran_app/providers/mushaf_reading_provider.dart';
import 'package:thai_quran_app/providers/notes_provider.dart';
import 'package:thai_quran_app/providers/recitation_tracker_provider.dart';
import 'package:thai_quran_app/providers/settings_provider.dart';
import 'package:thai_quran_app/providers/stats_provider.dart';
import 'package:thai_quran_app/providers/supabase_provider.dart';
import 'package:thai_quran_app/providers/translation_manager_provider.dart';
import 'package:thai_quran_app/screens/hifz_memorize_screen.dart';
import 'package:thai_quran_app/screens/hifz_settings_screen.dart';
import 'package:thai_quran_app/screens/settings_screen.dart';

class _FakeBleRemoteProvider extends BleRemoteProvider {
  List<ScanResult> fakeResults = [];
  BluetoothDevice? lastConnectAttempt;

  _FakeBleRemoteProvider() : super(autoConnect: false);

  @override
  List<ScanResult> get scanResults => fakeResults;

  @override
  Future<void> connectToDevice(
    BluetoothDevice device, {
    bool isAutoConnect = false,
  }) async {
    lastConnectAttempt = device;
  }

  @override
  Future<void> stopScan() async {}
}

ScanResult _makeScanResult(int index, String advName) {
  return ScanResult(
    device: BluetoothDevice.fromId('AA:BB:CC:DD:EE:${index.toRadixString(16).padLeft(2, '0')}'),
    advertisementData: AdvertisementData(
      advName: advName,
      txPowerLevel: null,
      appearance: null,
      connectable: true,
      manufacturerData: const {},
      serviceData: const {},
      serviceUuids: const [],
    ),
    rssi: -40 - index,
    timeStamp: DateTime(2026, 1, 1),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'languageCode': 'en'});
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

  group('Bluetooth remote & scan list scrolling', () {
    testWidgets(
      'BleDeviceManagementUI resolves advName and scrolls a long scan list to select the bottom device',
      (tester) async {
        final fakeBle = _FakeBleRemoteProvider()
          ..fakeResults = [
            for (var i = 1; i <= 15; i++) _makeScanResult(i, 'Zikir Ring #$i'),
          ];
        final settings = SettingsProvider();
        addTearDown(() {
          fakeBle.dispose();
          settings.dispose();
        });

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<BleRemoteProvider>.value(value: fakeBle),
              ChangeNotifierProvider<SettingsProvider>.value(value: settings),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: BleDeviceManagementUI(),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Discovered Devices (15)'), findsOneWidget);
        expect(find.text('Zikir Ring #1'), findsOneWidget);

        final bottomItem = find.text('Zikir Ring #15');
        await tester.scrollUntilVisible(
          bottomItem,
          200,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();

        expect(bottomItem, findsOneWidget);
        await tester.tap(bottomItem);
        await tester.pump();

        expect(fakeBle.lastConnectAttempt, isNotNull);
        expect(
          fakeBle.lastConnectAttempt!.remoteId.toString(),
          'AA:BB:CC:DD:EE:0f',
        );
      },
    );

    testWidgets(
      'SettingsScreen Hifz devices sheet exposes input mode options and updates SettingsProvider',
      (tester) async {
        final fakeBle = _FakeBleRemoteProvider();
        final settings = SettingsProvider();
        addTearDown(() {
          fakeBle.dispose();
          settings.dispose();
        });

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<BleRemoteProvider>.value(value: fakeBle),
              ChangeNotifierProvider<SettingsProvider>.value(value: settings),
              ChangeNotifierProvider(create: (_) => LocalReadingProvider()),
              ChangeNotifierProvider(create: (_) => MushafReadingProvider()),
              ChangeNotifierProvider(create: (_) => MushafAudioProvider()),
              ChangeNotifierProvider(create: (_) => NotesProvider()),
              ChangeNotifierProvider(create: (_) => StatsProvider()),
              ChangeNotifierProvider(create: (_) => SupabaseProvider()),
              ChangeNotifierProvider(create: (_) => TranslationManagerProvider()),
            ],
            child: const MaterialApp(
              home: SettingsScreen(
                initialCategory: SettingsCategoryTab.hifz,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Bluetooth Remote / Shutter'), findsOneWidget);
        expect(find.text('BLE Smart Ring'), findsOneWidget);

        await tester.tap(find.text('Bluetooth Remote / Shutter'));
        await tester.pumpAndSettle();
        expect(settings.hifzInputMode, HifzInputMode.bluetoothShutter);

        await tester.tap(find.text('BLE Smart Ring'));
        await tester.pumpAndSettle();
        expect(settings.hifzInputMode, HifzInputMode.bleSmartRing);
      },
    );

    test('BleRemoteProvider parses BEIQI-S7 and fallback click notifications', () {
      final ble = BleRemoteProvider(autoConnect: false);
      addTearDown(ble.dispose);

      expect(ble.clickCount, 0);

      // Mode change sets baseline without incrementing
      ble.handleNotificationForTest([0x06, 0x01, 0x00, 0x00, 0x05]);
      expect(ble.clickCount, 0);

      // Increment in same mode increments clickCount
      ble.handleNotificationForTest([0x06, 0x01, 0x00, 0x00, 0x06]);
      expect(ble.clickCount, 1);
    });

    testWidgets(
      'HifzMemorizeScreen opens phone-friendly Quick Settings bottom sheet and keeps it open across toggles',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'languageCode': 'en',
          'voice_recitation_enabled': false,
        });
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final fakeBle = _FakeBleRemoteProvider();
        final settings = SettingsProvider();
        final tracker = RecitationTrackerProvider();
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await settings.setVoiceRecitationEnabled(false);
        });
        addTearDown(() {
          fakeBle.dispose();
          settings.dispose();
        });

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<BleRemoteProvider>.value(value: fakeBle),
              ChangeNotifierProvider<SettingsProvider>.value(value: settings),
              ChangeNotifierProvider(create: (_) => MushafAudioProvider()),
              ChangeNotifierProvider(create: (_) => MushafReadingProvider()),
              ChangeNotifierProvider(create: (_) => NotesProvider()),
              ChangeNotifierProvider<RecitationTrackerProvider>.value(
                value: tracker,
              ),
              ChangeNotifierProvider(create: (_) => TranslationManagerProvider()),
            ],
            child: MaterialApp(
              home: HifzMemorizeScreen(
                quranRepository: QuranRepository(),
                foundationRepository: QuranFoundationRepository(),
                initialSessionType: HifzSessionType.newVerses,
                surahNumber: 1,
                startVerse: 1,
                endVerse: 3,
                chunkLongVerses: false,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(find.byTooltip('Quick settings'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Quick Settings'), findsOneWidget);
        expect(find.text('Dark Mode'), findsOneWidget);
        expect(find.text('Keep Screen Awake'), findsOneWidget);
        expect(find.text('BT Remote'), findsOneWidget);

        // Navigation/report clutter should not live in in-session Quick Settings
        expect(find.text('Select Range'), findsNothing);
        expect(find.text('Repetition Report'), findsNothing);
        expect(find.text('Mastery List'), findsNothing);
        expect(find.text('How to Hifz'), findsNothing);
        expect(find.text('Main Settings'), findsNothing);
        expect(find.text('Exit Session'), findsNothing);

        // Toggle Dark Mode and verify the sheet stays open
        await tester.tap(find.text('Dark Mode'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('Quick Settings'), findsOneWidget);
        expect(settings.isDarkMode, isTrue);

        // Switch input mode inline inside Quick Settings
        await tester.ensureVisible(find.text('BT Remote'));
        await tester.pump();
        await tester.tap(find.text('BT Remote'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(settings.hifzInputMode, HifzInputMode.bluetoothShutter);
        expect(find.text('Quick Settings'), findsOneWidget);

        // Open Bluetooth Devices sheet directly over Hifz and tap Done to return cleanly
        await tester.ensureVisible(find.text('Scan & Configure Bluetooth Devices'));
        await tester.pump();
        await tester.tap(find.text('Scan & Configure Bluetooth Devices'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Hifz Remote & BLE Devices'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
        await tester.tap(find.text('Done'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(HifzMemorizeScreen), findsOneWidget);
        expect(find.byType(SettingsScreen), findsNothing);
      },
    );

    testWidgets(
      'HifzMemorizeScreen completing verse-by-verse reveal completes 1 tally and resets for next round',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'languageCode': 'en',
          'voice_recitation_enabled': false,
        });
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final fakeBle = _FakeBleRemoteProvider();
        final settings = SettingsProvider();
        final tracker = RecitationTrackerProvider();
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await settings.setVoiceRecitationEnabled(false);
        });
        addTearDown(() {
          fakeBle.dispose();
          settings.dispose();
        });

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<BleRemoteProvider>.value(value: fakeBle),
              ChangeNotifierProvider<SettingsProvider>.value(value: settings),
              ChangeNotifierProvider(create: (_) => MushafAudioProvider()),
              ChangeNotifierProvider(create: (_) => MushafReadingProvider()),
              ChangeNotifierProvider(create: (_) => NotesProvider()),
              ChangeNotifierProvider<RecitationTrackerProvider>.value(
                value: tracker,
              ),
              ChangeNotifierProvider(
                create: (_) => TranslationManagerProvider(),
              ),
            ],
            child: MaterialApp(
              home: HifzMemorizeScreen(
                quranRepository: QuranRepository(),
                foundationRepository: QuranFoundationRepository(),
                initialSessionType: HifzSessionType.review,
                reviewGranularity: ReviewGranularity.byVerses,
                reviewTargetParams: const ReviewTargetParams(
                  surahNumber: 1,
                  startVerse: 1,
                  endVerse: 3,
                ),
                surahNumber: 1,
                startVerse: 1,
                endVerse: 3,
                chunkLongVerses: false,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Visible phase: step-reveal rail button should not appear yet
        expect(find.text('Ayah 1'), findsNothing);

        // Complete 2 visible repetitions to enter Hidden stage
        await tester.tap(find.textContaining('Tally  0/2'));
        await tester.pump();
        await tester.tap(find.textContaining('Tally  1/2'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1700));

        // Hidden phase starts at 0/2 with Ayah 1 ready to reveal
        expect(find.text('Hidden'), findsOneWidget);
        expect(find.textContaining('Tally  0/2'), findsOneWidget);
        expect(find.text('Ayah 1'), findsOneWidget);

        // Reveal verse 1 and 2 without completing round yet
        await tester.tap(find.text('Ayah 1'));
        await tester.pump();
        expect(find.text('Ayah 2'), findsOneWidget);
        expect(find.textContaining('Tally  0/2'), findsOneWidget);

        await tester.tap(find.text('Ayah 2'));
        await tester.pump();
        expect(find.text('Ayah 3'), findsOneWidget);

        // Revealing the last verse (Ayah 3) completes 1 tally immediately
        await tester.tap(find.text('Ayah 3'));
        await tester.pump();
        expect(find.text('Done'), findsOneWidget);
        expect(find.textContaining('Tally  1/2'), findsOneWidget);

        // After brief reveal hold, resets cleanly back to Ayah 1 for round 1/2
        await tester.pump(const Duration(milliseconds: 1000));
        expect(find.text('Ayah 1'), findsOneWidget);
        expect(find.textContaining('Tally  1/2'), findsOneWidget);

        // Manual Tally after revealing Ayah 1 resets reveal back to Ayah 1
        await tester.tap(find.text('Ayah 1'));
        await tester.pump();
        expect(find.text('Ayah 2'), findsOneWidget);
      },
    );
  });
}
