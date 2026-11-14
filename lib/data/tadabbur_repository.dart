// lib/data/tadabbur_repository.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/tadabbur_note.dart';

class TadabburRepository {
  static const String _blockedUsersPrefsKey = 'blocked_tadabbur_user_ids';
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
