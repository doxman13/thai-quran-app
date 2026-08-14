import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../data/translation_database.dart';
import '../services/offline_quran_database_service.dart';

class TranslationManagerProvider extends ChangeNotifier {
  final TranslationDatabase _db = TranslationDatabase.instance;
  
  List<Map<String, dynamic>> _downloadedTranslations = [];
  final Map<dynamic, Map<String, String>> _activeTranslationsCache = {};
  final Set<dynamic> _loadingIds = {}; // Track currently loading IDs
  final Map<int, double> _downloadProgress = {};

  List<Map<String, dynamic>> get downloadedTranslations => _downloadedTranslations;
  Set<dynamic> get loadingIds => _loadingIds;
  Map<int, double> get downloadProgress => _downloadProgress;

  TranslationManagerProvider() {
    refreshDownloadedList();
    _initBackgroundServiceListener();
  }

  void _initBackgroundServiceListener() {
    final service = FlutterBackgroundService();

    service.on('update_progress').listen((event) {
      final id = event?['id'] as int?;
      final progress = event?['progress'] as double?;
      if (id != null && progress != null) {
        _downloadProgress[id] = progress;
        _loadingIds.add(id);
        notifyListeners();
      }
    });

    service.on('download_success').listen((event) async {
      final id = event?['id'] as int?;
      if (id != null) {
        _downloadProgress.remove(id);
        _loadingIds.remove(id);
        await refreshDownloadedList();
      }
    });

    service.on('download_failed').listen((event) {
      final id = event?['id'] as int?;
      if (id != null) {
        _downloadProgress.remove(id);
        _loadingIds.remove(id);
        notifyListeners();
      }
    });
  }

  Future<void> startBackgroundDownload({
    required int id,
    required String name,
    required String author,
    required String language,
  }) async {
    if (_loadingIds.contains(id)) return;

    _loadingIds.add(id);
    _downloadProgress[id] = 0.0;
    notifyListeners();

    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    if (!isRunning) {
      await service.startService();
      // Give it some time to spawn and connect
      await Future.delayed(const Duration(milliseconds: 650));
    }

    service.invoke('start_download', {
      'id': id,
      'name': name,
      'author': author,
      'language': language,
    });
  }

  Future<void> refreshDownloadedList() async {
    _downloadedTranslations = await _db.getDownloadedTranslations();
    notifyListeners();
  }

  /// Load a translation into memory cache if not already loaded.
  Future<void> loadTranslationIntoCache(dynamic id) async {
    if (id == null) return;
    if (_activeTranslationsCache.containsKey(id)) return;
    if (_loadingIds.contains(id)) return; // Prevent duplicate concurrent loads!
    
    _loadingIds.add(id);
    try {
      Map<String, String> verses = {};
      final idStr = id.toString().trim();

      if (idStr == 'en_usmani' || idStr == 'english') {
        verses = await OfflineQuranDatabaseService.getAllTranslations(lang: 'en');
      } else if (idStr == 'ms_basmeih' || idStr == 'malay') {
        verses = await OfflineQuranDatabaseService.getAllTranslations(lang: 'ms');
      } else if (idStr == 'thai_v3') {
        verses = await OfflineQuranDatabaseService.getAllTranslations(lang: 'th');
      } else {
        final idInt = int.tryParse(idStr);
        if (idInt != null) {
          verses = await _db.getAllVersesForTranslation(idInt);
        }
      }

      if (verses.isNotEmpty) {
        _activeTranslationsCache[id] = verses;
        if (id is int) {
          _activeTranslationsCache[id.toString()] = verses;
        } else if (id is String && int.tryParse(id) != null) {
          _activeTranslationsCache[int.parse(id)] = verses;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading translation $id into cache: $e');
    } finally {
      _loadingIds.remove(id);
    }
  }

  /// Remove from memory cache if no longer needed.
  void removeTranslationFromCache(dynamic id) {
    if (id == null) return;
    _activeTranslationsCache.remove(id);
    _activeTranslationsCache.remove(id.toString());
    if (id is String && int.tryParse(id) != null) {
      _activeTranslationsCache.remove(int.parse(id));
    }
    _loadingIds.remove(id);
  }

  /// Get the translation text synchronously from memory.
  /// If it is not in the cache, it schedules a lazy load and returns null.
  String? getVerseTranslation(dynamic id, String verseKey) {
    if (id == null) return null;
    if (!_activeTranslationsCache.containsKey(id)) {
      loadTranslationIntoCache(id);
      return null;
    }
    return _activeTranslationsCache[id]?[verseKey];
  }

  Future<void> deleteTranslation(int id) async {
    await _db.removeTranslation(id);
    removeTranslationFromCache(id);
    await refreshDownloadedList();
  }
}
