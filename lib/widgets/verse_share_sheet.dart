import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/quran_repository.dart';
import '../providers/settings_provider.dart';
import '../providers/thai_text_protection_provider.dart';
import '../providers/translation_manager_provider.dart';
import '../services/footnote_service.dart';
import '../services/offline_quran_database_service.dart';
import '../shared/quran_translation_helper.dart';
import '../shared/share_formatter.dart';
import '../shared/translation_constants.dart';
import '../theme/app_theme.dart';

enum ShareCardTheme { emerald, parchment, midnight, minimal }

enum ShareCardLayout { vertical, landscape }

class _ShareCardPalette {
  final Color containerBg;
  final Color containerBorder;
  final Color headerText;
  final Color headerSubText;
  final Color badgeBg;
  final Color badgeText;
  final Color badgeBorder;
  final Color arabicText;
  final Color meaningText;
  final Color innerCardBg;
  final Color innerCardBorder;
  final Color reflectionBg;
  final Color reflectionBorder;
  final Color reflectionAccent;
  final Color divider;
  final Color footerText;
  final Color watermark;

  const _ShareCardPalette({
    required this.containerBg,
    required this.containerBorder,
    required this.headerText,
    required this.headerSubText,
    required this.badgeBg,
    required this.badgeText,
    required this.badgeBorder,
    required this.arabicText,
    required this.meaningText,
    required this.innerCardBg,
    required this.innerCardBorder,
    required this.reflectionBg,
    required this.reflectionBorder,
    required this.reflectionAccent,
    required this.divider,
    required this.footerText,
    required this.watermark,
  });

  static _ShareCardPalette of(ShareCardTheme theme) {
    switch (theme) {
      case ShareCardTheme.emerald:
        return _ShareCardPalette(
          containerBg: const Color(0xFFFDFBF7),
          containerBorder: const Color(0xFF0E5A4A).withValues(alpha: 0.30),
          headerText: const Color(0xFF0E5A4A),
          headerSubText: const Color(0xFF0E5A4A).withValues(alpha: 0.75),
          badgeBg: const Color(0xFF0E5A4A).withValues(alpha: 0.12),
          badgeText: const Color(0xFF0E5A4A),
          badgeBorder: const Color(0xFF0E5A4A).withValues(alpha: 0.25),
          arabicText: const Color(0xFF1C1917),
          meaningText: const Color(0xFF292524),
          innerCardBg: const Color(0xFFFAFAF9),
          innerCardBorder: const Color(0xFFE7E5E4),
          reflectionBg: const Color(0xFFF2F7F5),
          reflectionBorder: const Color(0xFFB7D4C7),
          reflectionAccent: const Color(0xFF0E5A4A),
          divider: const Color(0xFF0E5A4A).withValues(alpha: 0.12),
          footerText: const Color(0xFF78716C),
          watermark: const Color(0xFF0E5A4A),
        );
      case ShareCardTheme.parchment:
        return _ShareCardPalette(
          containerBg: const Color(0xFFFAF6EE),
          containerBorder: const Color(0xFFCBAD5F).withValues(alpha: 0.50),
          headerText: const Color(0xFF73531F),
          headerSubText: const Color(0xFF8A6530).withValues(alpha: 0.82),
          badgeBg: const Color(0xFFCBAD5F).withValues(alpha: 0.25),
          badgeText: const Color(0xFF73531F),
          badgeBorder: const Color(0xFFCBAD5F).withValues(alpha: 0.40),
          arabicText: const Color(0xFF1C1917),
          meaningText: const Color(0xFF292524),
          innerCardBg: const Color(0xFFF5EFE1),
          innerCardBorder: const Color(0xFFCBAD5F).withValues(alpha: 0.35),
          reflectionBg: const Color(0xFFF5EFE1),
          reflectionBorder: const Color(0xFFD7C299),
          reflectionAccent: const Color(0xFF8A6530),
          divider: const Color(0xFF8A6530).withValues(alpha: 0.14),
          footerText: const Color(0xFF57534E),
          watermark: const Color(0xFF8A6530),
        );
      case ShareCardTheme.midnight:
        return _ShareCardPalette(
          containerBg: const Color(0xFF0B131E),
          containerBorder: const Color(0xFF1E293B),
          headerText: const Color(0xFFF1F5F9),
          headerSubText: const Color(0xFF94A3B8),
          badgeBg: const Color(0xFF064E3B).withValues(alpha: 0.55),
          badgeText: const Color(0xFF34D399),
          badgeBorder: const Color(0xFF065F46).withValues(alpha: 0.65),
          arabicText: const Color(0xFFFFFFFF),
          meaningText: const Color(0xFFE2E8F0),
          innerCardBg: const Color(0xFF0F172A),
          innerCardBorder: const Color(0xFF1E293B),
          reflectionBg: const Color(0xFF0F172A),
          reflectionBorder: const Color(0xFF1E293B),
          reflectionAccent: const Color(0xFF34D399),
          divider: const Color(0xFF1E293B),
          footerText: const Color(0xFF94A3B8),
          watermark: const Color(0xFF34D399),
        );
      case ShareCardTheme.minimal:
        return const _ShareCardPalette(
          containerBg: Color(0xFFFFFFFF),
          containerBorder: Color(0xFFE7E5E4),
          headerText: Color(0xFF1C1917),
          headerSubText: Color(0xFF78716C),
          badgeBg: Color(0xFFF5F5F4),
          badgeText: Color(0xFF44403C),
          badgeBorder: Color(0xFFE7E5E4),
          arabicText: Color(0xFF1C1917),
          meaningText: Color(0xFF292524),
          innerCardBg: Color(0xFFFAFAF9),
          innerCardBorder: Color(0xFFE7E5E4),
          reflectionBg: Color(0xFFFAFAF9),
          reflectionBorder: Color(0xFFE7E5E4),
          reflectionAccent: Color(0xFF78716C),
          divider: Color(0xFFE7E5E4),
          footerText: Color(0xFF78716C),
          watermark: Color(0xFF44403C),
        );
    }
  }
}

/// Web-standard Share Studio modal bottom sheet supporting both Quran Ayah cards
/// and Tadabbur Reflection cards with 4 themes, modular toggles, and 390px vertical PNG capture.
class VerseShareSheet extends StatefulWidget {
  final String surahId;
  final String verseId;
  final String surahName;
  final String? arabicText;
  final String? translationText;
  final String? translationLabel;
  final String? shortTafsir;
  final String? shortTafsirSource;
  final List<FootnoteItem>? footnotes;
  final String? reflectionText;
  final String? reflectionAuthor;
  final String? shareUrlOverride;
  final List<Map<String, dynamic>>? wbwWords;
  final QuranRepository? repository;
  final bool? isThai;

  const VerseShareSheet({
    super.key,
    required this.surahId,
    required this.verseId,
    required this.surahName,
    this.arabicText,
    this.translationText,
    this.translationLabel,
    this.shortTafsir,
    this.shortTafsirSource,
    this.footnotes,
    this.reflectionText,
    this.reflectionAuthor,
    this.shareUrlOverride,
    this.wbwWords,
    this.repository,
    this.isThai,
  });

  static Future<void> show(
    BuildContext context, {
    required String surahId,
    required String verseId,
    required String surahName,
    String? arabicText,
    String? translationText,
    String? translationLabel,
    String? shortTafsir,
    String? shortTafsirSource,
    List<FootnoteItem>? footnotes,
    String? reflectionText,
    String? reflectionAuthor,
    String? shareUrlOverride,
    List<Map<String, dynamic>>? wbwWords,
    QuranRepository? repository,
    bool? isThai,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VerseShareSheet(
        surahId: surahId,
        verseId: verseId,
        surahName: surahName,
        arabicText: arabicText,
        translationText: translationText,
        translationLabel: translationLabel,
        shortTafsir: shortTafsir,
        shortTafsirSource: shortTafsirSource,
        footnotes: footnotes,
        reflectionText: reflectionText,
        reflectionAuthor: reflectionAuthor,
        shareUrlOverride: shareUrlOverride,
        wbwWords: wbwWords,
        repository: repository,
        isThai: isThai,
      ),
    );
  }

  @override
  State<VerseShareSheet> createState() => _VerseShareSheetState();
}

class _VerseShareSheetState extends State<VerseShareSheet> {
  static const MethodChannel _mediaShareChannel = MethodChannel(
    'com.thaiquran.app/media_share',
  );

  final GlobalKey _cardKey = GlobalKey();
  final GlobalKey _shareButtonKey = GlobalKey();

  late String _arabicText;
  late String _translationText;
  late String _translationLabel;
  String? _shortTafsir;
  late String _shortTafsirSource;
  List<FootnoteItem> _footnotes = const [];
  List<Map<String, dynamic>> _wbwWords = const [];

  late bool _includeReflection;
  late bool _includeAuthor;
  bool _includeArabic = true;
  bool _includeTranslation = true;
  bool _includeWbw = false;
  bool _includeTafsir = false;
  bool _includeFootnotes = false;
  ShareCardTheme _theme = ShareCardTheme.emerald;
  ShareCardLayout _layout = ShareCardLayout.vertical;
  double _fontScale = 1.0;
  bool _isGenerating = false;
  bool _isCopyingImage = false;
  bool _isSavingImage = false;

  String? _toastMessage;
  Timer? _toastTimer;
  String _effectiveLang = 'th';
  String _primaryTranslationId = 'thai_v3';

  String get _verseKey => '${widget.surahId}:${widget.verseId}';
  bool get _hasReflectionInput =>
      widget.reflectionText != null && widget.reflectionText!.trim().isNotEmpty;
  bool get _hasAuthorInput =>
      widget.reflectionAuthor != null &&
      widget.reflectionAuthor!.trim().isNotEmpty;

  String get _shareUrl {
    final override = widget.shareUrlOverride?.trim();
    if (override != null && override.isNotEmpty) return override;
    return 'https://quran-th.com/surah/${widget.surahId}#v-${widget.verseId}';
  }

  @override
  void initState() {
    super.initState();
    _arabicText = (widget.arabicText ?? '').trim();
    _translationText = _cleanPlainTranslation(widget.translationText ?? '');
    _translationLabel = (widget.translationLabel ?? '').trim();
    _shortTafsir = widget.shortTafsir?.trim().isNotEmpty == true
        ? widget.shortTafsir!.trim()
        : null;
    _shortTafsirSource = widget.shortTafsirSource?.trim().isNotEmpty == true
        ? widget.shortTafsirSource!.trim()
        : 'Al-Mukhtasar';
    _footnotes = widget.footnotes ?? const [];
    _wbwWords = _filterWbwWords(widget.wbwWords);

    _includeReflection = _hasReflectionInput;
    _includeAuthor = _hasAuthorInput;

    _readProviderContext();
    _hydrateMissingData();
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  void _readProviderContext() {
    SettingsProvider? settings;
    TranslationManagerProvider? transManager;
    try {
      settings = Provider.of<SettingsProvider>(context, listen: false);
    } catch (_) {}
    try {
      transManager = Provider.of<TranslationManagerProvider>(
        context,
        listen: false,
      );
    } catch (_) {}

    if (settings != null) {
      _primaryTranslationId = settings.primaryTranslationId;
      _effectiveLang = resolveEffectiveTranslationLanguage(
        context,
        settings: settings,
        transManager: transManager,
      );
    } else if (widget.isThai != null) {
      _effectiveLang = widget.isThai! ? 'th' : 'en';
    }

    if (_translationLabel.isEmpty) {
      _translationLabel = _resolveDefaultTranslationLabel(
        _primaryTranslationId,
        transManager: transManager,
      );
    }

    if (_translationText.isEmpty && widget.repository != null) {
      final verse = widget.repository!.getVerse(widget.surahId, widget.verseId);
      if (verse != null) {
        if (settings != null) {
          final resolved = resolveVerseTranslationText(
            context: context,
            verseKey: _verseKey,
            verse: verse,
            settings: settings,
            transManager: transManager,
            repository: widget.repository,
          );
          if (resolved.isNotEmpty && resolved != 'Loading translation...') {
            _translationText = _cleanPlainTranslation(resolved);
          }
        } else {
          final fallback = _effectiveLang == 'en'
              ? (verse.english != 'N/A' ? verse.english : verse.thaiV3)
              : verse.thaiV3;
          _translationText = _cleanPlainTranslation(fallback);
        }
      }
    }

    if ((_shortTafsir == null || _shortTafsir!.isEmpty) &&
        widget.repository != null) {
      final verse = widget.repository!.getVerse(widget.surahId, widget.verseId);
      if (verse != null) {
        if (_effectiveLang == 'ms' &&
            verse.shortTafsirId?.trim().isNotEmpty == true) {
          _shortTafsir = verse.shortTafsirId!.trim();
          _shortTafsirSource = verse.shortTafsirSourceId ?? 'Mokhtasar (ID)';
        } else if (_effectiveLang != 'th' &&
            verse.shortTafsirEn?.trim().isNotEmpty == true) {
          _shortTafsir = verse.shortTafsirEn!.trim();
          _shortTafsirSource =
              verse.shortTafsirSourceEn ?? 'QuranEnc English Mokhtasar';
        } else if (verse.shortTafsir?.trim().isNotEmpty == true) {
          _shortTafsir = verse.shortTafsir!.trim();
          _shortTafsirSource =
              verse.shortTafsirSource ?? 'QuranEnc Thai Mokhtasar';
        }
      }
    }
  }

  String _resolveDefaultTranslationLabel(
    String translationId, {
    TranslationManagerProvider? transManager,
  }) {
    final canonical = TranslationConstants.resolveTranslationId(translationId);
    if (canonical == 'thai_v3') return 'ไทย - King Fahd';
    final known = TranslationConstants.getKnownOption(canonical);
    if (known != null) return known.name.replaceAll('(Offline)', '').trim();
    if (transManager != null) {
      final apiId = TranslationConstants.resolveApiId(translationId);
      if (apiId != null) {
        for (final t in transManager.downloadedTranslations) {
          if (t['id'] == apiId &&
              (t['name']?.toString().trim().isNotEmpty ?? false)) {
            return t['name'].toString().trim();
          }
        }
      }
    }
    return 'ไทย - King Fahd';
  }

  Future<void> _hydrateMissingData() async {
    final futures = <Future<void>>[];

    if (_arabicText.isEmpty) {
      futures.add(_fetchArabic());
    }
    if (_wbwWords.isEmpty && widget.wbwWords == null) {
      futures.add(_fetchWbw());
    }
    if (widget.footnotes == null) {
      futures.add(_fetchFootnotes());
    }
    if (_translationText.isEmpty) {
      futures.add(_fetchTranslationFallback());
    }
    if (_shortTafsir == null || _shortTafsir!.isEmpty) {
      futures.add(_fetchTafsirFallback());
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  Future<void> _fetchArabic() async {
    try {
      String fetched = '';
      if (widget.repository != null) {
        fetched = await widget.repository!.fetchArabicVerse(
          widget.surahId,
          widget.verseId,
        );
      }
      if (fetched.trim().isEmpty) {
        final row = await OfflineQuranDatabaseService.getVerse(_verseKey);
        final dbText = row?['text_uthmani']?.toString() ?? '';
        if (dbText.isNotEmpty) {
          fetched = sanitizeUthmanicText(dbText);
        }
      }
      if (mounted && fetched.trim().isNotEmpty) {
        setState(() => _arabicText = fetched.trim());
      }
    } catch (_) {}
  }

  Future<void> _fetchWbw() async {
    try {
      final words = await OfflineQuranDatabaseService.getVerseWords(_verseKey);
      final filtered = _filterWbwWords(words);
      if (mounted && filtered.isNotEmpty) {
        setState(() => _wbwWords = filtered);
      }
    } catch (_) {}
  }

  Future<void> _fetchFootnotes() async {
    try {
      final fns = await FootnoteService().getVerseFootnotes(
        _verseKey,
        translationId: _primaryTranslationId,
      );
      if (mounted && fns.isNotEmpty) {
        setState(() => _footnotes = fns);
      }
    } catch (_) {}
  }

  Future<void> _fetchTranslationFallback() async {
    try {
      final text = await OfflineQuranDatabaseService.getTranslation(
        _verseKey,
        lang: _effectiveLang,
      );
      if (mounted && text != null && text.trim().isNotEmpty) {
        setState(() => _translationText = _cleanPlainTranslation(text));
      }
    } catch (_) {}
  }

  Future<void> _fetchTafsirFallback() async {
    try {
      final tafsir = await OfflineQuranDatabaseService.getTafsir(_verseKey);
      if (mounted && tafsir != null && tafsir.trim().isNotEmpty) {
        setState(() {
          _shortTafsir = tafsir.trim();
          _shortTafsirSource = 'QuranEnc Thai Mokhtasar';
        });
      }
    } catch (_) {}
  }

  static List<Map<String, dynamic>> _filterWbwWords(
    List<Map<String, dynamic>>? words,
  ) {
    if (words == null || words.isEmpty) return const [];
    final numeralOnly = RegExp(r'^[\u0660-\u06690-9()]+$');
    return words.where((w) {
      final charType = (w['char_type'] ?? w['type'] ?? '').toString();
      if (charType == 'end') return false;
      final ar = (w['text_uthmani'] ?? w['text'] ?? w['arabic'] ?? '')
          .toString()
          .trim();
      if (ar.isEmpty || numeralOnly.hasMatch(ar)) return false;
      return true;
    }).toList();
  }

  static String _cleanPlainTranslation(String raw) {
    if (raw.trim().isEmpty) return '';
    return raw
        .replaceAllMapped(
          RegExp(
            r'''<sup\s+[^>]*foot_note[^>]*>(\d+)<\/sup>''',
            caseSensitive: false,
          ),
          (m) => '[${m.group(1)}]',
        )
        .replaceAll(RegExp(r'''<br\s*/?>''', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _showToast(String message) {
    _toastTimer?.cancel();
    if (!mounted) return;
    setState(() => _toastMessage = message);
    _toastTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _toastMessage = null);
      }
    });
  }

  bool _isThaiUi() {
    if (widget.isThai != null) return widget.isThai!;
    try {
      return Provider.of<SettingsProvider>(context, listen: false).isThai;
    } catch (_) {
      return true;
    }
  }

  String _wbwWordArabic(Map<String, dynamic> w) {
    final raw = (w['text_uthmani'] ?? w['text'] ?? w['arabic'] ?? '')
        .toString();
    return sanitizeWbwUthmanicText(raw).trim();
  }

  String _wbwWordMeaning(Map<String, dynamic> w) {
    String pick;
    if (_effectiveLang == 'ms') {
      pick = (w['translation_ms'] ?? w['ms'] ?? '').toString();
    } else if (_effectiveLang == 'en') {
      pick = (w['translation_en'] ?? w['en'] ?? w['english'] ?? w['translation'] ?? '')
          .toString();
    } else {
      pick = (w['translation_th'] ?? w['th'] ?? w['thai'] ?? '').toString();
    }
    if (pick.trim().isEmpty) {
      pick = (w['translation_th'] ??
              w['th'] ??
              w['translation_en'] ??
              w['en'] ??
              w['translation'] ??
              w['transliteration'] ??
              w['tr'] ??
              '')
          .toString();
    }
    return pick.trim();
  }

  bool get _hasReflection => _includeReflection && _hasReflectionInput;
  bool get _hasTafsir =>
      _includeTafsir && (_shortTafsir?.trim().isNotEmpty ?? false);
  bool get _hasFootnotes => _includeFootnotes && _footnotes.isNotEmpty;
  bool get _hasWbw => _includeWbw && _wbwWords.isNotEmpty;

  bool get _isLandscape => _layout == ShareCardLayout.landscape;
  double get _cardWidth => _isLandscape ? 640.0 : 390.0;
  int get _fontScalePercent => (_fontScale * 100).round();

  bool get _isMultiContent =>
      (_hasTafsir && _hasFootnotes) ||
      ((_hasTafsir || _hasFootnotes || _hasWbw || _hasReflection) &&
          (_includeArabic || _includeTranslation));

  bool get _useCompactMode =>
      _fontScale <= 0.90 || (_fontScalePercent == 100 && _isMultiContent);

  Future<void> _handleCopyText() async {
    final isThai = _isThaiUi();
    final lines = <String>['${widget.surahName} ($_verseKey)', ''];

    if (_hasReflection) {
      lines.add(widget.reflectionText!.trim());
      if (_includeAuthor && _hasAuthorInput) {
        lines.add('— ${widget.reflectionAuthor!.trim()}');
      }
      lines.add('');
    }

    if (_includeArabic && _arabicText.isNotEmpty) {
      lines.add(
        formatArabicAyahText(_arabicText, verseNumber: widget.verseId),
      );
      lines.add('');
    }

    if (_hasWbw) {
      lines.add(isThai ? 'คำต่อคำ:' : 'Word by Word:');
      final wbwPairs = _wbwWords.map((w) {
        final ar = _wbwWordArabic(w);
        final tr = _wbwWordMeaning(w);
        return tr.isNotEmpty ? '$ar = $tr' : ar;
      }).toList();
      lines.add(wbwPairs.join(' | '));
      lines.add('');
    }

    if (_includeTranslation && _translationText.isNotEmpty) {
      lines.add(_translationText.trim());
      final cleanLabel = _translationLabel.replaceAll('(ปรับปรุง)', '').trim();
      if (cleanLabel.isNotEmpty) {
        lines.add('($cleanLabel)');
      }
      lines.add('');
    }

    if (_hasTafsir) {
      lines.add(
        '📖 ${isThai ? 'ตัฟซีรสั้น' : 'Short Tafsir'} ($_shortTafsirSource): ${_shortTafsir!.trim()}',
      );
      lines.add('');
    }

    if (_hasFootnotes) {
      lines.add(isThai ? 'เชิงอรรถ:' : 'Footnotes:');
      for (final fn in _footnotes) {
        final numLabel = fn.origId > 0 ? fn.origId : fn.id;
        lines.add('[$numLabel] ${fn.text}');
      }
      lines.add('');
    }

    lines.add('${isThai ? 'อ่านต่อ' : 'Read more'}: $_shareUrl');

    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    _showToast(isThai ? 'คัดลอกข้อความแล้ว' : 'Copied text');
  }

  Future<Uint8List> _captureCardPngBytes() async {
    await WidgetsBinding.instance.endOfFrame;
    final boundary = _cardKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('Share card render boundary is unavailable.');
    }

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData?.buffer.asUint8List();
    if (bytes == null) {
      throw StateError('Failed to encode share card PNG.');
    }
    return bytes;
  }

  Future<({Uint8List bytes, String ext, String mime})>
  _captureCardJpegOrFallback() async {
    final pngBytes = await _captureCardPngBytes();
    if (!kIsWeb) {
      try {
        final encoded = await _mediaShareChannel.invokeMethod<Object?>(
          'encodeJpeg',
          {'bytes': pngBytes, 'quality': 95},
        );
        if (encoded is Uint8List && encoded.isNotEmpty) {
          return (bytes: encoded, ext: 'jpg', mime: 'image/jpeg');
        }
      } on MissingPluginException {
        // Native channel unavailable (e.g., unit tests); fall back to PNG bytes.
      } catch (_) {}
    }
    return (bytes: pngBytes, ext: 'png', mime: 'image/png');
  }

  Future<void> _handleCopyImage() async {
    if (_isCopyingImage || _isSavingImage || _isGenerating) return;
    final isThai = _isThaiUi();
    setState(() => _isCopyingImage = true);

    try {
      final bytes = await _captureCardPngBytes();
      await _mediaShareChannel.invokeMethod<bool>('copyImage', {
        'bytes': bytes,
        'fileName': 'quran_${widget.surahId}_${widget.verseId}.png',
      });
      _showToast(
        isThai ? 'คัดลอกรูปภาพแล้ว กดวางได้เลย' : 'Image copied to clipboard',
      );
    } catch (e) {
      debugPrint('Error copying verse card image: $e');
      _showToast(
        isThai ? 'ไม่สามารถคัดลอกรูปภาพได้' : 'Could not copy image',
      );
    } finally {
      if (mounted) {
        setState(() => _isCopyingImage = false);
      }
    }
  }

  Future<void> _handleSaveImage() async {
    if (_isSavingImage || _isCopyingImage || _isGenerating) return;
    final isThai = _isThaiUi();
    setState(() => _isSavingImage = true);

    try {
      final pngBytes = await _captureCardPngBytes();
      await _mediaShareChannel.invokeMethod<bool>('saveImage', {
        'bytes': pngBytes,
        'fileName': 'quran_${widget.surahId}_${widget.verseId}.jpg',
      });
      _showToast(
        isThai ? 'บันทึกรูปภาพลงอัลบั้มสำเร็จ' : 'Image saved to Photos',
      );
    } on PlatformException catch (e) {
      debugPrint('Error saving verse card image: $e');
      if (e.code == 'permission_denied') {
        _showToast(
          isThai
              ? 'กรุณาอนุญาตการเข้าถึงคลังรูปภาพเพื่อบันทึก'
              : 'Please allow photo library access to save',
        );
      } else {
        _showToast(
          isThai ? 'ไม่สามารถบันทึกรูปภาพได้' : 'Could not save image',
        );
      }
    } catch (e) {
      debugPrint('Error saving verse card image: $e');
      _showToast(
        isThai ? 'ไม่สามารถบันทึกรูปภาพได้' : 'Could not save image',
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingImage = false);
      }
    }
  }

  Future<void> _handleShareImage() async {
    if (_isGenerating || _isCopyingImage || _isSavingImage) return;
    final isThai = _isThaiUi();
    setState(() => _isGenerating = true);

    try {
      final captured = await _captureCardJpegOrFallback();

      Rect? origin;
      final btnBox = _shareButtonKey.currentContext?.findRenderObject()
          as RenderBox?;
      if (btnBox != null && btnBox.hasSize) {
        origin = btnBox.localToGlobal(Offset.zero) & btnBox.size;
      }

      final caption = formatImageShareCaption(
        widget.surahId,
        widget.verseId,
        _shareUrl,
      );

      File? tempFile;
      final XFile xFile;
      if (kIsWeb) {
        xFile = XFile.fromData(
          captured.bytes,
          mimeType: captured.mime,
          name: 'quran-${widget.surahId}-${widget.verseId}.${captured.ext}',
        );
      } else {
        final dir = await getTemporaryDirectory();
        tempFile = File(
          '${dir.path}/quran_${widget.surahId}_${widget.verseId}.${captured.ext}',
        );
        await tempFile.writeAsBytes(captured.bytes, flush: true);
        xFile = XFile(tempFile.path, mimeType: captured.mime);
      }

      // Reset loading spinner BEFORE opening the native share sheet so it
      // never stays stuck behind the iPad popover.
      if (mounted) {
        setState(() => _isGenerating = false);
      }

      // Copy caption to clipboard for convenient pasting in apps like Facebook Feed.
      await Clipboard.setData(ClipboardData(text: caption));

      if (!kIsWeb && Platform.isIOS && tempFile != null) {
        try {
          final status = await _mediaShareChannel.invokeMethod<String>(
            'shareImage',
            {
              'filePath': tempFile.path,
              'text': caption,
              'originX': origin?.left,
              'originY': origin?.top,
              'originWidth': origin?.width,
              'originHeight': origin?.height,
            },
          );
          if (status == 'completed') {
            _showToast(isThai ? 'แชร์รูปภาพสำเร็จ' : 'Shared successfully');
          }
          return;
        } on MissingPluginException {
          // Fall back to SharePlus if native channel is unavailable (e.g. tests).
        }
      }

      final shareResult = await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          text: caption,
          sharePositionOrigin: origin,
        ),
      );
      if (shareResult.status == ShareResultStatus.success) {
        _showToast(isThai ? 'แชร์รูปภาพสำเร็จ' : 'Shared successfully');
      }
    } catch (e) {
      debugPrint('Error sharing verse card image: $e');
      _showToast(
        isThai ? 'ไม่สามารถสร้างรูปภาพสำหรับแชร์ได้' : 'Could not share image',
      );
    } finally {
      if (mounted && _isGenerating) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isThai = _isThaiUi();
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;
    final palette = _ShareCardPalette.of(_theme);

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 560),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.radius),
            ),
            border: Border(top: BorderSide(color: colors.borderSoft)),
          ),
          child: SafeArea(
            top: false,
            child: Stack(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSheetHeader(colors, isThai),
                    Divider(height: 1, color: colors.borderSoft),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildControlsPanel(colors, isThai),
                            const SizedBox(height: 14),
                            Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: RepaintBoundary(
                                  key: _cardKey,
                                  child: SizedBox(
                                    width: _cardWidth,
                                    child: _buildShareCard(
                                      palette: palette,
                                      isThai: isThai,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _buildStickyBottomBar(colors, isThai),
                  ],
                ),
                if (_toastMessage != null)
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 126,
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colors.textStrong,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSm,
                          ),
                        ),
                        child: Text(
                          _toastMessage!,
                          style: GoogleFonts.notoSansThai(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.textInverse,
                          ),
                        ),
                      ),
                    ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSheetHeader(AppThemeColors colors, bool isThai) {
    final title = _hasReflectionInput
        ? (isThai ? 'แชร์ข้อคิดตะดับบุร' : 'Share Reflection')
        : (isThai ? 'แชร์อายะฮฺ' : 'Share Verse');
    final subtitle = isThai
        ? '${widget.surahName} • อายะฮฺที่ ${widget.verseId} ($_verseKey)'
        : '${widget.surahName} • Ayah ${widget.verseId} ($_verseKey)';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colors.borderSoft,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 12, 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: colors.primaryLight,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: colors.primaryLightBorder),
                ),
                child: Icon(
                  Icons.share_outlined,
                  size: 18,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.notoSansThai(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: colors.textStrong,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSansThai(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: isThai ? 'ปิด' : 'Close',
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                  backgroundColor: colors.surfaceMuted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    side: BorderSide(color: colors.borderSoft),
                  ),
                  minimumSize: const Size(34, 34),
                  padding: EdgeInsets.zero,
                ),
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: colors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControlsPanel(AppThemeColors colors, bool isThai) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Text(
                  isThai ? 'แสดงในภาพ:' : 'Include:',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.textMuted,
                  ),
                ),
              ),
              if (_hasReflectionInput)
                _buildTogglePill(
                  colors: colors,
                  label: isThai ? 'ข้อคิดตะดับบุร' : 'Reflection',
                  selected: _includeReflection,
                  onTap: () => setState(
                    () => _includeReflection = !_includeReflection,
                  ),
                ),
              if (_hasAuthorInput)
                _buildTogglePill(
                  colors: colors,
                  label: isThai ? 'ผู้เขียน' : 'Author',
                  selected: _includeAuthor,
                  onTap: () =>
                      setState(() => _includeAuthor = !_includeAuthor),
                ),
              if (_arabicText.isNotEmpty)
                _buildTogglePill(
                  colors: colors,
                  label: isThai ? 'ภาษาอาหรับ' : 'Arabic',
                  selected: _includeArabic,
                  onTap: () =>
                      setState(() => _includeArabic = !_includeArabic),
                ),
              if (_translationText.isNotEmpty)
                _buildTogglePill(
                  colors: colors,
                  label: isThai ? 'คำแปล' : 'Translation',
                  selected: _includeTranslation,
                  onTap: () => setState(
                    () => _includeTranslation = !_includeTranslation,
                  ),
                ),
              if (_wbwWords.isNotEmpty)
                _buildTogglePill(
                  colors: colors,
                  label: isThai ? 'คำต่อคำ (WBW)' : 'Word-by-Word',
                  selected: _includeWbw,
                  onTap: () => setState(() => _includeWbw = !_includeWbw),
                ),
              if (_shortTafsir != null && _shortTafsir!.isNotEmpty)
                _buildTogglePill(
                  colors: colors,
                  label: isThai ? 'ตัฟซีรสั้น' : 'Short Tafsir',
                  selected: _includeTafsir,
                  onTap: () =>
                      setState(() => _includeTafsir = !_includeTafsir),
                ),
              if (_footnotes.isNotEmpty)
                _buildTogglePill(
                  colors: colors,
                  label: isThai
                      ? 'เชิงอรรถ (${_footnotes.length})'
                      : 'Footnotes (${_footnotes.length})',
                  selected: _includeFootnotes,
                  onTap: () =>
                      setState(() => _includeFootnotes = !_includeFootnotes),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: colors.borderSoft),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                isThai ? 'โทนสี:' : 'Theme:',
                style: GoogleFonts.notoSansThai(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textMuted,
                ),
              ),
              _buildThemePill(
                colors: colors,
                theme: ShareCardTheme.emerald,
                label: isThai ? 'มรกต' : 'Emerald',
                swatchColor: const Color(0xFF0E5A4A),
                activeBg: const Color(0xFF0E5A4A),
                activeFg: const Color(0xFFFFFFFF),
              ),
              _buildThemePill(
                colors: colors,
                theme: ShareCardTheme.parchment,
                label: isThai ? 'ครีมทอง' : 'Parchment',
                swatchColor: const Color(0xFF8A6530),
                activeBg: const Color(0xFF8A6530),
                activeFg: const Color(0xFFFAF6EE),
              ),
              _buildThemePill(
                colors: colors,
                theme: ShareCardTheme.midnight,
                label: isThai ? 'ราตรี' : 'Midnight',
                swatchColor: const Color(0xFF0B131E),
                activeBg: const Color(0xFF0B131E),
                activeFg: const Color(0xFF34D399),
              ),
              _buildThemePill(
                colors: colors,
                theme: ShareCardTheme.minimal,
                label: isThai ? 'มินิมอล' : 'Minimal',
                swatchColor: const Color(0xFF44403C),
                activeBg: const Color(0xFF1C1917),
                activeFg: const Color(0xFFFFFFFF),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: colors.borderSoft),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                isThai ? 'รูปแบบ:' : 'Layout:',
                style: GoogleFonts.notoSansThai(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(width: 6),
              _buildLayoutPill(
                colors: colors,
                layout: ShareCardLayout.vertical,
                label: isThai ? 'แนวตั้ง' : 'Vertical',
              ),
              const SizedBox(width: 6),
              _buildLayoutPill(
                colors: colors,
                layout: ShareCardLayout.landscape,
                label: isThai ? 'แนวนอน' : 'Landscape',
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildFontSizeControl(colors, isThai),
        ],
      ),
    );
  }

  Widget _buildTogglePill({
    required AppThemeColors colors,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: selected ? colors.primary : colors.borderSoft,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check_rounded, size: 13, color: colors.textInverse),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.notoSansThai(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: selected ? colors.textInverse : colors.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemePill({
    required AppThemeColors colors,
    required ShareCardTheme theme,
    required String label,
    required Color swatchColor,
    required Color activeBg,
    required Color activeFg,
  }) {
    final isSelected = _theme == theme;
    return InkWell(
      onTap: () => setState(() => _theme = theme),
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : colors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: isSelected ? activeBg : colors.borderSoft,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: isSelected ? activeFg : swatchColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? activeFg.withValues(alpha: 0.4)
                      : colors.borderSoft,
                ),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.notoSansThai(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isSelected ? activeFg : colors.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLayoutPill({
    required AppThemeColors colors,
    required ShareCardLayout layout,
    required String label,
  }) {
    final isSelected = _layout == layout;
    return InkWell(
      onTap: () => setState(() => _layout = layout),
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary : colors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: isSelected ? colors.primary : colors.borderSoft,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.notoSansThai(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: isSelected ? colors.textInverse : colors.foreground,
          ),
        ),
      ),
    );
  }

  Widget _buildFontSizeControl(AppThemeColors colors, bool isThai) {
    final percent = _fontScalePercent;
    return Row(
      children: [
        Text(
          isThai ? 'ตัวอักษร:' : 'Font:',
          style: GoogleFonts.notoSansThai(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colors.textMuted,
          ),
        ),
        const SizedBox(width: 6),
        _buildFontStepButton(
          key: const ValueKey('share_font_decrease'),
          colors: colors,
          label: 'A-',
          enabled: _fontScale > 0.751,
          onTap: () => setState(
            () => _fontScale = (_fontScale - 0.05).clamp(0.75, 1.50),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: colors.primary,
              inactiveTrackColor: colors.borderSoft,
              thumbColor: colors.primary,
            ),
            child: Slider(
              key: const ValueKey('share_font_slider'),
              value: _fontScale.clamp(0.75, 1.50),
              min: 0.75,
              max: 1.50,
              divisions: 15,
              onChanged: (v) => setState(() => _fontScale = v),
            ),
          ),
        ),
        _buildFontStepButton(
          key: const ValueKey('share_font_increase'),
          colors: colors,
          label: 'A+',
          enabled: _fontScale < 1.499,
          onTap: () => setState(
            () => _fontScale = (_fontScale + 0.05).clamp(0.75, 1.50),
          ),
        ),
        const SizedBox(width: 6),
        InkWell(
          onTap: percent == 100 ? null : () => setState(() => _fontScale = 1.0),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: colors.borderSoft),
            ),
            child: Text(
              '$percent%',
              style: GoogleFonts.notoSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: colors.textStrong,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFontStepButton({
    Key? key,
    required AppThemeColors colors,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(color: colors.borderSoft),
          ),
          child: Text(
            label,
            style: GoogleFonts.notoSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colors.textStrong,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShareCard({
    required _ShareCardPalette palette,
    required bool isThai,
  }) {
    final compact = _useCompactMode;
    final scale = _fontScale;
    final cleanLabel = _translationLabel.replaceAll('(ปรับปรุง)', '').trim();

    final baseArabic = _isMultiContent ? 21.0 : 24.0;
    final arabicSize = (baseArabic * scale).clamp(15.0, 42.0);
    final wbwArabicSize = (16.0 * scale).clamp(12.0, 26.0);
    final wbwMeaningSize = (10.5 * scale).clamp(8.5, 16.0);
    final baseMeaning = _isMultiContent ? 13.0 : 14.5;
    final meaningSize = (baseMeaning * scale).clamp(11.0, 24.0);
    final reflectionSize = ((_isMultiContent ? 13.0 : 14.0) * scale).clamp(11.0, 23.0);
    final tafsirSize = (11.5 * scale).clamp(10.0, 19.0);
    final footnoteSize = (10.5 * scale).clamp(9.0, 17.0);

    final hasArabicSide = (_includeArabic && _arabicText.isNotEmpty) || _hasWbw;
    final hasMeaningSide =
        _hasReflection || (_includeTranslation && _translationText.isNotEmpty);
    final useTwoColumnLandscape =
        _isLandscape && hasArabicSide && hasMeaningSide;

    final arabicWidget = (_includeArabic && _arabicText.isNotEmpty)
        ? Text(
            formatArabicAyahText(
              _arabicText,
              verseNumber: widget.verseId,
            ),
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            locale: const Locale('ar'),
            style: TextStyle(
              fontFamily: 'UthmanicHafs',
              fontWeight: FontWeight.w400,
              fontSize: arabicSize,
              height: scale > 1.2 ? 2.0 : 2.15,
              letterSpacing: 0,
              color: palette.arabicText,
            ),
          )
        : null;

    final wbwWidget = _hasWbw
        ? Directionality(
            textDirection: TextDirection.rtl,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.start,
              children: [
                for (final word in _wbwWords)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: palette.innerCardBg,
                      border: Border.all(
                        color: palette.innerCardBorder,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _wbwWordArabic(word),
                          textDirection: TextDirection.rtl,
                          locale: const Locale('ar'),
                          style: TextStyle(
                            fontFamily: 'UthmanicHafs',
                            fontWeight: FontWeight.w400,
                            fontSize: wbwArabicSize,
                            height: 1.4,
                            letterSpacing: 0,
                            color: palette.arabicText,
                          ),
                        ),
                        if (_wbwWordMeaning(word).isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            _wbwWordMeaning(word),
                            textDirection: TextDirection.ltr,
                            style: GoogleFonts.notoSansThai(
                              fontSize: wbwMeaningSize,
                              fontWeight: FontWeight.w500,
                              color: palette.meaningText.withValues(
                                alpha: 0.85,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          )
        : null;

    final reflectionWidget = _hasReflection
        ? _buildReflectionCardBox(palette, isThai, reflectionSize)
        : null;

    final translationWidget =
        (_includeTranslation && _translationText.isNotEmpty)
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ThaiTextProtectionProvider.protectSafe(
                      context,
                      _translationText,
                    ),
                    locale: ThaiTextProtectionProvider.localeForText(
                      _translationText,
                      forceThai: isThai,
                    ),
                    style: GoogleFonts.notoSansThai(
                      fontSize: meaningSize,
                      fontWeight: FontWeight.w500,
                      height: 1.6,
                      color: palette.meaningText,
                    ),
                  ),
                  if (cleanLabel.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      cleanLabel,
                      style: GoogleFonts.notoSansThai(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: palette.footerText,
                      ),
                    ),
                  ],
                ],
              )
            : null;

    final tafsirWidget = _hasTafsir
        ? Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.innerCardBg,
              border: Border.all(color: palette.innerCardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_stories_outlined,
                      size: 13,
                      color: palette.watermark,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        isThai
                            ? 'ตัฟซีรฉบับย่อ ($_shortTafsirSource)'
                            : 'Short Tafsir ($_shortTafsirSource)',
                        style: GoogleFonts.notoSansThai(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: palette.headerText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  ThaiTextProtectionProvider.protectSafe(
                    context,
                    _shortTafsir!,
                  ),
                  locale: ThaiTextProtectionProvider.localeForText(
                    _shortTafsir!,
                    forceThai: isThai,
                  ),
                  style: GoogleFonts.notoSansThai(
                    fontSize: tafsirSize,
                    height: 1.55,
                    color: palette.meaningText.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          )
        : null;

    final footnotesWidget = _hasFootnotes
        ? Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.innerCardBg,
              border: Border.all(color: palette.innerCardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.notes_rounded,
                      size: 13,
                      color: palette.watermark,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isThai ? 'เชิงอรรถ' : 'Footnotes',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: palette.headerText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                for (final fn in _footnotes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      '[${fn.origId > 0 ? fn.origId : fn.id}] ${fn.text}',
                      style: GoogleFonts.notoSansThai(
                        fontSize: footnoteSize,
                        height: 1.5,
                        color: palette.meaningText.withValues(alpha: 0.88),
                      ),
                    ),
                  ),
              ],
            ),
          )
        : null;

    return Container(
      key: const ValueKey('verse_share_card'),
      decoration: BoxDecoration(
        color: palette.containerBg,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: palette.containerBorder, width: 1.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card Header
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: _isLandscape ? 22 : 16,
              vertical: _isLandscape ? 13 : 14,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: palette.divider, width: 1),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildBrandIcon(size: 32, radius: AppTheme.radiusSm),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.surahName,
                        softWrap: true,
                        style: GoogleFonts.notoSansThai(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                          color: palette.headerText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isThai
                            ? 'อายะฮฺที่ ${widget.verseId} ($_verseKey)'
                            : 'Ayah ${widget.verseId} ($_verseKey)',
                        style: GoogleFonts.notoSansThai(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: palette.headerSubText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: palette.badgeBg,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: palette.badgeBorder),
                  ),
                  child: Text(
                    _verseKey,
                    style: GoogleFonts.notoSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: palette.badgeText,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Card Body (2-column spread in Landscape when both sides present, stacked otherwise)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: _isLandscape ? 22 : (compact ? 16 : 20),
              vertical: _isLandscape ? 20 : (compact ? 16 : 20),
            ),
            child: useTwoColumnLandscape
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 165),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                flex: 1,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ?reflectionWidget,
                                    if (reflectionWidget != null &&
                                        translationWidget != null)
                                      const SizedBox(height: 12),
                                    ?translationWidget,
                                  ],
                                ),
                              ),
                              Container(
                                width: 1,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                ),
                                color: palette.divider,
                              ),
                              Expanded(
                                flex: 1,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    ?arabicWidget,
                                    if (arabicWidget != null &&
                                        wbwWidget != null)
                                      const SizedBox(height: 10),
                                    ?wbwWidget,
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (tafsirWidget != null || footnotesWidget != null) ...[
                        const SizedBox(height: 14),
                        Divider(height: 1, color: palette.divider),
                        if (tafsirWidget != null) ...[
                          const SizedBox(height: 12),
                          tafsirWidget,
                        ],
                        if (footnotesWidget != null) ...[
                          const SizedBox(height: 10),
                          footnotesWidget,
                        ],
                      ],
                    ],
                  )
                : ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: _isLandscape ? 165 : 0,
                    ),
                    child: Column(
                      mainAxisAlignment: _isLandscape
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (reflectionWidget != null) ...[
                          reflectionWidget,
                          SizedBox(height: compact ? 12 : 16),
                        ],
                        if (arabicWidget != null) ...[
                          arabicWidget,
                          SizedBox(height: compact ? 10 : 14),
                        ],
                        if (wbwWidget != null) ...[
                          wbwWidget,
                          SizedBox(height: compact ? 10 : 14),
                        ],
                        ?translationWidget,
                        if (tafsirWidget != null) ...[
                          SizedBox(height: compact ? 10 : 14),
                          tafsirWidget,
                        ],
                        if (footnotesWidget != null) ...[
                          SizedBox(height: compact ? 10 : 14),
                          footnotesWidget,
                        ],
                      ],
                    ),
                  ),
          ),

          // Card Watermark Footer
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: _isLandscape ? 22 : 16,
              vertical: 11,
            ),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: palette.divider, width: 1),
              ),
            ),
            child: Row(
              children: [
                _buildBrandIcon(size: 18, radius: 4),
                const SizedBox(width: 7),
                Text(
                  'Thai Quran • quran-th.com',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: palette.watermark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReflectionCardBox(
    _ShareCardPalette palette,
    bool isThai,
    double reflectionFontSize,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: palette.reflectionBg,
        border: Border.all(color: palette.reflectionBorder),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3.5, color: palette.reflectionAccent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isThai
                          ? 'ข้อคิดตะดับบุร • Tadabbur'
                          : 'Reflection • Tadabbur',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: palette.watermark,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      ThaiTextProtectionProvider.protectSafe(
                        context,
                        widget.reflectionText!.trim(),
                      ),
                      locale: ThaiTextProtectionProvider.localeForText(
                        widget.reflectionText!,
                        forceThai: isThai,
                      ),
                      style: GoogleFonts.notoSansThai(
                        fontSize: reflectionFontSize,
                        fontWeight: FontWeight.w500,
                        height: 1.6,
                        color: palette.meaningText,
                      ),
                    ),
                    if (_includeAuthor && _hasAuthorInput) ...[
                      const SizedBox(height: 6),
                      Text(
                        '— ${widget.reflectionAuthor!.trim()}',
                        style: GoogleFonts.notoSansThai(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: palette.headerSubText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandIcon({required double size, required double radius}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        'assets/icons/playstore-icon.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: size,
            height: size,
            color: const Color(0xFF0E5A4A),
            alignment: Alignment.center,
            child: Icon(
              Icons.menu_book_rounded,
              size: size * 0.6,
              color: Colors.white,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSecondaryActionButton({
    required AppThemeColors colors,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: colors.surfaceMuted,
          foregroundColor: colors.textStrong,
          side: BorderSide(color: colors.borderSoft),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
        ),
        icon: isLoading
            ? SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.primary,
                ),
              )
            : Icon(icon, size: 16, color: colors.textMuted),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.notoSansThai(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.textStrong,
          ),
        ),
      ),
    );
  }

  Widget _buildStickyBottomBar(AppThemeColors colors, bool isThai) {
    final anyBusy = _isGenerating || _isCopyingImage || _isSavingImage;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.borderSoft)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _buildSecondaryActionButton(
                colors: colors,
                icon: Icons.copy_rounded,
                label: isThai ? 'คัดลอกข้อความ' : 'Copy Text',
                onPressed: _handleCopyText,
              ),
              const SizedBox(width: 8),
              _buildSecondaryActionButton(
                colors: colors,
                icon: Icons.image_outlined,
                label: isThai ? 'คัดลอกรูป' : 'Copy Image',
                isLoading: _isCopyingImage,
                onPressed: anyBusy ? null : _handleCopyImage,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildSecondaryActionButton(
                colors: colors,
                icon: Icons.download_rounded,
                label: isThai ? 'บันทึกภาพ' : 'Save Image',
                isLoading: _isSavingImage,
                onPressed: anyBusy ? null : _handleSaveImage,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  key: _shareButtonKey,
                  onPressed: anyBusy ? null : _handleShareImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0E5A4A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                  ),
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.share_outlined, size: 16),
                  label: Text(
                    _isGenerating
                        ? (isThai ? 'กำลังสร้างภาพ...' : 'Sharing...')
                        : (isThai ? 'แชร์' : 'Share'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSansThai(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
