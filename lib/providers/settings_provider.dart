// lib/providers/settings_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  bool _alwaysShowArabic = false;
  String _arabicFontFamily = 'UthmanicHafs';
  double _arabicFontSize = 28.0;
  String _themeColor = 'teal'; // teal, emerald, blue, purple, sepia, grey
  String _webHostUrl = 'http://10.0.2.2:3000'; // Default emulator localhost

  // Translation display toggles
  bool _showThaiV3 = true;
  bool _showThaiV2 = false;
  bool _showEnglish = false;

  bool get isDarkMode => _isDarkMode;
  bool get alwaysShowArabic => _alwaysShowArabic;
  String get arabicFontFamily => _arabicFontFamily;
  double get arabicFontSize => _arabicFontSize;
  String get themeColor => _themeColor;
  String get webHostUrl => _webHostUrl;

  bool get showThaiV3 => _showThaiV3;
  bool get showThaiV2 => _showThaiV2;
  bool get showEnglish => _showEnglish;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    _alwaysShowArabic = prefs.getBool('alwaysShowArabic') ?? false;
    _arabicFontFamily = prefs.getString('arabicFontFamily') ?? 'UthmanicHafs';
    _arabicFontSize = prefs.getDouble('arabicFontSize') ?? 28.0;
    _themeColor = prefs.getString('themeColor') ?? 'teal';
    _webHostUrl = prefs.getString('webHostUrl') ?? 'http://10.0.2.2:3000';

    _showThaiV3 = prefs.getBool('showThaiV3') ?? true;
    _showThaiV2 = prefs.getBool('showThaiV2') ?? false;
    _showEnglish = prefs.getBool('showEnglish') ?? false;
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

  void setThemeColor(String value) async {
    if (!['teal', 'emerald', 'blue', 'purple', 'sepia', 'grey'].contains(value)) return;
    _themeColor = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeColor', value);
  }

  void setWebHostUrl(String value) async {
    _webHostUrl = value.trim();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('webHostUrl', _webHostUrl);
  }

  void setShowThaiV3(bool value) async {
    _showThaiV3 = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showThaiV3', value);
  }

  void setShowThaiV2(bool value) async {
    _showThaiV2 = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showThaiV2', value);
  }

  void setShowEnglish(bool value) async {
    _showEnglish = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showEnglish', value);
  }

  // Helper method to get theme colors
  MaterialColor getThemeSwatch() {
    switch (_themeColor) {
      case 'emerald':
        return Colors.green;
      case 'blue':
        return Colors.blue;
      case 'purple':
        return Colors.purple;
      case 'sepia':
        return Colors.amber;
      case 'grey':
        return Colors.blueGrey;
      case 'teal':
      default:
        return Colors.teal;
    }
  }

  Color getPrimaryColor() {
    switch (_themeColor) {
      case 'emerald':
        return const Color(0xFF047857); // emerald.shade700
      case 'blue':
        return Colors.blue.shade700;
      case 'purple':
        return Colors.purple.shade700;
      case 'sepia':
        return Colors.amber.shade800;
      case 'grey':
        return Colors.blueGrey.shade700;
      case 'teal':
      default:
        return Colors.teal.shade700;
    }
  }

  Color getHighlightColor() {
    switch (_themeColor) {
      case 'emerald':
        return const Color(0xFF34D399); // emerald.shade400
      case 'blue':
        return Colors.blue.shade400;
      case 'purple':
        return Colors.purple.shade400;
      case 'sepia':
        return Colors.amber.shade600;
      case 'grey':
        return Colors.blueGrey.shade400;
      case 'teal':
      default:
        return Colors.teal.shade400;
    }
  }
}
