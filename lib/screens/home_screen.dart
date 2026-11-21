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
import '../models/hifz_session_config.dart';
import '../models/mushaf_models.dart';
import '../models/tadabbur_note.dart';
import '../providers/local_reading_provider.dart';
import '../providers/mushaf_reading_provider.dart';
import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/stats_provider.dart';
import '../providers/supabase_provider.dart';
import '../providers/thai_text_protection_provider.dart';
import '../services/app_update_service.dart';
import '../shared/shared.dart';
import '../theme/app_theme.dart';
import '../utils/hifz_mastery_utils.dart';
import 'bookmarks_screen.dart';
import 'browse_screen.dart';
import 'goals_screen.dart';
import 'hifz_landing_screen.dart';
import 'hifz_memorize_screen.dart';
import 'hifz_wizard_setup_screen.dart';
import 'mushaf_reader_screen.dart';
import 'reading_screen.dart';
import 'settings_screen.dart';
import 'tadabbur_community_screen.dart';
import '../widgets/auth_bottom_sheet.dart';
import '../widgets/home/home_community_preview.dart';
import '../widgets/home/home_continue_hero.dart';
import '../widgets/home/home_goals_snapshot.dart';
import '../widgets/home/home_hifz_resume_banner.dart';
import '../widgets/home/home_quick_surahs.dart';
import '../widgets/home/home_study_hub_grid.dart';
import '../widgets/surah_picker_sheet.dart';
import '../widgets/voice_search_sheet.dart';
import 'package:qcf_quran/qcf_quran.dart' as qcf;

class _DailyQuranQuote {
  final String surahId;
  final String verseId;
  final String arabicUthmanic;
  final String meaningTh;
  final String meaningEn;

  const _DailyQuranQuote({
    required this.surahId,
    required this.verseId,
    required this.arabicUthmanic,
    required this.meaningTh,
    required this.meaningEn,
  });
}

const List<_DailyQuranQuote> _dailyQuranQuotes = [
  _DailyQuranQuote(
    surahId: '94',
    verseId: '6',
    arabicUthmanic: 'إِنَّ مَعَ ٱلۡعُسۡرِ يُسۡرٗا | ٦',
    meaningTh: 'แท้จริงหลังจากความยากลำบาก ก็จะมีความง่าย',
    meaningEn: 'Indeed, with hardship [will be] ease.',
  ),
  _DailyQuranQuote(
    surahId: '55',
    verseId: '60',
    arabicUthmanic: 'هَلۡ جَزَآءُ ٱلۡإِحۡسَٰنِ إِلَّا ٱلۡإِحۡسَٰنُ | ٦٠',
    meaningTh: 'จะมีการตอบแทนความดีอันใดเล่า นอกจากความดี',
    meaningEn: 'Is the reward for good [anything] but good?',
  ),
  _DailyQuranQuote(
    surahId: '93',
    verseId: '5',
    arabicUthmanic: 'وَلَسَوۡفَ يُعۡطِيكَ رَبُّكَ فَتَرۡضَىٰٓ | ٥',
    meaningTh: 'และแน่นอน พระผู้อภิบาลของเจ้าจะให้แก่เจ้าจนกว่าจะพอใจ',
    meaningEn: 'And your Lord is going to give you, and you will be satisfied.',
  ),
  _DailyQuranQuote(
    surahId: '1',
    verseId: '2',
    arabicUthmanic: 'ٱلۡحَمۡدُ لِلَّهِ رَبِّ ٱلۡعَٰلَمِينَ | ٢',
    meaningTh: 'การสรรเสริญทั้งหลายนั้นเป็นสิทธิของอัลลอฮฺ พระผู้อภิบาลแห่งสากลโลก',
    meaningEn: 'All praise is due to Allah, Lord of the worlds.',
  ),
];

@visibleForTesting
List<TadabburNote> selectHomepageCommunityNotes({
  required List<TadabburNote> thaiNotes,
  required List<TadabburNote> englishFallbackNotes,
}) {
  final validThai =
      thaiNotes.where((n) => n.noteText.trim().isNotEmpty).toList();
  if (validThai.isNotEmpty) return validThai;
  return englishFallbackNotes
      .where((n) => n.noteText.trim().isNotEmpty)
      .toList();
}

extension _TadabburNoteAuthorExt on TadabburNote {
  String get authorName {
    if (isQuranReflect) {
      final raw = (userEmail ?? '').trim();
      return raw.isNotEmpty ? raw : 'QuranReflect';
    }
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
  final GlobalKey<BrowseScreenState> _browseKey = GlobalKey<BrowseScreenState>();

  int _navIndex = 0;
  bool _isInit = false;
  bool _initFailed = false;

  // Community Tadabbur preview state
  List<TadabburNote> _communityPool = [];
  bool _loadingCommunity = true;

  // Active Hifz midway session for Home resume banner
  ActiveSessionSnapshot? _activeHifzSession;

  // Custom Quick Links
  List<CustomQuickLink> _quickLinks = _defaultQuickLinks();
  StreamSubscription<AuthState>? _quickLinkAuthSubscription;
  Future<void>? _quickLinksLoadFuture;
  bool _quickLinksHydrated = false;
  String? _quickLinksLoadedForUser;
  int _quickLinksRevision = 0;

  @override
  void initState() {
    super.initState();
    _isInit = widget.repositoryReady;
    _loadQuickLinks();
    _loadCommunityPreview();
    unawaited(_loadActiveHifzSession());
    _quickLinkAuthSubscription = Supabase.instance.client.auth.onAuthStateChange
        .listen((data) {
      final userId = data.session?.user.id;
      if (_quickLinksHydrated && userId == _quickLinksLoadedForUser) return;
      unawaited(_loadQuickLinks());
    }, onError: (Object error, StackTrace stackTrace) {
      debugPrint('[HomeScreen] onAuthStateChange error: $error');
    });
    if (!_isInit) {
      _initApp();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(AppUpdateService.instance.checkAndPromptOnStartup(context));
    });
  }

  Future<void> _loadActiveHifzSession() async {
    try {
      final snap = await HifzRepository().loadActiveSession();
      if (!mounted) return;
      setState(() => _activeHifzSession = snap);
    } catch (_) {}
  }

  Future<void> _resumeActiveHifzSession() async {
    final snap = _activeHifzSession ?? await HifzRepository().loadActiveSession();
    if (snap == null || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HifzMemorizeScreen(
          quranRepository: widget.repository,
          foundationRepository: _foundationRepository,
          resumeSessionSnapshot: snap,
        ),
      ),
    );
    if (mounted) {
      unawaited(_loadActiveHifzSession());
    }
  }

  Future<void> _discardActiveHifzSession() async {
    await HifzRepository().clearActiveSession(
      sessionId: _activeHifzSession?.sessionId,
    );
    if (!mounted) return;
    setState(() => _activeHifzSession = null);
  }

  Future<void> _loadCommunityPreview() async {
    try {
      final results = await Future.wait([
        _tadabburRepository.getBlockedUserIds(),
        _tadabburRepository.fetchCommunityNotes(
          '0',
          '0',
          limit: 25,
        ),
      ]);
      final blockedUsers = results[0] as Set<String>;
      final rawThaiNotes = results[1] as List<TadabburNote>;
      final thaiNotes = rawThaiNotes
          .where(
            (n) =>
                !blockedUsers.contains(n.userId) &&
                n.noteText.trim().isNotEmpty,
          )
          .toList();

      List<TadabburNote> englishFallback = const [];
      if (thaiNotes.isEmpty) {
        englishFallback = await _tadabburRepository.fetchQuranReflectNotes(
          limit: 50,
        );
      }

      final selected = selectHomepageCommunityNotes(
        thaiNotes: thaiNotes,
        englishFallbackNotes: englishFallback,
      );
      if (!mounted) return;
      setState(() {
        _communityPool = selected;
        _loadingCommunity = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingCommunity = false;
      });
    }
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
    await _loadActiveHifzSession();
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
    ).then((_) => unawaited(_loadActiveHifzSession()));
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
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map(
            (e) => CustomQuickLink.tryFromJson(Map<String, dynamic>.from(e)),
          )
          .whereType<CustomQuickLink>()
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

  Future<void> _loadQuickLinks() {
    final future = _performLoadQuickLinks();
    _quickLinksLoadFuture = future;
    return future;
  }

  Future<void> _performLoadQuickLinks() async {
    final revision = _quickLinksRevision;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final scope = _quickLinksScope(userId);

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      final currentAfterPrefs = Supabase.instance.client.auth.currentUser?.id;
      if (currentAfterPrefs != userId) {
        unawaited(_loadQuickLinks());
        return;
      }

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

      // Apply local/default shortcuts immediately before waiting on Supabase
      // so the UI renders shortcuts right away even offline or on slow networks.
      if (!mounted) return;
      if (Supabase.instance.client.auth.currentUser?.id != userId) {
        unawaited(_loadQuickLinks());
        return;
      }
      if (revision != _quickLinksRevision) {
        return;
      }
      _quickLinksLoadedForUser = userId;
      _quickLinksHydrated = true;
      setState(() {
        _quickLinks = links;
      });

      if (userId != null) {
        links = await _syncQuickLinksWithSupabase(userId, scope, links);
      }

      if (!mounted) return;
      if (Supabase.instance.client.auth.currentUser?.id != userId) {
        unawaited(_loadQuickLinks());
        return;
      }
      if (revision != _quickLinksRevision) {
        return;
      }
      _quickLinksLoadedForUser = userId;
      _quickLinksHydrated = true;
      setState(() {
        _quickLinks = links;
      });
      await _persistQuickLinks(prefs, scope, links);
    } catch (e) {
      debugPrint('Error loading quick links: $e');
      if (!mounted) return;
      if (Supabase.instance.client.auth.currentUser?.id != userId) {
        unawaited(_loadQuickLinks());
        return;
      }
      if (revision != _quickLinksRevision) return;
      _quickLinksLoadedForUser = userId;
      _quickLinksHydrated = true;
      setState(() {
        _quickLinks = _defaultQuickLinks();
      });
    }
  }

  static List<CustomQuickLink> _defaultQuickLinks() => [
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
    // Wait for any in-flight initial load before saving so auto-sync never
    // clobbers unhydrated state or aborts an active load.
    if (!_quickLinksHydrated ||
        (userId != null && _quickLinksLoadedForUser != userId)) {
      final pendingLoad = _quickLinksLoadFuture;
      if (pendingLoad != null) {
        await pendingLoad;
      }
    }
    final activeUserId = Supabase.instance.client.auth.currentUser?.id;
    if (!_quickLinksHydrated ||
        (activeUserId != null && _quickLinksLoadedForUser != activeUserId) ||
        (_quickLinksLoadedForUser != null &&
            activeUserId != _quickLinksLoadedForUser)) {
      return;
    }
    _quickLinksRevision++;
    _quickLinks = _normalizeQuickLinks(_quickLinks);
    final prefs = await SharedPreferences.getInstance();
    final scope = _quickLinksScope(activeUserId);
    await _persistQuickLinks(prefs, scope, _quickLinks);

    if (!syncRemote || activeUserId == null) return;
    final merged = await _syncQuickLinksWithSupabase(
      activeUserId,
      scope,
      _quickLinks,
    );
    if (!mounted ||
        Supabase.instance.client.auth.currentUser?.id != activeUserId) {
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
          .order('sort_order')
          .timeout(const Duration(seconds: 8));
      final remoteLinks = List<Map<String, dynamic>>.from(
        remoteRows,
      )
          .map(CustomQuickLink.tryFromSupabase)
          .whereType<CustomQuickLink>()
          .toList();
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
        appBar: _navIndex == 0
            ? null
            : AppBar(
                automaticallyImplyLeading: false,
                leading: IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: appColors.primary,
                  ),
                  tooltip: isThai ? 'กลับหน้าแรก' : 'Back to Home',
                  onPressed: _handleBackNavigation,
                ),
                elevation: 0,
                scrolledUnderElevation: 0,
                backgroundColor: appColors.background,
                titleSpacing: 16,
                title: _buildAppBarTitleForTab(_navIndex, isThai, appColors),
                actions: [
                  IconButton(
                    icon: Icon(Icons.search_rounded, color: appColors.primary),
                    tooltip: isThai ? 'ค้นหาอัลกุรอาน' : 'Search Quran',
                    onPressed: _openTabSearch,
                  ),
                  IconButton(
                    icon: Icon(Icons.mic_none_rounded, color: appColors.primary),
                    tooltip: isThai
                        ? 'ค้นหาด้วยเสียง (อัลกุรอาน)'
                        : 'Voice Search (Arabic Quran)',
                    onPressed: _openVoiceSearchSheet,
                  ),
                  const SizedBox(width: 6),
                ],
              ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: appColors.borderSoft.withValues(alpha: 0.7),
              ),
            ),
          ),
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.15,
            child: NavigationBar(
              height: 62,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              selectedIndex: _navIndex,
              onDestinationSelected: (index) {
                setState(() => _navIndex = index);
              },
              elevation: 0,
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? appColors.surface
                  : appColors.surfaceMuted,
              indicatorColor: appColors.primaryLight,
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home_rounded),
                  label: isThai ? 'หน้าแรก' : 'Home',
                ),
                NavigationDestination(
                  icon: const Icon(Icons.menu_book_outlined),
                  selectedIcon: const Icon(Icons.menu_book_rounded),
                  label: isThai ? 'ซูเราะฮฺ' : 'Surah',
                ),
                NavigationDestination(
                  icon: const Icon(Icons.bookmark_border_rounded),
                  selectedIcon: const Icon(Icons.bookmark_rounded),
                  label: isThai ? 'ที่คั่นหน้า' : 'Bookmarks',
                ),
                NavigationDestination(
                  icon: const Icon(Icons.person_outline_rounded),
                  selectedIcon: const Icon(Icons.person_rounded),
                  label: isThai ? 'โปรไฟล์' : 'Profile',
                ),
              ],
            ),
          ),
        ),
        body: Stack(
          children: [
            IndexedStack(
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
                  key: _browseKey,
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
            if (_navIndex != 0)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 24,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragEnd: (details) {
                    if ((details.primaryVelocity ?? 0) > 250) {
                      _handleBackNavigation();
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openTabSearch() {
    setState(() => _navIndex = 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _browseKey.currentState?.focusSearch();
    });
  }

  void _openVoiceSearchSheet() {
    VoiceSearchSheet.show(
      context,
      repository: widget.repository,
      onOpenPage: (page, {highlightVerseKey}) {
        _navigateToMushafFreeReadPage(
          page,
          highlightedVerseKey: highlightVerseKey,
        );
      },
    );
  }

  Widget _wrapHomeSection(Widget child) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: child,
        ),
      ),
    );
  }

  _DailyQuranQuote _todayQuranQuote() {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year)).inDays;
    return _dailyQuranQuotes[dayOfYear % _dailyQuranQuotes.length];
  }

  Widget _buildEditorialTopAtmosphere({
    required SettingsProvider settings,
    required AppThemeColors appColors,
    required bool isThai,
    required String displayName,
    required int streakCount,
    required bool hasReadToday,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cleanName = displayName.trim();
    final greeting = isThai ? 'อัสสลามุอะลัยกุม' : 'Assalamu Alaikum';
    final subUser = cleanName.isNotEmpty
        ? cleanName
        : (isThai ? 'ผู้ศรัทธา' : 'Reader');
    final streakLabel = isThai ? '$streakCount วันต่อเนื่อง' : '${streakCount}d streak';
    final streakBg = hasReadToday
        ? appColors.primaryLight.withValues(alpha: 0.92)
        : appColors.mushafGoldSoft.withValues(alpha: 0.92);
    final streakFg = hasReadToday ? appColors.primary : appColors.mushafGold;
    final pillActionBg = isDark
        ? appColors.surfaceMuted.withValues(alpha: 0.82)
        : appColors.surface.withValues(alpha: 0.86);

    final quote = _todayQuranQuote();
    final verseObj = widget.repository.getVerse(quote.surahId, quote.verseId);
    final rawArabic = (verseObj?.arabic ?? '').trim().isNotEmpty
        ? verseObj!.arabic
        : quote.arabicUthmanic;
    final quoteArabic = formatArabicAyahText(
      rawArabic,
      verseNumber: quote.verseId,
    );
    final resolvedFromRepo = verseObj != null
        ? resolveVerseTranslationText(
            context: context,
            verseKey: '${quote.surahId}:${quote.verseId}',
            verse: verseObj,
            settings: settings,
          ).trim()
        : '';
    final rawMeaning = resolvedFromRepo.isNotEmpty
        ? resolvedFromRepo
        : (isThai ? quote.meaningTh : quote.meaningEn);
    final quoteMeaning = ThaiTextProtectionProvider.protectSafe(
      context,
      rawMeaning,
      listen: true,
    );
    final quoteSurahName = surahDisplayName(quote.surahId, isThai: isThai);

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: appColors.background),
                Opacity(
                  opacity: isDark ? 0.36 : 0.70,
                  child: Image.asset(
                    'assets/images/image_slider1_x.webp',
                    fit: BoxFit.cover,
                    alignment: const Alignment(0.0, 0.80),
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
                // Light left wash keeping typography readable while letting sunlit Quran-on-rehal shine cleanly on the right
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        appColors.background.withValues(alpha: isDark ? 0.84 : 0.78),
                        appColors.background.withValues(alpha: isDark ? 0.58 : 0.48),
                        appColors.background.withValues(alpha: isDark ? 0.24 : 0.08),
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        appColors.background.withValues(alpha: isDark ? 0.10 : 0.06),
                        appColors.background.withValues(alpha: isDark ? 0.16 : 0.12),
                        appColors.background,
                      ],
                      stops: const [0.0, 0.76, 1.0],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                greeting,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.notoSansThai(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  color: appColors.textStrong,
                                  height: 1.2,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Wrap(
                                spacing: 7,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    subUser,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.notoSansThai(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: appColors.textMuted,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: streakBg,
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusSm,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          hasReadToday
                                              ? Icons.local_fire_department_rounded
                                              : Icons.auto_awesome_outlined,
                                          size: 12.5,
                                          color: streakFg,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            streakLabel,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.notoSansThai(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: streakFg,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: pillActionBg,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: appColors.borderSoft.withValues(alpha: 0.45),
                            ),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.search_rounded,
                              size: 19,
                              color: appColors.textStrong,
                            ),
                            tooltip: isThai ? 'ค้นหาอัลกุรอาน' : 'Search Quran',
                            onPressed: _openTabSearch,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: pillActionBg,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: appColors.borderSoft.withValues(alpha: 0.45),
                            ),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.mic_none_rounded,
                              size: 19,
                              color: appColors.textStrong,
                            ),
                            tooltip: isThai
                                ? 'ค้นหาด้วยเสียง (อัลกุรอาน)'
                                : 'Voice Search (Arabic Quran)',
                            onPressed: _openVoiceSearchSheet,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    LayoutBuilder(
                      builder: (ctx, constraints) {
                        final scale = MediaQuery.textScalerOf(ctx).scale(1.0);
                        final factor =
                            (constraints.maxWidth < 340 || scale > 1.05)
                                ? 0.88
                                : 0.76;
                        return FractionallySizedBox(
                          widthFactor: factor,
                          alignment: AlignmentDirectional.centerStart,
                          child: Semantics(
                            button: true,
                            label: '$quoteSurahName ${quote.surahId}:${quote.verseId}: $quoteMeaning',
                            child: InkWell(
                              onTap: () => _navigateToReading(
                                context,
                                quote.surahId,
                                verseId: quote.verseId,
                                saveToFreeReadOnly: true,
                              ),
                              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
                                decoration: BoxDecoration(
                                  border: Border(
                                    left: BorderSide(
                                      color: appColors.mushafGold.withValues(alpha: 0.78),
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Align(
                                      alignment: AlignmentDirectional.centerStart,
                                      child: Text(
                                        quoteArabic,
                                        textDirection: TextDirection.rtl,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: 'UthmanicHafs',
                                          fontSize: 26,
                                          height: 1.55,
                                          color: appColors.textStrong,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      '“$quoteMeaning”',
                                      maxLines: 4,
                                      overflow: TextOverflow.ellipsis,
                                      locale: ThaiTextProtectionProvider.localeForText(
                                        rawMeaning,
                                        forceThai: isThai,
                                      ),
                                      style: GoogleFonts.notoSansThai(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: appColors.foreground.withValues(
                                          alpha: isDark ? 0.90 : 0.88,
                                        ),
                                        height: 1.48,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            '$quoteSurahName (${quote.surahId}:${quote.verseId})',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.notoSansThai(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: appColors.primary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          size: 15,
                                          color: appColors.primary,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 0: CLEAN HOME SHOWCASE (Ultra-Minimal Editorial Layout)
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
    final appColors = settings.getAppColors();
    final supabaseProv = context.watch<SupabaseProvider>();

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          _loadCommunityPreview(),
          _triggerAutoSync(),
          _loadActiveHifzSession(),
        ]);
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _buildEditorialTopAtmosphere(
            settings: settings,
            appColors: appColors,
            isThai: isThai,
            displayName: supabaseProv.displayName,
            streakCount: statsProvider.streakCount,
            hasReadToday: statsProvider.hasReadOn(DateTime.now()),
          ),
          _wrapHomeSection(
            _buildHeroSection(
              readingProvider: readingProvider,
              mushafReadingProvider: mushafReadingProvider,
              isSignedIn: supabaseProv.isLoggedIn,
              isThai: isThai,
            ),
          ),
          const SizedBox(height: 18),

          _wrapHomeSection(
            HomeStudyHubGrid(
              isThai: isThai,
              appColors: appColors,
              hifzSubtitleOverride: _activeHifzSession != null
                  ? formatActiveSessionSubtitle(
                      _activeHifzSession!,
                      isThai: isThai,
                    )
                  : null,
              onOpenMeaning: _showMeaningHubModal,
              onOpenMushaf: _showMushafHubModal,
              onOpenHifz: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HifzLandingScreen(
                      quranRepository: widget.repository,
                      foundationRepository: _foundationRepository,
                    ),
                  ),
                ).then((_) => unawaited(_loadActiveHifzSession()));
              },
              onOpenGoals: () => _navigateToGoalsScreen(context),
            ),
          ),
          const SizedBox(height: 20),

          _wrapHomeSection(
            _buildGoalsSection(
              localReading: readingProvider,
              mushafReading: mushafReadingProvider,
              appColors: appColors,
              isThai: isThai,
            ),
          ),
          if (_activeHifzSession != null) ...[
            const SizedBox(height: 14),
            _wrapHomeSection(
              HomeHifzResumeBanner(
                snapshot: _activeHifzSession!,
                isThai: isThai,
                appColors: appColors,
                onResume: _resumeActiveHifzSession,
                onDiscard: _discardActiveHifzSession,
              ),
            ),
          ],
          const SizedBox(height: 20),

          _wrapHomeSection(
            HomeQuickSurahs(
              items: _quickLinks
                  .map(
                    (l) => HomeQuickSurahItem(
                      id: l.id,
                      surahNumber: l.surahNumber,
                      label: l.label,
                      isLocked: l.isLocked,
                    ),
                  )
                  .toList(),
              canPinMore: _quickLinks.where((l) => !l.isLocked).length < 8,
              isThai: isThai,
              appColors: appColors,
              onPinTap: _showAddQuickLinkSheet,
              onManageTap: _showManageQuickLinksSheet,
              onItemTap: (item) {
                final link = _quickLinks.firstWhere(
                  (l) => l.id == item.id,
                  orElse: () => CustomQuickLink(
                    id: item.id,
                    surahNumber: item.surahNumber,
                    label: item.label,
                    isLocked: item.isLocked,
                  ),
                );
                unawaited(_onQuickLinkTap(link));
              },
              onItemLongPress: (item) {
                final match =
                    _quickLinks.where((l) => l.id == item.id).firstOrNull;
                if (match != null && !match.isLocked) {
                  unawaited(_confirmDeleteQuickLink(match, isThai, appColors));
                }
              },
            ),
          ),
          const SizedBox(height: 20),

          _wrapHomeSection(
            _buildCommunitySection(
              settings: settings,
              appColors: appColors,
              isThai: isThai,
            ),
          ),
          const SizedBox(height: 12),

          _wrapHomeSection(_buildQuranThFooter(colorScheme, textTheme, isThai)),
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
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: Center(
        child: InkWell(
          onTap: () async {
            final uri = Uri.parse('https://quran-th.com');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_stories_outlined,
                  size: 13.5,
                  color: colorScheme.primary.withValues(alpha: 0.78),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Powered by quran-th.com',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSansThai(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.open_in_new_rounded,
                  size: 11.5,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
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
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: colors.primary,
          letterSpacing: -0.2,
        ),
      );
    } else if (tabIndex == 1) {
      return Text(
        isThai ? 'ซูเราะฮฺ' : 'Surah',
        style: GoogleFonts.notoSansThai(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: colors.primary,
          letterSpacing: -0.2,
        ),
      );
    } else if (tabIndex == 2) {
      return Text(
        isThai ? 'ที่คั่นหน้า & บันทึก' : 'Bookmarks & Notes',
        style: GoogleFonts.notoSansThai(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: colors.primary,
          letterSpacing: -0.2,
        ),
      );
    } else {
      return Text(
        isThai ? 'โปรไฟล์ & การตั้งค่า' : 'Profile & Settings',
        style: GoogleFonts.notoSansThai(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: colors.primary,
          letterSpacing: -0.2,
        ),
      );
    }
  }

  Widget _buildHeroSection({
    required LocalReadingProvider readingProvider,
    required MushafReadingProvider mushafReadingProvider,
    required bool isSignedIn,
    required bool isThai,
  }) {
    final verseRecent = _latestVerseLastRead(readingProvider);
    final mushafRecent = _latestMushafLastRead(mushafReadingProvider);
    final hasHistory = verseRecent != null || mushafRecent != null;
    final showMushaf = mushafRecent != null &&
        (verseRecent == null || mushafRecent.at.isAfter(verseRecent.at));

    final String modeBadge;
    final String contextTag;
    final String mainTitle;
    final String subDetail;
    final String arabicSurahName;
    final String surahNameLabel;
    final double? progressFraction;

    if (showMushaf) {
      final profile = mushafReadingProvider.profileById(mushafRecent.profileId);
      final rel = formatRelativeReadTime(mushafRecent.at, isThai: isThai);
      final pageData = getMedinaMushafPageData(mushafRecent.pageNumber);
      final sNum = pageData.isNotEmpty ? (pageData.first['surah'] ?? 1) : 1;
      final sId = sNum.toString();
      final arBare = offlineSurahNamesAr[sId] ?? '';
      final isCustomMushafGoal = profile != null &&
          !profile.isFreeRead &&
          profile.name.trim().toLowerCase() != 'free read';
      modeBadge = isThai ? 'อ่านต่อจากเดิม' : 'Continue Reading';
      contextTag = isCustomMushafGoal
          ? (isThai ? 'มุศหัฟ · ${profile.name}' : 'Mushaf · ${profile.name}')
          : (isThai ? 'มุศหัฟ' : 'Mushaf');
      mainTitle = isThai
          ? 'หน้า ${mushafRecent.pageNumber}'
          : 'Page ${mushafRecent.pageNumber}';
      subDetail = isThai ? 'จาก 604 หน้า · $rel' : 'of 604 pages · $rel';
      arabicSurahName = arBare.isNotEmpty ? 'سورة $arBare' : '';
      surahNameLabel = surahDisplayName(sId, isThai: isThai);
      progressFraction = (mushafRecent.pageNumber / 604).clamp(0.0, 1.0);
    } else if (verseRecent != null) {
      final sId = verseRecent.verse.surahId;
      final vId = verseRecent.verse.verseId;
      final sInt = int.tryParse(sId) ?? 1;
      final vInt = int.tryParse(vId) ?? 1;
      final pageNum = getMedinaMushafPageNumber(sInt, vInt);
      final arBare = offlineSurahNamesAr[sId] ?? '';
      final surahName = surahDisplayName(sId, isThai: isThai);
      final profile = verseRecent.profileId != null
          ? readingProvider.profileById(verseRecent.profileId!)
          : null;
      final rel = formatRelativeReadTime(verseRecent.at, isThai: isThai);
      final isCustomMeaningGoal =
          profile != null && !isFreeReadProfile(profile);
      modeBadge = isThai ? 'อ่านต่อจากเดิม' : 'Continue Reading';
      contextTag = isCustomMeaningGoal
          ? (isThai
              ? 'ความหมาย · ${profile.name}'
              : 'Meaning · ${profile.name}')
          : (isThai ? 'ความหมาย' : 'Meaning');
      mainTitle = surahName;
      subDetail = isThai
          ? 'หน้า $pageNum จาก 604 · $rel'
          : 'Page $pageNum of 604 · $rel';
      arabicSurahName = arBare.isNotEmpty ? 'سورة $arBare' : '';
      surahNameLabel = isThai ? 'อายะฮฺที่ $vId' : 'Ayah $vId';
      progressFraction = (pageNum / 604).clamp(0.0, 1.0);
    } else {
      final firstSurah = surahDisplayName('1', isThai: isThai);
      final arBare = offlineSurahNamesAr['1'] ?? 'الفَاتِـحَة';
      modeBadge = isThai ? 'เริ่มต้นอ่านอัลกุรอาน' : 'Start Reading Quran';
      contextTag = isThai ? 'หน้า 1 จาก 604' : 'Page 1 of 604';
      mainTitle = isThai ? '$firstSurah · อายะฮฺที่ 1' : '$firstSurah · Ayah 1';
      subDetail = isThai
          ? '7 อายะฮฺ · พร้อมคำแปลและตัฟซีรย่อ'
          : '7 Ayahs · With translation & tafsir';
      arabicSurahName = 'سورة $arBare';
      surahNameLabel = '';
      progressFraction = null;
    }

    return HomeContinueHero(
      hasHistory: hasHistory,
      isMushaf: showMushaf,
      modeBadge: modeBadge,
      contextTag: contextTag,
      mainTitle: mainTitle,
      subDetail: subDetail,
      arabicSurahName: arabicSurahName,
      surahNameLabel: surahNameLabel,
      progressFraction: progressFraction,
      isSignedIn: isSignedIn,
      isThai: isThai,
      onContinue: () => _openLastRead(readingProvider, mushafReadingProvider),
      onStartMeaning: () => _navigateToReading(
        context,
        '1',
        verseId: '1',
        saveToFreeReadOnly: true,
      ),
      onStartMushaf: () => _navigateToMushafFreeReadPage(1),
      onSwitchMode: hasHistory
          ? () {
              if (showMushaf) {
                final pageData =
                    getMedinaMushafPageData(mushafRecent.pageNumber);
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
                final sId = int.tryParse(verseRecent.verse.surahId) ?? 1;
                final vId = int.tryParse(verseRecent.verse.verseId) ?? 1;
                final page = getMedinaMushafPageNumber(sId, vId);
                unawaited(_navigateToMushafFreeReadPage(page));
              }
            }
          : null,
      onSignInTap: !isSignedIn ? () => AuthBottomSheet.show(context) : null,
    );
  }

  Widget _buildGoalsSection({
    required LocalReadingProvider localReading,
    required MushafReadingProvider mushafReading,
    required AppThemeColors appColors,
    required bool isThai,
  }) {
    final meaningGoals = localReading.profiles
        .where((p) => !isFreeReadProfile(p) && !p.isArchived)
        .toList();
    final mushafGoals = mushafReading.activeCustomProfiles;
    final totalActive = meaningGoals.length + mushafGoals.length;

    final items = <HomeGoalSnapshotItem>[];
    for (final profile in meaningGoals) {
      final startIdx = absoluteVerseIndex(profile.start);
      final endIdx =
          profile.target != null ? absoluteVerseIndex(profile.target!) : 6236;
      final currIdx = profile.furthestUnreadIndex;
      final total = (endIdx - startIdx + 1).clamp(1, 6236);
      final done = (currIdx - startIdx + 1).clamp(0, total);
      final remaining = (total - done).clamp(0, 6236);
      final progress = (done / total).clamp(0.0, 1.0);
      final sName = surahDisplayName(
        profile.furthestUnread.surahId,
        isThai: isThai,
      );
      items.add(
        HomeGoalSnapshotItem(
          modeLabel: isThai ? 'ความหมาย' : 'Meaning',
          isMushaf: false,
          title: profile.name,
          subtitle: isThai
              ? '$sName · อายะฮฺ ${profile.furthestUnread.verseId} · เหลือ $remaining อายะฮฺ'
              : '$sName · Ayah ${profile.furthestUnread.verseId} · $remaining left',
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
    }

    for (final profile in mushafGoals) {
      final total = (profile.targetPage - profile.startPage + 1).clamp(1, 604);
      final done =
          (profile.furthestUnreadPage - profile.startPage + 1).clamp(0, total);
      final remaining = (total - done).clamp(0, 604);
      final progress = (done / total).clamp(0.0, 1.0);
      items.add(
        HomeGoalSnapshotItem(
          modeLabel: isThai ? 'มุศหัฟ' : 'Mushaf',
          isMushaf: true,
          title: profile.name,
          subtitle: isThai
              ? 'ถึงหน้า ${profile.furthestUnreadPage} · เหลือ $remaining หน้า'
              : 'At Page ${profile.furthestUnreadPage} · $remaining left',
          progress: progress,
          onTap: () => _navigateToMushafProfile(
            profile,
            initialPage: profile.furthestUnreadPage,
          ),
        ),
      );
    }

    return HomeGoalsSnapshot(
      items: items,
      totalActiveCount: totalActive,
      isThai: isThai,
      appColors: appColors,
      onManageTap: () => _navigateToGoalsScreen(context),
    );
  }

  Widget _buildCommunitySection({
    required SettingsProvider settings,
    required AppThemeColors appColors,
    required bool isThai,
  }) {
    final featuredNote =
        _communityPool.isNotEmpty ? _communityPool.first : null;
    String translationText = '';
    if (featuredNote != null) {
      final verseObj = widget.repository.getVerse(
        featuredNote.surahId,
        featuredNote.verseId,
      );
      if (verseObj != null) {
        translationText = resolveVerseTranslationText(
          context: context,
          verseKey: '${featuredNote.surahId}:${featuredNote.verseId}',
          verse: verseObj,
          settings: settings,
        );
      }
    }

    return HomeCommunityPreview(
      featuredNote: featuredNote,
      translationText: translationText,
      authorName: featuredNote?.authorName ?? '',
      loading: _loadingCommunity,
      isThai: isThai,
      appColors: appColors,
      onViewAll: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                TadabburCommunityScreen(repository: widget.repository),
          ),
        ).then((_) => _loadCommunityPreview());
      },
      onOpenNote: (note) {
        final sName = surahDisplayName(note.surahId, isThai: isThai);
        _showTadabburDetailSheet(
          context,
          note,
          translationText,
          sName,
          isThai,
        );
      },
    );
  }

  Future<void> _confirmDeleteQuickLink(
    CustomQuickLink link,
    bool isThai,
    AppThemeColors appColors,
  ) async {
    final sName = surahDisplayName(link.surahNumber.toString(), isThai: isThai);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        title: Text(
          isThai ? 'นำซูเราะฮฺที่ปักหมุดออก?' : 'Unpin Surah?',
          style: GoogleFonts.notoSansThai(fontWeight: FontWeight.w700),
        ),
        content: Text(
          isThai
              ? 'ต้องการนำ "$sName" ออกจากซูเราะฮฺที่ปักหมุดหรือไม่'
              : 'Remove "$sName" from Pinned Surahs?',
          style: GoogleFonts.notoSansThai(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isThai ? 'ยกเลิก' : 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: appColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isThai ? 'นำออก' : 'Remove'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await _deleteQuickLink(link);
    }
  }

  static String formatRelativeReadTime(DateTime timestamp, {required bool isThai}) {
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

  String _formatRelativeReadTime(DateTime timestamp, {required bool isThai}) =>
      formatRelativeReadTime(timestamp, isThai: isThai);

  void _showMeaningHubModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ReaderHubSheet(
        isMushaf: false,
        repository: widget.repository,
        foundationRepository: _foundationRepository,
        onOpenMeaning: (surahId, verseId, {goalProfileId, saveToFreeReadOnly = true}) async {
          final localReading = context.read<LocalReadingProvider>();
          if (goalProfileId != null) {
            await localReading.setActiveProfile(goalProfileId);
          } else {
            final freeRead = localReading.freeReadProfile;
            if (freeRead != null) {
              await localReading.setActiveProfile(freeRead.id);
            }
          }
          if (!mounted) return;
          _navigateToReading(
            context,
            surahId,
            verseId: verseId,
            goalProfileId: goalProfileId,
            saveToFreeReadOnly: saveToFreeReadOnly,
          );
        },
        onOpenMushaf: (pageNumber, {profile, highlightedVerseKey}) async {},
      ),
    );
  }

  void _showMushafHubModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ReaderHubSheet(
        isMushaf: true,
        repository: widget.repository,
        foundationRepository: _foundationRepository,
        onOpenMeaning: (surahId, verseId, {goalProfileId, saveToFreeReadOnly = true}) async {},
        onOpenMushaf: (pageNumber, {profile, highlightedVerseKey}) async {
          if (profile != null) {
            await _navigateToMushafProfile(profile, initialPage: pageNumber);
          } else {
            await _navigateToMushafFreeReadPage(
              pageNumber,
              highlightedVerseKey: highlightedVerseKey,
            );
          }
        },
      ),
    );
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

  void _showManageQuickLinksSheet() {
    final isThai = context.read<SettingsProvider>().languageCode == 'th';
    final appColors = context.read<SettingsProvider>().getAppColors();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radius),
        ),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final customCount =
                _quickLinks.where((l) => !l.isLocked).length;
            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.72,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: appColors.borderSoft,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              isThai
                                  ? 'ซูเราะฮฺที่ปักหมุด'
                                  : 'Manage Pinned Surahs',
                              style: GoogleFonts.notoSansThai(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w700,
                                color: appColors.textStrong,
                              ),
                            ),
                          ),
                          if (customCount < 8)
                            TextButton.icon(
                              onPressed: () {
                                Navigator.pop(sheetCtx);
                                _showAddQuickLinkSheet();
                              },
                              icon: Icon(
                                Icons.add_rounded,
                                size: 17,
                                color: appColors.primary,
                              ),
                              label: Text(
                                isThai ? 'ปักหมุด' : 'Pin',
                                style: GoogleFonts.notoSansThai(
                                  fontWeight: FontWeight.w600,
                                  color: appColors.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _quickLinks.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            color: appColors.borderSoft.withValues(alpha: 0.6),
                          ),
                          itemBuilder: (_, idx) {
                            final link = _quickLinks[idx];
                            final sId = link.surahNumber.toString();
                            final sName =
                                surahDisplayName(sId, isThai: isThai);
                            final arName = offlineSurahNamesAr[sId] ?? '';
                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              leading: SizedBox(
                                width: 28,
                                child: Text(
                                  sId,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.notoSansThai(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: appColors.primary,
                                  ),
                                ),
                              ),
                              title: Text(
                                sName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.notoSansThai(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: appColors.textStrong,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (arName.isNotEmpty)
                                    Text(
                                      arName,
                                      textDirection: TextDirection.rtl,
                                      style: TextStyle(
                                        fontFamily: 'UthmanicHafs',
                                        fontSize: 16,
                                        color: appColors.mushafGold,
                                      ),
                                    ),
                                  if (!link.isLocked) ...[
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline_rounded,
                                        size: 19,
                                        color: appColors.danger,
                                      ),
                                      tooltip: isThai ? 'นำออก' : 'Remove',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () async {
                                        await _deleteQuickLink(link);
                                        if (ctx.mounted) setSheetState(() {});
                                      },
                                    ),
                                  ],
                                ],
                              ),
                              onTap: () {
                                Navigator.pop(sheetCtx);
                                unawaited(_onQuickLinkTap(link));
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
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
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radius),
        ),
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
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.radius),
            ),
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
                            borderRadius: BorderRadius.circular(AppTheme.radius),
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
                          ThaiTextProtectionProvider.protectSafe(
                            context,
                            translationText,
                          ),
                          locale: ThaiTextProtectionProvider.localeForText(
                            translationText,
                            forceThai: isThai,
                          ),
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
                        isThai ? 'บันทึกใคร่ครวญ (ตะดับบุร)' : 'Tadabbur Reflection',
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
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          ThaiTextProtectionProvider.protectSafe(
                            context,
                            note.noteText,
                          ),
                          locale: ThaiTextProtectionProvider.localeForText(
                            note.noteText,
                            forceThai: isThai,
                          ),
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

  static int? _parseSurahNumber(Object? raw) {
    int? parsed;
    if (raw is int) {
      parsed = raw;
    } else if (raw is num) {
      parsed = raw.toInt();
    } else if (raw is String) {
      parsed = int.tryParse(raw.trim());
    }
    if (parsed == null || parsed < 1 || parsed > 114) return null;
    return parsed;
  }

  static CustomQuickLink? tryFromJson(Map<String, dynamic> json) {
    final surahNumber = _parseSurahNumber(
      json['surahNumber'] ?? json['surah_number'],
    );
    if (surahNumber == null) return null;
    final rawLocked = json['isLocked'] ?? json['is_locked'];
    return CustomQuickLink(
      id: json['id']?.toString(),
      surahNumber: surahNumber,
      label: json['label']?.toString() ?? '',
      isLocked: rawLocked is bool ? rawLocked : false,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }

  static CustomQuickLink? tryFromSupabase(Map<String, dynamic> row) {
    final rawId = row['id']?.toString().trim() ?? '';
    final surahNumber = _parseSurahNumber(
      row['surah_number'] ?? row['surahNumber'],
    );
    if (rawId.isEmpty || surahNumber == null) return null;
    return CustomQuickLink(
      id: rawId,
      surahNumber: surahNumber,
      label: row['label']?.toString() ?? '',
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? ''),
    );
  }

  factory CustomQuickLink.fromJson(Map<String, dynamic> json) {
    final parsed = tryFromJson(json);
    if (parsed == null) {
      throw const FormatException('Invalid CustomQuickLink JSON');
    }
    return parsed;
  }

  factory CustomQuickLink.fromSupabase(Map<String, dynamic> row) {
    final parsed = tryFromSupabase(row);
    if (parsed == null) {
      throw const FormatException('Invalid CustomQuickLink Supabase row');
    }
    return parsed;
  }

  static String _fallbackId(int surahNumber, String label, bool isLocked) {
    if (isLocked && surahNumber == 67) return 'system_mulk';
    if (isLocked && surahNumber == 18) return 'system_kahf';
    if (isLocked && surahNumber == 36) return 'system_yasin';
    if (isLocked && surahNumber == 78) return 'system_naba';
    final safeLabel = base64Url.encode(utf8.encode(label)).replaceAll('=', '');
    return 'ql_${surahNumber}_$safeLabel';
  }
}

class _ReaderHubSheet extends StatefulWidget {
  final bool isMushaf;
  final QuranRepository repository;
  final QuranFoundationRepository foundationRepository;
  final Future<void> Function(
    String surahId,
    String verseId, {
    String? goalProfileId,
    bool saveToFreeReadOnly,
  }) onOpenMeaning;
  final Future<void> Function(
    int pageNumber, {
    MushafProfile? profile,
    String? highlightedVerseKey,
  }) onOpenMushaf;

  const _ReaderHubSheet({
    required this.isMushaf,
    required this.repository,
    required this.foundationRepository,
    required this.onOpenMeaning,
    required this.onOpenMushaf,
  });

  @override
  State<_ReaderHubSheet> createState() => _ReaderHubSheetState();
}

class _ReaderHubSheetState extends State<_ReaderHubSheet> {
  late int _selectedSurah;
  late int _selectedAyah;

  @override
  void initState() {
    super.initState();
    if (widget.isMushaf) {
      final mushafReading = context.read<MushafReadingProvider>();
      final recent = mushafReading.recentReadings.isNotEmpty
          ? mushafReading.recentReadings.first
          : null;
      if (recent != null) {
        final surahs = getSurahsOnMedinaPage(recent.pageNumber);
        _selectedSurah = surahs.isNotEmpty ? surahs.first : 1;
        _selectedAyah = 1;
      } else {
        _selectedSurah = 1;
        _selectedAyah = 1;
      }
    } else {
      final localReading = context.read<LocalReadingProvider>();
      final recent = localReading.recentReadings.isNotEmpty
          ? localReading.recentReadings.first
          : null;
      if (recent != null) {
        _selectedSurah = int.tryParse(recent.verse.surahId) ?? 1;
        _selectedAyah = int.tryParse(recent.verse.verseId) ?? 1;
      } else {
        _selectedSurah = 1;
        _selectedAyah = 1;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final colors = settings.getAppColors();
    final isThai = settings.isThai;
    final readingProvider = context.watch<LocalReadingProvider>();
    final mushafReadingProvider = context.watch<MushafReadingProvider>();
    final primaryAccent = widget.isMushaf
        ? const Color(0xFF8A6530)
        : const Color(0xFF0E5A4A);

    // Active goal resolution
    final MushafProfile? mushafGoal;
    final LocalReadingProfile? meaningGoal;
    if (widget.isMushaf) {
      final goals = mushafReadingProvider.profiles
          .where((p) => !p.isFreeRead && !p.isArchived)
          .toList();
      mushafGoal = goals.isNotEmpty ? goals.first : null;
      meaningGoal = null;
    } else {
      mushafGoal = null;
      final active = readingProvider.activeProfiles
          .where((p) => !isFreeReadProfile(p) && !p.isArchived)
          .toList();
      if (active.isNotEmpty) {
        meaningGoal = active.first;
      } else {
        final all = readingProvider.profiles
            .where((p) => !isFreeReadProfile(p) && !p.isArchived)
            .toList();
        meaningGoal = all.isNotEmpty ? all.first : null;
      }
    }

    // Recent reads resolution
    final recentMeaning = readingProvider.recentReadings.take(5).toList();
    final recentMushaf = mushafReadingProvider.recentReadings.take(5).toList();
    final bool hasRecents = widget.isMushaf
        ? recentMushaf.isNotEmpty
        : recentMeaning.isNotEmpty;

    final totalVerses = qcf.getVerseCount(_selectedSurah);
    final surahName = surahDisplayName(_selectedSurah.toString(), isThai: isThai);
    final resolvedPage = getMedinaMushafPageNumber(_selectedSurah, _selectedAyah);

    final bool hasGoal = widget.isMushaf ? mushafGoal != null : meaningGoal != null;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: colors.borderSoft),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 4, bottom: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.borderSoft,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: primaryAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      widget.isMushaf
                          ? Icons.auto_stories_rounded
                          : Icons.menu_book_rounded,
                      color: primaryAccent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isMushaf
                              ? (isThai ? 'มุศหัฟมะดีนะฮฺ' : 'Medina Mushaf')
                              : (isThai ? 'อ่านฉบับแปล' : 'Meaning Reader'),
                          style: GoogleFonts.notoSansThai(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colors.textStrong,
                          ),
                        ),
                        Text(
                          widget.isMushaf
                              ? (isThai
                                  ? 'เป้าหมาย • ประวัติล่าสุด • เลือกหน้า'
                                  : 'Goals • Recents • Select Page')
                              : (isThai
                                  ? 'เป้าหมาย • ประวัติล่าสุด • เลือกอายะฮฺ'
                                  : 'Goals • Recents • Select Ayah'),
                          style: GoogleFonts.notoSansThai(
                            fontSize: 11,
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: colors.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Section 1: Active Goal Card ──
              if (hasGoal) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    border: Border.all(
                      color: primaryAccent.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: primaryAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.track_changes_rounded,
                          color: primaryAccent,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: primaryAccent.withValues(alpha: 0.14),
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusSm),
                              ),
                              child: Text(
                                isThai ? 'อ่านต่อตามเป้าหมาย' : 'Continue Goal',
                                style: GoogleFonts.notoSansThai(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: primaryAccent,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.isMushaf
                                  ? (mushafGoal?.name ?? '')
                                  : (meaningGoal?.name ?? ''),
                              style: GoogleFonts.notoSansThai(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: colors.textStrong,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.isMushaf
                                  ? (mushafGoal != null
                                      ? (isThai
                                          ? 'ถึงหน้าที่ ${mushafGoal.furthestUnreadPage} (เป้า ${mushafGoal.startPage}–${mushafGoal.targetPage})'
                                          : 'At page ${mushafGoal.furthestUnreadPage} (Target ${mushafGoal.startPage}–${mushafGoal.targetPage})')
                                      : '')
                                  : (meaningGoal != null
                                      ? '${surahDisplayName(meaningGoal.furthestUnread.surahId, isThai: isThai)} • ${isThai ? 'อายะฮฺ' : 'Ayah'} ${meaningGoal.furthestUnread.verseId}'
                                      : ''),
                              style: GoogleFonts.notoSansThai(
                                fontSize: 12,
                                color: colors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryAccent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          if (widget.isMushaf && mushafGoal != null) {
                            widget.onOpenMushaf(mushafGoal.furthestUnreadPage, profile: mushafGoal);
                          } else if (!widget.isMushaf && meaningGoal != null) {
                            widget.onOpenMeaning(
                              meaningGoal.furthestUnread.surahId,
                              meaningGoal.furthestUnread.verseId,
                              goalProfileId: meaningGoal.id,
                              saveToFreeReadOnly: false,
                            );
                          }
                        },
                        child: Text(
                          isThai ? 'อ่านต่อ' : 'Continue',
                          style: GoogleFonts.notoSansThai(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Section 2: Recent Reads ──
              if (hasRecents) ...[
                Text(
                  isThai ? 'อ่านล่าสุด' : 'Recent Reads',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.textStrong,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: colors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    border: Border.all(color: colors.borderSoft),
                  ),
                  child: Column(
                    children: widget.isMushaf
                        ? recentMushaf.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final r = entry.value;
                            final surahs = getSurahsOnMedinaPage(r.pageNumber);
                            final sName = surahs.isNotEmpty
                                ? surahDisplayName(surahs.first.toString(), isThai: isThai)
                                : '';
                            final relative = _HomeScreenState.formatRelativeReadTime(
                              r.updatedAt,
                              isThai: isThai,
                            );
                            return Column(
                              children: [
                                if (idx > 0)
                                  Divider(height: 1, color: colors.borderSoft),
                                ListTile(
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  leading: Icon(
                                    Icons.history_rounded,
                                    size: 20,
                                    color: primaryAccent,
                                  ),
                                  title: Text(
                                    '${isThai ? "หน้า" : "Page"} ${r.pageNumber}${sName.isNotEmpty ? " • $sName" : ""}',
                                    style: GoogleFonts.notoSansThai(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: colors.textStrong,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        relative,
                                        style: GoogleFonts.notoSansThai(
                                          fontSize: 11,
                                          color: colors.textMuted,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        size: 16,
                                        color: colors.textMuted,
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    widget.onOpenMushaf(r.pageNumber);
                                  },
                                ),
                              ],
                            );
                          }).toList()
                        : recentMeaning.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final r = entry.value;
                            final sName = surahDisplayName(r.verse.surahId, isThai: isThai);
                            final relative = _HomeScreenState.formatRelativeReadTime(
                              r.readAt,
                              isThai: isThai,
                            );
                            return Column(
                              children: [
                                if (idx > 0)
                                  Divider(height: 1, color: colors.borderSoft),
                                ListTile(
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  leading: Icon(
                                    Icons.history_rounded,
                                    size: 20,
                                    color: primaryAccent,
                                  ),
                                  title: Text(
                                    '$sName • ${isThai ? "อายะฮฺ" : "Ayah"} ${r.verse.verseId}',
                                    style: GoogleFonts.notoSansThai(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: colors.textStrong,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        relative,
                                        style: GoogleFonts.notoSansThai(
                                          fontSize: 11,
                                          color: colors.textMuted,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        size: 16,
                                        color: colors.textMuted,
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    widget.onOpenMeaning(
                                      r.verse.surahId,
                                      r.verse.verseId,
                                      saveToFreeReadOnly: true,
                                    );
                                  },
                                ),
                              ],
                            );
                          }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Section 3: Select Surah & Ayah ──
              Text(
                isThai ? 'เลือกซูเราะฮฺและอายะฮฺ' : 'Choose Surah & Ayah',
                style: GoogleFonts.notoSansThai(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colors.textStrong,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  border: Border.all(color: colors.borderSoft),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Surah Picker Tile
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () async {
                        final picked = await SurahPickerSheet.show(
                          context,
                          selectedSurah: _selectedSurah,
                          title: isThai ? 'เลือกซูเราะฮฺ' : 'Select Surah',
                        );
                        if (picked != null && mounted) {
                          setState(() {
                            _selectedSurah = picked;
                            final maxV = qcf.getVerseCount(_selectedSurah);
                            if (_selectedAyah > maxV) _selectedAyah = 1;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colors.borderSoft),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.format_list_numbered_rounded, size: 18, color: primaryAccent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isThai ? 'ซูเราะฮฺ' : 'Surah',
                                    style: GoogleFonts.notoSansThai(
                                      fontSize: 11,
                                      color: colors.textMuted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '$_selectedSurah. $surahName',
                                    style: GoogleFonts.notoSansThai(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: colors.textStrong,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.unfold_more_rounded, size: 20, color: colors.textMuted),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Ayah Selector Row
                    Row(
                      children: [
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: colors.surface,
                            side: BorderSide(color: colors.borderSoft),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: Icon(
                            Icons.remove_rounded,
                            size: 18,
                            color: _selectedAyah > 1 ? primaryAccent : colors.textMuted,
                          ),
                          onPressed: _selectedAyah > 1
                              ? () => setState(() => _selectedAyah--)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: colors.borderSoft),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _selectedAyah.clamp(1, totalVerses),
                                isExpanded: true,
                                dropdownColor: colors.surface,
                                icon: Icon(Icons.arrow_drop_down_rounded, color: primaryAccent),
                                items: List.generate(totalVerses, (i) => i + 1).map((a) {
                                  return DropdownMenuItem<int>(
                                    value: a,
                                    child: Text(
                                      isThai
                                          ? 'อายะฮฺที่ $a (จาก $totalVerses)'
                                          : 'Ayah $a of $totalVerses',
                                      style: GoogleFonts.notoSansThai(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: colors.textStrong,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedAyah = val);
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: colors.surface,
                            side: BorderSide(color: colors.borderSoft),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: Icon(
                            Icons.add_rounded,
                            size: 18,
                            color: _selectedAyah < totalVerses ? primaryAccent : colors.textMuted,
                          ),
                          onPressed: _selectedAyah < totalVerses
                              ? () => setState(() => _selectedAyah++)
                              : null,
                        ),
                      ],
                    ),

                    // Mushaf Page Indicator (if Mushaf)
                    if (widget.isMushaf) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8A6530).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF8A6530).withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.auto_stories_rounded, size: 14, color: Color(0xFF8A6530)),
                            const SizedBox(width: 6),
                            Text(
                              isThai
                                  ? 'ตรงกับมุศหัฟหน้าที่ $resolvedPage (จาก 604)'
                                  : 'Corresponds to Mushaf Page $resolvedPage of 604',
                              style: GoogleFonts.notoSansThai(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF8A6530),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Primary Action Button
                    SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryAccent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          if (widget.isMushaf) {
                            widget.onOpenMushaf(
                              resolvedPage,
                              highlightedVerseKey: '$_selectedSurah:$_selectedAyah',
                            );
                          } else {
                            widget.onOpenMeaning(
                              '$_selectedSurah',
                              '$_selectedAyah',
                              saveToFreeReadOnly: true,
                            );
                          }
                        },
                        icon: Icon(
                          widget.isMushaf
                              ? Icons.auto_stories_rounded
                              : Icons.menu_book_rounded,
                          size: 18,
                        ),
                        label: Text(
                          widget.isMushaf
                              ? (isThai
                                  ? 'เปิดมุศหัฟ (หน้า $resolvedPage)'
                                  : 'Open Mushaf (Page $resolvedPage)')
                              : (isThai
                                  ? 'เปิดอ่านฉบับแปล ($_selectedSurah:$_selectedAyah)'
                                  : 'Open Meaning Reader ($_selectedSurah:$_selectedAyah)'),
                          style: GoogleFonts.notoSansThai(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
