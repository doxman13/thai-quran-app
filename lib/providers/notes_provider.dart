// lib/providers/notes_provider.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/tadabbur_repository.dart';
import '../models/tadabbur_note.dart';
import '../services/guest_lifecycle_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotesProvider extends ChangeNotifier {
  static const String _notesKey = 'personal_notes_v2';
  static const String _deletedNotesKey = 'deleted_note_keys_v1';
  Map<String, TadabburNote> _personalNotes = {};
  Set<String> _deletedNoteKeys = {};
  final TadabburRepository _repo = TadabburRepository();
  StreamSubscription<AuthState>? _authSubscription;

  Map<String, TadabburNote> get personalNotes => _personalNotes;
  Set<String> get deletedNoteKeys => Set.unmodifiable(_deletedNoteKeys);

  NotesProvider() {
    _loadNotes();
    // Auto-sync on startup if a user session is active
    syncWithSupabase();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      if (data.session?.user != null) {
        syncWithSupabase();
      }
    });
  }

  Future<void> syncWithSupabase() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // 1. Process pending offline deletions
      if (_deletedNoteKeys.isNotEmpty) {
        final toRemove = <String>[];
        for (final delKey in _deletedNoteKeys) {
          final parts = delKey.split(':');
          if (parts.length == 2) {
            try {
              await _repo.deleteNoteByVerse(parts[0], parts[1]);
              toRemove.add(delKey);
            } catch (e) {
              debugPrint('NotesProvider: Error syncing note deletion ($delKey): $e');
            }
          }
        }
        if (toRemove.isNotEmpty) {
          _deletedNoteKeys.removeAll(toRemove);
          await _saveDeletedNoteKeys();
        }
      }

      final remoteNotes = await _repo.fetchUserNotes();
      final remoteByVerse = {
        for (final note in remoteNotes)
          if (!_deletedNoteKeys.contains('${note.surahId}:${note.verseId}'))
            '${note.surahId}:${note.verseId}': note,
      };

      for (final entry in Map<String, TadabburNote>.from(
        _personalNotes,
      ).entries) {
        if (_deletedNoteKeys.contains(entry.key)) continue;
        final local = entry.value;
        final remote = remoteByVerse[entry.key];
        if (remote != null && !local.updatedAt.isAfter(remote.updatedAt)) {
          continue;
        }

        final noteToSave = TadabburNote(
          id: remote?.id ?? local.id,
          userId: user.id,
          surahId: local.surahId,
          verseId: local.verseId,
          noteText: local.noteText,
          isPublic: local.isPublic,
          isAnonymous: local.isAnonymous,
          likesCount: remote?.likesCount ?? local.likesCount,
          language: local.language,
          createdAt: remote?.createdAt ?? local.createdAt,
          updatedAt: local.updatedAt,
          userLiked: remote?.userLiked ?? local.userLiked,
          synced: true,
        );
        final saved = await _repo.saveNote(noteToSave);
        if (saved != null) {
          remoteByVerse[entry.key] = saved.copyWith(synced: true);
        }
      }

      _personalNotes = {
        ..._personalNotes,
        for (final entry in remoteByVerse.entries) entry.key: entry.value,
      };
      await _saveLocalCache();
      notifyListeners();
    } catch (e) {
      debugPrint('NotesProvider: Error syncing notes: $e');
    }
  }

  Future<void> _loadNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Flush local guest notes if inactive >= 30 days
      if (await GuestLifecycleService.isGuestInactiveExpired(prefs)) {
        await prefs.remove(_notesKey);
        await prefs.remove(_deletedNotesKey);
        _personalNotes = {};
        _deletedNoteKeys = {};
        notifyListeners();
        return;
      }

      final savedDeleted = prefs.getStringList(_deletedNotesKey);
      if (savedDeleted != null) {
        _deletedNoteKeys = savedDeleted.toSet();
      }

      final savedData = prefs.getString(_notesKey);
      if (savedData != null) {
        final Map<String, dynamic> decoded = json.decode(savedData);
        _personalNotes = decoded.map(
          (key, value) => MapEntry(
            key,
            TadabburNote.fromJson(value as Map<String, dynamic>),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error loading notes: $e');
    }
    notifyListeners();
  }

  Future<void> _saveLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> toSave = _personalNotes.map(
        (key, value) => MapEntry(key, value.toJson()),
      );
      await prefs.setString(_notesKey, json.encode(toSave));
    } catch (e) {
      debugPrint('Error saving notes to cache: $e');
    }
  }

  Future<void> _saveDeletedNoteKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_deletedNotesKey, _deletedNoteKeys.toList());
    } catch (e) {
      debugPrint('Error saving deleted note keys: $e');
    }
  }

  TadabburNote? getNoteObjectForVerse(String surahId, String verseId) {
    return _personalNotes['$surahId:$verseId'];
  }

  String getNoteForVerse(String surahId, String verseId) {
    return _personalNotes['$surahId:$verseId']?.noteText ?? '';
  }

  Future<void> saveNote({
    required String surahId,
    required String verseId,
    required String noteText,
    bool isPublic = false,
    bool isAnonymous = false,
  }) async {
    final key = '$surahId:$verseId';
    final existing = _personalNotes[key];

    final user = Supabase.instance.client.auth.currentUser;
    final isGuest = user == null;

    final note = TadabburNote(
      id: existing?.id ?? 'temp-${DateTime.now().millisecondsSinceEpoch}',
      userId: user?.id ?? 'guest',
      surahId: surahId,
      verseId: verseId,
      noteText: noteText.trim(),
      isPublic: isPublic,
      isAnonymous: isAnonymous,
      likesCount: existing?.likesCount ?? 0,
      language: 'th',
      createdAt: existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      userLiked: existing?.userLiked ?? false,
      synced: !isGuest,
    );

    _personalNotes[key] = note;
    _deletedNoteKeys.remove(key);
    await _saveDeletedNoteKeys();
    notifyListeners();
    await _saveLocalCache();

    if (isGuest) {
      await GuestLifecycleService.touchGuestActivity();
      return;
    }

    try {
      final savedNote = await _repo.saveNote(note);
      if (savedNote != null) {
        _personalNotes[key] = savedNote.copyWith(synced: true);
        await _saveLocalCache();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error saving note to supabase: $e');
      await _saveLocalCache();
    }
  }

  Future<void> deleteNote(String surahId, String verseId) async {
    final key = '$surahId:$verseId';
    final note = _personalNotes[key];
    if (note == null && !_deletedNoteKeys.contains(key)) return;

    _personalNotes.remove(key);
    _deletedNoteKeys.add(key);
    notifyListeners();
    await _saveLocalCache();
    await _saveDeletedNoteKeys();

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        await _repo.deleteNoteByVerse(surahId, verseId);
        _deletedNoteKeys.remove(key);
        await _saveDeletedNoteKeys();
      } catch (e) {
        debugPrint('Error deleting note from supabase: $e');
      }
    }
  }

  /// Wipes all personal notes and pending deletion tombstones on account deletion.
  Future<void> clearAllLocal() async {
    _personalNotes.clear();
    _deletedNoteKeys.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_notesKey);
      await prefs.remove(_deletedNotesKey);
    } catch (e) {
      debugPrint('Error clearing local notes: $e');
    }
    notifyListeners();
  }

  /// Toggle like locally and remotely
  Future<void> toggleLikeLocally(
    TadabburNote note,
    VoidCallback onLikedChanged,
  ) async {
    try {
      await _repo.toggleLike(note.id);
      // We can't mutate the final properties easily, so this should just refresh community notes
      onLikedChanged();
    } catch (e) {
      debugPrint('Failed to toggle like: $e');
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
