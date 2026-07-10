import 'package:flutter/material.dart';
import '../data/translation_database.dart';

class TranslationManagerProvider extends ChangeNotifier {
  final TranslationDatabase _db = TranslationDatabase.instance;
  
  List<Map<String, dynamic>> _downloadedTranslations = [];
  final Map<int, Map<String, String>> _activeTranslationsCache = {};
  final Set<int> _loadingIds = {}; // Track currently loading IDs

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
    if (_loadingIds.contains(id)) return; // Prevent duplicate concurrent loads!
    
    _loadingIds.add(id);
    try {
      final verses = await _db.getAllVersesForTranslation(id);
      if (verses.isNotEmpty) {
        _activeTranslationsCache[id] = verses;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading translation $id into cache: $e');
    } finally {
      _loadingIds.remove(id);
    }
  }

  /// Remove from memory cache if no longer needed.
  void removeTranslationFromCache(int id) {
    _activeTranslationsCache.remove(id);
    _loadingIds.remove(id);
  }

  /// Get the translation text synchronously from memory.
  /// If it is not in the cache, it schedules a lazy load and returns null.
  String? getVerseTranslation(int id, String verseKey) {
    if (!_activeTranslationsCache.containsKey(id)) {
      loadTranslationIntoCache(id);
      return null;
    }
    return _activeTranslationsCache[id]?[verseKey];
  }

  Future<void> deleteTranslation(int id) async {
    await _db.removeTranslation(id);
    _activeTranslationsCache.remove(id);
    _loadingIds.remove(id);
    await refreshDownloadedList();
  }
}
