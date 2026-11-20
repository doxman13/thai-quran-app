import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thai_quran_app/providers/settings_provider.dart';

Future<SettingsProvider> _createAndLoadProvider() async {
  final loaded = Completer<void>();
  final provider = SettingsProvider();
  void onNotify() {
    if (!loaded.isCompleted) {
      loaded.complete();
    }
  }

  provider.addListener(onNotify);
  await loaded.future.timeout(const Duration(seconds: 2));
  provider.removeListener(onNotify);
  return provider;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppThemeModePreference', () {
    test(
      'fresh install defaults to AppThemeModePreference.system and ThemeMode.system',
      () async {
        SharedPreferences.setMockInitialValues({});
        final provider = await _createAndLoadProvider();
        addTearDown(provider.dispose);

        expect(provider.themeModePreference, AppThemeModePreference.system);
        expect(provider.flutterThemeMode, ThemeMode.system);
      },
    );

    test(
      'legacy isDarkMode: true migrates to dark and keeps isDarkMode untouched',
      () async {
        SharedPreferences.setMockInitialValues({'isDarkMode': true});
        final provider = await _createAndLoadProvider();
        addTearDown(provider.dispose);

        expect(provider.themeModePreference, AppThemeModePreference.dark);
        expect(provider.flutterThemeMode, ThemeMode.dark);
        expect(provider.isDarkMode, isTrue);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('isDarkMode'), isTrue);
        expect(prefs.containsKey('themeModePreference'), isFalse);
      },
    );

    test(
      'legacy isDarkMode: false migrates to light and keeps isDarkMode untouched',
      () async {
        SharedPreferences.setMockInitialValues({'isDarkMode': false});
        final provider = await _createAndLoadProvider();
        addTearDown(provider.dispose);

        expect(provider.themeModePreference, AppThemeModePreference.light);
        expect(provider.flutterThemeMode, ThemeMode.light);
        expect(provider.isDarkMode, isFalse);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('isDarkMode'), isFalse);
        expect(prefs.containsKey('themeModePreference'), isFalse);
      },
    );

    test(
      'setThemeModePreference and toggleDarkMode persist across reload',
      () async {
        SharedPreferences.setMockInitialValues({});
        final first = await _createAndLoadProvider();

        await first.setThemeModePreference(AppThemeModePreference.dark);
        expect(first.themeModePreference, AppThemeModePreference.dark);
        expect(first.flutterThemeMode, ThemeMode.dark);
        expect(first.isDarkMode, isTrue);
        first.dispose();

        final reloadedDark = await _createAndLoadProvider();
        expect(reloadedDark.themeModePreference, AppThemeModePreference.dark);
        expect(reloadedDark.flutterThemeMode, ThemeMode.dark);
        expect(reloadedDark.isDarkMode, isTrue);

        reloadedDark.toggleDarkMode(false);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(reloadedDark.themeModePreference, AppThemeModePreference.light);
        expect(reloadedDark.flutterThemeMode, ThemeMode.light);
        expect(reloadedDark.isDarkMode, isFalse);
        reloadedDark.dispose();

        final reloadedLight = await _createAndLoadProvider();
        expect(reloadedLight.themeModePreference, AppThemeModePreference.light);
        expect(reloadedLight.flutterThemeMode, ThemeMode.light);
        expect(reloadedLight.isDarkMode, isFalse);

        await reloadedLight.setThemeModePreference(
          AppThemeModePreference.system,
        );
        expect(
          reloadedLight.themeModePreference,
          AppThemeModePreference.system,
        );
        expect(reloadedLight.flutterThemeMode, ThemeMode.system);
        reloadedLight.dispose();

        final reloadedSystem = await _createAndLoadProvider();
        addTearDown(reloadedSystem.dispose);
        expect(
          reloadedSystem.themeModePreference,
          AppThemeModePreference.system,
        );
        expect(reloadedSystem.flutterThemeMode, ThemeMode.system);
      },
    );
  });
}
