import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';

class OfflineQuranDatabaseService {
  static Database? _database;
  static const String _dbName = 'quran_offline.db';

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    // Check if database exists in app directory
    final exists = await databaseExists(path);

    if (!exists) {
      debugPrint("Creating a new copy from asset: $_dbName");
      try {
        await Directory(dirname(path)).create(recursive: true);
      } catch (_) {}

      // Copy from asset
      final data = await rootBundle.load('assets/$_dbName');
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(path).writeAsBytes(bytes, flush: true);
    }

    return await openDatabase(path, readOnly: false);
  }

  /// Get page line mapping records (15 lines per page)
  static Future<List<Map<String, dynamic>>> getPageLines(int pageNumber) async {
    final db = await database;
    return await db.query(
      'pages',
      where: 'page_number = ?',
      whereArgs: [pageNumber],
      orderBy: 'line_number ASC',
    );
  }

  /// Get all verses on a specific page
  static Future<List<Map<String, dynamic>>> getVersesForPage(int pageNumber) async {
    final db = await database;
    return await db.query(
      'verses',
      where: 'page_number = ?',
      whereArgs: [pageNumber],
      orderBy: 'surah_id ASC, verse_id ASC',
    );
  }

  /// Get all word-by-word records for a specific verse ('1:1', '18:74')
  static Future<List<Map<String, dynamic>>> getVerseWords(String verseKey) async {
    final db = await database;
    return await db.query(
      'words',
      where: 'verse_key = ?',
      whereArgs: [verseKey],
      orderBy: 'position ASC',
    );
  }

  /// Get a single verse by verseKey ('1:1', '18:74')
  static Future<Map<String, dynamic>?> getVerse(String verseKey) async {
    final db = await database;
    final results = await db.query(
      'verses',
      where: 'verse_key = ?',
      whereArgs: [verseKey],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Get translation for a specific verse and language ('th', 'en', 'ms')
  static Future<String?> getTranslation(String verseKey, {String lang = 'th'}) async {
    final db = await database;
    final column = switch (lang.toLowerCase()) {
      'en' => 'translation_en',
      'ms' => 'translation_ms',
      _ => 'translation_th',
    };
    final results = await db.query(
      'verses',
      columns: [column],
      where: 'verse_key = ?',
      whereArgs: [verseKey],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return results.first[column] as String?;
  }

  /// Get Tafsir for a specific verse
  static Future<String?> getTafsir(String verseKey) async {
    final db = await database;
    final results = await db.query(
      'verses',
      columns: ['tafsir_th'],
      where: 'verse_key = ?',
      whereArgs: [verseKey],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return results.first['tafsir_th'] as String?;
  }

  /// Get all topic categories
  static Future<List<Map<String, dynamic>>> getTopicCategories() async {
    final db = await database;
    return await db.query(
      'topic_categories',
      orderBy: 'sort_order ASC',
    );
  }

  /// Get topics for a specific category
  static Future<List<Map<String, dynamic>>> getTopicsForCategory(int categoryId) async {
    final db = await database;
    return await db.query(
      'topics',
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'id ASC',
    );
  }

  /// Get all verses for a topic along with their Arabic text and Thai translation
  static Future<List<Map<String, dynamic>>> getVersesForTopic(int topicId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT v.*, tv.sort_order 
      FROM topic_verses tv
      JOIN verses v ON tv.verse_key = v.verse_key
      WHERE tv.topic_id = ?
      ORDER BY tv.sort_order ASC
    ''', [topicId]);
  }

  /// Get Tajweed text for a specific verse
  static Future<String?> getTajweedText(String verseKey) async {
    final db = await database;
    final results = await db.query(
      'verses',
      columns: ['text_tajweed'],
      where: 'verse_key = ?',
      whereArgs: [verseKey],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return results.first['text_tajweed'] as String?;
  }

  /// Get 114 Surahs
  static Future<List<Map<String, dynamic>>> getSurahs() async {
    final db = await database;
    return await db.query('surahs', orderBy: 'id ASC');
  }

  /// Get metadata value by key
  static Future<String?> getMetadata(String key) async {
    final db = await database;
    final results = await db.query(
      'metadata',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return results.first['value'] as String?;
  }

  /// Dynamic Over-The-Air Update for Thai Translation
  /// Allows updating translation text without reinstalling or waiting for app store releases.
  static Future<bool> updateThaiTranslation(
    Map<String, String> newTranslations, {
    required String newVersion,
  }) async {
    final db = await database;
    try {
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final entry in newTranslations.entries) {
          batch.update(
            'verses',
            {'translation_th': entry.value},
            where: 'verse_key = ?',
            whereArgs: [entry.key],
          );
        }
        batch.insert(
          'metadata',
          {
            'key': 'translation_th_version',
            'value': newVersion,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        batch.insert(
          'metadata',
          {
            'key': 'translation_th_updated_at',
            'value': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await batch.commit(noResult: true);
      });
      debugPrint("Successfully updated Thai translation to $newVersion");
      return true;
    } catch (e) {
      debugPrint("Error updating Thai translation: $e");
      return false;
    }
  }
}
