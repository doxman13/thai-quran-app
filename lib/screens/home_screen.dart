import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

extension _TadabburNoteAuthorExt on TadabburNote {
  String get authorName {
    if (isAnonymous) return 'ผู้ศรัทธา (ไม่ระบุชื่อ)';
    final raw = (userEmail ?? '').trim();
    if (raw.isEmpty) return 'ผู้ศรัทธา';
    return raw.contains('@') ? raw.split('@').first : raw;
  }
}

class _FeaturedVerseSeed {
  final int surahId;
  final int verseId;
  final String themeTh;
  final String themeEn;

  const _FeaturedVerseSeed({
    required this.surahId,
    required this.verseId,
    required this.themeTh,
    required this.themeEn,
  });
}

const List<_FeaturedVerseSeed> _curatedFeaturedVerses = [
  _FeaturedVerseSeed(
    surahId: 94,
    verseId: 5,
    themeTh: 'ความหวังหลังความยากลำบาก',
    themeEn: 'Ease After Hardship',
  ),
  _FeaturedVerseSeed(
    surahId: 2,
    verseId: 286,
    themeTh: 'ความเมตตาของอัลลอฮฺ',
    themeEn: 'Allah’s Mercy & Capacity',
  ),
  _FeaturedVerseSeed(
    surahId: 13,
    verseId: 28,
    themeTh: 'ความสงบของหัวใจ',
    themeEn: 'Tranquility of Hearts',
  ),
  _FeaturedVerseSeed(
    surahId: 65,
    verseId: 3,
    themeTh: 'การมอบหมายต่ออัลลอฮฺ (ตะวักกุล)',
    themeEn: 'Trust in Allah (Tawakkul)',
  ),
  _FeaturedVerseSeed(
    surahId: 39,
    verseId: 53,
    themeTh: 'การให้อภัยอันกว้างใหญ่',
    themeEn: 'Boundless Forgiveness',
  ),
  _FeaturedVerseSeed(
    surahId: 3,
    verseId: 139,
    themeTh: 'กำลังใจสำหรับผู้ศรัทธา',
    themeEn: 'Strength for Believers',
  ),
  _FeaturedVerseSeed(
    surahId: 2,
    verseId: 152,
    themeTh: 'การรำลึกถึงอัลลอฮฺ',
    themeEn: 'Remembrance & Gratitude',
  ),
];

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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
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

  // Featured verse state
  late int _featuredVerseIndex;
  int _featuredDayOfYear = 0;
  Future<String>? _featuredArabicFuture;

  // Community Tadabbur preview state
  List<TadabburNote> _communityPool = [];
  List<TadabburNote> _communityPreview = [];
  int _communityOffset = 0;
  bool _loadingCommunity = true;

  // Custom Quick Links
  List<CustomQuickLink> _quickLinks = [];
  StreamSubscription<AuthState>? _quickLinkAuthSubscription;
  String? _quickLinksLoadedForUser;
  int _quickLinksRevision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isInit = widget.repositoryReady;
    _featuredDayOfYear = _dayOfYearNow();
    _featuredVerseIndex =
        _featuredDayOfYear % _curatedFeaturedVerses.length;
    _refreshFeaturedArabic();
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

  void _refreshFeaturedArabic() {
    final seed = _curatedFeaturedVerses[_featuredVerseIndex];
    _featuredArabicFuture = widget.repository.fetchArabicVerse(
      seed.surahId.toString(),
      seed.verseId.toString(),
    );
  }

  void _shuffleFeaturedVerse() {
    setState(() {
      _featuredVerseIndex =
          (_featuredVerseIndex + 1) % _curatedFeaturedVerses.length;
      _refreshFeaturedArabic();
    });
  }

  Future<void> _loadCommunityPreview() async {
    try {
      final notes = await _tadabburRepository.fetchCommunityNotes(
        '0',
        '0',
        limit: 6,
      );
      if (!mounted) return;
      setState(() {
        _communityPool = notes.take(6).toList();
        _communityOffset = 0;
        _communityPreview = _communityPool.take(3).toList();
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
      if (_communityPool.length <= 3) {
        _communityPool = List<TadabburNote>.from(_communityPool.reversed);
        _communityPreview = _communityPool.take(3).toList();
      } else {
        _communityOffset = (_communityOffset + 3) % _communityPool.length;
        final next = <TadabburNote>[];
        for (int i = 0; i < 3 && i < _communityPool.length; i++) {
          next.add(_communityPool[(_communityOffset + i) % _communityPool.length]);
        }
        _communityPreview = next;
      }
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
        _refreshFeaturedArabic();
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
          id: 'system_mulk',
          surahNumber: 67,
          label: 'ก่อนนอน',
          isLocked: true,
        ),
        CustomQuickLink(
          id: 'system_naba',
          surahNumber: 78,
          label: 'ญุซอ์ 30',
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
            'created_at': link.createdAt.toIso8601String(),
            'updated_at': link.updatedAt.toIso8601String(),
          }, onConflict: 'id,user_id');
        } catch (e) {
          pushedAll = false;
          debugPrint('Error saving quick link ${link.id} to Supabase: $e');
        }
      }
      if (pushedAll) {
        await prefs.setString(
          _quickLinksSyncedAtKey(scope),
          DateTime.now().toIso8601String(),
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

  int _dayOfYearNow() {
    final now = DateTime.now();
    return now.difference(DateTime(now.year, 1, 1)).inDays;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state != AppLifecycleState.resumed) return;
    // Roll the featured verse over when the app resumes on a new day.
    final dayOfYear = _dayOfYearNow();
    if (dayOfYear == _featuredDayOfYear) return;
    _featuredDayOfYear = dayOfYear;
    setState(() {
      _featuredVerseIndex = dayOfYear % _curatedFeaturedVerses.length;
      _refreshFeaturedArabic();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    String? shortcutId,
  }) {
    final localReading = context.read<LocalReadingProvider>();
    final String? fallbackProfileId;
    if (saveToFreeReadOnly) {
      fallbackProfileId = null;
    } else if (shortcutId != null) {
      fallbackProfileId = shortcutId;
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
          shortcutId: shortcutId,
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
    String? shortcutId,
    String? highlightedVerseKey,
  }) async {
    final mushafProvider = context.read<MushafReadingProvider>();
    final profile = mushafProvider.freeReadProfileForMushaf(1);
    unawaited(mushafProvider.openUnifiedFreeRead());
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MushafReaderScreen(
          quranRepository: widget.repository,
          foundationRepository: _foundationRepository,
          profileId: shortcutId != null ? null : profile.id,
          shortcutId: shortcutId,
          initialPage: pageNumber,
          initialHighlightVerseKey: highlightedVerseKey,
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
          if (surahId != profile.start.surahId) {
            profile = null;
          }
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
    if (dt.isUtc) {
      return DateTime(
        dt.year,
        dt.month,
        dt.day,
        dt.hour,
        dt.minute,
        dt.second,
        dt.millisecond,
        dt.microsecond,
      );
    }
    return dt;
  }

  ({VerseRef verse, String? profileId, DateTime at})? _latestVerseLastRead(
    LocalReadingProvider provider,
  ) {
    ({VerseRef verse, String? profileId, DateTime at})? latest;

    for (final reading in provider.recentReadings) {
      final readingProfile = reading.profileId == null
          ? null
          : provider.profileById(reading.profileId!);
      if (readingProfile != null && readingProfile.isArchived) continue;
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
      final profile = mushafReading.profileById(mushafRecent.profileId);
      if (profile != null) {
        _navigateToMushafProfile(profile, initialPage: mushafRecent.pageNumber);
      } else {
        await _navigateToMushafFreeReadPage(mushafRecent.pageNumber);
      }
      return;
    }

    if (verseRecent != null) {
      final resolved = verseRecent.profileId == null
          ? null
          : localReading.profileById(verseRecent.profileId!);
      // Never reactivate an archived goal through the Continue card.
      final profile =
          resolved != null && !resolved.isArchived ? resolved : null;
      if (profile != null) {
        await localReading.setActiveProfile(profile.id);
      }
      if (!mounted) return;
      _navigateToReading(
        context,
        verseRecent.verse.surahId,
        verseId: verseRecent.verse.verseId,
        saveToFreeReadOnly: profile == null,
      );
      return;
    }

    _navigateToReading(context, '1', verseId: '1', saveToFreeReadOnly: true);
  }

  Future<void> _chooseBrowseDestination(
    String surahId,
    String verseId, {
    String? shortcutId,
  }) async {
    final colorScheme = Theme.of(context).colorScheme;
    final isThai = context.read<SettingsProvider>().languageCode == 'th';
    final surah = int.tryParse(surahId) ?? 1;
    final verse = int.tryParse(verseId) ?? 1;
    final pageNumber = getMedinaMushafPageNumber(surah, verse);

    final destination = await showModalBottomSheet<String>(
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
                context.tr('select_reading_mode'),
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
    if (!mounted || destination == null) return;
    if (destination == 'mushaf') {
      await _navigateToMushafFreeReadPage(
        pageNumber,
        shortcutId: shortcutId,
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
      saveToFreeReadOnly: shortcutId == null,
      shortcutId: shortcutId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final settings = context.watch<SettingsProvider>();
    final readingProvider = context.watch<LocalReadingProvider>();
    final mushafReadingProvider = context.watch<MushafReadingProvider>();
    final statsProvider = context.watch<StatsProvider>();
    final isThai = settings.languageCode == 'th';

    if (!_isInit) {
      return Scaffold(
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
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0.5,
          backgroundColor: colorScheme.surface,
          titleSpacing: 16,
          title: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SvgPicture.asset(
                  isThai
                      ? 'assets/quran-app-LOGO-th.svg'
                      : 'assets/quran-app-LOGO-eng.svg',
                  width: 36,
                  height: 36,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                context.tr('welcome_app_name'),
                style: GoogleFonts.notoSansThai(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search_rounded),
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
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings_rounded),
              label: isThai ? 'ตั้งค่า' : 'Settings',
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

          // 6. Daily Inspiration Verse (Compact & Clean)
          _buildFeaturedVerseCard(colorScheme, textTheme, settings, isThai),
          const SizedBox(height: 20),

          // 7. Community Tadabbur Reflections Preview
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('salam'),
                      style: GoogleFonts.notoSansThai(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      supabaseProv.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSansThai(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_fire_department_rounded,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isThai
                          ? 'ต่อเนื่อง ${statsProvider.streakCount} วัน'
                          : '${statsProvider.streakCount}d Streak',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
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
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4A853).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFD4A853).withValues(alpha: 0.45),
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
                          Text(
                            modeBadge,
                            style: GoogleFonts.notoSansThai(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFF3D28A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
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
                            Text(
                              recommendationPill,
                              style: GoogleFonts.notoSansThai(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (hasHistory)
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
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _navigateToReading(
                            context,
                            '1',
                            verseId: '1',
                            saveToFreeReadOnly: true,
                          ),
                          icon: const Icon(Icons.menu_book_rounded, size: 18),
                          label: Text(
                            isThai ? 'อ่านแบบความหมาย' : 'Read with Meaning',
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
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _navigateToMushafFreeReadPage(1),
                          icon: const Icon(Icons.import_contacts_rounded, size: 18),
                          label: Text(
                            isThai ? 'เปิดมุศหัฟ' : 'Open Mushaf',
                            style: GoogleFonts.notoSansThai(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.12),
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
                        ),
                      ),
                    ],
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
        Row(
          children: [
            Expanded(
              child: _buildMetroTile(
                backgroundColor: meaningColor,
                icon: Icons.menu_book_rounded,
                title: isThai ? 'อ่านฉบับแปล' : 'Meaning Reader',
                subtitle: isThai ? 'แปลไทย & ตัฟซีร' : 'Translation & Tafsir',
                badgeText: isThai ? 'ความหมาย' : 'Meaning',
                onTap: () {
                  final verseRecent = _latestVerseLastRead(readingProvider);
                  if (verseRecent != null) {
                    final profile = verseRecent.profileId != null
                        ? readingProvider.profileById(verseRecent.profileId!)
                        : null;
                    _navigateToReading(
                      context,
                      verseRecent.verse.surahId,
                      verseId: verseRecent.verse.verseId,
                      saveToFreeReadOnly:
                          profile == null || isFreeReadProfile(profile),
                    );
                  } else {
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
                subtitle: isThai ? '15 บรรทัดมาตรฐาน' : '15-Line Standard',
                badgeText: isThai ? 'มุศหัฟ' : 'Mushaf',
                onTap: () {
                  final mushafRecent =
                      _latestMushafLastRead(mushafReadingProvider);
                  _navigateToMushafFreeReadPage(mushafRecent?.pageNumber ?? 1);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
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
  }) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Container(
          height: 108,
          padding: const EdgeInsets.all(13),
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
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeText,
                      style: GoogleFonts.notoSansThai(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ],
              ),
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
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                  ),
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
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GoalsScreen(
                      repository: widget.repository,
                      foundationRepository: _foundationRepository,
                    ),
                  ),
                );
              },
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
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GoalsScreen(
                    repository: widget.repository,
                    foundationRepository: _foundationRepository,
                  ),
                ),
              );
            },
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
          height: 100,
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
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppTheme.radius),
                child: InkWell(
                  onTap: () => _onQuickLinkTap(link),
                  onLongPress:
                      link.isLocked ? null : () => _deleteQuickLink(link),
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  child: Container(
                    width: 154,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                      border: Border.all(
                        color: colorScheme.outlineVariant
                            .withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                sId,
                                style: TextStyle(
                                  fontSize: 10.5,
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
                                  fontSize: 15,
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
                                  size: 14,
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
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isThai ? 'ความหมาย' : 'Meaning',
                              style: GoogleFonts.notoSansThai(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.primary,
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                final page = getMedinaMushafPageNumber(
                                  link.surahNumber,
                                  1,
                                );
                                _navigateToMushafFreeReadPage(page);
                              },
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
                                      size: 11,
                                      color: Color(0xFF8A6530),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      isThai ? 'มุศหัฟ' : 'Mushaf',
                                      style: GoogleFonts.notoSansThai(
                                        fontSize: 10,
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

  Future<void> _onQuickLinkTap(CustomQuickLink link) async {
    final provider = context.read<LocalReadingProvider>();
    final shortcutId =
        '00000000-0000-0000-0000-00000000${link.surahNumber.toString().padLeft(4, '0')}';

    provider.checkAndResetShortcutProfiles();
    final profile = await provider.ensureShortcutProfile(
      shortcutId,
      link.surahNumber,
    );
    var targetVerseId = profile.current.verseId;

    if (targetVerseId != '1') {
      if (!mounted) return;
      final startOver = await showModalBottomSheet<bool>(
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
          final sId = link.surahNumber.toString();
          final surahName = surahDisplayName(sId, isThai: isThai);
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  surahName,
                  style: GoogleFonts.notoSansThai(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isThai
                      ? 'คุณกำลังอ่านค้างอยู่ที่อายะฮฺ $targetVerseId คุณต้องการอ่านต่อหรือเริ่มต้นใหม่?'
                      : 'You are currently at Verse $targetVerseId. Do you want to continue or start over?',
                  style: GoogleFonts.notoSansThai(color: colors.foreground),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(
                    isThai
                        ? 'อ่านต่อ (อายะฮฺ $targetVerseId)'
                        : 'Continue reading (Verse $targetVerseId)',
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(
                    isThai ? 'เริ่มต้นใหม่จากอายะฮฺ 1' : 'Start from Verse 1',
                  ),
                ),
              ],
            ),
          );
        },
      );
      if (startOver == null) return;
      if (startOver) {
        targetVerseId = '1';
        await provider.updateShortcutProgress(
          shortcutId,
          toVerseRef(link.surahNumber.toString(), '1'),
        );
      }
    }

    if (!mounted) return;
    await _chooseBrowseDestination(
      link.surahNumber.toString(),
      targetVerseId,
      shortcutId: shortcutId,
    );
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

  // ── 6. Daily Inspiration Verse (Clean & Compact) ───────────────────────────
  Widget _buildFeaturedVerseCard(
    ColorScheme colorScheme,
    TextTheme textTheme,
    SettingsProvider settings,
    bool isThai,
  ) {
    final seed = _curatedFeaturedVerses[_featuredVerseIndex];
    final sStr = seed.surahId.toString();
    final vStr = seed.verseId.toString();
    final verseObj = widget.repository.getVerse(sStr, vStr);
    final surahName = surahDisplayName(sStr, isThai: isThai);
    final translationText = verseObj != null
        ? resolveVerseTranslationText(
            context: context,
            verseKey: '$sStr:$vStr',
            verse: verseObj,
            settings: settings,
          )
        : '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 13,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isThai ? 'อายะฮฺประจำวัน' : 'Daily Inspiration',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isThai ? seed.themeTh : seed.themeEn,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.notoSansThai(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              IconButton(
                onPressed: _shuffleFeaturedVerse,
                icon: const Icon(Icons.shuffle_rounded, size: 17),
                tooltip: isThai ? 'สุ่มอายะฮฺอื่น' : 'Shuffle Verse',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 10),
          FutureBuilder<String>(
            future: _featuredArabicFuture,
            builder: (context, snapshot) {
              final arabic = (snapshot.data ?? '').replaceAll(' | ', ' ');
              if (arabic.isEmpty) {
                return const SizedBox(height: 24);
              }
              return Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                  arabic,
                  textAlign: TextAlign.right,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'UthmanicHafs',
                    fontSize: 20,
                    height: 1.6,
                    color: colorScheme.onSurface,
                  ),
                ),
              );
            },
          ),
          if (translationText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '“$translationText”',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.notoSansThai(
                fontSize: 13,
                height: 1.5,
                fontStyle: FontStyle.italic,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$surahName ($sStr:$vStr)',
                style: GoogleFonts.notoSansThai(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
              TextButton.icon(
                onPressed: () => _navigateToReading(
                  context,
                  sStr,
                  verseId: vStr,
                  saveToFreeReadOnly: true,
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                label: Text(
                  isThai ? 'อ่านบริบท & ตัฟซีร' : 'Read in Context',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 6. Community Tadabbur Reflections Preview ───────────────────────────────
  Widget _buildCommunityReflectionsSection(
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isThai,
  ) {
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
            if (_communityPool.length > 1)
              TextButton.icon(
                onPressed: _shuffleCommunityPreview,
                icon: const Icon(Icons.shuffle_rounded, size: 14),
                label: Text(
                  isThai ? 'สลับข้อคิดอื่น' : 'Shuffle',
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
        const SizedBox(height: 6),
        if (_loadingCommunity)
          Container(
            padding: const EdgeInsets.all(20),
            alignment: Alignment.center,
            child: const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (_communityPreview.isEmpty)
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
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                ),
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
          ..._communityPreview.map((note) {
            final surahName = surahDisplayName(
              note.surahId,
              isThai: isThai,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
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
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$surahName (${note.surahId}:${note.verseId})',
                              style: GoogleFonts.notoSansThai(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.favorite_rounded,
                            size: 13,
                            color: colorScheme.secondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${note.likesCount}',
                            style: textTheme.labelSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        note.noteText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSansThai(
                          fontSize: 13,
                          height: 1.45,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isThai
                            ? 'โดย ${note.authorName}'
                            : 'By ${note.authorName}',
                        style: GoogleFonts.notoSansThai(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
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
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
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
