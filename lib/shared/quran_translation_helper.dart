import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/verse.dart';
import '../data/quran_repository.dart';
import '../providers/settings_provider.dart';
import '../providers/translation_manager_provider.dart';
import 'translation_constants.dart';
import 'translation_hierarchy.dart';

/// Converts Latin Arabic digits (0-9) to Eastern Arabic-Indic numerals (٠-٩).
String toArabicDigits(dynamic input) {
  if (input == null) return '';
  const latinToEastern = {
    '0': '٠',
    '1': '١',
    '2': '٢',
    '3': '٣',
    '4': '٤',
    '5': '٥',
    '6': '٦',
    '7': '٧',
    '8': '٨',
    '9': '٩',
  };
  final str = input.toString();
  final sb = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    final char = str[i];
    sb.write(latinToEastern[char] ?? char);
  }
  return sb.toString();
}

/// Normalizes Uthmanic Arabic characters that produce black/dotted-circle glyph
/// artifacts or floating meem misalignment when rendered with `UthmanicHafs.ttf`:
/// - `U+06DF` (Small High Rounded Zero) -> `U+0652` (hollow sukun)
/// - `U+06E3` (Small Low Seen) -> `U+06DC` (small high seen)
/// - `U+06EB` (Empty Centre High Stop) & `U+25CC` (Dotted Circle) -> removed
/// - `U+0654\u0652` (Hamza above + standard sukun) -> `U+0654\u06E1` (mkmk-supported Quranic sukun)
/// - Sequential tanween pseudo-marks -> canonical tanween or Iqlab meem pairs
String sanitizeUthmanicText(String text) {
  if (text.isEmpty) return '';
  return text
      .replaceAll('\u06DF', '\u0652')
      .replaceAll('\u06E3', '\u06DC')
      .replaceAll(RegExp(r'[\u06EB\u25CC]'), '')
      .replaceAll('\u0654\u0652', '\u0654\u06E1')
      .replaceAll('\u064B\u06ED', '\u064B')
      .replaceAll('\u064C\u06ED', '\u064C')
      .replaceAll('\u064D\u06E2', '\u064D')
      .replaceAll('\u064C\u06E2', '\u064F\u06E2')
      .replaceAll('\u064B\u06E2', '\u064E\u06E2')
      .replaceAll('\u064D\u06ED', '\u0650\u06ED');
}

/// Normalizes Quran.com WBW Arabic text (`words.text_uthmani`) for `UthmanicHafs.ttf`.
///
/// Raw WBW tokens encode consonantal sukun as `U+0652` and silent rounded zero
/// as `U+06DF`. Converting consonantal `U+0652` (excluding `U+0627\u0652`) to
/// Quranic sukun `U+06E1` before `U+06DF -> U+0652` prevents hamza + sukun
/// overlap (`ـْٔ` -> `ـٔۡ`) via `mkmk` positioning and matches verse text.
String sanitizeWbwUthmanicText(String text) {
  if (text.isEmpty) return '';
  final withHafsSukun = text.replaceAllMapped(
    RegExp(r'(?<!\u0627)\u0652'),
    (_) => '\u06E1',
  );
  return sanitizeUthmanicText(withHafsSukun);
}

/// Normalizes and formats Arabic Quran verse text so that the end of the ayat
/// includes the Quranic Arabic verse numeral formatted for the Uthmanic font.
String formatArabicAyahText(String text, {dynamic verseNumber}) {
  String cleaned = text.trim();
  if (cleaned.isEmpty) return '';

  // Sanitize Uthmanic characters that cause black-circle / dotted-circle glyphs
  cleaned = sanitizeUthmanicText(cleaned);

  // Strip any existing standalone \u06DD (۝) symbols to prevent double circle rendering
  cleaned = cleaned.replaceAll('\u06DD', '').replaceAll('۝', '').trim();

  String numStr = '';
  // Check if verse text ends with a pipe/space followed by digits e.g. " | 1", " | ١", " 12", " ١٢"
  final trailingMatch = RegExp(r'(\s*\|\s*[\d٠-٩]+|\s+[\d٠-٩]+)\s*$').firstMatch(cleaned);
  if (trailingMatch != null) {
    final matchedChunk = trailingMatch.group(0)!;
    numStr = matchedChunk.replaceAll(RegExp(r'[^\d٠-٩]'), '');
    cleaned = cleaned.substring(0, trailingMatch.start).trim();
  }

  if (numStr.isEmpty && verseNumber != null) {
    numStr = verseNumber.toString();
  }

  // Strip all remaining pipe separators (missing glyph in UthmanicHafs)
  cleaned = cleaned.replaceAll(RegExp(r'\s*\|\s*'), ' ').trim();

  if (numStr.isNotEmpty) {
    final arabicNum = toArabicDigits(numStr);
    return '$cleaned $arabicNum';
  }

  return cleaned;
}

/// Resolves the effective translation string for a verse based on the app's
/// global [SettingsProvider] and [TranslationManagerProvider].
///
/// Handles:
/// - Thai v3 (`thai_v3`)
/// - Thai v2 (`thai_v2`)
/// - English (`english`, `en_usmani`, `en_sahih`, or IDs starting with `en`)
/// - Malay (`ms_basmeih`, `malay`, or IDs starting with `ms`)
/// - Custom API-downloaded translation IDs
String resolveVerseTranslationText({
  required BuildContext context,
  required String verseKey,
  Verse? verse,
  Map<String, dynamic>? verseItem,
  SettingsProvider? settings,
  TranslationManagerProvider? transManager,
  QuranRepository? repository,
}) {
  final s = settings ?? Provider.of<SettingsProvider>(context, listen: false);
  final primaryId = TranslationConstants.resolveTranslationId(s.primaryTranslationId);
  final apiId = TranslationConstants.resolveApiId(s.primaryTranslationId);

  // 1. If a database query map is provided (from quran_offline.db)
  if (verseItem != null) {
    final th = (verseItem['translation_th'] as String?) ?? '';
    final en = (verseItem['translation_en'] as String?) ?? (verseItem['translation'] as String?) ?? '';
    final ms = (verseItem['translation_ms'] as String?) ?? '';

    if (primaryId == 'en_usmani' || primaryId == 'english') {
      final tm = transManager ?? Provider.of<TranslationManagerProvider>(context, listen: false);
      final enText = tm.getVerseTranslation('en_usmani', verseKey) ?? tm.getVerseTranslation('english', verseKey);
      if (enText != null && enText.isNotEmpty) return enText;
      if (en.isNotEmpty) return en;
      if (verse != null && verse.english.isNotEmpty && verse.english != 'N/A') return verse.english;
      return 'Loading translation...';
    } else if (primaryId == 'ms_basmeih' || primaryId == 'malay') {
      final tm = transManager ?? Provider.of<TranslationManagerProvider>(context, listen: false);
      final msText = tm.getVerseTranslation('ms_basmeih', verseKey) ?? tm.getVerseTranslation('malay', verseKey);
      if (msText != null && msText.isNotEmpty) return msText;
      if (ms.isNotEmpty) return ms;
      return 'Loading translation...';
    } else if (primaryId == 'thai_v3') {
      if (verse != null && verse.thaiV3.isNotEmpty) return verse.thaiV3;
      if (th.isNotEmpty) return th;
    } else if (primaryId == 'thai_v2') {
      if (verse != null && verse.thaiV2.isNotEmpty) return verse.thaiV2;
      if (verse != null && verse.thaiV3.isNotEmpty) return verse.thaiV3;
      if (th.isNotEmpty) return th;
    } else {
      // Custom downloaded translation
      final tm = transManager ?? Provider.of<TranslationManagerProvider>(context, listen: false);
      final customText = tm.getVerseTranslation(apiId ?? primaryId, verseKey) ??
          tm.getVerseTranslation(s.primaryTranslationId, verseKey);
      if (customText != null && customText.isNotEmpty) {
        return customText;
      }
      if (apiId != null) {
        final tInfo = tm.downloadedTranslations.firstWhere(
          (t) => t['id'] == apiId,
          orElse: () => <String, dynamic>{},
        );
        final lang = (tInfo['language_name'] ?? tInfo['language'] ?? '').toString().toLowerCase();
        if (lang.contains('en') || lang.contains('eng')) {
          if (en.isNotEmpty) return en;
        } else if (lang.contains('ms') || lang.contains('malay') || lang.contains('melayu')) {
          if (ms.isNotEmpty) return ms;
        }
      }
      return 'Loading translation...';
    }
  }

  // 2. If a Verse model object is available
  if (verse != null) {
    if (primaryId == 'en_usmani' || primaryId == 'english') {
      final tm = transManager ?? Provider.of<TranslationManagerProvider>(context, listen: false);
      final enText = tm.getVerseTranslation('en_usmani', verseKey) ?? tm.getVerseTranslation('english', verseKey);
      if (enText != null && enText.isNotEmpty) return enText;
      if (verse.english.isNotEmpty && verse.english != 'N/A') return verse.english;
      return 'Loading translation...';
    } else if (primaryId == 'ms_basmeih' || primaryId == 'malay') {
      final tm = transManager ?? Provider.of<TranslationManagerProvider>(context, listen: false);
      final msText = tm.getVerseTranslation('ms_basmeih', verseKey) ?? tm.getVerseTranslation('malay', verseKey);
      if (msText != null && msText.isNotEmpty) return msText;
      return 'Loading translation...';
    } else if (primaryId == 'thai_v3') {
      if (verse.thaiV3.isNotEmpty) return verse.thaiV3;
    } else if (primaryId == 'thai_v2') {
      if (verse.thaiV2.isNotEmpty) return verse.thaiV2;
      if (verse.thaiV3.isNotEmpty) return verse.thaiV3;
    } else {
      final tm = transManager ?? Provider.of<TranslationManagerProvider>(context, listen: false);
      final customText = tm.getVerseTranslation(apiId ?? primaryId, verseKey) ??
          tm.getVerseTranslation(s.primaryTranslationId, verseKey);
      if (customText != null && customText.isNotEmpty) {
        return customText;
      }
      return 'Loading translation...';
    }
  }

  // 3. If repository is provided or can be looked up
  if (repository != null) {
    final parts = verseKey.split(':');
    if (parts.length == 2) {
      final repoVerse = repository.getVerse(parts[0], parts[1]);
      if (repoVerse != null) {
        return resolveVerseTranslationText(
          context: context,
          verseKey: verseKey,
          verse: repoVerse,
          settings: s,
          transManager: transManager,
        );
      }
    }
  }

  return '';
}

/// Resolves the effective language code ('th', 'en', 'ms') for the selected translation.
String resolveEffectiveTranslationLanguage(
  BuildContext context, {
  SettingsProvider? settings,
  TranslationManagerProvider? transManager,
  String? translationId,
}) {
  final s = settings ?? Provider.of<SettingsProvider>(context, listen: false);
  final rawId = (translationId ?? s.primaryTranslationId).trim();
  final canonical = TranslationConstants.resolveTranslationId(rawId);

  final known = TranslationConstants.getKnownOption(canonical);
  if (known != null) {
    final kLang = known.language.toLowerCase();
    if (kLang == 'thai' || kLang == 'th') return 'th';
    if (kLang == 'malay' || kLang == 'ms' || kLang == 'melayu') return 'ms';
    if (kLang == 'english' || kLang == 'en') return 'en';
  }

  try {
    final tm = transManager ??
        Provider.of<TranslationManagerProvider>(context, listen: false);
    final customId = int.tryParse(canonical);
    if (customId != null) {
      final t = tm.downloadedTranslations.firstWhere(
        (item) => item['id'] == customId,
        orElse: () => <String, dynamic>{},
      );
      final lang =
          (t['language_name'] ?? t['language'] ?? '').toString().toLowerCase();
      if (lang.contains('th')) return 'th';
      if (lang.contains('ms') ||
          lang.contains('malay') ||
          lang.contains('melayu') ||
          lang.contains('indonesi')) {
        return 'ms';
      }
      if (lang.contains('en')) return 'en';
    }
  } catch (_) {}

  final hierarchyLang = TranslationHierarchy.getLanguageForTranslationId(rawId);
  if (hierarchyLang == 'thai') return 'th';
  if (hierarchyLang == 'malay') return 'ms';
  if (hierarchyLang == 'english') return 'en';

  return s.languageCode;
}

/// Returns the typography / TextStyle that dynamically matches the active translation language.
/// Uses NotoSansThai for Thai, and NotoSans for English/Malay/Latin scripts.
TextStyle getTranslationTextStyle(
  BuildContext context, {
  double fontSize = 15,
  double height = 1.6,
  FontWeight fontWeight = FontWeight.normal,
  Color? color,
  String? translationId,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final effectiveColor = color ?? colorScheme.onSurface;
  final lang = resolveEffectiveTranslationLanguage(
    context,
    translationId: translationId,
  );

  if (lang == 'en' || lang == 'ms') {
    return GoogleFonts.notoSans(
      fontSize: fontSize,
      height: height,
      fontWeight: fontWeight,
      color: effectiveColor,
    );
  }

  return GoogleFonts.notoSansThai(
    fontSize: fontSize,
    height: height,
    fontWeight: fontWeight,
    color: effectiveColor,
  );
}
