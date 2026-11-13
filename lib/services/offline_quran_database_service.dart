import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import '../data/offline_surah_names.dart';

class OfflineQuranDatabaseService {
  static Database? _database;
  static const String _dbName = 'quran_offline.db';
  static const int _targetDbVersion = 41;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    bool shouldCopy = false;
    final exists = await databaseExists(path);

    if (!exists) {
      shouldCopy = true;
    } else {
      // Check existing database version
      try {
        final existingDb = await openDatabase(path, readOnly: true);
        final versionRes = await existingDb.rawQuery('PRAGMA user_version;');
        final version = Sqflite.firstIntValue(versionRes) ?? 0;
        await existingDb.close();

        if (version < _targetDbVersion) {
          debugPrint("Updating quran_offline.db to version $_targetDbVersion (current: $version)");
          shouldCopy = true;
        }
      } catch (e) {
        debugPrint("Error checking db version, forcing copy: $e");
        shouldCopy = true;
      }
    }

    if (shouldCopy) {
      debugPrint("Creating a fresh copy from asset: $_dbName");
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
    try {
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
    } catch (e) {
      debugPrint("Error getting translation for $verseKey: $e");
      return null;
    }
  }

  /// Get all translations for a language ('th', 'en', 'ms')
  static Future<Map<String, String>> getAllTranslations({String lang = 'th'}) async {
    try {
      final db = await database;
      final column = switch (lang.toLowerCase()) {
        'en' => 'translation_en',
        'ms' => 'translation_ms',
        _ => 'translation_th',
      };
      final results = await db.query(
        'verses',
        columns: ['verse_key', column],
      );
      return {
        for (final row in results)
          if (row['verse_key'] != null && row[column] != null)
            row['verse_key'] as String: row[column] as String,
      };
    } catch (e) {
      debugPrint("Error fetching all translations for lang $lang: $e");
      return {};
    }
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

  /// Search topics by Thai title, English title, or category name
  static Future<List<Map<String, dynamic>>> searchTopics(String query) async {
    final db = await database;
    final q = '%${query.trim().toLowerCase()}%';
    return await db.rawQuery('''
      SELECT t.*, c.title_th as category_title_th, c.icon_name as category_icon
      FROM topics t
      JOIN topic_categories c ON t.category_id = c.id
      WHERE LOWER(t.title_th) LIKE ? 
         OR LOWER(t.title_en) LIKE ? 
         OR LOWER(c.title_th) LIKE ?
      ORDER BY t.verses_count DESC
    ''', [q, q, q]);
  }

  /// Get all verses containing words with a specific root ('ر ح م', 'س م و')
  static Future<List<Map<String, dynamic>>> getVersesByRoot(String rootArabic) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT DISTINCT v.* 
      FROM words w
      JOIN verses v ON w.verse_key = v.verse_key
      WHERE w.root_arabic = ?
      ORDER BY v.surah_id ASC, v.verse_id ASC
    ''', [rootArabic]);
  }

  /// Get all distinct Arabic roots with word and verse counts
  static Future<List<Map<String, dynamic>>> getAllRoots() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT root_arabic, COUNT(*) as word_count, COUNT(DISTINCT verse_key) as verse_count
      FROM words
      WHERE root_arabic IS NOT NULL AND TRIM(root_arabic) != ''
      GROUP BY root_arabic
      ORDER BY root_arabic ASC
    ''');
  }

  static Set<String>? _mutashabihatVerseKeySet;

  /// Preload / get all verse keys that have Mutashabihat
  static Future<Set<String>> getMutashabihatVerseKeys() async {
    if (_mutashabihatVerseKeySet != null) return _mutashabihatVerseKeySet!;
    try {
      final db = await database;
      final results = await db.rawQuery('SELECT DISTINCT verse_key FROM mutashabihat');
      _mutashabihatVerseKeySet = {
        for (final row in results)
          if (row['verse_key'] != null) row['verse_key'] as String,
      };
      return _mutashabihatVerseKeySet!;
    } catch (e) {
      debugPrint("Error loading mutashabihat keys: $e");
      return {};
    }
  }

  /// Synchronous check if a verse key has Mutashabihat
  static bool hasMutashabihatSync(String verseKey) {
    return _mutashabihatVerseKeySet?.contains(verseKey) ?? false;
  }

  /// Get all similar verses (Mutashabihat) for a specific verseKey ('2:48', etc.)
  static Future<List<Map<String, dynamic>>> getMutashabihat(String verseKey) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT v.*, m.context_type 
      FROM mutashabihat m
      JOIN verses v ON m.matched_verse_key = v.verse_key
      WHERE m.verse_key = ?
      GROUP BY m.matched_verse_key
      ORDER BY v.surah_id ASC, v.verse_id ASC
    ''', [verseKey]);
  }

  /// Check if a verse has any Mutashabihat
  static Future<int> getMutashabihatCount(String verseKey) async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT COUNT(DISTINCT matched_verse_key) as count FROM mutashabihat WHERE verse_key = ?
    ''', [verseKey]);
    return (results.first['count'] as int?) ?? 0;
  }

  /// Get QUL Ayah Themes for a specific Surah
  static Future<List<Map<String, dynamic>>> getQulThemesForSurah(int surah) async {
    final db = await database;
    return await db.query(
      'qul_ayah_themes',
      where: 'surah = ?',
      whereArgs: [surah],
      orderBy: 'ayah_from ASC',
    );
  }

  /// Get QUL Ayah Theme for a specific verse
  static Future<Map<String, dynamic>?> getQulThemeForVerse(int surah, int ayah) async {
    final db = await database;
    final results = await db.query(
      'qul_ayah_themes',
      where: 'surah = ? AND ayah_from <= ? AND ayah_to >= ?',
      whereArgs: [surah, ayah, ayah],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
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
            'value': DateTime.now().toUtc().toIso8601String(),
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

  static const Map<String, List<String>> _crossLanguageSearchAliases = {
    // Spirits & Unseen Beings
    'ญิน': ['jin', 'jinn', 'djinn', 'ยิน', 'พวกญิน'],
    'jin': ['ญิน', 'ยิน', 'jinn', 'พวกญิน'],
    'jinn': ['ญิน', 'ยิน', 'jin', 'พวกญิน'],
    'มลาอิกะฮฺ': ['angel', 'angels', 'มะลาอิกะฮฺ', 'มะลาอิกะห์', 'ทูตสวรรค์'],
    'มะลาอิกะฮฺ': ['angel', 'angels', 'มลาอิกะฮฺ', 'ทูตสวรรค์'],
    'angel': ['มลาอิกะฮฺ', 'มะลาอิกะฮฺ', 'ทูตสวรรค์'],
    'angels': ['มลาอิกะฮฺ', 'มะลาอิกะฮฺ', 'ทูตสวรรค์'],
    'ชัยฏอน': ['satan', 'devil', 'มารร้าย', 'ชัยตอน'],
    'ชัยตอน': ['satan', 'devil', 'ชัยฏอน', 'มารร้าย'],
    'satan': ['ชัยฏอน', 'ชัยตอน', 'มารร้าย', 'devil'],
    'devil': ['ชัยฏอน', 'ชัยตอน', 'มารร้าย'],

    // Faith & Afterlife
    'สวรรค์': ['paradise', 'heaven', 'jannah', 'สวนสวรรค์', 'ญันนะฮฺ'],
    'สวนสวรรค์': ['paradise', 'heaven', 'jannah', 'สวรรค์'],
    'paradise': ['สวรรค์', 'สวนสวรรค์', 'ญันนะฮฺ', 'heaven'],
    'heaven': ['สวรรค์', 'ฟากฟ้า', 'paradise'],
    'นรก': ['hell', 'fire', 'jahannam', 'ไฟนรก', 'ญะฮันนัม'],
    'ไฟนรก': ['hell', 'fire', 'jahannam', 'นรก'],
    'hell': ['นรก', 'ไฟนรก', 'jahannam'],
    'กิยามะฮฺ': ['resurrection', 'judgment', 'วันสิ้นโลก', 'วันฟื้นคืนชีพ', 'วันพิพากษา'],
    'วันสิ้นโลก': ['resurrection', 'judgment', 'กิยามะฮฺ', 'วันฟื้นคืนชีพ'],
    'วันฟื้นคืนชีพ': ['resurrection', 'judgment', 'กิยามะฮฺ'],
    'resurrection': ['กิยามะฮฺ', 'ฟื้นคืนชีพ', 'วันสิ้นโลก'],
    'ศรัทธา': ['faith', 'believe', 'believer', 'believers', 'ผู้ศรัทธา'],
    'ความศรัทธา': ['faith', 'believe', 'ผู้ศรัทธา'],
    'ผู้ศรัทธา': ['believer', 'believers', 'มุอ์มิน', 'ศรัทธา'],
    'faith': ['ศรัทธา', 'ความศรัทธา', 'ผู้ศรัทธา'],
    'believer': ['ผู้ศรัทธา', 'มุอ์มิน', 'ศรัทธา'],
    'believers': ['ผู้ศรัทธา', 'บรรดาผู้ศรัทธา'],
    'กาฟิร': ['disbeliever', 'disbelievers', 'ผู้ปฏิเสธศรัทธา', 'ผู้ปฏิเสธ'],
    'ผู้ปฏิเสธศรัทธา': ['disbeliever', 'disbelievers', 'กาฟิร'],
    'disbeliever': ['กาฟิร', 'ผู้ปฏิเสธศรัทธา', 'ผู้ปฏิเสธ'],
    'disbelievers': ['กาฟิร', 'ผู้ปฏิเสธศรัทธา', 'บรรดาผู้ปฏิเสธศรัทธา'],
    'มุนาฟิก': ['hypocrite', 'hypocrites', 'คนกลับกลอก'],
    'คนกลับกลอก': ['hypocrite', 'hypocrites', 'มุนาฟิก'],
    'hypocrite': ['มุนาฟิก', 'คนกลับกลอก'],

    // Worship & Pillars
    'ละหมาด': ['prayer', 'prayers', 'salah', 'salat', 'นมาซ', 'ดำรงละหมาด'],
    'การละหมาด': ['prayer', 'prayers', 'salah', 'ละหมาด'],
    'prayer': ['ละหมาด', 'นมาซ', 'ดุอาอ์', 'การละหมาด'],
    'prayers': ['การละหมาด', 'ละหมาด'],
    'salah': ['ละหมาด', 'การละหมาด'],
    'salat': ['ละหมาด', 'การละหมาด'],
    'ซะกาต': ['zakat', 'charity', 'ทาน', 'บริจาคทาน'],
    'zakat': ['ซะกาต', 'บริจาคทาน'],
    'charity': ['ซะกาต', 'บริจาค', 'การบริจาคทาน', 'ทาน'],
    'ศีลอด': ['fasting', 'fast', 'sawm', 'การถือศีลอด'],
    'การถือศีลอด': ['fasting', 'ศีลอด'],
    'fasting': ['ศีลอด', 'การถือศีลอด'],
    'ฮัจญ์': ['hajj', 'pilgrimage', 'ฮัจย์', 'การทำฮัจญ์'],
    'ฮัจย์': ['hajj', 'pilgrimage', 'ฮัจญ์'],
    'hajj': ['ฮัจญ์', 'ฮัจย์'],
    'pilgrimage': ['ฮัจญ์', 'อุมเราะฮฺ'],
    'เตาบัต': ['repentance', 'repent', 'กลับตัว', 'การกลับเนื้อกลับตัว'],
    'การกลับตัว': ['repentance', 'repent', 'เตาบัต'],
    'repentance': ['เตาบัต', 'การกลับเนื้อกลับตัว', 'ขออภัยโทษ'],
    'repent': ['กลับตัว', 'สำนึกผิด', 'เตาบัต'],
    'อภัยโทษ': ['forgiveness', 'forgive', 'การให้อภัย', 'การยกโทษ'],
    'การให้อภัย': ['forgiveness', 'อภัยโทษ'],
    'forgiveness': ['อภัยโทษ', 'การให้อภัย', 'การยกโทษ'],

    // Virtues & Attributes
    'เมตตา': ['mercy', 'merciful', 'ความเมตตา', 'ผู้ทรงเมตตา'],
    'ความเมตตา': ['mercy', 'merciful', 'เมตตา'],
    'mercy': ['เมตตา', 'ความเมตตา', 'ความกรุณา'],
    'merciful': ['ผู้ทรงเมตตา', 'เมตตา'],
    'อดทน': ['patience', 'patient', 'ความอดทน'],
    'ความอดทน': ['patience', 'patient', 'อดทน'],
    'patience': ['อดทน', 'ความอดทน'],
    'patient': ['ผู้อดทน', 'อดทน'],
    'ยุติธรรม': ['justice', 'just', 'ความยุติธรรม'],
    'ความยุติธรรม': ['justice', 'just', 'ยุติธรรม'],
    'justice': ['ยุติธรรม', 'ความยุติธรรม', 'เที่ยงธรรม'],
    'ความรู้': ['knowledge', 'ปัญญา'],
    'knowledge': ['ความรู้', 'วิชาการ'],

    // Prophets & Figures
    'นบี': ['prophet', 'prophets', 'นะบี', 'ศาสดา'],
    'นะบี': ['prophet', 'prophets', 'นบี'],
    'prophet': ['นบี', 'นะบี', 'ศาสดา'],
    'prophets': ['บรรดานบี', 'นบี', 'ศาสดา'],
    'รอซูล': ['messenger', 'messengers', 'เราะซูล'],
    'เราะซูล': ['messenger', 'messengers', 'รอซูล'],
    'messenger': ['รอซูล', 'เราะซูล', 'ทูต'],
    'messengers': ['บรรดารอซูล', 'รอซูล'],
    'มูซา': ['moses', 'mūsā', 'musa', 'นบีมูซา'],
    'นบีมูซา': ['moses', 'mūsā', 'musa'],
    'moses': ['มูซา', 'mūsā', 'musa', 'นบีมูซา'],
    'musa': ['มูซา', 'mūsā', 'moses'],
    'อิบรอฮีม': ['abraham', 'ibrāhīm', 'ibrahim', 'นบีอิบรอฮีม'],
    'abraham': ['อิบรอฮีม', 'ibrāhīm', 'ibrahim'],
    'ibrahim': ['อิบรอฮีม', 'ibrāhīm', 'abraham'],
    'อีซา': ['jesus', '‘īsā', 'isa', 'นบีอีซา', 'เยซู'],
    'jesus': ['อีซา', '‘īsā', 'isa', 'เยซู'],
    'isa': ['อีซา', '‘īsā', 'jesus'],
    'มุฮัมมัด': ['muhammad', 'muḥammad', 'นบีมุฮัมมัด'],
    'muhammad': ['มุฮัมมัด', 'muḥammad'],
    'นูฮฺ': ['noah', 'nūḥ', 'nuh', 'นบีนูฮฺ', 'โนอาห์'],
    'noah': ['นูฮฺ', 'nūḥ', 'nuh', 'โนอาห์'],
    'อาดัม': ['adam', 'ādam', 'นบีอาดัม'],
    'adam': ['อาดัม', 'ādam'],
    'ยูซุฟ': ['joseph', 'yūsuf', 'yusuf', 'นบียูซุฟ'],
    'joseph': ['ยูซุฟ', 'yūsuf', 'yusuf'],
    'ยูนุส': ['jonah', 'yūnus', 'yunus', 'นบียูนุส'],
    'jonah': ['ยูนุส', 'yūnus', 'yunus'],
    'ดาวูด': ['david', 'dāwūd', 'dawud', 'นบีดาวูด'],
    'david': ['ดาวูด', 'dāwūd', 'dawud'],
    'สุลัยมาน': ['solomon', 'sulaymān', 'sulaiman', 'นบีสุลัยมาน'],
    'solomon': ['สุลัยมาน', 'sulaymān', 'sulaiman'],
    'มัรยัม': ['mary', 'maryam'],
    'mary': ['มัรยัม'],
    'maryam': ['มัรยัม'],
    'ฟิรเอาน์': ['pharaoh', 'firaun', 'fir\'aun', 'ฟาโรห์'],
    'ฟาโรห์': ['pharaoh', 'ฟิรเอาน์'],
    'pharaoh': ['ฟิรเอาน์', 'ฟาโรห์'],
    'กอรูน': ['qorun', 'korah'],
    'ลูฏ': ['lot', 'lūṭ', 'lut', 'นบีลูฏ'],
    'lot': ['ลูฏ', 'lūṭ', 'lut'],
    'อิสมาอีล': ['ishmael', 'ismā‘īl', 'ismail'],
    'ishmael': ['อิสมาอีล', 'ismā‘īl'],
    'อิสฮาก': ['isaac', 'is-ḥāq', 'ishaq'],
    'isaac': ['อิสฮาก', 'is-ḥāq'],
    'ยะอฺกูบ': ['jacob', 'ya‘qūb', 'yaqub'],
    'jacob': ['ยะอฺกูบ', 'ya‘qūb'],
    'ฮารูน': ['aaron', 'hārūn', 'harun', 'นบีฮารูน'],
    'aaron': ['ฮารูน', 'hārūn', 'harun'],
    'อัยยูบ': ['job', 'ayyūb', 'ayyub'],
    'job': ['อัยยูบ', 'ayyūb'],
    'ซะกะรียา': ['zechariah', 'zakariyyā', 'zakariya'],
    'zechariah': ['ซะกะรียา', 'zakariyyā'],
    'ยะห์ยา': ['john', 'yaḥyā', 'yahya'],
    'john': ['ยะห์ยา', 'yaḥyā'],

    // Creation & Signs
    'วัว': ['cow', 'heifer', 'แม่วัว'],
    'cow': ['วัว', 'แม่วัว'],
    'มด': ['ant', 'ants'],
    'ant': ['มด'],
    'ants': ['มด', 'ฝูงมด'],
    'ผึ้ง': ['bee', 'bees'],
    'bee': ['ผึ้ง'],
    'bees': ['ผึ้ง'],
    'ช้าง': ['elephant'],
    'elephant': ['ช้าง'],
    'แมงมุม': ['spider'],
    'spider': ['แมงมุม'],
    'เหล็ก': ['iron'],
    'iron': ['เหล็ก'],
    'ดวงอาทิตย์': ['sun', 'พระอาทิตย์'],
    'sun': ['ดวงอาทิตย์', 'พระอาทิตย์'],
    'ดวงจันทร์': ['moon', 'พระจันทร์'],
    'moon': ['ดวงจันทร์', 'พระจันทร์'],
    'ดวงดาว': ['star', 'stars', 'ดาว'],
    'ดาว': ['star', 'stars', 'ดวงดาว'],
    'star': ['ดาว', 'ดวงดาว'],
    'stars': ['ดวงดาว', 'บรรดาดวงดาว'],
    'กลางคืน': ['night', 'ราตรี', 'ยามค่ำคืน'],
    'night': ['กลางคืน', 'ราตรี', 'ยามค่ำคืน'],
    'รุ่งอรุณ': ['dawn', 'daybreak', 'ยามรุ่งอรุณ'],
    'dawn': ['รุ่งอรุณ', 'ยามรุ่งอรุณ', 'ฟัจญร์'],
    'แม่น้ำ': ['river', 'rivers', 'ลำธาร'],
    'river': ['แม่น้ำ', 'ลำธาร'],
    'rivers': ['แม่น้ำ', 'ลำธารหลายสาย'],
    'ต้นไม้': ['tree', 'trees'],
    'tree': ['ต้นไม้'],
    'trees': ['ต้นไม้'],
    'ผลไม้': ['fruit', 'fruits'],
    'fruit': ['ผลไม้'],
    'fruits': ['ผลไม้'],
    'น้ำ': ['water'],
    'water': ['น้ำ'],
    'ฝน': ['rain'],
    'rain': ['ฝน', 'ห่าฝน'],
    'ลม': ['wind', 'winds'],
    'wind': ['ลม'],
    'winds': ['ลม'],
    'แผ่นดิน': ['earth', 'land', 'โลก'],
    'earth': ['แผ่นดิน', 'โลก'],
    'ภูเขา': ['mountain', 'mountains'],
    'mountain': ['ภูเขา'],
    'mountains': ['ภูเขา', 'เทือกเขา'],
    'ทะเล': ['sea', 'ocean'],
    'sea': ['ทะเล'],
    'เรือ': ['ship', 'ships'],
    'ship': ['เรือ'],
    'ships': ['เรือ', 'เรือกำปั่น'],
  };

  /// High-performance offline verse search across Thai, English, Arabic, and
  /// cross-language transliterated keywords (e.g. "ญิน" <-> "jin" / "jinn",
  /// "moses" <-> "มูซา", "mercy" <-> "เมตตา").
  static Future<List<Map<String, dynamic>>> searchVerses(
    String query, {
    int limit = 35,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return [];

    final db = await database;

    // Check if query is a direct reference like 2:255, 72:1, ญิน 1, jin 1
    final directRef = parseQuranReference(trimmed);
    if (directRef != null) {
      final directRows = await db.query(
        'verses',
        where: 'surah_id = ? AND verse_id = ?',
        whereArgs: [directRef.surahId, directRef.verseId],
        limit: 1,
      );
      if (directRows.isNotEmpty) {
        return directRows;
      }
    }

    final queryLower = trimmed.toLowerCase();
    final searchTerms = <String>{trimmed, queryLower};

    // Expand search terms with cross-language aliases
    for (final entry in _crossLanguageSearchAliases.entries) {
      final key = entry.key.toLowerCase();
      if (queryLower == key || queryLower.contains(key) || key.contains(queryLower)) {
        for (final alias in entry.value) {
          searchTerms.add(alias);
          searchTerms.add(alias.toLowerCase());
        }
      }
    }

    // Check if query has Arabic characters
    final hasArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(trimmed);

    // Build WHERE clauses
    final whereParts = <String>[];
    final whereArgs = <dynamic>[];

    for (final term in searchTerms.take(20)) {
      final t = term.trim();
      if (t.isEmpty) continue;
      final pattern = '%$t%';
      whereParts.add('translation_th LIKE ?');
      whereArgs.add(pattern);
      whereParts.add('translation_en LIKE ?');
      whereArgs.add(pattern);
      if (hasArabic) {
        whereParts.add('text_uthmani LIKE ?');
        whereArgs.add(pattern);
      }
    }

    if (whereParts.isEmpty) return [];

    // Prioritize exact query matches in translation_th, then translation_en, then tafsir_th
    final exactPattern = '%$queryLower%';
    final sql = '''
      SELECT *,
        CASE
          WHEN LOWER(translation_th) LIKE ? THEN 100
          WHEN LOWER(translation_en) LIKE ? THEN 90
          WHEN LOWER(translation_th) LIKE ? THEN 80
          WHEN LOWER(translation_en) LIKE ? THEN 70
          WHEN LOWER(tafsir_th) LIKE ? THEN 40
          ELSE 10
        END as search_score
      FROM verses
      WHERE ${whereParts.join(' OR ')}
      ORDER BY search_score DESC, surah_id ASC, verse_id ASC
      LIMIT ?
    ''';

    final scoreArgs = [
      '%$trimmed%',
      exactPattern,
      '%$queryLower%',
      '%$queryLower%',
      '%$queryLower%',
    ];

    try {
      final results = await db.rawQuery(
        sql,
        [...scoreArgs, ...whereArgs, limit],
      );
      return results;
    } catch (e) {
      debugPrint("Error searching verses in offline db: $e");
      return [];
    }
  }
}

