// lib/data/tadabbur_repository.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/tadabbur_note.dart';

class TadabburRepository {
  final _client = Supabase.instance.client;
  static const String _notesKey = 'personal_notes_v1';

  /// Syncs authenticated user's notes from Supabase to local SharedPreferences
  Future<void> syncFromSupabase() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      debugPrint('TadabburRepository: Sync skipped, user is unauthenticated.');
      return;
    }

    try {
      // 1. Fetch notes from Supabase where user_id matches
      final response = await _client
          .from('tadabbur_notes')
          .select()
          .eq('user_id', user.id);

      final List<dynamic> data = response as List<dynamic>;
      final remoteNotes = data.map((json) => TadabburNote.fromJson(json as Map<String, dynamic>)).toList();

      // 2. Load current local notes
      final prefs = await SharedPreferences.getInstance();
      final savedData = prefs.getString(_notesKey);
      Map<String, String> localNotes = {};
      if (savedData != null) {
        final Map<String, dynamic> decoded = json.decode(savedData);
        localNotes = decoded.map((key, value) => MapEntry(key, value.toString()));
      }

      // 3. Populate local notes from remote notes
      // Key format: "surahId:verseId"
      for (final remoteNote in remoteNotes) {
        final key = '${remoteNote.surahId}:${remoteNote.verseId}';
        localNotes[key] = remoteNote.noteText;
      }

      // 4. Save merged result to SharedPreferences
      await prefs.setString(_notesKey, json.encode(localNotes));
      debugPrint('TadabburRepository: Successfully synced ${remoteNotes.length} notes from Supabase.');
    } catch (e) {
      debugPrint('TadabburRepository: Error syncing notes from Supabase: $e');
      rethrow;
    }
  }

  /// Uploads local private notes to Supabase (synchronizes up)
  Future<void> uploadLocalNotes() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedData = prefs.getString(_notesKey);
      if (savedData == null) return;

      final Map<String, dynamic> decoded = json.decode(savedData);
      final localNotes = decoded.map((key, value) => MapEntry(key, value.toString()));

      for (final entry in localNotes.entries) {
        final parts = entry.key.split(':');
        if (parts.length != 2) continue;
        final surahId = parts[0];
        final verseId = parts[1];
        final noteText = entry.value;

        if (noteText.trim().isEmpty) continue;

        // Upsert to Supabase
        await _client.from('tadabbur_notes').upsert({
          'user_id': user.id,
          'surah_id': surahId,
          'verse_id': verseId,
          'note_text': noteText,
          'is_public': false,
          'language': 'th',
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
      debugPrint('TadabburRepository: Successfully uploaded local notes to Supabase.');
    } catch (e) {
      debugPrint('TadabburRepository: Error uploading notes to Supabase: $e');
    }
  }
}
