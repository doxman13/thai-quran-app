import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thai_quran_app/providers/settings_provider.dart';
import 'package:thai_quran_app/services/app_update_service.dart';
import 'package:thai_quran_app/widgets/app_update_dialog.dart';

AppVersionConfig _sampleConfig({
  String minVersion = '1.0.0',
  int minBuildNumber = 1,
  String latestVersion = '1.0.2',
  int latestBuildNumber = 5,
  bool isForceUpdate = false,
  String updateUrl =
      'https://play.google.com/store/apps/details?id=com.thaiquran.app',
  String? releaseNotesTh = '• เพิ่มฟีเจอร์ใหม่',
  String? releaseNotesEn = '• Added new features',
}) {
  return AppVersionConfig(
    platform: 'android',
    minVersion: minVersion,
    minBuildNumber: minBuildNumber,
    latestVersion: latestVersion,
    latestBuildNumber: latestBuildNumber,
    isForceUpdate: isForceUpdate,
    updateUrl: updateUrl,
    titleTh: 'มีเวอร์ชันใหม่พร้อมใช้งาน',
    titleEn: 'Update Available',
    messageTh: 'กรุณาอัปเดตเป็นเวอร์ชันล่าสุด',
    messageEn: 'Please update to the latest version.',
    releaseNotesTh: releaseNotesTh,
    releaseNotesEn: releaseNotesEn,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppUpdateService.instance.resetForTesting();
  });

  group('AppUpdateService Version Comparison & Evaluation', () {
    test('compareSemver handles standard, v-prefixed, and pre-release strings', () {
      expect(AppUpdateService.compareSemver('1.0.1', '1.0.2'), lessThan(0));
      expect(AppUpdateService.compareSemver('1.0.2', '1.0.2'), equals(0));
      expect(AppUpdateService.compareSemver('v1.0.3', '1.0.2'), greaterThan(0));
      expect(AppUpdateService.compareSemver('1.0.2+4', '1.0.2'), equals(0));
      expect(AppUpdateService.compareSemver('1.1', '1.1.0'), equals(0));
    });

    test('isVersionOlder considers semver precedence before build number', () {
      expect(
        AppUpdateService.isVersionOlder(
          currentVersion: '1.0.2',
          currentBuild: 4,
          targetVersion: '1.0.2',
          targetBuild: 5,
        ),
        isTrue,
      );
      expect(
        AppUpdateService.isVersionOlder(
          currentVersion: '1.0.3',
          currentBuild: 1,
          targetVersion: '1.0.2',
          targetBuild: 99,
        ),
        isFalse,
      );
      expect(
        AppUpdateService.isVersionOlder(
          currentVersion: '1.0.2',
          currentBuild: 5,
          targetVersion: '1.0.2',
          targetBuild: 0,
        ),
        isFalse,
      );
    });

    test('evaluateConfig returns forceUpdateRequired when below min version/build', () {
      final result = AppUpdateService.evaluateConfig(
        currentVersion: '1.0.0',
        currentBuildNumber: 2,
        config: _sampleConfig(
          minVersion: '1.0.1',
          minBuildNumber: 3,
          latestVersion: '1.0.2',
          latestBuildNumber: 5,
          isForceUpdate: false,
        ),
      );

      expect(result.status, equals(AppUpdateStatus.forceUpdateRequired));
      expect(result.isForced, isTrue);
      expect(result.hasUpdate, isTrue);
    });

    test('evaluateConfig returns softUpdateAvailable when below latest and not forced', () {
      final result = AppUpdateService.evaluateConfig(
        currentVersion: '1.0.2',
        currentBuildNumber: 4,
        config: _sampleConfig(
          minVersion: '1.0.0',
          minBuildNumber: 1,
          latestVersion: '1.0.2',
          latestBuildNumber: 5,
          isForceUpdate: false,
        ),
      );

      expect(result.status, equals(AppUpdateStatus.softUpdateAvailable));
      expect(result.isForced, isFalse);
      expect(result.hasUpdate, isTrue);
    });

    test('evaluateConfig returns forceUpdateRequired when below latest and isForceUpdate is true', () {
      final result = AppUpdateService.evaluateConfig(
        currentVersion: '1.0.2',
        currentBuildNumber: 4,
        config: _sampleConfig(
          latestVersion: '1.0.2',
          latestBuildNumber: 5,
          isForceUpdate: true,
        ),
      );

      expect(result.status, equals(AppUpdateStatus.forceUpdateRequired));
    });

    test('evaluateConfig returns upToDate when URL is empty or placeholder', () {
      final emptyUrlResult = AppUpdateService.evaluateConfig(
        currentVersion: '1.0.0',
        currentBuildNumber: 1,
        config: _sampleConfig(updateUrl: ''),
      );
      final placeholderUrlResult = AppUpdateService.evaluateConfig(
        currentVersion: '1.0.0',
        currentBuildNumber: 1,
        config: _sampleConfig(
          updateUrl: 'https://testflight.apple.com/join/YOUR_TESTFLIGHT_LINK',
        ),
      );

      expect(emptyUrlResult.status, equals(AppUpdateStatus.upToDate));
      expect(placeholderUrlResult.status, equals(AppUpdateStatus.upToDate));
    });

    test('soft update dismissal respects 24h cooldown and resets on newer version', () async {
      final config5 = _sampleConfig(latestVersion: '1.0.2', latestBuildNumber: 5);
      final config6 = _sampleConfig(latestVersion: '1.0.2', latestBuildNumber: 6);
      final t0 = DateTime.utc(2026, 11, 16, 12, 0);

      await AppUpdateService.instance.dismissSoftUpdate(config5, now: t0);

      expect(
        await AppUpdateService.instance.isSoftUpdateDismissed(
          config5,
          now: t0.add(const Duration(hours: 6)),
        ),
        isTrue,
      );
      expect(
        await AppUpdateService.instance.isSoftUpdateDismissed(
          config5,
          now: t0.add(const Duration(hours: 25)),
        ),
        isFalse,
      );
      expect(
        await AppUpdateService.instance.isSoftUpdateDismissed(
          config6,
          now: t0.add(const Duration(hours: 1)),
        ),
        isFalse,
      );
    });

    test('checkForUpdate integrates PackageInfo and remote config loader', () async {
      final result = await AppUpdateService.instance.checkForUpdate(
        platformOverride: TargetPlatform.iOS,
        packageInfoLoader: () async => PackageInfo(
          appName: 'Thai Quran',
          packageName: 'com.thaiquran.app',
          version: '1.0.1',
          buildNumber: '3',
        ),
        configLoader: (platform) async {
          expect(platform, equals('ios'));
          return _sampleConfig(latestVersion: '1.0.2', latestBuildNumber: 5);
        },
      );

      expect(result, isNotNull);
      expect(result!.status, equals(AppUpdateStatus.softUpdateAvailable));
      expect(result.currentVersion, equals('1.0.1'));
      expect(result.currentBuildNumber, equals(3));
    });
  });

  group('AppUpdateDialog Widget Tests', () {
    testWidgets('soft update shows Later and Update Now buttons and dismisses on Later', (tester) async {
      SharedPreferences.setMockInitialValues({'languageCode': 'th'});
      final settings = SettingsProvider();
      await tester.pumpAndSettle();

      var dismissedCalled = false;
      final config = _sampleConfig(latestVersion: '1.0.2', latestBuildNumber: 5);
      final result = AppUpdateService.evaluateConfig(
        currentVersion: '1.0.2',
        currentBuildNumber: 4,
        config: config,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        barrierDismissible: !result.isForced,
                        builder: (_) => AppUpdateDialog(
                          result: result,
                          onLaunchStore: (_) async => true,
                          onDismissLater: (_) async {
                            dismissedCalled = true;
                          },
                        ),
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('มีเวอร์ชันใหม่พร้อมใช้งาน'), findsOneWidget);
      expect(find.text('v1.0.2 (4)  →  v1.0.2 (5)'), findsOneWidget);
      expect(find.text('• เพิ่มฟีเจอร์ใหม่'), findsOneWidget);
      expect(find.text('อัปเดตตอนนี้'), findsOneWidget);
      expect(find.text('ไว้ภายหลัง'), findsOneWidget);

      await tester.tap(find.text('ไว้ภายหลัง'));
      await tester.pumpAndSettle();

      expect(dismissedCalled, isTrue);
      expect(find.byType(AppUpdateDialog), findsNothing);
    });

    testWidgets('force update hides Later button and keeps dialog open after tapping Update Now', (tester) async {
      SharedPreferences.setMockInitialValues({'languageCode': 'en'});
      final settings = SettingsProvider();
      await tester.pumpAndSettle();

      String? launchedUrl;
      final config = _sampleConfig(
        minVersion: '1.0.2',
        minBuildNumber: 5,
        latestVersion: '1.0.2',
        latestBuildNumber: 5,
      );
      final result = AppUpdateService.evaluateConfig(
        currentVersion: '1.0.1',
        currentBuildNumber: 3,
        config: config,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: MaterialApp(
            home: Scaffold(
              body: AppUpdateDialog(
                result: result,
                onLaunchStore: (url) async {
                  launchedUrl = url;
                  return true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Required Update'), findsOneWidget);
      expect(find.text('Update Available'), findsOneWidget);
      expect(find.text('Update Now'), findsOneWidget);
      expect(find.text('Later'), findsNothing);

      await tester.tap(find.text('Update Now'));
      await tester.pumpAndSettle();

      expect(launchedUrl, equals(config.updateUrl));
      expect(find.byType(AppUpdateDialog), findsOneWidget);
    });
  });
}
