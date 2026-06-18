// lib/data/quran_repository.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/verse.dart';

class QuranRepository {
  Map<String, dynamic>? _quranData;
  Map<String, dynamic>? _mergedQuranData;
  final Map<String, String> surahNames = {};

  // Loads all Surahs from the local JSON asset and fetches Surah Names
  Future<void> init() async {
    if (_quranData != null) return; // already initialized

    final String response = await rootBundle.loadString('assets/thai_v3.json');
    _quranData = json.decode(response);

    try {
      final String mergedResponse = await rootBundle.loadString(
        'assets/merged_quran.json',
      );
      _mergedQuranData = json.decode(mergedResponse);
    } catch (e) {
      print('Error loading merged_quran.json: $e');
    }

    // Fetch surah names
    try {
      final res = await http.get(
        Uri.parse('https://api.quran.com/api/v4/chapters'),
      );
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
    final versesMap = _getVersesMap(surahId);
    if (versesMap.isEmpty) {
      return [];
    }

    final List<Verse> versesList = [];

    final sortedKeys = versesMap.keys.toList()
      ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));

    for (var key in sortedKeys) {
      final verseKey = '$surahId:$key';
      final mergedVerse = _mergedQuranData?[verseKey];

      versesList.add(
        Verse(
          id: key,
          surahId: surahId,
          thaiV3: versesMap[key].toString(),
          thaiV2:
              mergedVerse?['thai_v2']?.toString() ??
              mergedVerse?['thai_v1']?.toString() ??
              versesMap[key].toString(),
          english: mergedVerse?['english']?.toString() ?? 'N/A',
          arabic: '', // Initially empty, will be fetched via API
        ),
      );
    }

    return versesList;
  }

  Map<String, String> _getVersesMap(String surahId) {
    final quranData = _quranData;
    if (quranData == null) return {};

    final oldSurahData = quranData[surahId];
    if (oldSurahData is Map<String, dynamic>) {
      final oldVerses = oldSurahData['verses'];
      if (oldVerses is Map<String, dynamic>) {
        return oldVerses.map(
          (verseId, verseText) => MapEntry(verseId, verseText.toString()),
        );
      }
    }

    final versePrefix = '$surahId:';
    final verses = <String, String>{};

    for (final entry in quranData.entries) {
      final key = entry.key;
      if (!key.startsWith(versePrefix)) continue;

      final verseId = key.substring(versePrefix.length);
      if (int.tryParse(verseId) == null) continue;

      verses[verseId] = entry.value.toString();
    }

    return verses;
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
        'https://api.quran.com/api/v4/verses/by_key/$surahId:$verseId?fields=text_uthmani',
      );
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
