import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import '../services/offline_quran_database_service.dart';

class WordByWordStrip extends StatefulWidget {
  final String verseKey;
  final bool isDarkMode;
  final ValueChanged<int>? onWordTap;

  const WordByWordStrip({
    super.key,
    required this.verseKey,
    this.isDarkMode = false,
    this.onWordTap,
  });

  @override
  State<WordByWordStrip> createState() => _WordByWordStripState();
}

class _WordByWordStripState extends State<WordByWordStrip> {
  List<Map<String, dynamic>>? _words;
  bool _isLoading = true;
  int? _activeWordIndex;
  AudioPlayer? _player;

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  @override
  void didUpdateWidget(covariant WordByWordStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.verseKey != widget.verseKey) {
      _loadWords();
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _loadWords() async {
    setState(() => _isLoading = true);
    final words = await OfflineQuranDatabaseService.getVerseWords(widget.verseKey);
    if (mounted) {
      setState(() {
        _words = words;
        _isLoading = false;
      });
    }
  }

  Future<void> _playWordAudio(String? audioPath, int index) async {
    if (audioPath == null || audioPath.isEmpty) return;
    setState(() => _activeWordIndex = index);
    
    try {
      _player ??= AudioPlayer();
      final fullUrl = 'https://audio.qurancdn.com/$audioPath';
      await _player!.setUrl(fullUrl);
      await _player!.play();
    } catch (e) {
      debugPrint("Error playing word audio: $e");
    } finally {
      if (mounted) {
        setState(() => _activeWordIndex = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return const SizedBox(
        height: 80,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_words == null || _words!.isEmpty) {
      return const SizedBox.shrink();
    }

    // Filter out verse end symbols from word list for clean carousel
    final wordList = _words!.where((w) => w['char_type'] != 'end').toList();

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        reverse: true, // Right-to-Left Arabic flow
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        itemCount: wordList.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final word = wordList[index];
          final textUthmani = word['text_uthmani'] as String? ?? '';
          final translation = word['translation'] as String? ?? '';
          final transliteration = word['transliteration'] as String? ?? '';
          final audioUrl = word['audio_url'] as String?;
          final isPlaying = _activeWordIndex == index;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                widget.onWordTap?.call(index);
                _playWordAudio(audioUrl, index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isPlaying
                      ? colorScheme.primary.withValues(alpha: 0.15)
                      : colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isPlaying
                        ? colorScheme.primary
                        : colorScheme.outlineVariant.withValues(alpha: 0.4),
                    width: isPlaying ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      textUthmani,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontFamily: 'Tajweed',
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      translation.isNotEmpty ? translation : transliteration,
                      style: GoogleFonts.notoSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
