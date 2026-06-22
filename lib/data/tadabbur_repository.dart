// lib/data/tadabbur_repository.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/tadabbur_note.dart';

class TadabburRepository {
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

  /// Fetch public community notes for a specific verse
  Future<List<TadabburNote>> fetchCommunityNotes(String surahId, String verseId) async {
    try {
      final user = _client.auth.currentUser;
      
      var query = _client
          .from('tadabbur_notes')
          .select()
          .eq('surah_id', surahId)
          .eq('verse_id', verseId)
          .eq('is_public', true);

      if (user != null) {
        // Exclude current user's notes from community notes (they have their own tab)
        query = query.neq('user_id', user.id);
      }

      final response = await query.order('likes_count', ascending: false).order('created_at', ascending: false);
      final List<dynamic> data = response as List<dynamic>;
      
      // If we need to know if the user liked the note, we would ideally do a join or separate query.
      // For simplicity in V2, the RPC toggle_tadabbur_like handles the backend. 
      // The web app handles user_liked client side based on context.
      return data.map((json) => TadabburNote.fromJson(json as Map<String, dynamic>)).toList();
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
        data['created_at'] = DateTime.now().toIso8601String();
      }
      data['updated_at'] = DateTime.now().toIso8601String();

      // If id is empty or a placeholder, remove it so DB generates one
      if (data['id'] == '' || data['id'].startsWith('temp-')) {
        data.remove('id');
      }

      final response = await _client.from('tadabbur_notes').upsert(data).select().single();
      return TadabburNote.fromJson(response as Map<String, dynamic>);
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
}
