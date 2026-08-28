import 'dart:convert';
import 'package:flutter/services.dart';

class FootnoteItem {
  final int id;
  final int origId;
  final String text;

  FootnoteItem({
    required this.id,
    required this.origId,
    required this.text,
  });

  factory FootnoteItem.fromJson(Map<String, dynamic> json) {
    return FootnoteItem(
      id: json['id'] as int? ?? 0,
      origId: json['origId'] as int? ?? 0,
      text: json['text'] as String? ?? '',
    );
  }
}

class FootnoteEntry {
  final String annotated;
  final List<FootnoteItem> footnotes;

  FootnoteEntry({
    required this.annotated,
    required this.footnotes,
  });
}

class FootnoteService {
  static final FootnoteService _instance = FootnoteService._internal();
  factory FootnoteService() => _instance;
  FootnoteService._internal();

  Map<String, FootnoteEntry>? _thaiFootnotes;
  Map<String, FootnoteEntry>? _saheehFootnotes;
  Map<String, FootnoteEntry>? _hilaliKhanFootnotes;
  Map<String, FootnoteEntry>? _bridgesFootnotes;
  bool _isLoading = false;

  Future<void> init() async {
    if (_thaiFootnotes != null &&
        _saheehFootnotes != null &&
        _hilaliKhanFootnotes != null &&
        _bridgesFootnotes != null) {
      return;
    }
    if (_isLoading) return;
    _isLoading = true;

    try {
      if (_thaiFootnotes == null) {
        final thStr = await rootBundle.loadString('assets/footnotes/thai_footnotes.json');
        _thaiFootnotes = _parseFootnotesMap(thStr);
      }

      if (_saheehFootnotes == null) {
        final enStr = await rootBundle.loadString('assets/footnotes/en_saheeh_footnotes.json');
        _saheehFootnotes = _parseFootnotesMap(enStr);
      }

      if (_hilaliKhanFootnotes == null) {
        final hkStr = await rootBundle.loadString('assets/footnotes/en_hilali_khan_footnotes.json');
        _hilaliKhanFootnotes = _parseFootnotesMap(hkStr);
      }

      if (_bridgesFootnotes == null) {
        final brStr = await rootBundle.loadString('assets/footnotes/en_bridges_footnotes.json');
        _bridgesFootnotes = _parseFootnotesMap(brStr);
      }
    } catch (_) {
      // Graceful fallback
    } finally {
      _isLoading = false;
    }
  }

  Map<String, FootnoteEntry> _parseFootnotesMap(String jsonStr) {
    final Map<String, dynamic> rawMap = jsonDecode(jsonStr);
    return rawMap.map((key, value) {
      final rawFns = (value['footnotes'] as List<dynamic>?) ?? [];
      return MapEntry(
        key,
        FootnoteEntry(
          annotated: value['annotated'] as String? ?? '',
          footnotes: rawFns.map((f) => FootnoteItem.fromJson(f as Map<String, dynamic>)).toList(),
        ),
      );
    });
  }

  FootnoteEntry? getEntry(String verseKey, String translationId) {
    final lower = translationId.toLowerCase();
    if (lower == 'en_saheeh' || lower == 'english' || lower == '20') {
      return _saheehFootnotes?[verseKey];
    }
    if (lower == 'en_hilali_khan' || lower == '203' || lower.contains('hilali')) {
      return _hilaliKhanFootnotes?[verseKey];
    }
    if (lower == 'en_bridges' || lower == '149' || lower.contains('bridges')) {
      return _bridgesFootnotes?[verseKey];
    }
    if (lower == 'thai_v3' || lower == 'thai_v2' || lower == 'thai_orig' || lower.startsWith('th')) {
      return _thaiFootnotes?[verseKey];
    }
    return null;
  }
}
