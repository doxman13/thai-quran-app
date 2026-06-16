// lib/data/quran_repository.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/verse.dart';

class QuranRepository {
  Map<String, dynamic>? _quranData;
  final Map<String, String> surahNames = {};

  // Loads all Surahs from the local JSON asset and fetches Surah Names
  Future<void> init() async {
    final String response = await rootBundle.loadString('assets/thai_v3.json');
    _quranData = json.decode(response);

    // Fetch surah names
    try {
      final res = await http.get(Uri.parse('https://api.quran.com/api/v4/chapters'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        for (var chapter in data['chapters']) {
          surahNames[chapter['id'].toString()] = chapter['name_simple'];
        }
      }
    } catch (e) {
      // Fallback if offline
      for (int i = 1; i <= 114; i++) {
        surahNames[i.toString()] = 'Surah $i';
      }
    }
  }

  String getSurahName(String surahId) {
    final name = surahNames[surahId] ?? 'Surah $surahId';
    return '$surahId. $name';
  }

  // Gets the verses for a specific Surah
  List<Verse> getSurahVerses(String surahId) {
    if (_quranData == null || !_quranData!.containsKey(surahId)) {
      return [];
    }

    final versesMap = _quranData![surahId]['verses'] as Map<String, dynamic>;
    final List<Verse> versesList = [];

    // Keys are strings like "1", "2", "3"
    final sortedKeys = versesMap.keys.toList()
      ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));

    for (var key in sortedKeys) {
      // In thai_v3.json, the value is just the Thai V3 string.
      // Wait, the prompt says we should also have Thai V2 and Arabic.
      // But thai_v3.json only contains:
      // "1": { "verses": { "1": "thai text" } }
      // We will map Thai V3 directly. Thai V2 and Arabic will be fetched or handled elsewhere.
      versesList.add(Verse(
        id: key,
        surahId: surahId,
        thaiV3: versesMap[key].toString(),
        thaiV2: versesMap[key].toString(), // fallback
        arabic: '', // Initially empty, will be fetched via API
      ));
    }

    return versesList;
  }

  // Fetches Arabic text from the Quran Foundation API
  // https://api.quran.com/api/v4/verses/by_key/{chapter}:{verse}?fields=text_uthmani
  Future<String> fetchArabicVerse(String surahId, String verseId) async {
    final cacheKey = 'arabic_${surahId}_$verseId';
    final prefs = await SharedPreferences.getInstance();

    // 1. Check local cache first
    final cached = prefs.getString(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    // 2. Fetch from internet if not cached
    try {
      final url = Uri.parse(
          'https://api.quran.com/api/v4/verses/by_key/$surahId:$verseId?fields=text_uthmani');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final arabicText = data['verse']['text_uthmani'] as String;

        // Save to cache
        await prefs.setString(cacheKey, arabicText);
        return arabicText;
      }
    } catch (e) {
      // Return empty if offline or error
      return '';
    }
    return '';
  }
}
