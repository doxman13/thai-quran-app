// lib/providers/progress_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class ProgressProvider extends ChangeNotifier {
  final String _surahKey = 'last_surah_id';
  final String _verseKey = 'last_verse_index';

  String _currentSurahId = '1';
  int _lastVerseIndex = 0;
  int _totalVerses = 0;
  bool _isInitialized = false;

  String get currentSurahId => _currentSurahId;
  int get lastVerseIndex => _lastVerseIndex;
  bool get isInitialized => _isInitialized;

  final ItemScrollController itemScrollController = ItemScrollController();
  final ItemPositionsListener itemPositionsListener = ItemPositionsListener.create();

  void setTotalVerses(int count) {
    _totalVerses = count;
  }

  ProgressProvider() {
    _init();
    
    // Listen to scrolling to automatically update progress
    itemPositionsListener.itemPositions.addListener(() {
      final positions = itemPositionsListener.itemPositions.value;
      if (positions.isNotEmpty) {
        int topIndex = 0;
        
        // Check if the last item is visible and fully/mostly inside the viewport
        bool isLastVisible = false;
        double lastTrailing = 2.0;
        for (var pos in positions) {
          if (pos.index == _totalVerses - 1) {
            isLastVisible = true;
            lastTrailing = pos.itemTrailingEdge;
            break;
          }
        }
        
        if (isLastVisible && lastTrailing <= 1.05) {
          topIndex = _totalVerses - 1;
        } else {
          // Find the item that covers or is closest to targetY (e.g. 30% from top)
          double targetY = 0.3;
          double minDistance = double.infinity;
          
          for (var pos in positions) {
            double itemCenter = (pos.itemLeadingEdge + pos.itemTrailingEdge) / 2;
            double dist = (itemCenter - targetY).abs();
            if (dist < minDistance) {
              minDistance = dist;
              topIndex = pos.index;
            }
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
    notifyListeners();
    
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
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_surahKey, surahId);
      await prefs.setInt(_verseKey, 0);
    }
  }
}
