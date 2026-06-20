// lib/providers/settings_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  StreamSubscription<AuthState>? _authSubscription;

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
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final user = data.session?.user;
      if (user != null) {
        await loadAndApplySyncedSettings(user.id);
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _syncToSupabase() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId != null) {
      try {
        await client.from('user_settings').upsert({
          'user_id': userId,
          'theme_color': _themeColor,
          'is_dark_mode': _isDarkMode,
          'always_show_arabic': _alwaysShowArabic,
          'arabic_font_family': _arabicFontFamily,
          'arabic_font_size': _arabicFontSize,
          'show_thai_v3': _showThaiV3,
          'show_thai_v2': _showThaiV2,
          'show_english': _showEnglish,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('Error syncing settings to Supabase: $e');
      }
    }
  }

  Future<void> loadAndApplySyncedSettings(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('user_settings')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        _themeColor = response['theme_color']?.toString() ?? _themeColor;
        _isDarkMode = response['is_dark_mode'] == true;
        _alwaysShowArabic = response['always_show_arabic'] == true;
        _arabicFontFamily = response['arabic_font_family']?.toString() ?? _arabicFontFamily;
        _arabicFontSize = double.tryParse(response['arabic_font_size']?.toString() ?? '') ?? _arabicFontSize;
        _showThaiV3 = response['show_thai_v3'] == true;
        _showThaiV2 = response['show_thai_v2'] == true;
        _showEnglish = response['show_english'] == true;

        notifyListeners();

        // Save to local SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('themeColor', _themeColor);
        await prefs.setBool('isDarkMode', _isDarkMode);
        await prefs.setBool('alwaysShowArabic', _alwaysShowArabic);
        await prefs.setString('arabicFontFamily', _arabicFontFamily);
        await prefs.setDouble('arabicFontSize', _arabicFontSize);
        await prefs.setBool('showThaiV3', _showThaiV3);
        await prefs.setBool('showThaiV2', _showThaiV2);
        await prefs.setBool('showEnglish', _showEnglish);
      }
    } catch (e) {
      debugPrint('Error loading/applying user settings: $e');
    }
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
    await _syncToSupabase();
  }

  void toggleAlwaysShowArabic(bool value) async {
    _alwaysShowArabic = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alwaysShowArabic', value);
    await _syncToSupabase();
  }

  void setArabicFontFamily(String value) async {
    _arabicFontFamily = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('arabicFontFamily', value);
    await _syncToSupabase();
  }

  void setArabicFontSize(double value) async {
    _arabicFontSize = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('arabicFontSize', value);
    await _syncToSupabase();
  }

  void setThemeColor(String value) async {
    if (!['teal', 'emerald', 'blue', 'purple', 'sepia', 'grey'].contains(value)) return;
    _themeColor = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeColor', value);
    await _syncToSupabase();
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
    await _syncToSupabase();
  }

  void setShowThaiV2(bool value) async {
    _showThaiV2 = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showThaiV2', value);
    await _syncToSupabase();
  }

  void setShowEnglish(bool value) async {
    _showEnglish = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showEnglish', value);
    await _syncToSupabase();
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
