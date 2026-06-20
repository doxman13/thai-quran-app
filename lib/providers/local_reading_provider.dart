import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  String? _activeProfileId;

  StreamSubscription<AuthState>? _authSubscription;
  Timer? _saveTimer;

  List<LocalReadingProfile> get profiles => List.unmodifiable(_profiles);
  List<LocalReadingProfile> get activeProfiles =>
      _profiles.where((profile) => !profile.isArchived).toList(growable: false);
  List<LocalReadingProfile> get archivedProfiles =>
      _profiles.where((profile) => profile.isArchived).toList(growable: false);
  List<LocalBookmarkCategory> get categories => List.unmodifiable(_categories);
  List<LocalBookmark> get bookmarks => List.unmodifiable(_bookmarks);
  List<LocalRecentReading> get recentReadings =>
      List.unmodifiable(_recentReadings);
  String? get activeProfileId => _activeProfileId;
  LocalReadingProfile? get activeProfile {
    if (_profiles.isEmpty) return null;
    final active = _profiles.where((profile) => profile.id == _activeProfileId);
    if (active.isNotEmpty) return active.first;
    return activeProfiles.isNotEmpty ? activeProfiles.first : _profiles.first;
  }

  bool get canCreateProfile =>
      canCreateActiveReadingProfile(activeProfiles.length);

  LocalReadingProvider() {
    _load();
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final user = data.session?.user;
      if (user != null) {
        await syncBookmarksAndProfilesWithSupabase(user.id);
      } else {
        await _load();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    if (_saveTimer != null) {
      _saveTimer!.cancel();
      _executeSave();
    }
    super.dispose();
  }

  Future<void> syncBookmarksAndProfilesWithSupabase(String userId) async {
    try {
      final client = Supabase.instance.client;
      // Get the default category ID
      final catQuery = await client
          .from('bookmark_categories')
          .select('id')
          .eq('user_id', userId)
          .eq('slug', 'saved_verses')
          .maybeSingle();

      String? serverCatId = catQuery?['id']?.toString();
      if (serverCatId == null) {
        final upserted = await client
            .from('bookmark_categories')
            .upsert({
              'user_id': userId,
              'name': 'Saved Verses',
              'slug': 'saved_verses',
              'max_items': 5,
              'sort_order': 0,
            })
            .select('id')
            .single();
        serverCatId = upserted['id']?.toString();
      }

      if (serverCatId != null) {
        // Push any local unsynced bookmarks
        final unsyncedLocalBookmarks = _bookmarks.where((b) => b.userId == 'local').toList();
        for (final b in unsyncedLocalBookmarks) {
          try {
            await client.from('bookmarks').upsert({
              'user_id': userId,
              'category_id': serverCatId,
              'surah_id': b.verse.surahId,
              'verse_id': b.verse.verseId,
              'label': b.label,
              'note': b.note,
              'sort_order': b.sortOrder,
            });
          } catch (e) {
            debugPrint('Error pushing unsynced bookmark: $e');
          }
        }

        // Fetch remote bookmarks
        final response = await client
            .from('bookmarks')
            .select('id, surah_id, verse_id, label, note, sort_order, created_at, category_id')
            .eq('user_id', userId);

        final List<dynamic> dbBookmarks = response;
        final List<LocalBookmark> syncedBookmarks = [];

        for (final dbB in dbBookmarks) {
          syncedBookmarks.add(LocalBookmark(
            id: dbB['id'].toString(),
            userId: userId,
            categoryId: dbB['category_id'].toString(),
            verse: toVerseRef(dbB['surah_id'], dbB['verse_id']),
            label: dbB['label']?.toString(),
            note: dbB['note']?.toString(),
            sortOrder: int.tryParse(dbB['sort_order']?.toString() ?? '') ?? 0,
            createdAt: DateTime.tryParse(dbB['created_at']?.toString() ?? '') ?? DateTime.now(),
          ));
        }

        _bookmarks = syncedBookmarks;
        _categories = [
          LocalBookmarkCategory(
            id: serverCatId,
            userId: userId,
            name: 'Saved Verses',
            slug: 'saved_verses',
            maxItems: 5,
            sortOrder: 0,
          )
        ];

        // Update profiles userId
        _profiles = _profiles.map((p) {
          if (p.userId == 'local') {
            return LocalReadingProfile(
              id: p.id,
              userId: userId,
              name: p.name,
              slug: p.slug,
              planMode: p.planMode,
              startJuz: p.startJuz,
              targetJuz: p.targetJuz,
              start: p.start,
              target: p.target,
              current: p.current,
              sortOrder: p.sortOrder,
              isArchived: p.isArchived,
              createdAt: p.createdAt,
              updatedAt: p.updatedAt,
            );
          }
          return p;
        }).toList();

        await _save(immediate: true);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error syncing bookmarks/profiles with Supabase: $e');
    }
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
    _activeProfileId = profile.id;
    await _save(immediate: true);
    notifyListeners();
    return profile;
  }

  Future<void> setActiveProfile(String profileId) async {
    if (!_profiles.any((profile) => profile.id == profileId)) return;
    _activeProfileId = profileId;
    await _save(immediate: true);
    notifyListeners();
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
    await _save(immediate: true);
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
    await _save(immediate: true);
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
    await _save(immediate: true);
    notifyListeners();
    return category;
  }

  bool isBookmarked(String surahId, String verseId) {
    return _bookmarks.any((b) => b.verse.surahId == surahId && b.verse.verseId == verseId);
  }

  Future<void> toggleBookmark(String surahId, String verseId) async {
    final existing = _bookmarks.where(
      (b) => b.verse.surahId == surahId && b.verse.verseId == verseId
    ).firstOrNull;

    if (existing != null) {
      await removeBookmark(existing.id);
    } else {
      await addBookmark(
        verse: toVerseRef(surahId, verseId),
      );
    }
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

    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user != null) {
      try {
        final inserted = await client.from('bookmarks').insert({
          'user_id': user.id,
          'category_id': category.id,
          'surah_id': verse.surahId,
          'verse_id': verse.verseId,
          if (label != null) 'label': label,
          if (note != null) 'note': note,
          'sort_order': categoryBookmarks.length,
        }).select('id').single();

        final bookmark = LocalBookmark(
          id: inserted['id'].toString(),
          userId: user.id,
          categoryId: category.id,
          verse: verse,
          label: label,
          note: note,
          sortOrder: categoryBookmarks.length,
          createdAt: DateTime.now(),
        );

        _bookmarks.add(bookmark);
        await _save(immediate: true);
        notifyListeners();
        return bookmark;
      } catch (e) {
        debugPrint('Error adding bookmark to Supabase: $e');
      }
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
    await _save(immediate: true);
    notifyListeners();
    return bookmark;
  }

  Future<void> removeBookmark(String bookmarkId) async {
    final bookmark = _bookmarks.where((bookmark) => bookmark.id == bookmarkId).firstOrNull;
    if (bookmark == null) return;

    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user != null && bookmark.userId != 'local') {
      try {
        await client.from('bookmarks').delete().eq('id', bookmarkId);
      } catch (e) {
        debugPrint('Error removing bookmark from Supabase: $e');
      }
    }

    _bookmarks = _bookmarks
        .where((bookmark) => bookmark.id != bookmarkId)
        .toList();
    await _save(immediate: true);
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
      if (raw == null) {
        _ensureDefaultProfile();
        await _migrateLegacyBookmarks();
        await _save(immediate: true);
        notifyListeners();
        return;
      }

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
      _activeProfileId = decoded['activeProfileId']?.toString();
      _ensureDefaultProfile();
      if (activeProfile == null) {
        _activeProfileId = activeProfiles.isNotEmpty
            ? activeProfiles.first.id
            : null;
      }
      await _migrateLegacyBookmarks();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading local reading store: $e');
      _ensureDefaultProfile();
      notifyListeners();
    }
  }

  Future<void> _migrateLegacyBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getStringList('manual_bookmarks');
      if (legacy != null && legacy.isNotEmpty) {
        final category = await ensureBookmarkCategory();
        for (final item in legacy) {
          final parts = item.split(':');
          if (parts.length == 2) {
            final verse = toVerseRef(parts[0], parts[1]);
            if (!_bookmarks.any((b) => b.verse.verseKey == verse.verseKey)) {
              final bookmark = LocalBookmark(
                id: _createLocalId(),
                userId: _localUserId,
                categoryId: category.id,
                verse: verse,
                sortOrder: _bookmarks.length,
                createdAt: DateTime.now(),
              );
              _bookmarks.add(bookmark);
            }
          }
        }
        await prefs.remove('manual_bookmarks');
        await _save(immediate: true);
      }
    } catch (e) {
      debugPrint('Error migrating legacy bookmarks: $e');
    }
  }

  Future<void> _save({bool immediate = false}) async {
    if (immediate) {
      _saveTimer?.cancel();
      _saveTimer = null;
      await _executeSave();
    } else {
      _saveTimer?.cancel();
      _saveTimer = Timer(const Duration(seconds: 1), () {
        _executeSave();
      });
    }
  }

  Future<void> _executeSave() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      json.encode({
        'activeProfileId': _activeProfileId,
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

  void _ensureDefaultProfile() {
    if (_profiles.any(isFreeReadProfile)) return;

    final now = DateTime.now();
    final profile = LocalReadingProfile(
      id: _createLocalId(),
      userId: _localUserId,
      name: 'Free Read',
      slug: 'free_read',
      start: toVerseRef(1, 1),
      current: toVerseRef(1, 1),
      sortOrder: 0,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    );

    _profiles.insert(0, profile);
    _activeProfileId ??= profile.id;
  }
}

bool isFreeReadProfile(LocalReadingProfile profile) {
  return profile.slug == 'free_read' ||
      profile.slug == 'main_read' ||
      profile.name == 'Free Read';
}
