import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/footnote_service.dart';

class HtmlParser {
  static List<TextSpan> parseTranslationText(
    BuildContext context,
    String text,
    TextStyle style,
    Color linkColor, {
    String? verseKey,
    String? translationId,
  }) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final showFootnotes = settings.showFootnotes;

    // Check if offline footnote entry exists
    FootnoteEntry? footnoteEntry;
    if (verseKey != null && translationId != null) {
      footnoteEntry = FootnoteService().getEntry(verseKey, translationId);
    }

    // Determine working text
    String workingText = text;
    if (showFootnotes && footnoteEntry != null && footnoteEntry.annotated.isNotEmpty) {
      workingText = footnoteEntry.annotated;
    }

    // If footnotes are disabled by user, strip any [N] or <sup foot_note=...> tags, but keep grammatical tags
    if (!showFootnotes) {
      workingText = workingText
          .replaceAll(RegExp(r'<sup\s+[^>]*foot_note="?\d+"?[^>]*>.*?<\/sup>'), '')
          .replaceAll(RegExp(r'\[\d+\]'), '')
          .trim();
    }

    final List<TextSpan> spans = [];

    // Combined regex to find:
    // 1) <sup foot_note="123">1</sup>
    // 2) [1]
    // 3) Grammatical floating tags like <sup>pl</sup> or <sup>sg </sup>
    final regex = RegExp(r'<sup\s+[^>]*foot_note="?(\d+)"?[^>]*>(.*?)<\/sup>|\[(\d+)\]|<sup[^>]*>(.*?)<\/sup>', caseSensitive: false);
    int lastMatchEnd = 0;

    for (final match in regex.allMatches(workingText)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: workingText.substring(lastMatchEnd, match.start), style: style));
      }

      // Check for grammatical floating tag
      if (match.group(4) != null) {
        final gramTag = match.group(4)!.trim();
        spans.add(
          TextSpan(
            text: gramTag,
            style: style.copyWith(
              fontSize: (style.fontSize ?? 14) * 0.65,
              fontWeight: FontWeight.bold,
              color: (style.color ?? Colors.black).withValues(alpha: 0.55),
            ),
          ),
        );
        lastMatchEnd = match.end;
        continue;
      }

      // Footnote marker
      int fnId = 1;
      String? rawOrigId;

      if (match.group(1) != null) {
        rawOrigId = match.group(1);
        fnId = int.tryParse(match.group(2) ?? '1') ?? 1;
      } else if (match.group(3) != null) {
        fnId = int.tryParse(match.group(3)!) ?? 1;
      }

      spans.add(
        TextSpan(
          text: '[$fnId]',
          style: style.copyWith(
            color: linkColor,
            fontWeight: FontWeight.bold,
            fontSize: (style.fontSize ?? 14) * 0.75,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              _showFootnoteModal(
                context,
                fnId: fnId,
                rawOrigId: rawOrigId,
                footnoteEntry: footnoteEntry,
                textColor: style.color ?? Colors.black,
                translationId: translationId,
              );
            },
        ),
      );

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < workingText.length) {
      spans.add(TextSpan(text: workingText.substring(lastMatchEnd), style: style));
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: workingText, style: style));
    }

    return spans;
  }

  static Future<void> _showFootnoteModal(
    BuildContext context, {
    required int fnId,
    String? rawOrigId,
    FootnoteEntry? footnoteEntry,
    required Color textColor,
    String? translationId,
  }) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final isThai = settings.languageCode == 'th';

    // Check offline footnote
    String? offlineText;
    if (footnoteEntry != null) {
      for (final f in footnoteEntry.footnotes) {
        if (f.id == fnId) {
          offlineText = f.text;
          break;
        }
      }
    }

    String editionTitle;
    final tid = translationId?.toLowerCase() ?? '';
    if (tid == 'en_hilali_khan' || tid == '203' || tid.contains('hilali')) {
      editionTitle = 'Al-Hilali & Muhsin Khan (King Fahd Complex)';
    } else if (tid == 'en_bridges' || tid == '149' || tid.contains('bridges')) {
      editionTitle = "Bridges' Translation (10 Qira'at)";
    } else if (tid == 'en_saheeh' || tid == 'english' || tid == '20') {
      editionTitle = 'Saheeh International';
    } else {
      editionTitle = 'King Fahd Complex (ฉบับสมาคมนักเรียนเก่าอาหรับ)';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        Widget content;
        if (offlineText != null && offlineText.isNotEmpty) {
          content = SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Text(
              offlineText,
              style: GoogleFonts.notoSansThai(fontSize: 15, height: 1.6, color: textColor),
            ),
          );
        } else if (rawOrigId != null) {
          content = FutureBuilder<String>(
            future: _fetchFootnote(rawOrigId),
            builder: (ctx, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      isThai ? 'โหลดเชิงอรรถล้มเหลว' : 'Failed to load footnote.',
                      style: GoogleFonts.notoSansThai(color: textColor),
                    ),
                  ),
                );
              }
              final clean = snapshot.data!.replaceAll(RegExp(r'<[^>]*>'), '');
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Text(
                  clean,
                  style: GoogleFonts.notoSansThai(fontSize: 15, height: 1.6, color: textColor),
                ),
              );
            },
          );
        } else {
          content = Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: Text(
                isThai ? 'ไม่พบข้อมูลเชิงอรรถ' : 'Footnote not found.',
                style: GoogleFonts.notoSansThai(color: textColor),
              ),
            ),
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isThai ? 'เชิงอรรถ [$fnId]' : 'Footnote [$fnId]',
                            style: GoogleFonts.notoSansThai(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            editionTitle,
                            style: GoogleFonts.notoSansThai(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Flexible(child: content),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  static Future<String> _fetchFootnote(String footnoteId) async {
    try {
      final res = await http.get(Uri.parse('https://api.quran.com/api/v4/foot_notes/$footnoteId'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['foot_note']?['text'] ?? 'Footnote text not found.';
      }
    } catch (_) {}
    return 'Footnote text not found.';
  }
}
