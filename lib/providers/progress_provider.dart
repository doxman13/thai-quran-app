// lib/providers/progress_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class ProgressProvider extends ChangeNotifier {
  final String _surahKey = 'last_surah_id';
  final String _verseKey = 'last_verse_index';

  String _currentSurahId = '1';
  int _lastVerseIndex = 0;
  bool _isInitialized = false;

  String get currentSurahId => _currentSurahId;
  int get lastVerseIndex => _lastVerseIndex;
  bool get isInitialized => _isInitialized;

  final ItemScrollController itemScrollController = ItemScrollController();
  final ItemPositionsListener itemPositionsListener = ItemPositionsListener.create();

  ProgressProvider() {
    _init();
    
    // Listen to scrolling to automatically update progress
    itemPositionsListener.itemPositions.addListener(() {
      final positions = itemPositionsListener.itemPositions.value;
      if (positions.isNotEmpty) {
        // Find the item that is at the top/center of the viewport
        // item.itemLeadingEdge represents the top edge of the item relative to the viewport.
        // We pick the first item whose leading edge is <= 0.5 (meaning it's in the top half)
        // or just the absolute top item.
        int topIndex = 0;
        double minDistance = double.infinity;
        
        for (var pos in positions) {
          double dist = pos.itemLeadingEdge.abs();
          if (dist < minDistance) {
            minDistance = dist;
            topIndex = pos.index;
          }
        }

        _saveProgress(_currentSurahId, topIndex);
      }
    });
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentSurahId = prefs.getString(_surahKey) ?? '1';
    _lastVerseIndex = prefs.getInt(_verseKey) ?? 0;
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _saveProgress(String surahId, int verseIndex) async {
    if (_currentSurahId == surahId && _lastVerseIndex == verseIndex) return;

    _currentSurahId = surahId;
    _lastVerseIndex = verseIndex;
    
    // Do not notifyListeners() here to avoid rebuilding UI on every scroll tick.
    // We just silently save to SharedPreferences.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_surahKey, surahId);
    await prefs.setInt(_verseKey, verseIndex);
  }

  void jumpToSavedPosition() {
    if (itemScrollController.isAttached) {
      itemScrollController.jumpTo(index: _lastVerseIndex);
    }
  }

  Future<void> setCurrentSurah(String surahId) async {
    if (_currentSurahId != surahId) {
      _currentSurahId = surahId;
      _lastVerseIndex = 0; // Reset index when changing surahs manually
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_surahKey, surahId);
      await prefs.setInt(_verseKey, 0);
    }
  }
}
