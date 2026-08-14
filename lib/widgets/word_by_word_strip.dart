import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../services/offline_quran_database_service.dart';
import '../screens/root_verses_screen.dart';
import '../providers/settings_provider.dart';

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

  void _showWordDetailSheet(BuildContext context, Map<String, dynamic> word) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final textUthmani = word['text_uthmani'] as String? ?? '';
    final translationTh = word['translation_th'] as String? ?? '';
    final translationEn = word['translation_en'] as String? ?? word['translation'] as String? ?? '';
    final translationMs = word['translation_ms'] as String? ?? '';
    final transliteration = word['transliteration'] as String? ?? '';
    final rootArabic = word['root_arabic'] as String?;
    final rootOccurrences = word['root_occurrences'] as int? ?? 0;
    final partOfSpeech = word['part_of_speech'] as String?;
    final audioUrl = word['audio_url'] as String?;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header indicator
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Word in Large Arabic Font with Audio Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton.filledTonal(
                    icon: const Icon(Icons.volume_up_rounded),
                    onPressed: () {
                      _playWordAudio(audioUrl, -1);
                    },
                  ),
                  Expanded(
                    child: Text(
                      textUthmani,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontFamily: 'Tajweed',
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Transliteration & Multilingual Meaning Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (transliteration.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(Icons.record_voice_over_outlined, size: 14, color: colorScheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            transliteration,
                            style: GoogleFonts.notoSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (translationTh.isNotEmpty) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('🇹🇭 ', style: const TextStyle(fontSize: 13)),
                          Expanded(
                            child: Text(
                              translationTh,
                              style: GoogleFonts.notoSansThai(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (translationEn.isNotEmpty) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('🇬🇧 ', style: const TextStyle(fontSize: 13)),
                          Expanded(
                            child: Text(
                              translationEn,
                              style: GoogleFonts.notoSans(
                                fontSize: 13,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (translationMs.isNotEmpty) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('🇲🇾 ', style: const TextStyle(fontSize: 13)),
                          Expanded(
                            child: Text(
                              translationMs,
                              style: GoogleFonts.notoSans(
                                fontSize: 13,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Morphology & Root Word Section
              if (rootArabic != null || partOfSpeech != null) ...[
                Text(
                  'ไวยากรณ์และรากศัพท์ (Morphology & Root)',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      if (rootArabic != null) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'รากศัพท์คำ (جذر)',
                              style: GoogleFonts.notoSansThai(
                                fontSize: 13,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                rootArabic,
                                style: const TextStyle(
                                  fontFamily: 'Tajweed',
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                      ],
                      if (partOfSpeech != null) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'หน้าที่ของคำ (POS)',
                              style: GoogleFonts.notoSansThai(
                                fontSize: 13,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              partOfSpeech,
                              style: GoogleFonts.notoSansThai(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Button to view all occurrences by root
              if (rootArabic != null && rootOccurrences > 0) ...[
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RootVersesScreen(
                          rootArabic: rootArabic,
                          occurrences: rootOccurrences,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.saved_search_rounded, size: 18),
                  label: Text(
                    'ดูทั้ง $rootOccurrences โองการที่มีรากศัพท์นี้ ($rootArabic)',
                    style: GoogleFonts.notoSansThai(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final wbwLang = context.select<SettingsProvider, String>(
      (settings) => settings.wordByWordLanguage,
    );

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

    final wordList = _words!.where((w) => w['char_type'] != 'end').toList();

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        reverse: true, // Right-to-Left Arabic flow
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        itemCount: wordList.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final word = wordList[index];
          final textUthmani = word['text_uthmani'] as String? ?? '';
          
          String translation;
          if (wbwLang == 'ms') {
            translation = (word['translation_ms'] as String?) ?? '';
          } else if (wbwLang == 'en') {
            translation = (word['translation_en'] as String?) ?? (word['translation'] as String?) ?? '';
          } else {
            translation = (word['translation_th'] as String?) ?? '';
          }

          if (translation.isEmpty) {
            translation = (word['translation_th'] as String?) ??
                (word['translation_en'] as String?) ??
                (word['translation'] as String?) ??
                (word['transliteration'] as String?) ?? '';
          }

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
              onLongPress: () {
                _showWordDetailSheet(context, word);
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
                      style: GoogleFonts.notoSansThai(
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
