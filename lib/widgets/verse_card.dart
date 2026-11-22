// lib/widgets/verse_card.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/verse.dart';
import '../models/tadabbur_note.dart';
import '../data/offline_surah_names.dart';
import '../data/quran_repository.dart';
import '../providers/settings_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/notes_provider.dart';
import '../providers/stats_provider.dart';
import '../providers/translation_manager_provider.dart';
import '../providers/local_reading_provider.dart';
import '../providers/thai_text_protection_provider.dart';
import '../providers/mushaf_audio_provider.dart';
import '../shared/shared.dart';
import '../theme/app_theme.dart';
import '../utils/html_parser.dart';
import 'tadabbur_panel.dart';
import 'verse_share_sheet.dart';
import 'word_by_word_strip.dart';
import 'tajweed_text.dart';
import '../services/footnote_service.dart';
import '../services/tajweed_service.dart';
import '../providers/supabase_provider.dart';
import 'auth_bottom_sheet.dart';

class VerseCardController extends ChangeNotifier {
  VoidCallback? toggleTafsir;
  VoidCallback? toggleAudit;
  VoidCallback? playAudio;
  VoidCallback? stopAudio;
  VoidCallback? copyText;
  VoidCallback? shareImage;
  VoidCallback? showWordByWord;
  VoidCallback? toggleBookmark;
  VoidCallback? toggleFavorite;
  VoidCallback? openTadabbur;

  bool isAudioPlaying = false;
  bool isAudioLoading = false;
  bool showTafsirBox = false;
  bool showAuditBox = false;
  bool hasTafsir = false;
  bool isBookmarked = false;
  bool isFavorited = false;

  void updateState({
    bool? isAudioPlaying,
    bool? isAudioLoading,
    bool? showTafsirBox,
    bool? showAuditBox,
    bool? hasTafsir,
    bool? isBookmarked,
    bool? isFavorited,
  }) {
    bool changed = false;
    if (isAudioPlaying != null && this.isAudioPlaying != isAudioPlaying) {
      this.isAudioPlaying = isAudioPlaying;
      changed = true;
    }
    if (isAudioLoading != null && this.isAudioLoading != isAudioLoading) {
      this.isAudioLoading = isAudioLoading;
      changed = true;
    }
    if (showTafsirBox != null && this.showTafsirBox != showTafsirBox) {
      this.showTafsirBox = showTafsirBox;
      changed = true;
    }
    if (showAuditBox != null && this.showAuditBox != showAuditBox) {
      this.showAuditBox = showAuditBox;
      changed = true;
    }
    if (hasTafsir != null && this.hasTafsir != hasTafsir) {
      this.hasTafsir = hasTafsir;
      changed = true;
    }
    if (isBookmarked != null && this.isBookmarked != isBookmarked) {
      this.isBookmarked = isBookmarked;
      changed = true;
    }
    if (isFavorited != null && this.isFavorited != isFavorited) {
      this.isFavorited = isFavorited;
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }
}

class VerseCard extends StatefulWidget {
  final Verse verse;
  final QuranRepository repository;
  final int index;
  final String? progressProfileId;
  final bool useExplicitProgressProfile;
  final bool splitLandscape;
  final VerseCardController? controller;

  const VerseCard({
    super.key,
    required this.verse,
    required this.repository,
    required this.index,
    this.progressProfileId,
    this.useExplicitProgressProfile = false,
    this.splitLandscape = false,
    this.controller,
  });

  @override
  State<VerseCard> createState() => _VerseCardState();
}

class _VerseCardState extends State<VerseCard> {
  // Audit and personal notes states
  bool _showAuditBox = false;
  bool _showTafsirBox = false;
  bool _isAudioLoading = false;
  bool _isAudioPlaying = false;

  final GlobalKey _tafsirKey = GlobalKey();
  final GlobalKey _auditKey = GlobalKey();
  final TextEditingController _auditController = TextEditingController();

  bool _isSavingAudit = false;
  bool _auditSaved = false;
  String? _lastTrackedVerseKey;

  bool _isActiveCard() {
    if (!mounted) return false;
    try {
      final progress = Provider.of<ProgressProvider>(context, listen: false);
      return widget.index == progress.lastVerseIndex;
    } catch (_) {
      return true;
    }
  }

  String _effectivePrimaryLang({bool listen = false}) {
    if (!mounted) return 'th';
    final settings = Provider.of<SettingsProvider>(context, listen: listen);
    final transManager =
        Provider.of<TranslationManagerProvider>(context, listen: false);
    return resolveEffectiveTranslationLanguage(
      context,
      settings: settings,
      transManager: transManager,
    );
  }

  bool _isNonThaiPrimary({bool listen = false}) =>
      _effectivePrimaryLang(listen: listen) != 'th';

  bool _isMalayPrimary({bool listen = false}) =>
      _effectivePrimaryLang(listen: listen) == 'ms';

  String? _getTafsir({bool listen = false}) {
    if (_isMalayPrimary(listen: listen)) {
      final idTafsir = widget.verse.shortTafsirId;
      if (idTafsir != null && idTafsir.trim().isNotEmpty) {
        return idTafsir;
      }
    }
    final primaryTafsir = _isNonThaiPrimary(listen: listen)
        ? widget.verse.shortTafsirEn
        : widget.verse.shortTafsir;
    if (primaryTafsir != null && primaryTafsir.trim().isNotEmpty) {
      return primaryTafsir;
    }
    final fallback = widget.verse.shortTafsir ?? widget.verse.shortTafsirEn ?? widget.verse.shortTafsirId;
    return (fallback != null && fallback.trim().isNotEmpty) ? fallback : null;
  }

  String? _getTafsirSource() {
    if (_isMalayPrimary() && widget.verse.shortTafsirId != null && widget.verse.shortTafsirId!.trim().isNotEmpty) {
      return widget.verse.shortTafsirSourceId ?? 'Mokhtasar (ID)';
    }
    final primaryTafsir = _isNonThaiPrimary() ? widget.verse.shortTafsirEn : widget.verse.shortTafsir;
    if (primaryTafsir != null && primaryTafsir.trim().isNotEmpty) {
      return _isNonThaiPrimary() ? widget.verse.shortTafsirSourceEn : widget.verse.shortTafsirSource;
    }
    if (widget.verse.shortTafsir != null && widget.verse.shortTafsir!.trim().isNotEmpty) {
      return widget.verse.shortTafsirSource;
    }
    return widget.verse.shortTafsirSourceEn ?? widget.verse.shortTafsirSourceId;
  }

  @override
  void initState() {
    super.initState();
    FootnoteService().addListener(_onFootnoteLoaded);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      if (settings.showArabicText) {
        _loadArabic();
      }
      if (_isActiveCard()) {
        _bindController();
      }
    });
  }

  @override
  void didUpdateWidget(VerseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.verse != widget.verse ||
        oldWidget.controller != widget.controller) {
      if (_isActiveCard()) {
        _bindController();
      }
    }
  }

  void _bindController() {
    if (widget.controller != null && _isActiveCard()) {
      widget.controller!.toggleTafsir = () {
        if (_getTafsir() != null) {
          setState(() {
            _showTafsirBox = !_showTafsirBox;
            _showAuditBox = false;
            _updateControllerState();
          });
          if (_showTafsirBox) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_tafsirKey.currentContext != null) {
                Scrollable.ensureVisible(
                  _tafsirKey.currentContext!,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOutCubic,
                );
              }
            });
          }
        }
      };
      widget.controller!.toggleAudit = () {
        setState(() {
          _showAuditBox = !_showAuditBox;
          _showTafsirBox = false;
          _updateControllerState();
        });
        if (_showAuditBox) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_auditKey.currentContext != null) {
              Scrollable.ensureVisible(
                _auditKey.currentContext!,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOutCubic,
              );
            }
          });
        }
      };
      widget.controller!.playAudio = _toggleAyahAudio;
      widget.controller!.stopAudio = () async {
        if (!mounted) return;
        final mushafAudio = Provider.of<MushafAudioProvider>(context, listen: false);
        await mushafAudio.stop();
      };
      widget.controller!.copyText = () {
        if (!mounted) return;
        _copyVerseText();
      };
      widget.controller!.shareImage = () {
        if (!mounted) return;
        _shareVerseImage();
      };
      widget.controller!.showWordByWord = () {
        if (!mounted) return;
        WordByWordSheet.show(
          context,
          verseKey: '${widget.verse.surahId}:${widget.verse.id}',
          verseTextUthmani: widget.verse.arabic.split(' | ').join(' '),
          translationText: _isNonThaiPrimary()
              ? widget.verse.english
              : (widget.verse.thaiV3.isNotEmpty
                  ? widget.verse.thaiV3
                  : (widget.verse.thaiV2.isNotEmpty
                      ? widget.verse.thaiV2
                      : widget.verse.english)),
        );
      };
      widget.controller!.toggleBookmark = () async {
        if (!mounted) return;
        final localReading = Provider.of<LocalReadingProvider>(
          context,
          listen: false,
        );
        final isBookmarked = localReading.isBookmarked(
          widget.verse.surahId,
          widget.verse.id,
        );
        if (!isBookmarked) {
          final ok = await GuestBookmarkWarningDialog.checkAndPrompt(context);
          if (!ok || !mounted) return;
        }
        await localReading.toggleBookmark(
          widget.verse.surahId,
          widget.verse.id,
        );
        if (mounted) _updateControllerState();
      };
      widget.controller!.toggleFavorite = () {
        if (!mounted) return;
        final notesProv = Provider.of<NotesProvider>(context, listen: false);
        final noteObj = notesProv.getNoteObjectForVerse(
          widget.verse.surahId,
          widget.verse.id,
        );
        _handleFavoriteTap(notesProv, noteObj).then((_) {
          if (mounted) _updateControllerState();
        });
      };
      widget.controller!.openTadabbur = _openTadabburModal;

      _updateControllerState();
    }
  }

  void _updateControllerState() {
    if (widget.controller != null) {
      widget.controller!.updateState(
        isAudioPlaying: _isAudioPlaying,
        isAudioLoading: _isAudioLoading,
        showTafsirBox: _showTafsirBox,
        showAuditBox: _showAuditBox,
        hasTafsir: _getTafsir() != null,
        isBookmarked: Provider.of<LocalReadingProvider>(
          context,
          listen: false,
        ).isBookmarked(widget.verse.surahId, widget.verse.id),
        isFavorited:
            Provider.of<NotesProvider>(
              context,
              listen: false,
            ).getNoteObjectForVerse(widget.verse.surahId, widget.verse.id) !=
            null,
      );
    }
  }

  @override
  void dispose() {
    FootnoteService().removeListener(_onFootnoteLoaded);
    _auditController.dispose();
    super.dispose();
  }

  void _onFootnoteLoaded() {
    if (mounted) {
      setState(() {});
    }
  }

  void _openTadabburModal() {
    final supabaseProv = Provider.of<SupabaseProvider>(context, listen: false);
    if (!supabaseProv.isLoggedIn) {
      AuthRequiredDialog.show(
        context,
        featureName: 'บันทึกตะดับบุร (Tadabbur Notes)',
        reason: 'การบันทึกตะดับบุรจำเป็นต้องเข้าสู่ระบบ เพื่อจัดเก็บข้อมูลอย่างปลอดภัยบนคลาวด์',
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: TadabburPanel(
            surahId: widget.verse.surahId,
            verseId: widget.verse.id,
            onClose: () => Navigator.pop(ctx),
          ),
        );
      },
    );
  }

  Future<void> _handleFavoriteTap(
    NotesProvider notesProv,
    TadabburNote? noteObj,
  ) async {
    final supabaseProv = Provider.of<SupabaseProvider>(context, listen: false);
    if (!supabaseProv.isLoggedIn) {
      AuthRequiredDialog.show(
        context,
        featureName: 'บันทึกอายะฮฺที่ชอบ (Favorite Verse)',
        reason: 'การบันทึกอายะฮฺที่ชอบและข้อคิดจำเป็นต้องเข้าสู่ระบบ เพื่อซิงค์ข้อมูลกับบัญชีของคุณ',
      );
      return;
    }

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final colors = settings.getAppColors();
    final isThai = settings.languageCode == 'th';
    final messenger = ScaffoldMessenger.of(context);
    final hasNoteText =
        noteObj != null &&
        noteObj.noteText.trim().isNotEmpty &&
        noteObj.noteText != '__favorited__';

    if (noteObj == null) {
      await notesProv.saveNote(
        surahId: widget.verse.surahId,
        verseId: widget.verse.id,
        noteText: '',
      );
      if (!mounted) return;
      _updateControllerState();
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            side: BorderSide(color: colors.borderSoft),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.favorite_rounded,
                        color: colors.danger,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isThai
                              ? 'รายการโปรด: อายะฮฺ ${widget.verse.surahId}:${widget.verse.id}'
                              : 'Favorite: Ayah ${widget.verse.surahId}:${widget.verse.id}',
                          style: GoogleFonts.notoSansThai(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colors.textStrong,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    hasNoteText
                        ? (isThai
                            ? 'อายะฮฺนี้มีบันทึกตะดับบุรของคุณอยู่แล้ว'
                            : 'You have a saved Tadabbur note for this ayah.')
                        : (isThai
                            ? 'บันทึกอายะฮฺนี้ในรายการโปรดแล้ว คุณสามารถเขียนข้อคิดตะดับบุรเพิ่มเติมได้'
                            : 'Saved to favorites. You can write a Tadabbur note for this ayah.'),
                    style: GoogleFonts.notoSansThai(
                      fontSize: 13.5,
                      height: 1.5,
                      color: colors.foreground,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openTadabburModal();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0E5A4A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                    ),
                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                    label: Text(
                      hasNoteText
                          ? (isThai
                              ? 'ดู / แก้ไขโน้ตของฉัน'
                              : 'View / Edit Note')
                          : (isThai
                              ? 'เขียนโน้ต / ตะดับบุร'
                              : 'Write Note / Tadabbur'),
                      style: GoogleFonts.notoSansThai(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await notesProv.deleteNote(
                              widget.verse.surahId,
                              widget.verse.id,
                            );
                            if (!mounted) return;
                            _updateControllerState();
                            messenger
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(
                                  content: Text(
                                    context.tr('removed_from_favorites'),
                                  ),
                                ),
                              );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: colors.danger,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusSm,
                              ),
                            ),
                          ),
                          child: Text(
                            isThai ? 'ลบรายการโปรด' : 'Remove Favorite',
                            style: GoogleFonts.notoSansThai(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colors.danger,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: colors.surfaceMuted,
                            foregroundColor: colors.textStrong,
                            side: BorderSide(color: colors.borderSoft),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusSm,
                              ),
                            ),
                          ),
                          child: Text(
                            isThai ? 'เรียบร้อย' : 'Done',
                            style: GoogleFonts.notoSansThai(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colors.textStrong,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadArabic() async {
    if (widget.verse.arabic.isNotEmpty) {
      return;
    }

    setState(() {
      widget.verse.isArabicLoading = true;
    });

    final fetched = await widget.repository.fetchArabicVerse(
      widget.verse.surahId,
      widget.verse.id,
    );

    if (mounted) {
      setState(() {
        widget.verse.arabic = fetched;
        widget.verse.isArabicLoading = false;
      });
    }
  }

  Future<void> _submitAuditComment() async {
    final comment = _auditController.text.trim();
    if (comment.isEmpty) return;

    setState(() {
      _isSavingAudit = true;
    });

    final surahNum = int.tryParse(widget.verse.surahId) ?? 0;
    final verseNum = int.tryParse(widget.verse.id) ?? 0;

    bool success = false;
    Object? saveError;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw StateError('Please log in to submit an error report.');
      }

      final reportedVerseText = widget.verse.thaiV3.isNotEmpty
          ? widget.verse.thaiV3
          : widget.verse.thaiV2;

      await Supabase.instance.client.from('error_reports').insert({
        'user_id': user.id,
        'surah_id': surahNum,
        'ayah_number': verseNum,
        'reported_verse_text': reportedVerseText,
        'user_comment': comment,
      });
      success = true;
      debugPrint('Audit saved to Supabase error_reports');
    } catch (supabaseError) {
      saveError = supabaseError;
      debugPrint('Supabase error report save failed: $supabaseError');
    }

    if (mounted) {
      setState(() {
        _isSavingAudit = false;
        _auditSaved = success;
        if (success) _auditController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Report submitted successfully!'
                : saveError is StateError
                ? 'Please log in to report an error.'
                : 'Could not submit the report. Please try again.',
          ),
          backgroundColor: success ? Colors.teal : Colors.redAccent,
        ),
      );

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _auditSaved = false;
          });
        }
      });
    }
  }

  void _copyVerseText() {
    final text = StringBuffer();
    if (widget.verse.arabic.trim().isNotEmpty) {
      text.writeln(
        formatArabicAyahText(
          widget.verse.arabic,
          verseNumber: widget.verse.id,
        ),
      );
      text.writeln();
    }
    if (widget.verse.thaiV3.trim().isNotEmpty) {
      text.writeln(widget.verse.thaiV3.trim());
    } else if (widget.verse.thaiV2.trim().isNotEmpty) {
      text.writeln(widget.verse.thaiV2.trim());
    } else if (widget.verse.english.trim().isNotEmpty) {
      text.writeln(widget.verse.english.trim());
    }
    final currentTafsir = _getTafsir();
    if (_showTafsirBox && currentTafsir?.trim().isNotEmpty == true) {
      text
        ..writeln()
        ..writeln('Short tafsir')
        ..writeln(currentTafsir!.trim());
    }
    text
      ..writeln()
      ..write('${widget.verse.surahId}:${widget.verse.id}');

    Clipboard.setData(ClipboardData(text: text.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied verse text'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  String? _resolveTranslationShareLabel(
    SettingsProvider settings,
    TranslationManagerProvider transManager,
  ) {
    final canonical = TranslationConstants.resolveTranslationId(
      settings.primaryTranslationId,
    );
    if (canonical == 'thai_v3') return 'ไทย - King Fahd';
    final known = TranslationConstants.getKnownOption(canonical);
    if (known != null) return known.name.replaceAll('(Offline)', '').trim();
    final apiId = TranslationConstants.resolveApiId(
      settings.primaryTranslationId,
    );
    if (apiId != null) {
      for (final t in transManager.downloadedTranslations) {
        if (t['id'] == apiId &&
            (t['name']?.toString().trim().isNotEmpty ?? false)) {
          return t['name'].toString().trim();
        }
      }
    }
    return null;
  }

  Future<void> _shareVerseImage() async {
    if (!mounted) return;
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final transManager = Provider.of<TranslationManagerProvider>(
      context,
      listen: false,
    );
    final isThai = settings.languageCode == 'th';
    final verseKey = '${widget.verse.surahId}:${widget.verse.id}';
    final surahName = surahDisplayName(
      widget.verse.surahId,
      isThai: isThai,
    );
    final translationText = resolveVerseTranslationText(
      context: context,
      verseKey: verseKey,
      verse: widget.verse,
      settings: settings,
      transManager: transManager,
      repository: widget.repository,
    );
    final translationLabel = _resolveTranslationShareLabel(
      settings,
      transManager,
    );
    final footnotes = FootnoteService()
        .getEntry(verseKey, settings.primaryTranslationId)
        ?.footnotes;

    await VerseShareSheet.show(
      context,
      surahId: widget.verse.surahId,
      verseId: widget.verse.id,
      surahName: surahName,
      arabicText: widget.verse.arabic,
      translationText: translationText,
      translationLabel: translationLabel,
      shortTafsir: _getTafsir(),
      shortTafsirSource: _getTafsirSource(),
      footnotes: footnotes,
      repository: widget.repository,
      isThai: isThai,
    );
  }

  Future<void> _toggleAyahAudio() async {
    if (_isAudioLoading) return;

    final mushafAudio = Provider.of<MushafAudioProvider>(context, listen: false);
    final verseKey = '${widget.verse.surahId}:${widget.verse.id}';

    if (_isAudioPlaying) {
      await mushafAudio.stop();
      return;
    }

    try {
      await mushafAudio.playSingleIndependentVerse(verseKey);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not play ayah audio: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioProvider = Provider.of<MushafAudioProvider>(context);
    final verseKey = '${widget.verse.surahId}:${widget.verse.id}';
    final isCurrentVerse = audioProvider.currentVerseKey == verseKey;
    final isPlaying = isCurrentVerse && audioProvider.isPlaying;
    final isLoading = isCurrentVerse && audioProvider.isLoading;

    if (isPlaying != _isAudioPlaying || isLoading != _isAudioLoading) {
      _isAudioPlaying = isPlaying;
      _isAudioLoading = isLoading;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _updateControllerState();
        }
      });
    }

    final settings = Provider.of<SettingsProvider>(context);
    final notesProv = Provider.of<NotesProvider>(context, listen: false);
    final localReading = Provider.of<LocalReadingProvider>(
      context,
      listen: false,
    );
    final thaiTextProtection = Provider.of<ThaiTextProtectionProvider>(
      context,
      listen: false,
    );
    final statsProv = Provider.of<StatsProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isHighlighted = context.select<ProgressProvider, bool>(
      (progress) => widget.index == progress.lastVerseIndex,
    );

    // Bind controller if this card is currently highlighted/active
    if (isHighlighted && widget.controller != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _bindController();
        }
      });
    }

    final colors = settings.getAppColors();
    final themeColor = settings.getPrimaryColor();
    final bodyTextColor = colors.textStrong;
    final arabicTextColor = isDark
        ? const Color(0xFFD7E0EA)
        : const Color(0xFF334155);
    final colorScheme = Theme.of(context).colorScheme;
    final isLandscapeSplit = widget.splitLandscape;

    final showArabicText = true;

    final verseRef = toVerseRef(widget.verse.surahId, widget.verse.id);

    // Select only this specific verse's bookmark status
    final isBookmarked = context.select<LocalReadingProvider, bool>(
      (lr) => lr.isBookmarked(verseRef.surahId, verseRef.verseId),
    );

    if (isHighlighted && _lastTrackedVerseKey != verseRef.verseKey) {
      _lastTrackedVerseKey = verseRef.verseKey;
      // Log reading stat
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        statsProv.logVerseRead(widget.verse.surahId, widget.verse.id);
        final localReading = Provider.of<LocalReadingProvider>(
          context,
          listen: false,
        );
        var progressProfile = widget.useExplicitProgressProfile
            ? (widget.progressProfileId == null
                  ? null
                  : localReading.profileById(widget.progressProfileId!))
            : localReading.activeProfile;

        if (progressProfile != null && isShortcutProfile(progressProfile)) {
          progressProfile = localReading.freeReadProfile;
        }

        if (progressProfile != null) {
          localReading.updateProfileProgress(
            progressProfile.id,
            verseRef,
            context: context,
          );
          localReading.addRecentReading(
            verse: verseRef,
            profileId: progressProfile.id,
          );
        } else {
          localReading.addRecentReading(
            verse: verseRef,
            profileId: null,
          );
        }
      });
    }

    final arabicStyle = TextStyle(
      fontFamily: 'UthmanicHafs',
      fontWeight: FontWeight.w400,
      fontSize: settings.arabicFontSize,
      height: 2.0,
      color: arabicTextColor,
    );

    // Force load if Arabic should be visible (globally or locally) and is not loaded yet
    if (showArabicText &&
        widget.verse.arabic.isEmpty &&
        !widget.verse.isArabicLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadArabic();
        }
      });
    }

    // Select only this specific verse's favorite / note status
    final noteObj = context.select<NotesProvider, TadabburNote?>(
      (notes) => notes.getNoteObjectForVerse(
        widget.verse.surahId,
        widget.verse.id,
      ),
    );
    final isFavorited = noteObj != null;
    final hasTadabburNote =
        noteObj != null &&
        noteObj.noteText.trim().isNotEmpty &&
        noteObj.noteText != '__favorited__';
    final isThai = settings.languageCode == 'th';
    final shareTooltip = isThai ? 'แชร์' : 'Share';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
              if (isLandscapeSplit)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildAyahAndNoteBadges(
                        colors: colors,
                        colorScheme: colorScheme,
                        isDark: isDark,
                        hasTadabburNote: hasTadabburNote,
                        isThai: isThai,
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildActionIcon(
                            tooltip: shareTooltip,
                            icon: Icons.share_outlined,
                            color: colors.primary,
                            onPressed: _shareVerseImage,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                flex: isLandscapeSplit ? 6 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Row (landscape uses the full-width action bar above)
                    if (!isLandscapeSplit)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildAyahAndNoteBadges(
                    colors: colors,
                    colorScheme: colorScheme,
                    isDark: isDark,
                    hasTadabburNote: hasTadabburNote,
                    isThai: isThai,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildActionIcon(
                        tooltip: shareTooltip,
                        icon: Icons.share_outlined,
                        color: colors.primary,
                        onPressed: _shareVerseImage,
                      ),
                      _buildActionIcon(
                        tooltip: isBookmarked ? 'Remove bookmark' : 'Bookmark',
                        icon: isBookmarked
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        active: isBookmarked,
                        color: colorScheme.tertiary,
                        onPressed: () async {
                          if (!isBookmarked) {
                            final ok =
                                await GuestBookmarkWarningDialog.checkAndPrompt(
                                  context,
                                );
                            if (!ok) return;
                          }
                          await localReading.toggleBookmark(
                            verseRef.surahId,
                            verseRef.verseId,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),

                    // Arabic Text Area (portrait only; landscape renders it in the left pane)
                    if (showArabicText && !isLandscapeSplit) ...[
                      _buildArabicPane(
                        settings: settings,
                        isDark: isDark,
                        arabicStyle: arabicStyle,
                        colorScheme: colorScheme,
                      ),
                      const SizedBox(height: 16),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.14)
                            : const Color(0xFFD5CEBE),
                      ),
                      const SizedBox(height: 16),
                    ],

              // Translations Container
              if (true) ...[
                if (settings.primaryTranslationId.isNotEmpty)
                  _buildDynamicTranslation(
                    context,
                    settings.primaryTranslationId,
                    settings,
                    isDark,
                    bodyTextColor,
                    thaiTextProtection,
                    isPrimary: true,
                  ),
                if (settings.secondaryTranslationId != null)
                  _buildDynamicTranslation(
                    context,
                    settings.secondaryTranslationId!,
                    settings,
                    isDark,
                    bodyTextColor,
                    thaiTextProtection,
                    isPrimary: false,
                  ),
              ],

              const SizedBox(height: 12),

              // Heart (favorite) button row (landscape moves this to the action bar)
              if (!isLandscapeSplit)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildActionIcon(
                    tooltip: isFavorited
                        ? 'Remove from favorites'
                        : 'Add to favorites',
                    icon: isFavorited
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    active: isFavorited,
                    color: colorScheme.error,
                    onPressed: () {
                      final currentNoteObj = notesProv.getNoteObjectForVerse(
                        widget.verse.surahId,
                        widget.verse.id,
                      );
                      _handleFavoriteTap(notesProv, currentNoteObj);
                    },
                  ),
                ],
              ),

              // Collapsible Short Tafsir
              if (_showTafsirBox && _getTafsir() != null) ...[
                const SizedBox(height: 8),
                Container(
                  key: _tafsirKey,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark
                          ? Colors.blueGrey.shade800
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Short tafsir',
                            style: GoogleFonts.notoSansThai(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: themeColor,
                            ),
                          ),
                          Text(
                            _getTafsirSource() ??
                                'QuranEnc Thai Mokhtasar',
                            style: GoogleFonts.notoSansThai(
                              fontSize: 10,
                              color: isDark
                                  ? Colors.blueGrey.shade300
                                  : Colors.blueGrey.shade500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isNonThaiPrimary() 
                            ? _getTafsir()!
                            : thaiTextProtection.protect(_getTafsir()!),
                        locale: _isNonThaiPrimary() ? null : const Locale('th', 'TH'),
                        style: _isNonThaiPrimary()
                          ? GoogleFonts.notoSansThai(
                              fontSize: 15,
                              height: 1.5,
                              color: isDark
                                  ? const Color(0xFFE2E8F0)
                                  : const Color(0xFF334155),
                              fontWeight: FontWeight.w400,
                            )
                          : GoogleFonts.notoSansThai(
                              fontSize: 17,
                              height: 1.7,
                              color: isDark
                                  ? const Color(0xFFE2E8F0)
                                  : const Color(0xFF334155),
                              fontWeight: FontWeight.w400,
                            ),
                      ),
                    ],
                  ),
                ),
              ],

              // Collapsible Audit Input
              if (_showAuditBox) ...[
                const SizedBox(height: 8),
                Container(
                  key: _auditKey,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      TextField(
                        controller: _auditController,
                        minLines: 3,
                        maxLines: 6,
                        style: GoogleFonts.notoSansThai(fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Enter audit error report/fix details...',
                          hintStyle: GoogleFonts.notoSansThai(fontSize: 14),
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.all(10),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => setState(() {
                              _showAuditBox = false;
                              _updateControllerState();
                            }),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.notoSansThai(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _isSavingAudit
                                ? null
                                : _submitAuditComment,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                            ),
                            child: _isSavingAudit
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _auditSaved ? 'Saved ✓' : 'Submit Audit',
                                    style: GoogleFonts.notoSansThai(
                                      fontSize: 12,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
                  ],
                ),
              ),
              if (isLandscapeSplit) ...[
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 18),
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.14)
                      : const Color(0xFFD5CEBE),
                ),
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: _buildArabicPane(
                      settings: settings,
                      isDark: isDark,
                      arabicStyle: arabicStyle,
                      colorScheme: colorScheme,
                      topSpacing: 8,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildArabicPane({
    required SettingsProvider settings,
    required bool isDark,
    required TextStyle arabicStyle,
    required ColorScheme colorScheme,
    double topSpacing = 16,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: topSpacing),
        if (widget.verse.isArabicLoading)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: colorScheme.primary,
                ),
              ),
            ),
          )
        else if (settings.showTajweedColors) ...[
          Builder(
            builder: (context) {
              final sId = int.tryParse(widget.verse.surahId) ?? 1;
              final vId = int.tryParse(widget.verse.id) ?? 1;
              final tajweedText = TajweedService.getVerse(sId, vId);
              if (tajweedText != null && tajweedText.isNotEmpty) {
                return Directionality(
                  textDirection: TextDirection.rtl,
                  child: TajweedText(
                    text: tajweedText,
                    fontSize: arabicStyle.fontSize ?? 26.0,
                    verseNumber: widget.verse.id,
                    textColor: arabicStyle.color,
                    height: arabicStyle.height ?? 2.0,
                  ),
                );
              }
              return Directionality(
                textDirection: TextDirection.rtl,
                child: RichText(
                  locale: const Locale('ar'),
                  text: TextSpan(
                    style: arabicStyle,
                    children: [
                      TextSpan(
                        text: formatArabicAyahText(
                          widget.verse.arabic,
                          verseNumber: widget.verse.id,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ] else
          Directionality(
            textDirection: TextDirection.rtl,
            child: RichText(
              locale: const Locale('ar'),
              text: TextSpan(
                style: arabicStyle,
                children: [
                  TextSpan(
                    text: formatArabicAyahText(
                      widget.verse.arabic,
                      verseNumber: widget.verse.id,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (settings.showWordByWord) ...[
          const SizedBox(height: 14),
          WordByWordView(
            verseKey: '${widget.verse.surahId}:${widget.verse.id}',
            isDarkMode: isDark,
          ),
        ],
      ],
    );
  }

  Widget _buildDynamicTranslation(
    BuildContext context,
    String translationId,
    SettingsProvider settings,
    bool isDark,
    Color bodyTextColor,
    ThaiTextProtectionProvider thaiTextProtection, {
    required bool isPrimary,
  }) {
    String text = '';
    Locale? locale;

    final canonicalId = TranslationConstants.resolveTranslationId(translationId);
    final apiId = TranslationConstants.resolveApiId(translationId);

    if (canonicalId == 'thai_v3') {
      text = thaiTextProtection.protect(widget.verse.thaiV3);
      locale = const Locale('th', 'TH');
    } else if (canonicalId == 'en_usmani' || canonicalId == 'english') {
      final transManager = Provider.of<TranslationManagerProvider>(context);
      final en = transManager.getVerseTranslation('en_usmani', widget.verse.verseKey);
      text = (en != null && en.isNotEmpty)
          ? en
          : (widget.verse.english.isNotEmpty && widget.verse.english != 'N/A'
              ? widget.verse.english
              : 'Loading translation...');
    } else if (canonicalId == 'ms_basmeih' || canonicalId == 'malay') {
      final transManager = Provider.of<TranslationManagerProvider>(context);
      text = transManager.getVerseTranslation('ms_basmeih', widget.verse.verseKey) ?? 'Loading translation...';
    } else {
      final transManager = Provider.of<TranslationManagerProvider>(context);
      final targetId = apiId ?? canonicalId;
      final tInfo = apiId != null
          ? transManager.downloadedTranslations.firstWhere(
              (t) => t['id'] == apiId,
              orElse: () => <String, dynamic>{},
            )
          : <String, dynamic>{};

      final customText = transManager.getVerseTranslation(
            targetId,
            widget.verse.verseKey,
          ) ??
          transManager.getVerseTranslation(
            translationId,
            widget.verse.verseKey,
          );
      text = customText ?? 'Loading translation...';

      final language = (tInfo['language_name'] ??
              tInfo['language'] ??
              (canonicalId.startsWith('en') || translationId.startsWith('en')
                  ? 'english'
                  : canonicalId.startsWith('ms') || translationId.startsWith('ms')
                      ? 'malay'
                      : ''))
          .toString()
          .toLowerCase();

      if (language == 'thai' || language == 'th') {
        locale = const Locale('th', 'TH');
        text = thaiTextProtection.protect(text);
      }
    }

    final secondaryTextColor = bodyTextColor.withValues(alpha: 0.72);

    final translationBlock = _buildTranslationBlock(
      text: text,
      locale: locale,
      translationId: translationId,
      textStyle: getTranslationTextStyle(
        context,
        fontSize: settings.translationFontSize + (isPrimary ? 1.0 : -1.0),
        height: 1.65,
        color: isPrimary ? bodyTextColor : secondaryTextColor,
        fontWeight: FontWeight.w400,
        translationId: translationId,
      ),
    );

    if (isPrimary) {
      return Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: translationBlock,
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('secondary_translation_label'),
            style: GoogleFonts.notoSansThai(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 6),
          translationBlock,
        ],
      ),
    );
  }

  Widget _buildTranslationBlock({
    required String text,
    required TextStyle textStyle,
    Locale? locale,
    String? translationId,
  }) {
    final footnoteColor = textStyle.color ?? Theme.of(context).colorScheme.onSurface;

    return RichText(
      locale: locale,
      softWrap: true,
      overflow: TextOverflow.visible,
      text: TextSpan(
        children: HtmlParser.parseTranslationText(
          context,
          text,
          textStyle,
          footnoteColor,
          verseKey: '${widget.verse.surahId}:${widget.verse.id}',
          translationId: translationId,
        ),
      ),
    );
  }

  Widget _buildAyahAndNoteBadges({
    required AppThemeColors colors,
    required ColorScheme colorScheme,
    required bool isDark,
    required bool hasTadabburNote,
    required bool isThai,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              colors.primary.withValues(alpha: isDark ? 0.12 : 0.06),
              colors.background,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(color: colors.borderSoft, width: 1),
          ),
          child: Text(
            context.tr(
              'ayah_number',
              args: {'number': widget.verse.id},
            ),
            style: GoogleFonts.notoSansThai(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        if (hasTadabburNote) ...[
          const SizedBox(width: 8),
          InkWell(
            onTap: _openTadabburModal,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: colors.mushafGoldSoft,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: colors.mushafGoldBorder, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.edit_note_rounded,
                    size: 14,
                    color: colors.mushafGold,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isThai ? 'โน้ต' : 'Note',
                    style: GoogleFonts.notoSansThai(
                      color: colors.mushafGold,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionIcon({
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    bool active = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disabled = onPressed == null;
    return IconButton(
      tooltip: tooltip,
      iconSize: 20,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        backgroundColor: active && !disabled
            ? color.withValues(alpha: 0.12)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: active && !disabled
                ? color.withValues(alpha: 0.3)
                : Colors.transparent,
            width: 1,
          ),
        ),
      ),
      icon: Icon(
        icon,
        color: disabled
            ? Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.38)
            : active
            ? color
            : (isDark ? Colors.blueGrey.shade300 : Colors.blueGrey.shade600),
      ),
      onPressed: onPressed,
    );
  }
}
