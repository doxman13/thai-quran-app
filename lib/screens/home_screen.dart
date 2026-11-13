import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/medina_mushaf_pages.dart';
import '../data/offline_surah_names.dart';
import '../data/quran_foundation_repository.dart';
import '../data/quran_repository.dart';
import '../data/tadabbur_repository.dart';
import '../database/hifz_repository.dart';
import '../models/mushaf_models.dart';
import '../models/tadabbur_note.dart';
import '../providers/local_reading_provider.dart';
import '../providers/mushaf_reading_provider.dart';
import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/stats_provider.dart';
import '../providers/supabase_provider.dart';
import '../shared/shared.dart';
import '../theme/app_theme.dart';
import 'bookmarks_screen.dart';
import 'browse_screen.dart';
import 'goals_screen.dart';
import 'hifz_landing_screen.dart';
import 'hifz_wizard_setup_screen.dart';
import 'mushaf_reader_screen.dart';
import 'reading_screen.dart';
import 'settings_screen.dart';
import 'tadabbur_community_screen.dart';
import '../widgets/auth_bottom_sheet.dart';

extension _TadabburNoteAuthorExt on TadabburNote {
  String get authorName {
    if (isAnonymous) return 'ผู้ศรัทธา (ไม่ระบุชื่อ)';
    final raw = (userEmail ?? '').trim();
    if (raw.isEmpty) return 'ผู้ศรัทธา';
    return raw.contains('@') ? raw.split('@').first : raw;
  }
}

class _ModeSelectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ModeSelectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: colorScheme.outline),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSansThai(
                  color: colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSansThai(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final QuranRepository repository;
  final bool repositoryReady;

  const HomeScreen({
    super.key,
    required this.repository,
    this.repositoryReady = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _legacyQuickLinksKey = 'custom_quick_links';
  static const String _quickLinksKeyPrefix = 'custom_quick_links_v2_';
  static const String _quickLinksDeletedKeyPrefix =
      'custom_quick_links_deleted_v2_';
  static const String _quickLinksSyncedAtKeyPrefix =
      'custom_quick_links_synced_at_v2_';

  final QuranFoundationRepository _foundationRepository =
      QuranFoundationRepository();
  final TadabburRepository _tadabburRepository = TadabburRepository();

  int _navIndex = 0;
  bool _isInit = false;
  bool _initFailed = false;

  // Community Tadabbur preview state
  List<TadabburNote> _communityPool = [];
  List<TadabburNote> _communityPreview = [];
  bool _loadingCommunity = true;

  // Custom Quick Links
  List<CustomQuickLink> _quickLinks = [];
  StreamSubscription<AuthState>? _quickLinkAuthSubscription;
  String? _quickLinksLoadedForUser;
  int _quickLinksRevision = 0;

  @override
  void initState() {
    super.initState();
    _isInit = widget.repositoryReady;
    _loadQuickLinks();
    _loadCommunityPreview();
    _quickLinkAuthSubscription = Supabase.instance.client.auth.onAuthStateChange
        .listen((data) {
      final userId = data.session?.user.id;
      if (userId == _quickLinksLoadedForUser) return;
      unawaited(_loadQuickLinks());
    });
    if (!_isInit) {
      _initApp();
    }
  }

  Future<void> _loadCommunityPreview() async {
    try {
      final notes = await _tadabburRepository.fetchCommunityNotes(
        '0',
        '0',
        limit: 10,
      );
      if (!mounted) return;
      setState(() {
        _communityPool = notes;
        _communityPreview = notes;
        _loadingCommunity = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingCommunity = false;
      });
    }
  }

  void _shuffleCommunityPreview() {
    if (_communityPool.isEmpty) {
      unawaited(_loadCommunityPreview());
      return;
    }
    setState(() {
      final shuffled = List<TadabburNote>.from(_communityPool)..shuffle();
      _communityPool = shuffled;
      _communityPreview = shuffled;
    });
  }

  Future<void> _initApp() async {
    try {
      await widget.repository.init();
    } catch (e) {
      debugPrint('Unable to initialize Quran repository: $e');
      if (mounted) {
        setState(() => _initFailed = true);
      }
      return;
    }
    if (mounted) {
      setState(() {
        _isInit = true;
        _initFailed = false;
      });
      unawaited(_triggerAutoSync());
    }
  }

  Future<void> _triggerAutoSync() async {
    try {
      await _syncAllUserData();
    } catch (e) {
      debugPrint('Auto sync failed: $e');
    }
  }

  Future<bool> _syncAllUserData() async {
    final supabaseProv = Provider.of<SupabaseProvider>(context, listen: false);
    if (!supabaseProv.isLoggedIn || supabaseProv.user == null) {
      return false;
    }

    final userId = supabaseProv.user!.id;
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final reading = Provider.of<LocalReadingProvider>(context, listen: false);
    final mushaf = Provider.of<MushafReadingProvider>(context, listen: false);
    final notes = Provider.of<NotesProvider>(context, listen: false);
    final stats = Provider.of<StatsProvider>(context, listen: false);
    final hifz = HifzRepository();

    await reading.flushPendingProfileSyncs();
    await reading.flushPendingRecentReadingSync();
    await reading.flushPendingReadingStateSync();
    await mushaf.flushPendingProfileSyncs();
    await mushaf.flushPendingRecentReadingSync();
    await stats.flushPendingSave();
    await settings.syncWithSupabase(userId);
    await notes.syncWithSupabase();
    await reading.syncBookmarksAndProfilesWithSupabase(userId);
    await reading.syncReadingStateWithSupabase(userId);
    await mushaf.syncWithSupabase(userId);
    await stats.syncWithSupabase(userId);
    await hifz.syncWithSupabase(userId);
    await hifz.syncHistoryWithSupabase();
    await _saveQuickLinks();
    return true;
  }

  void _navigateToGoalsScreen(BuildContext context) {
    final supabaseProv = Provider.of<SupabaseProvider>(context, listen: false);
    if (!supabaseProv.isLoggedIn) {
      AuthRequiredDialog.show(
        context,
        featureName: 'เป้าหมายการอ่าน (Reading Goals)',
        reason:
            'การสร้างและจัดการเป้าหมายการอ่านจำเป็นต้องเข้าสู่ระบบ เพื่อบันทึกความคืบหน้าบนคลาวด์',
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GoalsScreen(
          repository: widget.repository,
          foundationRepository: _foundationRepository,
        ),
      ),
    );
  }

  String _quickLinksScope(String? userId) => userId ?? 'guest';

  String _quickLinksStorageKey(String scope) =>
      '$_quickLinksKeyPrefix$scope';

  String _quickLinksDeletedKey(String scope) =>
      '$_quickLinksDeletedKeyPrefix$scope';

  String _quickLinksSyncedAtKey(String scope) =>
      '$_quickLinksSyncedAtKeyPrefix$scope';

  List<CustomQuickLink> _decodeQuickLinks(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded
          .whereType<Map>()
          .map(
            (e) => CustomQuickLink.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();
    } catch (e) {
      debugPrint('Error decoding quick links: $e');
      return [];
    }
  }

  Future<void> _persistQuickLinks(
    SharedPreferences prefs,
    String scope,
    List<CustomQuickLink> links,
  ) async {
    final normalized = _normalizeQuickLinks(links);
    await prefs.setString(
      _quickLinksStorageKey(scope),
      jsonEncode(normalized.map((e) => e.toJson()).toList()),
    );
  }

  Future<Set<String>> _loadDeletedQuickLinkIds(
    SharedPreferences prefs,
    String scope,
  ) async {
    final raw = prefs.getString(_quickLinksDeletedKey(scope));
    if (raw == null || raw.isEmpty) return <String>{};
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => e.toString())
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> _saveDeletedQuickLinkIds(
    SharedPreferences prefs,
    String scope,
    Set<String> ids,
  ) async {
    if (ids.isEmpty) {
      await prefs.remove(_quickLinksDeletedKey(scope));
    } else {
      await prefs.setString(
        _quickLinksDeletedKey(scope),
        jsonEncode(ids.toList()),
      );
    }
  }

  Future<void> _loadQuickLinks() async {
    final revision = _quickLinksRevision;
    final prefs = await SharedPreferences.getInstance();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final scope = _quickLinksScope(userId);

    List<CustomQuickLink> links;
    if (prefs.containsKey(_quickLinksStorageKey(scope))) {
      links = _decodeQuickLinks(prefs.getString(_quickLinksStorageKey(scope)));
    } else if (userId == null) {
      // One-time migration of the old unscoped key. Only the guest scope keeps
      // a local copy; signed-in accounts are restored from Supabase so that
      // another account's links can never be adopted.
      links = _decodeQuickLinks(prefs.getString(_legacyQuickLinksKey));
    } else {
      links = const [];
    }
    // The legacy blob was never account-scoped; drop it so it cannot leak into
    // another account that signs in on this device later.
    if (prefs.containsKey(_legacyQuickLinksKey)) {
      await prefs.remove(_legacyQuickLinksKey);
    }

    links = _normalizeQuickLinks(links);

    if (userId != null) {
      links = await _syncQuickLinksWithSupabase(userId, scope, links);
    }

    // A local edit (or an account switch) landed while this load was in
    // flight — keep the newer state instead of overwriting it.
    if (!mounted ||
        revision != _quickLinksRevision ||
        Supabase.instance.client.auth.currentUser?.id != userId) {
      return;
    }
    _quickLinksLoadedForUser = userId;
    setState(() {
      _quickLinks = links;
    });
    await _persistQuickLinks(prefs, scope, links);
  }

  List<CustomQuickLink> _defaultQuickLinks() => [
        CustomQuickLink(
          id: 'system_mulk',
          surahNumber: 67,
          label: 'ก่อนนอน',
          isLocked: true,
        ),
        CustomQuickLink(
          id: 'system_kahf',
          surahNumber: 18,
          label: 'วันศุกร์',
          isLocked: true,
        ),
        CustomQuickLink(
          id: 'system_yasin',
          surahNumber: 36,
          label: 'หัวใจกุรอาน',
          isLocked: true,
        ),
        CustomQuickLink(
          id: 'system_naba',
          surahNumber: 78,
          label: 'ญุซอ์ 30',
          isLocked: true,
        ),
        CustomQuickLink(
          id: 'system_rahman',
          surahNumber: 55,
          label: 'ความเมตตา',
          isLocked: true,
        ),
        CustomQuickLink(
          id: 'system_yusuf',
          surahNumber: 12,
          label: 'นบียูซุฟ',
          isLocked: true,
        ),
        CustomQuickLink(
          id: 'system_naml',
          surahNumber: 27,
          label: 'ปัญญานบี',
          isLocked: true,
        ),
        CustomQuickLink(
          id: 'system_waqiah',
          surahNumber: 56,
          label: 'ริสกี',
          isLocked: true,
        ),
        CustomQuickLink(
          id: 'system_baqarah',
          surahNumber: 2,
          label: 'กุรซีย์',
          isLocked: true,
        ),
      ];

  List<CustomQuickLink> _normalizeQuickLinks(List<CustomQuickLink> links) {
    final byId = <String, CustomQuickLink>{};
    final lockedSystemIds = <String>{};
    for (final link in _defaultQuickLinks()) {
      byId[link.id] = link;
      lockedSystemIds.add(link.id);
    }
    for (final link in links) {
      if (lockedSystemIds.contains(link.id)) continue;
      byId[link.id] = link;
    }
    return byId.values.toList();
  }

  Future<void> _saveQuickLinks({bool syncRemote = true}) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    // The account changed while a reload is in flight; never write one
    // account's list into another scope.
    if (_quickLinksLoadedForUser != null &&
        userId != _quickLinksLoadedForUser) {
      return;
    }
    _quickLinksRevision++;
    _quickLinks = _normalizeQuickLinks(_quickLinks);
    final prefs = await SharedPreferences.getInstance();
    final scope = _quickLinksScope(userId);
    await _persistQuickLinks(prefs, scope, _quickLinks);

    if (!syncRemote || userId == null) return;
    final merged = await _syncQuickLinksWithSupabase(
      userId,
      scope,
      _quickLinks,
    );
    if (!mounted ||
        Supabase.instance.client.auth.currentUser?.id != userId) {
      return;
    }
    setState(() {
      _quickLinks = merged;
    });
    await _persistQuickLinks(prefs, scope, merged);
  }

  Future<List<CustomQuickLink>> _syncQuickLinksWithSupabase(
    String userId,
    String scope,
    List<CustomQuickLink> localLinks,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final deletedIds = await _loadDeletedQuickLinkIds(prefs, scope);
    final lastSyncedAt = DateTime.tryParse(
      prefs.getString(_quickLinksSyncedAtKey(scope)) ?? '',
    );

    try {
      final client = Supabase.instance.client;
      final remoteRows = await client
          .from('custom_quick_links')
          .select('id, surah_number, label, sort_order, created_at, updated_at')
          .eq('user_id', userId)
          .order('sort_order');
      final remoteLinks = List<Map<String, dynamic>>.from(
        remoteRows,
      ).map(CustomQuickLink.fromSupabase).toList();
      final remoteById = <String, CustomQuickLink>{
        for (final link in remoteLinks) link.id: link,
      };

      // Finish deletions that were queued while offline or failed earlier.
      for (final id in deletedIds.toList()) {
        if (!remoteById.containsKey(id)) continue;
        try {
          await client
              .from('custom_quick_links')
              .delete()
              .eq('user_id', userId)
              .eq('id', id);
          deletedIds.remove(id);
        } catch (e) {
          debugPrint('Error deleting quick link $id from Supabase: $e');
        }
      }
      await _saveDeletedQuickLinkIds(prefs, scope, deletedIds);

      final mergedById = <String, CustomQuickLink>{};
      for (final link in _normalizeQuickLinks(localLinks)) {
        if (deletedIds.contains(link.id)) continue;
        if (link.isLocked) {
          mergedById[link.id] = link;
          continue;
        }
        final remote = remoteById[link.id];
        // Already synced before but missing on the server means it was deleted
        // from another device — don't resurrect it.
        if (remote == null &&
            lastSyncedAt != null &&
            !link.updatedAt.isAfter(lastSyncedAt)) {
          continue;
        }
        mergedById[link.id] = link;
      }
      for (final remote in remoteLinks) {
        if (deletedIds.contains(remote.id)) continue;
        final local = mergedById[remote.id];
        if (local == null || remote.updatedAt.isAfter(local.updatedAt)) {
          mergedById[remote.id] = remote;
        }
      }

      final merged = mergedById.values.toList();
      final customLinks = merged.where((link) => !link.isLocked).toList();
      var pushedAll = true;
      for (var index = 0; index < customLinks.length; index++) {
        final link = customLinks[index];
        try {
          await client.from('custom_quick_links').upsert({
            'id': link.id,
            'user_id': userId,
            'surah_number': link.surahNumber,
            'label': link.label,
            'sort_order': index,
            'created_at': link.createdAt.toUtc().toIso8601String(),
            'updated_at': link.updatedAt.toUtc().toIso8601String(),
          }, onConflict: 'id,user_id');
        } catch (e) {
          pushedAll = false;
          debugPrint('Error saving quick link ${link.id} to Supabase: $e');
        }
      }
      if (pushedAll) {
        await prefs.setString(
          _quickLinksSyncedAtKey(scope),
          DateTime.now().toUtc().toIso8601String(),
        );
      }

      return merged;
    } catch (e) {
      debugPrint('Error syncing quick links with Supabase: $e');
      return _normalizeQuickLinks(localLinks);
    }
  }

  Future<void> _deleteQuickLink(CustomQuickLink link) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    // Account changed while a reload is in flight — let the reload win.
    if (_quickLinksLoadedForUser != null &&
        userId != _quickLinksLoadedForUser) {
      return;
    }
    _quickLinksRevision++;
    setState(() => _quickLinks.removeWhere((item) => item.id == link.id));

    final prefs = await SharedPreferences.getInstance();
    final scope = _quickLinksScope(userId);
    await _persistQuickLinks(prefs, scope, _quickLinks);

    if (userId == null) return;

    final deletedIds = await _loadDeletedQuickLinkIds(prefs, scope);
    deletedIds.add(link.id);
    await _saveDeletedQuickLinkIds(prefs, scope, deletedIds);

    try {
      await Supabase.instance.client
          .from('custom_quick_links')
          .delete()
          .eq('user_id', userId)
          .eq('id', link.id);
      deletedIds.remove(link.id);
      await _saveDeletedQuickLinkIds(prefs, scope, deletedIds);
    } catch (e) {
      debugPrint('Error deleting quick link from Supabase: $e');
    }
  }

  @override
  void dispose() {
    _quickLinkAuthSubscription?.cancel();
    super.dispose();
  }

  void _handleBackNavigation() {
    if (_navIndex != 0) {
      setState(() => _navIndex = 0);
      return;
    }
    SystemNavigator.pop();
  }

  void _navigateToReading(
    BuildContext context,
    String surahId, {
    String? verseId,
    int? verseIndex,
    bool saveToFreeReadOnly = false,
    String? goalProfileId,
  }) {
    final localReading = context.read<LocalReadingProvider>();
    final String? fallbackProfileId;
    if (saveToFreeReadOnly) {
      fallbackProfileId = null;
    } else if (goalProfileId != null) {
      fallbackProfileId = goalProfileId;
    } else {
      final active = localReading.activeProfile;
      fallbackProfileId =
          (active != null && !isFreeReadProfile(active)) ? active.id : null;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReadingScreen(
          repository: widget.repository,
          initialSurah: surahId,
          initialVerseId: verseId,
          initialVerseIndex:
              verseIndex ?? ((int.tryParse(verseId ?? '1') ?? 1) - 1),
          saveToFreeReadOnly: saveToFreeReadOnly,
          goalProfileId: goalProfileId,
        ),
      ),
    ).then(
      (result) => _refreshHomeAfterReader(
        readingResult: result,
        saveToFreeReadOnly: saveToFreeReadOnly,
        fallbackProfileId: fallbackProfileId,
      ),
    );
  }

  Future<void> _navigateToMushafFreeReadPage(
    int pageNumber, {
    int? mushafId,
    int? surahContext,
    String? highlightedVerseKey,
  }) async {
    final mushafProvider = context.read<MushafReadingProvider>();
    final targetMushafId = mushafId ?? 1;
    final profile = mushafProvider.freeReadProfileForMushaf(targetMushafId);
    unawaited(mushafProvider.openFreeRead(targetMushafId));
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MushafReaderScreen(
          quranRepository: widget.repository,
          foundationRepository: _foundationRepository,
          profileId: profile.id,
          initialPage: pageNumber,
          initialHighlightVerseKey: highlightedVerseKey,
          initialSurahContext: surahContext,
        ),
      ),
    ).then((_) => _refreshHomeAfterReader());
  }

  Future<void> _navigateToMushafProfile(
    MushafProfile profile, {
    int? initialPage,
  }) async {
    final mushafProvider = context.read<MushafReadingProvider>();
    await mushafProvider.setActiveProfile(profile.id);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MushafReaderScreen(
          quranRepository: widget.repository,
          foundationRepository: _foundationRepository,
          profileId: profile.id,
          initialPage: initialPage,
        ),
      ),
    ).then((_) => _refreshHomeAfterReader());
  }

  Future<void> _refreshHomeAfterReader({
    Object? readingResult,
    bool saveToFreeReadOnly = false,
    String? fallbackProfileId,
  }) async {
    if (readingResult is Map) {
      final surahId = readingResult['surahId']?.toString();
      final verseId = readingResult['verseId']?.toString();
      if (surahId != null && verseId != null) {
        final localReading = context.read<LocalReadingProvider>();
        final resultProfileId = readingResult['profileId']?.toString();

        LocalReadingProfile? profile = resultProfileId != null
            ? localReading.profileById(resultProfileId)
            : null;

        if ((profile == null || isFreeReadProfile(profile)) &&
            fallbackProfileId != null &&
            !saveToFreeReadOnly) {
          final fallback = localReading.profileById(fallbackProfileId);
          if (fallback != null &&
              !isFreeReadProfile(fallback) &&
              !fallback.isArchived) {
            profile = fallback;
          }
        }

        if (profile != null && isShortcutProfile(profile)) {
          profile = null;
        }

        profile ??= saveToFreeReadOnly
            ? localReading.freeReadProfile
            : localReading.activeProfile;

        await localReading.addRecentReading(
          verse: toVerseRef(surahId, verseId),
          profileId: profile?.id,
        );
      }
    }
    if (!mounted) return;
    setState(() {});
  }

  DateTime _normalizeDate(DateTime dt) {
    return sanitizeSyncTimestamp(dt).normalized.toLocal();
  }

  ({VerseRef verse, String? profileId, DateTime at})? _latestVerseLastRead(
    LocalReadingProvider provider,
  ) {
    ({VerseRef verse, String? profileId, DateTime at})? latest;

    for (final reading in provider.recentReadings) {
      // Keep archived-goal history visible as a recent item. Resolution below
      // treats it as Free Read, so it never reactivates the archived goal.
      final normalizedReadAt = _normalizeDate(reading.readAt);
      if (latest == null || normalizedReadAt.isAfter(latest.at)) {
        latest = (
          verse: reading.verse,
          profileId: reading.profileId,
          at: normalizedReadAt,
        );
      }
    }

    final profiles = <LocalReadingProfile>[
      ...provider.activeProfiles,
      if (provider.freeReadProfile != null) provider.freeReadProfile!,
    ];
    final seen = <String>{};
    for (final profile in profiles) {
      if (!seen.add(profile.id) || profile.isArchived) continue;
      if (profile.updatedAt == profile.createdAt &&
          profile.lastViewed == profile.start) {
        continue;
      }
      final viewed = profile.lastViewed;
      final normalizedUpdatedAt = _normalizeDate(profile.updatedAt);
      if (latest == null || normalizedUpdatedAt.isAfter(latest.at)) {
        latest = (
          verse: viewed,
          profileId: profile.id,
          at: normalizedUpdatedAt,
        );
      }
    }

    return latest;
  }

  ({int pageNumber, String? profileId, DateTime at})? _latestMushafLastRead(
    MushafReadingProvider provider,
  ) {
    ({int pageNumber, String? profileId, DateTime at})? latest;

    for (final reading in provider.recentReadings) {
      final normalizedUpdatedAt = _normalizeDate(reading.updatedAt);
      if (latest == null || normalizedUpdatedAt.isAfter(latest.at)) {
        latest = (
          pageNumber: reading.pageNumber,
          profileId: reading.profileId,
          at: normalizedUpdatedAt,
        );
      }
    }

    for (final profile in provider.profiles) {
      if (profile.isArchived) continue;
      if (profile.updatedAt == profile.createdAt &&
          profile.lastViewedPage == profile.startPage) {
        continue;
      }
      final normalizedUpdatedAt = _normalizeDate(profile.updatedAt);
      if (latest == null || normalizedUpdatedAt.isAfter(latest.at)) {
        latest = (
          pageNumber: profile.lastViewedPage,
          profileId: profile.id,
          at: normalizedUpdatedAt,
        );
      }
    }

    return latest;
  }

  Future<void> _openLastRead(
    LocalReadingProvider localReading,
    MushafReadingProvider mushafReading,
  ) async {
    final verseRecent = _latestVerseLastRead(localReading);
    final mushafRecent = _latestMushafLastRead(mushafReading);
    final shouldOpenMushaf =
        mushafRecent != null &&
        (verseRecent == null || mushafRecent.at.isAfter(verseRecent.at));

    if (shouldOpenMushaf) {
      final page = mushafRecent.pageNumber;
      final resolved = mushafRecent.profileId != null
          ? mushafReading.profileById(mushafRecent.profileId!)
          : null;
      final isInside = resolved != null &&
          page >= resolved.startPage &&
          page <= resolved.targetPage;
      final profile =
          resolved != null && !resolved.isArchived && isInside ? resolved : null;
      final isGoal = profile != null && !profile.isFreeRead;
      if (isGoal) {
        await _navigateToMushafProfile(profile, initialPage: page);
      } else {
        await _navigateToMushafFreeReadPage(page);
      }
      return;
    }

    if (verseRecent != null) {
      final resolved = verseRecent.profileId == null
          ? null
          : localReading.profileById(verseRecent.profileId!);
      // Never reactivate an archived goal through the Continue card.
      final isInside = resolved != null &&
          localReading.isVerseInsideProfile(
            resolved,
            verseRecent.verse.surahId,
            verseRecent.verse.verseId,
          );
      final profile =
          resolved != null && !resolved.isArchived && isInside ? resolved : null;
      final isGoal = profile != null && !isFreeReadProfile(profile);
      if (isGoal) {
        await localReading.setActiveProfile(profile.id);
      } else {
        final freeRead = localReading.freeReadProfile;
        if (freeRead != null) {
          await localReading.setActiveProfile(freeRead.id);
        }
      }
      if (!mounted) return;
      _navigateToReading(
        context,
        verseRecent.verse.surahId,
        verseId: verseRecent.verse.verseId,
        saveToFreeReadOnly: !isGoal,
        goalProfileId: isGoal ? profile.id : null,
      );
      return;
    }

    final freeRead = localReading.freeReadProfile;
    if (freeRead != null) {
      await localReading.setActiveProfile(freeRead.id);
    }
    if (!mounted) return;
    _navigateToReading(context, '1', verseId: '1', saveToFreeReadOnly: true);
  }

  Future<String?> _showReadingModeSheet({
    required int pageNumber,
    String? title,
  }) async {
    final colorScheme = Theme.of(context).colorScheme;
    final isThai = context.read<SettingsProvider>().languageCode == 'th';

    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radius),
        ),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title != null && title.isNotEmpty
                    ? '$title · ${context.tr('select_reading_mode')}'
                    : context.tr('select_reading_mode'),
                style: GoogleFonts.notoSansThai(
                  color: colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _ModeSelectionCard(
                      icon: Icons.chrome_reader_mode_outlined,
                      title: context.tr('verse_by_verse'),
                      subtitle: context.tr('translation_audio'),
                      onTap: () => Navigator.pop(sheetContext, 'readspace'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ModeSelectionCard(
                      icon: Icons.import_contacts,
                      title: context.tr('mushaf_page'),
                      subtitle: '${context.tr('page')} $pageNumber',
                      onTap: () => Navigator.pop(sheetContext, 'mushaf'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ModeSelectionCard(
                      icon: Icons.psychology_outlined,
                      title: isThai ? 'ท่องจำฮิฟซ์' : 'Hifz Memorize',
                      subtitle: isThai ? 'โหมดฝึกท่องจำ' : 'Memorization Mode',
                      onTap: () => Navigator.pop(sheetContext, 'hifz'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _chooseBrowseDestination(
    String surahId,
    String verseId, {
    String? goalProfileId,
  }) async {
    final surah = int.tryParse(surahId) ?? 1;
    final verse = int.tryParse(verseId) ?? 1;
    final pageNumber = getMedinaMushafPageNumber(surah, verse);

    final destination = await _showReadingModeSheet(pageNumber: pageNumber);
    if (!mounted || destination == null) return;
    if (destination == 'mushaf') {
      await _navigateToMushafFreeReadPage(
        pageNumber,
        surahContext: surah,
        highlightedVerseKey: '$surah:$verse',
      );
      return;
    }
    if (destination == 'hifz') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HifzWizardSetupScreen(
            quranRepository: widget.repository,
            foundationRepository: _foundationRepository,
            initialSurah: surah,
            initialStartVerse: verse,
            initialStep: 0,
          ),
        ),
      );
      return;
    }
    _navigateToReading(
      context,
      surahId,
      verseId: verseId,
      saveToFreeReadOnly: goalProfileId == null,
      goalProfileId: goalProfileId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final settings = context.watch<SettingsProvider>();
    final appColors = settings.getAppColors();
    final readingProvider = context.watch<LocalReadingProvider>();
    final mushafReadingProvider = context.watch<MushafReadingProvider>();
    final statsProvider = context.watch<StatsProvider>();
    final isThai = settings.languageCode == 'th';

    if (!_isInit) {
      return Scaffold(
        backgroundColor: appColors.background,
        body: SafeArea(
          child: Center(
            child: _initFailed
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 44,
                          color: colorScheme.error,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isThai
                              ? 'ไม่สามารถโหลดข้อมูลอัลกุรอานได้'
                              : 'Unable to load Quran data',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.notoSansThai(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () {
                            setState(() => _initFailed = false);
                            _initApp();
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: Text(isThai ? 'ลองใหม่' : 'Retry'),
                        ),
                      ],
                    ),
                  )
                : CircularProgressIndicator(color: colorScheme.primary),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBackNavigation();
        }
      },
      child: Scaffold(
        backgroundColor: appColors.background,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: appColors.background,
          titleSpacing: 16,
          title: _buildAppBarTitleForTab(_navIndex, isThai, appColors),
          actions: [
            IconButton(
              icon: Icon(Icons.search_rounded, color: appColors.primary),
              tooltip: isThai ? 'ค้นหาอัลกุรอาน' : 'Search Quran',
              onPressed: () {
                setState(() => _navIndex = 1);
              },
            ),
            IconButton(
              icon: Icon(
                settings.isDarkMode
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                color: appColors.primary,
              ),
              tooltip: isThai
                  ? (settings.isDarkMode
                      ? 'เปลี่ยนเป็นโหมดสว่าง'
                      : 'เปลี่ยนเป็นโหมดมืด')
                  : (settings.isDarkMode
                      ? 'Switch to Light Mode'
                      : 'Switch to Dark Mode'),
              onPressed: () => settings.toggleDarkMode(!settings.isDarkMode),
            ),
            const SizedBox(width: 6),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          height: 66,
          selectedIndex: _navIndex,
          onDestinationSelected: (index) {
            setState(() => _navIndex = index);
          },
          elevation: 0,
          backgroundColor: appColors.background,
          indicatorColor: colorScheme.primaryContainer.withValues(alpha: 0.7),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              label: isThai ? 'หน้าแรก' : 'Home',
            ),
            NavigationDestination(
              icon: const Icon(Icons.menu_book_outlined),
              selectedIcon: const Icon(Icons.menu_book_rounded),
              label: isThai ? 'สารบัญ' : 'Surah',
            ),
            NavigationDestination(
              icon: const Icon(Icons.bookmark_border_rounded),
              selectedIcon: const Icon(Icons.bookmark_rounded),
              label: isThai ? 'ที่คั่น & บันทึก' : 'Bookmarks',
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline_rounded),
              selectedIcon: const Icon(Icons.person_rounded),
              label: isThai ? 'โปรไฟล์' : 'Profile',
            ),
          ],
        ),
        body: IndexedStack(
          index: _navIndex,
          children: [
            // ── Tab 0: Home (Calm Showcase Display) ────────────────────────
            _buildCleanHomeShowcase(
              colorScheme: colorScheme,
              textTheme: textTheme,
              settings: settings,
              readingProvider: readingProvider,
              mushafReadingProvider: mushafReadingProvider,
              statsProvider: statsProvider,
              isThai: isThai,
            ),

            // ── Tab 1: Surah Library & Search ──────────────────────────────
            BrowseScreen(
              repository: widget.repository,
              foundationRepository: _foundationRepository,
              colors: settings.getAppColors(),
              onOpen: _chooseBrowseDestination,
              onOpenMeaning: (surahId, verseId) {
                _navigateToReading(
                  context,
                  surahId,
                  verseId: verseId,
                  saveToFreeReadOnly: true,
                );
              },
              onOpenPage: _navigateToMushafFreeReadPage,
            ),

            // ── Tab 2: Bookmarks, Recent Reads & Notes ─────────────────────
            BookmarksScreen(
              repository: widget.repository,
            ),

            // ── Tab 3: Unified Settings & Profile ──────────────────────────
            SettingsScreen(
              repository: widget.repository,
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 0: CLEAN HOME SHOWCASE ("Display of This and That")
  // ===========================================================================
  Widget _buildCleanHomeShowcase({
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required SettingsProvider settings,
    required LocalReadingProvider readingProvider,
    required MushafReadingProvider mushafReadingProvider,
    required StatsProvider statsProvider,
    required bool isThai,
  }) {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadCommunityPreview();
        await _triggerAutoSync();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
        children: [
          // 1. Greeting + 7-Day Reading Streak Card
          _buildGreetingAndStreakCard(
            colorScheme,
            textTheme,
            statsProvider,
            isThai,
          ),
          const SizedBox(height: 16),

          // 2. Unified "Continue Reading" Hero Card
          _buildUnifiedContinueHeroCard(
            colorScheme,
            textTheme,
            readingProvider,
            mushafReadingProvider,
            isThai,
          ),
          const SizedBox(height: 20),

          // 3. 4-Box Windows Phone Metro Grid (Meaning / Mushaf / Hifz / Notes)
          _buildMetroHubGrid(
            colorScheme,
            textTheme,
            readingProvider,
            mushafReadingProvider,
            isThai,
          ),
          const SizedBox(height: 20),

          // 4. Active Goals Snapshot (Read-Only Display)
          _buildActiveGoalsSnapshot(
            colorScheme,
            textTheme,
            readingProvider,
            mushafReadingProvider,
            isThai,
          ),
          const SizedBox(height: 20),

          // 5. Quick Access / Favourite Surahs Row
          _buildQuickAccessSection(colorScheme, textTheme, isThai),
          const SizedBox(height: 20),

          // 6. Community Tadabbur Reflections Preview
          _buildCommunityReflectionsSection(colorScheme, textTheme, isThai),
          const SizedBox(height: 10),

          // 8. Brand Lockup Footer
          _buildQuranThFooter(colorScheme, textTheme, isThai),
        ],
      ),
    );
  }

  // ── Brand Lockup Footer ─────────────────────────────────────────────────────
  Widget _buildQuranThFooter(
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isThai,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Center(
        child: InkWell(
          onTap: () async {
            final uri = Uri.parse('https://quran-th.com');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_stories_outlined,
                      size: 14,
                      color: colorScheme.primary.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Powered by quran-th.com',
                      style: GoogleFonts.notoSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 11,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isThai
                      ? 'แพลตฟอร์มการอ่านและศึกษาอัลกุรอานแปลไทย'
                      : 'Modern Thai Quran Reading & Study Platform',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 10.5,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarTitleForTab(int tabIndex, bool isThai, AppThemeColors colors) {
    if (tabIndex == 0) {
      return Text(
        isThai ? 'อัสสลามุอะลัยกุม' : 'Assalamu Alaikum',
        style: GoogleFonts.notoSansThai(
          fontSize: 21,
          fontWeight: FontWeight.w900,
          color: colors.primary,
          letterSpacing: -0.3,
        ),
      );
    } else if (tabIndex == 1) {
      return Text(
        isThai ? 'สารบัญอัลกุรอาน' : 'Quran Index',
        style: GoogleFonts.notoSansThai(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: colors.primary,
          letterSpacing: -0.3,
        ),
      );
    } else if (tabIndex == 2) {
      return Text(
        isThai ? 'ที่คั่นหน้า & บันทึก' : 'Bookmarks & Notes',
        style: GoogleFonts.notoSansThai(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: colors.primary,
          letterSpacing: -0.3,
        ),
      );
    } else {
      return Text(
        isThai ? 'โปรไฟล์ & การตั้งค่า' : 'Profile & Settings',
        style: GoogleFonts.notoSansThai(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: colors.primary,
          letterSpacing: -0.3,
        ),
      );
    }
  }

  // ── 1. Greeting & 7-Day Reading Streak Strip ────────────────────────────────
  Widget _buildGreetingAndStreakCard(
    ColorScheme colorScheme,
    TextTheme textTheme,
    StatsProvider statsProvider,
    bool isThai,
  ) {
    final supabaseProv = context.watch<SupabaseProvider>();
    final now = DateTime.now();
    final daysList = List.generate(
      7,
      (index) => now.subtract(Duration(days: 6 - index)),
    );
    final dayLabels = [
      context.tr('weekday_mon_short'),
      context.tr('weekday_tue_short'),
      context.tr('weekday_wed_short'),
      context.tr('weekday_thu_short'),
      context.tr('weekday_fri_short'),
      context.tr('weekday_sat_short'),
      context.tr('weekday_sun_short'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  supabaseProv.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.notoSansThai(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_fire_department_rounded,
                      size: 15,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isThai
                          ? 'ต่อเนื่อง ${statsProvider.streakCount} วัน'
                          : '${statsProvider.streakCount}d Streak',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final date = daysList[index];
              final isToday = index == 6;
              final isRead = statsProvider.hasReadOn(date);
              final dayLabel = dayLabels[date.weekday - 1];

              final Color activeColor = isRead
                  ? const Color(0xFF15803D)
                  : (isToday
                      ? colorScheme.primary
                      : colorScheme.outlineVariant);

              return Column(
                children: [
                  Text(
                    dayLabel,
                    style: GoogleFonts.notoSansThai(
                      fontSize: 10.5,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
                      color: isToday
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isRead
                          ? const Color(0xFF15803D).withValues(alpha: 0.14)
                          : (isToday
                              ? colorScheme.primary.withValues(alpha: 0.1)
                              : Colors.transparent),
                      border: Border.all(
                        color: activeColor,
                        width: isToday ? 1.8 : 1.0,
                      ),
                    ),
                    child: isRead
                        ? const Icon(
                            Icons.check_rounded,
                            size: 15,
                            color: Color(0xFF15803D),
                          )
                        : (isToday
                            ? Icon(
                                Icons.circle,
                                size: 6,
                                color: colorScheme.primary,
                              )
                            : null),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── 2. Unified "Continue Reading" Hero Card ─────────────────────────────────
  Widget _buildUnifiedContinueHeroCard(
    ColorScheme colorScheme,
    TextTheme textTheme,
    LocalReadingProvider localReading,
    MushafReadingProvider mushafReading,
    bool isThai,
  ) {
    final verseRecent = _latestVerseLastRead(localReading);
    final mushafRecent = _latestMushafLastRead(mushafReading);
    final hasHistory = verseRecent != null || mushafRecent != null;
    final showMushaf =
        mushafRecent != null &&
        (verseRecent == null || mushafRecent.at.isAfter(verseRecent.at));

    final now = DateTime.now();
    final String recommendationPill;
    final int recommendationSurah;
    if (now.weekday == DateTime.friday) {
      recommendationPill =
          isThai ? 'วันศุกร์ · ซูเราะฮฺอัล-กะฮฺฟิ' : 'Friday · Al-Kahf';
      recommendationSurah = 18;
    } else if (now.hour >= 20 || now.hour < 4) {
      recommendationPill =
          isThai ? 'ยามค่ำคืน · ซูเราะฮฺอัล-มุลก์' : 'Night · Al-Mulk';
      recommendationSurah = 67;
    } else if (now.hour >= 4 && now.hour < 11) {
      recommendationPill =
          isThai ? 'ยามเช้า · ซูเราะฮฺยาซีน' : 'Morning · Ya-Sin';
      recommendationSurah = 36;
    } else if (now.hour >= 11 && now.hour < 16) {
      recommendationPill =
          isThai ? 'ยามบ่าย · ซูเราะฮฺอัน-นะบะอ์' : 'Afternoon · An-Naba';
      recommendationSurah = 78;
    } else {
      recommendationPill =
          isThai ? 'ยามเย็น · ซูเราะฮฺอัล-วากิอะฮฺ' : 'Evening · Al-Waqi\'ah';
      recommendationSurah = 56;
    }

    final String modeBadge;
    final String mainTitle;
    final String subDetail;

    if (showMushaf) {
      final profile = mushafReading.profileById(mushafRecent.profileId);
      modeBadge = isThai
          ? 'อ่านล่าสุด • ฉบับมุศหัฟ'
          : 'Last Read • Madinah Mushaf';
      mainTitle = isThai
          ? 'หน้า ${mushafRecent.pageNumber} (จาก 604)'
          : 'Page ${mushafRecent.pageNumber} of 604';
      subDetail = profile != null && !profile.isFreeRead
          ? '${isThai ? 'เป้าหมาย' : 'Goal'}: ${profile.name}'
          : (isThai ? 'โหมดอ่านอิสระ (Free Read)' : 'Free Read Session');
    } else if (verseRecent != null) {
      final sId = verseRecent.verse.surahId;
      final vId = verseRecent.verse.verseId;
      final surahName = surahDisplayName(sId, isThai: isThai);
      final profile = verseRecent.profileId != null
          ? localReading.profileById(verseRecent.profileId!)
          : null;
      modeBadge = isThai
          ? 'อ่านล่าสุด • พร้อมความหมาย'
          : 'Last Read • Meaning Mode';
      mainTitle = isThai
          ? '$surahName • อายะฮฺที่ $vId'
          : '$surahName • Ayah $vId';
      subDetail = profile != null && !isFreeReadProfile(profile)
          ? '${isThai ? 'เป้าหมาย' : 'Goal'}: ${profile.name}'
          : (isThai ? 'โหมดอ่านอิสระ (ซูเราะฮฺที่ $sId:$vId)' : 'Surah $sId:$vId');
    } else {
      final firstSurah = surahDisplayName('1', isThai: isThai);
      modeBadge = isThai ? 'เริ่มต้นอ่านอัลกุรอาน' : 'Start Reading Quran';
      mainTitle = isThai ? '$firstSurah • อายะฮฺที่ 1' : '$firstSurah • Ayah 1';
      subDetail = isThai
          ? '7 อายะฮฺ · หน้าที่ 1 · พร้อมคำแปลและตัฟซีรย่อ'
          : '7 Ayahs · Page 1 · With translation & tafsir';
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0E5A4A),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
        ),
      ),
      child: Stack(
        children: [
          // Subtle Arabic calligraphy watermark
          Positioned(
            right: -6,
            bottom: -14,
            child: IgnorePointer(
              child: Text(
                'ٱقْرَأْ',
                style: TextStyle(
                  fontFamily: 'UthmanicHafs',
                  fontSize: 96,
                  color: const Color(0xFFD4A853).withValues(alpha: 0.1),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4A853)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFD4A853)
                                    .withValues(alpha: 0.45),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  showMushaf
                                      ? Icons.import_contacts_rounded
                                      : Icons.menu_book_rounded,
                                  size: 13,
                                  color: const Color(0xFFF3D28A),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    modeBadge,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.notoSansThai(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFF3D28A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () => _navigateToReading(
                              context,
                              recommendationSurah.toString(),
                              verseId: '1',
                              saveToFreeReadOnly: true,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 11,
                                    color: Color(0xFFF3D28A),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      recommendationPill,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.notoSansThai(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasHistory) ...[
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BookmarksScreen(
                                repository: widget.repository,
                                initialTab: 0,
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: Text(
                            isThai ? 'ประวัติ →' : 'History →',
                            style: GoogleFonts.notoSansThai(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  mainTitle,
                  style: GoogleFonts.notoSansThai(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subDetail,
                  style: GoogleFonts.notoSansThai(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 18),
                if (!hasHistory) ...[
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final meaningButton = FilledButton.icon(
                        onPressed: () => _navigateToReading(
                          context,
                          '1',
                          verseId: '1',
                          saveToFreeReadOnly: true,
                        ),
                        icon: const Icon(Icons.menu_book_rounded, size: 18),
                        label: Text(
                          isThai ? 'อ่านแบบความหมาย' : 'Read with Meaning',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.notoSansThai(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0E5A4A),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                          ),
                        ),
                      );
                      final mushafButton = OutlinedButton.icon(
                        onPressed: () => _navigateToMushafFreeReadPage(1),
                        icon: const Icon(
                          Icons.import_contacts_rounded,
                          size: 18,
                        ),
                        label: Text(
                          isThai ? 'เปิดมุศหัฟ' : 'Open Mushaf',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.notoSansThai(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.12),
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                          ),
                        ),
                      );
                      if (constraints.maxWidth < 360) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            meaningButton,
                            const SizedBox(height: 8),
                            mushafButton,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: meaningButton),
                          const SizedBox(width: 10),
                          Expanded(child: mushafButton),
                        ],
                      );
                    },
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _openLastRead(localReading, mushafReading),
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      label: Text(
                        isThai
                            ? 'อ่านต่อจากจุดเดิม'
                            : 'Continue Where You Left Off',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSansThai(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFD4A853),
                        foregroundColor: const Color(0xFF1E1608),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: TextButton.icon(
                      onPressed: () {
                        if (showMushaf) {
                          // Cross-switch to meaning reader at the first verse of that page
                          final pageData = getMedinaMushafPageData(mushafRecent.pageNumber);
                          final first = pageData.isNotEmpty ? pageData.first : null;
                          final sId = first?['surah'] ?? 1;
                          final vId = first?['ayah_start'] ?? 1;
                          _navigateToReading(
                            context,
                            sId.toString(),
                            verseId: vId.toString(),
                            saveToFreeReadOnly: true,
                          );
                        } else if (verseRecent != null) {
                          // Cross-switch to mushaf reader at the page of this verse
                          final sId = int.tryParse(verseRecent.verse.surahId) ?? 1;
                          final vId = int.tryParse(verseRecent.verse.verseId) ?? 1;
                          final page = getMedinaMushafPageNumber(sId, vId);
                          _navigateToMushafFreeReadPage(page);
                        }
                      },
                      icon: Icon(
                        showMushaf
                            ? Icons.menu_book_rounded
                            : Icons.import_contacts_rounded,
                        size: 14,
                        color: Colors.white70,
                      ),
                      label: Text(
                        showMushaf
                            ? (isThai
                                ? 'สลับไปอ่านฉบับความหมาย'
                                : 'Switch to Meaning Mode')
                            : (isThai
                                ? 'สลับไปเปิดหน้ามุศหัฟ'
                                : 'Switch to Madinah Mushaf'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSansThai(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. Windows Phone Metro 4-Box Hub Grid ──────────────────────────────────
  Widget _buildMetroHubGrid(
    ColorScheme colorScheme,
    TextTheme textTheme,
    LocalReadingProvider readingProvider,
    MushafReadingProvider mushafReadingProvider,
    bool isThai,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Editorial color palette for the 4 tiles
    final meaningColor =
        isDark ? const Color(0xFF0D483B) : const Color(0xFF0E5A4A);
    final mushafColor =
        isDark ? const Color(0xFF6B4D21) : const Color(0xFF8A6530);
    final hifzColor =
        isDark ? const Color(0xFF1E4E38) : const Color(0xFF2D6A4F);
    final recentColor =
        isDark ? const Color(0xFF1F3A44) : const Color(0xFF264653);

    // ── Meaning Reader state ──
    final verseRecent = _latestVerseLastRead(readingProvider);
    final LocalReadingProfile? meaningProfile;
    final bool isMeaningGoal;
    final String meaningSubtitle;
    final String? meaningSourceLabel;
    final String meaningBadge;
    final Color meaningBadgeBg;
    final Color meaningBadgeFg;
    final Border? meaningBadgeBorder;

    if (verseRecent != null) {
      final sId = verseRecent.verse.surahId;
      final vId = verseRecent.verse.verseId;
      final surahName = surahDisplayName(sId, isThai: isThai);
      final resolved = verseRecent.profileId != null
          ? readingProvider.profileById(verseRecent.profileId!)
          : null;
      final isInside = resolved != null &&
          readingProvider.isVerseInsideProfile(resolved, sId, vId);
      meaningProfile =
          resolved != null && !resolved.isArchived && isInside ? resolved : null;
      isMeaningGoal =
          meaningProfile != null && !isFreeReadProfile(meaningProfile);

      meaningSubtitle = '$surahName • ${isThai ? 'อายะฮฺ' : 'Ayah'} $vId';
      if (isMeaningGoal) {
        meaningSourceLabel = isThai
            ? 'เป้าหมาย: ${meaningProfile.name}'
            : 'Goal: ${meaningProfile.name}';
        meaningBadge = isThai ? '🎯 เป้าหมาย' : '🎯 Goal';
        meaningBadgeBg = const Color(0xFFD4A853).withValues(alpha: 0.28);
        meaningBadgeFg = const Color(0xFFFDE68A);
        meaningBadgeBorder = Border.all(
          color: const Color(0xFFD4A853).withValues(alpha: 0.6),
          width: 0.8,
        );
      } else {
        meaningSourceLabel = isThai ? 'โหมดอ่านอิสระ' : 'Free Read';
        meaningBadge = isThai ? 'อ่านอิสระ' : 'Free Read';
        meaningBadgeBg = Colors.white.withValues(alpha: 0.16);
        meaningBadgeFg = Colors.white.withValues(alpha: 0.92);
        meaningBadgeBorder = null;
      }
    } else {
      meaningProfile = null;
      isMeaningGoal = false;
      meaningSubtitle = isThai ? 'แปลไทย & ตัฟซีร' : 'Translation & Tafsir';
      meaningSourceLabel = null;
      meaningBadge = isThai ? 'ความหมาย' : 'Meaning';
      meaningBadgeBg = Colors.black.withValues(alpha: 0.2);
      meaningBadgeFg = Colors.white.withValues(alpha: 0.9);
      meaningBadgeBorder = null;
    }

    // ── Mushaf Reader state ──
    final mushafRecent = _latestMushafLastRead(mushafReadingProvider);
    final MushafProfile? mushafProfile;
    final bool isMushafGoal;
    final String mushafSubtitle;
    final String? mushafSourceLabel;
    final String mushafBadge;
    final Color mushafBadgeBg;
    final Color mushafBadgeFg;
    final Border? mushafBadgeBorder;

    if (mushafRecent != null) {
      final page = mushafRecent.pageNumber;
      final resolved = mushafRecent.profileId != null
          ? mushafReadingProvider.profileById(mushafRecent.profileId!)
          : null;
      final isInside = resolved != null &&
          page >= resolved.startPage &&
          page <= resolved.targetPage;
      mushafProfile =
          resolved != null && !resolved.isArchived && isInside ? resolved : null;
      isMushafGoal = mushafProfile != null && !mushafProfile.isFreeRead;

      mushafSubtitle =
          isThai ? 'หน้า $page (จาก 604)' : 'Page $page of 604';
      if (isMushafGoal) {
        mushafSourceLabel = isThai
            ? 'เป้าหมาย: ${mushafProfile.name}'
            : 'Goal: ${mushafProfile.name}';
        mushafBadge = isThai ? '🎯 เป้าหมาย' : '🎯 Goal';
        mushafBadgeBg = const Color(0xFFD4A853).withValues(alpha: 0.28);
        mushafBadgeFg = const Color(0xFFFDE68A);
        mushafBadgeBorder = Border.all(
          color: const Color(0xFFD4A853).withValues(alpha: 0.6),
          width: 0.8,
        );
      } else {
        mushafSourceLabel = isThai ? 'โหมดอ่านอิสระ' : 'Free Read';
        mushafBadge = isThai ? 'อ่านอิสระ' : 'Free Read';
        mushafBadgeBg = Colors.white.withValues(alpha: 0.16);
        mushafBadgeFg = Colors.white.withValues(alpha: 0.92);
        mushafBadgeBorder = null;
      }
    } else {
      mushafProfile = null;
      isMushafGoal = false;
      mushafSubtitle = isThai ? '15 บรรทัดมาตรฐาน' : '15-Line Standard';
      mushafSourceLabel = null;
      mushafBadge = isThai ? 'มุศหัฟ' : 'Mushaf';
      mushafBadgeBg = Colors.black.withValues(alpha: 0.2);
      mushafBadgeFg = Colors.white.withValues(alpha: 0.9);
      mushafBadgeBorder = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.grid_view_rounded, size: 17, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              isThai ? 'เข้าถึงโหมดหลัก' : 'Study Hubs',
              style: GoogleFonts.notoSansThai(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildMetroTile(
                  backgroundColor: meaningColor,
                  icon: Icons.menu_book_rounded,
                  title: isThai ? 'อ่านฉบับแปล' : 'Meaning Reader',
                  subtitle: meaningSubtitle,
                  sourceLabel: meaningSourceLabel,
                  badgeText: meaningBadge,
                  badgeBackgroundColor: meaningBadgeBg,
                  badgeTextColor: meaningBadgeFg,
                  badgeBorder: meaningBadgeBorder,
                  onTap: () async {
                    if (verseRecent != null) {
                      if (isMeaningGoal && meaningProfile != null) {
                        await readingProvider.setActiveProfile(meaningProfile.id);
                      } else {
                        final freeRead = readingProvider.freeReadProfile;
                        if (freeRead != null) {
                          await readingProvider.setActiveProfile(freeRead.id);
                        }
                      }
                      if (!mounted) return;
                      _navigateToReading(
                        context,
                        verseRecent.verse.surahId,
                        verseId: verseRecent.verse.verseId,
                        saveToFreeReadOnly: !isMeaningGoal,
                        goalProfileId: isMeaningGoal ? meaningProfile?.id : null,
                      );
                    } else {
                      final freeRead = readingProvider.freeReadProfile;
                      if (freeRead != null) {
                        await readingProvider.setActiveProfile(freeRead.id);
                      }
                      if (!mounted) return;
                      _navigateToReading(
                        context,
                        '1',
                        verseId: '1',
                        saveToFreeReadOnly: true,
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetroTile(
                  backgroundColor: mushafColor,
                  icon: Icons.auto_stories_rounded,
                  title: isThai ? 'มุศหัฟมะดีนะฮฺ' : 'Medina Mushaf',
                  subtitle: mushafSubtitle,
                  sourceLabel: mushafSourceLabel,
                  badgeText: mushafBadge,
                  badgeBackgroundColor: mushafBadgeBg,
                  badgeTextColor: mushafBadgeFg,
                  badgeBorder: mushafBadgeBorder,
                  onTap: () async {
                    if (mushafRecent != null) {
                      if (isMushafGoal && mushafProfile != null) {
                        await _navigateToMushafProfile(
                          mushafProfile,
                          initialPage: mushafRecent.pageNumber,
                        );
                      } else {
                        await _navigateToMushafFreeReadPage(
                          mushafRecent.pageNumber,
                        );
                      }
                    } else {
                      await _navigateToMushafFreeReadPage(1);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildMetroTile(
                  backgroundColor: hifzColor,
                  icon: Icons.psychology_rounded,
                  title: isThai ? 'ท่องจำอัลกุรอาน' : 'Hifz Suite',
                  subtitle: isThai ? 'ทดสอบ & ทบทวน' : 'Tilawa & Review',
                  badgeText: isThai ? 'ท่องจำ' : 'Hifz',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HifzLandingScreen(
                          quranRepository: widget.repository,
                          foundationRepository: _foundationRepository,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetroTile(
                  backgroundColor: recentColor,
                  icon: Icons.history_rounded,
                  title: isThai ? 'อ่านล่าสุด' : 'Recent Reads',
                  subtitle: isThai ? 'ประวัติ & หน้าค้าง' : 'History & Resumes',
                  badgeText: isThai ? 'อ่านล่าสุด' : 'Recent',
                  onTap: () {
                    setState(() => _navIndex = 2);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetroTile({
    required Color backgroundColor,
    required IconData icon,
    required String title,
    required String subtitle,
    required String badgeText,
    required VoidCallback onTap,
    String? sourceLabel,
    Color? badgeBackgroundColor,
    Color? badgeTextColor,
    Border? badgeBorder,
  }) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Container(
          constraints: const BoxConstraints(minHeight: 114),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(5.5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      size: 17,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBackgroundColor ??
                            Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: badgeBorder,
                      ),
                      child: Text(
                        badgeText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSansThai(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: badgeTextColor ??
                              Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSansThai(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSansThai(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  if (sourceLabel != null) ...[
                    const SizedBox(height: 1.5),
                    Text(
                      sourceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSansThai(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: sourceLabel.startsWith('เป้าหมาย') ||
                                sourceLabel.startsWith('Goal')
                            ? const Color(0xFFFDE68A)
                            : Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 4. Active Goals Snapshot (Read-Only Display) ────────────────────────────
  Widget _buildActiveGoalsSnapshot(
    ColorScheme colorScheme,
    TextTheme textTheme,
    LocalReadingProvider localReading,
    MushafReadingProvider mushafReading,
    bool isThai,
  ) {
    final meaningGoals = localReading.profiles
        .where((p) => !isFreeReadProfile(p) && !p.isArchived)
        .toList();
    final mushafGoals = mushafReading.activeCustomProfiles;
    final totalActive = meaningGoals.length + mushafGoals.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.flag_rounded, size: 18, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              isThai ? 'เป้าหมายที่กำลังอ่าน' : 'Active Reading Goals',
              style: GoogleFonts.notoSansThai(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _navigateToGoalsScreen(context),
              icon: Text(
                isThai ? 'จัดการเป้าหมาย' : 'Manage Goals',
                style: GoogleFonts.notoSansThai(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
              label: Icon(
                Icons.arrow_forward_rounded,
                size: 15,
                color: colorScheme.primary,
              ),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (totalActive == 0)
          InkWell(
            onTap: () => _navigateToGoalsScreen(context),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.flag_outlined,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isThai
                              ? 'ยังไม่มีเป้าหมายการอ่านที่เปิดอยู่'
                              : 'No active reading goals yet',
                          style: GoogleFonts.notoSansThai(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          isThai
                              ? 'แตะเพื่อไปที่หน้าเป้าหมายและเลือกแผนสำเร็จรูป'
                              : 'Tap to open Goals and pick a 1-click preset plan',
                          style: GoogleFonts.notoSansThai(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          )
        else ...[
          ...meaningGoals.take(2).map((profile) {
            final startIdx = absoluteVerseIndex(profile.start);
            final endIdx = profile.target != null
                ? absoluteVerseIndex(profile.target!)
                : 6236;
            final currIdx = profile.furthestUnreadIndex;
            final total = (endIdx - startIdx + 1).clamp(1, 6236);
            final done = (currIdx - startIdx + 1).clamp(0, total);
            final progress = (done / total).clamp(0.0, 1.0);
            final sName = surahDisplayName(
              profile.furthestUnread.surahId,
              isThai: isThai,
            );

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildCompactGoalRow(
                colorScheme: colorScheme,
                accentColor: const Color(0xFF0E5B59),
                modeLabel: isThai ? 'ความหมาย' : 'Meaning',
                title: profile.name,
                subtitle:
                    '$sName • ${isThai ? 'อายะฮฺ' : 'Ayah'} ${profile.furthestUnread.verseId}',
                progress: progress,
                onTap: () async {
                  await localReading.setActiveProfile(profile.id);
                  if (!mounted) return;
                  _navigateToReading(
                    context,
                    profile.furthestUnread.surahId,
                    verseId: profile.furthestUnread.verseId,
                  );
                },
              ),
            );
          }),
          ...mushafGoals.take(2).map((profile) {
            final total =
                (profile.targetPage - profile.startPage + 1).clamp(1, 604);
            final done =
                (profile.furthestUnreadPage - profile.startPage + 1)
                    .clamp(0, total);
            final progress = (done / total).clamp(0.0, 1.0);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildCompactGoalRow(
                colorScheme: colorScheme,
                accentColor: const Color(0xFF8A6530),
                modeLabel: isThai ? 'มุศหัฟ' : 'Mushaf',
                title: profile.name,
                subtitle: isThai
                    ? 'ถึงหน้าที่ ${profile.furthestUnreadPage} (เป้า ${profile.startPage}–${profile.targetPage})'
                    : 'At Page ${profile.furthestUnreadPage} (${profile.startPage}–${profile.targetPage})',
                progress: progress,
                onTap: () => _navigateToMushafProfile(
                  profile,
                  initialPage: profile.furthestUnreadPage,
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildCompactGoalRow({
    required ColorScheme colorScheme,
    required Color accentColor,
    required String modeLabel,
    required String title,
    required String subtitle,
    required double progress,
    required VoidCallback onTap,
  }) {
    final pct = (progress * 100).round().clamp(0, 100);
    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      modeLabel,
                      style: GoogleFonts.notoSansThai(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSansThai(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$pct%',
                    style: GoogleFonts.notoSansThai(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.play_circle_fill_rounded,
                    size: 20,
                    color: accentColor,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSansThai(
                        fontSize: 11.5,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor:
                      colorScheme.outlineVariant.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 4. Quick Access / Favourite Surahs Row ──────────────────────────────────
  Widget _buildQuickAccessSection(
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isThai,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark
        ? const Color(0xFF1B2621)
        : const Color(0xFFF3F7F4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bolt_rounded, size: 18, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              isThai ? 'ทางลัดซูเราะฮฺยอดนิยม' : 'Quick Surah Access',
              style: GoogleFonts.notoSansThai(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            if (_quickLinks.length < 8)
              TextButton.icon(
                onPressed: _showAddQuickLinkSheet,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(
                  isThai ? 'เพิ่มทางลัด' : 'Pin Surah',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _quickLinks.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final link = _quickLinks[index];
              final sId = link.surahNumber.toString();
              final surahName = surahDisplayName(sId, isThai: isThai);
              final arName = offlineSurahNamesAr[sId] ?? '';

              return Material(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () => _onQuickLinkTap(link),
                  onLongPress:
                      link.isLocked ? null : () => _deleteQuickLink(link),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 148,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colorScheme.outlineVariant
                            .withValues(alpha: isDark ? 0.35 : 0.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 1.5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                sId,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (arName.isNotEmpty)
                              Text(
                                arName,
                                style: const TextStyle(
                                  fontFamily: 'UthmanicHafs',
                                  fontSize: 13.5,
                                  color: Color(0xFF8A6530),
                                  height: 1.1,
                                ),
                              ),
                            if (!link.isLocked) ...[
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => _deleteQuickLink(link),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 13,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          surahName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.notoSansThai(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            InkWell(
                              onTap: () =>
                                  _openQuickLinkInMode(link, 'meaning'),
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                  vertical: 1,
                                ),
                                child: Text(
                                  isThai ? 'ความหมาย' : 'Meaning',
                                  style: GoogleFonts.notoSansThai(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () => _openQuickLinkInMode(link, 'mushaf'),
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.import_contacts_rounded,
                                      size: 10,
                                      color: Color(0xFF8A6530),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      isThai ? 'มุศหัฟ' : 'Mushaf',
                                      style: GoogleFonts.notoSansThai(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF8A6530),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatRelativeReadTime(DateTime timestamp, {required bool isThai}) {
    final diff = DateTime.now().difference(timestamp.toLocal());
    if (diff.inSeconds < 60) {
      return isThai ? 'เมื่อสักครู่' : 'just now';
    }
    if (diff.inMinutes < 60) {
      final mins = diff.inMinutes;
      return isThai ? '$mins นาทีที่แล้ว' : '${mins}m ago';
    }
    if (diff.inHours < 24) {
      final hrs = diff.inHours;
      return isThai ? '$hrs ชั่วโมงที่แล้ว' : '${hrs}h ago';
    }
    final days = diff.inDays;
    return isThai ? '$days วันที่แล้ว' : '${days}d ago';
  }

  Future<bool?> _showQuickResumeSheet({
    required String surahName,
    required String modeLabel,
    required String progressLabel,
    required DateTime timestamp,
    required String continueLabel,
    required String startOverLabel,
  }) async {
    return showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radius),
        ),
      ),
      builder: (ctx) {
        final settings = ctx.read<SettingsProvider>();
        final colors = settings.getAppColors();
        final isThai = settings.languageCode == 'th';
        final relative = _formatRelativeReadTime(timestamp, isThai: isThai);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      surahName,
                      style: GoogleFonts.notoSansThai(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: colors.primary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      modeLabel,
                      style: GoogleFonts.notoSansThai(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isThai
                    ? 'พบการอ่านล่าสุดที่ $progressLabel ($relative) ต้องการอ่านต่อหรือเริ่มใหม่?'
                    : 'Found a recent read at $progressLabel ($relative). Continue or start over?',
                style: GoogleFonts.notoSansThai(color: colors.foreground),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(continueLabel),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(startOverLabel),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openQuickLinkInMode(CustomQuickLink link, String mode) async {
    final sId = link.surahNumber.toString();
    final settings = context.read<SettingsProvider>();
    final isThai = settings.languageCode == 'th';
    final surahName = surahDisplayName(sId, isThai: isThai);

    if (mode == 'hifz') {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HifzWizardSetupScreen(
            quranRepository: widget.repository,
            foundationRepository: _foundationRepository,
            initialSurah: link.surahNumber,
            initialStartVerse: 1,
            initialStep: 0,
          ),
        ),
      );
      return;
    }

    if (mode == 'mushaf') {
      final mushafProvider = context.read<MushafReadingProvider>();
      final startPage = getMedinaMushafStartPageForSurah(link.surahNumber);
      final recent = mushafProvider.latestRecentForSurah(link.surahNumber);

      if (recent == null) {
        await _navigateToMushafFreeReadPage(
          startPage,
          surahContext: link.surahNumber,
          highlightedVerseKey: '${link.surahNumber}:1',
        );
        return;
      }

      if (!mounted) return;
      final startOver = await _showQuickResumeSheet(
        surahName: surahName,
        modeLabel: isThai ? 'มุศหัฟ' : 'Mushaf',
        progressLabel: isThai
            ? 'หน้า ${recent.pageNumber}'
            : 'Page ${recent.pageNumber}',
        timestamp: recent.updatedAt,
        continueLabel: isThai
            ? 'อ่านต่อ (หน้า ${recent.pageNumber})'
            : 'Continue (Page ${recent.pageNumber})',
        startOverLabel: isThai
            ? 'เริ่มจากหน้า $startPage'
            : 'Start from Page $startPage',
      );
      if (startOver == null || !mounted) return;

      if (startOver) {
        await mushafProvider.recordFreeReadPage(
          pageNumber: startPage,
          mushafId: recent.mushafId,
          surahId: link.surahNumber,
          immediateSync: true,
        );
        if (!mounted) return;
        await _navigateToMushafFreeReadPage(
          startPage,
          mushafId: recent.mushafId,
          surahContext: link.surahNumber,
          highlightedVerseKey: '${link.surahNumber}:1',
        );
        return;
      }

      await _navigateToMushafFreeReadPage(
        recent.pageNumber,
        mushafId: recent.mushafId,
        surahContext: link.surahNumber,
      );
      return;
    }

    final localReading = context.read<LocalReadingProvider>();
    final recent = localReading.latestRecentForSurah(link.surahNumber);
    if (recent == null) {
      if (!mounted) return;
      _navigateToReading(
        context,
        sId,
        verseId: '1',
        saveToFreeReadOnly: true,
      );
      return;
    }

    if (!mounted) return;
    final recentVerse = recent.verse.verseId;
    final startOver = await _showQuickResumeSheet(
      surahName: surahName,
      modeLabel: isThai ? 'ความหมาย' : 'Meaning',
      progressLabel: isThai ? 'อายะฮฺ $recentVerse' : 'Ayah $recentVerse',
      timestamp: recent.readAt,
      continueLabel: isThai
          ? 'อ่านต่อ (อายะฮฺ $recentVerse)'
          : 'Continue (Ayah $recentVerse)',
      startOverLabel: isThai ? 'เริ่มจากอายะฮฺ 1' : 'Start from Ayah 1',
    );
    if (startOver == null || !mounted) return;

    if (startOver) {
      await localReading.addRecentReading(
        verse: toVerseRef(sId, '1'),
        forceFreeRead: true,
        immediateSync: true,
      );
      if (!mounted) return;
      _navigateToReading(
        context,
        sId,
        verseId: '1',
        saveToFreeReadOnly: true,
      );
      return;
    }

    _navigateToReading(
      context,
      sId,
      verseId: recentVerse,
      saveToFreeReadOnly: true,
    );
  }

  Future<void> _onQuickLinkTap(CustomQuickLink link) async {
    final isThai = context.read<SettingsProvider>().languageCode == 'th';
    final surahName = surahDisplayName(
      link.surahNumber.toString(),
      isThai: isThai,
    );
    final startPage = getMedinaMushafStartPageForSurah(link.surahNumber);

    final destination = await _showReadingModeSheet(
      pageNumber: startPage,
      title: surahName,
    );
    if (!mounted || destination == null) return;

    final mode = destination == 'readspace' ? 'meaning' : destination;
    await _openQuickLinkInMode(link, mode);
  }

  void _showAddQuickLinkSheet() {
    int selectedSurah = 1;
    String customLabel = '';
    final isThai = context.read<SettingsProvider>().languageCode == 'th';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            final textTheme = Theme.of(context).textTheme;
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isThai ? 'เพิ่มทางลัดซูเราะฮฺ' : 'Pin Quick Surah Link',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: selectedSurah,
                    decoration: InputDecoration(
                      labelText: isThai ? 'เลือกซูเราะฮฺ' : 'Select Surah',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: List.generate(114, (i) {
                      final sNum = i + 1;
                      final sStr = sNum.toString();
                      final name =
                          '$sNum. ${surahDisplayName(sStr, isThai: isThai)}';
                      return DropdownMenuItem(
                        value: sNum,
                        child: Text(name),
                      );
                    }),
                    onChanged: (val) {
                      if (val != null) setSheetState(() => selectedSurah = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    decoration: InputDecoration(
                      labelText:
                          isThai ? 'ป้ายกำกับสั้นๆ (ไม่บังคับ)' : 'Short Label',
                      hintText:
                          isThai ? 'เช่น อ่านหลังฟัจญ์ร' : 'e.g., After Fajr',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (val) => customLabel = val,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        final now = DateTime.now();
                        setState(() {
                          _quickLinks.add(
                            CustomQuickLink(
                              id: 'ql_${now.microsecondsSinceEpoch}',
                              surahNumber: selectedSurah,
                              label: customLabel.trim(),
                              createdAt: now,
                              updatedAt: now,
                            ),
                          );
                        });
                        _saveQuickLinks();
                        Navigator.pop(sheetContext);
                      },
                      child: Text(isThai ? 'บันทึกทางลัด' : 'Save Quick Link'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── 6. Community Tadabbur Reflections Preview (Horizontal Slider) ────────────
  Widget _buildCommunityReflectionsSection(
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isThai,
  ) {
    final notes = _communityPool.isNotEmpty ? _communityPool : _communityPreview;
    final settings = context.read<SettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark
        ? const Color(0xFF1B2621)
        : const Color(0xFFF3F7F4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.forum_outlined, size: 18, color: colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isThai
                    ? 'บันทึกตดับบุรจากชุมชน'
                    : 'Community Tadabbur Reflections',
                style: GoogleFonts.notoSansThai(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            if (notes.length > 1)
              TextButton.icon(
                onPressed: _shuffleCommunityPreview,
                icon: const Icon(Icons.shuffle_rounded, size: 14),
                label: Text(
                  isThai ? 'สลับข้อคิด' : 'Shuffle',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TadabburCommunityScreen(
                      repository: widget.repository,
                    ),
                  ),
                ).then((_) => _loadCommunityPreview());
              },
              child: Text(
                isThai ? 'ดูทั้งหมด →' : 'View All →',
                style: GoogleFonts.notoSansThai(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_loadingCommunity)
          Container(
            height: 100,
            alignment: Alignment.center,
            child: const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (notes.isEmpty)
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TadabburCommunityScreen(
                    repository: widget.repository,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1.5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.rate_review_outlined,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isThai
                          ? 'แบ่งปันข้อคิดจากการอ่านอัลกุรอาน หรืออ่านบันทึกจากชุมชน'
                          : 'Share your Quran reflections or read notes from the community',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 168,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: notes.length,
              separatorBuilder: (_, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final note = notes[index];
                final surahName = surahDisplayName(
                  note.surahId,
                  isThai: isThai,
                );
                final verseObj =
                    widget.repository.getVerse(note.surahId, note.verseId);
                final translationText = verseObj != null
                    ? resolveVerseTranslationText(
                        context: context,
                        verseKey: '${note.surahId}:${note.verseId}',
                        verse: verseObj,
                        settings: settings,
                      )
                    : '';

                // Text truncation thresholds
                const maxTransChars = 60;
                const maxNoteChars = 75;
                final isTransLong = translationText.length > maxTransChars;
                final transSnippet = isTransLong
                    ? '${translationText.substring(0, maxTransChars).trim()}...'
                    : translationText;

                final isNoteLong = note.noteText.length > maxNoteChars;
                final noteSnippet = isNoteLong
                    ? '${note.noteText.substring(0, maxNoteChars).trim()}...'
                    : note.noteText;

                return InkWell(
                  onTap: () => _showTadabburDetailSheet(
                    context,
                    note,
                    translationText,
                    surahName,
                    isThai,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 280,
                    height: 168,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 1.5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Header Row
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$surahName (${note.surahId}:${note.verseId})',
                                style: GoogleFonts.notoSansThai(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.favorite_rounded,
                              size: 12,
                              color: colorScheme.secondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${note.likesCount}',
                              style: textTheme.labelSmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Translation Section (compact 1 line)
                        if (translationText.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.surface.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(6),
                              border: Border(
                                left: BorderSide(
                                  color: colorScheme.primary,
                                  width: 2.5,
                                ),
                              ),
                            ),
                            child: Text(
                              '${isThai ? 'ความหมาย: ' : 'Meaning: '}$transSnippet',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.notoSansThai(
                                fontSize: 10.5,
                                color: colorScheme.onSurfaceVariant,
                                height: 1.25,
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                        ],

                        // Tadabbur Note Reflection Section (2 lines max)
                        Expanded(
                          child: Text(
                            '${isThai ? 'ข้อคิด: ' : 'Reflection: '}$noteSnippet',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.notoSansThai(
                              fontSize: 11.5,
                              height: 1.35,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Footer Row
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                isThai
                                    ? 'โดย ${note.authorName}'
                                    : 'By ${note.authorName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.notoSansThai(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Text(
                              isThai ? 'ฉบับเต็ม →' : 'Full note →',
                              style: GoogleFonts.notoSansThai(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  void _showTadabburDetailSheet(
    BuildContext context,
    TadabburNote note,
    String translationText,
    String surahName,
    bool isThai,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final verseObj = widget.repository.getVerse(note.surahId, note.verseId);
    final arabicText = verseObj?.arabic ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$surahName (${note.surahId}:${note.verseId})',
                              style: GoogleFonts.notoSansThai(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.favorite_rounded,
                                size: 16,
                                color: colorScheme.secondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${note.likesCount}',
                                style: textTheme.labelMedium,
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 20),
                                onPressed: () => Navigator.pop(ctx),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Arabic verse text if available
                      if (arabicText.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBF9F5),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE8DFC8)),
                          ),
                          child: Text(
                            arabicText,
                            textAlign: TextAlign.right,
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(
                              fontFamily: 'UthmanicHafs',
                              fontSize: 22,
                              color: Color(0xFF0E5A4A),
                              height: 1.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Full translation
                      if (translationText.isNotEmpty) ...[
                        Text(
                          isThai ? 'ความหมายของอายะฮฺ' : 'Verse Translation',
                          style: GoogleFonts.notoSansThai(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          translationText,
                          style: GoogleFonts.notoSansThai(
                            fontSize: 14,
                            height: 1.6,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // Full Tadabbur note
                      Text(
                        isThai ? 'บันทึกใคร่ครวญ (ตดับบุร)' : 'Tadabbur Reflection',
                        style: GoogleFonts.notoSansThai(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF8A6530),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          note.noteText,
                          style: GoogleFonts.notoSansThai(
                            fontSize: 14.5,
                            height: 1.6,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isThai ? 'โดย ${note.authorName}' : 'By ${note.authorName}',
                        style: GoogleFonts.notoSansThai(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Action button
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _navigateToReading(
                            context,
                            note.surahId,
                            verseId: note.verseId,
                            saveToFreeReadOnly: true,
                          );
                        },
                        icon: const Icon(Icons.menu_book_rounded, size: 16),
                        label: Text(
                          isThai
                              ? 'เปิดอ่านในอัลกุรอาน'
                              : 'Read in Quran Reader',
                          style: GoogleFonts.notoSansThai(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0E5A4A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class CustomQuickLink {
  final String id;
  final int surahNumber;
  final String label;
  final bool isLocked;
  final DateTime createdAt;
  final DateTime updatedAt;

  CustomQuickLink({
    String? id,
    required this.surahNumber,
    required this.label,
    this.isLocked = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? createdAt ?? DateTime.now(),
       id = id ?? _fallbackId(surahNumber, label, isLocked);

  Map<String, dynamic> toJson() => {
    'id': id,
    'surahNumber': surahNumber,
    'label': label,
    'isLocked': isLocked,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory CustomQuickLink.fromJson(Map<String, dynamic> json) =>
      CustomQuickLink(
        id: json['id']?.toString(),
        surahNumber: json['surahNumber'],
        label: json['label'] ?? '',
        isLocked: json['isLocked'] ?? false,
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      );

  factory CustomQuickLink.fromSupabase(Map<String, dynamic> row) =>
      CustomQuickLink(
        id: row['id'].toString(),
        surahNumber: row['surah_number'],
        label: row['label']?.toString() ?? '',
        createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? ''),
      );

  static String _fallbackId(int surahNumber, String label, bool isLocked) {
    if (isLocked && surahNumber == 67) return 'system_mulk';
    if (isLocked && surahNumber == 18) return 'system_kahf';
    if (isLocked && surahNumber == 36) return 'system_yasin';
    if (isLocked && surahNumber == 78) return 'system_naba';
    final safeLabel = base64Url.encode(utf8.encode(label)).replaceAll('=', '');
    return 'ql_${surahNumber}_$safeLabel';
  }
}
