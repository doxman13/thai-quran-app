import 'package:flutter/material.dart';
import '../shared/quran_translation_helper.dart';
import '../theme/app_theme.dart';

class TajweedText extends StatelessWidget {
  final String text;
  final double fontSize;
  final String? verseNumber;
  final Color? textColor;
  final double height;

  const TajweedText({
    super.key,
    required this.text,
    this.fontSize = 24.0,
    this.verseNumber,
    this.textColor,
    this.height = 2.0,
  });

  static final RegExp _trailingVerseNumberPattern =
      RegExp(r'\s*(?:\u06DD|۝)?\s*([\d٠-٩]+)\s*$');

  /// Ensures a trailing verse number in DigitalKhatt Tajweed text is prefixed
  /// with U+06DD (End of Ayah) so `DigitalKhattQuranicV1.otf` shapes it inside
  /// a circular ayah marker instead of bare digits.
  @visibleForTesting
  static String ensureVerseEndMark(String rawText, {String? verseNumber}) {
    final trimmed = rawText.trimRight();
    if (trimmed.isEmpty) return '';

    final match = _trailingVerseNumberPattern.firstMatch(trimmed);
    if (match != null) {
      final rawDigits = match.group(1) ?? '';
      if (rawDigits.isNotEmpty) {
        final arabicDigits = toArabicDigits(rawDigits);
        final prefix = trimmed.substring(0, match.start).trimRight();
        if (prefix.isEmpty) {
          return '\u06DD$arabicDigits';
        }
        return '$prefix \u06DD$arabicDigits';
      }
    }

    if (verseNumber != null && verseNumber.trim().isNotEmpty) {
      final arabicDigits = toArabicDigits(verseNumber.trim());
      return '$trimmed \u06DD$arabicDigits';
    }

    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = textColor ?? context.appColors.textStrong;
    final formattedText = ensureVerseEndMark(text, verseNumber: verseNumber);
    final spans = <TextSpan>[];
    final parts = _parseTajweedParts(formattedText);

    for (final part in parts) {
      final isRule = part.className.isNotEmpty;
      final ruleColor = isRule
          ? TajweedPalette.getColor(part.className, isDark: isDark)
          : null;
      spans.add(TextSpan(
        text: part.text,
        style: TextStyle(
          fontFamily: 'Tajweed',
          fontSize: fontSize,
          height: height,
          color: ruleColor ?? defaultColor,
        ),
      ));
    }

    return RichText(
      textAlign: TextAlign.justify,
      textDirection: TextDirection.rtl,
      text: TextSpan(children: spans),
    );
  }

  static List<_TajweedPart> _parseTajweedParts(String wordStr) {
    final parts = <_TajweedPart>[];
    final classStack = <String>[];
    var buffer = StringBuffer();
    var bufferClass = '';

    String activeClass() => classStack.isEmpty ? '' : classStack.last;

    void flushBuffer() {
      if (buffer.isEmpty) return;
      parts.add(_TajweedPart(
        text: buffer.toString(),
        className: bufferClass,
      ));
      buffer = StringBuffer();
    }

    var index = 0;
    while (index < wordStr.length) {
      final tagStart = wordStr.indexOf('<', index);
      if (tagStart == -1) {
        final text = wordStr.substring(index);
        final nextClass = activeClass();
        if (buffer.isNotEmpty && bufferClass != nextClass) {
          flushBuffer();
        }
        bufferClass = nextClass;
        buffer.write(text);
        break;
      }

      if (tagStart > index) {
        final text = wordStr.substring(index, tagStart);
        final nextClass = activeClass();
        if (buffer.isNotEmpty && bufferClass != nextClass) {
          flushBuffer();
        }
        bufferClass = nextClass;
        buffer.write(text);
      }

      final tagEnd = wordStr.indexOf('>', tagStart + 1);
      if (tagEnd == -1) {
        break;
      }

      final tag = wordStr.substring(tagStart + 1, tagEnd).trim();
      if (tag.startsWith('/')) {
        if (classStack.isNotEmpty) classStack.removeLast();
      } else if (!tag.startsWith('img') && !tag.endsWith('/')) {
        final className = _extractClass(tag);
        classStack.add(className);
      }

      index = tagEnd + 1;
    }

    flushBuffer();
    return parts;
  }

  static String _extractClass(String tag) {
    final match = RegExp(r'''class\s*=\s*["']?([^"'>\s]+)''').firstMatch(tag);
    if (match != null) {
      return match.group(1)?.replaceAll("'", "").replaceAll('"', '').trim() ?? '';
    }
    return '';
  }
}

class _TajweedPart {
  final String text;
  final String className;
  _TajweedPart({required this.text, required this.className});
}
