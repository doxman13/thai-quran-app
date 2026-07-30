import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class TajweedService {
  static Map<String, dynamic>? _data;
  
  static Future<void> load() async {
    if (_data != null) return;
    try {
      final jsonString = await rootBundle.loadString('assets/Tajweed/qpc-hafs-tajweed.json');
      _data = jsonDecode(jsonString);
    } catch (e) {
      debugPrint("Error loading Tajweed JSON: $e");
    }
  }

  static String? getVerse(int surah, int ayah) {
    return _data?['$surah:$ayah']?['text'];
  }
}
