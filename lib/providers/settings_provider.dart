// lib/providers/settings_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  bool _alwaysShowArabic = false;

  bool get isDarkMode => _isDarkMode;
  bool get alwaysShowArabic => _alwaysShowArabic;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    _alwaysShowArabic = prefs.getBool('alwaysShowArabic') ?? false;
    notifyListeners();
  }

  void toggleDarkMode(bool value) async {
    _isDarkMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
  }

  void toggleAlwaysShowArabic(bool value) async {
    _alwaysShowArabic = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alwaysShowArabic', value);
  }
}
