import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qcf_quran/qcf_quran.dart' as qcf;

import '../models/hifz_task.dart';

class HifzSessionProvider extends ChangeNotifier {
  int _surahNumber;
  int _repeatStart;
  int _startVerse;
  int _endVerse;
  List<HifzTask> _tasks = [];
  int _currentTaskIndex = 0;
  bool _isPeekActive = false;
  final Map<int, int> _verseTallyMap = {}; // Verse number -> total repetitions
  DateTime _startTime = DateTime.now();


  HifzSessionProvider({
    int surahNumber = 1,
    int repeatStart = 1,
    int startVerse = 1,
    int endVerse = 3,
  })  : _surahNumber = surahNumber,
        _repeatStart = repeatStart,
        _startVerse = startVerse,
        _endVerse = endVerse {
    initRoutine(repeatStart, startVerse, endVerse);
  }

  int get surahNumber => _surahNumber;
  int get repeatStart => _repeatStart;
  int get startVerse => _startVerse;
  int get endVerse => _endVerse;
  List<HifzTask> get tasks => _tasks;
  int get currentTaskIndex => _currentTaskIndex;
  bool get isPeekActive => _isPeekActive;
  Map<int, int> get verseTallyMap => Map.unmodifiable(_verseTallyMap);
  DateTime get startTime => _startTime;

  HifzTask? get currentTask =>
      _tasks.isNotEmpty && _currentTaskIndex < _tasks.length
          ? _tasks[_currentTaskIndex]
          : null;

  bool get isSessionCompleted => _currentTaskIndex >= _tasks.length;

  double get routineProgress {
    if (_tasks.isEmpty) return 0.0;
    int totalReq = 0;
    int currentReq = 0;
    for (var task in _tasks) {
      totalReq += task.targetRepetitions;
      currentReq += task.currentProgress;
    }
    return totalReq == 0 ? 0.0 : (currentReq / totalReq).clamp(0.0, 1.0);
  }

  int get totalRecitationsCount {
    int total = 0;
    _verseTallyMap.forEach((_, count) => total += count);
    return total;
  }

  void initRoutine(int repeatStart, int startVerse, int endVerse) {
    _repeatStart = repeatStart;
    _startVerse = startVerse;
    _endVerse = endVerse;
    _tasks = generateHifzRoutine(repeatStart, startVerse, endVerse);
    _currentTaskIndex = 0;
    _isPeekActive = false;
    _verseTallyMap.clear();
    _startTime = DateTime.now();
    notifyListeners();
  }

  void setPeekActive(bool active) {
    if (_isPeekActive != active) {
      _isPeekActive = active;
      notifyListeners();
    }
  }


  void incrementProgress() {
    if (currentTask == null || isSessionCompleted) return;

    final task = currentTask!;
    
    if (task.currentProgress >= task.targetRepetitions) {
      // Advance to the next task
      _currentTaskIndex++;
      if (isSessionCompleted) {
        notifyListeners();
        return;
      }
      // Start the new task
      final newTask = currentTask!;
      newTask.currentProgress = 1;
      for (int v in newTask.verseNumbers) {
        _verseTallyMap[v] = (_verseTallyMap[v] ?? 0) + 1;
      }
    } else {
      task.currentProgress++;
      for (int v in task.verseNumbers) {
        _verseTallyMap[v] = (_verseTallyMap[v] ?? 0) + 1;
      }
    }

    notifyListeners();
  }

  void resetSession() {
    initRoutine(_repeatStart, _startVerse, _endVerse);
  }

  @override
  void dispose() {
    super.dispose();
  }
}
