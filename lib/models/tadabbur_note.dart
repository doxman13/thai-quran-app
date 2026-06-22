// lib/models/tadabbur_note.dart

class TadabburNote {
  final String id;
  final String userId;
  final String surahId;
  final String verseId;
  final String noteText;
  final bool isPublic;
  final String language;
  final DateTime createdAt;

  TadabburNote({
    required this.id,
    required this.userId,
    required this.surahId,
    required this.verseId,
    required this.noteText,
    required this.isPublic,
    required this.language,
    required this.createdAt,
  });

  factory TadabburNote.fromJson(Map<String, dynamic> json) {
    return TadabburNote(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      surahId: json['surah_id'] as String,
      verseId: json['verse_id'] as String,
      noteText: json['note_text'] as String,
      isPublic: json['is_public'] as bool? ?? false,
      language: json['language'] as String? ?? 'th',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'surah_id': surahId,
      'verse_id': verseId,
      'note_text': noteText,
      'is_public': isPublic,
      'language': language,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
