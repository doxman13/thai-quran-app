// lib/providers/settings_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  bool _alwaysShowArabic = false;
  String _arabicFontFamily = 'UthmanicHafs';
  double _arabicFontSize = 28.0;

  bool get isDarkMode => _isDarkMode;
  bool get alwaysShowArabic => _alwaysShowArabic;
  String get arabicFontFamily => _arabicFontFamily;
  double get arabicFontSize => _arabicFontSize;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    _alwaysShowArabic = prefs.getBool('alwaysShowArabic') ?? false;
    _arabicFontFamily = prefs.getString('arabicFontFamily') ?? 'UthmanicHafs';
    _arabicFontSize = prefs.getDouble('arabicFontSize') ?? 28.0;
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

  void setArabicFontFamily(String value) async {
    _arabicFontFamily = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('arabicFontFamily', value);
  }

  void setArabicFontSize(double value) async {
    _arabicFontSize = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('arabicFontSize', value);
  }
}

