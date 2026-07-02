import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:qcf_quran/qcf_quran.dart' as qcf;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/quran_foundation_repository.dart';
import '../data/quran_repository.dart';
import '../models/mushaf_models.dart';
import '../providers/local_reading_provider.dart';
import '../providers/mushaf_reading_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/supabase_provider.dart';
import '../providers/notes_provider.dart';
import '../theme/app_theme.dart';
import 'mushaf_reader_screen.dart';
import 'reading_screen.dart';
import 'settings_screen.dart';
import 'bookmarks_screen.dart';
import 'profile_screen.dart';
import 'browse_screen.dart';

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
                child: Icon(icon, size: 24, color: colorScheme.onPrimaryContainer),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
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

  const HomeScreen({super.key, required this.repository});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final QuranFoundationRepository _foundationRepository = QuranFoundationRepository();
  int _selectedTabIndex = 0; // 0: Meaningful Read, 1: Mushaf Read, 2: Quick Links
  int _navIndex = 0;
  bool _isInit = false;

  final ScrollController _capsuleScrollController = ScrollController();

  final List<Map<String, dynamic>> _tabs = [
    {'title': "Meaningful Read", 'icon': Icons.menu_book},
    {'title': "Mushaf Read", 'icon': Icons.import_contacts},
    {'title': "Quick Links", 'icon': Icons.flash_on},
  ];

  List<CustomQuickLink> _quickLinks = [];

  @override
  void initState() {
    super.initState();
    _loadQuickLinks();
    _searchController.addListener(() {
      setState(() {});
    });
    _initApp();
  }

  Future<void> _initApp() async {
    await widget.repository.init();
    if (mounted) {
      setState(() {
        _isInit = true;
      });
    }
  }

  Future<void> _loadQuickLinks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? linksJson = prefs.getString('custom_quick_links');
    if (linksJson != null) {
      final List<dynamic> decoded = jsonDecode(linksJson);
      setState(() {
        _quickLinks = decoded.map((e) => CustomQuickLink.fromJson(e as Map<String, dynamic>)).toList();
      });
    } else {
      setState(() {
        _quickLinks = [
          CustomQuickLink(surahNumber: 67, label: "Don't forget to read every night.", isLocked: true),
          CustomQuickLink(surahNumber: 18, label: "Read every Friday.", isLocked: true),
        ];
      });
      _saveQuickLinks();
    }
  }

  Future<void> _saveQuickLinks() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_quickLinks.map((e) => e.toJson()).toList());
    await prefs.setString('custom_quick_links', encoded);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _capsuleScrollController.dispose();
    super.dispose();
  }

  void _navigateToReading(
    BuildContext context,
    String surahId, {
    String? verseId,
    int? verseIndex,
    bool saveToFreeReadOnly = false,
  }) {
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
        ),
      ),
    );
  }

  Future<void> _navigateToMushafFreeReadPage(int pageNumber) async {
    final mushafProvider = context.read<MushafReadingProvider>();
    final profile = await mushafProvider.openUnifiedFreeRead();
    await mushafProvider.updateProgress(
      profileId: profile.id,
      pageNumber: pageNumber,
    );
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MushafReaderScreen(
          quranRepository: widget.repository,
          foundationRepository: _foundationRepository,
          profileId: profile.id,
        ),
      ),
    );
  }

  Future<void> _chooseBrowseDestination(String surahId, String verseId) async {
    final colorScheme = Theme.of(context).colorScheme;
    final surah = int.tryParse(surahId) ?? 1;
    final verse = int.tryParse(verseId) ?? 1;
    final pageNumber = qcf.getPageNumber(surah, verse);
    final destination = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radius)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Select Reading Mode',
                style: GoogleFonts.inter(
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
                      title: 'Verse-by-Verse',
                      subtitle: 'Translation & Audio',
                      onTap: () => Navigator.pop(sheetContext, 'readspace'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ModeSelectionCard(
                      icon: Icons.import_contacts,
                      title: 'Mushaf Page',
                      subtitle: 'Page $pageNumber',
                      onTap: () => Navigator.pop(sheetContext, 'mushaf'),
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
      await _navigateToMushafFreeReadPage(pageNumber);
      return;
    }
    _navigateToReading(
      context,
      surahId,
      verseId: verseId,
      saveToFreeReadOnly: true,
    );
  }

  Future<Map<String, String>> _fetchArabicPreviewForPage(int page) async {
    try {
      final mushafPage = await _foundationRepository.fetchPage(mushafId: 2, pageNumber: page);
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

  Widget _buildDailyReadTracker(ColorScheme colorScheme) {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final statuses = ['read', 'read', 'missed', 'read', 'today', 'future', 'future'];
    
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16, left: 24, right: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (index) {
          final isToday = statuses[index] == 'today';
          final status = statuses[index];
          
          Color circleColor;
          if (status == 'read') {
            circleColor = Colors.green;
          } else if (status == 'missed') {
            circleColor = Colors.red;
          } else if (status == 'today') {
            circleColor = colorScheme.primary;
          } else {
            circleColor = colorScheme.outlineVariant;
          }

          return Column(
            children: [
              Text(
                days[index],
                style: GoogleFonts.inter(
                  fontSize: isToday ? 11 : 9,
                  fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                  color: isToday ? colorScheme.primary : colorScheme.onSurfaceVariant,
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
                  border: Border.all(color: circleColor, width: isToday ? 2.0 : 1.0),
                ),
                child: isToday 
                    ? Icon(Icons.menu_book, size: 14, color: colorScheme.primary) 
                    : (status == 'read' 
                        ? Icon(Icons.check, size: 12, color: Colors.green)
                        : (status == 'missed' 
                            ? Icon(Icons.close, size: 12, color: Colors.red)
                            : null)),
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

    if (!_isInit) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        ),
      );
    }

    final isSearching = _searchController.text.isNotEmpty;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      bottomNavigationBar: NavigationBar(
        height: 52,
        selectedIndex: _navIndex,
        onDestinationSelected: (index) {
          setState(() => _navIndex = index);
        },
        elevation: 0,
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.secondaryContainer.withValues(alpha: 0.5),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.format_list_bulleted_outlined),
            selectedIcon: Icon(Icons.format_list_bulleted),
            label: 'Surahs',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_outline),
            selectedIcon: Icon(Icons.bookmark),
            label: 'Bookmarks',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_circle_outlined),
            selectedIcon: Icon(Icons.account_circle),
            label: 'Profile',
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
                  padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 16),
                  child: Column(
                    children: [
                      // ROW 1: THE WELCOME TYPOGRAPHY HEADER
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Salam, Chareef 👋',
                                  style: textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Which Surah you want to read?',
                                  style: textTheme.bodyLarge?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
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
                                MaterialPageRoute(builder: (_) => const SettingsScreen()),
                              );
                            },
                            borderRadius: BorderRadius.circular(24),
                            child: CircleAvatar(
                              radius: 24,
                              backgroundColor: colorScheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.settings,
                                color: colorScheme.onSurface,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // CARD/PILL SEARCH INPUT MATRIX
                      Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search Surah, Page, Meaning...',
                            hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(left: 16.0, right: 8.0),
                              child: Icon(
                                Icons.search,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            suffixIcon: Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: IconButton(
                                icon: Icon(
                                  Icons.arrow_forward_ios,
                                  size: 18,
                                  color: colorScheme.primary,
                                ),
                                onPressed: () {
                                  FocusScope.of(context).unfocus();
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                if (!isSearching) ...[
                  // Daily Read Checks Tracker
                  _buildDailyReadTracker(colorScheme),

                  // ROW 2: HORIZONTAL CAPSULE MENUS
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      controller: _capsuleScrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: _tabs.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final isActive = _selectedTabIndex == index;
                        final tab = _tabs[index];
                        return InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () {
                            setState(() {
                              _selectedTabIndex = index;
                            });
                            final screenWidth = MediaQuery.of(context).size.width;
                            final offset = (index * 150.0) - (screenWidth / 2) + 75.0;
                            _capsuleScrollController.animateTo(
                              offset.clamp(0.0, _capsuleScrollController.position.maxScrollExtent),
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeOutCubic,
                            );
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isActive ? colorScheme.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(24),
                              border: isActive ? null : Border.all(color: colorScheme.outline),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  tab['icon'] as IconData,
                                  size: 16,
                                  color: isActive ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  tab['title'] as String,
                                  style: TextStyle(
                                    color: isActive ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
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
            else
              _buildDynamicDockSliver(colorScheme, textTheme),
              
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
      BookmarksScreen(repository: widget.repository),
      // 3: Profile
      const ProfileScreen(),
    ],
  ),
);
  }

  Widget _buildDynamicDockSliver(ColorScheme colorScheme, TextTheme textTheme) {
    if (_selectedTabIndex == 0) {
      // Meaningful Read
      return SliverList(
        delegate: SliverChildListDelegate([
          _buildMeaningfulReadSection(colorScheme, textTheme)
        ]),
      );
    } else if (_selectedTabIndex == 1) {
      // Mushaf Read
      return SliverList(
        delegate: SliverChildListDelegate([
          _buildMushafReadSection(colorScheme, textTheme)
        ]),
      );
    } else if (_selectedTabIndex == 2) {
      // Quick Links
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        sliver: _buildQuickLinksSliverList(colorScheme, textTheme),
      );
    }
    return const SliverToBoxAdapter(child: SizedBox());
  }

  Future<void> _triggerAutoSync() async {
    final supabaseProv = Provider.of<SupabaseProvider>(context, listen: false);
    if (supabaseProv.isLoggedIn && supabaseProv.user != null) {
      final userId = supabaseProv.user!.id;
      await Provider.of<NotesProvider>(context, listen: false).syncWithSupabase();
      await Provider.of<LocalReadingProvider>(context, listen: false).syncBookmarksAndProfilesWithSupabase(userId);
      await Provider.of<MushafReadingProvider>(context, listen: false).syncWithSupabase(userId);
    }
  }

  int _getAbsoluteVerseIndex(int surah, int verse) {
    int index = 0;
    for (int i = 1; i < surah; i++) {
      index += widget.repository.getSurahVerses(i.toString()).length;
    }
    return index + verse;
  }

  Widget _buildMeaningfulReadSection(ColorScheme colorScheme, TextTheme textTheme) {
    final localReading = Provider.of<LocalReadingProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);

    final customProfiles = localReading.profiles.where((p) => !isFreeReadProfile(p) && !p.isArchived).toList();
    final freeReadProfile = localReading.profiles.where((p) => isFreeReadProfile(p)).firstOrNull;
    
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
                'Meaningful Read',
                style: GoogleFonts.inter(
                  color: colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please switch to the main Home tab to create a goal for now.')),
                  );
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Goal'),
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
            'เพิ่มความสนิทสนมกับอัลกุรอาน โดยการอ่านอัลกุรอานพร้อมความหมาย ใคร่ครวญไตร่ตรองทีละอายะห์ อินชาอัลลอฮฺ',
            style: GoogleFonts.notoSansThai(
              color: colorScheme.onSurfaceVariant,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 320,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: allItems.length,
            itemBuilder: (context, index) {
              final item = allItems[index];
              if (item == 'add_goal') {
                return _buildAddGoalCard(colorScheme);
              }
              if (item == 'guest_read') {
                return _buildMeaningfulGuestCard(colorScheme, settings, index);
              }
              return _buildMeaningfulProfileCard(item as LocalReadingProfile, colorScheme, settings, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMushafReadSection(ColorScheme colorScheme, TextTheme textTheme) {
    final mushafReading = Provider.of<MushafReadingProvider>(context);
    final customProfiles = mushafReading.activeCustomProfiles;
    final freeReadProfile = mushafReading.profiles.where((p) => p.isFreeRead && !p.isArchived).firstOrNull;
    
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
                'Mushaf Read',
                style: GoogleFonts.inter(
                  color: colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please switch to the main Home tab to create a goal for now.')),
                  );
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Goal'),
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
            'อ่านอัลกุรอานจากหน้ามุสฮัฟเพื่อความเคยชินและสะดวกในการจดจำ',
            style: GoogleFonts.notoSansThai(
              color: colorScheme.onSurfaceVariant,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 320,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: allItems.length,
            itemBuilder: (context, index) {
              final item = allItems[index];
              if (item == 'add_goal') {
                return _buildAddGoalCard(colorScheme);
              }
              if (item == 'guest_read') {
                 return _buildMushafGuestCard(colorScheme, index);
              }
              return _buildMushafProfileCard(item as MushafProfile, colorScheme, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMeaningfulProfileCard(LocalReadingProfile profile, ColorScheme colorScheme, SettingsProvider settings, int index) {
    bool isFreeRead = isFreeReadProfile(profile);
    double? progressPercent;
    
    if (!isFreeRead && profile.planMode != 'mushaf' && profile.target != null) {
      final startAbs = _getAbsoluteVerseIndex(int.parse(profile.start.surahId), int.parse(profile.start.verseId));
      final currentAbs = _getAbsoluteVerseIndex(int.parse(profile.current.surahId), int.parse(profile.current.verseId));
      final targetAbs = _getAbsoluteVerseIndex(int.parse(profile.target!.surahId), int.parse(profile.target!.verseId));
      
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
      continueSurah: profile.current.surahId,
      continueVerse: profile.current.verseId,
      imageIndex: index,
      progressPercent: progressPercent,
      onDelete: isFreeRead ? null : () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Goal?'),
            content: const Text('Are you sure you want to delete this goal? This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirm == true) {
          if (mounted) {
            context.read<LocalReadingProvider>().archiveProfile(profile.id);
          }
        }
      },
      onContinue: () {
         context.read<LocalReadingProvider>().setActiveProfile(profile.id);
         _navigateToReading(context, profile.current.surahId, verseId: profile.current.verseId);
      },
      onEdit: isFreeRead ? null : () => _showEditMeaningfulGoalDialog(profile),
    );
  }

  Future<void> _showEditMeaningfulGoalDialog(LocalReadingProfile profile) async {
    final TextEditingController nameCtrl = TextEditingController(text: profile.name);
    final colorScheme = Theme.of(context).colorScheme;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Goal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Goal Name'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset Progress'),
                onPressed: () {
                  Navigator.pop(ctx);
                  context.read<LocalReadingProvider>().updateProfileProgress(
                    profile.id,
                    profile.start,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Goal progress reset.')));
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                context.read<LocalReadingProvider>().updateProfile(
                  profileId: profile.id,
                  name: nameCtrl.text.trim(),
                  start: profile.start,
                  target: profile.target,
                  planMode: profile.planMode,
                  startJuz: profile.startJuz,
                  targetJuz: profile.targetJuz,
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildMeaningfulGuestCard(ColorScheme colorScheme, SettingsProvider settings, int index) {
    return _buildMeaningfulCardLayout(
      colorScheme: colorScheme,
      settings: settings,
      isFreeRead: true,
      profileName: 'Just Read',
      continueSurah: '1',
      continueVerse: '1',
      imageIndex: index,
      onContinue: () {
         _navigateToReading(context, '1', verseId: '1', saveToFreeReadOnly: true);
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
    required int imageIndex,
    required VoidCallback onContinue,
    VoidCallback? onDelete,
    VoidCallback? onEdit,
    double? progressPercent,
  }) {
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
      width: MediaQuery.of(context).size.width * 0.85,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        image: DecorationImage(
          image: AssetImage('assets/images/image_slider${imageNumber}_x.webp'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.55), BlendMode.darken),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: textColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: textColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_stories, size: 12, color: textColor),
                          const SizedBox(width: 4),
                          Text(
                            profileName.toUpperCase(),
                            style: GoogleFonts.inter(
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
                                child: Icon(Icons.edit, size: 14, color: textColor),
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
                              child: Icon(Icons.delete_outline, size: 16, color: colorScheme.onError),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.repository.getSurahName(continueSurah),
                  style: GoogleFonts.prompt(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Current ayah $continueSurah:$continueVerse',
                  style: GoogleFonts.inter(
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
                          valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                          minHeight: 4,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(progressPercent * 100).toInt()}%',
                        style: GoogleFonts.inter(
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: textColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border(
                        left: BorderSide(color: textColor.withValues(alpha: 0.6), width: 3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TRANSLATION',
                          style: GoogleFonts.inter(
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
                          style: GoogleFonts.inter(
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
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: textColor,
                      foregroundColor: colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 0,
                    ),
                    onPressed: onContinue,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Continue Reading',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMushafProfileCard(MushafProfile profile, ColorScheme colorScheme, int index) {
    bool isFreeRead = profile.isFreeRead;
    double? progressPercent;
    
    if (!isFreeRead && profile.startPage != null && profile.targetPage != null) {
      final start = profile.startPage!;
      final target = profile.targetPage!;
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
      profileName: profile.name,
      page: profile.currentPage,
      imageIndex: index,
      progressPercent: progressPercent,
      onDelete: isFreeRead ? null : () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Goal?'),
            content: const Text('Are you sure you want to delete this goal? This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirm == true) {
          if (mounted) {
            context.read<MushafReadingProvider>().archiveProfile(profile.id);
          }
        }
      },
      onContinue: () => _navigateToMushafFreeReadPage(profile.currentPage),
      onEdit: isFreeRead ? null : () => _showEditMushafGoalDialog(profile),
    );
  }

  Future<void> _showEditMushafGoalDialog(MushafProfile profile) async {
    final TextEditingController nameCtrl = TextEditingController(text: profile.name);
    final colorScheme = Theme.of(context).colorScheme;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Goal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Goal Name'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset Progress'),
                onPressed: () {
                  Navigator.pop(ctx);
                  context.read<MushafReadingProvider>().updateProgress(
                    profileId: profile.id,
                    pageNumber: profile.startPage ?? 1,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Goal progress reset.')));
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                context.read<MushafReadingProvider>().updateProfile(
                  profile.id,
                  name: nameCtrl.text.trim(),
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildMushafGuestCard(ColorScheme colorScheme, int index) {
    return _buildMushafCardLayout(
      colorScheme: colorScheme,
      isFreeRead: true,
      profileName: 'Just Read',
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
    VoidCallback? onDelete,
    VoidCallback? onEdit,
    double? progressPercent,
  }) {
    final textColor = Colors.white;
    // Offset image for Mushaf Read so it looks different (e.g., 5, 1, 2, 3, 4)
    final imageNumber = ((imageIndex + 4) % 5) + 1;

    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        image: DecorationImage(
          image: AssetImage('assets/images/image_slider${imageNumber}_x.webp'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.65), BlendMode.darken),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: textColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: textColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.import_contacts, size: 12, color: textColor),
                          const SizedBox(width: 4),
                          Text(
                            profileName.toUpperCase(),
                            style: GoogleFonts.inter(
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
                                child: Icon(Icons.edit, size: 14, color: textColor),
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
                              child: Icon(Icons.delete_outline, size: 16, color: colorScheme.onError),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Page $page',
                  style: GoogleFonts.prompt(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (progressPercent != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: progressPercent,
                          backgroundColor: textColor.withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                          minHeight: 4,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(progressPercent * 100).toInt()}%',
                        style: GoogleFonts.inter(
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
                    future: _fetchArabicPreviewForPage(page),
                    builder: (context, snapshot) {
                      final data = snapshot.data ?? {};
                      final arabicText = data['arabic'] ?? '';
                      final surahId = data['surahId'] ?? '';
                      final verseId = data['verseId'] ?? '';

                      if (arabicText.isEmpty) {
                         // Fallback or loading state
                         return const SizedBox.shrink();
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(
                            '${widget.repository.getSurahName(surahId)} • Ayah $verseId',
                            style: GoogleFonts.inter(
                              color: textColor.withValues(alpha: 0.85),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: textColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              arabicText,
                              maxLines: 1,
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
                        ],
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: textColor,
                      foregroundColor: colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 0,
                    ),
                    onPressed: onContinue,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Continue Reading',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddGoalCard(ColorScheme colorScheme) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radius * 1.2),
        border: Border.all(color: colorScheme.outline, width: 2),
      ),
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please switch to the main Home tab to create a goal for now.')),
          );
        },
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
              child: Icon(Icons.add, size: 32, color: colorScheme.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            Text(
              'Add New Goal',
              style: GoogleFonts.inter(
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

  Widget _buildQuickLinksSliverList(ColorScheme colorScheme, TextTheme textTheme) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == _quickLinks.length) {
            if (_quickLinks.length >= 7) return const SizedBox();
            return Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 24),
              child: FilledButton.tonalIcon(
                onPressed: _showAddQuickLinkSheet,
                icon: const Icon(Icons.add),
                label: const Text('Add Quick Link'),
              ),
            );
          }

          final link = _quickLinks[index];
          final surahName = widget.repository.getSurahName(link.surahNumber.toString());
          final versesCount = widget.repository.getSurahVerses(link.surahNumber.toString()).length;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              color: colorScheme.surface,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                onTap: () => _chooseBrowseDestination(link.surahNumber.toString(), '1'),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${link.surahNumber}',
                          style: textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              surahName,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              link.label.isNotEmpty ? link.label : '$versesCount Verses',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!link.isLocked)
                        IconButton(
                          icon: Icon(Icons.remove_circle_outline, color: colorScheme.error),
                          onPressed: () {
                            setState(() {
                              _quickLinks.removeAt(index);
                            });
                            _saveQuickLinks();
                          },
                        )
                      else
                        Icon(
                          Icons.lock_outline,
                          size: 16,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        childCount: _quickLinks.length + 1,
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
            final colorScheme = Theme.of(context).colorScheme;
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
                  Text('Add Quick Link', style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Text('Select Surah', style: textTheme.titleSmall),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: selectedSurah,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items: List.generate(114, (i) {
                      final sNum = i + 1;
                      return DropdownMenuItem(
                        value: sNum,
                        child: Text('$sNum. ${widget.repository.getSurahName(sNum.toString())}'),
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (val) => customLabel = val,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: () {
                        setState(() {
                          _quickLinks.add(CustomQuickLink(
                            surahNumber: selectedSurah,
                            label: customLabel,
                          ));
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

  Widget _buildSearchResultsSliver(ColorScheme colorScheme, TextTheme textTheme) {
    final query = _searchController.text.toLowerCase();
    
    final surahs = [
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
            title: Text(surah.name, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            subtitle: Text('${surah.count} ayat', style: TextStyle(color: colorScheme.onSurfaceVariant)),
            trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
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
              (verse.shortTafsir?.toLowerCase().contains(query) ?? false)) {
            
            final surahName = widget.repository.getSurahName(verse.surahId);
            results.add(
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  tileColor: colorScheme.surface,
                  title: Text('$surahName, Ayah ${verse.id}', style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    verse.thaiV3,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                  ),
                  trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant, size: 16),
                  onTap: () => _navigateToReading(context, verse.surahId, verseId: verse.id),
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
          )
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
  final int surahNumber;
  final String label;
  final bool isLocked;

  CustomQuickLink({
    required this.surahNumber,
    required this.label,
    this.isLocked = false,
  });

  Map<String, dynamic> toJson() => {
    'surahNumber': surahNumber,
    'label': label,
    'isLocked': isLocked,
  };

  factory CustomQuickLink.fromJson(Map<String, dynamic> json) => CustomQuickLink(
    surahNumber: json['surahNumber'],
    label: json['label'] ?? '',
    isLocked: json['isLocked'] ?? false,
  );
}
