import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/quran_foundation_repository.dart';
import '../models/mushaf_models.dart';

class MushafReadingProvider extends ChangeNotifier {
  List<MushafProfile> _profiles = [];
  List<MushafPageBookmark> _pageBookmarks = [];
  List<MushafVerseBookmark> _verseBookmarks = [];
  List<MushafRecentReading> _recentReadings = [];
  String? _activeProfileId;
  int _displayMushafId = 2;
  bool _isLoaded = false;

  StreamSubscription<AuthState>? _authSubscription;
  Timer? _recentReadingSyncTimer;
  String? _pendingRecentUserId;
  int? _pendingRecentMushafId;
  int? _pendingRecentPageNumber;
  String? _pendingRecentProfileId;

  MushafReadingProvider() {
    load();
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) async {
      final user = data.session?.user;
      if (user != null) {
        await syncWithSupabase(user.id);
      }
    });
  }

  bool get isLoaded => _isLoaded;
  List<MushafProfile> get profiles => List.unmodifiable(_profiles);
  List<MushafProfile> get activeCustomProfiles =>
      _profiles
          .where((profile) => !profile.isFreeRead && !profile.isArchived)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  List<MushafPageBookmark> get pageBookmarks =>
      List.unmodifiable(_pageBookmarks);
  List<MushafVerseBookmark> get verseBookmarks =>
      List.unmodifiable(_verseBookmarks);
  List<MushafRecentReading> get recentReadings =>
      List.unmodifiable(_recentReadings);
  MushafProfile? get activeProfile => profileById(_activeProfileId);
  int get displayMushafId => _displayMushafId;
  bool get canCreateProfile =>
      activeCustomProfiles.length < maxActiveMushafProfiles;

  MushafProfile? profileById(String? id) {
    if (id == null) return null;
    for (final profile in _profiles) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  MushafProfile freeReadProfileForMushaf(int mushafId) {
    final existing = _profiles.where((profile) {
      return profile.isFreeRead && profile.mushafId == mushafId;
    }).firstOrNull;
    if (existing != null) {
      if (existing.name != 'Just Read') {
        final index = _profiles.indexWhere(
          (profile) => profile.id == existing.id,
        );
        if (index != -1) {
          final updated = existing.copyWith(
            name: 'Just Read',
            updatedAt: DateTime.now(),
          );
          _profiles[index] = updated;
          _save();
          return updated;
        }
      }
      return existing;
    }

    final now = DateTime.now();
    final type = mushafTypeById(mushafId);
    final profile = MushafProfile(
      id: 'mushaf-free-$mushafId',
      userId: 'local',
      name: 'Just Read',
      slug: mushafFreeReadSlug,
      mushafId: mushafId,
      planMode: 'free_read',
      startPage: 1,
      targetPage: type.pageCount,
      currentPage: 1,
      sortOrder: -1,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    );
    _profiles.add(profile);
    _save();
    return profile;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(mushafStoreKey);
    if (raw == null || raw.isEmpty) {
      _ensureDefaultProfile();
      _isLoaded = true;
      await _save();
      notifyListeners();
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _profiles = _decodeList(decoded['profiles'], MushafProfile.fromJson);
        _pageBookmarks = _decodeList(
          decoded['pageBookmarks'],
          MushafPageBookmark.fromJson,
        );
        _verseBookmarks = _decodeList(
          decoded['verseBookmarks'],
          MushafVerseBookmark.fromJson,
        );
        _recentReadings = _decodeList(
          decoded['recentReadings'],
          MushafRecentReading.fromJson,
        );
        _activeProfileId = decoded['activeProfileId']?.toString();
        final displayMushafId =
            int.tryParse(decoded['displayMushafId']?.toString() ?? '') ?? 2;
        _displayMushafId = visibleMushafTypeIds.contains(displayMushafId)
            ? displayMushafId
            : 2;
      }
    } catch (_) {
      _profiles = [];
      _pageBookmarks = [];
      _verseBookmarks = [];
      _recentReadings = [];
      _activeProfileId = null;
    }

    _ensureDefaultProfile();
    _normalizeFreeReadProfiles();
    if (activeProfile == null) {
      _activeProfileId = _profiles.first.id;
    }
    _isLoaded = true;
    await _save();
    notifyListeners();
  }

  Future<MushafProfile> openFreeRead(int mushafId) async {
    final profile = freeReadProfileForMushaf(mushafId);
    _activeProfileId = profile.id;
    await _save();
    notifyListeners();
    return profile;
  }

  Future<MushafProfile> openUnifiedFreeRead() async {
    return openFreeRead(1);
  }

  void _normalizeFreeReadProfiles() {
    var changed = false;
    _profiles = _profiles.map((profile) {
      if (!profile.isFreeRead || profile.name == 'Just Read') {
        return profile;
      }
      changed = true;
      return profile.copyWith(name: 'Just Read');
    }).toList();
    if (changed) {
      _save();
    }
  }

  Future<void> setDisplayMushafId(int mushafId) async {
    if (!visibleMushafTypeIds.contains(mushafId)) return;
    _displayMushafId = mushafId;
    await _save();
    notifyListeners();
  }

  Future<void> setActiveProfile(String profileId) async {
    if (profileById(profileId) == null) return;
    _activeProfileId = profileId;
    await _save();
    notifyListeners();
  }

  Future<void> updateProgress({
    required String profileId,
    required int pageNumber,
  }) async {
    final index = _profiles.indexWhere((profile) => profile.id == profileId);
    if (index == -1) return;
    final profile = _profiles[index];
    final page = _clampInt(pageNumber, profile.startPage, profile.targetPage);
    final updated = profile.copyWith(
      currentPage: page,
      updatedAt: DateTime.now(),
    );
    _profiles[index] = updated;
    _upsertRecentReading(updated);
    await _save();
    notifyListeners();
    _syncProfileToSupabase(updated);
  }

  Future<void> updateProfile(
    String profileId, {
    required String name,
  }) async {
    final index = _profiles.indexWhere((profile) => profile.id == profileId);
    if (index == -1) return;
    final profile = _profiles[index];
    final updated = profile.copyWith(
      name: name,
      updatedAt: DateTime.now(),
    );
    _profiles[index] = updated;
    await _save();
    notifyListeners();
    _syncProfileToSupabase(updated);
  }

  Future<void> createPageRangeProfile({
    required String name,
    required int mushafId,
    required int startPage,
    required int targetPage,
    required String planMode,
  }) async {
    if (!canCreateProfile) {
      throw const QuranFoundationException(
        'Only 3 active Mushaf profiles are allowed.',
      );
    }
    final pageCount = mushafTypeById(mushafId).pageCount;
    final start = _clampInt(startPage, 1, pageCount);
    final target = _clampInt(targetPage, start, pageCount);
    final now = DateTime.now();
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'local';
    final profile = MushafProfile(
      id: 'mushaf-profile-${now.microsecondsSinceEpoch}',
      userId: userId,
      name: name,
      slug: _slugify(name),
      mushafId: mushafId,
      planMode: planMode,
      startPage: start,
      targetPage: target,
      currentPage: start,
      sortOrder: activeCustomProfiles.length,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    );
    _profiles.add(profile);
    _activeProfileId = profile.id;
    await _save();
    notifyListeners();
    _syncProfileToSupabase(profile);
  }

  Future<void> createSurahProfile({
    required String name,
    required int mushafId,
    required int surahNumber,
    required QuranFoundationRepository repository,
  }) async {
    final pageCount = mushafTypeById(mushafId).pageCount;
    await createPageRangeProfile(
      name: name,
      mushafId: mushafId,
      startPage: _madaniStartPageForSurah(surahNumber),
      targetPage: _madaniEndPageForSurah(surahNumber, pageCount),
      planMode: 'by_surah',
    );
  }

  Future<void> createJuzProfile({
    required String name,
    required int mushafId,
    required int juzNumber,
    required QuranFoundationRepository repository,
  }) async {
    final pageCount = mushafTypeById(mushafId).pageCount;
    await createPageRangeProfile(
      name: name,
      mushafId: mushafId,
      startPage: _madaniStartPageForJuz(juzNumber),
      targetPage: _madaniEndPageForJuz(juzNumber, pageCount),
      planMode: 'by_juz',
    );
  }

  Future<void> archiveProfile(String profileId) async {
    final index = _profiles.indexWhere((profile) => profile.id == profileId);
    if (index == -1 || _profiles[index].isFreeRead) return;
    final updated = _profiles[index].copyWith(
      isArchived: true,
      updatedAt: DateTime.now(),
    );
    _profiles[index] = updated;
    if (_activeProfileId == profileId) {
      _activeProfileId = freeReadProfileForMushaf(_profiles[index].mushafId).id;
    }
    await _save();
    notifyListeners();
    _syncProfileToSupabase(updated);
  }

  bool isPageBookmarked(int mushafId, int pageNumber) {
    return _pageBookmarks.any(
      (bookmark) =>
          bookmark.mushafId == mushafId && bookmark.pageNumber == pageNumber,
    );
  }

  Future<void> togglePageBookmark(int mushafId, int pageNumber) async {
    final index = _pageBookmarks.indexWhere(
      (bookmark) =>
          bookmark.mushafId == mushafId && bookmark.pageNumber == pageNumber,
    );
    if (index >= 0) {
      _pageBookmarks.removeAt(index);
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        try {
          await Supabase.instance.client
              .from('mushaf_page_bookmarks')
              .delete()
              .eq('user_id', user.id)
              .eq('mushaf_id', mushafId)
              .eq('page_number', pageNumber);
        } catch (e) {
          debugPrint('Error deleting page bookmark from Supabase: $e');
        }
      }
    } else {
      final bookmark = MushafPageBookmark(
        id: 'mushaf-page-bookmark-$mushafId-$pageNumber',
        mushafId: mushafId,
        pageNumber: pageNumber,
        createdAt: DateTime.now(),
      );
      _pageBookmarks.add(bookmark);
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        try {
          await Supabase.instance.client.from('mushaf_page_bookmarks').upsert({
            'user_id': user.id,
            'mushaf_id': mushafId,
            'page_number': pageNumber,
            'created_at': bookmark.createdAt.toIso8601String(),
          }, onConflict: 'user_id,mushaf_id,page_number');
        } catch (e) {
          debugPrint('Error saving page bookmark to Supabase: $e');
        }
      }
    }
    await _save();
    notifyListeners();
  }

  bool isVerseBookmarked(int mushafId, int pageNumber, String verseKey) {
    return _verseBookmarks.any(
      (bookmark) =>
          bookmark.mushafId == mushafId &&
          bookmark.pageNumber == pageNumber &&
          bookmark.verseKey == verseKey,
    );
  }

  Future<void> toggleVerseBookmark({
    required int mushafId,
    required int pageNumber,
    required String verseKey,
  }) async {
    final index = _verseBookmarks.indexWhere(
      (bookmark) =>
          bookmark.mushafId == mushafId &&
          bookmark.pageNumber == pageNumber &&
          bookmark.verseKey == verseKey,
    );
    if (index >= 0) {
      _verseBookmarks.removeAt(index);
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        try {
          await Supabase.instance.client
              .from('mushaf_verse_bookmarks')
              .delete()
              .eq('user_id', user.id)
              .eq('mushaf_id', mushafId)
              .eq('page_number', pageNumber)
              .eq('verse_key', verseKey);
        } catch (e) {
          debugPrint('Error deleting verse bookmark from Supabase: $e');
        }
      }
    } else {
      final bookmark = MushafVerseBookmark(
        id: 'mushaf-verse-bookmark-$mushafId-$pageNumber-$verseKey',
        mushafId: mushafId,
        pageNumber: pageNumber,
        verseKey: verseKey,
        createdAt: DateTime.now(),
      );
      _verseBookmarks.add(bookmark);
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        try {
          await Supabase.instance.client.from('mushaf_verse_bookmarks').upsert({
            'user_id': user.id,
            'mushaf_id': mushafId,
            'page_number': pageNumber,
            'verse_key': verseKey,
            'created_at': bookmark.createdAt.toIso8601String(),
          }, onConflict: 'user_id,mushaf_id,page_number,verse_key');
        } catch (e) {
          debugPrint('Error saving verse bookmark to Supabase: $e');
        }
      }
    }
    await _save();
    notifyListeners();
  }

  void _ensureDefaultProfile() {
    freeReadProfileForMushaf(1);
    _activeProfileId ??= 'mushaf-free-1';
  }

  void _upsertRecentReading(MushafProfile profile) {
    _recentReadings.removeWhere(
      (reading) =>
          reading.mushafId == profile.mushafId &&
          reading.profileId == profile.id,
    );
    final recent = MushafRecentReading(
      mushafId: profile.mushafId,
      pageNumber: profile.currentPage,
      profileId: profile.id,
      updatedAt: DateTime.now(),
    );
    _recentReadings.insert(0, recent);
    if (_recentReadings.length > 20) {
      _recentReadings = _recentReadings.take(20).toList();
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      _debounceRecentReadingSync(
        user.id,
        profile.mushafId,
        profile.currentPage,
        profile.id,
      );
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      mushafStoreKey,
      jsonEncode({
        'activeProfileId': _activeProfileId,
        'displayMushafId': _displayMushafId,
        'profiles': _profiles.map((profile) => profile.toJson()).toList(),
        'pageBookmarks': _pageBookmarks
            .map((bookmark) => bookmark.toJson())
            .toList(),
        'verseBookmarks': _verseBookmarks
            .map((bookmark) => bookmark.toJson())
            .toList(),
        'recentReadings': _recentReadings
            .map((reading) => reading.toJson())
            .toList(),
      }),
    );
  }

  List<T> _decodeList<T>(
    dynamic raw,
    T Function(Map<String, dynamic>) decoder,
  ) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((item) => decoder(Map<String, dynamic>.from(item)))
        .toList();
  }

  String _slugify(String value) {
    final slug = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9ก-๙]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    if (slug.isEmpty) return 'mushaf_profile';
    return slug;
  }

  Future<void> syncWithSupabase(String userId) async {
    final client = Supabase.instance.client;
    try {
      // 1. Sync Profiles
      final remoteProfilesRes = await client
          .from('mushaf_profiles')
          .select('*')
          .eq('user_id', userId);
      final List<dynamic> dbProfiles = remoteProfilesRes;

      final Set<String> matchedRemoteIds = {};
      final List<MushafProfile> reconciledProfiles = [];

      for (final localP in _profiles) {
        if (localP.userId != userId && localP.userId != 'local') {
          reconciledProfiles.add(localP);
          continue;
        }

        final dbP = dbProfiles.firstWhere(
          (item) =>
              item['id'] == localP.id ||
              (item['slug'] == localP.slug &&
                  item['mushaf_id'] == localP.mushafId),
          orElse: () => null,
        );

        if (dbP != null) {
          final remoteId = dbP['id'].toString();
          matchedRemoteIds.add(remoteId);

          final remoteUpdatedAt =
              DateTime.tryParse(dbP['updated_at']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          if (localP.updatedAt.isAfter(remoteUpdatedAt)) {
            final syncedLocal = localP.copyWith(id: remoteId, userId: userId);
            reconciledProfiles.add(syncedLocal);
            await _syncProfileToSupabase(syncedLocal);
          } else {
            reconciledProfiles.add(
              MushafProfile(
                id: remoteId,
                userId: userId,
                name: dbP['name'],
                slug: dbP['slug'],
                mushafId: dbP['mushaf_id'],
                planMode: dbP['plan_mode'],
                startPage: dbP['start_page'],
                targetPage: dbP['target_page'],
                currentPage: dbP['current_page'],
                sortOrder: dbP['sort_order'],
                isArchived: dbP['is_archived'] ?? false,
                createdAt:
                    DateTime.tryParse(dbP['created_at']?.toString() ?? '') ??
                    DateTime.now(),
                updatedAt: remoteUpdatedAt,
              ),
            );
          }
        } else {
          final syncedLocal = localP.copyWith(userId: userId);
          final returnedId = await _syncProfileToSupabase(syncedLocal);
          reconciledProfiles.add(
            syncedLocal.copyWith(id: returnedId ?? syncedLocal.id),
          );
        }
      }

      for (final dbP in dbProfiles) {
        final remoteId = dbP['id'].toString();
        if (matchedRemoteIds.contains(remoteId)) continue;

        reconciledProfiles.add(
          MushafProfile(
            id: remoteId,
            userId: userId,
            name: dbP['name'],
            slug: dbP['slug'],
            mushafId: dbP['mushaf_id'],
            planMode: dbP['plan_mode'],
            startPage: dbP['start_page'],
            targetPage: dbP['target_page'],
            currentPage: dbP['current_page'],
            sortOrder: dbP['sort_order'],
            isArchived: dbP['is_archived'] ?? false,
            createdAt:
                DateTime.tryParse(dbP['created_at']?.toString() ?? '') ??
                DateTime.now(),
            updatedAt:
                DateTime.tryParse(dbP['updated_at']?.toString() ?? '') ??
                DateTime.now(),
          ),
        );
      }

      _profiles = reconciledProfiles;

      // 2. Sync Page Bookmarks
      final remotePageBookRes = await client
          .from('mushaf_page_bookmarks')
          .select('*')
          .eq('user_id', userId);
      final List<dynamic> dbPageBook = remotePageBookRes;
      final List<MushafPageBookmark> reconciledPageBook = [];
      final Set<String> matchedPageBookKeys = {};

      for (final localB in _pageBookmarks) {
        final dbB = dbPageBook.firstWhere(
          (item) =>
              item['mushaf_id'] == localB.mushafId &&
              item['page_number'] == localB.pageNumber,
          orElse: () => null,
        );
        if (dbB != null) {
          matchedPageBookKeys.add('${localB.mushafId}-${localB.pageNumber}');
        } else {
          await client.from('mushaf_page_bookmarks').upsert({
            'user_id': userId,
            'mushaf_id': localB.mushafId,
            'page_number': localB.pageNumber,
            'created_at': localB.createdAt.toIso8601String(),
          }, onConflict: 'user_id,mushaf_id,page_number');
        }
        reconciledPageBook.add(localB);
      }

      for (final dbB in dbPageBook) {
        final key = '${dbB['mushaf_id']}-${dbB['page_number']}';
        if (matchedPageBookKeys.contains(key)) continue;
        reconciledPageBook.add(
          MushafPageBookmark(
            id: dbB['id'].toString(),
            mushafId: dbB['mushaf_id'],
            pageNumber: dbB['page_number'],
            createdAt:
                DateTime.tryParse(dbB['created_at']?.toString() ?? '') ??
                DateTime.now(),
          ),
        );
      }
      _pageBookmarks = reconciledPageBook;

      // 3. Sync Verse Bookmarks
      final remoteVerseBookRes = await client
          .from('mushaf_verse_bookmarks')
          .select('*')
          .eq('user_id', userId);
      final List<dynamic> dbVerseBook = remoteVerseBookRes;
      final List<MushafVerseBookmark> reconciledVerseBook = [];
      final Set<String> matchedVerseBookKeys = {};

      for (final localB in _verseBookmarks) {
        final dbB = dbVerseBook.firstWhere(
          (item) =>
              item['mushaf_id'] == localB.mushafId &&
              item['page_number'] == localB.pageNumber &&
              item['verse_key'] == localB.verseKey,
          orElse: () => null,
        );
        if (dbB != null) {
          matchedVerseBookKeys.add(
            '${localB.mushafId}-${localB.pageNumber}-${localB.verseKey}',
          );
        } else {
          await client.from('mushaf_verse_bookmarks').upsert({
            'user_id': userId,
            'mushaf_id': localB.mushafId,
            'page_number': localB.pageNumber,
            'verse_key': localB.verseKey,
            'created_at': localB.createdAt.toIso8601String(),
          }, onConflict: 'user_id,mushaf_id,page_number,verse_key');
        }
        reconciledVerseBook.add(localB);
      }

      for (final dbB in dbVerseBook) {
        final key =
            '${dbB['mushaf_id']}-${dbB['page_number']}-${dbB['verse_key']}';
        if (matchedVerseBookKeys.contains(key)) continue;
        reconciledVerseBook.add(
          MushafVerseBookmark(
            id: dbB['id'].toString(),
            mushafId: dbB['mushaf_id'],
            pageNumber: dbB['page_number'],
            verseKey: dbB['verse_key'],
            createdAt:
                DateTime.tryParse(dbB['created_at']?.toString() ?? '') ??
                DateTime.now(),
          ),
        );
      }
      _verseBookmarks = reconciledVerseBook;

      // 4. Sync Recent Readings
      final remoteRecentRes = await client
          .from('mushaf_recent_readings')
          .select('*')
          .eq('user_id', userId)
          .order('updated_at', ascending: false)
          .limit(20);
      final List<dynamic> dbRecent = remoteRecentRes;
      final List<MushafRecentReading> reconciledRecent = [];
      final Set<String> matchedRecentKeys = {};

      for (final localR in _recentReadings) {
        final dbR = dbRecent.firstWhere(
          (item) =>
              item['mushaf_id'] == localR.mushafId &&
              item['profile_id'] == localR.profileId,
          orElse: () => null,
        );
        
        if (dbR != null) {
          matchedRecentKeys.add('${localR.mushafId}-${localR.profileId}');
          final remoteDate = DateTime.tryParse(dbR['updated_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          
          if (localR.updatedAt.isAfter(remoteDate)) {
            // Local is newer, keep it and push it
            reconciledRecent.add(localR);
            _debounceRecentReadingSync(userId, localR.mushafId, localR.pageNumber, localR.profileId);
          } else {
            // Remote is newer, keep it
            reconciledRecent.add(
              MushafRecentReading(
                mushafId: dbR['mushaf_id'],
                pageNumber: dbR['page_number'],
                profileId: dbR['profile_id']?.toString(),
                updatedAt: remoteDate,
              )
            );
          }
        } else {
          // Local only, keep it and push it
          reconciledRecent.add(localR);
          _debounceRecentReadingSync(userId, localR.mushafId, localR.pageNumber, localR.profileId);
        }
      }

      for (final dbR in dbRecent) {
        final key = '${dbR['mushaf_id']}-${dbR['profile_id']}';
        if (matchedRecentKeys.contains(key)) continue;
        reconciledRecent.add(
          MushafRecentReading(
            mushafId: dbR['mushaf_id'],
            pageNumber: dbR['page_number'],
            profileId: dbR['profile_id']?.toString(),
            updatedAt:
                DateTime.tryParse(dbR['updated_at']?.toString() ?? '') ??
                DateTime.now(),
          ),
        );
      }
      _recentReadings = reconciledRecent;

      await _save();
      notifyListeners();
    } catch (e) {
      debugPrint('Error syncing Mushaf with Supabase: $e');
    }
  }

  Future<String?> _syncProfileToSupabase(MushafProfile p) async {
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
          'name': p.name,
          'slug': p.slug,
          'mushaf_id': p.mushafId,
          'plan_mode': p.planMode,
          'start_page': p.startPage,
          'target_page': p.targetPage,
          'current_page': p.currentPage,
          'sort_order': p.sortOrder,
          'is_archived': p.isArchived,
          'updated_at': p.updatedAt.toIso8601String(),
        };

        if (hasUuid) {
          upsertData['id'] = p.id;
          await client
              .from('mushaf_profiles')
              .upsert(upsertData, onConflict: 'id');
          return p.id;
        } else {
          final response = await client
              .from('mushaf_profiles')
              .insert(upsertData)
              .select('id')
              .single();
          final returnedId = response['id']?.toString();
          if (returnedId != null) {
            final index = _profiles.indexWhere((item) => item.id == p.id);
            if (index != -1) {
              _profiles[index] = _profiles[index].copyWith(id: returnedId);
              if (_activeProfileId == p.id) {
                _activeProfileId = returnedId;
              }
              await _save();
            }
            return returnedId;
          }
        }
      } catch (e) {
        debugPrint('Error syncing Mushaf profile to Supabase: $e');
      }
    }
    return null;
  }

  void _debounceRecentReadingSync(
    String userId,
    int mushafId,
    int pageNumber,
    String? profileId,
  ) {
    _pendingRecentUserId = userId;
    _pendingRecentMushafId = mushafId;
    _pendingRecentPageNumber = pageNumber;
    _pendingRecentProfileId = profileId;

    _recentReadingSyncTimer?.cancel();
    _recentReadingSyncTimer = Timer(const Duration(seconds: 2), () async {
      final uId = _pendingRecentUserId;
      final mId = _pendingRecentMushafId;
      final pNum = _pendingRecentPageNumber;
      final profId = _pendingRecentProfileId;
      if (uId == null || mId == null || pNum == null) return;

      try {
        final uuidRegExp = RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        );
        if (profId == null || !uuidRegExp.hasMatch(profId)) {
          // Omit syncing recent readings for unsynced profiles (e.g. Free/Just Read when offline/not reconciled yet)
          return;
        }

        final client = Supabase.instance.client;
        await client.from('mushaf_recent_readings').upsert({
          'user_id': uId,
          'mushaf_id': mId,
          'page_number': pNum,
          'profile_id': profId,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id,mushaf_id,profile_id');
      } catch (e) {
        debugPrint('Error syncing Mushaf recent reading to Supabase: $e');
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _recentReadingSyncTimer?.cancel();
    super.dispose();
  }
}

int _clampInt(int value, int min, int max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

int _madaniStartPageForSurah(int surahNumber) {
  const List<int> surahStartPages = [
    1,
    2,
    50,
    77,
    106,
    128,
    151,
    177,
    187,
    208,
    221,
    235,
    249,
    255,
    262,
    267,
    282,
    293,
    305,
    312,
    322,
    332,
    342,
    350,
    359,
    367,
    377,
    385,
    396,
    404,
    411,
    415,
    418,
    428,
    434,
    440,
    446,
    453,
    458,
    467,
    477,
    483,
    489,
    496,
    499,
    502,
    507,
    511,
    515,
    518,
    520,
    523,
    526,
    528,
    531,
    534,
    537,
    542,
    545,
    549,
    551,
    553,
    554,
    556,
    558,
    560,
    562,
    564,
    566,
    568,
    570,
    572,
    574,
    575,
    577,
    578,
    580,
    582,
    583,
    585,
    586,
    587,
    587,
    589,
    590,
    591,
    591,
    592,
    593,
    594,
    595,
    595,
    596,
    596,
    597,
    597,
    598,
    598,
    599,
    599,
    600,
    600,
    601,
    601,
    601,
    602,
    602,
    602,
    603,
    603,
    603,
    604,
    604,
    604,
  ];
  if (surahNumber < 1 || surahNumber > 114) return 1;
  return surahStartPages[surahNumber - 1];
}

int _madaniEndPageForSurah(int surahNumber, int pageCount) {
  if (surahNumber >= 114) return pageCount;
  return _clampInt(_madaniStartPageForSurah(surahNumber + 1) - 1, 1, pageCount);
}

int _madaniStartPageForJuz(int juzNumber) {
  const juzStartPages = [
    1,
    22,
    42,
    62,
    82,
    102,
    121,
    142,
    162,
    182,
    201,
    222,
    242,
    262,
    282,
    302,
    322,
    342,
    362,
    382,
    402,
    422,
    442,
    462,
    482,
    502,
    522,
    542,
    562,
    582,
  ];
  if (juzNumber < 1 || juzNumber > 30) return 1;
  return juzStartPages[juzNumber - 1];
}

int _madaniEndPageForJuz(int juzNumber, int pageCount) {
  if (juzNumber >= 30) return pageCount;
  return _clampInt(_madaniStartPageForJuz(juzNumber + 1) - 1, 1, pageCount);
}
