import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../data/medina_mushaf_pages.dart';
import '../data/offline_surah_names.dart';
import '../data/quran_repository.dart';
import '../providers/mushaf_audio_provider.dart';
import '../providers/settings_provider.dart';
import '../screens/reading_screen.dart';
import '../services/ctc_matcher.dart';
import '../services/offline_quran_database_service.dart';
import '../services/recitation_engine.dart';
import '../theme/app_theme.dart';

/// Interactive Material 3 Modal Bottom Sheet for "Recite-to-Search" (Voice Quran Search).
class VoiceSearchSheet extends StatefulWidget {
  final QuranRepository repository;
  final void Function(int page, {String? highlightVerseKey}) onOpenPage;

  const VoiceSearchSheet({
    super.key,
    required this.repository,
    required this.onOpenPage,
  });

  static Future<void> show(
    BuildContext context, {
    required QuranRepository repository,
    required void Function(int page, {String? highlightVerseKey}) onOpenPage,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => VoiceSearchSheet(
        repository: repository,
        onOpenPage: onOpenPage,
      ),
    );
  }

  @override
  State<VoiceSearchSheet> createState() => _VoiceSearchSheetState();
}

class _VoiceSearchSheetState extends State<VoiceSearchSheet>
    with SingleTickerProviderStateMixin {
  final RecitationEngine _engine = RecitationEngine();

  bool _isListening = false;
  bool _isStartingMic = false;
  bool _isProcessing = false;
  bool _fetchingDetails = false;
  bool _noMatchDetected = false;
  double _audioLevel = 0.0;
  String _recognizedText = '';
  String? _errorMessage;
  List<VerseSearchResult> _searchResults = [];
  final Map<String, Map<String, dynamic>> _verseDetailsCache = {};

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Automatically start listening after sheet slides up
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startVoiceSearch();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    unawaited(_engine.stopListening());
    super.dispose();
  }

  String _formatSearchError(Object err, bool isThai) {
    final msg = err.toString().replaceFirst('Exception: ', '').trim();
    if (msg.contains('Microphone permission not granted')) {
      return isThai
          ? 'ยังไม่ได้รับอนุญาตใช้ไมโครโฟน กรุณาเปิดสิทธิ์ไมโครโฟนในการตั้งค่า'
          : 'Microphone permission is required. Please enable microphone access in Settings.';
    }
    return msg;
  }

  Future<void> _startVoiceSearch() async {
    if (!mounted) return;
    final isThai = context.read<SettingsProvider>().languageCode == 'th';
    setState(() {
      _isStartingMic = true;
      _isListening = false;
      _isProcessing = false;
      _fetchingDetails = false;
      _noMatchDetected = false;
      _errorMessage = null;
      _audioLevel = 0.0;
      _recognizedText = '';
      _searchResults = [];
    });

    try {
      try {
        final audio = Provider.of<MushafAudioProvider>(context, listen: false);
        if (audio.isPlaying) {
          await audio.togglePlayPause();
        }
      } catch (_) {}

      await _engine.startVoiceSearch(
        onAudioLevel: (level) {
          if (mounted) {
            setState(() => _audioLevel = level);
          }
        },
        onNoMatch: (text) {
          if (!mounted) return;
          setState(() {
            _noMatchDetected = true;
            if (text.isNotEmpty) {
              _recognizedText = text;
            }
          });
        },
        onResults: (results, text) async {
          if (!mounted) return;
          // If we already have valid search results locked in and a trailing empty/noise
          // chunk arrives, do not overwrite the existing recognized text or results.
          if (results.isEmpty && _searchResults.isNotEmpty) {
            return;
          }

          if (results.isEmpty) {
            setState(() {
              _noMatchDetected = false;
              _recognizedText = text;
              _searchResults = const [];
            });
            return;
          }

          // Ensure mic stops once a match is found.
          if (_engine.isListening) {
            await _engine.stopListening();
          }

          if (!mounted) return;
          setState(() {
            _isListening = false;
            _audioLevel = 0.0;
            _noMatchDetected = false;
            _isProcessing = true;
            _fetchingDetails = true;
            _recognizedText = text;
            _searchResults = results;
          });

          try {
            // Fetch full verse details (Uthmani text and translations) from local DB
            for (final r in results) {
              final key = '${r.surah}:${r.ayah}';
              if (!_verseDetailsCache.containsKey(key)) {
                final data = await OfflineQuranDatabaseService.getVerse(key);
                if (data != null && mounted) {
                  _verseDetailsCache[key] = data;
                }
              }
            }
          } finally {
            if (mounted) {
              setState(() {
                _fetchingDetails = false;
                _isProcessing = false;
              });
            }
          }
        },
        onError: (err) {
          if (mounted) {
            setState(() {
              _isStartingMic = false;
              _isListening = false;
              _isProcessing = false;
              _fetchingDetails = false;
              _errorMessage = _formatSearchError(err, isThai);
            });
          }
        },
      );
      if (mounted) {
        setState(() {
          _isStartingMic = false;
          _isListening = _engine.isListening;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isStartingMic = false;
          _isListening = false;
          _isProcessing = false;
          _fetchingDetails = false;
          _errorMessage = _formatSearchError(e, isThai);
        });
      }
    }
  }

  Future<void> _stopVoiceSearch() async {
    if (!mounted) return;
    setState(() {
      _isStartingMic = false;
      _isListening = false;
      _isProcessing = true;
      _audioLevel = 0.0;
    });
    try {
      await _engine.finishVoiceSearch();
    } finally {
      if (mounted && !_fetchingDetails) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isThai = context.watch<SettingsProvider>().languageCode == 'th';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title Header
            Row(
              children: [
                Icon(
                  Icons.mic_none_rounded,
                  color: colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  isThai ? 'ค้นหาด้วยเสียง (อัลกุรอานภาษาอาหรับ)' : 'Voice Search (Arabic Quran)',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Mic & Wave Stage
            _buildMicStage(colorScheme, textTheme, isThai),
            const SizedBox(height: 16),

            // Spoken text pill
            if (_recognizedText.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.record_voice_over_rounded,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _recognizedText,
                        style: TextStyle(
                          fontFamily: 'UthmanicHafs',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                          height: 1.6,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Results Header or Error
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _errorMessage!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              )
            else if (_isProcessing)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: colorScheme.primary,
                  ),
                ),
              )
            else if (_searchResults.isNotEmpty)
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _searchResults.length,
                  separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _searchResults[index];
                    return _buildResultCard(item, colorScheme, textTheme, isThai);
                  },
                ),
              )
            else if (!_isListening && !_isProcessing && _recognizedText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    isThai
                        ? 'ไม่พบอายะฮฺที่ตรงกัน ลองอ่านใหม่อีกครั้ง'
                        : 'No matching verse found. Please try reciting again.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else if (_isListening && _noMatchDetected && _searchResults.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Center(
                  child: Text(
                    isThai
                        ? 'ไม่พบอายะฮฺที่ตรงกัน ลองอ่านอีกครั้งให้ชัดขึ้น'
                        : 'No verse matched yet — try reciting again',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMicStage(
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isThai,
  ) {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              if (_isStartingMic || _isProcessing) return;
              if (_isListening) {
                _stopVoiceSearch();
              } else {
                _startVoiceSearch();
              }
            },
            child: ScaleTransition(
              scale: _isListening ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (_isStartingMic || _isProcessing)
                      ? colorScheme.surfaceContainerHigh
                      : _isListening
                          ? colorScheme.primary
                          : colorScheme.surfaceContainerHigh,
                  border: _isListening
                      ? Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.3),
                          width: 4 + _audioLevel * 4,
                        )
                      : null,
                ),
                child: Center(
                  child: (_isStartingMic || _isProcessing)
                      ? SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: colorScheme.primary,
                          ),
                        )
                      : Icon(
                          _isListening ? Icons.stop_rounded : Icons.mic_none_rounded,
                          color: _isListening ? colorScheme.onPrimary : colorScheme.onSurface,
                          size: 32,
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_isStartingMic) ...[
            Text(
              isThai
                  ? 'กำลังเตรียมไมโครโฟน กรุณารอสักครู่...'
                  : 'Preparing microphone, please wait...',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              isThai
                  ? 'กรุณาเริ่มอ่านเมื่อขึ้นสถานะ "กำลังฟัง..."'
                  : 'Please wait until "Listening..." appears before reciting',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ] else if (_isProcessing) ...[
            Text(
              isThai
                  ? 'กำลังค้นหาอายะฮฺที่ตรงกัน...'
                  : 'Searching for matching verses...',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ] else ...[
            Text(
              _isListening
                  ? (isThai
                      ? 'กำลังฟัง... หยุดพูดสักครู่ หรือแตะปุ่มเพื่อค้นหา'
                      : 'Listening... Pause briefly or tap button to search')
                  : (isThai ? 'แตะไมโครโฟนเพื่อเริ่มอ่าน' : 'Tap microphone to recite'),
              style: textTheme.bodyMedium?.copyWith(
                color: _isListening
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (_isListening && _recognizedText.isNotEmpty) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _stopVoiceSearch,
                icon: const Icon(Icons.search_rounded, size: 16),
                label: Text(
                  isThai ? 'ค้นหาอายะฮฺนี้' : 'Search Now',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildResultCard(
    VerseSearchResult item,
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isThai,
  ) {
    final key = '${item.surah}:${item.ayah}';
    final details = _verseDetailsCache[key];
    final pageNumber = details?['page_number'] as int? ??
        getMedinaMushafPageNumber(item.surah, item.ayah);

    final surahNameEn = offlineSurahNamesEn[item.surah.toString()] ??
        widget.repository.getSurahName(item.surah.toString());
    final surahNameTh = offlineSurahNamesTh[item.surah.toString()] ?? surahNameEn;
    final displayName = isThai ? surahNameTh : surahNameEn;

    final uthmaniText = details?['text_uthmani'] as String? ?? item.text;
    final translation = isThai
        ? (details?['translation_th'] as String? ?? '')
        : (details?['translation_en'] as String? ?? '');

    final confidencePct = (item.score * 100).toInt().clamp(1, 100);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top header: Surah & Ayah badge + confidence
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$displayName ${item.surah}:${item.ayah}',
                    style: textTheme.labelMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  String.fromCharCode(0xe000 + item.surah),
                  style: TextStyle(
                    fontFamily: 'QcfSurahName',
                    fontSize: 22,
                    color: colorScheme.primary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$confidencePct% match',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Arabic verse preview
            Text(
              uthmaniText,
              style: TextStyle(
                fontFamily: 'UthmanicHafs',
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
                height: 1.8,
              ),
              textDirection: TextDirection.rtl,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (translation.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                translation,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 14),

            // Dual action buttons
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReadingScreen(
                            repository: widget.repository,
                            initialSurah: item.surah.toString(),
                            initialVerseIndex: item.ayah - 1,
                            initialVerseId: key,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.menu_book_rounded, size: 14),
                    label: Text(
                      isThai ? 'อ่านความหมาย' : 'Meaning',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onOpenPage(pageNumber, highlightVerseKey: key);
                    },
                    icon: const Icon(Icons.import_contacts_rounded, size: 14),
                    label: Text(
                      isThai ? 'เปิดมุศหัฟ (หน้า $pageNumber)' : 'Mushaf (P.$pageNumber)',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF8A6530),
                      side: const BorderSide(color: Color(0xFF8A6530)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
