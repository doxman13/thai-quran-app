// lib/providers/settings_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

class SettingsProvider extends ChangeNotifier {
  static const quranOnlyMode = 'quran_only';
  static const translationOnlyMode = 'translation_only';
  static const quranTranslationMode = 'quran_translation';
  static const _validDisplayModes = {
    quranOnlyMode,
    translationOnlyMode,
    quranTranslationMode,
  };

  bool _isDarkMode = false;
  String _readingDisplayMode = quranTranslationMode;
  double _arabicFontSize = 28.0;
  double _translationFontSize = 15.0;
  String _themeColor = 'blue';
  String _webHostUrl = 'http://10.0.2.2:3000'; // Default emulator localhost
  DateTime _settingsUpdatedAt = DateTime.fromMillisecondsSinceEpoch(0);

  // Dual-slot translation model
  // Valid IDs: 'thai_v3', 'thai_v2', 'english'
  String _primaryTranslationId = 'thai_v3';
  String? _secondaryTranslationId;

  StreamSubscription<AuthState>? _authSubscription;

  bool get isDarkMode => _isDarkMode;
  String get readingDisplayMode => _readingDisplayMode;
  bool get showArabicText =>
      _readingDisplayMode == quranOnlyMode ||
      _readingDisplayMode == quranTranslationMode;
  bool get showTranslationText =>
      _readingDisplayMode == translationOnlyMode ||
      _readingDisplayMode == quranTranslationMode;
  bool get alwaysShowArabic => showArabicText;
  bool get alwaysShowTranslation => showTranslationText;
  String get arabicFontFamily => 'UthmanicHafs';
  double get arabicFontSize => _arabicFontSize;
  double get translationFontSize => _translationFontSize;
  String get themeColor => _themeColor;
  String get webHostUrl => _webHostUrl;

  // New dual-slot getters
  String get primaryTranslationId => _primaryTranslationId;
  String? get secondaryTranslationId => _secondaryTranslationId;

  // Derived boolean getters (computed from slots — backwards compat for verse_card.dart etc.)
  bool get showThaiV3 =>
      _primaryTranslationId == 'thai_v3' ||
      _secondaryTranslationId == 'thai_v3';
  bool get showThaiV2 =>
      _primaryTranslationId == 'thai_v2' ||
      _secondaryTranslationId == 'thai_v2';
  bool get showEnglish =>
      _primaryTranslationId == 'english' ||
      _secondaryTranslationId == 'english';

  SettingsProvider() {
    _loadSettings();
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) async {
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
        final updatedAt =
            _settingsUpdatedAt.isAfter(DateTime.fromMillisecondsSinceEpoch(0))
            ? _settingsUpdatedAt
            : DateTime.now();
        // Derive legacy booleans from slots for backward compat with old Supabase rows
        await client.from('user_settings').upsert({
          'user_id': userId,
          'theme_color': 'blue',
          'is_dark_mode': _isDarkMode,
          'always_show_arabic': showArabicText,
          'arabic_font_family': 'UthmanicHafs',
          'arabic_font_size': _arabicFontSize,
          // Legacy boolean columns kept for web backwards compat
          'show_thai_v3': showThaiV3,
          'show_thai_v2': showThaiV2,
          'show_english': showEnglish,
          // New dual-slot columns
          'primary_translation_id': _primaryTranslationId,
          'secondary_translation_id': _secondaryTranslationId,
          'updated_at': updatedAt.toIso8601String(),
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
        final prefs = await SharedPreferences.getInstance();
        final hasLocalDisplayMode = prefs.containsKey('readingDisplayMode');
        final localUpdatedAt =
            DateTime.tryParse(prefs.getString('settingsUpdatedAt') ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final remoteUpdatedAt =
            DateTime.tryParse(response['updated_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);

        if (localUpdatedAt.isAfter(remoteUpdatedAt)) {
          _settingsUpdatedAt = localUpdatedAt;
          await _syncToSupabase();
          return;
        }

        _themeColor = _normalizeThemeColor(
          response['theme_color']?.toString() ?? _themeColor,
        );
        _isDarkMode = response['is_dark_mode'] == true;
        if (!hasLocalDisplayMode) {
          _readingDisplayMode = _modeFromLegacyFlags(
            showArabic: response['always_show_arabic'] == true,
            showTranslation: _readingDisplayMode != quranOnlyMode,
          );
        }
        _arabicFontSize =
            double.tryParse(response['arabic_font_size']?.toString() ?? '') ??
            _arabicFontSize;

        // Prefer new dual-slot columns; fall back to legacy booleans for old rows
        final rawPrimary = response['primary_translation_id']?.toString();
        if (rawPrimary != null && rawPrimary.isNotEmpty) {
          _primaryTranslationId = rawPrimary;
          _secondaryTranslationId = response['secondary_translation_id']
              ?.toString();
        } else {
          // Migrate from legacy boolean columns
          final v3 = response['show_thai_v3'] == true;
          final v2 = response['show_thai_v2'] == true;
          final en = response['show_english'] == true;
          final ids = _deriveSlotIds(v3: v3, v2: v2, en: en);
          _primaryTranslationId = ids.$1;
          _secondaryTranslationId = ids.$2;
        }

        notifyListeners();

        // Save to local SharedPreferences
        await prefs.setString('themeColor', _themeColor);
        await prefs.setBool('isDarkMode', _isDarkMode);
        await prefs.setString('readingDisplayMode', _readingDisplayMode);
        await prefs.setBool('alwaysShowArabic', showArabicText);
        await prefs.setBool('alwaysShowTranslation', showTranslationText);
        await prefs.setString('arabicFontFamily', 'UthmanicHafs');
        await prefs.setDouble('arabicFontSize', _arabicFontSize);
        await prefs.setString('primaryTranslationId', _primaryTranslationId);
        _settingsUpdatedAt = remoteUpdatedAt;
        await prefs.setString(
          'settingsUpdatedAt',
          remoteUpdatedAt.toIso8601String(),
        );
        if (_secondaryTranslationId != null) {
          await prefs.setString(
            'secondaryTranslationId',
            _secondaryTranslationId!,
          );
        } else {
          await prefs.remove('secondaryTranslationId');
        }
      }
    } catch (e) {
      debugPrint('Error loading/applying user settings: $e');
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    final storedDisplayMode = prefs.getString('readingDisplayMode');
    if (storedDisplayMode != null && storedDisplayMode.isNotEmpty) {
      _readingDisplayMode = _normalizeReadingDisplayMode(storedDisplayMode);
    } else {
      _readingDisplayMode = _modeFromLegacyFlags(
        showArabic: prefs.getBool('alwaysShowArabic') ?? false,
        showTranslation: prefs.getBool('alwaysShowTranslation') ?? true,
      );
      await prefs.setString('readingDisplayMode', _readingDisplayMode);
    }
    await prefs.setString('arabicFontFamily', 'UthmanicHafs');
    _arabicFontSize = prefs.getDouble('arabicFontSize') ?? 28.0;
    _translationFontSize = prefs.getDouble('translationFontSize') ?? 15.0;
    _themeColor = _normalizeThemeColor(prefs.getString('themeColor') ?? 'blue');
    _webHostUrl = prefs.getString('webHostUrl') ?? 'http://10.0.2.2:3000';
    _settingsUpdatedAt =
        DateTime.tryParse(prefs.getString('settingsUpdatedAt') ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);

    // Load dual-slot translation state — migrate from legacy booleans if absent
    final storedPrimary = prefs.getString('primaryTranslationId');
    if (storedPrimary != null && storedPrimary.isNotEmpty) {
      _primaryTranslationId = storedPrimary;
      _secondaryTranslationId = prefs.getString('secondaryTranslationId');
    } else {
      // First-run locale detection with migration from old boolean prefs
      final bool hasShowThaiV3 = prefs.containsKey('showThaiV3');
      bool v3, v2, en;
      if (!hasShowThaiV3) {
        final String nativeLang =
            WidgetsBinding.instance.platformDispatcher.locale.languageCode;
        v3 = nativeLang == 'th';
        v2 = false;
        en = nativeLang != 'th';
      } else {
        v3 = prefs.getBool('showThaiV3') ?? true;
        v2 = prefs.getBool('showThaiV2') ?? false;
        en = prefs.getBool('showEnglish') ?? false;
      }
      final ids = _deriveSlotIds(v3: v3, v2: v2, en: en);
      _primaryTranslationId = ids.$1;
      _secondaryTranslationId = ids.$2;
      // Persist migrated values
      await prefs.setString('primaryTranslationId', _primaryTranslationId);
      if (_secondaryTranslationId != null) {
        await prefs.setString(
          'secondaryTranslationId',
          _secondaryTranslationId!,
        );
      }
    }

    notifyListeners();
  }

  /// Derive dual-slot IDs from legacy boolean flags.
  /// Priority: thai_v3 > thai_v2 > english.
  (String, String?) _deriveSlotIds({
    required bool v3,
    required bool v2,
    required bool en,
  }) {
    final enabled = [if (v3) 'thai_v3', if (v2) 'thai_v2', if (en) 'english'];
    if (enabled.isEmpty) return ('thai_v3', null);
    return (enabled[0], enabled.length > 1 ? enabled[1] : null);
  }

  String _normalizeReadingDisplayMode(String value) {
    return _validDisplayModes.contains(value) ? value : quranTranslationMode;
  }

  String _modeFromLegacyFlags({
    required bool showArabic,
    required bool showTranslation,
  }) {
    if (showArabic && !showTranslation) return quranOnlyMode;
    if (!showArabic && showTranslation) return translationOnlyMode;
    if (showArabic && showTranslation) return quranTranslationMode;
    return quranTranslationMode;
  }

  Future<void> _markSettingsChanged(SharedPreferences prefs) async {
    _settingsUpdatedAt = DateTime.now();
    await prefs.setString(
      'settingsUpdatedAt',
      _settingsUpdatedAt.toIso8601String(),
    );
  }

  void toggleDarkMode(bool value) async {
    _isDarkMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
    await _markSettingsChanged(prefs);
    await _syncToSupabase();
  }

  void toggleAlwaysShowArabic(bool value) async {
    setReadingDisplayMode(
      value
          ? (showTranslationText ? quranTranslationMode : quranOnlyMode)
          : translationOnlyMode,
    );
  }

  void toggleAlwaysShowTranslation(bool value) async {
    setReadingDisplayMode(
      value
          ? (showArabicText ? quranTranslationMode : translationOnlyMode)
          : quranOnlyMode,
    );
  }

  void setArabicFontFamily(String value) async {
    if (value != 'UthmanicHafs') return;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('arabicFontFamily', 'UthmanicHafs');
    await _markSettingsChanged(prefs);
    await _syncToSupabase();
  }

  void setReadingDisplayMode(String value) async {
    final normalized = _normalizeReadingDisplayMode(value);
    if (_readingDisplayMode == normalized) return;
    _readingDisplayMode = normalized;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('readingDisplayMode', normalized);
    await prefs.setBool('alwaysShowArabic', showArabicText);
    await prefs.setBool('alwaysShowTranslation', showTranslationText);
    await _markSettingsChanged(prefs);
    await _syncToSupabase();
  }

  void setArabicFontSize(double value) async {
    _arabicFontSize = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('arabicFontSize', value);
    await _markSettingsChanged(prefs);
    await _syncToSupabase();
  }

  void setTranslationFontSize(double value) async {
    _translationFontSize = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('translationFontSize', value);
    await _markSettingsChanged(prefs);
  }

  void setThemeColor(String value) async {
    _themeColor = 'blue';
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeColor', 'blue');
    await _markSettingsChanged(prefs);
    await _syncToSupabase();
  }

  void setWebHostUrl(String value) async {
    _webHostUrl = value.trim();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('webHostUrl', _webHostUrl);
    await _markSettingsChanged(prefs);
  }

  /// Core dual-slot mutation with Auto-Eviction collision logic.
  ///
  /// [slot] must be `'primary'` or `'secondary'`.
  /// [id] must be one of `'thai_v3'`, `'thai_v2'`, `'english'`, or `null` (secondary only).
  ///
  /// Rules:
  /// - `primary` cannot be null.
  /// - If new primary == current secondary → secondary is evicted to null.
  /// - If new secondary == current primary → silently rejected (no-op).
  void updateTranslationSlot(String slot, String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (slot == 'primary') {
      if (id == null) return; // primary must always have a value
      final newSecondary = _secondaryTranslationId == id
          ? null
          : _secondaryTranslationId;
      _primaryTranslationId = id;
      _secondaryTranslationId = newSecondary;
    } else {
      if (id == _primaryTranslationId) return; // collision — reject
      _secondaryTranslationId = id;
    }
    notifyListeners();
    await prefs.setString('primaryTranslationId', _primaryTranslationId);
    if (_secondaryTranslationId != null) {
      await prefs.setString('secondaryTranslationId', _secondaryTranslationId!);
    } else {
      await prefs.remove('secondaryTranslationId');
    }
    await _markSettingsChanged(prefs);
    await _syncToSupabase();
  }

  // Legacy adaptor setters — delegate to updateTranslationSlot for backwards compat
  void setShowThaiV3(bool value) {
    if (value) {
      updateTranslationSlot('primary', 'thai_v3');
    } else if (_primaryTranslationId == 'thai_v3') {
      final fallback = _secondaryTranslationId ?? 'english';
      updateTranslationSlot('primary', fallback);
    } else {
      updateTranslationSlot('secondary', null);
    }
  }

  void setShowThaiV2(bool value) {
    if (value) {
      if (_primaryTranslationId != 'thai_v2') {
        updateTranslationSlot('secondary', 'thai_v2');
      }
    } else {
      if (_primaryTranslationId == 'thai_v2') {
        final fallback = _secondaryTranslationId ?? 'thai_v3';
        updateTranslationSlot('primary', fallback);
      } else {
        updateTranslationSlot('secondary', null);
      }
    }
  }

  void setShowEnglish(bool value) {
    if (value) {
      if (_primaryTranslationId != 'english') {
        updateTranslationSlot('secondary', 'english');
      }
    } else {
      if (_primaryTranslationId == 'english') {
        final fallback = _secondaryTranslationId ?? 'thai_v3';
        updateTranslationSlot('primary', fallback);
      } else {
        updateTranslationSlot('secondary', null);
      }
    }
  }

  // Helper method to get theme colors
  MaterialColor getThemeSwatch() {
    return Colors.blue;
  }

  AppThemeColors getAppColors() {
    return AppTheme.colors(isDark: _isDarkMode, palette: 'blue');
  }

  Color getPrimaryColor() {
    return getAppColors().primary;
  }

  Color getHighlightColor() {
    return getAppColors().accent;
  }

  String _normalizeThemeColor(String value) {
    return 'blue';
  }
}
