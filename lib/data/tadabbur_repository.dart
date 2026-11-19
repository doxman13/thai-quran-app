// lib/data/tadabbur_repository.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/tadabbur_note.dart';
import 'quran_foundation_repository.dart';

class TadabburRepository {
  static const String _blockedUsersPrefsKey = 'blocked_tadabbur_user_ids';
  static String? _qrCachedToken;
  static DateTime? _qrTokenExpiry;
  final _client = Supabase.instance.client;

  /// Fetch all notes belonging to the current user
  Future<List<TadabburNote>> fetchUserNotes() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      debugPrint('TadabburRepository: fetchUserNotes skipped, unauthenticated.');
      return [];
    }

    try {
      final response = await _client
          .from('tadabbur_notes')
          .select()
          .eq('user_id', user.id);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => TadabburNote.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('TadabburRepository: Error fetching user notes: $e');
      rethrow;
    }
  }

  /// Fetch public community notes — matches web fetchPublicTadabburFeed:
  /// includes ALL public notes (including the logged-in user's own),
  /// joins tadabbur_likes to compute user_liked, ordered newest first.
  Future<List<TadabburNote>> fetchCommunityNotes(
    String surahId,
    String verseId, {
    int? limit,
  }) async {
    try {
      final user = _client.auth.currentUser;

      var query = _client
          .from('tadabbur_notes')
          .select('*, tadabbur_likes(user_id)')
          .eq('is_public', true);

      if (surahId != '0') {
        query = query.eq('surah_id', surahId);
      }
      if (verseId != '0') {
        query = query.eq('verse_id', verseId);
      }
      final ordered = query.order('created_at', ascending: false);
      final response = limit != null && limit > 0
          ? await ordered.limit(limit)
          : await ordered;
      final List<dynamic> data = response as List<dynamic>;

      return data.map((row) {
        final json = row as Map<String, dynamic>;
        // Compute user_liked from the joined tadabbur_likes rows
        final likes = json['tadabbur_likes'] as List<dynamic>? ?? [];
        final userLiked = user != null
            ? likes.any((like) => (like as Map<String, dynamic>)['user_id'] == user.id)
            : false;
        return TadabburNote.fromJson({
          ...json,
          'user_liked': userLiked,
        });
      }).toList();
    } catch (e) {
      debugPrint('TadabburRepository: Error fetching community notes: $e');
      return [];
    }
  }

  /// Fetch English Tadabbur reflections from Quran Foundation's QuranReflect API (tab=popular).
  Future<List<TadabburNote>> fetchQuranReflectNotes({
    String? surahId,
    String? verseId,
    int page = 1,
    int limit = 50,
  }) async {
    final result = await fetchQuranReflectNotesWithMeta(
      surahId: surahId,
      verseId: verseId,
      page: page,
      limit: limit,
    );
    return result.reflections;
  }

  /// Fetch English QuranReflect reflections with pagination metadata.
  Future<({List<TadabburNote> reflections, bool hasMore})>
      fetchQuranReflectNotesWithMeta({
    String? surahId,
    String? verseId,
    int page = 1,
    int limit = 50,
  }) async {
    final normalizedSurah =
        (surahId != null && surahId != '0' && surahId != 'all' && surahId.isNotEmpty)
            ? surahId
            : null;
    final normalizedVerse =
        (verseId != null && verseId != '0' && verseId.isNotEmpty)
            ? verseId
            : null;

    // 1. Primary source: Direct Quran Foundation QuranReflect API
    try {
      final direct = await _fetchQuranReflectDirect(
        surahId: normalizedSurah,
        verseId: normalizedVerse,
        page: page,
        limit: limit,
      );
      if (direct.reflections.isNotEmpty || normalizedSurah != null) {
        return direct;
      }
    } catch (e) {
      debugPrint('TadabburRepository: Direct QuranReflect fetch failed: $e');
    }

    // 2. Secondary fallback: Backend proxy endpoint
    try {
      final secondary = await _fetchQuranReflectProxy(
        surahId: normalizedSurah,
        verseId: normalizedVerse,
        page: page,
        limit: limit,
      );
      if (secondary.reflections.isNotEmpty) {
        return secondary;
      }
    } catch (e) {
      debugPrint('TadabburRepository: Proxy QuranReflect fetch failed: $e');
    }

    // 3. Offline curated English reflections fallback
    final curated = _curatedFallbackReflections().where((note) {
      if (normalizedSurah != null && note.surahId != normalizedSurah) {
        return false;
      }
      if (normalizedVerse != null && note.verseId != normalizedVerse) {
        return false;
      }
      return true;
    }).toList();

    return (reflections: curated, hasMore: false);
  }

  Future<String> _getQuranReflectToken({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _qrCachedToken != null &&
        _qrTokenExpiry != null &&
        DateTime.now().isBefore(_qrTokenExpiry!)) {
      return _qrCachedToken!;
    }

    final authBase = QuranFoundationConfig.authBaseUrl.isNotEmpty
        ? QuranFoundationConfig.authBaseUrl.replaceAll(RegExp(r'/+$'), '')
        : 'https://oauth2.quran.foundation';
    final uri = Uri.parse('$authBase/oauth2/token');
    final creds = base64Encode(
      utf8.encode(
        '${QuranFoundationConfig.clientId}:${QuranFoundationConfig.authToken}',
      ),
    );

    final res = await http
        .post(
          uri,
          headers: {
            'accept': 'application/json',
            'content-type': 'application/x-www-form-urlencoded',
            'authorization': 'Basic $creds',
          },
          body: {'grant_type': 'client_credentials', 'scope': 'post.read'},
        )
        .timeout(const Duration(seconds: 10));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('OAuth2 token request failed (${res.statusCode})');
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final token = decoded['access_token']?.toString() ?? '';
    if (token.isEmpty) {
      throw Exception('Empty QuranReflect access token');
    }

    final expiresIn = (decoded['expires_in'] as num?)?.toInt() ?? 3600;
    _qrCachedToken = token;
    _qrTokenExpiry = DateTime.now().add(
      Duration(seconds: (expiresIn - 60).clamp(60, 86400)),
    );
    return token;
  }

  Future<({List<TadabburNote> reflections, bool hasMore})>
      _fetchQuranReflectDirect({
    String? surahId,
    String? verseId,
    required int page,
    required int limit,
  }) async {
    var token = await _getQuranReflectToken();
    final pagesNeeded = (limit / 10).ceil().clamp(1, 5);
    final startUpstreamPage = (page - 1) * pagesNeeded + 1;

    Future<Map<String, dynamic>> fetchPage(int upstreamPage, String authToken) async {
      final params = <String, String>{
        'tab': 'popular',
        'languages': '2',
        'page': upstreamPage.toString(),
        'limit': '10',
      };
      if (surahId != null) {
        params['filter[references][0][chapterId]'] = surahId;
        if (verseId != null) {
          params['filter[references][0][from]'] = verseId;
          params['filter[references][0][to]'] = verseId;
        }
      }
      final uri = Uri.https(
        'apis.quran.foundation',
        '/quran-reflect/v1/posts/feed',
        params,
      );
      var res = await http
          .get(
            uri,
            headers: {
              'accept': 'application/json',
              'x-client-id': QuranFoundationConfig.clientId,
              'x-auth-token': authToken,
            },
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode == 401) {
        token = await _getQuranReflectToken(forceRefresh: true);
        res = await http
            .get(
              uri,
              headers: {
                'accept': 'application/json',
                'x-client-id': QuranFoundationConfig.clientId,
                'x-auth-token': token,
              },
            )
            .timeout(const Duration(seconds: 12));
      }

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('QuranReflect feed failed (${res.statusCode})');
      }
      return jsonDecode(res.body) as Map<String, dynamic>;
    }

    final pagePayloads = await Future.wait(
      List.generate(
        pagesNeeded,
        (idx) => fetchPage(startUpstreamPage + idx, token),
      ),
    );

    final notes = <TadabburNote>[];
    final seenIds = <String>{};
    var hasMore = false;

    for (final payload in pagePayloads) {
      final currentPage = (payload['currentPage'] as num?)?.toInt() ?? 0;
      final totalPages = (payload['pages'] as num?)?.toInt() ?? 0;
      if (totalPages > 0 && currentPage < totalPages) {
        hasMore = true;
      }

      final items = payload['data'] as List<dynamic>? ?? const [];
      for (final raw in items) {
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);
        final parsed = _parseQuranReflectItem(item, preferredSurahId: surahId);
        if (parsed != null && seenIds.add(parsed.id)) {
          notes.add(parsed);
        }
      }
    }

    return (reflections: notes, hasMore: hasMore);
  }

  Future<({List<TadabburNote> reflections, bool hasMore})>
      _fetchQuranReflectProxy({
    String? surahId,
    String? verseId,
    required int page,
    required int limit,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (surahId != null) params['surahId'] = surahId;
    if (verseId != null) params['verseId'] = verseId;

    final uri = Uri.https(
      'quran-th.com',
      '/api/quran-foundation/reflections',
      params,
    );
    final res = await http
        .get(uri, headers: {'accept': 'application/json'})
        .timeout(const Duration(seconds: 10));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Proxy reflections failed (${res.statusCode})');
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      return (reflections: <TadabburNote>[], hasMore: false);
    }

    final rawList = (decoded['reflections'] ?? decoded['data']) as List<dynamic>? ??
        const [];
    final notes = <TadabburNote>[];
    for (final raw in rawList) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      if (item.containsKey('note_text')) {
        notes.add(TadabburNote.fromJson({...item, 'source': 'quranreflect'}));
      } else {
        final parsed = _parseQuranReflectItem(item, preferredSurahId: surahId);
        if (parsed != null) notes.add(parsed);
      }
    }
    final hasMore = decoded['hasMore'] as bool? ?? false;
    return (reflections: notes, hasMore: hasMore);
  }

  TadabburNote? _parseQuranReflectItem(
    Map<String, dynamic> item, {
    String? preferredSurahId,
  }) {
    final rawId = item['id']?.toString() ?? '';
    if (rawId.isEmpty) return null;

    final cleanBody = _stripHtmlTags(item['body']?.toString() ?? '');
    if (cleanBody.isEmpty) return null;

    final refs = item['references'] as List<dynamic>? ?? const [];
    Map<String, dynamic>? chosenRef;
    for (final r in refs) {
      if (r is! Map) continue;
      final refMap = Map<String, dynamic>.from(r);
      final ch = (refMap['chapterId'] as num?)?.toInt() ??
          int.tryParse(refMap['chapterId']?.toString() ?? '');
      if (ch != null && ch >= 1 && ch <= 114) {
        if (preferredSurahId != null && ch.toString() == preferredSurahId) {
          chosenRef = refMap;
          break;
        }
        chosenRef ??= refMap;
      }
    }
    if (chosenRef == null) return null;

    final chapterId = (chosenRef['chapterId'] as num?)?.toInt() ??
        int.parse(chosenRef['chapterId'].toString());
    final fromVerse = ((chosenRef['from'] as num?)?.toInt() ??
            int.tryParse(chosenRef['from']?.toString() ?? '') ??
            1)
        .clamp(1, 286);

    final author = item['author'] is Map
        ? Map<String, dynamic>.from(item['author'] as Map)
        : null;
    final fullName = author?['fullName']?.toString().trim() ?? '';
    final username = author?['username']?.toString().trim() ?? '';
    final authorName = fullName.isNotEmpty
        ? fullName
        : (username.isNotEmpty ? username : 'QuranReflect');

    final createdAt =
        DateTime.tryParse(item['createdAt']?.toString() ?? '') ??
        DateTime.now();
    final updatedAt =
        DateTime.tryParse(item['updatedAt']?.toString() ?? '') ?? createdAt;

    return TadabburNote(
      id: rawId.startsWith('qr-') ? rawId : 'qr-$rawId',
      userId: 'qr-${author?['id']?.toString() ?? 'reader'}',
      surahId: chapterId.toString(),
      verseId: fromVerse.toString(),
      noteText: cleanBody,
      isPublic: true,
      isAnonymous: false,
      likesCount: (item['likesCount'] as num?)?.toInt() ?? 0,
      language: 'en',
      createdAt: createdAt,
      updatedAt: updatedAt,
      userEmail: authorName,
      userLiked: false,
      synced: true,
      source: 'quranreflect',
    );
  }

  String _stripHtmlTags(String raw) {
    if (raw.isEmpty) return '';
    return raw
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</(p|div|li|h[1-6])>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  List<TadabburNote> _curatedFallbackReflections() {
    final now = DateTime.utc(2026, 1, 1);
    return [
      TadabburNote(
        id: 'qr-curated-1',
        userId: 'qr-curated',
        surahId: '1',
        verseId: '1',
        noteText:
            'Beginning every action in the name of Allah, the Entirely Merciful, the Especially Merciful, transforms routine moments into conscious worship.',
        isPublic: true,
        isAnonymous: false,
        likesCount: 120,
        language: 'en',
        createdAt: now,
        updatedAt: now,
        userEmail: 'QuranReflect',
        source: 'quranreflect',
      ),
      TadabburNote(
        id: 'qr-curated-2',
        userId: 'qr-curated',
        surahId: '2',
        verseId: '255',
        noteText:
            'Ayat al-Kursi reminds the heart that Allah never slumbers nor sleeps. Whatever worries weigh us down tonight, His watchfulness and care never pause.',
        isPublic: true,
        isAnonymous: false,
        likesCount: 98,
        language: 'en',
        createdAt: now,
        updatedAt: now,
        userEmail: 'QuranReflect',
        source: 'quranreflect',
      ),
      TadabburNote(
        id: 'qr-curated-3',
        userId: 'qr-curated',
        surahId: '2',
        verseId: '286',
        noteText:
            'Allah does not burden a soul beyond that it can bear. The very fact that you are facing a trial is proof that He placed the capacity to endure within you.',
        isPublic: true,
        isAnonymous: false,
        likesCount: 95,
        language: 'en',
        createdAt: now,
        updatedAt: now,
        userEmail: 'QuranReflect',
        source: 'quranreflect',
      ),
      TadabburNote(
        id: 'qr-curated-4',
        userId: 'qr-curated',
        surahId: '18',
        verseId: '10',
        noteText:
            'The youth of the Cave asked for mercy first, then guidance. When we seek Allah’s mercy before clarity, He opens doors we could never plan ourselves.',
        isPublic: true,
        isAnonymous: false,
        likesCount: 84,
        language: 'en',
        createdAt: now,
        updatedAt: now,
        userEmail: 'QuranReflect',
        source: 'quranreflect',
      ),
      TadabburNote(
        id: 'qr-curated-5',
        userId: 'qr-curated',
        surahId: '36',
        verseId: '58',
        noteText:
            '"Peace," a word from a Merciful Lord. True tranquility is not the absence of worldly noise, but closeness to the One who speaks peace directly to the soul.',
        isPublic: true,
        isAnonymous: false,
        likesCount: 76,
        language: 'en',
        createdAt: now,
        updatedAt: now,
        userEmail: 'QuranReflect',
        source: 'quranreflect',
      ),
      TadabburNote(
        id: 'qr-curated-6',
        userId: 'qr-curated',
        surahId: '55',
        verseId: '13',
        noteText:
            'Every heartbeat, breath, and quiet blessing is an invitation to gratitude. Which of your Lord’s favors will you pause to thank Him for today?',
        isPublic: true,
        isAnonymous: false,
        likesCount: 88,
        language: 'en',
        createdAt: now,
        updatedAt: now,
        userEmail: 'QuranReflect',
        source: 'quranreflect',
      ),
      TadabburNote(
        id: 'qr-curated-7',
        userId: 'qr-curated',
        surahId: '67',
        verseId: '2',
        noteText:
            'Allah tests us to see which of us is best in deeds—not merely most in quantity, but most sincere and excellent in quality.',
        isPublic: true,
        isAnonymous: false,
        likesCount: 72,
        language: 'en',
        createdAt: now,
        updatedAt: now,
        userEmail: 'QuranReflect',
        source: 'quranreflect',
      ),
      TadabburNote(
        id: 'qr-curated-8',
        userId: 'qr-curated',
        surahId: '96',
        verseId: '1',
        noteText:
            '"Read in the name of your Lord who created." Sacred knowledge and learning begin with humility and connection to the Creator.',
        isPublic: true,
        isAnonymous: false,
        likesCount: 91,
        language: 'en',
        createdAt: now,
        updatedAt: now,
        userEmail: 'QuranReflect',
        source: 'quranreflect',
      ),
    ];
  }

  /// Upsert a single personal note to Supabase
  Future<TadabburNote?> saveNote(TadabburNote note) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final data = note.toJson();
      // Remove created_at if we are updating, or let DB handle defaults
      if (!data.containsKey('created_at') || data['created_at'] == null) {
        data['created_at'] = DateTime.now().toUtc().toIso8601String();
      }
      data['updated_at'] = DateTime.now().toUtc().toIso8601String();

      // If id is empty or a placeholder, remove it so DB generates one
      if (data['id'] == '' || data['id'].startsWith('temp-')) {
        data.remove('id');
      }

      final response = await _client.from('tadabbur_notes').upsert(data).select().single();
      return TadabburNote.fromJson(response);
    } catch (e) {
      debugPrint('TadabburRepository: Error saving note to Supabase: $e');
      rethrow;
    }
  }

  /// Delete a personal note by ID
  Future<void> deleteNote(String noteId) async {
    try {
      await _client.from('tadabbur_notes').delete().eq('id', noteId);
    } catch (e) {
      debugPrint('TadabburRepository: Error deleting note: $e');
      rethrow;
    }
  }

  /// Delete a personal note by (user_id, surah_id, verse_id)
  Future<void> deleteNoteByVerse(Object surahId, Object verseId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      await _client
          .from('tadabbur_notes')
          .delete()
          .eq('user_id', user.id)
          .eq('surah_id', surahId.toString())
          .eq('verse_id', verseId.toString());
    } catch (e) {
      debugPrint('TadabburRepository: Error deleting note by verse: $e');
      rethrow;
    }
  }

  /// Report an inappropriate community note (UGC compliance - POL-01)
  Future<void> reportCommunityNote({
    required String noteId,
    required String reason,
    String? details,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Authentication required');
    }
    try {
      await _client.from('tadabbur_reports').upsert(
        {
          'note_id': noteId,
          'reporter_user_id': user.id,
          'reason': reason,
          'details': details,
          'status': 'pending_review',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'note_id,reporter_user_id',
      );
    } catch (e) {
      debugPrint('TadabburRepository: Error reporting community note: $e');
      rethrow;
    }
  }

  /// Block a user from appearing in community Tadabbur feed (UGC compliance - POL-01)
  Future<void> blockUser(String blockedUserId) async {
    if (blockedUserId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final current = (prefs.getStringList(_blockedUsersPrefsKey) ?? <String>[]).toSet();
    current.add(blockedUserId);
    await prefs.setStringList(_blockedUsersPrefsKey, current.toList());

    final user = _client.auth.currentUser;
    if (user != null && user.id != blockedUserId) {
      try {
        await _client.from('user_blocks').upsert(
          {
            'blocker_user_id': user.id,
            'blocked_user_id': blockedUserId,
          },
          onConflict: 'blocker_user_id,blocked_user_id',
        );
      } catch (e) {
        debugPrint('TadabburRepository: Error syncing user block to Supabase: $e');
      }
    }
  }

  /// Retrieve set of blocked user IDs from local storage + Supabase (UGC compliance - POL-01)
  Future<Set<String>> getBlockedUserIds() async {
    final prefs = await SharedPreferences.getInstance();
    final blocked = (prefs.getStringList(_blockedUsersPrefsKey) ?? <String>[]).toSet();

    final user = _client.auth.currentUser;
    if (user != null) {
      try {
        final rows = await _client
            .from('user_blocks')
            .select('blocked_user_id')
            .eq('blocker_user_id', user.id);
        for (final row in (rows as List<dynamic>)) {
          final id = (row as Map<String, dynamic>)['blocked_user_id']?.toString();
          if (id != null && id.isNotEmpty) {
            blocked.add(id);
          }
        }
        await prefs.setStringList(_blockedUsersPrefsKey, blocked.toList());
      } catch (e) {
        debugPrint('TadabburRepository: Error fetching blocked users: $e');
      }
    }
    return blocked;
  }

  /// Toggle like for a note
  Future<bool> toggleLike(String noteId) async {
    try {
      final response = await _client.rpc('toggle_tadabbur_like', params: {'note_id_param': noteId});
      return response as bool; // true if liked, false if unliked
    } catch (e) {
      debugPrint('TadabburRepository: Error toggling like: $e');
      rethrow;
    }
  }

  /// Submit a note for admin review before making it public
  Future<void> submitForPublicReview(TadabburNote note) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Authentication required');

    final existing = await _client
        .from('translation_reports')
        .select('id')
        .eq('user_id', user.id)
        .eq('suggested_text', note.id)
        .eq('translation_version', 'tadabbur_review')
        .eq('status', 'open')
        .maybeSingle();

    if (existing != null) return;

    await _client.from('translation_reports').insert({
      'user_id': user.id,
      'surah_id': note.surahId,
      'verse_id': note.verseId,
      'translation_version': 'tadabbur_review',
      'issue_type': 'other',
      'comment': note.noteText,
      'suggested_text': note.id,
      'status': 'open',
      'source': kIsWeb ? 'web' : 'flutter',
    });
  }

  /// Cancel review request (reverting to private)
  Future<void> cancelReviewRequest(String noteId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      await _client
          .from('translation_reports')
          .delete()
          .eq('user_id', user.id)
          .eq('suggested_text', noteId)
          .eq('translation_version', 'tadabbur_review');
    } catch (e) {
      debugPrint('Error canceling review request: $e');
    }
  }

  /// Fetch map of noteId -> review status ('open', 'reviewing', 'accepted', 'rejected')
  Future<Map<String, String>> fetchUserReviewStatuses() async {
    final user = _client.auth.currentUser;
    if (user == null) return {};

    try {
      final response = await _client
          .from('translation_reports')
          .select('suggested_text, status')
          .eq('user_id', user.id)
          .eq('translation_version', 'tadabbur_review');

      final map = <String, String>{};
      for (final row in (response as List<dynamic>)) {
        final noteId = row['suggested_text']?.toString();
        final status = row['status']?.toString();
        if (noteId != null && status != null) {
          map[noteId] = status;
        }
      }
      return map;
    } catch (e) {
      debugPrint('TadabburRepository: Error fetching review statuses: $e');
      return {};
    }
  }

  /// Verify admin passphrase via Supabase RPC
  Future<bool> verifyAdminPassphrase(String candidate) async {
    try {
      final res = await _client.rpc(
        'verify_admin_passphrase',
        params: {'p_username': 'admin', 'p_passphrase': candidate.trim()},
      );
      return res == true;
    } catch (e) {
      debugPrint('Admin passphrase verification error: $e');
      return false;
    }
  }

  static String? _cachedAdminPassphrase;

  static void setAdminPassphrase(String passphrase) {
    _cachedAdminPassphrase = passphrase.trim();
  }

  static String? get cachedAdminPassphrase => _cachedAdminPassphrase;

  /// Admin method: fetch all tadabbur review requests
  Future<List<Map<String, dynamic>>> fetchAdminReviewRequests({String? passphrase}) async {
    final pass = passphrase ?? _cachedAdminPassphrase;

    // 1. Try secure HTTPS backend endpoint if passphrase is known
    if (pass != null && pass.isNotEmpty) {
      try {
        final uri = Uri.parse('https://quran-th.com/api/admin/tadabbur');
        final res = await http.get(uri, headers: {
          'x-admin-passphrase': pass,
        }).timeout(const Duration(seconds: 10));

        if (res.statusCode == 200) {
          final decoded = jsonDecode(res.body) as Map<String, dynamic>;
          final items = decoded['items'] as List<dynamic>?;
          if (items != null) {
            return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        }
      } catch (e) {
        debugPrint('REST fetchAdminReviewRequests error (falling back to Supabase): $e');
      }
    }

    // 2. Fallback to direct Supabase client
    try {
      final response = await _client
          .from('translation_reports')
          .select('*')
          .eq('translation_version', 'tadabbur_review')
          .order('created_at', ascending: false);

      final list = <Map<String, dynamic>>[];
      for (final r in (response as List<dynamic>)) {
        final row = Map<String, dynamic>.from(r as Map);
        list.add({
          'id': row['id'],
          'noteId': row['suggested_text'],
          'surahId': row['surah_id'],
          'verseId': row['verse_id'],
          'status': row['status'] ?? 'open',
          'noteText': row['comment'] ?? '',
          'reviewerNote': row['reviewer_note'],
          'userId': row['user_id'],
          'isPublic': false,
          'isAnonymous': false,
          'source': row['source'] ?? 'flutter',
          'createdAt': row['created_at'],
          'updatedAt': row['updated_at'],
        });
      }
      return list;
    } catch (e) {
      debugPrint('Error fetching admin review requests: $e');
      return [];
    }
  }

  /// Admin method: approve tadabbur note
  Future<bool> approveTadabburNote(String reportId, String noteId, {String? passphrase}) async {
    final pass = passphrase ?? _cachedAdminPassphrase;

    // 1. Try secure HTTPS backend endpoint
    if (pass != null && pass.isNotEmpty) {
      try {
        final uri = Uri.parse('https://quran-th.com/api/admin/tadabbur');
        final res = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'x-admin-passphrase': pass,
          },
          body: jsonEncode({
            'action': 'approve',
            'reportId': reportId,
            'noteId': noteId,
          }),
        ).timeout(const Duration(seconds: 10));

        if (res.statusCode == 200) return true;
      } catch (e) {
        debugPrint('REST approveTadabburNote error (falling back to Supabase): $e');
      }
    }

    // 2. Direct Supabase update
    try {
      await _client
          .from('translation_reports')
          .update({
            'status': 'accepted',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', reportId);

      await _client
          .from('tadabbur_notes')
          .update({
            'is_public': true,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', noteId);
      return true;
    } catch (e) {
      debugPrint('Error approving tadabbur note: $e');
      return false;
    }
  }

  /// Admin method: reject tadabbur note
  Future<bool> rejectTadabburNote(
    String reportId,
    String noteId, {
    String? reviewerNote,
    String? passphrase,
  }) async {
    final pass = passphrase ?? _cachedAdminPassphrase;

    // 1. Try secure HTTPS backend endpoint
    if (pass != null && pass.isNotEmpty) {
      try {
        final uri = Uri.parse('https://quran-th.com/api/admin/tadabbur');
        final res = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'x-admin-passphrase': pass,
          },
          body: jsonEncode({
            'action': 'reject',
            'reportId': reportId,
            'noteId': noteId,
            'reviewerNote': reviewerNote,
          }),
        ).timeout(const Duration(seconds: 10));

        if (res.statusCode == 200) return true;
      } catch (e) {
        debugPrint('REST rejectTadabburNote error (falling back to Supabase): $e');
      }
    }

    // 2. Direct Supabase update
    try {
      await _client
          .from('translation_reports')
          .update({
            'status': 'rejected',
            'reviewer_note': reviewerNote,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', reportId);

      await _client
          .from('tadabbur_notes')
          .update({
            'is_public': false,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', noteId);
      return true;
    } catch (e) {
      debugPrint('Error rejecting tadabbur note: $e');
      return false;
    }
  }
}
