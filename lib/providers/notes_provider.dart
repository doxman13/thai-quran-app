// lib/providers/notes_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotesProvider extends ChangeNotifier {
  static const String _notesKey = 'personal_notes_v1';
  Map<String, String> _notes = {};

  Map<String, String> get notes => _notes;

  NotesProvider() {
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedData = prefs.getString(_notesKey);
      if (savedData != null) {
        final Map<String, dynamic> decoded = json.decode(savedData);
        _notes = decoded.map((key, value) => MapEntry(key, value.toString()));
      }
    } catch (e) {
      debugPrint('Error loading notes: $e');
    }
    notifyListeners();
  }

  String getNoteForVerse(String surahId, String verseId) {
    return _notes['$surahId:$verseId'] ?? '';
  }

  Future<void> saveNote(String surahId, String verseId, String noteText) async {
    final key = '$surahId:$verseId';
    if (noteText.trim().isEmpty) {
      _notes.remove(key);
    } else {
      _notes[key] = noteText.trim();
    }
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_notesKey, json.encode(_notes));
    } catch (e) {
      debugPrint('Error saving notes: $e');
    }
  }

  Future<void> deleteNote(String surahId, String verseId) async {
    await saveNote(surahId, verseId, '');
  }
}
