// lib/providers/stats_provider.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StatsProvider extends ChangeNotifier {
  static const String _historyKey = 'reading_history_v1';
  
  // Date string YYYY-MM-DD -> Set of "surahId:verseId"
  Map<String, Set<String>> _history = {};
  Timer? _saveTimer;

  StatsProvider() {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedData = prefs.getString(_historyKey);
      if (savedData != null) {
        final Map<String, dynamic> decoded = json.decode(savedData);
        _history = decoded.map((date, list) {
          final set = (list as List).map((e) => e.toString()).toSet();
          return MapEntry(date, set);
        });
      }
    } catch (e) {
      debugPrint('Error loading stats history: $e');
    }
    notifyListeners();
  }

  String _getDateString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> logVerseRead(String surahId, String verseId) async {
    final dateStr = _getDateString(DateTime.now());
    final verseKey = '$surahId:$verseId';
    
    _history.putIfAbsent(dateStr, () => {});
    if (_history[dateStr]!.contains(verseKey)) return; // already logged

    _history[dateStr]!.add(verseKey);
    notifyListeners();

    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        // Serialize map of sets to map of lists
        final mapToSave = _history.map((date, set) => MapEntry(date, set.toList()));
        await prefs.setString(_historyKey, json.encode(mapToSave));
      } catch (e) {
        debugPrint('Error saving stats history: $e');
      }
    });
  }

  int get todayReadCount {
    final todayStr = _getDateString(DateTime.now());
    return _history[todayStr]?.length ?? 0;
  }

  int get weekReadCount {
    final now = DateTime.now();
    final uniqueVerses = <String>{};
    for (int i = 0; i < 7; i++) {
      final dateStr = _getDateString(now.subtract(Duration(days: i)));
      if (_history.containsKey(dateStr)) {
        uniqueVerses.addAll(_history[dateStr]!);
      }
    }
    return uniqueVerses.length;
  }

  int get monthReadCount {
    final now = DateTime.now();
    final uniqueVerses = <String>{};
    for (int i = 0; i < 30; i++) {
      final dateStr = _getDateString(now.subtract(Duration(days: i)));
      if (_history.containsKey(dateStr)) {
        uniqueVerses.addAll(_history[dateStr]!);
      }
    }
    return uniqueVerses.length;
  }

  int get streakCount {
    if (_history.isEmpty) return 0;

    final today = DateTime.now();
    final todayStr = _getDateString(today);
    final yesterdayStr = _getDateString(today.subtract(const Duration(days: 1)));

    // If no reading today and no reading yesterday, streak is broken/0
    bool readToday = _history.containsKey(todayStr) && _history[todayStr]!.isNotEmpty;
    bool readYesterday = _history.containsKey(yesterdayStr) && _history[yesterdayStr]!.isNotEmpty;

    if (!readToday && !readYesterday) {
      return 0;
    }

    int streak = 0;
    DateTime checkDate = readToday ? today : today.subtract(const Duration(days: 1));

    while (true) {
      final checkStr = _getDateString(checkDate);
      if (_history.containsKey(checkStr) && _history[checkStr]!.isNotEmpty) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }

  @override
  void dispose() {
    if (_saveTimer != null && _saveTimer!.isActive) {
      _saveTimer!.cancel();
      try {
        final mapToSave = _history.map((date, set) => MapEntry(date, set.toList()));
        SharedPreferences.getInstance().then((prefs) {
          prefs.setString(_historyKey, json.encode(mapToSave));
        });
      } catch (e) {
        debugPrint('Error saving stats history on dispose: $e');
      }
    }
    super.dispose();
  }
}
