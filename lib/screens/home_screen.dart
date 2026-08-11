import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:qcf_quran/qcf_quran.dart' as qcf;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/quran_foundation_repository.dart';
import '../data/quran_repository.dart';
import '../models/mushaf_models.dart';
import '../providers/local_reading_provider.dart';
import '../providers/mushaf_reading_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/supabase_provider.dart';
import '../providers/notes_provider.dart';
import '../providers/stats_provider.dart';
import '../shared/shared.dart';
import '../theme/app_theme.dart';
import 'mushaf_reader_screen.dart';
import 'reading_screen.dart';
import 'settings_screen.dart';
import 'bookmarks_screen.dart';
import 'profile_screen.dart';
import 'browse_screen.dart';
import 'hifz_landing_screen.dart';

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
                  fontWeight: FontWeight.w800,
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

class _GoalRangeSection extends StatelessWidget {
  final String title;
  final AppThemeColors colors;
  final List<Widget> children;

  const _GoalRangeSection({
    required this.title,
    required this.colors,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: GoogleFonts.notoSansThai(
              color: colors.textStrong,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
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

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final QuranFoundationRepository _foundationRepository =
      QuranFoundationRepository();
  late final AnimationController _lastReadGlowController;
  int _selectedTabIndex =
      0; // 0: Meaningful Read, 1: Mushaf Read, 2: Quick Links
  int _navIndex = 0;
  bool _isInit = false;

  final ScrollController _meaningfulCardsScrollController = ScrollController();
  final ScrollController _mushafCardsScrollController = ScrollController();
  StreamSubscription<AuthState>? _quickLinkAuthSubscription;
  String? _quickLinksLoadedForUser;

  final List<Map<String, dynamic>> _tabs = [
    {'title': "meaningful_read", 'icon': Icons.menu_book},
    {'title': "mushaf_read", 'icon': Icons.import_contacts},
  ];

  List<CustomQuickLink> _quickLinks = [];

  // Juz boundary data (shared with Browse screen)
  static const List<List<int>> _juzStarts = [
    [1, 1],
    [2, 142],
    [2, 253],
    [3, 93],
    [4, 24],
    [4, 148],
    [5, 82],
    [6, 111],
    [7, 88],
    [8, 41],
    [9, 93],
    [11, 6],
    [12, 53],
    [15, 1],
    [17, 1],
    [18, 75],
    [21, 1],
    [23, 1],
    [25, 21],
    [27, 56],
    [29, 46],
    [33, 31],
    [36, 28],
    [39, 32],
    [41, 47],
    [46, 1],
    [51, 31],
    [58, 1],
    [67, 1],
    [78, 1],
  ];

  @override
  void initState() {
    super.initState();
    _lastReadGlowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _isInit = widget.repositoryReady;
    _loadQuickLinks();
    _quickLinkAuthSubscription = Supabase.instance.client.auth.onAuthStateChange
        .listen((data) {
          final userId = data.session?.user.id;
          if (userId == _quickLinksLoadedForUser) return;
          unawaited(_loadQuickLinks());
        });
    _searchController.addListener(() {
      setState(() {});
    });
    if (!_isInit) {
      _initApp();
    }
  }

  Future<void> _initApp() async {
    await widget.repository.init();
    if (mounted) {
      setState(() {
        _isInit = true;
      });
      unawaited(_triggerAutoSync());
    }
  }

  Future<void> _loadQuickLinks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? linksJson = prefs.getString('custom_quick_links');
    List<CustomQuickLink> links;
    if (linksJson != null) {
      final List<dynamic> decoded = jsonDecode(linksJson);
      links = decoded
          .map((e) => CustomQuickLink.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      links = _defaultQuickLinks();
    }

    links = _normalizeQuickLinks(links);

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      links = await _syncQuickLinksWithSupabase(userId, links);
    }
    _quickLinksLoadedForUser = userId;

    if (!mounted) return;
    setState(() {
      _quickLinks = links;
    });
    await _saveQuickLinks(syncRemote: userId == null);
  }

  List<CustomQuickLink> _defaultQuickLinks() => [
    CustomQuickLink(
      id: 'system_mulk',
      surahNumber: 67,
      label: "Read every night.",
      isLocked: true,
    ),
    CustomQuickLink(
      id: 'system_kahf',
      surahNumber: 18,
      label: "Read every Friday.",
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
    _quickLinks = _normalizeQuickLinks(_quickLinks);
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(
      _quickLinks.map((e) => e.toJson()).toList(),
    );
    await prefs.setString('custom_quick_links', encoded);

    if (!syncRemote) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    await _syncQuickLinksWithSupabase(userId, _quickLinks);
  }

  Future<List<CustomQuickLink>> _syncQuickLinksWithSupabase(
    String userId,
    List<CustomQuickLink> localLinks,
  ) async {
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

      final mergedById = <String, CustomQuickLink>{};
      for (final link in _normalizeQuickLinks(localLinks)) {
        mergedById[link.id] = link;
      }
      for (final remote in remoteLinks) {
        final local = mergedById[remote.id];
        if (local == null || remote.updatedAt.isAfter(local.updatedAt)) {
          mergedById[remote.id] = remote;
        }
      }

      final merged = mergedById.values.toList();
      final customLinks = merged.where((link) => !link.isLocked).toList();
      for (var index = 0; index < customLinks.length; index++) {
        final link = customLinks[index];
        await client.from('custom_quick_links').upsert({
          'id': link.id,
          'user_id': userId,
          'surah_number': link.surahNumber,
          'label': link.label,
          'sort_order': index,
          'created_at': link.createdAt.toIso8601String(),
          'updated_at': link.updatedAt.toIso8601String(),
        }, onConflict: 'id,user_id');
      }

      return merged;
    } catch (e) {
      debugPrint('Error syncing quick links with Supabase: $e');
      return _normalizeQuickLinks(localLinks);
    }
  }

  Future<void> _deleteQuickLink(CustomQuickLink link) async {
    setState(() => _quickLinks.removeWhere((item) => item.id == link.id));
    await _saveQuickLinks(syncRemote: false);

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await Supabase.instance.client
          .from('custom_quick_links')
          .delete()
          .eq('user_id', userId)
          .eq('id', link.id);
    } catch (e) {
      debugPrint('Error deleting quick link from Supabase: $e');
    }
  }

  @override
  void dispose() {
    _quickLinkAuthSubscription?.cancel();
    _lastReadGlowController.dispose();
    _searchController.dispose();
    _meaningfulCardsScrollController.dispose();
    _mushafCardsScrollController.dispose();
    super.dispose();
  }

  void _handleBackNavigation() {
    if (_searchController.text.isNotEmpty) {
      _searchController.clear();
      return;
    }

    if (_navIndex != 0) {
      setState(() => _navIndex = 0);
      return;
    }

    SystemNavigator.pop();
  }

  void _resetCardsForTab(int tabIndex) {
    final controller = switch (tabIndex) {
      0 => _meaningfulCardsScrollController,
      1 => _mushafCardsScrollController,
      _ => null,
    };
    if (controller == null || !controller.hasClients) return;
    controller.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  double _goalCardWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return math.min(width * 0.82, 420);
  }

  Widget _buildGoalCarouselHint(ColorScheme colorScheme, int itemCount) {
    if (itemCount < 2) return const SizedBox.shrink();

    final visibleDots = math.min(itemCount, 3);

    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 24, right: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ...List.generate(visibleDots, (index) {
            final isFirst = index == 0;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: isFirst ? 18 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: isFirst
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(16),
              ),
            );
          }),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right,
            size: 18,
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  void _navigateToReading(
    BuildContext context,
    String surahId, {
    String? verseId,
    int? verseIndex,
    bool saveToFreeReadOnly = false,
    String? shortcutId,
  }) {
    // Capture the intended goal profile BEFORE opening the reader so it can
    // be used as a fallback in case switchToFreeReadIfOutside fires during
    // the session and changes the activeProfile.
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
    final profile = await mushafProvider.openUnifiedFreeRead();
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

  void _navigateToMushafProfile(MushafProfile profile, {int? initialPage}) {
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
    // Intended goal profile captured before opening the reader, used as
    // fallback if the result returns a free-read profile (e.g. because
    // switchToFreeReadIfOutside fired during surah navigation).
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

        // If the result resolved to a free-read (or is missing) but we had
        // an explicit custom goal, restore it so the entry carries the goal.
        if ((profile == null || isFreeReadProfile(profile)) &&
            fallbackProfileId != null &&
            !saveToFreeReadOnly) {
          final fallback = localReading.profileById(fallbackProfileId);
          if (fallback != null && !isFreeReadProfile(fallback)) {
            profile = fallback;
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

  LocalRecentReading? _latestVerseRecent(LocalReadingProvider provider) {
    LocalRecentReading? latest;
    for (final reading in provider.recentReadings) {
      if (latest == null ||
          _normalizeDate(
            reading.readAt,
          ).isAfter(_normalizeDate(latest.readAt))) {
        latest = reading;
      }
    }
    return latest;
  }

  MushafRecentReading? _latestMushafRecent(MushafReadingProvider provider) {
    MushafRecentReading? latest;
    for (final reading in provider.recentReadings) {
      if (latest == null ||
          _normalizeDate(
            reading.updatedAt,
          ).isAfter(_normalizeDate(latest.updatedAt))) {
        latest = reading;
      }
    }
    return latest;
  }

  ({VerseRef verse, String? profileId, DateTime at})? _latestVerseLastRead(
    LocalReadingProvider provider,
  ) {
    ({VerseRef verse, String? profileId, DateTime at})? latest;

    for (final reading in provider.recentReadings) {
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
      final profile = verseRecent.profileId == null
          ? null
          : localReading.profileById(verseRecent.profileId!);
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

  // ignore: unused_element
  Widget _buildLastReadPill(
    ColorScheme colorScheme,
    TextTheme textTheme,
    LocalReadingProvider localReading,
    MushafReadingProvider mushafReading,
  ) {
    final verseRecent = _latestVerseRecent(localReading);
    final mushafRecent = _latestMushafRecent(mushafReading);
    final showMushaf =
        mushafRecent != null &&
        (verseRecent == null ||
            mushafRecent.updatedAt.isAfter(verseRecent.readAt));

    final String detail;
    final IconData icon;
    if (showMushaf) {
      detail =
          '${context.tr('mushaf_read')} • ${context.tr('page')} ${mushafRecent.pageNumber}';
      icon = Icons.import_contacts;
    } else if (verseRecent != null) {
      final surahName = widget.repository.getSurahName(
        verseRecent.verse.surahId,
      );
      detail =
          '${context.tr('verse_by_verse')} • $surahName ${context.tr('ayah')} ${verseRecent.verse.verseId}';
      icon = Icons.menu_book;
    } else {
      detail =
          '${context.tr('verse_by_verse')} • ${widget.repository.getSurahName('1')} ${context.tr('ayah')} 1';
      icon = Icons.menu_book;
    }

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: () => _openLastRead(localReading, mushafReading),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.tr('continue_your_last_read'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios,
                size: 18,
                color: colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedLastReadPill(
    ColorScheme colorScheme,
    TextTheme textTheme,
    LocalReadingProvider localReading,
    MushafReadingProvider mushafReading,
  ) {
    final verseRecent = _latestVerseLastRead(localReading);
    final mushafRecent = _latestMushafLastRead(mushafReading);
    final showMushaf =
        mushafRecent != null &&
        (verseRecent == null || mushafRecent.at.isAfter(verseRecent.at));

    final String detail;
    final IconData icon;
    if (showMushaf) {
      detail =
          '${context.tr('mushaf_read')} - ${context.tr('page')} ${mushafRecent.pageNumber}';
      icon = Icons.import_contacts;
    } else if (verseRecent != null) {
      final surahName = widget.repository.getSurahName(
        verseRecent.verse.surahId,
      );
      detail =
          '${context.tr('meaningful_read')} - $surahName ${context.tr('ayah')} ${verseRecent.verse.verseId}';
      icon = Icons.menu_book;
    } else {
      detail =
          '${context.tr('meaningful_read')} - ${widget.repository.getSurahName('1')} ${context.tr('ayah')} 1';
      icon = Icons.menu_book;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rainbowColors = isDark
        ? [
            const Color(0xFF6366F1), // Indigo
            const Color(0xFFEC4899), // Pink
            const Color(0xFFF59E0B), // Amber
            const Color(0xFF10B981), // Emerald
            const Color(0xFF3B82F6), // Blue
            const Color(0xFF6366F1), // Indigo
          ]
        : [
            const Color(0xFF4F46E5), // Indigo
            const Color(0xFFDB2777), // Pink
            const Color(0xFFD97706), // Amber
            const Color(0xFF059669), // Emerald
            const Color(0xFF2563EB), // Blue
            const Color(0xFF4F46E5), // Indigo
          ];

    final onCardBg = Colors.white;

    return AnimatedBuilder(
      animation: _lastReadGlowController,
      builder: (context, child) {
        final double value = _lastReadGlowController.value;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment(-2.0 + (value * 3.0), -1.0),
              end: Alignment(1.0 + (value * 3.0), 1.0),
              colors: rainbowColors,
            ),
            boxShadow: [
              BoxShadow(
                color: (isDark ? const Color(0xFF6366F1) : const Color(0xFF4F46E5))
                    .withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _openLastRead(localReading, mushafReading),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Icon(icon, color: onCardBg, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            context.tr('continue_your_last_read'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.notoSansThai(
                              color: onCardBg.withValues(alpha: 0.85),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.notoSansThai(
                              color: onCardBg,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.play_arrow_rounded,
                        size: 24,
                        color: isDark ? const Color(0xFF6366F1) : const Color(0xFF4F46E5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _chooseBrowseDestination(
    String surahId,
    String verseId, {
    String? shortcutId,
  }) async {
    final colorScheme = Theme.of(context).colorScheme;
    final surah = int.tryParse(surahId) ?? 1;
    final verse = int.tryParse(verseId) ?? 1;
    final pageNumber = qcf.getPageNumber(surah, verse);

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
                  fontWeight: FontWeight.w900,
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
                      title: 'ท่องจำฮิฟซ์',
                      subtitle: 'Hifz Memorize',
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
      await _navigateToMushafFreeReadPage(pageNumber, shortcutId: shortcutId);
      return;
    }
    if (destination == 'hifz') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HifzLandingScreen(
            quranRepository: widget.repository,
            foundationRepository: _foundationRepository,
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

  Future<Map<String, String>> _fetchArabicPreviewForPage(int page) async {
    try {
      final mushafPage = await _foundationRepository.fetchPage(
        mushafId: 2,
        pageNumber: page,
      );
      if (mushafPage.verses.isEmpty) return {};
      final firstVerse = mushafPage.verses.first;

      final arabicText = await widget.repository.fetchArabicVerse(
        firstVerse.surahId.toString(),
        firstVerse.verseId.toString(),
      );
      return {
        'arabic': arabicText,
        'surahId': firstVerse.surahId.toString(),
        'verseId': firstVerse.verseId.toString(),
      };
    } catch (e) {
      return {};
    }
  }

  Widget _buildDailyReadTracker(
    ColorScheme colorScheme,
    StatsProvider statsProvider,
  ) {
    final now = DateTime.now();

    // Compute the past 7 days ending today
    final daysList = List.generate(7, (index) {
      final date = now.subtract(Duration(days: 6 - index));
      return date;
    });

    final dayLabels = [
      context.tr('weekday_mon_short'),
      context.tr('weekday_tue_short'),
      context.tr('weekday_wed_short'),
      context.tr('weekday_thu_short'),
      context.tr('weekday_fri_short'),
      context.tr('weekday_sat_short'),
      context.tr('weekday_sun_short'),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16, left: 24, right: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (index) {
          final date = daysList[index];
          final isToday = index == 6; // Last item is today
          final isRead = statsProvider.hasReadOn(date);

          Color circleColor;
          if (isRead) {
            circleColor = Colors.green;
          } else if (isToday) {
            circleColor = colorScheme.primary;
          } else {
            circleColor = colorScheme.outlineVariant;
          }

          final dayLabel =
              dayLabels[date.weekday - 1]; // weekday is 1(Mon) to 7(Sun)

          return Column(
            children: [
              Text(
                dayLabel,
                style: GoogleFonts.notoSansThai(
                  fontSize: isToday ? 11 : 9,
                  fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                  color: isToday
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: isToday ? 28 : 20,
                height: isToday ? 28 : 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: circleColor.withValues(alpha: isToday ? 0.2 : 0.1),
                  border: Border.all(
                    color: circleColor,
                    width: isToday ? 2.0 : 1.0,
                  ),
                ),
                child: isToday
                    ? (isRead
                          ? const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.green,
                            )
                          : Icon(
                              Icons.menu_book,
                              size: 14,
                              color: colorScheme.primary,
                            ))
                    : (isRead
                          ? const Icon(
                              Icons.check,
                              size: 12,
                              color: Colors.green,
                            )
                          : null), // We can omit the red X or add it if needed. Let's just leave it blank if not read, or maybe a small dot.
              ),
            ],
          );
        }),
      ),
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

    if (!_isInit) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: CircularProgressIndicator(color: colorScheme.primary),
          ),
        ),
      );
    }

    final isSearching = _searchController.text.isNotEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBackNavigation();
        }
      },
      child: Scaffold(
        bottomNavigationBar: NavigationBar(
          height: 64,
          selectedIndex: _navIndex,
          onDestinationSelected: (index) {
            setState(() => _navIndex = index);
          },
          elevation: 0,
          indicatorColor: colorScheme.secondaryContainer.withValues(alpha: 0.5),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: settings.languageCode == 'th' ? 'หน้าแรก' : 'Home',
            ),
            NavigationDestination(
              icon: const Icon(Icons.format_list_bulleted_outlined),
              selectedIcon: const Icon(Icons.format_list_bulleted),
              label: settings.languageCode == 'th' ? 'ซูเราะฮฺ' : 'Surah',
            ),
            NavigationDestination(
              icon: const Icon(Icons.bookmark_outline),
              selectedIcon: const Icon(Icons.bookmark),
              label: settings.languageCode == 'th' ? 'บุ๊กมาร์ก' : 'Bookmark',
            ),
            NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings),
              label: settings.languageCode == 'th' ? 'ตั้งค่า' : 'Settings',
            ),
          ],
        ),
        body: IndexedStack(
          index: _navIndex,
          children: [
            // 0: Home
            SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverList(
                    delegate: SliverChildListDelegate([
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 24,
                          right: 24,
                          top: 24,
                          bottom: 16,
                        ),
                        child: Column(
                          children: [
                            // ROW 1: THE WELCOME TYPOGRAPHY HEADER
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        context.tr('salam'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: textTheme.labelMedium?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${Provider.of<SupabaseProvider>(context).displayName} 🤝',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: textTheme.headlineMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme.primary,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const ProfileScreen(),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(24),
                                  child: CircleAvatar(
                                    radius: 24,
                                    backgroundColor:
                                        colorScheme.surfaceContainerHighest,
                                    child: Icon(
                                      Icons.person_outline_rounded,
                                      color: colorScheme.onSurface,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),

                            _buildAnimatedLastReadPill(
                              colorScheme,
                              textTheme,
                              readingProvider,
                              mushafReadingProvider,
                            ),
                          ],
                        ),
                      ),

                      if (!isSearching) ...[
                        // Daily Read Checks Tracker
                        _buildDailyReadTracker(colorScheme, statsProvider),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: _buildReadingModeCapsule(
                            colorScheme,
                            textTheme,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ]),
                  ),

                  // Dynamic Dock Content as Slivers
                  if (isSearching)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      sliver: _buildSearchResultsSliver(colorScheme, textTheme),
                    )
                  else ...[
                    _buildDynamicDockSliver(colorScheme, textTheme),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.psychology_alt_rounded,
                              color: colorScheme.primary,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              settings.languageCode == 'th' ? 'ท่องให้จำ' : 'Hifz Memorization',
                              style: GoogleFonts.notoSansThai(
                                color: colorScheme.onSurface,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                        child: _buildHifzBanner(colorScheme, textTheme),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _buildShortcutSection(colorScheme, textTheme),
                    ),
                  ],

                  const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
                ],
              ),
            ),
            // 1: Browse (Surahs)
            BrowseScreen(
              repository: widget.repository,
              colors: settings.getAppColors(),
              onOpen: _chooseBrowseDestination,
              onOpenPage: _navigateToMushafFreeReadPage,
            ),
            // 2: Bookmarks
            BookmarksScreen(
              repository: widget.repository,
              onBackToHome: () {
                setState(() => _navIndex = 0);
              },
            ),
            // 3: Settings
            SettingsScreen(repository: widget.repository),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicDockSliver(ColorScheme colorScheme, TextTheme textTheme) {
    if (_selectedTabIndex == 0) {
      // Meaningful Read
      return SliverList(
        delegate: SliverChildListDelegate([
          _buildMeaningfulReadSection(colorScheme, textTheme),
        ]),
      );
    } else if (_selectedTabIndex == 1) {
      // Mushaf Read
      return SliverList(
        delegate: SliverChildListDelegate([
          _buildMushafReadSection(colorScheme, textTheme),
        ]),
      );
    }
    return const SliverToBoxAdapter(child: SizedBox());
  }

  Widget _buildReadingModeCapsule(
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Container(
      height: 56,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: List.generate(_tabs.length, (index) {
          final tab = _tabs[index];
          final isActive = _selectedTabIndex == index;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                setState(() => _selectedTabIndex = index);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _resetCardsForTab(index);
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isActive ? colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      tab['icon'] as IconData,
                      size: 18,
                      color: isActive
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        context.tr(tab['title'] as String),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelLarge?.copyWith(
                          color: isActive
                              ? colorScheme.onPrimary
                              : colorScheme.onSurface.withValues(alpha: 0.55),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildHifzBanner(ColorScheme colorScheme, TextTheme textTheme) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final isThai = settings.languageCode == 'th';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HifzLandingScreen(
            quranRepository: widget.repository,
            foundationRepository: _foundationRepository,
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A4D3C),
              Color(0xFFB58E3D),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0A4D3C).withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.psychology_alt_rounded,
                size: 30,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isThai ? 'โหมดท่องจำกุรอาน' : 'Hifz Memorization',
                    style: GoogleFonts.notoSansThai(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isThai
                        ? 'ท่องจำอายะห์ใหม่ · ทบทวน · ติดตามความเชี่ยวชาญ'
                        : 'New Verses · Review · Mastery Tracking',
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutSection(ColorScheme colorScheme, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              context.tr('quick_links'),
              style: GoogleFonts.notoSansThai(
                color: colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: _quickLinks.length + (_quickLinks.length >= 7 ? 0 : 1),
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == _quickLinks.length) {
                  return _buildAddShortcutSquare(colorScheme, textTheme);
                }

                final link = _quickLinks[index];
                return _buildSurahShortcutSquare(link, colorScheme, textTheme);
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onQuickLinkTap(CustomQuickLink link) async {
    final provider = context.read<LocalReadingProvider>();
    final shortcutId = '00000000-0000-0000-0000-00000000${link.surahNumber.toString().padLeft(4, '0')}';

    var targetVerseId = '1';

    provider.checkAndResetShortcutProfiles();
    final profile = await provider.ensureShortcutProfile(shortcutId, link.surahNumber);
    targetVerseId = profile.current.verseId;

    if (targetVerseId != '1') {
      // Show Continue or Start from 1 modal popup
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
          final colors = ctx.read<SettingsProvider>().getAppColors();
          final displayTitle = link.label.isNotEmpty 
              ? link.label 
              : 'Surah ${widget.repository.getSurahName(link.surahNumber.toString())}';
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  displayTitle,
                  style: GoogleFonts.notoSansThai(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You are currently at Verse $targetVerseId. Do you want to continue or start over?',
                  style: GoogleFonts.notoSansThai(color: colors.foreground),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.background,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('Continue reading (Verse $targetVerseId)'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    'Start from Verse 1',
                    style: GoogleFonts.notoSansThai(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );

      if (startOver == null) return; // Modal dismissed
      if (startOver) {
        targetVerseId = '1';
        await provider.updateShortcutProgress(
          shortcutId,
          toVerseRef(link.surahNumber.toString(), '1'),
        );
      }
    }

    if (!mounted) return;
    final surah = int.tryParse(link.surahNumber.toString()) ?? 1;
    final verse = int.tryParse(targetVerseId) ?? 1;
    final pageNumber = qcf.getPageNumber(surah, verse);
    await _navigateToMushafFreeReadPage(pageNumber, shortcutId: shortcutId);
  }

  Widget _buildSurahShortcutSquare(
    CustomQuickLink link,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final surahId = link.surahNumber.toString();
    final englishName = widget.repository.getSurahName(surahId);
    final arabicName = mushafSurahArabicName(surahId);
    final cardBackground = Color.alphaBlend(
      colorScheme.primary.withValues(alpha: 0.04),
      colorScheme.surfaceContainerLow,
    );
    final titleColor = colorScheme.primary;
    final supportingColor = colorScheme.onSurfaceVariant;

    return SizedBox(
      width: 104,
      height: 104,
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _onQuickLinkTap(link),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      arabicName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.rtl,
                      style: textTheme.titleLarge?.copyWith(
                        color: titleColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      englishName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelMedium?.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w900,
                        height: 1.18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      link.label.isNotEmpty
                          ? link.label
                          : '${context.tr('surah')} $surahId',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelSmall?.copyWith(
                        color: supportingColor,
                        height: 1.18,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
                if (!link.isLocked)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _deleteQuickLink(link),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close,
                          color: colorScheme.onSurfaceVariant,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddShortcutSquare(ColorScheme colorScheme, TextTheme textTheme) {
    return SizedBox(
      width: 104,
      height: 104,
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _showAddQuickLinkSheet,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.add, color: colorScheme.onPrimaryContainer),
                ),
                const SizedBox(height: 10),
                Text(
                  'Add more',
                  textAlign: TextAlign.center,
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _triggerAutoSync() async {
    final supabaseProv = Provider.of<SupabaseProvider>(context, listen: false);
    if (supabaseProv.isLoggedIn && supabaseProv.user != null) {
      final userId = supabaseProv.user!.id;
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      final reading = Provider.of<LocalReadingProvider>(context, listen: false);
      final mushaf = Provider.of<MushafReadingProvider>(context, listen: false);
      final notes = Provider.of<NotesProvider>(context, listen: false);
      final stats = Provider.of<StatsProvider>(context, listen: false);

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
      await _saveQuickLinks();
    }
  }

  int _getAbsoluteVerseIndex(int surah, int verse) {
    int index = 0;
    for (int i = 1; i < surah; i++) {
      index += widget.repository.getSurahVerses(i.toString()).length;
    }
    return index + verse;
  }

  Widget _buildMeaningfulReadSection(
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final localReading = Provider.of<LocalReadingProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);

    final customProfiles = localReading.profiles
        .where((p) => !isFreeReadProfile(p) && !p.isArchived)
        .toList();
    final freeReadProfile = localReading.freeReadProfile;

    final allItems = [
      ...customProfiles,
      if (freeReadProfile != null) freeReadProfile else 'guest_read',
      'add_goal',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr('meaningful_read'),
                style: GoogleFonts.notoSansThai(
                  color: colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              FilledButton.icon(
                onPressed: () {
                  _showProfileDialog(context);
                },
                icon: const Icon(Icons.add, size: 18),
                label: Text(context.tr('goal')),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            context.tr('mushaf_meaningful_desc'),
            style: GoogleFonts.notoSansThai(
              color: colorScheme.onSurfaceVariant,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 328,
          child: ListView.builder(
            controller: _meaningfulCardsScrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 24, right: 8),
            itemCount: allItems.length,
            itemBuilder: (context, index) {
              final item = allItems[index];
              if (item == 'add_goal') {
                return _buildAddGoalCard(colorScheme);
              }
              if (item == 'guest_read') {
                return _buildMeaningfulGuestCard(colorScheme, settings, index);
              }
              return _buildMeaningfulProfileCard(
                item as LocalReadingProfile,
                colorScheme,
                settings,
                index,
              );
            },
          ),
        ),
        _buildGoalCarouselHint(colorScheme, allItems.length),
      ],
    );
  }

  Widget _buildMushafReadSection(ColorScheme colorScheme, TextTheme textTheme) {
    final mushafReading = Provider.of<MushafReadingProvider>(context);
    final customProfiles = mushafReading.activeCustomProfiles;
    final freeReadProfiles =
        mushafReading.profiles
            .where((p) => p.isFreeRead && !p.isArchived)
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final recentFreeRead = mushafReading.recentReadings
        .map((reading) => mushafReading.profileById(reading.profileId))
        .whereType<MushafProfile>()
        .where((profile) => profile.isFreeRead && !profile.isArchived)
        .firstOrNull;
    final freeReadProfile = recentFreeRead ?? freeReadProfiles.firstOrNull;

    final allItems = [
      ...customProfiles,
      if (freeReadProfile != null) freeReadProfile else 'guest_read',
      'add_goal',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr('mushaf_read'),
                style: GoogleFonts.notoSansThai(
                  color: colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              FilledButton.icon(
                onPressed: () {
                  _showCreateMushafGoalDialog();
                },
                icon: const Icon(Icons.add, size: 18),
                label: Text(context.tr('goal')),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            context.tr('mushaf_read_desc'),
            style: GoogleFonts.notoSansThai(
              color: colorScheme.onSurfaceVariant,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 328,
          child: ListView.builder(
            controller: _mushafCardsScrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 24, right: 8),
            itemCount: allItems.length,
            itemBuilder: (context, index) {
              final item = allItems[index];
              if (item == 'add_goal') {
                return _buildAddGoalCard(
                  colorScheme,
                  onTap: _showCreateMushafGoalDialog,
                );
              }
              if (item == 'guest_read') {
                return _buildMushafGuestCard(colorScheme, index);
              }
              return _buildMushafProfileCard(
                item as MushafProfile,
                colorScheme,
                index,
              );
            },
          ),
        ),
        _buildGoalCarouselHint(colorScheme, allItems.length),
      ],
    );
  }

  Widget _buildMeaningfulProfileCard(
    LocalReadingProfile profile,
    ColorScheme colorScheme,
    SettingsProvider settings,
    int index,
  ) {
    bool isFreeRead = isFreeReadProfile(profile);
    double? progressPercent;

    if (!isFreeRead && profile.planMode != 'mushaf' && profile.target != null) {
      final startAbs = _getAbsoluteVerseIndex(
        int.parse(profile.start.surahId),
        int.parse(profile.start.verseId),
      );
      final currentAbs = _getAbsoluteVerseIndex(
        int.parse(profile.furthestUnread.surahId),
        int.parse(profile.furthestUnread.verseId),
      );
      final targetAbs = _getAbsoluteVerseIndex(
        int.parse(profile.target!.surahId),
        int.parse(profile.target!.verseId),
      );

      if (targetAbs > startAbs) {
        progressPercent = (currentAbs - startAbs) / (targetAbs - startAbs);
        if (progressPercent > 1.0) progressPercent = 1.0;
        if (progressPercent < 0.0) progressPercent = 0.0;
      }
    }

    return _buildMeaningfulCardLayout(
      colorScheme: colorScheme,
      settings: settings,
      isFreeRead: isFreeRead,
      profileName: profile.name,
      continueSurah: profile.furthestUnread.surahId,
      continueVerse: profile.furthestUnread.verseId,
      lastViewedSurah: profile.lastViewed.surahId,
      lastViewedVerse: profile.lastViewed.verseId,
      imageIndex: index,
      progressPercent: progressPercent,
      onDelete: isFreeRead
          ? null
          : () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(context.tr('delete_goal_title')),
                  content: Text(context.tr('delete_goal_confirm')),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(context.tr('cancel')),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.error,
                        foregroundColor: colorScheme.onError,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(context.tr('delete')),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                if (mounted) {
                  context.read<LocalReadingProvider>().deleteProfile(
                    profile.id,
                  );
                }
              }
            },
      onContinue: () async {
        await context.read<LocalReadingProvider>().setActiveProfile(profile.id);
        if (!mounted) return;
        _navigateToReading(
          context,
          profile.furthestUnread.surahId,
          verseId: profile.furthestUnread.verseId,
        );
      },
      onJumpBack: profile.lastViewedIndex < profile.furthestUnreadIndex
          ? () async {
              await context.read<LocalReadingProvider>().setActiveProfile(
                profile.id,
              );
              if (!mounted) return;
              _navigateToReading(
                context,
                profile.lastViewed.surahId,
                verseId: profile.lastViewed.verseId,
              );
            }
          : null,
      onEdit: isFreeRead
          ? null
          : () => _showProfileDialog(context, profile: profile),
    );
  }

  // ── Goal create / edit dialog ────────────────────────────────────────────

  Future<void> _showProfileDialog(
    BuildContext context, {
    LocalReadingProfile? profile,
  }) async {
    final provider = context.read<LocalReadingProvider>();
    final colors = context.read<SettingsProvider>().getAppColors();
    final nameController = TextEditingController(text: profile?.name ?? '');
    var planMode = profile?.planMode ?? 'custom';
    var startSurah = profile?.start.surahId ?? '1';
    var startAyah = profile?.start.verseId ?? '1';
    var endSurah = profile?.target?.surahId ?? startSurah;
    var endAyah = profile?.target?.verseId ?? startAyah;
    var startJuz = profile?.startJuz ?? 1;
    var endJuz = profile?.targetJuz ?? startJuz;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final startAyahCount = widget.repository
                .getSurahVerses(startSurah)
                .length;
            final endAyahCount = widget.repository
                .getSurahVerses(endSurah)
                .length;
            startAyah = _clampAyah(startAyah, startAyahCount);
            endAyah = _clampAyah(endAyah, endAyahCount);

            // Pre-compute translations to avoid context capture in DropdownOverlay
            final trGoalName = context.tr('goal_name');
            final trPlanType = context.tr('plan_type');
            final trJuzMode = context.tr('juz_mode');
            final trAyahMode = context.tr('ayah_mode');
            final trSurahMode = context.tr('surah_mode');
            final trCustomMode = context.tr('custom_mode');
            final trStartJuz = context.tr('start_juz');
            final trTargetJuz = context.tr('target_juz');
            final trStartSurah = context.tr('start_surah');
            final trTargetSurah = context.tr('target_surah');
            final trStartAyah = context.tr('start_ayah');
            final trTargetAyah = context.tr('target_ayah');
            final trResetProgress = context.tr('reset_progress');
            final trGoalProgressReset = context.tr('goal_progress_reset');
            final trCancel = context.tr('cancel');
            final trCreate = context.tr('create');
            final trSave = context.tr('save');
            final trEnterGoalName = context.tr('enter_goal_name');
            final trEndMustBeAfterStart = context.tr('end_must_be_after_start');
            final trCreateGoal = context.tr('create_goal');
            final trEditGoal = context.tr('edit_goal');

            return AlertDialog(
              backgroundColor: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                side: BorderSide(color: colors.borderSoft),
              ),
              title: Text(
                profile == null ? trCreateGoal : trEditGoal,
                style: GoogleFonts.notoSansThai(
                  fontWeight: FontWeight.w800,
                  color: colors.textStrong,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: trGoalName,
                        hintText: 'e.g. Ramadan 2026',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: planMode,
                      decoration: InputDecoration(labelText: trPlanType),
                      items: [
                        DropdownMenuItem(
                          value: 'by_juz',
                          child: Text(trJuzMode),
                        ),
                        DropdownMenuItem(
                          value: 'by_ayat',
                          child: Text(trAyahMode),
                        ),
                        DropdownMenuItem(
                          value: 'by_surah',
                          child: Text(trSurahMode),
                        ),
                        DropdownMenuItem(
                          value: 'custom',
                          child: Text(trCustomMode),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => planMode = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    if (planMode == 'by_juz')
                      Row(
                        children: [
                          Expanded(
                            child: _numberDropdown(
                              label: trStartJuz,
                              value: startJuz,
                              max: 30,
                              onChanged: (value) {
                                setDialogState(() {
                                  startJuz = value;
                                  if (endJuz < startJuz) endJuz = startJuz;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _numberDropdown(
                              label: trTargetJuz,
                              value: endJuz,
                              min: startJuz,
                              max: 30,
                              onChanged: (value) =>
                                  setDialogState(() => endJuz = value),
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _GoalRangeSection(
                        title: context.tr('start'),
                        colors: colors,
                        children: [
                          _surahDropdown(
                            label: trStartSurah,
                            value: startSurah,
                            onChanged: (value) {
                              setDialogState(() {
                                startSurah = value;
                                if (int.parse(endSurah) <
                                    int.parse(startSurah)) {
                                  endSurah = startSurah;
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          _ayahDropdown(
                            label: trStartAyah,
                            value: planMode == 'by_surah' ? '1' : startAyah,
                            max: startAyahCount,
                            enabled: planMode != 'by_surah',
                            onChanged: (value) =>
                                setDialogState(() => startAyah = value),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _GoalRangeSection(
                        title: context.tr('target'),
                        colors: colors,
                        children: [
                          _surahDropdown(
                            label: trTargetSurah,
                            value: endSurah,
                            min: int.parse(startSurah),
                            onChanged: (value) =>
                                setDialogState(() => endSurah = value),
                          ),
                          const SizedBox(height: 12),
                          _ayahDropdown(
                            label: trTargetAyah,
                            value: planMode == 'by_surah'
                                ? endAyahCount.toString()
                                : endAyah,
                            max: endAyahCount,
                            enabled: planMode != 'by_surah',
                            onChanged: (value) =>
                                setDialogState(() => endAyah = value),
                          ),
                        ],
                      ),
                    ],
                    if (profile != null) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.restart_alt),
                        label: Text(trResetProgress),
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          provider.updateProfileProgress(
                            profile.id,
                            profile.start,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(trGoalProgressReset)),
                          );
                        },
                      ),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        error!,
                        style: GoogleFonts.notoSansThai(
                          color: Colors.red.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(trCancel),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      setDialogState(() => error = trEnterGoalName);
                      return;
                    }

                    final start = planMode == 'by_juz'
                        ? _juzStartRef(startJuz)
                        : toVerseRef(
                            startSurah,
                            planMode == 'by_surah' ? 1 : startAyah,
                          );
                    final target = planMode == 'by_juz'
                        ? _juzEndRef(endJuz)
                        : toVerseRef(
                            endSurah,
                            planMode == 'by_surah'
                                ? widget.repository
                                      .getSurahVerses(endSurah)
                                      .length
                                : endAyah,
                          );

                    if (_verseOrdinal(target.surahId, target.verseId) <
                        _verseOrdinal(start.surahId, start.verseId)) {
                      setDialogState(() => error = trEndMustBeAfterStart);
                      return;
                    }

                    if (profile == null) {
                      try {
                        await provider.createProfile(
                          name: name,
                          planMode: planMode,
                          startJuz: planMode == 'by_juz' ? startJuz : null,
                          targetJuz: planMode == 'by_juz' ? endJuz : null,
                          start: start,
                          target: target,
                          context: context,
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                      } catch (e) {
                        setDialogState(() => error = e.toString());
                      }
                    } else {
                      try {
                        await provider.updateProfile(
                          profileId: profile.id,
                          name: name,
                          planMode: planMode,
                          startJuz: planMode == 'by_juz' ? startJuz : null,
                          targetJuz: planMode == 'by_juz' ? endJuz : null,
                          start: start,
                          target: target,
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                      } catch (e) {
                        setDialogState(() => error = e.toString());
                      }
                    }
                  },
                  child: Text(profile == null ? trCreate : trSave),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
  }

  int _verseOrdinal(String surahId, String verseId) {
    var ordinal = 0;
    for (var surah = 1; surah <= 114; surah++) {
      final id = surah.toString();
      final count = widget.repository.getSurahVerses(id).length;
      if (id == surahId) return ordinal + (int.tryParse(verseId) ?? 1);
      ordinal += count;
    }
    return ordinal;
  }

  String _clampAyah(String value, int max) {
    final ayah = int.tryParse(value) ?? 1;
    return ayah.clamp(1, max < 1 ? 1 : max).toString();
  }

  VerseRef _juzStartRef(int juz) {
    final s = _juzStarts[(juz - 1).clamp(0, _juzStarts.length - 1)];
    return toVerseRef(s[0], s[1]);
  }

  VerseRef _juzEndRef(int juz) {
    if (juz >= _juzStarts.length) {
      final lastCount = widget.repository.getSurahVerses('114').length;
      return toVerseRef(114, lastCount);
    }
    final nextStart = _juzStarts[juz];
    var surah = nextStart[0];
    var ayah = nextStart[1] - 1;
    if (ayah < 1) {
      surah -= 1;
      ayah = widget.repository.getSurahVerses(surah.toString()).length;
    }
    return toVerseRef(surah, ayah);
  }

  Widget _numberDropdown({
    required String label,
    required int value,
    required int max,
    int min = 1,
    required ValueChanged<int> onChanged,
  }) {
    final safe = value.clamp(min, max);
    return DropdownButtonFormField<int>(
      initialValue: safe,
      decoration: InputDecoration(labelText: label),
      items: [
        for (var n = min; n <= max; n++)
          DropdownMenuItem(value: n, child: Text(n.toString())),
      ],
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }

  Widget _surahDropdown({
    required String label,
    required String value,
    int min = 1,
    required ValueChanged<String> onChanged,
  }) {
    final parsed = int.tryParse(value) ?? min;
    final safe = parsed.clamp(min, 114);
    return DropdownButtonFormField<String>(
      initialValue: safe.toString(),
      decoration: InputDecoration(labelText: label),
      items: [
        for (var s = min; s <= 114; s++)
          DropdownMenuItem(
            value: s.toString(),
            child: Text(widget.repository.getSurahName(s.toString())),
          ),
      ],
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }

  Widget _ayahDropdown({
    required String label,
    required String value,
    required int max,
    required ValueChanged<String> onChanged,
    bool enabled = true,
  }) {
    final safe = _clampAyah(value, max);
    return DropdownButtonFormField<String>(
      initialValue: safe,
      decoration: InputDecoration(labelText: label),
      items: [
        for (var a = 1; a <= max; a++)
          DropdownMenuItem(value: a.toString(), child: Text(a.toString())),
      ],
      onChanged: enabled
          ? (next) {
              if (next != null) onChanged(next);
            }
          : null,
    );
  }

  Widget _buildMeaningfulGuestCard(
    ColorScheme colorScheme,
    SettingsProvider settings,
    int index,
  ) {
    return _buildMeaningfulCardLayout(
      colorScheme: colorScheme,
      settings: settings,
      isFreeRead: true,
      profileName: context.tr('just_read'),
      continueSurah: '1',
      continueVerse: '1',
      imageIndex: index,
      onContinue: () {
        _navigateToReading(
          context,
          '1',
          verseId: '1',
          saveToFreeReadOnly: true,
        );
      },
    );
  }

  Widget _buildMeaningfulCardLayout({
    required ColorScheme colorScheme,
    required SettingsProvider settings,
    required bool isFreeRead,
    required String profileName,
    required String continueSurah,
    required String continueVerse,
    String? lastViewedSurah,
    String? lastViewedVerse,
    required int imageIndex,
    required VoidCallback onContinue,
    VoidCallback? onJumpBack,
    VoidCallback? onDelete,
    VoidCallback? onEdit,
    double? progressPercent,
  }) {
    final isReviewing =
        onJumpBack != null &&
        lastViewedSurah != null &&
        lastViewedVerse != null;
    final verses = widget.repository.getSurahVerses(continueSurah);
    String translationText = '';
    if (verses.isNotEmpty) {
      final verseObj = verses.firstWhere(
        (v) => v.id == continueVerse,
        orElse: () => verses.first,
      );
      if (settings.primaryTranslationId == 'thai_v2') {
        translationText = verseObj.thaiV2;
      } else if (settings.primaryTranslationId == 'english') {
        translationText = verseObj.english;
      } else {
        translationText = verseObj.thaiV3;
      }
    }

    final textColor = Colors.white;
    // Offset image for Meaningful Read so it looks different (e.g., 3, 4, 5, 1, 2)
    final imageNumber = ((imageIndex + 2) % 5) + 1;

    return Container(
      width: _goalCardWidth(context),
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        image: DecorationImage(
          image: AssetImage('assets/images/image_slider${imageNumber}_x.webp'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.55),
            BlendMode.darken,
          ),
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius * 1.2),
      ),
      child: Stack(
        children: [
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: textColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: textColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_stories, size: 12, color: textColor),
                          const SizedBox(width: 4),
                          Text(
                            profileName.toUpperCase(),
                            style: GoogleFonts.notoSansThai(
                              color: textColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                          if (!isFreeRead && onEdit != null) ...[
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: onEdit,
                              child: Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: Icon(
                                  Icons.edit,
                                  size: 14,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.bookmark,
                          color: textColor.withValues(alpha: 0.7),
                          size: 20,
                        ),
                        if (onDelete != null) ...[
                          const SizedBox(width: 12),
                          InkWell(
                            onTap: onDelete,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: colorScheme.error.withValues(alpha: 0.8),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.delete_outline,
                                size: 16,
                                color: colorScheme.onError,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (isReviewing) ...[
                  Text(
                    context.tr('next_unread_verse').toUpperCase(),
                    style: GoogleFonts.notoSansThai(
                      color: textColor.withValues(alpha: 0.7),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        widget.repository.getSurahName(continueSurah),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSansThai(
                          color: textColor,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text(
                        mushafSurahArabicName(continueSurah),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontFamily: 'UthmanicHafs',
                          color: textColor.withValues(alpha: 0.9),
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${context.tr('current_ayah')} $continueSurah:$continueVerse',
                  style: GoogleFonts.notoSansThai(
                    color: textColor.withValues(alpha: 0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (progressPercent != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: progressPercent,
                          backgroundColor: textColor.withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colorScheme.primary,
                          ),
                          minHeight: 4,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(progressPercent * 100).toInt()}%',
                        style: GoogleFonts.notoSansThai(
                          color: textColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
                if (translationText.isNotEmpty) ...[
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: textColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border(
                        left: BorderSide(
                          color: textColor.withValues(alpha: 0.6),
                          width: 3,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('translation').toUpperCase(),
                          style: GoogleFonts.notoSansThai(
                            color: textColor.withValues(alpha: 0.6),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          translationText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.notoSansThai(
                            color: textColor.withValues(alpha: 0.95),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Opacity(
                    opacity: 0.7,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: textColor,
                        foregroundColor: colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        minimumSize: const Size(0, 34),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        elevation: 0,
                      ),
                      onPressed: onContinue,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            context.tr(
                              isReviewing
                                  ? 'resume_progress'
                                  : 'continue_reading',
                            ),
                            style: GoogleFonts.notoSansThai(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
                if (isReviewing) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: textColor.withValues(alpha: 0.18),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${context.tr('last_viewed')}: ${widget.repository.getSurahName(lastViewedSurah)} $lastViewedSurah:$lastViewedVerse',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.notoSansThai(
                              color: textColor.withValues(alpha: 0.72),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: onJumpBack,
                          style: TextButton.styleFrom(
                            foregroundColor: textColor.withValues(alpha: 0.82),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            context.tr('jump_back'),
                            style: GoogleFonts.notoSansThai(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildMushafProfileCard(
    MushafProfile profile,
    ColorScheme colorScheme,
    int index,
  ) {
    bool isFreeRead = profile.isFreeRead;
    double? progressPercent;
    final displayPage = isFreeRead
        ? profile.lastViewedPage
        : profile.currentPage;
    final continuePage = isFreeRead
        ? profile.lastViewedPage
        : profile.furthestUnreadPage;

    if (!isFreeRead) {
      final start = profile.startPage;
      final target = profile.targetPage;
      final current = profile.currentPage;
      if (target > start) {
        progressPercent = (current - start) / (target - start);
        if (progressPercent > 1.0) progressPercent = 1.0;
        if (progressPercent < 0.0) progressPercent = 0.0;
      }
    }

    return _buildMushafCardLayout(
      colorScheme: colorScheme,
      isFreeRead: isFreeRead,
      profileName: isFreeRead ? context.tr('just_read') : profile.name,
      page: displayPage,
      imageIndex: index,
      progressPercent: progressPercent,
      onDelete: isFreeRead
          ? null
          : () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(context.tr('delete_goal_title')),
                  content: Text(context.tr('delete_goal_confirm')),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(context.tr('cancel')),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.error,
                        foregroundColor: colorScheme.onError,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(context.tr('delete')),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                if (mounted) {
                  context.read<MushafReadingProvider>().archiveProfile(
                    profile.id,
                  );
                }
              }
            },
      onContinue: () =>
          _navigateToMushafProfile(profile, initialPage: continuePage),
      onJumpBack:
          (!isFreeRead && profile.lastViewedPage < profile.furthestUnreadPage)
          ? () => _navigateToMushafProfile(
              profile,
              initialPage: profile.lastViewedPage,
            )
          : null,
      lastViewedPage: profile.lastViewedPage,
      onEdit: isFreeRead ? null : () => _showEditMushafGoalDialog(profile),
    );
  }

  Future<void> _showEditMushafGoalDialog(MushafProfile profile) async {
    await _showMushafGoalDialog(profile: profile);
  }

  Future<void> _showCreateMushafGoalDialog() async {
    await _showMushafGoalDialog();
  }

  Future<void> _showMushafGoalDialog({MushafProfile? profile}) async {
    final provider = context.read<MushafReadingProvider>();
    final mushafId = profile?.mushafId ?? provider.displayMushafId;
    final pageCount = mushafTypeById(mushafId).pageCount;
    final nameController = TextEditingController(text: profile?.name ?? '');
    var rangeType = switch (profile?.planMode) {
      'by_surah' => 'surah_range',
      'by_juz' => 'juz_range',
      'detailed_range' => 'detailed_range',
      _ => 'page_range',
    };
    var startPage = profile?.startPage ?? 1;
    var targetPage = profile?.targetPage ?? pageCount;
    var startSurah = _surahForMushafPage(startPage).toString();
    var endSurah = _surahForMushafPage(targetPage).toString();
    var startAyah = '1';
    var endAyah = widget.repository
        .getSurahVerses(endSurah)
        .length
        .clamp(1, 286)
        .toString();
    var startJuz = getOfflineJuzForPage(startPage);
    var endJuz = getOfflineJuzForPage(targetPage);
    var isSaving = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final colorScheme = Theme.of(context).colorScheme;
            final colors = context.read<SettingsProvider>().getAppColors();
            final startAyahCount = widget.repository
                .getSurahVerses(startSurah)
                .length;
            final endAyahCount = widget.repository
                .getSurahVerses(endSurah)
                .length;
            startAyah = _clampAyah(startAyah, startAyahCount);
            endAyah = _clampAyah(endAyah, endAyahCount);

            return AlertDialog(
              backgroundColor: colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
              title: Text(
                profile == null
                    ? context.tr('create_goal')
                    : context.tr('edit_goal'),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: context.tr('goal_name'),
                        hintText: 'e.g. Mushaf goal',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: rangeType,
                      decoration: InputDecoration(
                        labelText: context.tr('mushaf_range_type'),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'surah_range',
                          child: Text(context.tr('surah_range')),
                        ),
                        DropdownMenuItem(
                          value: 'juz_range',
                          child: Text(context.tr('juz_range')),
                        ),
                        DropdownMenuItem(
                          value: 'page_range',
                          child: Text(context.tr('page_range')),
                        ),
                        DropdownMenuItem(
                          value: 'detailed_range',
                          child: Text(context.tr('detailed_range')),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          rangeType = value;
                          error = null;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    if (rangeType == 'page_range')
                      Row(
                        children: [
                          Expanded(
                            child: _numberDropdown(
                              label: context.tr('start_page'),
                              value: startPage,
                              max: pageCount,
                              onChanged: (value) {
                                setDialogState(() {
                                  startPage = value;
                                  error = null;
                                  if (targetPage < startPage) {
                                    targetPage = startPage;
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _numberDropdown(
                              label: context.tr('target_page'),
                              value: targetPage,
                              min: startPage,
                              max: pageCount,
                              onChanged: (value) {
                                setDialogState(() {
                                  targetPage = value;
                                  error = null;
                                });
                              },
                            ),
                          ),
                        ],
                      )
                    else if (rangeType == 'juz_range')
                      Row(
                        children: [
                          Expanded(
                            child: _numberDropdown(
                              label: context.tr('start_juz'),
                              value: startJuz,
                              max: 30,
                              onChanged: (value) {
                                setDialogState(() {
                                  startJuz = value;
                                  error = null;
                                  if (endJuz < startJuz) endJuz = startJuz;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _numberDropdown(
                              label: context.tr('target_juz'),
                              value: endJuz,
                              min: startJuz,
                              max: 30,
                              onChanged: (value) {
                                setDialogState(() {
                                  endJuz = value;
                                  error = null;
                                });
                              },
                            ),
                          ),
                        ],
                      )
                    else if (rangeType == 'surah_range')
                      _GoalRangeSection(
                        title: context.tr('surah_range'),
                        colors: colors,
                        children: [
                          _surahDropdown(
                            label: context.tr('start_surah'),
                            value: startSurah,
                            onChanged: (value) {
                              setDialogState(() {
                                startSurah = value;
                                error = null;
                                if (int.parse(endSurah) <
                                    int.parse(startSurah)) {
                                  endSurah = startSurah;
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          _surahDropdown(
                            label: context.tr('target_surah'),
                            value: endSurah,
                            min: int.parse(startSurah),
                            onChanged: (value) {
                              setDialogState(() {
                                endSurah = value;
                                error = null;
                              });
                            },
                          ),
                        ],
                      )
                    else ...[
                      _GoalRangeSection(
                        title: context.tr('start'),
                        colors: colors,
                        children: [
                          _surahDropdown(
                            label: context.tr('start_surah'),
                            value: startSurah,
                            onChanged: (value) {
                              setDialogState(() {
                                startSurah = value;
                                error = null;
                                if (int.parse(endSurah) <
                                    int.parse(startSurah)) {
                                  endSurah = startSurah;
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          _ayahDropdown(
                            label: context.tr('start_ayah'),
                            value: startAyah,
                            max: startAyahCount,
                            onChanged: (value) {
                              setDialogState(() {
                                startAyah = value;
                                error = null;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _GoalRangeSection(
                        title: context.tr('target'),
                        colors: colors,
                        children: [
                          _surahDropdown(
                            label: context.tr('target_surah'),
                            value: endSurah,
                            min: int.parse(startSurah),
                            onChanged: (value) {
                              setDialogState(() {
                                endSurah = value;
                                error = null;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          _ayahDropdown(
                            label: context.tr('target_ayah'),
                            value: endAyah,
                            max: endAyahCount,
                            onChanged: (value) {
                              setDialogState(() {
                                endAyah = value;
                                error = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                    if (profile != null) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.restart_alt),
                          label: Text(context.tr('reset_progress')),
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            context
                                .read<MushafReadingProvider>()
                                .updateProgress(
                                  profileId: profile.id,
                                  pageNumber: profile.startPage,
                                );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.tr('goal_progress_reset'),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          error!,
                          style: GoogleFonts.notoSansThai(
                            color: colorScheme.onErrorContainer,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: Text(context.tr('cancel')),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            setDialogState(() {
                              error = context.tr('enter_goal_name');
                            });
                            return;
                          }
                          setDialogState(() {
                            isSaving = true;
                            error = null;
                          });
                          try {
                            final range = _resolveMushafGoalRange(
                              rangeType: rangeType,
                              pageCount: pageCount,
                              startPage: startPage,
                              targetPage: targetPage,
                              startSurah: startSurah,
                              endSurah: endSurah,
                              startAyah: startAyah,
                              endAyah: endAyah,
                              startJuz: startJuz,
                              endJuz: endJuz,
                            );
                            if (profile == null) {
                              await provider.createPageRangeProfile(
                                name: name,
                                mushafId: mushafId,
                                startPage: range.startPage,
                                targetPage: range.endPage,
                                planMode: rangeType == 'page_range'
                                    ? 'page_range'
                                    : rangeType == 'surah_range'
                                    ? 'by_surah'
                                    : rangeType == 'juz_range'
                                    ? 'by_juz'
                                    : 'detailed_range',
                              );
                            } else {
                              await provider.updateProfileRange(
                                profileId: profile.id,
                                name: name,
                                planMode: rangeType == 'page_range'
                                    ? 'page_range'
                                    : rangeType == 'surah_range'
                                    ? 'by_surah'
                                    : rangeType == 'juz_range'
                                    ? 'by_juz'
                                    : 'detailed_range',
                                startPage: range.startPage,
                                targetPage: range.endPage,
                              );
                            }
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          } catch (e) {
                            if (!dialogContext.mounted) return;
                            setDialogState(() {
                              isSaving = false;
                              error = e.toString();
                            });
                          }
                        },
                  child: Text(
                    isSaving
                        ? context.tr('saving')
                        : profile == null
                        ? context.tr('create')
                        : context.tr('save'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
  }

  MushafPageRange _resolveMushafGoalRange({
    required String rangeType,
    required int pageCount,
    required int startPage,
    required int targetPage,
    required String startSurah,
    required String endSurah,
    required String startAyah,
    required String endAyah,
    required int startJuz,
    required int endJuz,
  }) {
    if (rangeType == 'juz_range') {
      final start = _mushafJuzStartPage(startJuz);
      final target = endJuz >= 30
          ? pageCount
          : _mushafJuzStartPage(endJuz + 1) - 1;
      return MushafPageRange(startPage: start, endPage: target);
    }
    if (rangeType == 'surah_range') {
      final start = getStartPageForSurah(int.parse(startSurah));
      final endNumber = int.parse(endSurah);
      final target = endNumber >= 114
          ? pageCount
          : getStartPageForSurah(endNumber + 1) - 1;
      return MushafPageRange(startPage: start, endPage: target);
    }
    if (rangeType == 'detailed_range') {
      final start = qcf.getPageNumber(
        int.parse(startSurah),
        int.parse(startAyah),
      );
      final target = qcf.getPageNumber(int.parse(endSurah), int.parse(endAyah));
      return MushafPageRange(
        startPage: start.clamp(1, pageCount),
        endPage: target.clamp(start, pageCount),
      );
    }
    return MushafPageRange(
      startPage: startPage.clamp(1, pageCount),
      endPage: targetPage.clamp(startPage, pageCount),
    );
  }

  int _mushafJuzStartPage(int juz) {
    const starts = [
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
    return starts[(juz - 1).clamp(0, starts.length - 1)];
  }

  int _surahForMushafPage(int page) {
    var surah = 1;
    for (var s = 1; s <= 114; s++) {
      if (getStartPageForSurah(s) <= page) {
        surah = s;
      } else {
        break;
      }
    }
    return surah;
  }

  Widget _buildMushafGuestCard(ColorScheme colorScheme, int index) {
    return _buildMushafCardLayout(
      colorScheme: colorScheme,
      isFreeRead: true,
      profileName: context.tr('just_read'),
      page: 1,
      imageIndex: index,
      onContinue: () => _navigateToMushafFreeReadPage(1),
    );
  }

  Widget _buildMushafCardLayout({
    required ColorScheme colorScheme,
    required bool isFreeRead,
    required String profileName,
    required int page,
    required int imageIndex,
    required VoidCallback onContinue,
    VoidCallback? onJumpBack,
    VoidCallback? onDelete,
    VoidCallback? onEdit,
    double? progressPercent,
    int? lastViewedPage,
  }) {
    final bool isReviewing = onJumpBack != null && lastViewedPage != null;
    final textColor = Colors.white;
    // Offset image for Mushaf Read so it looks different (e.g., 5, 1, 2, 3, 4)
    final imageNumber = ((imageIndex + 4) % 5) + 1;
    final previewFuture = _fetchArabicPreviewForPage(page);

    return Container(
      width: _goalCardWidth(context),
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        image: DecorationImage(
          image: AssetImage('assets/images/image_slider${imageNumber}_x.webp'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.65),
            BlendMode.darken,
          ),
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius * 1.2),
      ),
      child: Stack(
        children: [
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: textColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: textColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.import_contacts,
                            size: 12,
                            color: textColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            profileName.toUpperCase(),
                            style: GoogleFonts.notoSansThai(
                              color: textColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                          if (!isFreeRead && onEdit != null) ...[
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: onEdit,
                              child: Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: Icon(
                                  Icons.edit,
                                  size: 14,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.bookmark,
                          color: textColor.withValues(alpha: 0.7),
                          size: 20,
                        ),
                        if (onDelete != null) ...[
                          const SizedBox(width: 12),
                          InkWell(
                            onTap: onDelete,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: colorScheme.error.withValues(alpha: 0.8),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.delete_outline,
                                size: 16,
                                color: colorScheme.onError,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FutureBuilder<Map<String, String>>(
                  future: previewFuture,
                  builder: (context, snapshot) {
                    final data = snapshot.data ?? {};
                    final surahId = data['surahId'] ?? '';
                    final title = surahId.isEmpty
                        ? '${context.tr('page')} $page'
                        : widget.repository.getSurahName(surahId);
                    final arabicName = surahId.isEmpty
                        ? ''
                        : mushafSurahArabicName(surahId);

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.notoSansThai(
                              color: textColor,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (arabicName.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Directionality(
                            textDirection: TextDirection.rtl,
                            child: Text(
                              arabicName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontFamily: 'UthmanicHafs',
                                color: textColor.withValues(alpha: 0.9),
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                if (progressPercent != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: progressPercent,
                          backgroundColor: textColor.withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colorScheme.primary,
                          ),
                          minHeight: 4,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(progressPercent * 100).toInt()}%',
                        style: GoogleFonts.notoSansThai(
                          color: textColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],

                // Fetch and render the Arabic Text from Repository
                Expanded(
                  child: FutureBuilder<Map<String, String>>(
                    future: previewFuture,
                    builder: (context, snapshot) {
                      final data = snapshot.data ?? {};
                      final arabicText = data['arabic'] ?? '';
                      final previewArabicText = arabicText
                          .split(' | ')
                          .join(' ');
                      final verseId = data['verseId'] ?? '';

                      if (arabicText.isEmpty) {
                        // Fallback or loading state
                        return const SizedBox.shrink();
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  '${context.tr('page')} $page - ${context.tr('ayah')} $verseId',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.notoSansThai(
                                    color: textColor.withValues(alpha: 0.85),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: textColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Directionality(
                              textDirection: TextDirection.rtl,
                              child: Text(
                                previewArabicText,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontFamily: 'UthmanicHafs',
                                  color: textColor.withValues(alpha: 0.95),
                                  fontSize: 24,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Opacity(
                    opacity: 0.7,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: textColor,
                        foregroundColor: colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        minimumSize: const Size(0, 34),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        elevation: 0,
                      ),
                      onPressed: onContinue,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            context.tr(
                              isReviewing
                                  ? 'resume_progress'
                                  : 'continue_reading',
                            ),
                            style: GoogleFonts.notoSansThai(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
                if (isReviewing) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: textColor.withValues(alpha: 0.18),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${context.tr('last_viewed')}: ${context.tr('page')} $lastViewedPage',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.notoSansThai(
                              color: textColor.withValues(alpha: 0.72),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: onJumpBack,
                          style: TextButton.styleFrom(
                            foregroundColor: textColor.withValues(alpha: 0.82),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            context.tr('jump_back'),
                            style: GoogleFonts.notoSansThai(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildAddGoalCard(ColorScheme colorScheme, {VoidCallback? onTap}) {
    return Container(
      width: _goalCardWidth(context),
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radius * 1.2),
        border: Border.all(color: colorScheme.outline, width: 2),
      ),
      child: InkWell(
        onTap: onTap ?? () => _showProfileDialog(context),
        borderRadius: BorderRadius.circular(AppTheme.radius * 1.2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add,
                size: 32,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('create_goal'),
              style: GoogleFonts.notoSansThai(
                color: colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddQuickLinkSheet() {
    int selectedSurah = 1;
    String customLabel = "";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            final textTheme = Theme.of(context).textTheme;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Quick Link',
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Select Surah', style: textTheme.titleSmall),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: selectedSurah,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    items: List.generate(114, (i) {
                      final sNum = i + 1;
                      return DropdownMenuItem(
                        value: sNum,
                        child: Text(
                          widget.repository.getSurahName(sNum.toString()),
                        ),
                      );
                    }),
                    onChanged: (val) {
                      if (val != null) setSheetState(() => selectedSurah = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  Text('Custom Label', style: textTheme.titleSmall),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'e.g., Read after Fajr',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (val) => customLabel = val,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: () {
                        final now = DateTime.now();
                        setState(() {
                          _quickLinks.add(
                            CustomQuickLink(
                              id: 'ql_${now.microsecondsSinceEpoch}',
                              surahNumber: selectedSurah,
                              label: customLabel,
                              createdAt: now,
                              updatedAt: now,
                            ),
                          );
                        });
                        _saveQuickLinks();
                        Navigator.pop(context);
                      },
                      child: const Text('Add Link'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchResultsSliver(
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final query = _searchController.text.toLowerCase();

    final surahs =
        [
          for (var id = 1; id <= 114; id++)
            (
              id: id.toString(),
              name: widget.repository.getSurahName(id.toString()),
              count: widget.repository.getSurahVerses(id.toString()).length,
            ),
        ].where((surah) {
          return query.isEmpty ||
              surah.id.contains(query) ||
              surah.name.toLowerCase().contains(query);
        }).toList();

    final List<Widget> results = [];

    // Surah Matches
    for (var surah in surahs) {
      results.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            tileColor: colorScheme.surfaceContainerLow,
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                surah.id,
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              surah.name,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              '${surah.count} ayat',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: colorScheme.onSurfaceVariant,
            ),
            onTap: () => _chooseBrowseDestination(surah.id, '1'),
          ),
        ),
      );
    }

    // Verse Matches (Translation Search)
    if (query.length >= 2) {
      int verseMatchCount = 0;
      outer:
      for (var id = 1; id <= 114; id++) {
        final verses = widget.repository.getSurahVerses(id.toString());
        for (var verse in verses) {
          if (verse.thaiV3.toLowerCase().contains(query) ||
              verse.thaiV2.toLowerCase().contains(query) ||
              verse.english.toLowerCase().contains(query) ||
              (verse.shortTafsir?.toLowerCase().contains(query) ?? false) ||
              (verse.shortTafsirEn?.toLowerCase().contains(query) ?? false)) {
            final surahName = widget.repository.getSurahName(verse.surahId);
            final sId = int.tryParse(verse.surahId) ?? 1;
            final vId = int.tryParse(verse.id) ?? 1;
            final mushafPage = qcf.getPageNumber(sId, vId);

            results.add(
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    side: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  tileColor: colorScheme.surface,
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '$surahName, ${context.tr('ayah')} ${verse.id}',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => _navigateToMushafFreeReadPage(
                          mushafPage,
                          highlightedVerseKey: '$sId:$vId',
                        ),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.import_contacts,
                                size: 12,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'มุศหัฟ',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      verse.thaiV3,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  onTap: () {
                    if (_selectedTabIndex == 1) {
                      _navigateToMushafFreeReadPage(
                        mushafPage,
                        highlightedVerseKey: '$sId:$vId',
                      );
                    } else {
                      _navigateToReading(
                        context,
                        verse.surahId,
                        verseId: verse.id,
                      );
                    }
                  },
                ),
              ),
            );

            verseMatchCount++;
            if (verseMatchCount >= 30) break outer;
          }
        }
      }
    }

    if (results.isEmpty) {
      return SliverList(
        delegate: SliverChildListDelegate([
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Center(
              child: Text(
                'No results found for "$query"',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        ]),
      );
    }

    return SliverList(
      delegate: SliverChildListDelegate([
        Text(
          'Search Results',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        ...results,
      ]),
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
    final safeLabel = base64Url.encode(utf8.encode(label)).replaceAll('=', '');
    return 'ql_${surahNumber}_$safeLabel';
  }
}
