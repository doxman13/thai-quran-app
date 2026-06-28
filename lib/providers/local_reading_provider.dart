import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared/shared.dart';

class StorageException implements Exception {
  final String message;
  const StorageException(this.message);
  @override
  String toString() => message;
}

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
    String? name,
    String? slug,
    String? planMode,
    int? startJuz,
    int? targetJuz,
    VerseRef? start,
    VerseRef? target,
    bool clearTarget = false,
    VerseRef? current,
    bool? isArchived,
    DateTime? updatedAt,
  }) {
    return LocalReadingProfile(
      id: id,
      userId: userId,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      planMode: planMode ?? this.planMode,
      startJuz: startJuz ?? this.startJuz,
      targetJuz: targetJuz ?? this.targetJuz,
      start: start ?? this.start,
      target: clearTarget ? null : target ?? this.target,
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
  final Completer<void> _loadCompleter = Completer<void>();

  StreamSubscription<AuthState>? _authSubscription;
  Timer? _saveTimer;
  Timer? _recentReadingSyncTimer;
  String? _pendingSyncSurahId;
  String? _pendingSyncVerseId;
  String? _pendingSyncUserId;

  Timer? _readingStateSyncTimer;
  int? _pendingReadingStateSurahId;
  int? _pendingReadingStateVerseId;
  String? _pendingReadingStateUserId;

  String get currentUserId =>
      Supabase.instance.client.auth.currentUser?.id ?? _localUserId;

  List<LocalReadingProfile> get profiles {
    final userProfiles = _profiles
        .where((p) => p.userId == currentUserId)
        .toList();
    final hasCustomActive = userProfiles.any(
      (p) => !isFreeReadProfile(p) && !p.isArchived,
    );
    if (hasCustomActive) {
      return userProfiles.where((p) => !isFreeReadProfile(p)).toList();
    }
    return userProfiles;
  }

  List<LocalReadingProfile> get activeProfiles {
    final allActive = _profiles
        .where(
          (profile) => !profile.isArchived && profile.userId == currentUserId,
        )
        .toList();
    final hasCustomActive = allActive.any((p) => !isFreeReadProfile(p));
    if (hasCustomActive) {
      return allActive
          .where((p) => !isFreeReadProfile(p))
          .toList(growable: false);
    }
    return allActive;
  }

  List<LocalReadingProfile> get archivedProfiles {
    final allArchived = _profiles
        .where(
          (profile) => profile.isArchived && profile.userId == currentUserId,
        )
        .toList();
    return allArchived
        .where((p) => !isFreeReadProfile(p))
        .toList(growable: false);
  }

  List<LocalBookmarkCategory> get categories =>
      _categories.where((c) => c.userId == currentUserId).toList();
  List<LocalBookmark> get bookmarks =>
      _bookmarks.where((b) => b.userId == currentUserId).toList();
  List<LocalRecentReading> get recentReadings =>
      _recentReadings.where((r) => r.userId == currentUserId).toList();
  String? get activeProfileId => _activeProfileId;
  LocalReadingProfile? get freeReadProfile => _profiles
      .where((profile) => profile.userId == currentUserId)
      .where(isFreeReadProfile)
      .firstOrNull;

  LocalReadingProfile? profileById(String profileId) {
    return _profiles
        .where((profile) => profile.userId == currentUserId)
        .where((profile) => profile.id == profileId)
        .firstOrNull;
  }

  LocalReadingProfile? get activeProfile {
    final allUserProfiles = _profiles
        .where((p) => p.userId == currentUserId && !p.isArchived)
        .toList();
    final explicitActive = allUserProfiles
        .where((profile) => profile.id == _activeProfileId)
        .firstOrNull;
    if (explicitActive != null) return explicitActive;

    final userProfiles = profiles;
    if (userProfiles.isEmpty) return null;
    final active = userProfiles.where(
      (profile) => profile.id == _activeProfileId,
    );
    if (active.isNotEmpty) return active.first;
    final activeList = activeProfiles;
    return activeList.isNotEmpty ? activeList.first : userProfiles.first;
  }

  bool get canCreateProfile =>
      canCreateActiveReadingProfile(activeProfiles.length);

  bool isVerseInsideProfile(
    LocalReadingProfile profile,
    String surahId,
    String verseId,
  ) {
    if (profile.target == null || isFreeReadProfile(profile)) return true;

    final ref = toVerseRef(surahId, verseId);
    return _compareVerseRefs(ref, profile.start) >= 0 &&
        _compareVerseRefs(ref, profile.target!) <= 0;
  }

  Future<bool> switchToFreeReadIfOutside(String surahId, String verseId) async {
    final profile = activeProfile;
    final freeRead = freeReadProfile;
    if (profile == null ||
        freeRead == null ||
        isVerseInsideProfile(profile, surahId, verseId)) {
      return false;
    }

    final now = DateTime.now();
    final freeReadRef = toVerseRef(surahId, verseId);
    _profiles = _profiles
        .map(
          (item) => item.id == freeRead.id
              ? item.copyWith(current: freeReadRef, updatedAt: now)
              : item,
        )
        .toList();
    _activeProfileId = freeRead.id;
    await _save(immediate: true);
    notifyListeners();
    return true;
  }

  int _compareVerseRefs(VerseRef left, VerseRef right) {
    final leftSurah = int.tryParse(left.surahId) ?? 0;
    final rightSurah = int.tryParse(right.surahId) ?? 0;
    if (leftSurah != rightSurah) return leftSurah.compareTo(rightSurah);

    final leftVerse = int.tryParse(left.verseId) ?? 0;
    final rightVerse = int.tryParse(right.verseId) ?? 0;
    return leftVerse.compareTo(rightVerse);
  }

  LocalReadingProvider() {
    _load();
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) async {
      await _loadCompleter.future;
      final user = data.session?.user;
      if (user != null) {
        await syncBookmarksAndProfilesWithSupabase(user.id);
        await syncReadingStateWithSupabase(user.id);
      } else {
        // Guard logout: ensure guest profiles are preserved and default is active
        _ensureDefaultProfile();
        final guestActive = _profiles
            .where((p) => p.userId == _localUserId && !p.isArchived)
            .firstOrNull;
        _activeProfileId =
            guestActive?.id ??
            _profiles.where((p) => p.userId == _localUserId).firstOrNull?.id;
        await _save(immediate: true);
        notifyListeners();
      }
    });
  }

  LocalReadingProfile? _getLatestReadProfile(
    List<LocalReadingProfile> userProfiles,
  ) {
    final activeList = userProfiles.where((p) => !p.isArchived).toList();
    if (activeList.isEmpty) return null;

    // Sort by updatedAt descending (newest first)
    activeList.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final first = activeList.first;
    if (isFreeReadProfile(first)) {
      // If the newest read profile is "Free Read", look for the 2nd latest (which is NOT Free Read)
      for (int i = 1; i < activeList.length; i++) {
        if (!isFreeReadProfile(activeList[i])) {
          return activeList[i];
        }
      }
    }
    return first;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _recentReadingSyncTimer?.cancel();
    _readingStateSyncTimer?.cancel();
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
              'max_items': 9999,
              'sort_order': 0,
            })
            .select('id')
            .single();
        serverCatId = upserted['id']?.toString();
      }

      if (serverCatId != null) {
        // Push any local unsynced bookmarks
        final unsyncedLocalBookmarks = _bookmarks
            .where((b) => b.userId == 'local')
            .toList();
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
            .select(
              'id, surah_id, verse_id, label, note, sort_order, created_at, category_id',
            )
            .eq('user_id', userId);

        final List<dynamic> dbBookmarks = response;
        final List<LocalBookmark> syncedBookmarks = [];

        for (final dbB in dbBookmarks) {
          syncedBookmarks.add(
            LocalBookmark(
              id: dbB['id'].toString(),
              userId: userId,
              categoryId: dbB['category_id'].toString(),
              verse: toVerseRef(dbB['surah_id'], dbB['verse_id']),
              label: dbB['label']?.toString(),
              note: dbB['note']?.toString(),
              sortOrder: int.tryParse(dbB['sort_order']?.toString() ?? '') ?? 0,
              createdAt:
                  DateTime.tryParse(dbB['created_at']?.toString() ?? '') ??
                  DateTime.now(),
            ),
          );
        }

        final otherBookmarks = _bookmarks
            .where((b) => b.userId != userId)
            .toList();
        _bookmarks = otherBookmarks + syncedBookmarks;

        final otherCategories = _categories
            .where((c) => c.userId != userId)
            .toList();
        _categories =
            otherCategories +
            [
              LocalBookmarkCategory(
                id: serverCatId,
                userId: userId,
                name: 'Saved Verses',
                slug: 'saved_verses',
                maxItems: 5,
                sortOrder: 0,
              ),
            ];

        // Fetch remote recent readings
        try {
          final recentResponse = await client
              .from('recent_readings')
              .select('id, surah_id, last_read_verse, updated_at, profile_id')
              .eq('user_id', userId)
              .order('updated_at', ascending: false)
              .limit(20);

          final List<dynamic> dbRecent = recentResponse;
          final List<LocalRecentReading> syncedRecent = [];

          for (final dbR in dbRecent) {
            syncedRecent.add(
              LocalRecentReading(
                id: dbR['id'].toString(),
                userId: userId,
                verse: toVerseRef(dbR['surah_id'], dbR['last_read_verse']),
                profileId: dbR['profile_id']?.toString(),
                readAt:
                    DateTime.tryParse(dbR['updated_at']?.toString() ?? '') ??
                    DateTime.now(),
              ),
            );
          }

          final otherRecent = _recentReadings
              .where((r) => r.userId != userId)
              .toList();
          _recentReadings = otherRecent + syncedRecent;
        } catch (e) {
          debugPrint('Error syncing recent readings: $e');
        }

        // Push local guest profiles to Supabase user_reading_profiles
        final unsyncedGuestProfiles = _profiles
            .where((p) => p.userId == 'local')
            .toList();
        for (final p in unsyncedGuestProfiles) {
          try {
            final uuidRegExp = RegExp(
              r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
            );
            final bool hasUuid = uuidRegExp.hasMatch(p.id);

            final insertData = {
              'user_id': userId,
              'profile_name': p.name,
              'current_surah': int.tryParse(p.current.surahId) ?? 1,
              'current_ayah': int.tryParse(p.current.verseId) ?? 1,
              'last_read_at': p.updatedAt.toIso8601String(),
            };
            if (hasUuid) {
              insertData['id'] = p.id;
            }

            final response = hasUuid
                ? await client
                      .from('user_reading_profiles')
                      .upsert(insertData, onConflict: 'id')
                      .select('id')
                      .single()
                : await client
                      .from('user_reading_profiles')
                      .insert(insertData)
                      .select('id')
                      .single();

            final returnedId = response['id']?.toString();
            if (returnedId != null) {
              final idx = _profiles.indexWhere((item) => item.id == p.id);
              if (idx != -1) {
                _profiles[idx] = LocalReadingProfile(
                  id: returnedId,
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
            }
          } catch (e) {
            debugPrint('Error migrating guest profile: $e');
          }
        }

        // Run reconciliation
        await reconcileProfilesOnBoot(userId);

        await _save(immediate: true);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error syncing bookmarks/profiles with Supabase: $e');
    }
  }

  Future<void> reconcileProfilesOnBoot(String userId) async {
    try {
      final client = Supabase.instance.client;

      // 1. Fetch remote profiles from user_reading_profiles
      final response = await client
          .from('user_reading_profiles')
          .select('*')
          .eq('user_id', userId);

      final List<dynamic> dbProfiles = response;

      // Helper to check if string is a valid UUID
      final uuidRegExp = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      );
      bool isValidUuid(String id) => uuidRegExp.hasMatch(id);

      final List<LocalReadingProfile> reconciledProfiles = [];
      final Set<String> matchedRemoteIds = {};
      final Set<String> profilesToSync = {};
      bool localStateChanged = false;
      bool hasRemoteUpdates = false;

      // Index remote profiles by id and name (case-insensitive) for fast lookup
      final Map<String, Map<String, dynamic>> remoteById = {};
      final Map<String, Map<String, dynamic>> remoteByName = {};
      for (final dbP in dbProfiles) {
        final rId = dbP['id']?.toString();
        final rName = dbP['profile_name']?.toString();
        if (rId != null) remoteById[rId] = dbP;
        if (rName != null) remoteByName[rName.toLowerCase()] = dbP;
      }

      // Iterate through local profiles
      for (final localP in _profiles) {
        if (localP.userId != userId) {
          // Keep other users' or local guest profiles untouched
          reconciledProfiles.add(localP);
          continue;
        }

        // Try to match local profile with a remote profile
        Map<String, dynamic>? matchedRemote;
        if (isValidUuid(localP.id) && remoteById.containsKey(localP.id)) {
          matchedRemote = remoteById[localP.id];
        } else if (remoteByName.containsKey(localP.name.toLowerCase())) {
          matchedRemote = remoteByName[localP.name.toLowerCase()];
        }

        if (matchedRemote != null) {
          final remoteId = matchedRemote['id'].toString();
          matchedRemoteIds.add(remoteId);

          final remoteLastReadAt =
              DateTime.tryParse(
                matchedRemote['last_read_at']?.toString() ?? '',
              ) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final localUpdatedAt = localP.updatedAt;

          if (localUpdatedAt.isAfter(remoteLastReadAt)) {
            // Local is newer: keep local and mark for sync to remote
            reconciledProfiles.add(localP);
            profilesToSync.add(localP.id);
          } else {
            // Remote is newer or equal: update local with remote progress
            final remoteSurah =
                matchedRemote['current_surah']?.toString() ?? '1';
            final remoteAyah = matchedRemote['current_ayah']?.toString() ?? '1';

            if (remoteLastReadAt.isAfter(localUpdatedAt)) {
              hasRemoteUpdates = true;
            }

            final updatedP = LocalReadingProfile(
              id: remoteId, // Ensure local has the UUID from database
              userId: localP.userId,
              name: localP.name,
              slug: localP.slug,
              planMode: localP.planMode,
              startJuz: localP.startJuz,
              targetJuz: localP.targetJuz,
              start: localP.start,
              target: localP.target,
              current: toVerseRef(remoteSurah, remoteAyah),
              sortOrder: localP.sortOrder,
              isArchived: localP.isArchived,
              createdAt: localP.createdAt,
              updatedAt: remoteLastReadAt,
            );
            reconciledProfiles.add(updatedP);
            localStateChanged = true;
          }
        } else {
          // Local-only: keep local and mark for sync to remote
          reconciledProfiles.add(localP);
          profilesToSync.add(localP.id);
        }
      }

      // 3. Remote-only profiles: insert into local storage
      for (final dbP in dbProfiles) {
        final remoteId = dbP['id'].toString();
        if (matchedRemoteIds.contains(remoteId)) continue;

        final rName = dbP['profile_name']?.toString() ?? 'Free Read';
        // Double check we don't duplicate by name
        if (reconciledProfiles.any(
          (p) =>
              p.userId == userId && p.name.toLowerCase() == rName.toLowerCase(),
        )) {
          continue;
        }

        final remoteSurah = dbP['current_surah']?.toString() ?? '1';
        final remoteAyah = dbP['current_ayah']?.toString() ?? '1';
        final remoteLastReadAt =
            DateTime.tryParse(dbP['last_read_at']?.toString() ?? '') ??
            DateTime.now();

        final newLocalP = LocalReadingProfile(
          id: remoteId,
          userId: userId,
          name: rName,
          slug: _uniqueSlug(slugifyReadingProfileName(rName)),
          start: toVerseRef(1, 1),
          current: toVerseRef(remoteSurah, remoteAyah),
          sortOrder: reconciledProfiles.where((p) => p.userId == userId).length,
          isArchived: false,
          createdAt: remoteLastReadAt,
          updatedAt: remoteLastReadAt,
        );
        reconciledProfiles.add(newLocalP);
        localStateChanged = true;
        hasRemoteUpdates = true;
      }

      // Update local profiles list
      _profiles = reconciledProfiles;
      _ensureDefaultProfile();

      // Update active profile ID if needed
      final userProfiles = _profiles.where((p) => p.userId == userId).toList();
      final belongsToUser = userProfiles.any((p) => p.id == _activeProfileId);
      if (!belongsToUser || hasRemoteUpdates) {
        final latest = _getLatestReadProfile(userProfiles);
        if (latest != null && latest.id != _activeProfileId) {
          _activeProfileId = latest.id;
          localStateChanged = true;
        }
      }

      if (localStateChanged || profilesToSync.isNotEmpty) {
        await _save(immediate: true);
        notifyListeners();
      }

      // Sync local-newer and local-only profiles to Supabase
      for (final id in profilesToSync) {
        final p = _profiles.where((p) => p.id == id).firstOrNull;
        if (p != null) {
          await _syncProfileToSupabase(p);
        }
      }
    } catch (e) {
      debugPrint('Error in reconcileProfilesOnBoot: $e');
    }
  }

  Future<void> _syncProfileToSupabase(LocalReadingProfile p) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user != null && p.userId != 'local') {
      try {
        final uuidRegExp = RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        );
        final bool hasUuid = uuidRegExp.hasMatch(p.id);

        final upsertData = {
          'user_id': user.id,
          'profile_name': p.name,
          'current_surah': int.tryParse(p.current.surahId) ?? 1,
          'current_ayah': int.tryParse(p.current.verseId) ?? 1,
          'last_read_at': p.updatedAt.toIso8601String(),
        };

        if (hasUuid) {
          upsertData['id'] = p.id;
        }

        final response = hasUuid
            ? await client
                  .from('user_reading_profiles')
                  .upsert(upsertData, onConflict: 'id')
                  .select('id')
                  .single()
            : await client
                  .from('user_reading_profiles')
                  .insert(upsertData)
                  .select('id')
                  .single();

        final returnedId = response['id']?.toString();
        if (returnedId != null && returnedId != p.id) {
          // Update profile ID locally
          final index = _profiles.indexWhere((item) => item.id == p.id);
          if (index != -1) {
            final oldP = _profiles[index];
            final newP = LocalReadingProfile(
              id: returnedId,
              userId: oldP.userId,
              name: oldP.name,
              slug: oldP.slug,
              planMode: oldP.planMode,
              startJuz: oldP.startJuz,
              targetJuz: oldP.targetJuz,
              start: oldP.start,
              target: oldP.target,
              current: oldP.current,
              sortOrder: oldP.sortOrder,
              isArchived: oldP.isArchived,
              createdAt: oldP.createdAt,
              updatedAt: oldP.updatedAt,
            );
            _profiles[index] = newP;
            if (_activeProfileId == p.id) {
              _activeProfileId = returnedId;
            }
            await _save(immediate: true);
            notifyListeners();
          }
        }
      } catch (e) {
        debugPrint('Error syncing profile to Supabase: $e');
      }
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
    BuildContext? context,
  }) async {
    await _loadCompleter.future;
    if (!canCreateProfile) {
      throw StateError(
        'Only $maxActiveReadingProfiles active reading profiles are allowed.',
      );
    }

    final now = DateTime.now();
    final slug = _uniqueSlug(slugifyReadingProfileName(name));
    final profile = LocalReadingProfile(
      id: _createLocalId(),
      userId: currentUserId,
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

    try {
      final prefs = await SharedPreferences.getInstance();

      final updatedProfiles = [..._profiles, profile];
      final newActiveProfileId = profile.id;

      final dataString = json.encode({
        'activeProfileId': newActiveProfileId,
        'profiles': updatedProfiles.map((p) => p.toJson()).toList(),
        'categories': _categories.map((c) => c.toJson()).toList(),
        'bookmarks': _bookmarks.map((b) => b.toJson()).toList(),
        'recentReadings': _recentReadings.map((r) => r.toJson()).toList(),
      });

      final success = await prefs.setString(_storageKey, dataString);
      if (!success) {
        throw const StorageException(
          'Failed to write profiles to SharedPreferences.',
        );
      }

      // Succeeded: update in-memory state
      _profiles.add(profile);
      _activeProfileId = profile.id;
      notifyListeners();

      _syncProfileToSupabase(profile);
      return profile;
    } catch (e) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save to device storage.')),
        );
      }
      debugPrint(
        'local_reading_provider: StorageException in createProfile: $e',
      );
      throw const StorageException('Failed to save to device storage.');
    }
  }

  Future<void> updateProfile({
    required String profileId,
    required String name,
    required VerseRef start,
    VerseRef? target,
    String? planMode,
    int? startJuz,
    int? targetJuz,
  }) async {
    await _loadCompleter.future;
    final profile = _profiles.where((item) => item.id == profileId).firstOrNull;
    if (profile == null || isFreeReadProfile(profile)) return;

    final updated = profile.copyWith(
      name: name,
      planMode: planMode,
      startJuz: startJuz,
      targetJuz: targetJuz,
      start: start,
      target: target,
      clearTarget: target == null,
      current: start,
      updatedAt: DateTime.now(),
    );

    _profiles = _profiles
        .map((item) => item.id == profileId ? updated : item)
        .toList();
    await _save(immediate: true);
    notifyListeners();

    _syncProfileToSupabase(updated);
  }

  Future<void> deleteProfile(String profileId) async {
    await _loadCompleter.future;
    final profile = _profiles.where((item) => item.id == profileId).firstOrNull;
    if (profile == null || isFreeReadProfile(profile)) return;

    _profiles = _profiles.where((item) => item.id != profileId).toList();
    if (_activeProfileId == profileId) {
      final userProfiles = _profiles
          .where((p) => p.userId == currentUserId)
          .toList();
      final latest = _getLatestReadProfile(userProfiles);
      _activeProfileId = latest?.id ?? _profiles.firstOrNull?.id;
    }
    await _save(immediate: true);
    notifyListeners();

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && profile.userId != 'local') {
      try {
        final uuidRegExp = RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        );
        if (uuidRegExp.hasMatch(profile.id)) {
          await Supabase.instance.client
              .from('user_reading_profiles')
              .delete()
              .eq('id', profile.id);
        } else {
          await Supabase.instance.client
              .from('user_reading_profiles')
              .delete()
              .eq('user_id', user.id)
              .eq('profile_name', profile.name);
        }
      } catch (e) {
        debugPrint('Error deleting reading profile from Supabase: $e');
      }
    }
  }

  Future<void> setActiveProfile(String profileId) async {
    await _loadCompleter.future;
    if (!_profiles.any((profile) => profile.id == profileId)) return;
    _activeProfileId = profileId;
    await _save(immediate: true);
    notifyListeners();
  }

  Future<void> updateProfileProgress(
    String profileId,
    VerseRef current, {
    BuildContext? context,
  }) async {
    await _loadCompleter.future;
    final existingProfile = _profiles
        .where((profile) => profile.id == profileId)
        .firstOrNull;
    if (existingProfile == null ||
        !isVerseInsideProfile(
          existingProfile,
          current.surahId,
          current.verseId,
        )) {
      return;
    }

    final now = DateTime.now();

    // 1. Prepare updated profiles list (cloned in memory)
    final updatedProfiles = _profiles.map((profile) {
      if (profile.id == profileId) {
        return profile.copyWith(current: current, updatedAt: now);
      }
      return profile;
    }).toList();

    // 2. Enforce Disk-First Guarantee: Attempt to save to disk first
    try {
      final prefs = await SharedPreferences.getInstance();

      // Update reading state timestamp on disk
      final timestampSuccess = await prefs.setString(
        'user_reading_state_updated_at',
        now.toIso8601String(),
      );
      if (!timestampSuccess) {
        throw const StorageException(
          'Failed to write timestamp to SharedPreferences.',
        );
      }

      // Serialize and write profiles list to disk
      final dataString = json.encode({
        'activeProfileId': _activeProfileId,
        'profiles': updatedProfiles.map((p) => p.toJson()).toList(),
        'categories': _categories.map((c) => c.toJson()).toList(),
        'bookmarks': _bookmarks.map((b) => b.toJson()).toList(),
        'recentReadings': _recentReadings.map((r) => r.toJson()).toList(),
      });

      final success = await prefs.setString(_storageKey, dataString);
      if (!success) {
        throw const StorageException(
          'Failed to write profiles to SharedPreferences.',
        );
      }

      // 3. Disk write succeeded: update in-memory state and notify listeners
      _profiles = updatedProfiles;
      notifyListeners();

      // Sync to Supabase
      final updatedProfile = _profiles
          .where((item) => item.id == profileId)
          .firstOrNull;
      if (updatedProfile != null) {
        _syncProfileToSupabase(updatedProfile);
      }

      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final surahInt = int.tryParse(current.surahId) ?? 1;
        final verseInt = int.tryParse(current.verseId) ?? 1;
        _debounceReadingStateSync(user.id, surahInt, verseInt);
      }
    } catch (e) {
      // 4. Failed: emit SnackBar & throw exception (in-memory state was not mutated)
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save to device storage.')),
        );
      }
      debugPrint(
        'local_reading_provider: StorageException in updateProfileProgress: $e',
      );
      throw const StorageException('Failed to save to device storage.');
    }
  }

  Future<void> archiveProfile(String profileId) async {
    await _loadCompleter.future;
    final profile = _profiles.where((item) => item.id == profileId).firstOrNull;
    if (profile == null || isFreeReadProfile(profile)) return;

    final updated = profile.copyWith(
      isArchived: true,
      updatedAt: DateTime.now(),
    );
    _profiles = _profiles.map((p) => p.id == profileId ? updated : p).toList();

    if (_activeProfileId == profileId) {
      final userProfiles = _profiles
          .where((p) => p.userId == currentUserId)
          .toList();
      final latest = _getLatestReadProfile(userProfiles);
      _activeProfileId = latest?.id;
    }

    await _save(immediate: true);
    notifyListeners();

    _syncProfileToSupabase(updated);
  }

  Future<void> restoreProfile(String profileId) async {
    await _loadCompleter.future;
    if (!canCreateProfile) {
      throw StateError(
        'Only $maxActiveReadingProfiles active reading profiles are allowed.',
      );
    }

    final profile = _profiles.where((item) => item.id == profileId).firstOrNull;
    if (profile == null) return;

    final updated = profile.copyWith(
      isArchived: false,
      updatedAt: DateTime.now(),
    );
    _profiles = _profiles.map((p) => p.id == profileId ? updated : p).toList();
    await _save(immediate: true);
    notifyListeners();

    _syncProfileToSupabase(updated);
  }

  Future<LocalBookmarkCategory> ensureBookmarkCategory({
    String name = 'Saved Verses',
    int maxItems = defaultBookmarkCategoryMaxItems,
  }) async {
    await _loadCompleter.future;
    final slug = slugifyReadingProfileName(name);
    final curUserId = currentUserId;
    final existing = _categories
        .where(
          (category) => category.slug == slug && category.userId == curUserId,
        )
        .firstOrNull;
    if (existing != null) return existing;

    final category = LocalBookmarkCategory(
      id: _createLocalId(),
      userId: curUserId,
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
    final numericSurah = int.tryParse(surahId) ?? 0;
    final numericVerse = int.tryParse(verseId) ?? 0;
    final uid = currentUserId;
    return _bookmarks.any((b) {
      final bSurah = int.tryParse(b.verse.surahId) ?? 0;
      final bVerse = int.tryParse(b.verse.verseId) ?? 0;
      return bSurah == numericSurah &&
          bVerse == numericVerse &&
          b.userId == uid;
    });
  }

  Future<void> toggleBookmark(String surahId, String verseId) async {
    final numericSurah = int.tryParse(surahId) ?? 0;
    final numericVerse = int.tryParse(verseId) ?? 0;
    final uid = currentUserId;
    final existing = _bookmarks.where((b) {
      final bSurah = int.tryParse(b.verse.surahId) ?? 0;
      final bVerse = int.tryParse(b.verse.verseId) ?? 0;
      // Only consider bookmarks belonging to the current user
      return bSurah == numericSurah &&
          bVerse == numericVerse &&
          b.userId == uid;
    }).firstOrNull;

    if (existing != null) {
      await removeBookmark(existing.id);
    } else {
      // Let StateError (e.g. bookmark limit) propagate so callers can show feedback
      await addBookmark(verse: toVerseRef(surahId, verseId));
    }
  }

  Future<LocalBookmark> addBookmark({
    required VerseRef verse,
    String? categoryId,
    String? label,
    String? note,
  }) async {
    await _loadCompleter.future;
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

    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user != null) {
      try {
        final inserted = await client
            .from('bookmarks')
            .insert({
              'user_id': user.id,
              'category_id': category.id,
              'surah_id': verse.surahId,
              'verse_id': verse.verseId,
              if (label != null) 'label': label,
              if (note != null) 'note': note,
              'sort_order': categoryBookmarks.length,
            })
            .select('id')
            .single();

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
    await _loadCompleter.future;
    final bookmark = _bookmarks
        .where((bookmark) => bookmark.id == bookmarkId)
        .firstOrNull;
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

  void _debounceRecentReadingSync(
    String userId,
    String surahId,
    String verseId,
  ) {
    _pendingSyncUserId = userId;
    _pendingSyncSurahId = surahId;
    _pendingSyncVerseId = verseId;

    _recentReadingSyncTimer?.cancel();
    _recentReadingSyncTimer = Timer(const Duration(seconds: 2), () async {
      final uId = _pendingSyncUserId;
      final sId = _pendingSyncSurahId;
      final vId = _pendingSyncVerseId;
      if (uId == null || sId == null || vId == null) return;

      try {
        final client = Supabase.instance.client;
        await client.from('recent_readings').upsert({
          'user_id': uId,
          'surah_id': sId,
          'last_read_verse': vId,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id,surah_id');
      } catch (e) {
        debugPrint('Error syncing recent reading to Supabase: $e');
      }
    });
  }

  Future<void> addRecentReading({
    required VerseRef verse,
    String? profileId,
    int limit = defaultRecentReadingsLimit,
  }) async {
    await _loadCompleter.future;
    final client = Supabase.instance.client;
    final currentUser = client.auth.currentUser;
    final String currentUserId = currentUser?.id ?? _localUserId;
    final taggedProfile = profileId == null
        ? null
        : _profiles.where((profile) => profile.id == profileId).firstOrNull;
    final safeProfileId =
        taggedProfile != null &&
            isVerseInsideProfile(taggedProfile, verse.surahId, verse.verseId)
        ? profileId
        : null;

    // Local update: find if there is an existing entry for this user_id and surah_id
    final existingIndex = _recentReadings.indexWhere(
      (item) =>
          item.userId == currentUserId && item.verse.surahId == verse.surahId,
    );

    final updatedReading = LocalRecentReading(
      id: existingIndex != -1
          ? _recentReadings[existingIndex].id
          : _createLocalId(),
      userId: currentUserId,
      verse: verse,
      profileId: safeProfileId,
      readAt: DateTime.now(),
    );

    if (existingIndex != -1) {
      _recentReadings.removeAt(existingIndex);
    }
    _recentReadings.insert(0, updatedReading);

    if (_recentReadings.length > limit) {
      _recentReadings = _recentReadings.take(limit).toList();
    }

    await _save();
    notifyListeners();

    if (currentUser != null) {
      _debounceRecentReadingSync(currentUser.id, verse.surahId, verse.verseId);
    }
  }

  void _debounceReadingStateSync(String userId, int surahId, int verseId) {
    _pendingReadingStateUserId = userId;
    _pendingReadingStateSurahId = surahId;
    _pendingReadingStateVerseId = verseId;

    _readingStateSyncTimer?.cancel();
    _readingStateSyncTimer = Timer(const Duration(seconds: 2), () async {
      final uId = _pendingReadingStateUserId;
      final sId = _pendingReadingStateSurahId;
      final vId = _pendingReadingStateVerseId;
      if (uId == null || sId == null || vId == null) return;

      try {
        final client = Supabase.instance.client;
        await client.from('user_reading_state').upsert({
          'user_id': uId,
          'surah_id': sId,
          'verse_id': vId,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id');
      } catch (e) {
        debugPrint('Error syncing reading state to Supabase: $e');
      }
    });
  }

  Future<void> syncReadingStateWithSupabase(String userId) async {
    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('user_reading_state')
          .select('surah_id, verse_id, updated_at')
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        final int remoteSurahId = int.parse(response['surah_id'].toString());
        final int remoteVerseId = int.parse(response['verse_id'].toString());
        final DateTime remoteUpdatedAt = DateTime.parse(
          response['updated_at'].toString(),
        );

        final prefs = await SharedPreferences.getInstance();
        final localUpdatedAtStr = prefs.getString(
          'user_reading_state_updated_at',
        );
        final localUpdatedAt = localUpdatedAtStr != null
            ? DateTime.tryParse(localUpdatedAtStr) ??
                  DateTime.fromMillisecondsSinceEpoch(0)
            : DateTime.fromMillisecondsSinceEpoch(0);

        if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
          final remoteVerseRef = toVerseRef(
            remoteSurahId.toString(),
            remoteVerseId.toString(),
          );

          final targetProfile =
              _profiles.where(isFreeReadProfile).firstOrNull ??
              _profiles.firstOrNull;
          if (targetProfile != null) {
            final active = activeProfile;
            final remoteIsInsideActive =
                active != null &&
                isVerseInsideProfile(
                  active,
                  remoteVerseRef.surahId,
                  remoteVerseRef.verseId,
                );
            final targetProfileId = remoteIsInsideActive
                ? active.id
                : targetProfile.id;
            _profiles = _profiles.map((p) {
              if (p.id == targetProfileId) {
                return p.copyWith(
                  current: remoteVerseRef,
                  updatedAt: remoteUpdatedAt,
                );
              }
              return p;
            }).toList();
            if (!remoteIsInsideActive) {
              _activeProfileId = targetProfileId;
            }
          }

          await prefs.setString(
            'user_reading_state_updated_at',
            remoteUpdatedAt.toIso8601String(),
          );
          await _save(immediate: true);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error syncing reading state with Supabase: $e');
    }
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
      var loadedProfiles = _decodeList(
        decoded['profiles'],
        LocalReadingProfile.fromJson,
      );

      // Deduplicate "Free Read" profiles (keep the oldest/first one)
      final freeReads = loadedProfiles
          .where((p) => p.name == 'Free Read')
          .toList();
      if (freeReads.length > 1) {
        freeReads.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        final toKeep = freeReads.first;
        loadedProfiles = loadedProfiles
            .where((p) => p.name != 'Free Read' || p.id == toKeep.id)
            .toList();
      }
      _profiles = loadedProfiles;
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
      _profiles = _profiles
          .map(
            (profile) =>
                profile.target != null &&
                    !isFreeReadProfile(profile) &&
                    !isVerseInsideProfile(
                      profile,
                      profile.current.surahId,
                      profile.current.verseId,
                    )
                ? profile.copyWith(current: profile.start)
                : profile,
          )
          .toList();
      if (activeProfile == null) {
        final userProfiles = _profiles
            .where((p) => p.userId == currentUserId)
            .toList();
        final latest = _getLatestReadProfile(userProfiles);
        _activeProfileId = latest?.id;
      }
      await _migrateLegacyBookmarks();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading local reading store: $e');
      _ensureDefaultProfile();
      notifyListeners();
    } finally {
      if (!_loadCompleter.isCompleted) {
        _loadCompleter.complete();
      }
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
    if (_profiles.any(
      (p) => isFreeReadProfile(p) && p.userId == currentUserId,
    )) {
      return;
    }

    final now = DateTime.now();
    final profile = LocalReadingProfile(
      id: _createLocalId(),
      userId: currentUserId,
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
