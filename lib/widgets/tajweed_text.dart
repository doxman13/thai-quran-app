import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TajweedText extends StatelessWidget {
  final String text;
  final double fontSize;

  const TajweedText({
    super.key,
    required this.text,
    this.fontSize = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = context.appColors.textStrong;
    final spans = <TextSpan>[];
    final parts = _parseTajweedParts(text);

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
