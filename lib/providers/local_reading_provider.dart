import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../shared/shared.dart';

class LocalReadingProfile {
  final String id;
  final String userId;
  final String name;
  final String slug;
  final String? planMode;
  final int? startJuz;
  final int? targetJuz;
  final VerseRef start;
  final VerseRef? target;
  final VerseRef current;
  final int sortOrder;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LocalReadingProfile({
    required this.id,
    required this.userId,
    required this.name,
    required this.slug,
    this.planMode,
    this.startJuz,
    this.targetJuz,
    required this.start,
    this.target,
    required this.current,
    required this.sortOrder,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
  });

  LocalReadingProfile copyWith({
    VerseRef? current,
    bool? isArchived,
    DateTime? updatedAt,
  }) {
    return LocalReadingProfile(
      id: id,
      userId: userId,
      name: name,
      slug: slug,
      planMode: planMode,
      startJuz: startJuz,
      targetJuz: targetJuz,
      start: start,
      target: target,
      current: current ?? this.current,
      sortOrder: sortOrder,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'slug': slug,
      if (planMode != null) 'planMode': planMode,
      if (startJuz != null) 'startJuz': startJuz,
      if (targetJuz != null) 'targetJuz': targetJuz,
      'startSurahId': start.surahId,
      'startVerseId': start.verseId,
      if (target != null) 'targetSurahId': target!.surahId,
      if (target != null) 'targetVerseId': target!.verseId,
      'currentSurahId': current.surahId,
      'currentVerseId': current.verseId,
      'sortOrder': sortOrder,
      'isArchived': isArchived,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory LocalReadingProfile.fromJson(Map<String, dynamic> json) {
    final targetSurahId = json['targetSurahId']?.toString();
    final targetVerseId = json['targetVerseId']?.toString();

    return LocalReadingProfile(
      id: json['id'].toString(),
      userId: json['userId']?.toString() ?? 'local',
      name: json['slug'] == 'main_read' || json['name'] == 'Main Read'
          ? 'Free Read'
          : json['name'].toString(),
      slug: json['slug'] == 'main_read' ? 'free_read' : json['slug'].toString(),
      planMode: json['planMode']?.toString(),
      startJuz: int.tryParse(json['startJuz']?.toString() ?? ''),
      targetJuz: int.tryParse(json['targetJuz']?.toString() ?? ''),
      start: toVerseRef(json['startSurahId'], json['startVerseId']),
      target: targetSurahId != null && targetVerseId != null
          ? toVerseRef(targetSurahId, targetVerseId)
          : null,
      current: toVerseRef(json['currentSurahId'], json['currentVerseId']),
      sortOrder: int.tryParse(json['sortOrder']?.toString() ?? '') ?? 0,
      isArchived: json['isArchived'] == true,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class LocalBookmarkCategory {
  final String id;
  final String userId;
  final String name;
  final String slug;
  final int maxItems;
  final int sortOrder;

  const LocalBookmarkCategory({
    required this.id,
    required this.userId,
    required this.name,
    required this.slug,
    required this.maxItems,
    required this.sortOrder,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'slug': slug,
      'maxItems': maxItems,
      'sortOrder': sortOrder,
    };
  }

  factory LocalBookmarkCategory.fromJson(Map<String, dynamic> json) {
    return LocalBookmarkCategory(
      id: json['id'].toString(),
      userId: json['userId']?.toString() ?? 'local',
      name: json['name'].toString(),
      slug: json['slug'].toString(),
      maxItems:
          int.tryParse(json['maxItems']?.toString() ?? '') ??
          defaultBookmarkCategoryMaxItems,
      sortOrder: int.tryParse(json['sortOrder']?.toString() ?? '') ?? 0,
    );
  }
}

class LocalBookmark {
  final String id;
  final String userId;
  final String categoryId;
  final VerseRef verse;
  final String? label;
  final String? note;
  final int sortOrder;
  final DateTime createdAt;

  const LocalBookmark({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.verse,
    this.label,
    this.note,
    required this.sortOrder,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'categoryId': categoryId,
      'surahId': verse.surahId,
      'verseId': verse.verseId,
      if (label != null) 'label': label,
      if (note != null) 'note': note,
      'sortOrder': sortOrder,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory LocalBookmark.fromJson(Map<String, dynamic> json) {
    return LocalBookmark(
      id: json['id'].toString(),
      userId: json['userId']?.toString() ?? 'local',
      categoryId: json['categoryId'].toString(),
      verse: toVerseRef(json['surahId'], json['verseId']),
      label: json['label']?.toString(),
      note: json['note']?.toString(),
      sortOrder: int.tryParse(json['sortOrder']?.toString() ?? '') ?? 0,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class LocalRecentReading {
  final String id;
  final String userId;
  final VerseRef verse;
  final String? profileId;
  final DateTime readAt;

  const LocalRecentReading({
    required this.id,
    required this.userId,
    required this.verse,
    this.profileId,
    required this.readAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'surahId': verse.surahId,
      'verseId': verse.verseId,
      if (profileId != null) 'profileId': profileId,
      'readAt': readAt.toIso8601String(),
    };
  }

  factory LocalRecentReading.fromJson(Map<String, dynamic> json) {
    return LocalRecentReading(
      id: json['id'].toString(),
      userId: json['userId']?.toString() ?? 'local',
      verse: toVerseRef(json['surahId'], json['verseId']),
      profileId: json['profileId']?.toString(),
      readAt:
          DateTime.tryParse(json['readAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class LocalReadingProvider extends ChangeNotifier {
  static const _storageKey = 'thai_quran_local_reading_store_v1';
  static const _localUserId = 'local';

  List<LocalReadingProfile> _profiles = [];
  List<LocalBookmarkCategory> _categories = [];
  List<LocalBookmark> _bookmarks = [];
  List<LocalRecentReading> _recentReadings = [];

  List<LocalReadingProfile> get profiles => List.unmodifiable(_profiles);
  List<LocalReadingProfile> get activeProfiles =>
      _profiles.where((profile) => !profile.isArchived).toList(growable: false);
  List<LocalReadingProfile> get archivedProfiles =>
      _profiles.where((profile) => profile.isArchived).toList(growable: false);
  List<LocalBookmarkCategory> get categories => List.unmodifiable(_categories);
  List<LocalBookmark> get bookmarks => List.unmodifiable(_bookmarks);
  List<LocalRecentReading> get recentReadings =>
      List.unmodifiable(_recentReadings);

  bool get canCreateProfile =>
      canCreateActiveReadingProfile(activeProfiles.length);

  LocalReadingProvider() {
    _load();
  }

  Future<LocalReadingProfile> createProfile({
    required String name,
    required VerseRef start,
    VerseRef? target,
    VerseRef? current,
    String? planMode,
    int? startJuz,
    int? targetJuz,
  }) async {
    if (!canCreateProfile) {
      throw StateError(
        'Only $maxActiveReadingProfiles active reading profiles are allowed.',
      );
    }

    final now = DateTime.now();
    final slug = _uniqueSlug(slugifyReadingProfileName(name));
    final profile = LocalReadingProfile(
      id: _createLocalId(),
      userId: _localUserId,
      name: name,
      slug: slug,
      planMode: planMode,
      startJuz: startJuz,
      targetJuz: targetJuz,
      start: start,
      target: target,
      current: current ?? start,
      sortOrder: activeProfiles.length,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    );

    _profiles.add(profile);
    await _save();
    notifyListeners();
    return profile;
  }

  Future<void> updateProfileProgress(String profileId, VerseRef current) async {
    _profiles = _profiles
        .map(
          (profile) => profile.id == profileId
              ? profile.copyWith(current: current, updatedAt: DateTime.now())
              : profile,
        )
        .toList();
    await _save();
    notifyListeners();
  }

  Future<void> archiveProfile(String profileId) async {
    final profile = _profiles.where((item) => item.id == profileId).firstOrNull;
    if (profile == null || isFreeReadProfile(profile)) return;

    _profiles = _profiles
        .map(
          (profile) => profile.id == profileId
              ? profile.copyWith(isArchived: true, updatedAt: DateTime.now())
              : profile,
        )
        .toList();
    await _save();
    notifyListeners();
  }

  Future<void> restoreProfile(String profileId) async {
    if (!canCreateProfile) {
      throw StateError(
        'Only $maxActiveReadingProfiles active reading profiles are allowed.',
      );
    }

    _profiles = _profiles
        .map(
          (profile) => profile.id == profileId
              ? profile.copyWith(isArchived: false, updatedAt: DateTime.now())
              : profile,
        )
        .toList();
    await _save();
    notifyListeners();
  }

  Future<LocalBookmarkCategory> ensureBookmarkCategory({
    String name = 'Saved Verses',
    int maxItems = defaultBookmarkCategoryMaxItems,
  }) async {
    final slug = slugifyReadingProfileName(name);
    final existing = _categories
        .where((category) => category.slug == slug)
        .firstOrNull;
    if (existing != null) return existing;

    final category = LocalBookmarkCategory(
      id: _createLocalId(),
      userId: _localUserId,
      name: name,
      slug: slug,
      maxItems: maxItems,
      sortOrder: _categories.length,
    );

    _categories.add(category);
    await _save();
    notifyListeners();
    return category;
  }

  Future<LocalBookmark> addBookmark({
    required VerseRef verse,
    String? categoryId,
    String? label,
    String? note,
  }) async {
    final category = categoryId == null
        ? await ensureBookmarkCategory()
        : _categories.firstWhere((item) => item.id == categoryId);
    final categoryBookmarks = _bookmarks
        .where((bookmark) => bookmark.categoryId == category.id)
        .toList();

    final existing = categoryBookmarks
        .where((bookmark) => bookmark.verse.verseKey == verse.verseKey)
        .firstOrNull;
    if (existing != null) return existing;

    if (categoryBookmarks.length >= category.maxItems) {
      throw StateError(
        'This bookmark category allows ${category.maxItems} items.',
      );
    }

    final bookmark = LocalBookmark(
      id: _createLocalId(),
      userId: _localUserId,
      categoryId: category.id,
      verse: verse,
      label: label,
      note: note,
      sortOrder: categoryBookmarks.length,
      createdAt: DateTime.now(),
    );

    _bookmarks.add(bookmark);
    await _save();
    notifyListeners();
    return bookmark;
  }

  Future<void> removeBookmark(String bookmarkId) async {
    _bookmarks = _bookmarks
        .where((bookmark) => bookmark.id != bookmarkId)
        .toList();
    await _save();
    notifyListeners();
  }

  Future<void> addRecentReading({
    required VerseRef verse,
    String? profileId,
    int limit = defaultRecentReadingsLimit,
  }) async {
    final reading = LocalRecentReading(
      id: _createLocalId(),
      userId: _localUserId,
      verse: verse,
      profileId: profileId,
      readAt: DateTime.now(),
    );

    _recentReadings = [
      reading,
      ..._recentReadings.where(
        (item) =>
            item.verse.verseKey != verse.verseKey ||
            item.profileId != profileId,
      ),
    ].take(limit).toList();

    await _save();
    notifyListeners();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null) return;

      final decoded = json.decode(raw) as Map<String, dynamic>;
      _profiles = _decodeList(
        decoded['profiles'],
        LocalReadingProfile.fromJson,
      );
      _categories = _decodeList(
        decoded['categories'],
        LocalBookmarkCategory.fromJson,
      );
      _bookmarks = _decodeList(decoded['bookmarks'], LocalBookmark.fromJson);
      _recentReadings = _decodeList(
        decoded['recentReadings'],
        LocalRecentReading.fromJson,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading local reading store: $e');
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      json.encode({
        'profiles': _profiles.map((profile) => profile.toJson()).toList(),
        'categories': _categories.map((category) => category.toJson()).toList(),
        'bookmarks': _bookmarks.map((bookmark) => bookmark.toJson()).toList(),
        'recentReadings': _recentReadings
            .map((reading) => reading.toJson())
            .toList(),
      }),
    );
  }

  List<T> _decodeList<T>(
    Object? value,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((item) => fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  String _uniqueSlug(String slug) {
    final existingSlugs = _profiles.map((profile) => profile.slug).toSet();
    if (!existingSlugs.contains(slug)) return slug;

    var index = 2;
    var next = '${slug}_$index';
    while (existingSlugs.contains(next)) {
      index += 1;
      next = '${slug}_$index';
    }
    return next;
  }

  String _createLocalId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_profiles.length}_${_bookmarks.length}';
}

bool isFreeReadProfile(LocalReadingProfile profile) {
  return profile.slug == 'free_read' ||
      profile.slug == 'main_read' ||
      profile.name == 'Free Read';
}
