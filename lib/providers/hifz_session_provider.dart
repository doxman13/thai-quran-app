// lib/providers/hifz_session_provider.dart
//
// The single source of truth for all Hifz session logic.
// Supports both HifzSessionType.newVerses and HifzSessionType.review
// with all three ReviewGranularity options.
//
// ARCHITECTURE RULES (enforced here):
//  - Zero UI code in this file.
//  - All DB calls delegated to HifzRepository (injected dependency).
//  - Auto-save fires asynchronously on every incrementProgress() call.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:qcf_quran/qcf_quran.dart' as qcf;

import '../models/hifz_task.dart';
import '../models/hifz_verse_chunk.dart';
import '../models/hifz_session_config.dart';
import '../database/hifz_repository.dart';
import '../utils/hifz_mastery_utils.dart';

class HifzSessionProvider extends ChangeNotifier {
  // ---------------------------------------------------------------------------
  // Dependencies
  // ---------------------------------------------------------------------------
  final HifzRepository _repo;

  // ---------------------------------------------------------------------------
  // Session type & mode
  // ---------------------------------------------------------------------------
  HifzSessionType _sessionType;
  HifzSessionType get sessionType => _sessionType;

  // ---------------------------------------------------------------------------
  // New Verses state (mirrors original provider exactly)
  // ---------------------------------------------------------------------------
  int _surahNumber;
  int _repeatStart;
  int _startVerse;
  int _endVerse;
  List<HifzTask> _tasks = [];
  int _currentTaskIndex = 0;
  bool _isPeekActive = false;
  final Map<int, int> _verseTallyMap = {};
  DateTime _startTime = DateTime.now();

  // ---------------------------------------------------------------------------
  // Review mode state
  // ---------------------------------------------------------------------------
  ReviewGranularity _reviewGranularity = ReviewGranularity.bySurah;
  ReviewTargetParams? _reviewTargetParams;
  List<ReviewStep> _reviewSteps = [];
  int _reviewStepIndex = 0;
  ReviewPhase _reviewPhase = ReviewPhase.visible;
  int _reviewTally = 0; // current recitation count in this phase (max 2)
  static const int _reviewTargetTally = 2;

  // ---------------------------------------------------------------------------
  // Shared
  // ---------------------------------------------------------------------------
  String _sessionId;
  String get sessionId => _sessionId;

  bool _chunkLongVerses = true;
  bool get chunkLongVerses => _chunkLongVerses;
  Map<int, List<HifzVerseChunk>> _verseChunksMap = {};
  Map<int, List<HifzVerseChunk>> get verseChunksMap => Map.unmodifiable(_verseChunksMap);
  ActiveSessionSnapshot? _pendingResumeSnapshot;

  // ---------------------------------------------------------------------------
  // Constructor: New Verses mode (backward-compatible default)
  // ---------------------------------------------------------------------------
  HifzSessionProvider({
    HifzRepository? repository,
    this._surahNumber = 1,
    int repeatStart = 1,
    int startVerse = 1,
    int endVerse = 3,
    String? sessionId,
    this._chunkLongVerses = true,
    Map<int, List<HifzVerseChunk>>? verseChunksMap,
  })  : _repo = repository ?? HifzRepository(),
        _sessionType = HifzSessionType.newVerses,
        _repeatStart = repeatStart,
        _startVerse = startVerse,
        _endVerse = endVerse,
        _sessionId = sessionId ?? DateTime.now().millisecondsSinceEpoch.toString() {
    if (verseChunksMap != null) {
      _verseChunksMap = verseChunksMap;
    }
    initRoutine(
      repeatStart,
      startVerse,
      endVerse,
      surah: _surahNumber,
      chunkLongVerses: _chunkLongVerses,
      verseChunksMap: _verseChunksMap.isNotEmpty ? _verseChunksMap : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Named constructor: Review mode
  // ---------------------------------------------------------------------------
  HifzSessionProvider.review({
    HifzRepository? repository,
    required ReviewGranularity granularity,
    required ReviewTargetParams targetParams,
    String? sessionId,
  })  : _repo = repository ?? HifzRepository(),
        _sessionType = HifzSessionType.review,
        _surahNumber = 1,
        _repeatStart = 1,
        _startVerse = 1,
        _endVerse = 1,
        _sessionId = sessionId ?? DateTime.now().millisecondsSinceEpoch.toString() {
    _reviewGranularity = granularity;
    _reviewTargetParams = targetParams;
    _initReviewRoutine(granularity, targetParams);
  }

  // ---------------------------------------------------------------------------
  // New Verses getters (preserved exactly)
  // ---------------------------------------------------------------------------
  int get surahNumber => _surahNumber;

  /// Returns the effective surah number for both Review and New Verses modes.
  int get currentSurahNumber {
    if (_sessionType == HifzSessionType.review) {
      final step = currentReviewStep;
      if (step != null) {
        return step.surahNumber ?? (_reviewGranularity == ReviewGranularity.bySurah ? step.primaryIndex : _surahNumber);
      }
    }
    return _surahNumber;
  }

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

  bool get isNewVersesSessionCompleted => _currentTaskIndex >= _tasks.length;

  double get routineProgress {
    if (_sessionType == HifzSessionType.newVerses) {
      if (_tasks.isEmpty) return 0.0;
      int totalReq = 0;
      int currentReq = 0;
      for (final task in _tasks) {
        totalReq += task.targetRepetitions;
        currentReq += task.currentProgress;
      }
      return totalReq == 0 ? 0.0 : (currentReq / totalReq).clamp(0.0, 1.0);
    } else {
      if (_reviewSteps.isEmpty) return 0.0;
      // Each step has 2 phases × 2 tally = 4 increments total
      final totalIncrements = _reviewSteps.length * 4;
      final doneSteps = _reviewStepIndex * 4;
      final phaseOffset = (_reviewPhase == ReviewPhase.hidden ? 2 : 0) + _reviewTally;
      return ((doneSteps + phaseOffset) / totalIncrements).clamp(0.0, 1.0);
    }
  }

  int get totalRecitationsCount {
    if (_sessionType == HifzSessionType.newVerses) {
      int total = 0;
      _verseTallyMap.forEach((_, count) => total += count);
      return total;
    } else {
      // Each increment in review = 1 recitation of the whole block
      return (_reviewStepIndex * 4) +
          (_reviewPhase == ReviewPhase.hidden ? 2 : 0) +
          _reviewTally;
    }
  }

  // ---------------------------------------------------------------------------
  // Review mode getters
  // ---------------------------------------------------------------------------
  ReviewGranularity get reviewGranularity => _reviewGranularity;
  ReviewTargetParams? get reviewTargetParams => _reviewTargetParams;
  List<ReviewStep> get reviewSteps => _reviewSteps;
  int get reviewStepIndex => _reviewStepIndex;
  ReviewPhase get reviewPhase => _reviewPhase;
  int get reviewTally => _reviewTally;
  int get reviewTargetTally => _reviewTargetTally;

  ReviewStep? get currentReviewStep =>
      _reviewSteps.isNotEmpty && _reviewStepIndex < _reviewSteps.length
          ? _reviewSteps[_reviewStepIndex]
          : null;

  bool get isReviewSessionCompleted => _reviewStepIndex >= _reviewSteps.length;

  // Unified "is session done" property
  bool get isSessionCompleted => _sessionType == HifzSessionType.newVerses
      ? isNewVersesSessionCompleted
      : isReviewSessionCompleted;

  // ---------------------------------------------------------------------------
  // New Verses init (backward-compatible)
  // ---------------------------------------------------------------------------
  void initRoutine(
    int repeatStart,
    int startVerse,
    int endVerse, {
    int? surah,
    bool? chunkLongVerses,
    Map<int, List<HifzVerseChunk>>? verseChunksMap,
  }) {
    _pendingResumeSnapshot = null;
    _sessionType = HifzSessionType.newVerses;
    if (surah != null) {
      _surahNumber = surah;
    }
    if (chunkLongVerses != null) {
      _chunkLongVerses = chunkLongVerses;
    }
    if (verseChunksMap != null) {
      _verseChunksMap = verseChunksMap;
    }
    _repeatStart = repeatStart;
    _startVerse = startVerse;
    _endVerse = endVerse;
    _tasks = generateHifzRoutine(
      repeatStart,
      startVerse,
      endVerse,
      verseChunksMap: (_chunkLongVerses && _verseChunksMap.isNotEmpty) ? _verseChunksMap : null,
    );
    _currentTaskIndex = 0;
    _isPeekActive = false;
    _verseTallyMap.clear();
    _startTime = DateTime.now();
    notifyListeners();
  }

  /// Sets chunk data for the active session and regenerates tasks if in New Verses mode,
  /// preserving pending resume snapshots or live progress.
  void setVerseChunks(Map<int, List<HifzVerseChunk>> chunksMap, {bool enable = true}) {
    _chunkLongVerses = enable;
    _verseChunksMap = chunksMap;
    if (_sessionType == HifzSessionType.newVerses) {
      _regenerateNewVersesTasksPreservingProgress();
    }
  }

  /// Toggles chunking on or off for the active session.
  void toggleChunkLongVerses(bool enable) {
    if (_chunkLongVerses == enable) return;
    _chunkLongVerses = enable;
    if (_sessionType == HifzSessionType.newVerses) {
      _regenerateNewVersesTasksPreservingProgress();
    }
  }

  void _regenerateNewVersesTasksPreservingProgress() {
    final effectiveMap = (_chunkLongVerses && _verseChunksMap.isNotEmpty) ? _verseChunksMap : null;
    final pendingSnap = _pendingResumeSnapshot;
    if (pendingSnap != null && pendingSnap.sessionType == HifzSessionType.newVerses) {
      _pendingResumeSnapshot = null;
      _hydrateNewVersesFromSnapshot(pendingSnap, chunksOverride: effectiveMap);
      _isPeekActive = false;
      notifyListeners();
      unawaited(_autoSave());
      return;
    }

    final prevTask = currentTask;
    final prevIdx = _currentTaskIndex;
    final hadLiveProgress = prevIdx > 0 || (prevTask?.currentProgress ?? 0) > 0;
    final generated = generateHifzRoutine(
      _repeatStart,
      _startVerse,
      _endVerse,
      verseChunksMap: effectiveMap,
    );

    if (hadLiveProgress && generated.isNotEmpty) {
      final matchedIdx = prevTask != null ? generated.indexWhere((t) => t.id == prevTask.id) : -1;
      final nextIdx = matchedIdx >= 0 ? matchedIdx : prevIdx.clamp(0, generated.length - 1);
      for (int i = 0; i < generated.length; i++) {
        if (i < nextIdx) {
          generated[i].currentProgress = generated[i].targetRepetitions;
        } else if (i == nextIdx) {
          final maxPartial = (generated[i].targetRepetitions - 1).clamp(0, generated[i].targetRepetitions);
          generated[i].currentProgress = (prevTask?.currentProgress ?? 0).clamp(0, maxPartial);
        }
      }
      _tasks = generated;
      _currentTaskIndex = nextIdx;
      _isPeekActive = false;
      notifyListeners();
      unawaited(_autoSave());
      return;
    }

    _tasks = generated;
    _currentTaskIndex = 0;
    _isPeekActive = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Review mode init
  // ---------------------------------------------------------------------------
  void initReviewRoutine(
      ReviewGranularity granularity, ReviewTargetParams params) {
    _sessionType = HifzSessionType.review;
    _reviewGranularity = granularity;
    _reviewTargetParams = params;
    _initReviewRoutine(granularity, params);
    _startTime = DateTime.now();
    notifyListeners();
  }

  void _initReviewRoutine(
      ReviewGranularity granularity, ReviewTargetParams params) {
    _reviewSteps = _buildReviewSteps(granularity, params);
    _reviewStepIndex = 0;
    _reviewPhase = ReviewPhase.visible;
    _reviewTally = 0;
    _isPeekActive = false;
  }

  List<ReviewStep> _buildReviewSteps(
      ReviewGranularity granularity, ReviewTargetParams params) {
    final steps = <ReviewStep>[];
    switch (granularity) {
      case ReviewGranularity.bySurah:
        final start = params.startSurah ?? 1;
        final end = params.endSurah ?? 114;
        for (int s = start; s <= end; s++) {
          steps.add(ReviewStep(
            label: 'Surah $s',
            primaryIndex: s,
            surahNumber: s,
          ));
        }
        break;

      case ReviewGranularity.byVerses:
        final surah = params.surahNumber ?? 1;
        final vStart = params.startVerse ?? 1;
        final vEnd = params.endVerse ?? 1;
        steps.add(ReviewStep(
          label: 'Surah $surah, Verses $vStart–$vEnd',
          primaryIndex: surah,
          surahNumber: surah,
          verseStart: vStart,
          verseEnd: vEnd,
        ));
        break;

      case ReviewGranularity.byPage:
        final pStart = params.startPage ?? 1;
        final pEnd = params.endPage ?? 1;
        for (int p = pStart; p <= pEnd; p++) {
          steps.add(ReviewStep(
            label: 'Page $p',
            primaryIndex: p,
          ));
        }
        break;
    }
    return steps;
  }

  // ---------------------------------------------------------------------------
  // Visibility & Peek State (Dynamic Hide/Show Anytime)
  // ---------------------------------------------------------------------------
  bool? _manualHiddenOverride;

  bool get defaultTaskHidden =>
      currentTask?.mode == TextVisibilityMode.hidden;

  bool get defaultReviewHidden =>
      _reviewPhase == ReviewPhase.hidden;

  bool get isCurrentStepDefaultHidden =>
      _sessionType == HifzSessionType.newVerses
          ? defaultTaskHidden
          : defaultReviewHidden;

  /// Returns whether the target verse(s) are currently rendered hidden.
  bool get isTargetHidden {
    if (isSessionCompleted) return false;
    return _manualHiddenOverride ?? isCurrentStepDefaultHidden;
  }

  /// Whether voice recitation tracking is eligible for the current session state.
  /// Only available for:
  /// 1. Review mode in hidden stage.
  /// 2. New verses mode during cumulative repeat range in hidden stage.
  bool get isVoiceTrackingEligible {
    if (isSessionCompleted) return false;
    if (_sessionType == HifzSessionType.review) {
      return _reviewPhase == ReviewPhase.hidden;
    } else if (_sessionType == HifzSessionType.newVerses) {
      final task = currentTask;
      if (task == null) return false;
      return task.type == TaskType.cumulativeLink &&
          task.mode == TextVisibilityMode.hidden;
    }
    return false;
  }

  /// True if the user has manually toggled the visibility away from default for this step.
  bool get isVisibilityOverridden => _manualHiddenOverride != null;

  /// Toggles visibility anytime. Inverts current hidden state.
  void toggleVisibilityOverride() {
    _manualHiddenOverride = !isTargetHidden;
    _isPeekActive = !isTargetHidden && isCurrentStepDefaultHidden;
    notifyListeners();
  }

  /// Backward-compatible peek setter.
  void setPeekActive(bool active) {
    toggleVisibilityOverride();
  }

  /// Resets manual visibility override back to the current step's default mode.
  void resetVisibilityOverride() {
    if (_manualHiddenOverride != null) {
      _manualHiddenOverride = null;
      _isPeekActive = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // incrementProgress — the single entry point for all tally actions
  // ---------------------------------------------------------------------------
  void incrementProgress() {
    // Automatically revert visibility override back to default upon clicking count
    _pendingResumeSnapshot = null;
    _manualHiddenOverride = null;
    _isPeekActive = false;
    if (_sessionType == HifzSessionType.newVerses) {
      _incrementNewVerses();
    } else {
      _incrementReview();
    }
    // Fire-and-forget auto-save
    unawaited(_autoSave());
  }

  void advanceStepOrPhase() {
    _pendingResumeSnapshot = null;
    _manualHiddenOverride = null;
    _isPeekActive = false;
    if (_sessionType == HifzSessionType.newVerses) {
      if (currentTask == null || isNewVersesSessionCompleted) return;
      _currentTaskIndex++;
      if (isNewVersesSessionCompleted) {
        unawaited(_handleNewVersesSessionCompleted());
      }
    } else {
      if (isReviewSessionCompleted) return;
      if (_reviewPhase == ReviewPhase.visible) {
        _reviewPhase = ReviewPhase.hidden;
        _reviewTally = 0;
      } else {
        final step = currentReviewStep;
        if (step != null) {
          if (_reviewGranularity == ReviewGranularity.bySurah) {
            unawaited(_repo.incrementReviewCount(step.primaryIndex));
            unawaited(_repo.recordHistory(HifzSessionType.review, 'Surah ${step.primaryIndex} (Review)', surahNumber: step.primaryIndex));
          } else {
            unawaited(_repo.recordHistory(HifzSessionType.review, '${step.label} (Review)', surahNumber: step.surahNumber));
          }
        }
        _reviewStepIndex++;
        _reviewPhase = ReviewPhase.visible;
        _reviewTally = 0;

        if (isReviewSessionCompleted) {
          unawaited(_repo.clearActiveSession(sessionId: _sessionId));
        }
      }
    }
    notifyListeners();
    if (!isSessionCompleted) {
      unawaited(_autoSave());
    }
  }

  Future<void> _handleNewVersesSessionCompleted() async {
    final totalVersesInSurah = qcf.getVerseCount(_surahNumber);
    final history = await _repo.getHistory(limit: 200);
    final isRangeFullSurah = _startVerse == 1 && _endVerse >= totalVersesInSurah;
    final isFullSurahCompleted = isRangeFullSurah ||
        areAllSurahVersesCoveredFromHistory(
          surahNumber: _surahNumber,
          history: history,
          extraRanges: [
            VerseRange(startVerse: _startVerse, endVerse: _endVerse),
          ],
        );
    if (isFullSurahCompleted) {
      await _repo.markNewVersesCompleted(_surahNumber);
    }
    final rangeLabel = isRangeFullSurah
        ? 'Surah $_surahNumber'
        : 'Surah $_surahNumber:$_startVerse-$_endVerse';
    await _repo.recordHistory(
      HifzSessionType.newVerses,
      '$rangeLabel (New Verses)',
      surahNumber: _surahNumber,
    );
    await _repo.clearActiveSession(sessionId: _sessionId);
  }

  void _incrementNewVerses() {
    if (currentTask == null || isNewVersesSessionCompleted) return;
    final task = currentTask!;
    if (task.currentProgress < task.targetRepetitions) {
      task.currentProgress++;
      for (int v in task.verseNumbers) {
        _verseTallyMap[v] = (_verseTallyMap[v] ?? 0) + 1;
      }
    }
    notifyListeners();
  }

  void _incrementReview() {
    if (isReviewSessionCompleted) return;
    if (_reviewTally < _reviewTargetTally) {
      _reviewTally++;
    }
    notifyListeners();
  }

  void undoLastIncrement() {
    _pendingResumeSnapshot = null;
    if (_sessionType == HifzSessionType.newVerses) {
      _undoNewVerses();
    } else {
      _undoReview();
    }
    notifyListeners();
    unawaited(_autoSave());
  }

  void _undoNewVerses() {
    _manualHiddenOverride = null;
    _isPeekActive = false;

    if (isNewVersesSessionCompleted) {
      if (_tasks.isNotEmpty) {
        _currentTaskIndex = _tasks.length - 1;
        final task = _tasks[_currentTaskIndex];
        if (task.currentProgress > 0) {
          task.currentProgress--;
          for (int v in task.verseNumbers) {
            _verseTallyMap[v] = (_verseTallyMap[v] ?? 0) - 1;
          }
        }
      }
      return;
    }

    if (currentTask == null) return;
    final task = currentTask!;
    if (task.currentProgress > 0) {
      task.currentProgress--;
      for (int v in task.verseNumbers) {
        _verseTallyMap[v] = (_verseTallyMap[v] ?? 0) - 1;
      }
    } else if (_currentTaskIndex > 0) {
      _currentTaskIndex--;
      final prevTask = _tasks[_currentTaskIndex];
      if (prevTask.currentProgress > 0) {
        prevTask.currentProgress--;
        for (int v in prevTask.verseNumbers) {
          _verseTallyMap[v] = (_verseTallyMap[v] ?? 0) - 1;
        }
      }
    }
  }

  void _undoReview() {
    _manualHiddenOverride = null;
    _isPeekActive = false;

    if (isReviewSessionCompleted) {
      if (_reviewSteps.isNotEmpty) {
        _reviewStepIndex = _reviewSteps.length - 1;
        _reviewPhase = ReviewPhase.hidden;
        _reviewTally = (_reviewTargetTally - 1).clamp(0, _reviewTargetTally);
      }
      return;
    }

    if (_reviewTally > 0) {
      _reviewTally--;
    } else if (_reviewPhase == ReviewPhase.hidden) {
      _reviewPhase = ReviewPhase.visible;
      _reviewTally = (_reviewTargetTally - 1).clamp(0, _reviewTargetTally);
    } else if (_reviewStepIndex > 0) {
      _reviewStepIndex--;
      _reviewPhase = ReviewPhase.hidden;
      _reviewTally = (_reviewTargetTally - 1).clamp(0, _reviewTargetTally);
    }
  }

  void resetCurrentTask() {
    _pendingResumeSnapshot = null;
    _manualHiddenOverride = null;
    _isPeekActive = false;
    if (_sessionType == HifzSessionType.newVerses) {
      if (currentTask == null || isNewVersesSessionCompleted) return;
      currentTask!.currentProgress = 0;
      for (int v in currentTask!.verseNumbers) {
        _verseTallyMap[v] = 0;
      }
    } else {
      _reviewTally = 0;
    }
    notifyListeners();
    unawaited(_autoSave());
  }

  void resetSession() {
    _pendingResumeSnapshot = null;
    _manualHiddenOverride = null;
    _isPeekActive = false;
    if (_sessionType == HifzSessionType.newVerses) {
      initRoutine(_repeatStart, _startVerse, _endVerse);
    } else if (_reviewTargetParams != null) {
      initReviewRoutine(_reviewGranularity, _reviewTargetParams!);
    }
    unawaited(_repo.clearActiveSession(sessionId: _sessionId));
  }

  /// Flushes any debounced active session snapshot immediately to cloud.
  Future<void> flushActiveSessionSync() => _repo.flushPendingActiveSessionSync();

  // ---------------------------------------------------------------------------
  // Restore from snapshot (called by resume dialog)
  // ---------------------------------------------------------------------------
  void restoreFromSnapshot(ActiveSessionSnapshot snap) {
    _sessionId = snap.sessionId;
    _manualHiddenOverride = null;
    _sessionType = snap.sessionType;
    _startTime = DateTime.fromMillisecondsSinceEpoch(snap.lastUpdatedTimestamp);

    if (snap.sessionType == HifzSessionType.newVerses) {
      _surahNumber = snap.nvSurahNumber ?? _surahNumber;
      _repeatStart = snap.nvRepeatStart ?? _repeatStart;
      _startVerse = snap.nvStartVerse ?? _startVerse;
      _endVerse = snap.nvEndVerse ?? _endVerse;
      _chunkLongVerses = snap.nvChunkLongVerses;
      // Preserve snapshot across imminent async _loadVerseChunks / setVerseChunks call
      _pendingResumeSnapshot = snap;
      _hydrateNewVersesFromSnapshot(snap);
    } else {
      _pendingResumeSnapshot = null;
      _reviewGranularity = snap.reviewGranularity ?? ReviewGranularity.bySurah;
      _reviewTargetParams = snap.reviewTargetParams;
      if (_reviewTargetParams != null) {
        _reviewSteps =
            _buildReviewSteps(_reviewGranularity, _reviewTargetParams!);
      }
      if (_reviewSteps.isEmpty) {
        _reviewStepIndex = 0;
        _reviewPhase = ReviewPhase.visible;
        _reviewTally = 0;
      } else {
        var stepIdx = snap.currentStepIndex.clamp(0, _reviewSteps.length - 1);
        var phase = snap.currentMode == 'hidden'
            ? ReviewPhase.hidden
            : ReviewPhase.visible;
        var tally = math.max(0, snap.currentTally);

        if (tally >= _reviewTargetTally) {
          if (phase == ReviewPhase.visible) {
            phase = ReviewPhase.hidden;
            tally = 0;
          } else if (stepIdx + 1 < _reviewSteps.length) {
            stepIdx += 1;
            phase = ReviewPhase.visible;
            tally = 0;
          } else {
            tally = _reviewTargetTally - 1;
          }
        }
        _reviewStepIndex = stepIdx;
        _reviewPhase = phase;
        _reviewTally = tally;
      }
    }

    _isPeekActive = false;
    notifyListeners();
  }

  void _hydrateNewVersesFromSnapshot(
    ActiveSessionSnapshot snap, {
    Map<int, List<HifzVerseChunk>>? chunksOverride,
  }) {
    final effectiveMap = chunksOverride ??
        ((_chunkLongVerses && _verseChunksMap.isNotEmpty) ? _verseChunksMap : null);
    final generated = generateHifzRoutine(
      _repeatStart,
      _startVerse,
      _endVerse,
      verseChunksMap: effectiveMap,
    );

    if (generated.isEmpty) {
      _tasks = [];
      _currentTaskIndex = 0;
      _verseTallyMap.clear();
      if (snap.verseTallyMap != null) {
        _verseTallyMap.addAll(snap.verseTallyMap!);
      }
      return;
    }

    final matchedIdx = snap.currentTaskId != null
        ? generated.indexWhere((t) => t.id == snap.currentTaskId)
        : -1;
    var restoredIndex = matchedIdx >= 0
        ? matchedIdx
        : snap.currentStepIndex.clamp(0, generated.length - 1);

    final targetAtIdx = generated[restoredIndex].targetRepetitions;
    var tallyAtIdx = math.max(0, snap.currentTally);

    if (tallyAtIdx >= targetAtIdx && restoredIndex + 1 < generated.length) {
      restoredIndex += 1;
      tallyAtIdx = 0;
    } else {
      tallyAtIdx = tallyAtIdx.clamp(0, math.max(0, targetAtIdx - 1));
    }

    for (int i = 0; i < generated.length; i++) {
      if (i < restoredIndex) {
        generated[i].currentProgress = generated[i].targetRepetitions;
      } else if (i == restoredIndex) {
        generated[i].currentProgress = tallyAtIdx;
      } else {
        generated[i].currentProgress = 0;
      }
    }

    _tasks = generated;
    _currentTaskIndex = restoredIndex;
    _verseTallyMap.clear();
    if (snap.verseTallyMap != null && snap.verseTallyMap!.isNotEmpty) {
      _verseTallyMap.addAll(snap.verseTallyMap!);
    } else {
      for (int i = 0; i <= restoredIndex && i < _tasks.length; i++) {
        final t = _tasks[i];
        final count = i < restoredIndex ? t.targetRepetitions : t.currentProgress;
        for (final v in t.verseNumbers) {
          _verseTallyMap[v] = (_verseTallyMap[v] ?? 0) + count;
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Auto-save helper (private)
  // ---------------------------------------------------------------------------
  Future<void> _autoSave() async {
    try {
      if (_pendingResumeSnapshot != null) return;
      late ActiveSessionSnapshot snap;
      if (_sessionType == HifzSessionType.newVerses) {
        if (_tasks.isEmpty || isNewVersesSessionCompleted) return;
        var savedStepIdx = _currentTaskIndex.clamp(0, _tasks.length - 1);
        var savedTask = _tasks[savedStepIdx];
        var savedTally = savedTask.currentProgress;
        if (savedTally >= savedTask.targetRepetitions &&
            savedStepIdx + 1 < _tasks.length) {
          savedStepIdx += 1;
          savedTask = _tasks[savedStepIdx];
          savedTally = 0;
        }
        snap = ActiveSessionSnapshot(
          sessionId: _sessionId,
          sessionType: _sessionType,
          nvSurahNumber: _surahNumber,
          nvRepeatStart: _repeatStart,
          nvStartVerse: _startVerse,
          nvEndVerse: _endVerse,
          nvChunkLongVerses: _chunkLongVerses,
          currentTaskId: savedTask.id,
          currentVerse: savedTask.verseNumbers.isNotEmpty
              ? savedTask.verseNumbers.first
              : _startVerse,
          totalSteps: _tasks.length,
          verseTallyMap: _verseTallyMap.isEmpty
              ? null
              : Map<int, int>.from(_verseTallyMap),
          currentStepIndex: savedStepIdx,
          currentMode:
              savedTask.mode == TextVisibilityMode.hidden ? 'hidden' : 'visible',
          currentTally: savedTally,
          targetTally: savedTask.targetRepetitions,
          lastUpdatedTimestamp: DateTime.now().millisecondsSinceEpoch,
        );
      } else {
        if (_reviewSteps.isEmpty || isReviewSessionCompleted) return;
        var savedStepIdx = _reviewStepIndex.clamp(0, _reviewSteps.length - 1);
        var savedPhase = _reviewPhase;
        var savedTally = _reviewTally;
        if (savedTally >= _reviewTargetTally) {
          if (savedPhase == ReviewPhase.visible) {
            savedPhase = ReviewPhase.hidden;
            savedTally = 0;
          } else if (savedStepIdx + 1 < _reviewSteps.length) {
            savedStepIdx += 1;
            savedPhase = ReviewPhase.visible;
            savedTally = 0;
          }
        }
        final savedStepObj = _reviewSteps[savedStepIdx];
        final effectiveRevSurah = savedStepObj.surahNumber ??
            (_reviewGranularity == ReviewGranularity.bySurah
                ? savedStepObj.primaryIndex
                : _reviewTargetParams?.surahNumber);
        snap = ActiveSessionSnapshot(
          sessionId: _sessionId,
          sessionType: _sessionType,
          nvSurahNumber: effectiveRevSurah,
          currentVerse: savedStepObj.verseStart ?? 1,
          totalSteps: _reviewSteps.length,
          reviewGranularity: _reviewGranularity,
          reviewTargetParams: _reviewTargetParams,
          currentStepIndex: savedStepIdx,
          currentMode:
              savedPhase == ReviewPhase.hidden ? 'hidden' : 'visible',
          currentTally: savedTally,
          targetTally: _reviewTargetTally,
          lastUpdatedTimestamp: DateTime.now().millisecondsSinceEpoch,
        );
      }
      await _repo.saveActiveSession(snap);
    } catch (_) {
      // Never surface auto-save errors to the user.
    }
  }
}
