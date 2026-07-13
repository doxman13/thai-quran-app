import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_service/audio_service.dart';

import '../data/quran_foundation_repository.dart';
import '../models/mushaf_models.dart';

class MushafAudioProvider extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final QuranFoundationRepository _audioRepository =
      QuranFoundationRepository();

  bool _isPlaying = false;
  bool _isLoading = false;
  String? _currentVerseKey;
  int? _currentPageNumber;
  int? _mushafId;
  bool _isContinuous = false;

  List<MushafVerse> _playlist = [];
  int _playlistIndex = -1;

  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;

  MushafAudioProvider() {
    _initPlayerStateListener();
  }

  // Getters
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  String? get currentVerseKey => _currentVerseKey;
  int? get currentPageNumber => _currentPageNumber;
  int? get mushafId => _mushafId;
  bool get isContinuous => _isContinuous;
  List<MushafVerse> get playlist => _playlist;
  int get playlistIndex => _playlistIndex;

  void _initPlayerStateListener() {
    _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      final processingState = state.processingState;
      _isLoading =
          processingState == ProcessingState.loading ||
          processingState == ProcessingState.buffering;

      if (processingState == ProcessingState.completed) {
        _handlePlaybackCompleted();
      }
      notifyListeners();
    });
  }

  void _handlePlaybackCompleted() {
    if (_isContinuous) {
      _playNext();
    } else {
      stop();
    }
  }

  Future<void> playPage({
    required int mushafId,
    required int pageNumber,
    required List<MushafVerse> verses,
    int startVerseIndex = 0,
  }) async {
    if (verses.isEmpty) return;

    _mushafId = mushafId;
    _currentPageNumber = pageNumber;
    _playlist = List.from(verses);
    _playlistIndex = startVerseIndex.clamp(0, verses.length - 1);
    _isContinuous = true;

    await _playCurrentVerse();
  }

  Future<void> playVerse({
    required int mushafId,
    required int pageNumber,
    required String verseKey,
    required List<MushafVerse> pageVerses,
  }) async {
    _mushafId = mushafId;
    _currentPageNumber = pageNumber;
    _playlist = List.from(pageVerses);
    _isContinuous = false;

    final index = _playlist.indexWhere((v) => v.verseKey == verseKey);
    if (index != -1) {
      _playlistIndex = index;
    } else {
      // Fallback: if not in pageVerses, play as a single item list
      final parts = verseKey.split(':');
      final verse = MushafVerse(
        verseKey: verseKey,
        surahId: parts[0],
        verseId: parts.length > 1 ? parts[1] : '1',
        words: [],
      );
      _playlist = [verse];
      _playlistIndex = 0;
    }

    await _playCurrentVerse();
  }

  Future<void> playSingleIndependentVerse(String verseKey) async {
    await stop();
    _isContinuous = false;
    _currentPageNumber = null;
    _mushafId = null;

    final parts = verseKey.split(':');
    final surahId = parts[0];
    final verseId = parts.length > 1 ? parts[1] : '1';

    final verse = MushafVerse(
      verseKey: verseKey,
      surahId: surahId,
      verseId: verseId,
      words: [],
    );
    _playlist = [verse];
    _playlistIndex = 0;

    await _playCurrentVerse();
  }

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      if (_currentVerseKey != null) {
        await _audioPlayer.play();
      }
    }
  }

  Future<void> stop() async {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    await _audioPlayer.stop();
    _isPlaying = false;
    _isLoading = false;
    _currentVerseKey = null;
    _playlistIndex = -1;
    notifyListeners();
  }

  Future<void> nextVerse() async {
    if (_playlistIndex + 1 < _playlist.length) {
      _playlistIndex++;
      await _playCurrentVerse();
    } else if (_isContinuous) {
      await _loadAndPlayNextPage();
    }
  }

  Future<void> previousVerse() async {
    if (_playlistIndex > 0) {
      _playlistIndex--;
      await _playCurrentVerse();
    } else if (_isContinuous &&
        _currentPageNumber != null &&
        _currentPageNumber! > 1) {
      await _loadAndPlayPreviousPage();
    }
  }

  void _playNext() {
    if (_playlistIndex + 1 < _playlist.length) {
      _playlistIndex++;
      _playCurrentVerse();
    } else if (_isContinuous) {
      _loadAndPlayNextPage();
    } else {
      stop();
    }
  }

  Future<void> _loadAndPlayNextPage() async {
    if (_mushafId == null || _currentPageNumber == null) return;

    final type = mushafTypeById(_mushafId!);
    if (_currentPageNumber! >= type.pageCount) {
      await stop();
      return;
    }

    _isLoading = true;
    _currentPageNumber = _currentPageNumber! + 1;
    notifyListeners();

    try {
      final nextPageData = await _audioRepository.fetchPage(
        mushafId: _mushafId!,
        pageNumber: _currentPageNumber!,
      );

      if (nextPageData.verses.isEmpty) {
        await stop();
        return;
      }

      _playlist = List.from(nextPageData.verses);
      _playlistIndex = 0;
      await _playCurrentVerse();
    } catch (e) {
      debugPrint('Failed to load next page: $e');
      await stop();
    }
  }

  Future<void> _loadAndPlayPreviousPage() async {
    if (_mushafId == null ||
        _currentPageNumber == null ||
        _currentPageNumber! <= 1) {
      return;
    }

    _isLoading = true;
    _currentPageNumber = _currentPageNumber! - 1;
    notifyListeners();

    try {
      final prevPageData = await _audioRepository.fetchPage(
        mushafId: _mushafId!,
        pageNumber: _currentPageNumber!,
      );

      if (prevPageData.verses.isEmpty) {
        await stop();
        return;
      }

      _playlist = List.from(prevPageData.verses);
      // Play the last verse of the previous page
      _playlistIndex = _playlist.length - 1;
      await _playCurrentVerse();
    } catch (e) {
      debugPrint('Failed to load previous page: $e');
      await stop();
    }
  }

  Future<void> _playCurrentVerse() async {
    if (_playlistIndex < 0 || _playlistIndex >= _playlist.length) return;

    final verse = _playlist[_playlistIndex];
    _currentVerseKey = verse.verseKey;
    _isLoading = true;
    notifyListeners();

    _positionSubscription?.cancel();
    _positionSubscription = null;

    try {
      final parts = verse.verseKey.split(':');
      final surahNumber = int.parse(parts[0]);

      // reciterId 161 (Khalifah Al Tunaiji)
      final reciterId = 161;
      final chapterData = await _audioRepository.fetchChapterRecitation(
        reciterId: reciterId,
        chapterNumber: surahNumber,
      );

      final String audioUrl = chapterData['audio_url'] ?? '';
      final Map<String, Map<String, int>> timestamps =
          chapterData['timestamps'] ?? {};

      final verseTime = timestamps[verse.verseKey];
      if (verseTime == null) {
        throw Exception('No timing data for verse ${verse.verseKey}');
      }

      final int fromMs = verseTime['from'] ?? 0;
      final int toMs = verseTime['to'] ?? 0;

      final verseId = parts.length > 1 ? parts[1] : '1';
      final currentSource = _audioPlayer.audioSource;
      bool needLoad = true;
      if (currentSource is UriAudioSource) {
        if (currentSource.uri.toString() == audioUrl) {
          needLoad = false;
        }
      }

      if (needLoad) {
        await _audioPlayer.setAudioSource(
          AudioSource.uri(
            Uri.parse(audioUrl),
            tag: MediaItem(
              id: verse.verseKey,
              album: "Mushaf Recitation",
              title: "Surah $surahNumber - Verse $verseId",
              artist: "Khalifah Al Tunaiji",
              artUri: Uri.parse(
                "https://raw.githubusercontent.com/doxman13/thai-quran-app/main/assets/icons/playstore-icon.png",
              ),
            ),
          ),
        );
      }

      await _audioPlayer.seek(Duration(milliseconds: fromMs));

      // Setup position limit stream
      _positionSubscription = _audioPlayer.positionStream.listen((position) {
        if (position.inMilliseconds >= toMs) {
          _positionSubscription?.cancel();
          _positionSubscription = null;
          _handlePlaybackCompleted();
        }
      });

      _isLoading = false;
      _isPlaying = true;
      notifyListeners();

      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Chapter recitation playback failed: $e, trying fallback...');
      await _playFallbackAyah(verse);
    }
  }

  Future<void> _playFallbackAyah(MushafVerse verse) async {
    try {
      final parts = verse.verseKey.split(':');
      final surahNumber = int.parse(parts[0]);
      final verseId = int.parse(parts[1]);

      final audioUrls = await _fetchPlayableAyahUrls(
        surahNumber: surahNumber,
        verseId: verseId,
        verseKey: verse.verseKey,
      );

      await _playFirstAvailableUrl(
        audioUrls,
        verseKey: verse.verseKey,
        surahNumber: surahNumber,
        verseId: verseId.toString(),
      );
    } catch (err) {
      debugPrint('Fallback play failed: $err');
      _isLoading = false;
      _isPlaying = false;
      notifyListeners();
      // Stop completely
      await stop();
      throw Exception('Unable to play audio for ${verse.verseKey}.');
    }
  }

  Future<List<String>> _fetchPlayableAyahUrls({
    required int surahNumber,
    required int verseId,
    required String verseKey,
  }) async {
    final fallbackUrls = _everyAyahUrls(
      surahNumber: surahNumber,
      verseId: verseId,
    );

    try {
      final quranFoundationUrl = await _audioRepository.fetchAyahRecitationUrl(
        recitationId: 161,
        verseKey: verseKey,
      );
      return [quranFoundationUrl, ...fallbackUrls];
    } catch (error) {
      debugPrint('Quran Foundation ayah audio failed for $verseKey: $error');
      return fallbackUrls;
    }
  }

  List<String> _everyAyahUrls({
    required int surahNumber,
    required int verseId,
  }) {
    final chapter = surahNumber.toString().padLeft(3, '0');
    final verse = verseId.toString().padLeft(3, '0');
    final fileName = '$chapter$verse.mp3';

    return [
      'https://everyayah.com/data/Alafasy_128kbps/$fileName',
      'https://everyayah.com/data/Husary_128kbps/$fileName',
      'https://everyayah.com/data/Minshawy_Murattal_128kbps/$fileName',
    ];
  }

  Future<void> _playFirstAvailableUrl(
    List<String> audioUrls, {
    required String verseKey,
    required int surahNumber,
    required String verseId,
  }) async {
    Object? lastError;

    for (final audioUrl in audioUrls) {
      try {
        await _audioPlayer.setAudioSource(
          AudioSource.uri(
            Uri.parse(audioUrl),
            tag: MediaItem(
              id: verseKey,
              album: "Mushaf Recitation (Fallback)",
              title: "Surah $surahNumber - Verse $verseId",
              artist: "Quran Reciter",
              artUri: Uri.parse(
                "https://raw.githubusercontent.com/doxman13/thai-quran-app/main/assets/icons/playstore-icon.png",
              ),
            ),
          ),
        );
        _isLoading = false;
        _isPlaying = true;
        notifyListeners();
        await _audioPlayer.play();
        return;
      } catch (error) {
        lastError = error;
        debugPrint('Audio URL failed: $audioUrl ($error)');
      }
    }

    throw Exception(lastError ?? 'No playable audio URL was found.');
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}
