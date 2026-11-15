import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:onnxruntime_v2/onnxruntime_v2.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/recitation_event.dart';
import 'ctc_matcher.dart';
import 'tilawa_fbank.dart';

class ZipformerStateSpec {
  final String name;
  final List<int> shape;
  final String dtype;
  final int size;

  ZipformerStateSpec({
    required this.name,
    required this.shape,
    required this.dtype,
  }) : size = shape.reduce((a, b) => a * b);
}

class RecitationEngine {
  static final RecitationEngine _instance = RecitationEngine._internal();
  factory RecitationEngine() => _instance;
  RecitationEngine._internal();

  AudioRecorder? _audioRecorder;
  StreamSubscription<Uint8List>? _audioSubscription;
  OrtSession? _session;
  OrtSessionOptions? _sessionOptions;
  CtcMatcher? _matcher;

  final TilawaFbank _fbank = TilawaFbank();
  final List<Float32List> _fbankFeats = [];
  int _fbankConsumed = 0;
  int _fbankFrames = 0;
  int _window = 45;
  int _shift = 32;
  int _mels = 80;
  double _padValue = -23.0259;

  List<ZipformerStateSpec> _stateSpecs = [];
  final Map<String, OrtValue> _states = {};
  int _prevToken = 0;
  bool _carried = false;

  bool _isInitialized = false;
  bool _isListening = false;
  bool _isInferring = false;
  bool _isSearchMode = false;
  void Function(double audioLevel)? _onSearchAudioLevel;
  void Function(List<VerseSearchResult> results, String recognizedText)? _onSearchResults;

  int _currentSurah = 1;
  int _startAyah = 1;
  int _expectedAyah = 1;
  int _endAyah = 7;
  RecitationSensitivity _sensitivity = RecitationSensitivity.balanced;

  void Function(RecitationEvent)? _onEvent;

  RecitationSensitivity get sensitivity => _sensitivity;

  void setSensitivity(RecitationSensitivity sensitivity) {
    _sensitivity = sensitivity;
  }

  // Adaptive noise floor tracking
  bool _adaptiveNoise = true;
  double _ambientNoiseFloor = 0.008;
  int _calibrationFramesRemaining = 8;

  bool get adaptiveNoise => _adaptiveNoise;

  void setAdaptiveNoise(bool enabled) {
    _adaptiveNoise = enabled;
    if (!enabled) {
      _ambientNoiseFloor = _silenceThreshold;
    }
  }

  // Audio buffer & VAD parameters
  static const int _sampleRate = 16000;
  static const double _silenceThreshold = 0.012;
  static const int _silenceFramesNeeded = 3;
  static const int _searchSilenceFramesNeeded = 8;
  static const Duration _staleBufferResetDelay = Duration(seconds: 5);

  final List<int> _accumulatedTokens = [];
  int _trailingSilenceCount = 0;
  bool _speechActive = false;
  Timer? _staleBufferTimer;

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  int get currentExpectedAyah => _expectedAyah;
  int get fbankFrames => _fbankFrames;

  void _cancelStaleBufferTimer() {
    _staleBufferTimer?.cancel();
    _staleBufferTimer = null;
  }

  void _scheduleStaleBufferReset() {
    _cancelStaleBufferTimer();
    if (!_isListening || _accumulatedTokens.isEmpty) return;

    _staleBufferTimer = Timer(_staleBufferResetDelay, () {
      _staleBufferTimer = null;
      if (!_isListening ||
          _speechActive ||
          _isInferring ||
          _accumulatedTokens.isEmpty) {
        return;
      }
      _accumulatedTokens.clear();
      _trailingSilenceCount = 0;
      _onEvent?.call(const RecitationBufferClearedEvent());
    });
  }

  Future<File> _ensureModelFile(String assetPath) async {
    final directFile = File(assetPath);
    if (await directFile.exists()) {
      return directFile;
    }

    final dir = await getApplicationSupportDirectory();
    final fileName = assetPath.split('/').last;
    final cachedFile = File('${dir.path}/$fileName');

    final byteData = await rootBundle.load(assetPath);
    final assetLen = byteData.lengthInBytes;
    if (assetLen < 1000000) {
      throw StateError(
        'Model file "$assetPath" is corrupted or an unpulled Git LFS pointer ($assetLen bytes).',
      );
    }

    if (await cachedFile.exists()) {
      final len = await cachedFile.length();
      if (len == assetLen) {
        return cachedFile;
      }
    }

    debugPrint('[RecitationEngine] Extracting $assetPath to ${cachedFile.path}...');
    final buffer = byteData.buffer;
    await cachedFile.writeAsBytes(
      buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
      flush: true,
    );
    debugPrint('[RecitationEngine] Model extracted (${await cachedFile.length()} bytes)');
    return cachedFile;
  }

  /// Initializes ONNX Runtime, CtcMatcher, and loads Tilawa 1.0 streaming Zipformer2.
  Future<void> initialize({
    String modelPath = 'assets/models/spliced-clean-1-int8.onnx',
    String manifestPath = 'assets/models/models-v1.json',
    String refPath = 'assets/models/ref-v2.json',
    String phrasesPath = 'assets/models/phrases-v1.json',
    String? tokensPath,
    String? vocabPath,
  }) async {
    if (_isInitialized) return;

    try {
      // 1. Initialize ONNX environment
      OrtEnv.instance.init();

      // 2. Load CtcMatcher token dictionary and phoneme reference in background
      _matcher = await CtcMatcher.load(
        refPath: refPath,
        phrasesPath: phrasesPath,
        tokensPath: tokensPath,
        vocabPath: vocabPath,
      );

      // 3. Load full tier manifest from models-v1.json
      String manifestStr;
      try {
        manifestStr = await rootBundle.loadString(manifestPath);
      } catch (_) {
        final f = File(manifestPath);
        manifestStr = await f.readAsString();
      }

      final manifestJson = jsonDecode(manifestStr) as Map<String, dynamic>;
      final tiers = manifestJson['tiers'] as List;
      final fullTier = tiers.firstWhere(
        (t) => t['tier'] == 'full' || t['id'] == 'spliced-clean',
        orElse: () => tiers.first,
      ) as Map<String, dynamic>;
      final manifest = fullTier['manifest'] as Map<String, dynamic>;

      _window = (manifest['window'] as num?)?.toInt() ?? 45;
      _shift = (manifest['shift'] as num?)?.toInt() ?? 32;

      if (manifest['fbank'] is Map) {
        final fb = manifest['fbank'] as Map<String, dynamic>;
        _mels = (fb['mels'] as num?)?.toInt() ?? 80;
        _padValue = (fb['padValue'] as num?)?.toDouble() ?? -23.0259;
      }

      final rawStates = manifest['states'] as List;
      _stateSpecs = rawStates.map((s) {
        final m = s as Map<String, dynamic>;
        return ZipformerStateSpec(
          name: m['name'] as String,
          shape: (m['shape'] as List).map((e) => (e as num).toInt()).toList(),
          dtype: m['dtype'] as String,
        );
      }).toList();

      // 4. Ensure model file exists on disk
      final modelFile = await _ensureModelFile(modelPath);

      // 5. Configure Session Options
      _sessionOptions = OrtSessionOptions();
      _sessionOptions!.setIntraOpNumThreads(4);
      _sessionOptions!.setInterOpNumThreads(1);
      _sessionOptions!.setSessionGraphOptimizationLevel(
        GraphOptimizationLevel.ortEnableAll,
      );

      if (Platform.isWindows) {
        try {
          _sessionOptions!.appendDirectMLProvider();
        } catch (_) {}
      } else if (Platform.isIOS || Platform.isMacOS) {
        try {
          _sessionOptions!.appendCoreMLProvider(CoreMLFlags.useNone);
        } catch (_) {}
      }
      _sessionOptions!.appendCPUProvider(CPUFlags.useArena);

      // 6. Create Session
      try {
        _session = OrtSession.fromFile(modelFile, _sessionOptions!);
        debugPrint('[RecitationEngine] Initialized Zipformer2 session from file');
      } catch (e, st) {
        debugPrint('[RecitationEngine] fromFile accelerator error: $e\n$st. Retrying pure CPU...');
        _sessionOptions?.release();
        _sessionOptions = OrtSessionOptions();
        _sessionOptions!.setIntraOpNumThreads(4);
        _sessionOptions!.setInterOpNumThreads(1);
        _sessionOptions!.appendCPUProvider(CPUFlags.useArena);
        _session = OrtSession.fromFile(modelFile, _sessionOptions!);
      }

      _resetStreamingState();

      _audioRecorder = AudioRecorder();
      _isInitialized = true;
      debugPrint('[RecitationEngine] Initialized Tilawa 1.0 successfully');
    } catch (e, st) {
      debugPrint('[RecitationEngine] Init error: $e\n$st');
      rethrow;
    }
  }

  void _resetStreamingState() {
    for (final val in _states.values) {
      val.release();
    }
    _states.clear();

    for (final s in _stateSpecs) {
      if (s.dtype == 'int64') {
        _states[s.name] = OrtValueTensor.createTensorWithDataList(
          Int64List(s.size),
          s.shape,
        );
      } else {
        _states[s.name] = OrtValueTensor.createTensorWithDataList(
          Float32List(s.size),
          s.shape,
        );
      }
    }

    _fbank.reset();
    _fbankFeats.clear();
    _fbankConsumed = 0;
    _fbankFrames = 0;
    _prevToken = 0;
    _carried = false;
  }

  /// Runs one streaming 45-frame window and updates the 98 recurrent encoder states.
  Future<List<int>> _stepWindow(Float32List xData) async {
    if (_session == null || _states.isEmpty) return const [];

    final xTensor = OrtValueTensor.createTensorWithDataList(
      xData,
      [1, _window, _mels],
    );

    final runOptions = OrtRunOptions();
    final inputs = <String, OrtValue>{
      'x': xTensor,
      ..._states,
    };

    final outputs = await _session!.runAsync(runOptions, inputs);

    xTensor.release();
    runOptions.release();

    if (outputs == null || outputs.isEmpty) return const [];

    final outputMap = <String, OrtValue>{};
    for (int i = 0; i < _session!.outputNames.length; i++) {
      final name = _session!.outputNames[i];
      final val = outputs[i];
      if (val != null) {
        outputMap[name] = val;
      }
    }

    final logProbsOrt = outputMap['log_probs'];
    final emittedTokens = <int>[];

    if (logProbsOrt != null) {
      final val = logProbsOrt.value;
      if (val is List && val.isNotEmpty && val[0] is List) {
        final frames = val[0] as List;
        for (final frame in frames) {
          if (frame is List) {
            int maxIdx = 0;
            double maxVal = (frame[0] as num).toDouble();
            for (int i = 1; i < frame.length; i++) {
              final v = (frame[i] as num).toDouble();
              if (v > maxVal) {
                maxVal = v;
                maxIdx = i;
              }
            }

            if (maxIdx != 0 && maxIdx == _prevToken && _carried) {
              // Same token carried from previous window boundary
            } else if (maxIdx != 0 && maxIdx == _prevToken) {
              // Same token within current window
            } else if (maxIdx != 0) {
              emittedTokens.add(maxIdx);
              _carried = false;
            }

            if (maxIdx != _prevToken) {
              _carried = false;
            }
            _prevToken = maxIdx;
          }
        }
        if (_prevToken != 0) {
          _carried = true;
        }
      }
      logProbsOrt.release();
    }

    // Reuse native OrtValue output pointers directly without re-allocating
    for (final s in _stateSpecs) {
      final oldVal = _states[s.name];
      final newVal = outputMap['new_${s.name}'];
      if (newVal != null) {
        oldVal?.release();
        _states[s.name] = newVal;
      }
    }

    return emittedTokens;
  }

  /// Checks if microphone permission is granted.
  Future<bool> hasPermission() async {
    _audioRecorder ??= AudioRecorder();
    return await _audioRecorder!.hasPermission();
  }

  /// Starts listening and tracking recitation for a given surah range.
  Future<void> startListening({
    required int surah,
    required int startAyah,
    required int endAyah,
    int? initialExpectedAyah,
    bool? adaptiveNoise,
    required void Function(RecitationEvent) onEvent,
  }) async {
    if (_isListening) {
      await stopListening();
    }

    if (!_isInitialized) {
      await initialize();
    }

    final permitted = await hasPermission();
    if (!permitted) {
      const err = 'Microphone permission not granted';
      onEvent(const RecitationErrorEvent(err));
      throw Exception(err);
    }

    if (adaptiveNoise != null) {
      _adaptiveNoise = adaptiveNoise;
    }
    _ambientNoiseFloor = 0.008;
    _calibrationFramesRemaining = 8;

    _currentSurah = surah;
    _startAyah = startAyah;
    _expectedAyah = initialExpectedAyah ?? startAyah;
    _endAyah = endAyah;
    _onEvent = onEvent;

    _cancelStaleBufferTimer();
    _resetStreamingState();
    _accumulatedTokens.clear();
    _trailingSilenceCount = 0;
    _speechActive = false;

    _audioRecorder ??= AudioRecorder();

    try {
      final audioStream = await _audioRecorder!.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _sampleRate,
          numChannels: 1,
        ),
      );

      _isListening = true;
      _onEvent?.call(RecitationStatusEvent(
        status: RecitationStatus.listening,
        audioLevel: 0.0,
        currentExpectedAyah: _expectedAyah,
      ));

      _audioSubscription = audioStream.listen(
        _processAudioChunk,
        onError: (err) {
          debugPrint('[RecitationEngine] Audio stream error: $err');
          _onEvent?.call(RecitationErrorEvent(err.toString()));
        },
      );
    } catch (e) {
      debugPrint('[RecitationEngine] startStream error: $e');
      _onEvent?.call(RecitationErrorEvent('Failed to start audio stream: $e'));
      rethrow;
    }
  }

  /// Updates current expected Ayah.
  void setExpectedAyah(int ayah) {
    _expectedAyah = ayah;
    _cancelStaleBufferTimer();
    _accumulatedTokens.clear();
    _resetStreamingState();
    _onEvent?.call(RecitationStatusEvent(
      status: _isListening ? RecitationStatus.listening : RecitationStatus.idle,
      audioLevel: 0.0,
      currentExpectedAyah: _expectedAyah,
    ));
  }

  /// Updates active range for progressive tracking.
  void updateRange({int? surah, required int startAyah, required int endAyah, int? initialExpectedAyah}) {
    if (surah != null) _currentSurah = surah;
    _startAyah = startAyah;
    _expectedAyah = initialExpectedAyah ?? startAyah;
    _endAyah = endAyah;
    _cancelStaleBufferTimer();
    _accumulatedTokens.clear();
    _resetStreamingState();
    _onEvent?.call(RecitationStatusEvent(
      status: _isListening ? RecitationStatus.listening : RecitationStatus.idle,
      audioLevel: 0.0,
      currentExpectedAyah: _expectedAyah,
    ));
  }

  /// Searches for matching verses across the entire Quran.
  List<VerseSearchResult> searchVerses(List<int> candidateTokens, {int limit = 5, double minScore = 0.35}) {
    if (_matcher == null) return const [];
    return _matcher!.searchVerses(candidateTokens, limit: limit, minScore: minScore);
  }

  /// Starts listening for recitation search across the entire Quran.
  Future<void> startVoiceSearch({
    required void Function(double audioLevel) onAudioLevel,
    required void Function(List<VerseSearchResult> results, String recognizedText) onResults,
    required void Function(String error) onError,
    bool? adaptiveNoise,
  }) async {
    if (_isListening) {
      await stopListening();
    }

    if (!_isInitialized) {
      await initialize();
    }

    final permitted = await hasPermission();
    if (!permitted) {
      const err = 'Microphone permission not granted';
      onError(err);
      throw Exception(err);
    }

    if (adaptiveNoise != null) {
      _adaptiveNoise = adaptiveNoise;
    }
    _ambientNoiseFloor = 0.008;
    _calibrationFramesRemaining = 8;
    _isSearchMode = true;
    _onSearchAudioLevel = onAudioLevel;
    _onSearchResults = onResults;

    _cancelStaleBufferTimer();
    _resetStreamingState();
    _accumulatedTokens.clear();
    _trailingSilenceCount = 0;
    _speechActive = false;

    _audioRecorder ??= AudioRecorder();

    try {
      final audioStream = await _audioRecorder!.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _sampleRate,
          numChannels: 1,
        ),
      );

      _isListening = true;

      _audioSubscription = audioStream.listen(
        _processAudioChunk,
        onError: (err) {
          debugPrint('[RecitationEngine] Audio stream error: $err');
          onError(err.toString());
        },
      );
    } catch (e) {
      debugPrint('[RecitationEngine] startVoiceSearch error: $e');
      onError('Failed to start audio stream: $e');
      rethrow;
    }
  }

  /// Stops listening and releases active audio stream.
  Future<void> stopListening() async {
    _isListening = false;
    _speechActive = false;
    _isSearchMode = false;
    _onSearchAudioLevel = null;
    _onSearchResults = null;
    _trailingSilenceCount = 0;
    _cancelStaleBufferTimer();

    await _audioSubscription?.cancel();
    _audioSubscription = null;

    if (_audioRecorder != null) {
      final rec = _audioRecorder;
      _audioRecorder = null;
      try {
        await rec?.stop().timeout(const Duration(milliseconds: 500), onTimeout: () => null);
      } catch (_) {}
      try {
        await rec?.dispose().timeout(const Duration(milliseconds: 500), onTimeout: () => null);
      } catch (_) {}
    }

    _resetStreamingState();
    _accumulatedTokens.clear();

    _onEvent?.call(RecitationStatusEvent(
      status: RecitationStatus.idle,
      audioLevel: 0.0,
      currentExpectedAyah: _expectedAyah,
    ));
  }

  /// Processes incoming PCM 16-bit chunks from microphone.
  void _processAudioChunk(Uint8List pcmChunk) {
    if (!_isListening || pcmChunk.isEmpty) return;

    final numSamples = pcmChunk.length ~/ 2;
    if (numSamples == 0) return;

    final byteData = ByteData.sublistView(pcmChunk);
    final samples = Float32List(numSamples);
    double sumSquares = 0.0;

    for (int i = 0; i < numSamples; i++) {
      final sampleInt = byteData.getInt16(i * 2, Endian.little);
      final s = sampleInt / 32768.0;
      samples[i] = s;
      sumSquares += s * s;
    }

    final rms = math.sqrt(sumSquares / numSamples);

    if (_adaptiveNoise && _calibrationFramesRemaining > 0) {
      _calibrationFramesRemaining--;
      if (rms > 0.002 && rms < 0.050) {
        _ambientNoiseFloor = (_ambientNoiseFloor * 0.7) + (rms * 0.3);
      }
    }

    final double effectiveThreshold;
    if (_adaptiveNoise) {
      effectiveThreshold = (_ambientNoiseFloor * 1.75).clamp(0.010, 0.045);
      if (!_speechActive && rms < _ambientNoiseFloor * 1.5 && rms > 0.002) {
        _ambientNoiseFloor = (_ambientNoiseFloor * 0.95) + (rms * 0.05);
        _ambientNoiseFloor = _ambientNoiseFloor.clamp(0.005, 0.035);
      }
    } else {
      effectiveThreshold = _silenceThreshold;
    }

    final isVoice = rms > effectiveThreshold;
    final level = _adaptiveNoise
        ? math.min(1.0, math.max(0.0, rms - _ambientNoiseFloor) * 15.0)
        : math.min(1.0, rms * 15.0);

    if (isVoice) {
      _cancelStaleBufferTimer();
      _speechActive = true;
      _trailingSilenceCount = 0;

      if (_isSearchMode) {
        _onSearchAudioLevel?.call(level);
      } else {
        _onEvent?.call(RecitationStatusEvent(
          status: RecitationStatus.listening,
          audioLevel: level,
          currentExpectedAyah: _expectedAyah,
        ));
      }

      final frames = _fbank.push(samples);
      _fbankFeats.addAll(frames);
      _fbankFrames += frames.length;

      if (!_isInferring) {
        _drainStreamingWindows();
      }
    } else {
      if (_speechActive) {
        _trailingSilenceCount++;
        final frames = _fbank.push(samples);
        _fbankFeats.addAll(frames);
        _fbankFrames += frames.length;

        if (!_isInferring) {
          _drainStreamingWindows();
        }

        final silenceTarget =
            _isSearchMode ? _searchSilenceFramesNeeded : _silenceFramesNeeded;

        if (_trailingSilenceCount >= silenceTarget && !_isInferring) {
          _speechActive = false;
          _flushTrailingSilence();
        }
      } else if (_isSearchMode) {
        _onSearchAudioLevel?.call(0.0);
      }
    }
  }

  /// Drains all available 45-frame windows advancing by shift (32 frames = 320ms).
  Future<void> _drainStreamingWindows() async {
    if (_isInferring || _session == null || _matcher == null) return;
    _isInferring = true;

    try {
      while (_fbankFeats.length - _fbankConsumed >= _window && _isListening) {
        final windowFrames = _fbankFeats.sublist(_fbankConsumed, _fbankConsumed + _window);
        final xData = Float32List(_window * _mels);
        for (int i = 0; i < _window; i++) {
          xData.setRange(i * _mels, (i + 1) * _mels, windowFrames[i]);
        }
        final windowTokens = await _stepWindow(xData);
        _fbankConsumed += _shift;
        if (windowTokens.isNotEmpty) {
          await _handleNewTokens(windowTokens, isFlush: false);
        }
      }

      if (_fbankConsumed > 4 * _window) {
        _fbankFeats.removeRange(0, _fbankConsumed);
        _fbankConsumed = 0;
      }
    } catch (e, st) {
      debugPrint('[RecitationEngine] Streaming inference error: $e\n$st');
    } finally {
      _isInferring = false;
      if (_isListening) {
        _onEvent?.call(RecitationStatusEvent(
          status: RecitationStatus.listening,
          audioLevel: 0.0,
          currentExpectedAyah: _expectedAyah,
        ));
      }
      _scheduleStaleBufferReset();
    }
  }

  /// When trailing silence is reached, pads the remaining fbank frames with padValue (-23.0259)
  /// so that the final word of the verse is immediately recognized without delay.
  Future<void> _flushTrailingSilence() async {
    if (_isInferring || _session == null || _matcher == null) return;
    _isInferring = true;

    try {
      final padFrame = Float32List(_mels)..fillRange(0, _mels, _padValue);
      while (_fbankFeats.length - _fbankConsumed < _window) {
        _fbankFeats.add(padFrame);
      }
      final windowFrames = _fbankFeats.sublist(_fbankConsumed, _fbankConsumed + _window);
      final xData = Float32List(_window * _mels);
      for (int i = 0; i < _window; i++) {
        xData.setRange(i * _mels, (i + 1) * _mels, windowFrames[i]);
      }
      final windowTokens = await _stepWindow(xData);
      _fbankConsumed += _shift;
      if (windowTokens.isNotEmpty || _accumulatedTokens.isNotEmpty) {
        await _handleNewTokens(windowTokens, isFlush: true);
      }
    } catch (e, st) {
      debugPrint('[RecitationEngine] Flush error: $e\n$st');
    } finally {
      _isInferring = false;
      if (_isListening) {
        _onEvent?.call(RecitationStatusEvent(
          status: RecitationStatus.listening,
          audioLevel: 0.0,
          currentExpectedAyah: _expectedAyah,
        ));
      }
      _scheduleStaleBufferReset();
    }
  }

  /// Processes new emitted tokens from the Zipformer CTC decoder.
  Future<void> _handleNewTokens(List<int> tokens, {bool isFlush = false}) async {
    _accumulatedTokens.addAll(tokens);
    final activeText = _matcher!.tokensToReadableText(_accumulatedTokens);

    debugPrint('[RecitationEngine] Emitted: $tokens -> "$activeText" (flush: $isFlush)');

    if (_isSearchMode) {
      final cleanText = activeText.trim();
      if (!isFlush) {
        if (cleanText.isNotEmpty) {
          _onSearchResults?.call(const [], cleanText);
        }
        return;
      }

      if (_accumulatedTokens.length < 5) {
        if (cleanText.isNotEmpty) {
          _onSearchResults?.call(const [], cleanText);
        }
        return;
      }

      final results = _matcher!.searchVerses(_accumulatedTokens, limit: 5);
      final cb = _onSearchResults;
      if (results.isNotEmpty) {
        final recognizedText = results.first.text.isNotEmpty
            ? results.first.text
            : cleanText;
        await stopListening();
        cb?.call(results, recognizedText);
      } else {
        cb?.call(const [], cleanText);
      }
      return;
    }

    if (_isListening && activeText.isNotEmpty) {
      _onEvent?.call(RecitationStatusEvent(
        status: RecitationStatus.processing,
        audioLevel: 0.0,
        currentExpectedAyah: _expectedAyah,
        partialTranscript: activeText,
      ));
    }

    // Cascading match loop: continuously match consecutive verses in the active window
    while (_expectedAyah <= _endAyah && _accumulatedTokens.isNotEmpty) {
      final match = _matcher!.matchSlidingWindow(
        surah: _currentSurah,
        expectedAyah: _expectedAyah,
        candidateTokens: _accumulatedTokens,
        windowAhead: 2,
        windowBehind: 1,
        minAyah: _startAyah,
        maxAyah: _endAyah,
        sensitivity: _sensitivity,
        requireLastWord: false,
      );

      if (match == null) {
        break;
      }

      if (match.isSkip) {
        debugPrint('[RecitationEngine] SKIP DETECTED from ${match.expectedAyah} to ${match.detectedAyah}');
        _onEvent?.call(RecitationSkippedEvent(
          surah: match.surah,
          expectedAyah: match.expectedAyah,
          jumpedToAyah: match.detectedAyah,
          confidence: match.confidence,
        ));
        _accumulatedTokens.clear();
        break;
      }

      debugPrint('[RecitationEngine] REVEAL Matched Ayah ${match.detectedAyah} (conf: ${match.confidence.toStringAsFixed(2)})');
      _expectedAyah = math.max(_expectedAyah, match.detectedAyah + 1);

      _onEvent?.call(RecitationMatchedEvent(
        surah: match.surah,
        ayah: match.detectedAyah,
        confidence: match.confidence,
        text: match.decodedText,
      ));

      if (match.tokensConsumed > 0 && (_accumulatedTokens.length - match.tokensConsumed) >= 5) {
        _accumulatedTokens.removeRange(0, match.tokensConsumed);
      } else {
        _accumulatedTokens.clear();
        break;
      }
    }

    final expectedTokensLen = _matcher?.getTargetTokens(_currentSurah, _expectedAyah)?.length ?? 40;
    final maxBuffer = math.max(100, (expectedTokensLen * 1.8).round());
    if (_accumulatedTokens.length > maxBuffer) {
      _accumulatedTokens.removeRange(0, _accumulatedTokens.length - expectedTokensLen);
    }
  }

  /// Disposes resources.
  void dispose() {
    stopListening();
    for (final s in _states.values) {
      s.release();
    }
    _states.clear();
    _session?.release();
    _sessionOptions?.release();
    OrtEnv.instance.release();
    _audioRecorder?.dispose();
    _isInitialized = false;
  }
}
