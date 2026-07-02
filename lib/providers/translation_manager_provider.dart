import 'package:flutter/material.dart';
import '../data/translation_database.dart';

class TranslationManagerProvider extends ChangeNotifier {
  final TranslationDatabase _db = TranslationDatabase.instance;
  
  List<Map<String, dynamic>> _downloadedTranslations = [];
  Map<int, Map<String, String>> _activeTranslationsCache = {};

  List<Map<String, dynamic>> get downloadedTranslations => _downloadedTranslations;

  TranslationManagerProvider() {
    refreshDownloadedList();
  }

  Future<void> refreshDownloadedList() async {
    _downloadedTranslations = await _db.getDownloadedTranslations();
    notifyListeners();
  }

  /// Load a translation into memory cache if not already loaded.
  Future<void> loadTranslationIntoCache(int id) async {
    if (_activeTranslationsCache.containsKey(id)) return;
    final verses = await _db.getAllVersesForTranslation(id);
    if (verses.isNotEmpty) {
      _activeTranslationsCache[id] = verses;
      notifyListeners();
    }
  }

  /// Remove from memory cache if no longer needed.
  void removeTranslationFromCache(int id) {
    _activeTranslationsCache.remove(id);
  }

  /// Get the translation text synchronously from memory.
  String? getVerseTranslation(int id, String verseKey) {
    return _activeTranslationsCache[id]?[verseKey];
  }

  Future<void> deleteTranslation(int id) async {
    await _db.removeTranslation(id);
    _activeTranslationsCache.remove(id);
    await refreshDownloadedList();
  }
}
