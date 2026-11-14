import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/medina_mushaf_pages.dart';
import '../data/quran_foundation_repository.dart';
import '../models/mushaf_models.dart';
import '../services/guest_lifecycle_service.dart';
import '../shared/quran_contract.dart';

class MushafReadingProvider extends ChangeNotifier with WidgetsBindingObserver {
  List<MushafProfile> _profiles = [];
  List<MushafPageBookmark> _pageBookmarks = [];
  List<MushafVerseBookmark> _verseBookmarks = [];
  List<MushafRecentReading> _recentReadings = [];
  final Set<String> _deletedPageBookmarkKeys = {};
  final Set<String> _deletedVerseBookmarkKeys = {};
  String? _activeProfileId;
  int _displayMushafId = 2;
  bool _isLoaded = false;

  StreamSubscription<AuthState>? _authSubscription;
  Timer? _recentReadingSyncTimer;
  Timer? _profileSyncTimer;
  final Completer<void> _loadCompleter = Completer<void>();
  final Map<String, ({String userId, MushafRecentReading recent})>
  _pendingRecentSyncs = {};
  bool _isFlushingProfileSync = false;
  bool _isDeletedAtColumnSupported = true;
  bool _isRecentKeyColumnSupported = true;
  final Map<String, MushafProfile> _pendingProfileSyncs = {};

  MushafReadingProvider() {
    WidgetsBinding.instance.addObserver(this);
    load();
    _listenToAuthChanges();
    unawaited(_syncExistingSessionAfterLoad());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(flushPendingProfileSyncs());
      unawaited(flushPendingRecentReadingSync());
    }
  }

  void _listenToAuthChanges() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) async {
      await _loadCompleter.future;
      final user = data.session?.user;
      if (user != null) {
        try {
          await syncWithSupabase(user.id);
        } catch (e) {
          debugPrint('Error syncing Mushaf after auth change: $e');
        }
      }
    });
  }

  Future<void> _syncExistingSessionAfterLoad() async {
    await _loadCompleter.future;
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        await syncWithSupabase(user.id);
      } catch (e) {
        debugPrint('Error syncing Mushaf existing session: $e');
      }
    }
  }

  bool get isLoaded => _isLoaded;
  List<MushafProfile> get profiles => List.unmodifiable(_profiles);
  List<MushafProfile> get activeCustomProfiles =>
      _profiles
          .where(
            (profile) =>
                profile.deletedAt == null &&
                !profile.isFreeRead &&
                !profile.isArchived,
          )
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  List<MushafPageBookmark> get pageBookmarks =>
      List.unmodifiable(_pageBookmarks);
  List<MushafVerseBookmark> get verseBookmarks =>
      List.unmodifiable(_verseBookmarks);
  List<MushafRecentReading> get recentReadings =>
      List.unmodifiable(_recentReadings);
  MushafProfile? get activeProfile {
    final profile = profileById(_activeProfileId);
    return profile != null && profile.deletedAt == null ? profile : null;
  }
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
      if (existing.name != 'Just Read' ||
          existing.isArchived ||
          existing.deletedAt != null) {
        final index = _profiles.indexWhere(
          (profile) => profile.id == existing.id,
        );
        if (index != -1) {
          final updated = existing.copyWith(
            name: 'Just Read',
            isArchived: false,
            clearDeletedAt: true,
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
      _completeLoad();
      notifyListeners();
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _profiles = _deduplicateProfiles(
          _decodeList(decoded['profiles'], MushafProfile.fromJson),
        );
        _pageBookmarks = _decodeList(
          decoded['pageBookmarks'],
          MushafPageBookmark.fromJson,
        );
        _verseBookmarks = _decodeList(
          decoded['verseBookmarks'],
          MushafVerseBookmark.fromJson,
        );
        _deletedPageBookmarkKeys
          ..clear()
          ..addAll(_decodeStringSet(decoded['deletedPageBookmarkKeys']));
        _deletedVerseBookmarkKeys
          ..clear()
          ..addAll(_decodeStringSet(decoded['deletedVerseBookmarkKeys']));
        _recentReadings = _deduplicateRecent(
          _decodeList(
            decoded['recentReadings'],
            MushafRecentReading.fromJson,
          ),
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
      _deletedPageBookmarkKeys.clear();
      _deletedVerseBookmarkKeys.clear();
      _activeProfileId = null;
    }

    _ensureDefaultProfile();
    _normalizeFreeReadProfiles();

    // 30-Day Inactive Auto-Flush for Guest Data
    final isGuestExpired =
        await GuestLifecycleService.isGuestInactiveExpired(prefs);
    if (isGuestExpired) {
      debugPrint(
        '[GuestLifecycle] Inactive for >= 30 days. Flushing local guest mushaf data.',
      );
      _pageBookmarks.clear();
      _verseBookmarks.clear();
      _recentReadings.clear();
      _deletedPageBookmarkKeys.clear();
      _deletedVerseBookmarkKeys.clear();
      final now = DateTime.now();
      _profiles = _profiles.map((p) {
        if (p.isFreeRead) {
          return p.copyWith(
            currentPage: 1,
            lastViewedPage: 1,
            updatedAt: now,
          );
        }
        return p;
      }).toList();
    }
    if (activeProfile == null) {
      _activeProfileId = _profiles.first.id;
    }
    _isLoaded = true;
    await _save();
    _completeLoad();
    notifyListeners();
  }

  void _completeLoad() {
    if (!_loadCompleter.isCompleted) {
      _loadCompleter.complete();
    }
  }

  /// Wipes all local mushaf bookmarks, recent readings, and resets profiles on account deletion.
  Future<void> clearAllLocal() async {
    _pageBookmarks.clear();
    _verseBookmarks.clear();
    _recentReadings.clear();
    _deletedPageBookmarkKeys.clear();
    _deletedVerseBookmarkKeys.clear();
    _profiles.clear();
    _activeProfileId = null;
    _ensureDefaultProfile();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(mushafStoreKey);
      await prefs.remove('mushaf_reading_state_updated_at');
    } catch (e) {
      debugPrint('Error removing mushaf store key: $e');
    }
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
      return profile.copyWith(
        name: 'Just Read',
        isArchived: false,
        clearDeletedAt: true,
      );
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
    final profile = profileById(profileId);
    // Archived goals are history-only until explicitly restored.
    if (profile == null || profile.isArchived || profile.deletedAt != null) return;
    _activeProfileId = profileId;
    await _save();
    notifyListeners();
  }

  int preferredMedinaMushafId() {
    final current = mushafTypeById(_displayMushafId);
    return current.pageCount == 604 ? _displayMushafId : 2;
  }

  Future<void> updateProgress({
    required String profileId,
    required int pageNumber,
    int? surahId,
  }) async {
    final index = _profiles.indexWhere((profile) => profile.id == profileId);
    if (index == -1 || _profiles[index].deletedAt != null) return;
    final profile = _profiles[index];
    final page = _clampInt(pageNumber, profile.startPage, profile.targetPage);
    final furthestPage = page > profile.furthestUnreadPage
        ? page
        : profile.furthestUnreadPage;
    final updated = profile.copyWith(
      currentPage: furthestPage,
      lastViewedPage: page,
      updatedAt: DateTime.now(),
    );
    _profiles[index] = updated;
    _upsertRecentReading(updated, preferredSurahId: surahId);
    await _save();
    notifyListeners();
    _queueProfileSync(updated, delay: Duration.zero);
  }

  Future<void> recordFreeReadPage({
    required int pageNumber,
    int? mushafId,
    int? surahId,
    bool immediateSync = false,
  }) async {
    final targetMushafId = mushafId ?? preferredMedinaMushafId();
    final freeProfile = freeReadProfileForMushaf(targetMushafId);
    final pageCount = mushafTypeById(targetMushafId).pageCount;
    final page = _clampInt(pageNumber, 1, pageCount);
    final furthestPage = page > freeProfile.furthestUnreadPage
        ? page
        : freeProfile.furthestUnreadPage;
    final updated = freeProfile.copyWith(
      currentPage: furthestPage,
      lastViewedPage: page,
      updatedAt: DateTime.now(),
    );
    final index = _profiles.indexWhere((p) => p.id == freeProfile.id);
    if (index != -1) {
      _profiles[index] = updated;
    }
    _upsertRecentReading(updated, preferredSurahId: surahId);
    await _save();
    notifyListeners();
    _queueProfileSync(updated, delay: Duration.zero);
    if (immediateSync) {
      try {
        await flushPendingRecentReadingSync();
      } catch (e) {
        debugPrint('Error flushing Mushaf recent reading: $e');
      }
    }
  }

  MushafRecentReading? latestRecentForSurah(int surahNumber) {
    final now = DateTime.now().toUtc();
    final range = getMedinaSurahPageRange(surahNumber);
    final candidates = _recentReadings.where((reading) {
      final mType = mushafTypeById(reading.mushafId);
      if (mType.pageCount != 604) return false;
      if (reading.pageNumber < range.startPage ||
          reading.pageNumber > range.endPage) {
        return false;
      }
      if (reading.surahId != null &&
          reading.surahId! >= 1 &&
          reading.surahId! <= 114) {
        return reading.surahId == surahNumber;
      }
      return getSurahsOnMedinaPage(reading.pageNumber).contains(surahNumber);
    }).toList()
      ..sort(
        (a, b) => sanitizeSyncTimestamp(b.updatedAt, now: now).normalized
            .compareTo(sanitizeSyncTimestamp(a.updatedAt, now: now).normalized),
      );

    var newest = candidates.firstOrNull;

    // Check if active profiles have higher progress in this Surah
    for (final p in _profiles) {
      if (p.deletedAt != null || p.isArchived) continue;
      final pPage = p.lastViewedPage;
      if (pPage > range.startPage && pPage <= range.endPage) {
        if (newest == null ||
            pPage > newest.pageNumber ||
            p.updatedAt.isAfter(newest.updatedAt)) {
          newest = MushafRecentReading(
            mushafId: p.mushafId,
            pageNumber: pPage,
            profileId: p.id,
            surahId: surahNumber,
            recentKey:
                p.isFreeRead ? 'free:surah:$surahNumber' : 'profile:${p.id}',
            updatedAt: p.updatedAt,
          );
        }
      }
    }

    if (newest == null) return null;
    // Only offer resume when progress moved past the Surah's opening page.
    return newest.pageNumber > range.startPage &&
            newest.pageNumber <= range.endPage
        ? newest
        : null;
  }

  Future<void> updateProfile(String profileId, {required String name}) async {
    final index = _profiles.indexWhere((profile) => profile.id == profileId);
    if (index == -1 || _profiles[index].deletedAt != null) return;
    final profile = _profiles[index];
    final updated = profile.copyWith(name: name, updatedAt: DateTime.now());
    _profiles[index] = updated;
    await _save();
    notifyListeners();
    _queueProfileSync(updated, delay: Duration.zero);
  }

  Future<void> updateProfileRange({
    required String profileId,
    required String name,
    required String planMode,
    required int startPage,
    required int targetPage,
    bool resetProgress = false,
  }) async {
    final index = _profiles.indexWhere((profile) => profile.id == profileId);
    if (index == -1 || _profiles[index].deletedAt != null) return;
    final profile = _profiles[index];
    if (profile.isFreeRead) return;

    final pageCount = mushafTypeById(profile.mushafId).pageCount;
    final start = _clampInt(startPage, 1, pageCount);
    final target = _clampInt(targetPage, start, pageCount);
    final current = resetProgress
        ? start
        : _clampInt(profile.currentPage, start, target);
    final lastViewed = resetProgress
        ? start
        : _clampInt(profile.lastViewedPage, start, target);
    final updated = profile.copyWith(
      name: name,
      planMode: planMode,
      startPage: start,
      targetPage: target,
      currentPage: current,
      lastViewedPage: lastViewed,
      updatedAt: DateTime.now(),
    );
    _profiles[index] = updated;
    _upsertRecentReading(updated);
    await _save();
    notifyListeners();
    _queueProfileSync(updated, delay: Duration.zero);
  }

  Future<void> createPageRangeProfile({
    required String name,
    required int mushafId,
    required int startPage,
    required int targetPage,
    required String planMode,
  }) async {
    if (!canCreateProfile) {
      throw QuranFoundationException(
        'Only $maxActiveMushafProfiles active Mushaf profiles are allowed.',
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
    _queueProfileSync(profile, delay: Duration.zero);
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
    if (index == -1 ||
        _profiles[index].isFreeRead ||
        _profiles[index].deletedAt != null) {
      return;
    }
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
    _queueProfileSync(updated, delay: Duration.zero);
  }

  Future<void> restoreProfile(String profileId) async {
    final index = _profiles.indexWhere((profile) => profile.id == profileId);
    if (index == -1 ||
        _profiles[index].isFreeRead ||
        _profiles[index].deletedAt != null) {
      return;
    }
    if (!canCreateProfile) {
      throw QuranFoundationException(
        'Only $maxActiveMushafProfiles active Mushaf profiles are allowed.',
      );
    }
    final updated = _profiles[index].copyWith(
      isArchived: false,
      updatedAt: DateTime.now(),
    );
    _profiles[index] = updated;
    await _save();
    notifyListeners();
    _queueProfileSync(updated, delay: Duration.zero);
  }

  /// Soft-delete an archived Mushaf goal. The tombstone is synced to Supabase
  /// and purged after 30 days.
  Future<void> deleteProfile(String profileId) async {
    final index = _profiles.indexWhere((profile) => profile.id == profileId);
    if (index == -1) return;
    final profile = _profiles[index];
    if (profile.isFreeRead ||
        profile.deletedAt != null ||
        !profile.isArchived) {
      return;
    }

    final now = DateTime.now();
    final updated = profile.copyWith(
      isArchived: true,
      deletedAt: now,
      updatedAt: now,
    );
    _profiles[index] = updated;
    _recentReadings = _recentReadings
        .where((reading) => reading.profileId != profileId)
        .toList();
    if (_activeProfileId == profileId) {
      _activeProfileId = freeReadProfileForMushaf(profile.mushafId).id;
    }
    await _save();
    notifyListeners();
    _queueProfileSync(updated, delay: Duration.zero);
  }

  List<MushafProfile> get archivedCustomProfiles =>
      _profiles
          .where(
            (profile) =>
                profile.deletedAt == null &&
                !profile.isFreeRead &&
                profile.isArchived,
          )
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

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
      final key = _pageBookmarkKey(mushafId, pageNumber);
      _deletedPageBookmarkKeys.add(key);
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        try {
          await Supabase.instance.client
              .from('mushaf_page_bookmarks')
              .delete()
              .eq('user_id', user.id)
              .eq('mushaf_id', mushafId)
              .eq('page_number', pageNumber);
          _deletedPageBookmarkKeys.remove(key);
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
      _deletedPageBookmarkKeys.remove(_pageBookmarkKey(mushafId, pageNumber));
      _pageBookmarks.add(bookmark);
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        try {
          await Supabase.instance.client.from('mushaf_page_bookmarks').upsert({
            'user_id': user.id,
            'mushaf_id': mushafId,
            'page_number': pageNumber,
            'created_at': bookmark.createdAt.toUtc().toIso8601String(),
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
      final key = _verseBookmarkKey(mushafId, pageNumber, verseKey);
      _deletedVerseBookmarkKeys.add(key);
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
          _deletedVerseBookmarkKeys.remove(key);
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
      _deletedVerseBookmarkKeys.remove(
        _verseBookmarkKey(mushafId, pageNumber, verseKey),
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
            'created_at': bookmark.createdAt.toUtc().toIso8601String(),
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

  List<MushafProfile> _deduplicateProfiles(List<MushafProfile> profiles) {
    final byKey = <String, MushafProfile>{};
    for (final profile in profiles) {
      if (profile.isFreeRead) {
        final key = 'free_read_${profile.mushafId}';
        final existing = byKey[key];
        if (existing == null || profile.updatedAt.isAfter(existing.updatedAt)) {
          byKey[key] = profile;
        }
        continue;
      }
      final key = 'custom_${profile.slug}_${profile.mushafId}';
      final existing = byKey[key];
      if (existing == null) {
        byKey[key] = profile;
      } else {
        final isUuid = RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          caseSensitive: false,
        );
        final preferCurrent =
            (isUuid.hasMatch(profile.id) && !isUuid.hasMatch(existing.id)) ||
            profile.updatedAt.isAfter(existing.updatedAt);
        final base = preferCurrent ? profile : existing;
        byKey[key] = base.copyWith(
          isArchived: _resolveArchivedState(profile, existing),
          deletedAt: profile.deletedAt ?? existing.deletedAt,
        );
      }
    }
    return byKey.values.toList();
  }

  /// Resolve the archive flag independently of the row chosen as metadata base.
  /// The newest write wins; an exact tie prefers "archived" so a stale active
  /// copy cannot resurrect a goal that was just archived on another device.
  bool _resolveArchivedState(MushafProfile a, MushafProfile b) {
    if (a.updatedAt.isAfter(b.updatedAt)) return a.isArchived;
    if (b.updatedAt.isAfter(a.updatedAt)) return b.isArchived;
    return a.isArchived || b.isArchived;
  }

  ({bool isFree, int? surahId, String recentKey}) _resolveRecentIdentity(
    MushafRecentReading item, {
    int? preferredSurahId,
  }) {
    final existingKey = item.recentKey?.trim();
    final explicitSurahId =
        (preferredSurahId != null &&
            preferredSurahId >= 1 &&
            preferredSurahId <= 114)
        ? preferredSurahId
        : (item.surahId != null && item.surahId! >= 1 && item.surahId! <= 114)
        ? item.surahId
        : null;

    if (existingKey != null && existingKey.isNotEmpty) {
      if (existingKey.startsWith('free:surah:')) {
        final parsed = int.tryParse(
          existingKey.substring('free:surah:'.length),
        );
        final resolvedSurah =
            explicitSurahId ??
            (parsed != null && parsed >= 1 && parsed <= 114
                ? parsed
                : getPrimarySurahOnMedinaPage(item.pageNumber));
        return (
          isFree: true,
          surahId: resolvedSurah,
          recentKey: 'free:surah:$resolvedSurah',
        );
      }
      if (existingKey.startsWith('profile:')) {
        return (
          isFree: false,
          surahId: explicitSurahId,
          recentKey: existingKey,
        );
      }
    }

    final matchedProfile = profileById(item.profileId);
    final isFree =
        item.profileId == null ||
        item.profileId!.startsWith('mushaf-free') ||
        (matchedProfile?.isFreeRead ?? false);

    if (isFree) {
      final resolvedSurah =
          explicitSurahId ?? getPrimarySurahOnMedinaPage(item.pageNumber);
      return (
        isFree: true,
        surahId: resolvedSurah,
        recentKey: 'free:surah:$resolvedSurah',
      );
    }

    return (
      isFree: false,
      surahId: explicitSurahId,
      recentKey: 'profile:${item.profileId}',
    );
  }

  List<MushafRecentReading> _deduplicateRecent(
    List<MushafRecentReading> items,
  ) {
    final sorted = List<MushafRecentReading>.from(items)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final seen = <String>{};
    final result = <MushafRecentReading>[];
    for (final item in sorted) {
      final identity = _resolveRecentIdentity(item);
      final key = '${item.mushafId}:${identity.recentKey}';
      if (seen.add(key)) {
        result.add(
          item.copyWith(
            surahId: identity.surahId,
            recentKey: identity.recentKey,
          ),
        );
      }
    }
    return result.take(30).toList();
  }

  void _upsertRecentReading(
    MushafProfile profile, {
    int? preferredSurahId,
  }) {
    final page = profile.lastViewedPage;
    final isFree = profile.isFreeRead || profile.isArchived;
    final isMedina = mushafTypeById(profile.mushafId).pageCount == 604;
    final int? resolvedPreferredSurah = !isFree
        ? null
        : isMedina
        ? getPrimarySurahOnMedinaPage(page, preferredSurahId: preferredSurahId)
        : preferredSurahId;

    final draft = MushafRecentReading(
      mushafId: profile.mushafId,
      pageNumber: page,
      profileId: profile.id,
      surahId: resolvedPreferredSurah,
      updatedAt: DateTime.now(),
    );
    final identity = _resolveRecentIdentity(
      draft,
      preferredSurahId: resolvedPreferredSurah,
    );
    final recent = draft.copyWith(
      surahId: identity.surahId,
      recentKey: identity.recentKey,
    );

    _recentReadings.removeWhere((reading) {
      if (reading.mushafId != profile.mushafId) return false;
      return _resolveRecentIdentity(reading).recentKey == identity.recentKey;
    });
    _recentReadings.insert(0, recent);
    _recentReadings = _deduplicateRecent(_recentReadings);

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      _debounceRecentReadingSync(user.id, recent);
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
        'deletedPageBookmarkKeys': _deletedPageBookmarkKeys.toList(),
        'deletedVerseBookmarkKeys': _deletedVerseBookmarkKeys.toList(),
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

  Set<String> _decodeStringSet(dynamic raw) {
    if (raw is! List) return {};
    return raw
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toSet();
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

  Future<void> reconcileMushafOnBoot(String userId) => syncWithSupabase(userId);

  Future<void> syncWithSupabase(String userId) async {
    final client = Supabase.instance.client;
    try {
      // 1. Sync Profiles (fetch remote before pushing so remote progress is never blindly overwritten)
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

        final dbP = _firstMapWhereOrNull(
          dbProfiles,
          (item) =>
              item['id'] == localP.id ||
              (item['slug'] == localP.slug &&
                  item['mushaf_id'] == localP.mushafId) ||
              (!localP.isFreeRead && item['slug'] == localP.slug),
        );

        if (dbP != null) {
          final remoteId = dbP['id'].toString();
          matchedRemoteIds.add(remoteId);
          if (localP.id != remoteId) {
            await _replaceProfileReferences(localP.id, remoteId);
          }

          final remoteDeletedAt = DateTime.tryParse(
            dbP['deleted_at']?.toString() ?? '',
          );

          // Local tombstone: keep it and push the deletion to the cloud.
          if (localP.deletedAt != null) {
            final tombstone = localP.copyWith(id: remoteId);
            reconciledProfiles.add(tombstone);
            await _syncProfileToSupabase(tombstone, userId: userId);
            continue;
          }

          // Remote tombstone is authoritative; never resurrect with a stale
          // active copy.
          if (remoteDeletedAt != null) {
            reconciledProfiles.add(
              localP.copyWith(
                id: remoteId,
                isArchived: true,
                deletedAt: remoteDeletedAt,
                updatedAt: remoteDeletedAt,
              ),
            );
            continue;
          }

          final syncNow = DateTime.now().toUtc();
          final rawRemoteUpdatedAt = DateTime.tryParse(
            dbP['updated_at']?.toString() ?? '',
          );
          final remoteUpdatedCheck = sanitizeSyncTimestamp(
            rawRemoteUpdatedAt,
            now: syncNow,
          );
          final remoteUpdatedAt = rawRemoteUpdatedAt == null
              ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
              : remoteUpdatedCheck.normalized;
          final localUpdatedCheck = sanitizeSyncTimestamp(
            localP.updatedAt,
            now: syncNow,
          );
          final localUpdatedAt = localUpdatedCheck.normalized;
          final effectiveLocalP = localUpdatedCheck.wasFuture
              ? localP.copyWith(updatedAt: localUpdatedAt)
              : localP;
          final remoteIsArchived = dbP['is_archived'] == true;
          final int remoteCurrent =
              int.tryParse(dbP['current_page']?.toString() ?? '') ?? 1;
          final int remoteFurthest =
              int.tryParse(
                (dbP['furthest_unread_page'] ?? dbP['current_page'])
                        ?.toString() ??
                    '',
              ) ??
              remoteCurrent;
          final int remoteLastViewed =
              int.tryParse(dbP['last_viewed_page']?.toString() ?? '') ??
              remoteFurthest;

          final int maxFurthest = math.max(
            effectiveLocalP.furthestUnreadPage,
            remoteFurthest,
          );
          final int maxCurrent =
              math.max(effectiveLocalP.currentPage, remoteCurrent);
          final int maxLastViewed = math.max(
            effectiveLocalP.lastViewedPage,
            remoteLastViewed,
          );
          final int mergedPage = math.max(maxFurthest, maxCurrent);

          // Archive/restore resolves by `updatedAt` (last write wins). On an
          // exact tie the archived state wins so a stale active copy on another
          // device cannot silently resurrect a goal.
          final bool localWins =
              localUpdatedAt.isAfter(remoteUpdatedAt) ||
              (localUpdatedAt.isAtSameMomentAs(remoteUpdatedAt) &&
                  effectiveLocalP.isArchived &&
                  !remoteIsArchived);

          if (localWins) {
            final syncedLocal = effectiveLocalP.copyWith(
              id: remoteId,
              userId: userId,
              currentPage: mergedPage,
              lastViewedPage: maxLastViewed,
            );
            reconciledProfiles.add(syncedLocal);
            await _syncProfileToSupabase(syncedLocal, userId: userId);
          } else {
            final mergedProfile = MushafProfile(
              id: remoteId,
              userId: userId,
              name: effectiveLocalP.isFreeRead
                  ? 'Just Read'
                  : (dbP['name']?.toString() ?? effectiveLocalP.name),
              slug: dbP['slug']?.toString() ?? effectiveLocalP.slug,
              mushafId:
                  int.tryParse(dbP['mushaf_id']?.toString() ?? '') ??
                  effectiveLocalP.mushafId,
              planMode: dbP['plan_mode']?.toString() ?? effectiveLocalP.planMode,
              startPage:
                  int.tryParse(dbP['start_page']?.toString() ?? '') ??
                  effectiveLocalP.startPage,
              targetPage:
                  int.tryParse(dbP['target_page']?.toString() ?? '') ??
                  effectiveLocalP.targetPage,
              currentPage: mergedPage,
              lastViewedPage: maxLastViewed,
              sortOrder:
                  int.tryParse(dbP['sort_order']?.toString() ?? '') ??
                  effectiveLocalP.sortOrder,
              isArchived: remoteIsArchived,
              createdAt: sanitizeSyncTimestamp(
                DateTime.tryParse(dbP['created_at']?.toString() ?? ''),
                now: syncNow,
              ).normalized,
              updatedAt: remoteUpdatedAt,
            );
            reconciledProfiles.add(mergedProfile);

            final bool localProgressAhead =
                maxFurthest > remoteFurthest ||
                maxCurrent > remoteCurrent ||
                maxLastViewed > remoteLastViewed;

            if (localProgressAhead || remoteUpdatedCheck.wasFuture) {
              await _syncProfileToSupabase(
                localProgressAhead
                    ? mergedProfile.copyWith(updatedAt: DateTime.now().toUtc())
                    : mergedProfile,
                userId: userId,
              );
            }
          }
        } else {
          final syncedLocal = localP.copyWith(userId: userId);
          final returnedId = await _syncProfileToSupabase(
            syncedLocal,
            userId: userId,
          );
          if (returnedId != null && returnedId != localP.id) {
            await _replaceProfileReferences(localP.id, returnedId);
          }
          reconciledProfiles.add(
            syncedLocal.copyWith(id: returnedId ?? syncedLocal.id),
          );
        }
      }

      for (final dbP in dbProfiles) {
        final remoteId = dbP['id'].toString();
        if (matchedRemoteIds.contains(remoteId)) continue;
        if (dbP['deleted_at'] != null) continue;

        final remoteProfile = MushafProfile(
          id: remoteId,
          userId: userId,
          name: dbP['name'],
          slug: dbP['slug'],
          mushafId: dbP['mushaf_id'],
          planMode: dbP['plan_mode'],
          startPage: dbP['start_page'],
          targetPage: dbP['target_page'],
          currentPage: dbP['furthest_unread_page'] ?? dbP['current_page'],
          lastViewedPage:
              dbP['last_viewed_page'] ??
              dbP['furthest_unread_page'] ??
              dbP['current_page'],
          sortOrder: dbP['sort_order'],
          isArchived: dbP['is_archived'] ?? false,
          deletedAt: DateTime.tryParse(dbP['deleted_at']?.toString() ?? ''),
          createdAt:
              DateTime.tryParse(dbP['created_at']?.toString() ?? '') ??
              DateTime.now(),
          updatedAt:
              DateTime.tryParse(dbP['updated_at']?.toString() ?? '') ??
              DateTime.now(),
        );

        if (!remoteProfile.isFreeRead) {
          final existingIndex = reconciledProfiles.indexWhere(
            (p) => !p.isFreeRead && p.slug == remoteProfile.slug,
          );
          if (existingIndex != -1) {
            final existing = reconciledProfiles[existingIndex];
            reconciledProfiles[existingIndex] = existing.copyWith(
              currentPage: math.max(
                existing.currentPage,
                remoteProfile.currentPage,
              ),
              lastViewedPage: math.max(
                existing.lastViewedPage,
                remoteProfile.lastViewedPage,
              ),
              isArchived: _resolveArchivedState(existing, remoteProfile),
            );
            continue;
          }
        }

        reconciledProfiles.add(remoteProfile);
      }

      _profiles = _deduplicateProfiles(reconciledProfiles);

      // Purge tombstones after the 30-day retention window.
      final purgeCutoff = DateTime.now().subtract(const Duration(days: 30));
      final expiredTombstoneIds = _profiles
          .where(
            (p) =>
                p.deletedAt != null && p.deletedAt!.isBefore(purgeCutoff),
          )
          .map((p) => p.id)
          .toSet();
      if (expiredTombstoneIds.isNotEmpty) {
        _profiles = _profiles
            .where((p) => !expiredTombstoneIds.contains(p.id))
            .toList();
        _recentReadings = _recentReadings
            .where(
              (reading) =>
                  reading.profileId == null ||
                  !expiredTombstoneIds.contains(reading.profileId),
            )
            .toList();
      }

      final active = profileById(_activeProfileId);
      if (active == null || active.isArchived || active.deletedAt != null) {
        _activeProfileId = freeReadProfileForMushaf(_displayMushafId).id;
      }

      try {
        await client
            .from('mushaf_profiles')
            .delete()
            .eq('user_id', userId)
            .lt('deleted_at', purgeCutoff.toUtc().toIso8601String());
      } catch (e) {
        debugPrint('Error purging expired Mushaf tombstones: $e');
      }

      // 2. Sync Page Bookmarks
      await _flushDeletedPageBookmarks(userId);
      final remotePageBookRes = await client
          .from('mushaf_page_bookmarks')
          .select('*')
          .eq('user_id', userId);
      final List<dynamic> dbPageBook = remotePageBookRes;
      final List<MushafPageBookmark> reconciledPageBook = [];
      final Set<String> matchedPageBookKeys = {};

      for (final localB in _pageBookmarks) {
        final key = _pageBookmarkKey(localB.mushafId, localB.pageNumber);
        if (_deletedPageBookmarkKeys.contains(key)) continue;

        final dbB = _firstMapWhereOrNull(
          dbPageBook,
          (item) =>
              item['mushaf_id'] == localB.mushafId &&
              item['page_number'] == localB.pageNumber,
        );
        if (dbB != null) {
          matchedPageBookKeys.add(key);
        } else {
          await client.from('mushaf_page_bookmarks').upsert({
            'user_id': userId,
            'mushaf_id': localB.mushafId,
            'page_number': localB.pageNumber,
            'created_at': localB.createdAt.toUtc().toIso8601String(),
          }, onConflict: 'user_id,mushaf_id,page_number');
        }
        reconciledPageBook.add(localB);
      }

      for (final dbB in dbPageBook) {
        final key = _pageBookmarkKey(dbB['mushaf_id'], dbB['page_number']);
        if (matchedPageBookKeys.contains(key)) continue;
        if (_deletedPageBookmarkKeys.contains(key)) continue;
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
      await _flushDeletedVerseBookmarks(userId);
      final remoteVerseBookRes = await client
          .from('mushaf_verse_bookmarks')
          .select('*')
          .eq('user_id', userId);
      final List<dynamic> dbVerseBook = remoteVerseBookRes;
      final List<MushafVerseBookmark> reconciledVerseBook = [];
      final Set<String> matchedVerseBookKeys = {};

      for (final localB in _verseBookmarks) {
        final key = _verseBookmarkKey(
          localB.mushafId,
          localB.pageNumber,
          localB.verseKey,
        );
        if (_deletedVerseBookmarkKeys.contains(key)) continue;

        final dbB = _firstMapWhereOrNull(
          dbVerseBook,
          (item) =>
              item['mushaf_id'] == localB.mushafId &&
              item['page_number'] == localB.pageNumber &&
              item['verse_key'] == localB.verseKey,
        );
        if (dbB != null) {
          matchedVerseBookKeys.add(key);
        } else {
          await client.from('mushaf_verse_bookmarks').upsert({
            'user_id': userId,
            'mushaf_id': localB.mushafId,
            'page_number': localB.pageNumber,
            'verse_key': localB.verseKey,
            'created_at': localB.createdAt.toUtc().toIso8601String(),
          }, onConflict: 'user_id,mushaf_id,page_number,verse_key');
        }
        reconciledVerseBook.add(localB);
      }

      for (final dbB in dbVerseBook) {
        final key = _verseBookmarkKey(
          dbB['mushaf_id'],
          dbB['page_number'],
          dbB['verse_key'],
        );
        if (matchedVerseBookKeys.contains(key)) continue;
        if (_deletedVerseBookmarkKeys.contains(key)) continue;
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
      final recentSyncNow = DateTime.now().toUtc();
      final remoteRecentRes = await client
          .from('mushaf_recent_readings')
          .select('*')
          .eq('user_id', userId)
          .order('updated_at', ascending: false)
          .limit(20);
      final List<dynamic> dbRecent = remoteRecentRes;
      final Set<String> futureRemoteRecentKeys = {};
      final List<MushafRecentReading> parsedDbRecent = dbRecent.map((raw) {
        final map = raw is Map<String, dynamic>
            ? raw
            : Map<String, dynamic>.from(raw as Map);
        final parsed = MushafRecentReading.fromJson(map);
        final identity = _resolveRecentIdentity(parsed);
        final sanitizedTs = sanitizeSyncTimestamp(
          parsed.updatedAt,
          now: recentSyncNow,
        );
        if (sanitizedTs.wasFuture) {
          futureRemoteRecentKeys.add('${parsed.mushafId}:${identity.recentKey}');
        }
        return parsed.copyWith(
          surahId: identity.surahId,
          recentKey: identity.recentKey,
          updatedAt: sanitizedTs.normalized,
        );
      }).toList();

      final List<MushafRecentReading> reconciledRecent = [];
      final Set<String> matchedRecentKeys = {};
      final List<MushafRecentReading> recentToPush = [];

      for (final localR in _recentReadings) {
        final localIdentity = _resolveRecentIdentity(localR);
        final sanitizedLocalTs = sanitizeSyncTimestamp(
          localR.updatedAt,
          now: recentSyncNow,
        );
        final normalizedLocal = localR.copyWith(
          surahId: localIdentity.surahId,
          recentKey: localIdentity.recentKey,
          updatedAt: sanitizedLocalTs.normalized,
        );
        final compositeKey = '${localR.mushafId}:${localIdentity.recentKey}';
        final dbR = parsedDbRecent.where((remote) {
          return remote.mushafId == localR.mushafId &&
              _resolveRecentIdentity(remote).recentKey ==
                  localIdentity.recentKey;
        }).firstOrNull;

        if (dbR != null) {
          matchedRecentKeys.add(compositeKey);
          final remoteWasFuture = futureRemoteRecentKeys.contains(compositeKey);
          if ((remoteWasFuture && !sanitizedLocalTs.wasFuture) ||
              normalizedLocal.updatedAt.isAfter(dbR.updatedAt)) {
            reconciledRecent.add(normalizedLocal);
            recentToPush.add(normalizedLocal);
          } else {
            final winner = dbR.copyWith(
              profileId: dbR.profileId ?? normalizedLocal.profileId,
            );
            reconciledRecent.add(winner);
            if (remoteWasFuture) {
              recentToPush.add(winner);
            }
          }
        } else {
          reconciledRecent.add(normalizedLocal);
          recentToPush.add(normalizedLocal);
        }
      }

      for (final dbR in parsedDbRecent) {
        final identity = _resolveRecentIdentity(dbR);
        final key = '${dbR.mushafId}:${identity.recentKey}';
        if (matchedRecentKeys.contains(key)) continue;
        matchedRecentKeys.add(key);
        reconciledRecent.add(dbR);
        if (futureRemoteRecentKeys.contains(key)) {
          recentToPush.add(dbR);
        }
      }

      // Ensure reconciled profile progress (lastViewedPage) is synchronized into recent readings
      for (final profile in _profiles) {
        if (profile.deletedAt != null || profile.isArchived) continue;
        final pageNum = profile.lastViewedPage;
        if (pageNum <= 1) continue;

        final isFree = profile.isFreeRead;
        final surahId = getPrimarySurahOnMedinaPage(pageNum);
        final resolvedKey = isFree ? 'free:surah:$surahId' : 'profile:${profile.id}';

        final existingIndex = reconciledRecent.indexWhere((r) {
          if (r.mushafId != profile.mushafId) return false;
          return _resolveRecentIdentity(r).recentKey == resolvedKey;
        });

        if (existingIndex == -1) {
          final newRecent = MushafRecentReading(
            mushafId: profile.mushafId,
            pageNumber: pageNum,
            profileId: profile.id,
            surahId: isFree ? surahId : null,
            recentKey: resolvedKey,
            updatedAt: profile.updatedAt,
          );
          reconciledRecent.add(newRecent);
          recentToPush.add(newRecent);
        } else {
          final existing = reconciledRecent[existingIndex];
          if (pageNum > existing.pageNumber ||
              profile.updatedAt.isAfter(existing.updatedAt)) {
            final updated = existing.copyWith(
              pageNumber: math.max(existing.pageNumber, pageNum),
              profileId: profile.id,
              surahId: isFree ? surahId : existing.surahId,
              recentKey: resolvedKey,
              updatedAt: profile.updatedAt,
            );
            reconciledRecent[existingIndex] = updated;
            recentToPush.add(updated);
          }
        }
      }

      _recentReadings = _deduplicateRecent(reconciledRecent);
      if (recentToPush.isNotEmpty) {
        await _syncRecentReadingsBatchToSupabase(userId, recentToPush);
      }

      await _save();
      notifyListeners();
    } catch (e) {
      debugPrint('Error syncing Mushaf with Supabase: $e');
      rethrow;
    }
  }

  Future<String?> _syncProfileToSupabase(
    MushafProfile p, {
    String? userId,
  }) async {
    final client = Supabase.instance.client;
    final targetUserId =
        userId ??
        client.auth.currentUser?.id ??
        (p.userId == 'local' ? null : p.userId);
    if (targetUserId == null) {
      throw StateError(
        'Cannot sync Mushaf profile without an authenticated user.',
      );
    }

    try {
      final uuidRegExp = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      );
      final bool hasUuid = uuidRegExp.hasMatch(p.id);

      final upsertData = {
        'user_id': targetUserId,
        'name': p.name,
        'slug': p.slug,
        'mushaf_id': p.mushafId,
        'plan_mode': p.planMode,
        'start_page': p.startPage,
        'target_page': p.targetPage,
        'current_page': p.currentPage,
        'furthest_unread_page': p.furthestUnreadPage,
        'last_viewed_page': p.lastViewedPage,
        'sort_order': p.sortOrder,
        'is_archived': p.isArchived,
        'deleted_at': p.deletedAt?.toUtc().toIso8601String(),
        'updated_at': p.updatedAt.toUtc().toIso8601String(),
      };
      if (!_isDeletedAtColumnSupported) {
        upsertData.remove('deleted_at');
      }

      if (hasUuid) {
        upsertData['id'] = p.id;
        try {
          await client
              .from('mushaf_profiles')
              .upsert(upsertData, onConflict: 'id');
          return p.id;
        } on PostgrestException catch (pgErr) {
          if (pgErr.code != '23505') rethrow;
          final fallbackData = Map<String, dynamic>.from(upsertData)
            ..remove('id');
          final response = await client
              .from('mushaf_profiles')
              .upsert(fallbackData, onConflict: 'user_id,slug,mushaf_id')
              .select('id')
              .single();
          final returnedId = response['id']?.toString();
          if (returnedId != null) {
            final index = _profiles.indexWhere((item) => item.id == p.id);
            if (index != -1) {
              _profiles[index] = _profiles[index].copyWith(
                id: returnedId,
                userId: targetUserId,
              );
              if (_activeProfileId == p.id) {
                _activeProfileId = returnedId;
              }
            }
            await _replaceProfileReferences(p.id, returnedId);
            await _save();
            return returnedId;
          }
          return p.id;
        }
      } else {
        final response = await client
            .from('mushaf_profiles')
            .upsert(upsertData, onConflict: 'user_id,slug,mushaf_id')
            .select('id')
            .single();
        final returnedId = response['id']?.toString();
        if (returnedId != null) {
          final index = _profiles.indexWhere((item) => item.id == p.id);
          if (index != -1) {
            _profiles[index] = _profiles[index].copyWith(
              id: returnedId,
              userId: targetUserId,
            );
            if (_activeProfileId == p.id) {
              _activeProfileId = returnedId;
            }
          }
          await _replaceProfileReferences(p.id, returnedId);
          await _save();
          return returnedId;
        }
      }
    } catch (e) {
      if (_isDeletedAtColumnSupported &&
          e is PostgrestException &&
          (e.message.contains('deleted_at') ||
              e.code == 'PGRST204' ||
              e.code == '42703')) {
        // Backward compatibility while the deleted_at migration rolls out.
        _isDeletedAtColumnSupported = false;
        return _syncProfileToSupabase(p, userId: userId);
      }
      debugPrint('Error syncing Mushaf profile to Supabase: $e');
      rethrow;
    }
    return null;
  }

  Future<void> _replaceProfileReferences(String oldId, String newId) async {
    if (oldId == newId) return;

    var changed = false;
    if (_activeProfileId == oldId) {
      _activeProfileId = newId;
      changed = true;
    }
    if (_pendingRecentSyncs.isNotEmpty) {
      final remapped =
          <String, ({String userId, MushafRecentReading recent})>{};
      for (final entry in _pendingRecentSyncs.entries) {
        final item = entry.value;
        if (item.recent.profileId == oldId) {
          changed = true;
          final updatedItem = item.recent.copyWith(profileId: newId);
          final identity = _resolveRecentIdentity(updatedItem);
          remapped['${updatedItem.mushafId}:${identity.recentKey}'] = (
            userId: item.userId,
            recent: updatedItem.copyWith(
              surahId: identity.surahId,
              recentKey: identity.recentKey,
            ),
          );
        } else {
          remapped[entry.key] = item;
        }
      }
      _pendingRecentSyncs
        ..clear()
        ..addAll(remapped);
    }

    final updatedRecent = <MushafRecentReading>[];
    for (final reading in _recentReadings) {
      final profileId = reading.profileId == oldId ? newId : reading.profileId;
      if (profileId != reading.profileId) {
        changed = true;
        updatedRecent.add(reading.copyWith(profileId: profileId));
      } else {
        updatedRecent.add(reading);
      }
    }

    if (changed) {
      _recentReadings = _deduplicateRecent(updatedRecent);
      await _save();
    }
  }

  Future<void> _flushDeletedPageBookmarks(String userId) async {
    if (_deletedPageBookmarkKeys.isEmpty) return;
    final client = Supabase.instance.client;
    final deletedKeys = Set<String>.from(_deletedPageBookmarkKeys);
    for (final key in deletedKeys) {
      final parts = key.split('-');
      if (parts.length != 2) continue;
      final mushafId = int.tryParse(parts[0]);
      final pageNumber = int.tryParse(parts[1]);
      if (mushafId == null || pageNumber == null) continue;

      await client
          .from('mushaf_page_bookmarks')
          .delete()
          .eq('user_id', userId)
          .eq('mushaf_id', mushafId)
          .eq('page_number', pageNumber);
      _deletedPageBookmarkKeys.remove(key);
    }
  }

  Future<void> _flushDeletedVerseBookmarks(String userId) async {
    if (_deletedVerseBookmarkKeys.isEmpty) return;
    final client = Supabase.instance.client;
    final deletedKeys = Set<String>.from(_deletedVerseBookmarkKeys);
    for (final key in deletedKeys) {
      final parts = key.split('|');
      if (parts.length != 3) continue;
      final mushafId = int.tryParse(parts[0]);
      final pageNumber = int.tryParse(parts[1]);
      final verseKey = parts[2];
      if (mushafId == null || pageNumber == null || verseKey.isEmpty) {
        continue;
      }

      await client
          .from('mushaf_verse_bookmarks')
          .delete()
          .eq('user_id', userId)
          .eq('mushaf_id', mushafId)
          .eq('page_number', pageNumber)
          .eq('verse_key', verseKey);
      _deletedVerseBookmarkKeys.remove(key);
    }
  }

  void _queueProfileSync(
    MushafProfile profile, {
    Duration delay = const Duration(milliseconds: 900),
  }) {
    if (profile.userId == 'local') return;
    if (Supabase.instance.client.auth.currentUser == null) return;

    _pendingProfileSyncs[profile.id] = profile;
    _profileSyncTimer?.cancel();
    _profileSyncTimer = Timer(delay, () {
      unawaited(flushPendingProfileSyncs());
    });
  }

  Future<bool> flushPendingProfileSyncs() async {
    if (_pendingProfileSyncs.isEmpty) return true;
    if (_isFlushingProfileSync) return false;

    _isFlushingProfileSync = true;
    final pending = Map<String, MushafProfile>.from(_pendingProfileSyncs);
    _pendingProfileSyncs.clear();

    try {
      for (final profile in pending.values) {
        await _syncProfileToSupabase(profile);
      }
    } catch (_) {
      _pendingProfileSyncs.addAll(pending);
      return false;
    } finally {
      _isFlushingProfileSync = false;
      if (_pendingProfileSyncs.isNotEmpty) {
        _profileSyncTimer?.cancel();
        _profileSyncTimer = Timer(const Duration(seconds: 5), () {
          unawaited(flushPendingProfileSyncs());
        });
      }
    }
    return _pendingProfileSyncs.isEmpty;
  }

  void _debounceRecentReadingSync(
    String userId,
    MushafRecentReading recent,
  ) {
    final identity = _resolveRecentIdentity(recent);
    final key = '${recent.mushafId}:${identity.recentKey}';
    _pendingRecentSyncs[key] = (
      userId: userId,
      recent: recent.copyWith(
        surahId: identity.surahId,
        recentKey: identity.recentKey,
      ),
    );

    _recentReadingSyncTimer?.cancel();
    _recentReadingSyncTimer = Timer(const Duration(seconds: 2), () async {
      unawaited(flushPendingRecentReadingSync());
    });
  }

  String? _resolveUuidProfileIdForRecent(MushafRecentReading reading) {
    final uuidRegExp = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (reading.profileId != null && uuidRegExp.hasMatch(reading.profileId!)) {
      return reading.profileId;
    }
    if (reading.profileId == null ||
        reading.profileId!.startsWith('mushaf-free')) {
      final freeProfile = _profiles.where((p) {
        return p.deletedAt == null &&
            p.isFreeRead &&
            p.mushafId == reading.mushafId &&
            uuidRegExp.hasMatch(p.id);
      }).firstOrNull;
      return freeProfile?.id;
    }
    return null;
  }

  bool _isMissingRecentKeySchemaError(Object error) {
    if (error is! PostgrestException) return false;
    final code = error.code ?? '';
    final msg = '${error.message} ${error.details ?? ''}';
    return code == '42703' ||
        code == 'PGRST204' ||
        code == '42P10' ||
        msg.contains('recent_key') ||
        msg.contains('surah_id');
  }

  Future<void> _syncRecentReadingsBatchToSupabase(
    String userId,
    List<MushafRecentReading> readings,
  ) async {
    if (readings.isEmpty) return;
    final client = Supabase.instance.client;

    if (_isRecentKeyColumnSupported) {
      try {
        final dedupedPayload = <String, Map<String, dynamic>>{};
        for (final r in readings) {
          final identity = _resolveRecentIdentity(r);
          final resolvedProfileId = _resolveUuidProfileIdForRecent(r);
          if (!identity.isFree && resolvedProfileId == null) continue;
          final key = '${r.mushafId}:${identity.recentKey}';
          dedupedPayload[key] = {
            'user_id': userId,
            'mushaf_id': r.mushafId,
            'page_number': r.pageNumber,
            'profile_id': resolvedProfileId,
            'surah_id': identity.surahId,
            'recent_key': identity.recentKey,
            'updated_at': r.updatedAt.toUtc().toIso8601String(),
          };
        }
        if (dedupedPayload.isNotEmpty) {
          await client
              .from('mushaf_recent_readings')
              .upsert(
                dedupedPayload.values.toList(),
                onConflict: 'user_id,mushaf_id,recent_key',
              );
        }
        return;
      } catch (e) {
        if (!_isMissingRecentKeySchemaError(e)) {
          debugPrint('Error syncing Mushaf recent readings to Supabase: $e');
          rethrow;
        }
        _isRecentKeyColumnSupported = false;
      }
    }

    // Legacy fallback before the recent_key/surah_id migration is applied.
    final legacyPayload = <String, Map<String, dynamic>>{};
    for (final r in readings) {
      final resolvedProfileId = _resolveUuidProfileIdForRecent(r);
      final identity = _resolveRecentIdentity(r);
      if (!identity.isFree && resolvedProfileId == null) continue;
      final legacyKey = '${r.mushafId}:${resolvedProfileId ?? 'null'}';
      legacyPayload[legacyKey] = {
        'user_id': userId,
        'mushaf_id': r.mushafId,
        'page_number': r.pageNumber,
        'profile_id': resolvedProfileId,
        'updated_at': r.updatedAt.toUtc().toIso8601String(),
      };
    }
    if (legacyPayload.isNotEmpty) {
      try {
        await client
            .from('mushaf_recent_readings')
            .upsert(
              legacyPayload.values.toList(),
              onConflict: 'user_id,mushaf_id,profile_id',
            );
      } catch (e) {
        debugPrint('Error syncing legacy Mushaf recent readings: $e');
        rethrow;
      }
    }
  }

  Future<void> flushPendingRecentReadingSync() async {
    _recentReadingSyncTimer?.cancel();
    _recentReadingSyncTimer = null;

    if (_pendingRecentSyncs.isEmpty) return;
    final pending = Map<String, ({String userId, MushafRecentReading recent})>.from(
      _pendingRecentSyncs,
    );
    _pendingRecentSyncs.clear();

    try {
      final byUser = <String, List<MushafRecentReading>>{};
      for (final entry in pending.values) {
        byUser.putIfAbsent(entry.userId, () => []).add(entry.recent);
      }
      for (final userEntry in byUser.entries) {
        await _syncRecentReadingsBatchToSupabase(userEntry.key, userEntry.value);
      }
    } catch (_) {
      for (final entry in pending.entries) {
        _pendingRecentSyncs.putIfAbsent(entry.key, () => entry.value);
      }
      rethrow;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    unawaited(flushPendingProfileSyncs());
    unawaited(flushPendingRecentReadingSync());
    super.dispose();
  }
}

int _clampInt(int value, int min, int max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

Map<String, dynamic>? _firstMapWhereOrNull(
  Iterable<dynamic> items,
  bool Function(Map<String, dynamic> item) test,
) {
  for (final item in items) {
    if (item is! Map) continue;
    final map = Map<String, dynamic>.from(item);
    if (test(map)) return map;
  }
  return null;
}

String _pageBookmarkKey(dynamic mushafId, dynamic pageNumber) {
  return '$mushafId-$pageNumber';
}

String _verseBookmarkKey(
  dynamic mushafId,
  dynamic pageNumber,
  dynamic verseKey,
) {
  return '$mushafId|$pageNumber|$verseKey';
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
