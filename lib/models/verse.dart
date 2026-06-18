// lib/models/verse.dart
class Verse {
  final String id;
  final String surahId;
  String arabic;
  final String thaiV3;
  final String thaiV2;
  final String english;
  bool isArabicLoading;

  Verse({
    required this.id,
    required this.surahId,
    required this.arabic,
    required this.thaiV3,
    required this.thaiV2,
    required this.english,
    this.isArabicLoading = false,
  });
}
