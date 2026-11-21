import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ThaiTextProtectionProvider extends ChangeNotifier {
  static const String _cacheKey = 'thai_protected_terms_cache_v1';
  static const String _wordJoiner = '\u2060';
  static const Locale thaiLocale = Locale('th', 'TH');
  static final RegExp _thaiScriptRegex = RegExp(r'[\u0E00-\u0E7F]');

  static const List<String> seedTerms = [
    'ฟิรเอานฺ',
    'อัลลอฮฺ',
    'มุฮัมมัด',
    'อิบรอฮีม',
    'อิสมาอีล',
    'อิสฮาก',
    'ยะอฺกูบ',
    'ญิบรีล',
    'ตอรูต',
    'ญาลูต',
    'ฏอลูต',
    'ฮารูน',
    'อีซา',
    'มูซา',
    'อัลกุรอาน',
    'ตะดับบุร',
    'อินชาอัลลอฮฺ',
    'อัลฮัมดุลิลลาฮฺ',
    'พระผู้อภิบาล',
    'มุสลิม',
    'อิสลาม',
    'ตัฟซีร',
  ];

  static final List<String> _normalizedSeedTerms = _normalizeTerms(seedTerms);

  List<String> _terms = List<String>.from(_normalizedSeedTerms);

  ThaiTextProtectionProvider() {
    load();
  }

  List<String> get terms => List.unmodifiable(_terms);

  static bool containsThai(String text) => _thaiScriptRegex.hasMatch(text);

  static Locale? localeForText(String text, {bool forceThai = false}) {
    return (forceThai || containsThai(text)) ? thaiLocale : null;
  }

  /// Safely protects Thai terms even in isolated widget trees/tests where
  /// [ThaiTextProtectionProvider] is not mounted in the Provider ancestor chain.
  static String protectSafe(
    BuildContext context,
    String text, {
    bool listen = false,
  }) {
    if (text.isEmpty || !containsThai(text)) return text;
    try {
      final provider = Provider.of<ThaiTextProtectionProvider>(
        context,
        listen: listen,
      );
      return provider.protect(text);
    } on ProviderNotFoundException {
      return protectWithTerms(text, _normalizedSeedTerms);
    }
  }

  static String protectWithTerms(String text, List<String> terms) {
    if (text.isEmpty || !containsThai(text) || terms.isEmpty) return text;

    // 1. Replace protected terms with private-use sentinels to avoid double matching.
    final matchedValues = <int, String>{};
    var processedText = text;

    for (var i = 0; i < terms.length; i++) {
      final term = terms[i];
      if (processedText.contains(term)) {
        final sentinel = '\uE000$i\uE001';
        matchedValues[i] = _protectTerm(term);
        processedText = processedText.replaceAll(term, sentinel);
      }
    }

    if (matchedValues.isEmpty) return text;

    // 2. Restore protected terms, inserting Zero-Width Space (\u200B) only on
    // adjacent word-character boundaries so punctuation/quotes remain attached.
    return processedText.replaceAllMapped(
      RegExp(r'\uE000(\d+)\uE001'),
      (match) {
        final idx = int.parse(match.group(1)!);
        final protectedValue = matchedValues[idx]!;
        final hasWordBefore = match.start > 0 &&
            _isWordBoundaryRune(
              processedText.substring(0, match.start).runes.last,
            );
        final hasWordAfter = match.end < processedText.length &&
            _isWordBoundaryRune(
              processedText.substring(match.end).runes.first,
            );
        final prefix = hasWordBefore ? '\u200B' : '';
        final suffix = hasWordAfter ? '\u200B' : '';
        return '$prefix$protectedValue$suffix';
      },
    );
  }

  Future<void> load() async {
    await _loadCachedTerms();
    await _fetchRemoteTerms();
  }

  String protect(String text) => protectWithTerms(text, _terms);

  Future<void> _loadCachedTerms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached == null || cached.isEmpty) return;

      final decoded = jsonDecode(cached);
      if (decoded is! List) return;

      _terms = _normalizeTerms([
        ...seedTerms,
        ...decoded.map((value) => value.toString()),
      ]);
      notifyListeners();
    } catch (error) {
      debugPrint('Thai protected terms cache load failed: $error');
    }
  }

  Future<void> _fetchRemoteTerms() async {
    try {
      final rows = await Supabase.instance.client
          .from('thai_protected_terms')
          .select('term')
          .eq('is_active', true)
          .order('sort_order')
          .order('term');

      final remoteTerms = rows
          .map<String>((row) => row['term']?.toString() ?? '')
          .where((term) => term.trim().isNotEmpty);
      _terms = _normalizeTerms([...seedTerms, ...remoteTerms]);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(_terms));
      notifyListeners();
    } catch (error) {
      debugPrint('Thai protected terms remote load failed: $error');
    }
  }

  static List<String> _normalizeTerms(Iterable<String> values) {
    final seen = <String>{};
    final terms = values
        .map((term) => term.trim())
        .where((term) => term.isNotEmpty && seen.add(term))
        .toList();
    terms.sort((a, b) => b.length.compareTo(a.length));
    return terms;
  }

  static String _protectTerm(String term) {
    final runes = term.runes.toList(growable: false);
    if (runes.length < 2) return term;

    final buffer = StringBuffer();
    for (var index = 0; index < runes.length; index += 1) {
      final rune = runes[index];
      if (index > 0 && !_isThaiCombiningMark(rune)) {
        buffer.write(_wordJoiner);
      }
      buffer.writeCharCode(rune);
    }
    return buffer.toString();
  }

  static bool _isWordBoundaryRune(int rune) {
    return (rune >= 0x0E01 && rune <= 0x0E7F) ||
        (rune >= 0x30 && rune <= 0x39) ||
        (rune >= 0x41 && rune <= 0x5A) ||
        (rune >= 0x61 && rune <= 0x7A) ||
        rune == 0xE000 ||
        rune == 0xE001;
  }

  static bool _isThaiCombiningMark(int rune) {
    return rune == 0x0E31 ||
        (rune >= 0x0E34 && rune <= 0x0E3A) ||
        (rune >= 0x0E47 && rune <= 0x0E4E);
  }
}
