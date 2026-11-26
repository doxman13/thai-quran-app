import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:onnxruntime_v2/onnxruntime_v2.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/recitation_event.dart';
import 'ctc_matcher.dart';
import 'tilawa_fbank.dart';

Future<int> _createOrtSessionInIsolate(
  String modelPath, {
  required bool useDirectML,
}) {
  return Isolate.run(() {
    OrtEnv.instance.init();
    final opts = OrtSessionOptions()
      ..setIntraOpNumThreads(4)
      ..setInterOpNumThreads(1)
      ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);

    if (useDirectML) {
      try {
        opts.appendDirectMLProvider();
      } catch (_) {}
    }
    opts.appendCPUProvider(CPUFlags.useArena);

    try {
      final session = OrtSession.fromFile(File(modelPath), opts);
      final address = session.address;
      opts.release();
      return address;
    } catch (_) {
      opts.release();
      if (!useDirectML) rethrow;
      final fallbackOpts = OrtSessionOptions()
        ..setIntraOpNumThreads(4)
        ..setInterOpNumThreads(1)
        ..appendCPUProvider(CPUFlags.useArena);
      try {
        final session = OrtSession.fromFile(File(modelPath), fallbackOpts);
        return session.address;
      } finally {
        fallbackOpts.release();
      }
    }
  });
}

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
  Future<void>? _initFuture;
  bool _isListening = false;
  bool _isInferring = false;
  bool _pendingFlush = false;
  bool _pendingSearchStop = false;
  bool _suppressSearchAutoStop = false;
  bool _isSearchMode = false;
  int _listenOpSeq = 0;
  Future<void>? _stopFuture;
  Future<void>? _inferenceFuture;
  void Function(double audioLevel)? _onSearchAudioLevel;
  void Function(List<VerseSearchResult> results, String recognizedText)? _onSearchResults;
  void Function(String recognizedText)? _onSearchNoMatch;

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

  // Adaptive Log-dB noise floor & soft input gain tracking
  bool _adaptiveNoise = true;
  double _floorDb = -49.12; // ~0.0035 RMS initial baseline
  int _calibrationFramesRemaining = 4;
  double _inputGain = 1.0;
  double _speechPeakDb = -120.0;
  int _samplesSinceLastToken = 0;
  int _flushCountForTest = 0;

  bool get adaptiveNoise => _adaptiveNoise;

  void setAdaptiveNoise(bool enabled) {
    _adaptiveNoise = enabled;
    if (!enabled) {
      _floorDb = _fixedVadThresholdDb;
    }
  }

  // Audio buffer & VAD parameters
  static const int _sampleRate = 16000;
  static const double _fixedVadThresholdDb = -43.1; // ~0.007 RMS when adaptiveNoise == false
  static const double _vadMarginDb = 5.5; // ~1.88x RMS above ambient noise floor
  static const double _iosGainOffsetDb = 6.85; // 20 * log10(2.2) base iOS profile offset
  static const int _silenceSamplesNeeded = 3840; // 240ms at 16 kHz
  static const int _searchSilenceSamplesNeeded = 8800; // 550ms at 16 kHz
  static const int _hifzNoTokenFlushSamples = 8800; // 550ms without new tokens (Hifz)
  static const int _searchNoTokenFlushSamples = 12800; // 800ms without new tokens (Search)
  static const int _maxPreSpeechSamples = 12800; // 800ms pre-speech lookback
  static const int _leadingSilenceSamples = 1600; // 100ms lead-in if speech starts immediately
  static const Duration _staleBufferResetDelay = Duration(seconds: 5);

  static double _meanSqToDb(double meanSq) {
    return 10.0 * math.log(meanSq + 1e-12) / math.ln10;
  }

  static double _dbToRms(double db) {
    return math.pow(10.0, db / 20.0).toDouble();
  }

  final List<int> _accumulatedTokens = [];
  final List<Float32List> _preSpeechChunks = [];
  int _preSpeechSamplesCount = 0;
  int _trailingSilenceSamples = 0;
  bool _speechActive = false;
  Timer? _staleBufferTimer;
  DateTime? _firstTokenInBufferTime;
  Completer<void>? _firstAudioChunkCompleter;

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  int get currentExpectedAyah => _expectedAyah;
  int get fbankFrames => _fbankFrames;

  @visibleForTesting
  int get preSpeechBufferSampleCountForTest => _preSpeechSamplesCount;

  @visibleForTesting
  bool get isSpeechActiveForTest => _speechActive;

  @visibleForTesting
  double get ambientNoiseFloorForTest => _dbToRms(_floorDb);

  @visibleForTesting
  double get effectiveThresholdForTest => _dbToRms(_effectiveVadThresholdDb());

  @visibleForTesting
  int get flushCountForTest => _flushCountForTest;

  @visibleForTesting
  void setListeningForTest(bool listening, {bool isIosProfile = false}) {
    _isListening = listening;
    _flushCountForTest = 0;
    _resetVadAndNoiseCalibration(resetNoiseAndGain: true, isIosProfile: isIosProfile);
    _fbank.reset();
    _fbankFeats.clear();
    _fbankConsumed = 0;
    _fbankFrames = 0;
    _accumulatedTokens.clear();
  }

  @visibleForTesting
  void seedAccumulatedTokensForTest(List<int> tokens) {
    _accumulatedTokens
      ..clear()
      ..addAll(tokens);
    _samplesSinceLastToken = 0;
  }

  @visibleForTesting
  void processAudioChunkForTest(Uint8List pcmChunk, {bool isIosProfile = false}) {
    _processAudioChunkInternal(pcmChunk, isIosProfile: isIosProfile);
  }

  @visibleForTesting
  int get accumulatedTokenCountForTest => _accumulatedTokens.length;

  @visibleForTesting
  int get listenOpSeqForTest => _listenOpSeq;

  @visibleForTesting
  void setSearchModeForTest({
    required CtcMatcher matcher,
    void Function(double audioLevel)? onAudioLevel,
    void Function(List<VerseSearchResult> results, String recognizedText)? onResults,
    void Function(String recognizedText)? onNoMatch,
    bool isIosProfile = true,
  }) {
    _matcher = matcher;
    _isListening = true;
    _isSearchMode = true;
    _onSearchAudioLevel = onAudioLevel;
    _onSearchResults = onResults;
    _onSearchNoMatch = onNoMatch;
    _resetVadAndNoiseCalibration(resetNoiseAndGain: true, isIosProfile: isIosProfile);
    _fbank.reset();
    _fbankFeats.clear();
    _fbankConsumed = 0;
    _fbankFrames = 0;
    _accumulatedTokens.clear();
  }

  @visibleForTesting
  Future<void> processSearchTokensForTest(List<int> tokens, {required bool isFlush}) async {
    await _handleNewTokens(tokens, isFlush: isFlush);
  }

  void _cancelStaleBufferTimer() {
    _staleBufferTimer?.cancel();
    _staleBufferTimer = null;
  }

  void _scheduleStaleBufferReset() {
    _cancelStaleBufferTimer();
    if (!_isListening || _accumulatedTokens.isEmpty) return;

    final delay = _isSearchMode
        ? const Duration(milliseconds: 2500)
        : _staleBufferResetDelay;
    _staleBufferTimer = Timer(delay, () {
      _staleBufferTimer = null;
      if (!_isListening ||
          _speechActive ||
          _isInferring ||
          _accumulatedTokens.isEmpty) {
        return;
      }
      _accumulatedTokens.clear();
      _firstTokenInBufferTime = null;
      _trailingSilenceSamples = 0;
      if (!_isSearchMode) {
        _onEvent?.call(const RecitationBufferClearedEvent());
      }
    });
  }

  Future<File> _ensureModelFile(String assetPath, {int? expectedBytes}) async {
    final directFile = File(assetPath);
    if (await directFile.exists()) {
      return directFile;
    }

    final dir = await getApplicationSupportDirectory();
    final fileName = assetPath.split('/').last;
    final cachedFile = File('${dir.path}/$fileName');

    if (expectedBytes != null &&
        expectedBytes >= 1000000 &&
        await cachedFile.exists() &&
        await cachedFile.length() == expectedBytes) {
      return cachedFile;
    }

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
    final bytes = byteData.buffer.asUint8List(byteData.offsetInBytes, assetLen);
    final raf = await cachedFile.open(mode: FileMode.write);
    try {
      const chunkSize = 2 * 1024 * 1024;
      for (int offset = 0; offset < bytes.length; offset += chunkSize) {
        final end = math.min(offset + chunkSize, bytes.length);
        await raf.writeFrom(bytes, offset, end);
      }
      await raf.flush();
    } finally {
      await raf.close();
    }
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
    if (_initFuture != null) {
      await _initFuture;
      return;
    }

    final future = _performInitialize(
      modelPath: modelPath,
      manifestPath: manifestPath,
      refPath: refPath,
      phrasesPath: phrasesPath,
      tokensPath: tokensPath,
      vocabPath: vocabPath,
    );
    _initFuture = future;
    try {
      await future;
    } finally {
      if (identical(_initFuture, future)) {
        _initFuture = null;
      }
    }
  }

  Future<void> _performInitialize({
    required String modelPath,
    required String manifestPath,
    required String refPath,
    required String phrasesPath,
    String? tokensPath,
    String? vocabPath,
  }) async {
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
      final expectedBytes = (fullTier['bytes'] as num?)?.toInt();
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

      // 4. Ensure model file exists on disk without reading 65 MB when already cached
      final modelFile = await _ensureModelFile(modelPath, expectedBytes: expectedBytes);

      // 5. Create ONNX session off the main UI isolate on CPU EP (avoids iOS CoreML UI freeze)
      final sessionAddress = await _createOrtSessionInIsolate(
        modelFile.path,
        useDirectML: Platform.isWindows,
      );
      _session = OrtSession.fromAddress(sessionAddress);
      debugPrint('[RecitationEngine] Initialized Zipformer2 session off main isolate');

      _resetStreamingState();

      // 6. Pre-warm persistent inference isolate with 1 silent window so Word 1 has zero startup lag
      try {
        final warmupInput = Float32List(_window * _mels)
          ..fillRange(0, _window * _mels, _padValue);
        await _stepWindow(warmupInput);
        _resetStreamingState();
      } catch (e) {
        debugPrint('[RecitationEngine] Warmup window skipped: $e');
        _resetStreamingState();
      }

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

  double _effectiveVadThresholdDb() {
    if (_adaptiveNoise) {
      return (_floorDb + _vadMarginDb).clamp(-44.4, -22.0);
    }
    return _fixedVadThresholdDb;
  }

  void _resetVadAndNoiseCalibration({
    bool resetNoiseAndGain = true,
    bool? isIosProfile,
  }) {
    final ios = isIosProfile ?? (!kIsWeb && Platform.isIOS);
    if (resetNoiseAndGain) {
      _floorDb = -49.12;
      _calibrationFramesRemaining = 4;
      _inputGain = ios ? 2.2 : 1.0;
    } else {
      // Keep learned gain and ambient floor across consecutive verses/rounds,
      // just allow a brief 2-chunk re-check without disrupting onset detection.
      _calibrationFramesRemaining = 2;
    }
    _speechPeakDb = -120.0;
    _samplesSinceLastToken = 0;
    _trailingSilenceSamples = 0;
    _pendingFlush = false;
    _speechActive = false;
    _preSpeechChunks.clear();
    _preSpeechSamplesCount = 0;
  }

  void _pushSamplesToFbank(Float32List samples) {
    final frames = _fbank.push(samples);
    if (frames.isNotEmpty) {
      _fbankFeats.addAll(frames);
      _fbankFrames += frames.length;
    }
  }

  void _enqueuePreSpeech(Float32List samples) {
    _preSpeechChunks.add(samples);
    _preSpeechSamplesCount += samples.length;
    while (_preSpeechChunks.length > 1 &&
        _preSpeechSamplesCount - _preSpeechChunks.first.length >= _maxPreSpeechSamples) {
      final removed = _preSpeechChunks.removeAt(0);
      _preSpeechSamplesCount -= removed.length;
    }
  }

  void _flushPreSpeechToFbank() {
    if (_fbankFrames == 0 && _preSpeechSamplesCount < _leadingSilenceSamples) {
      final leadInLen = _leadingSilenceSamples - _preSpeechSamplesCount;
      _pushSamplesToFbank(Float32List(leadInLen));
    }
    for (final chunk in _preSpeechChunks) {
      _pushSamplesToFbank(chunk);
    }
    _preSpeechChunks.clear();
    _preSpeechSamplesCount = 0;
  }

  Future<bool> _prepareAudioSessionForStart(
    int opSeq, {
    required void Function(String err) onPermissionError,
  }) async {
    if (_stopFuture != null) {
      await _stopFuture;
      if (opSeq != _listenOpSeq) return false;
    }

    if (_isListening) {
      await _runSerializedStop();
      if (opSeq != _listenOpSeq) return false;
    }

    if (_inferenceFuture != null) {
      try {
        await _inferenceFuture;
      } catch (_) {}
      if (opSeq != _listenOpSeq) return false;
    }

    if (!_isInitialized) {
      await initialize();
      if (opSeq != _listenOpSeq) return false;
    }

    final permitted = await hasPermission();
    if (opSeq != _listenOpSeq) return false;
    if (!permitted) {
      const err = 'Microphone permission not granted';
      onPermissionError(err);
      throw Exception(err);
    }

    return true;
  }

  Future<void> _openAudioStream(
    int opSeq, {
    required void Function(String err) onStreamError,
  }) async {
    _audioRecorder ??= AudioRecorder();

    try {
      final audioStream = await _audioRecorder!.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _sampleRate,
          numChannels: 1,
        ),
      );

      if (opSeq != _listenOpSeq) {
        await _runSerializedStop();
        return;
      }

      _isListening = true;
      _firstAudioChunkCompleter = Completer<void>();
      _audioSubscription = audioStream.listen(
        _processAudioChunk,
        onError: (err) {
          debugPrint('[RecitationEngine] Audio stream error: $err');
          onStreamError(err.toString());
        },
      );

      try {
        await _firstAudioChunkCompleter!.future.timeout(const Duration(milliseconds: 700));
      } catch (_) {}
      _firstAudioChunkCompleter = null;

      if (opSeq != _listenOpSeq) {
        await _runSerializedStop();
      }
    } catch (e) {
      await _stopAudioStreamAndRecorder();
      rethrow;
    }
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
    final opSeq = ++_listenOpSeq;
    final ready = await _prepareAudioSessionForStart(
      opSeq,
      onPermissionError: (err) => onEvent(RecitationErrorEvent(err)),
    );
    if (!ready) return;

    if (adaptiveNoise != null) {
      _adaptiveNoise = adaptiveNoise;
    }

    _isSearchMode = false;
    _onSearchAudioLevel = null;
    _onSearchResults = null;
    _onSearchNoMatch = null;
    _pendingSearchStop = false;
    _suppressSearchAutoStop = false;
    _currentSurah = surah;
    _startAyah = startAyah;
    _expectedAyah = initialExpectedAyah ?? startAyah;
    _endAyah = endAyah;
    _onEvent = onEvent;

    _cancelStaleBufferTimer();
    _resetStreamingState();
    _accumulatedTokens.clear();
    _firstTokenInBufferTime = null;
    _resetVadAndNoiseCalibration(resetNoiseAndGain: true);

    try {
      await _openAudioStream(
        opSeq,
        onStreamError: (err) => _onEvent?.call(RecitationErrorEvent(err)),
      );
      if (opSeq != _listenOpSeq || !_isListening) return;

      _onEvent?.call(RecitationStatusEvent(
        status: RecitationStatus.listening,
        audioLevel: 0.0,
        currentExpectedAyah: _expectedAyah,
      ));
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
    _firstTokenInBufferTime = null;
    _resetStreamingState();
    _resetVadAndNoiseCalibration(resetNoiseAndGain: false);
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
    _firstTokenInBufferTime = null;
    _resetStreamingState();
    _resetVadAndNoiseCalibration(resetNoiseAndGain: false);
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
    void Function(String recognizedText)? onNoMatch,
    bool? adaptiveNoise,
  }) async {
    final opSeq = ++_listenOpSeq;
    final ready = await _prepareAudioSessionForStart(
      opSeq,
      onPermissionError: onError,
    );
    if (!ready) return;

    if (adaptiveNoise != null) {
      _adaptiveNoise = adaptiveNoise;
    }
    _isSearchMode = true;
    _onEvent = null;
    _pendingSearchStop = false;
    _suppressSearchAutoStop = false;
    _onSearchAudioLevel = onAudioLevel;
    _onSearchResults = onResults;
    _onSearchNoMatch = onNoMatch;

    _cancelStaleBufferTimer();
    _resetStreamingState();
    _accumulatedTokens.clear();
    _firstTokenInBufferTime = null;
    _resetVadAndNoiseCalibration(resetNoiseAndGain: true);

    try {
      await _openAudioStream(
        opSeq,
        onStreamError: onError,
      );
    } catch (e) {
      debugPrint('[RecitationEngine] startVoiceSearch error: $e');
      onError('Failed to start audio stream: $e');
      rethrow;
    }
  }

  /// Stops mic capture in voice search mode and flushes buffered speech
  /// so manually stopping search evaluates the spoken phrase before closing.
  Future<void> finishVoiceSearch() async {
    if (!_isListening || !_isSearchMode) {
      await stopListening();
      return;
    }

    final opSeq = _listenOpSeq;
    _pendingFlush = false;
    _cancelStaleBufferTimer();
    if (_firstAudioChunkCompleter != null && !_firstAudioChunkCompleter!.isCompleted) {
      _firstAudioChunkCompleter!.complete();
    }
    _firstAudioChunkCompleter = null;

    await _stopAudioStreamAndRecorder();
    if (opSeq != _listenOpSeq) {
      await stopListening();
      return;
    }

    if (!_speechActive && _fbankFrames == 0 && _preSpeechChunks.isNotEmpty) {
      _flushPreSpeechToFbank();
    }

    final inFlight = _inferenceFuture;
    if (inFlight != null) {
      await inFlight;
    }
    if (opSeq != _listenOpSeq) {
      await stopListening();
      return;
    }

    final cb = _onSearchResults;
    _suppressSearchAutoStop = true;
    try {
      if (_session != null && _matcher != null && _fbankConsumed < _fbankFeats.length) {
        _isInferring = true;
        final flushTokens = <int>[];
        try {
          flushTokens.addAll(await _stepUnconsumedWithPadding());
        } finally {
          _isInferring = false;
        }
        if (opSeq == _listenOpSeq) {
          if (flushTokens.isNotEmpty || _accumulatedTokens.isNotEmpty) {
            await _handleNewTokens(flushTokens, isFlush: true);
          } else {
            cb?.call(const [], '');
          }
        }
      } else if (opSeq == _listenOpSeq && _matcher != null && _accumulatedTokens.isNotEmpty) {
        await _handleNewTokens(const [], isFlush: true);
      } else if (opSeq == _listenOpSeq) {
        cb?.call(const [], '');
      }
    } finally {
      _suppressSearchAutoStop = false;
    }

    if (opSeq == _listenOpSeq && (_isListening || _isSearchMode)) {
      await stopListening();
    }
  }

  Future<void> _stopAudioStreamAndRecorder() async {
    await _audioSubscription?.cancel();
    _audioSubscription = null;

    final rec = _audioRecorder;
    if (rec != null) {
      _audioRecorder = null;
      try {
        await rec.stop().timeout(const Duration(milliseconds: 500), onTimeout: () => null);
      } catch (_) {}
      try {
        await rec.dispose().timeout(const Duration(milliseconds: 500), onTimeout: () => null);
      } catch (_) {}
    }
  }

  Future<void> _runSerializedStop() async {
    if (_stopFuture != null) {
      await _stopFuture;
      return;
    }

    final future = _performStopListening();
    _stopFuture = future;
    try {
      await future;
    } finally {
      if (identical(_stopFuture, future)) {
        _stopFuture = null;
      }
    }
  }

  /// Stops listening and releases active audio stream.
  Future<void> stopListening() async {
    _listenOpSeq++;
    await _runSerializedStop();
  }

  Future<void> _performStopListening() async {
    _isListening = false;
    _speechActive = false;
    _pendingFlush = false;
    _pendingSearchStop = false;
    _suppressSearchAutoStop = false;
    _isSearchMode = false;
    _onSearchAudioLevel = null;
    _onSearchResults = null;
    _onSearchNoMatch = null;
    _trailingSilenceSamples = 0;
    _speechPeakDb = -120.0;
    _samplesSinceLastToken = 0;
    _preSpeechChunks.clear();
    _preSpeechSamplesCount = 0;
    if (_firstAudioChunkCompleter != null && !_firstAudioChunkCompleter!.isCompleted) {
      _firstAudioChunkCompleter!.complete();
    }
    _firstAudioChunkCompleter = null;
    _cancelStaleBufferTimer();

    await _stopAudioStreamAndRecorder();

    _resetStreamingState();
    _accumulatedTokens.clear();
    _firstTokenInBufferTime = null;

    _onEvent?.call(RecitationStatusEvent(
      status: RecitationStatus.idle,
      audioLevel: 0.0,
      currentExpectedAyah: _expectedAyah,
    ));
  }

  /// Processes incoming PCM 16-bit chunks from microphone.
  void _processAudioChunk(Uint8List pcmChunk) {
    _processAudioChunkInternal(pcmChunk, isIosProfile: !kIsWeb && Platform.isIOS);
  }

  void _processAudioChunkInternal(Uint8List pcmChunk, {required bool isIosProfile}) {
    if (!_isListening || pcmChunk.isEmpty) return;
    if (_firstAudioChunkCompleter != null && !_firstAudioChunkCompleter!.isCompleted) {
      _firstAudioChunkCompleter!.complete();
    }

    final numSamples = pcmChunk.length ~/ 2;
    if (numSamples == 0) return;

    final byteData = ByteData.sublistView(pcmChunk);
    final samples = Float32List(numSamples);
    double rawSumSquares = 0.0;
    double rawPeak = 0.0;

    for (int i = 0; i < numSamples; i++) {
      final sampleInt = byteData.getInt16(i * 2, Endian.little);
      final s = sampleInt / 32768.0;
      samples[i] = s;
      rawSumSquares += s * s;
      final absVal = s.abs();
      if (absVal > rawPeak) rawPeak = absVal;
    }

    final rawMeanSq = rawSumSquares / numSamples;
    final rawRms = math.sqrt(rawMeanSq);
    if (isIosProfile) {
      const baseGain = 1.8;
      const maxGain = 2.8;
      double nextGain = _inputGain;

      if (rawPeak * _inputGain > 0.85) {
        nextGain = (0.85 / rawPeak).clamp(1.0, maxGain);
      } else if (rawRms > 0.003) {
        final targetGain = (0.18 / math.max(rawPeak, 0.05)).clamp(baseGain, maxGain);
        nextGain = (_inputGain * 0.88) + (targetGain * 0.12);
      } else if (!_speechActive) {
        nextGain = (_inputGain * 0.94) + (2.2 * 0.06);
      }

      final prevGain = _inputGain;
      final gainStep = numSamples > 1 ? (nextGain - prevGain) / numSamples : 0.0;
      for (int i = 0; i < numSamples; i++) {
        final g = prevGain + (gainStep * i);
        samples[i] = (samples[i] * g).clamp(-1.0, 1.0);
      }
      _inputGain = nextGain;
    }

    // Measure VAD energy in gain-invariant Log-dB (anchored to base iOS profile offset)
    // so variable anti-clipping gain shifts never push room hiss above the threshold.
    final calibratedDb = _meanSqToDb(rawMeanSq) + (isIosProfile ? _iosGainOffsetDb : 0.0);

    if (_adaptiveNoise && _calibrationFramesRemaining > 0) {
      final currentThreshDb = _effectiveVadThresholdDb();
      if (calibratedDb > currentThreshDb && calibratedDb >= -37.0) {
        // User is already speaking: stop calibration immediately so voice is never learned as noise.
        _calibrationFramesRemaining = 0;
      } else {
        _calibrationFramesRemaining--;
        if (calibratedDb > -66.0) {
          _floorDb = ((_floorDb * 0.7) + (calibratedDb * 0.3)).clamp(-54.0, -24.0);
        }
      }
    }

    final effectiveThreshDb = _effectiveVadThresholdDb();
    final double activeThreshDb;
    if (_speechActive && _adaptiveNoise && _speechPeakDb > -36.0) {
      // Upstream-style relative speech drop-off in dB: pause triggers once energy drops
      // >= 12 dB below recent voice peak, even in rooms louder than -34 dBFS.
      activeThreshDb = math.max(effectiveThreshDb, _speechPeakDb - 12.0);
    } else {
      activeThreshDb = effectiveThreshDb;
    }

    if (_adaptiveNoise &&
        !_speechActive &&
        _calibrationFramesRemaining == 0 &&
        calibratedDb < _floorDb + 3.5 &&
        calibratedDb > -66.0) {
      final rate = calibratedDb < _floorDb ? 0.20 : 0.05;
      _floorDb = (_floorDb + (calibratedDb - _floorDb) * rate).clamp(-54.0, -24.0);
    }

    final isVoice = calibratedDb > activeThreshDb;
    final effectiveRms = _dbToRms(calibratedDb);
    final floorRms = _dbToRms(_floorDb);
    final level = _adaptiveNoise
        ? math.min(1.0, math.max(0.0, effectiveRms - floorRms) * 15.0)
        : math.min(1.0, effectiveRms * 15.0);

    if (_speechActive || _accumulatedTokens.isNotEmpty) {
      _samplesSinceLastToken += numSamples;
    }

    final noTokenLimit =
        _isSearchMode ? _searchNoTokenFlushSamples : _hifzNoTokenFlushSamples;

    if (isVoice) {
      _cancelStaleBufferTimer();
      _pendingFlush = false;
      final wasSpeechActive = _speechActive;
      _speechActive = true;
      _trailingSilenceSamples = 0;
      _speechPeakDb = math.max(calibratedDb, _speechPeakDb - 0.25);

      if (_isSearchMode) {
        _onSearchAudioLevel?.call(level);
      } else {
        _onEvent?.call(RecitationStatusEvent(
          status: RecitationStatus.listening,
          audioLevel: level,
          currentExpectedAyah: _expectedAyah,
        ));
      }

      if (!wasSpeechActive) {
        _flushPreSpeechToFbank();
      }
      _pushSamplesToFbank(samples);

      if (!_isInferring) {
        _drainStreamingWindows();
      }

      if (_accumulatedTokens.isNotEmpty &&
          _samplesSinceLastToken >= noTokenLimit &&
          (calibratedDb <= _speechPeakDb - 7.0 ||
              _samplesSinceLastToken >= noTokenLimit + 6400)) {
        _triggerTrailingFlush(reason: 'no-token-progress', signalDb: calibratedDb);
      }
    } else {
      if (_speechActive) {
        _trailingSilenceSamples += numSamples;
        if (_adaptiveNoise && calibratedDb > -66.0 && calibratedDb < -24.0) {
          _floorDb = (_floorDb + (calibratedDb - _floorDb) * 0.22).clamp(-54.0, -24.0);
        }
        _pushSamplesToFbank(samples);
        if (_isSearchMode) {
          _onSearchAudioLevel?.call(level);
        }

        if (!_isInferring) {
          _drainStreamingWindows();
        }

        final silenceTarget =
            _isSearchMode ? _searchSilenceSamplesNeeded : _silenceSamplesNeeded;

        if (_trailingSilenceSamples >= silenceTarget) {
          _triggerTrailingFlush(reason: 'vad-silence', signalDb: calibratedDb);
        } else if (_accumulatedTokens.isNotEmpty &&
            _samplesSinceLastToken >= noTokenLimit) {
          _triggerTrailingFlush(reason: 'no-token-progress', signalDb: calibratedDb);
        }
      } else {
        _enqueuePreSpeech(samples);
        if (_isSearchMode) {
          _onSearchAudioLevel?.call(0.0);
        }
      }
    }
  }

  void _triggerTrailingFlush({required String reason, required double signalDb}) {
    _flushCountForTest++;
    _speechActive = false;
    _speechPeakDb = -120.0;
    _samplesSinceLastToken = 0;
    if (_adaptiveNoise && signalDb > -66.0 && signalDb < -24.0) {
      _floorDb = math.max(_floorDb, (signalDb - 1.5).clamp(-54.0, -24.0));
    }
    debugPrint(
      '[RecitationEngine] Triggering flush ($reason) db=${signalDb.toStringAsFixed(1)} '
      'floor=${_floorDb.toStringAsFixed(1)} tokens=${_accumulatedTokens.length}',
    );
    if (!_isInferring) {
      _flushTrailingSilence();
    } else {
      _pendingFlush = true;
    }
  }

  Float32List _packWindow(int startFrame) {
    final xData = Float32List(_window * _mels);
    for (int i = 0; i < _window; i++) {
      xData.setRange(i * _mels, (i + 1) * _mels, _fbankFeats[startFrame + i]);
    }
    return xData;
  }

  Future<List<int>> _stepUnconsumedWithPadding() async {
    final int realEnd = _fbankFeats.length;
    final flushTokens = <int>[];
    final padFrame = Float32List(_mels)..fillRange(0, _mels, _padValue);

    while (_fbankConsumed < realEnd && _isListening) {
      while (_fbankFeats.length - _fbankConsumed < _window) {
        _fbankFeats.add(padFrame);
      }
      final windowTokens = await _stepWindow(_packWindow(_fbankConsumed));
      _fbankConsumed += _shift;
      if (windowTokens.isNotEmpty) {
        flushTokens.addAll(windowTokens);
      }
    }

    if (_fbankFeats.length > realEnd) {
      _fbankFeats.removeRange(realEnd, _fbankFeats.length);
      _fbankConsumed = _fbankFeats.length;
    }

    if (_fbankConsumed > 4 * _window) {
      _fbankFeats.removeRange(0, _fbankConsumed);
      _fbankConsumed = 0;
    }
    return flushTokens;
  }

  /// Drains all available 45-frame windows advancing by shift (32 frames = 320ms).
  Future<void> _drainStreamingWindows() {
    if (_isInferring || _session == null || _matcher == null) {
      return _inferenceFuture ?? Future.value();
    }
    final future = _runDrainStreamingWindows();
    _inferenceFuture = future;
    return future.whenComplete(() {
      if (identical(_inferenceFuture, future)) {
        _inferenceFuture = null;
      }
    });
  }

  Future<void> _runDrainStreamingWindows() async {
    final opSeq = _listenOpSeq;
    _isInferring = true;

    try {
      while (_fbankFeats.length - _fbankConsumed >= _window &&
          _isListening &&
          opSeq == _listenOpSeq) {
        final windowTokens = await _stepWindow(_packWindow(_fbankConsumed));
        if (opSeq != _listenOpSeq || !_isListening) break;
        _fbankConsumed += _shift;
        if (windowTokens.isNotEmpty) {
          await _handleNewTokens(windowTokens, isFlush: false);
        }
      }

      if (opSeq == _listenOpSeq && _fbankConsumed > 4 * _window) {
        _fbankFeats.removeRange(0, _fbankConsumed);
        _fbankConsumed = 0;
      }
    } catch (e, st) {
      debugPrint('[RecitationEngine] Streaming inference error: $e\n$st');
    } finally {
      _isInferring = false;
      if (opSeq == _listenOpSeq) {
        if (_pendingFlush && _isListening && !_speechActive) {
          _pendingFlush = false;
          unawaited(_flushTrailingSilence());
        } else {
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
    }
  }

  /// When trailing silence is reached, pads remaining fbank frames with padValue (-23.0259)
  /// and steps until all unconsumed speech frames have cleared the shift boundary.
  Future<void> _flushTrailingSilence() {
    if (_isInferring || _session == null || _matcher == null) {
      return _inferenceFuture ?? Future.value();
    }
    final future = _runFlushTrailingSilence();
    _inferenceFuture = future;
    return future.whenComplete(() {
      if (identical(_inferenceFuture, future)) {
        _inferenceFuture = null;
      }
    });
  }

  Future<void> _runFlushTrailingSilence() async {
    final opSeq = _listenOpSeq;
    _isInferring = true;

    try {
      final flushTokens = await _stepUnconsumedWithPadding();

      if (opSeq == _listenOpSeq &&
          (flushTokens.isNotEmpty || _accumulatedTokens.isNotEmpty) &&
          _isListening) {
        await _handleNewTokens(flushTokens, isFlush: true);
      }
    } catch (e, st) {
      debugPrint('[RecitationEngine] Flush error: $e\n$st');
    } finally {
      _isInferring = false;
      if (opSeq == _listenOpSeq) {
        if (_pendingSearchStop) {
          _pendingSearchStop = false;
          unawaited(stopListening());
        } else if (_isListening && _fbankFeats.length - _fbankConsumed >= _window) {
          unawaited(_drainStreamingWindows());
        } else {
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
    }
  }

  /// Processes new emitted tokens from the Zipformer CTC decoder.
  Future<void> _handleNewTokens(List<int> tokens, {bool isFlush = false}) async {
    if (tokens.isNotEmpty) {
      _samplesSinceLastToken = 0;
    }
    if (_accumulatedTokens.isEmpty && tokens.isNotEmpty) {
      _firstTokenInBufferTime = DateTime.now();
    }
    _accumulatedTokens.addAll(tokens);
    String activeText = _matcher!.tokensToReadableText(_accumulatedTokens);

    debugPrint('[RecitationEngine] Emitted: $tokens -> "$activeText" (flush: $isFlush)');

    if (_isSearchMode) {
      final cleanText = activeText.trim();
      final cb = _onSearchResults;
      final noMatchCb = _onSearchNoMatch;
      if (!isFlush) {
        if (cleanText.isNotEmpty) {
          cb?.call(const [], cleanText);
        }
        return;
      }

      final phonemeLen = _matcher!.tokensToPhonemes(_accumulatedTokens).length;
      if (phonemeLen < 4) {
        _accumulatedTokens.clear();
        _firstTokenInBufferTime = null;
        if (cleanText.isNotEmpty) {
          noMatchCb?.call(cleanText);
        }
        return;
      }

      final results = _matcher!.searchVerses(_accumulatedTokens, limit: 5);
      if (results.isNotEmpty) {
        final recognizedText = results.first.text.isNotEmpty
            ? results.first.text
            : cleanText;
        _isListening = false;
        _speechActive = false;
        if (!_suppressSearchAutoStop) {
          _pendingSearchStop = true;
        }
        cb?.call(results, recognizedText);
      } else {
        _accumulatedTokens.clear();
        _firstTokenInBufferTime = null;
        cb?.call(const [], cleanText);
        noMatchCb?.call(cleanText);
      }
      return;
    }

    // If user restarted from the first words of the expected verse after an incomplete attempt,
    // discard the abandoned prefix so the restart cannot fuse with old tokens.
    if (_accumulatedTokens.isNotEmpty) {
      final restartIdx = _matcher!.findExpectedAyahRestartIndex(
        surah: _currentSurah,
        expectedAyah: _expectedAyah,
        candidateTokens: _accumulatedTokens,
      );
      if (restartIdx != null && restartIdx > 0 && restartIdx < _accumulatedTokens.length) {
        _accumulatedTokens.removeRange(0, restartIdx);
        _firstTokenInBufferTime = DateTime.now();
        activeText = _matcher!.tokensToReadableText(_accumulatedTokens);
      }
    }

    // Auto-clear off-passage noise/chatter if >= 7.5s elapsed with no prefix match on expected ayah
    if (_accumulatedTokens.isNotEmpty && _firstTokenInBufferTime != null) {
      final elapsedMs = DateTime.now().difference(_firstTokenInBufferTime!).inMilliseconds;
      if (elapsedMs >= 7500 &&
          !_matcher!.hasPrefixProgress(
            surah: _currentSurah,
            expectedAyah: _expectedAyah,
            candidateTokens: _accumulatedTokens,
          )) {
        _accumulatedTokens.clear();
        _firstTokenInBufferTime = null;
        _trailingSilenceSamples = 0;
        _onEvent?.call(const RecitationBufferClearedEvent());
        return;
      }
    }

    if (_isListening && activeText.isNotEmpty) {
      _onEvent?.call(RecitationStatusEvent(
        status: RecitationStatus.processing,
        audioLevel: 0.0,
        currentExpectedAyah: _expectedAyah,
        partialTranscript: activeText,
      ));
    }

    if (!isFlush) {
      // While user is actively speaking (no trailing silence pause yet):
      // Only reveal if connected recitation (Wasl) into the next verse has occurred:
      // i.e. requireLastWord: true AND at least 6 trailing tokens in buffer after the match.
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
          requireLastWord: true,
        );

        if (match == null) {
          break;
        }

        final trailingTokens = _accumulatedTokens.length - match.tokensConsumed;
        if (trailingTokens < 6) {
          // Mid-verse recitation or just finished last word without pausing yet;
          // wait for trailing silence pause (_flushTrailingSilence) to reveal.
          break;
        }

        if (match.isSkip) {
          debugPrint('[RecitationEngine] SKIP DETECTED (Wasl) from ${match.expectedAyah} to ${match.detectedAyah}');
          _onEvent?.call(RecitationSkippedEvent(
            surah: match.surah,
            expectedAyah: match.expectedAyah,
            jumpedToAyah: match.detectedAyah,
            confidence: match.confidence,
          ));
          _accumulatedTokens.clear();
          _firstTokenInBufferTime = null;
          break;
        }

        debugPrint('[RecitationEngine] REVEAL Wasl Matched Ayah ${match.detectedAyah} (conf: ${match.confidence.toStringAsFixed(2)})');
        _expectedAyah = math.max(_expectedAyah, match.detectedAyah + 1);

        _onEvent?.call(RecitationMatchedEvent(
          surah: match.surah,
          ayah: match.detectedAyah,
          confidence: match.confidence,
          text: match.decodedText,
        ));

        if (match.tokensConsumed > 0 && trailingTokens >= 5) {
          _accumulatedTokens.removeRange(0, match.tokensConsumed);
          _firstTokenInBufferTime = DateTime.now();
        } else {
          _accumulatedTokens.clear();
          _firstTokenInBufferTime = null;
          break;
        }
      }
      return;
    }

    // isFlush == true: user finished reciting and paused (trailing silence detected)
    // Cascading match loop with requireLastWord: false
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
        _firstTokenInBufferTime = null;
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
        _firstTokenInBufferTime = DateTime.now();
      } else {
        _accumulatedTokens.clear();
        _firstTokenInBufferTime = null;
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
    final session = _session;
    _session = null;
    _isInitialized = false;
    _audioRecorder?.dispose();
    if (session != null) {
      unawaited(session.release().whenComplete(() {
        OrtEnv.instance.release();
      }));
    } else {
      OrtEnv.instance.release();
    }
  }
}
