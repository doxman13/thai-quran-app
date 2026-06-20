// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/progress_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/stats_provider.dart';
import '../providers/local_reading_provider.dart';
import '../data/quran_repository.dart';
import '../shared/shared.dart';
import 'reading_screen.dart';
import 'bookmarks_screen.dart';
import 'notes_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final QuranRepository repository;

  const HomeScreen({Key? key, required this.repository}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isInit = false;

  @override
  void initState() {
    super.initState();
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

  void _navigateToReading(
    BuildContext context,
    String surahId,
    int jumpToIndex,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReadingScreen(
          repository: widget.repository,
          initialSurah: surahId,
          initialVerseIndex: jumpToIndex,
        ),
      ),
    );
  }

  void _navigateToBookmarks(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookmarksScreen(repository: widget.repository),
      ),
    );

    if (result != null && mounted) {
      final targetSurah = result['surahId'];
      if (result.containsKey('verseIndex')) {
        _navigateToReading(context, targetSurah, result['verseIndex']);
      } else if (result.containsKey('verseId')) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReadingScreen(
              repository: widget.repository,
              initialSurah: targetSurah,
              initialVerseId: result['verseId'],
            ),
          ),
        );
      }
    }
  }

  void _navigateToNotes(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotesScreen(repository: widget.repository),
      ),
    );
  }

  Future<void> _showCreateProfileDialog(BuildContext context) async {
    final provider = Provider.of<LocalReadingProvider>(context, listen: false);
    final nameController = TextEditingController();
    var planMode = 'by_surah';
    var startSurah = '1';
    var startAyah = '1';
    var endSurah = '1';
    var endAyah = '1';
    var startJuz = 1;
    var endJuz = 1;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            final primary = Provider.of<SettingsProvider>(
              context,
              listen: false,
            ).getPrimaryColor();
            final startAyahCount = widget.repository
                .getSurahVerses(startSurah)
                .length;
            final endAyahCount = widget.repository
                .getSurahVerses(endSurah)
                .length;
            startAyah = _clampAyah(startAyah, startAyahCount);
            endAyah = _clampAyah(endAyah, endAyahCount);

            return AlertDialog(
              title: Text(
                'Create Reading Profile',
                style: GoogleFonts.prompt(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Profile name',
                        hintText: 'Ramadan 2026',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: planMode,
                      decoration: const InputDecoration(labelText: 'Plan mode'),
                      items: const [
                        DropdownMenuItem(
                          value: 'by_juz',
                          child: Text('By Juz'),
                        ),
                        DropdownMenuItem(
                          value: 'by_surah',
                          child: Text('By Surah'),
                        ),
                        DropdownMenuItem(
                          value: 'by_ayat',
                          child: Text('By Ayat'),
                        ),
                        DropdownMenuItem(
                          value: 'custom',
                          child: Text('Custom'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          planMode = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    if (planMode == 'by_juz') ...[
                      Row(
                        children: [
                          Expanded(
                            child: _buildNumberDropdown(
                              label: 'Start Juz',
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
                            child: _buildNumberDropdown(
                              label: 'End Juz',
                              value: endJuz,
                              min: startJuz,
                              max: 30,
                              onChanged: (value) {
                                setDialogState(() => endJuz = value);
                              },
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: _buildSurahDropdown(
                              label: 'Start Surah',
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
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildSurahDropdown(
                              label: 'End Surah',
                              value: endSurah,
                              min: int.parse(startSurah),
                              onChanged: (value) {
                                setDialogState(() => endSurah = value);
                              },
                            ),
                          ),
                        ],
                      ),
                      if (planMode == 'by_ayat' || planMode == 'custom') ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildAyahDropdown(
                                label: 'Start Ayah',
                                value: startAyah,
                                max: startAyahCount,
                                onChanged: (value) {
                                  setDialogState(() => startAyah = value);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildAyahDropdown(
                                label: 'End Ayah',
                                value: endAyah,
                                max: endAyahCount,
                                onChanged: (value) {
                                  setDialogState(() => endAyah = value);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                    if (!provider.canCreateProfile) ...[
                      const SizedBox(height: 12),
                      Text(
                        'You already have $maxActiveReadingProfiles active profiles.',
                        style: GoogleFonts.prompt(
                          color: theme.colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text('Cancel', style: GoogleFonts.prompt()),
                ),
                ElevatedButton(
                  onPressed: provider.canCreateProfile
                      ? () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) return;

                          final startRef = planMode == 'by_juz'
                              ? _juzStartRef(startJuz)
                              : toVerseRef(
                                  startSurah,
                                  planMode == 'by_surah' ? 1 : startAyah,
                                );
                          final targetRef = planMode == 'by_juz'
                              ? _juzStartRef(endJuz)
                              : toVerseRef(
                                  endSurah,
                                  planMode == 'by_surah' ? 1 : endAyah,
                                );

                          await provider.createProfile(
                            name: name,
                            planMode: planMode,
                            startJuz: planMode == 'by_juz' ? startJuz : null,
                            targetJuz: planMode == 'by_juz' ? endJuz : null,
                            start: startRef,
                            target: targetRef,
                          );

                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Create', style: GoogleFonts.prompt()),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = Provider.of<ProgressProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final stats = Provider.of<StatsProvider>(context);
    final localReading = Provider.of<LocalReadingProvider>(context);

    final themeColor = settings.getPrimaryColor();
    final activeProfile = localReading.activeProfile;
    final continueSurahId =
        activeProfile?.current.surahId ?? progress.currentSurahId;
    final continueVerseId = activeProfile?.current.verseId;
    final continueVerseIndex = continueVerseId == null
        ? progress.lastVerseIndex
        : (int.tryParse(continueVerseId) ?? 1) - 1;

    if (!_isInit) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.teal)),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // Top Bar with App Name and Settings Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'อัลกุรอานแปลไทย',
                        style: GoogleFonts.prompt(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: themeColor,
                        ),
                      ),
                      Text(
                        'Thai Quran Translation Dashboard',
                        style: GoogleFonts.prompt(
                          fontSize: 14,
                          color: isDark
                              ? Colors.blueGrey.shade400
                              : Colors.blueGrey.shade600,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.account_circle,
                          color: themeColor,
                          size: 28,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProfileScreen(),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          settings.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                          color: themeColor,
                        ),
                        onPressed: () {
                          settings.toggleDarkMode(!settings.isDarkMode);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Streak & Stats Dashboard Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [
                            themeColor.withOpacity(0.15),
                            themeColor.withOpacity(0.35),
                          ]
                        : [
                            themeColor.withOpacity(0.05),
                            themeColor.withOpacity(0.12),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: themeColor.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.local_fire_department,
                              color: Colors.orange.shade700,
                              size: 28,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${stats.streakCount} Day Streak',
                              style: GoogleFonts.prompt(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          stats.streakCount > 0
                              ? 'Keep it up!'
                              : 'Start reading!',
                          style: GoogleFonts.prompt(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          'Today',
                          stats.todayReadCount.toString(),
                          isDark,
                        ),
                        _buildStatItem(
                          'This Week',
                          stats.weekReadCount.toString(),
                          isDark,
                        ),
                        _buildStatItem(
                          'This Month',
                          stats.monthReadCount.toString(),
                          isDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          'Read Completed',
                          progress.completedReadCount.toString(),
                          isDark,
                        ),
                        _buildStatItem(
                          'Check Completed',
                          progress.completedCheckCount.toString(),
                          isDark,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Profile Selector & Continue Card
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Active Reading Profile',
                      style: GoogleFonts.prompt(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.blueGrey.shade200
                            : Colors.blueGrey.shade800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButton<String>(
                        value: activeProfile?.id,
                        dropdownColor: isDark
                            ? const Color(0xFF1E293B)
                            : Colors.white,
                        style: GoogleFonts.prompt(
                          color: themeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        underline: Container(height: 1.5, color: themeColor),
                        items: localReading.activeProfiles.map((profile) {
                          return DropdownMenuItem<String>(
                            value: profile.id,
                            child: Text(profile.name),
                          );
                        }).toList(),
                        onChanged: (profileId) {
                          if (profileId != null) {
                            localReading.setActiveProfile(profileId);
                          }
                        },
                      ),
                      IconButton(
                        tooltip: 'Create profile',
                        onPressed: localReading.canCreateProfile
                            ? () => _showCreateProfileDialog(context)
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                        color: themeColor,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Continue Reading Card for Active Profile
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      themeColor,
                      themeColor.withRed((themeColor.red - 20).clamp(0, 255)),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: themeColor.withOpacity(0.35),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.bookmark_added,
                          color: Colors.white70,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          activeProfile?.target == null
                              ? '${activeProfile?.name ?? 'Free Read'}'
                              : '${activeProfile?.name ?? 'Free Read'} Progress',
                          style: GoogleFonts.prompt(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.repository.getSurahName(continueSurahId),
                      style: GoogleFonts.prompt(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      activeProfile?.target == null
                          ? 'Free Read has no target'
                          : 'Current Ayah: ${continueVerseIndex + 1}',
                      style: GoogleFonts.prompt(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => _navigateToReading(
                        context,
                        continueSurahId,
                        continueVerseIndex,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: themeColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Continue Reading',
                        style: GoogleFonts.prompt(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Quick Actions Grid
              Text(
                'Quick Actions',
                style: GoogleFonts.prompt(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? Colors.blueGrey.shade200
                      : Colors.blueGrey.shade800,
                ),
              ),
              const SizedBox(height: 12),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.3,
                children: [
                  _buildActionCard(
                    context,
                    title: 'Read from Start',
                    icon: Icons.play_arrow_rounded,
                    color: Colors.indigo.shade400,
                    onTap: () => _navigateToReading(context, '1', 0),
                  ),
                  _buildActionCard(
                    context,
                    title: 'My Bookmarks',
                    icon: Icons.bookmarks_rounded,
                    color: Colors.amber.shade600,
                    onTap: () => _navigateToBookmarks(context),
                  ),
                  _buildActionCard(
                    context,
                    title: 'Personal Notes',
                    icon: Icons.edit_note,
                    color: Colors.teal.shade600,
                    onTap: () => _navigateToNotes(context),
                  ),
                  _buildActionCard(
                    context,
                    title: 'Settings',
                    icon: Icons.settings_accessibility,
                    color: Colors.purple.shade400,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReadingScreen(
                            repository: widget.repository,
                            initialSurah: progress.currentSurahId,
                            initialVerseIndex: progress.lastVerseIndex,
                            openSettingsPanel: true,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildActionCard(
                    context,
                    title: 'Audit Sync & Progress',
                    icon: Icons.sync,
                    color: Colors.blueGrey.shade500,
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      final localAudits =
                          prefs.getStringList('local_audits') ?? [];
                      final completedCheck = Provider.of<ProgressProvider>(
                        context,
                        listen: false,
                      ).completedCheckCount;

                      if (context.mounted) {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(
                              'Audit Sync Status',
                              style: GoogleFonts.prompt(
                                fontWeight: FontWeight.bold,
                                color: themeColor,
                              ),
                            ),
                            backgroundColor: isDark
                                ? const Color(0xFF1E293B)
                                : Colors.white,
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '• Completely Audited: ~$completedCheck Surahs',
                                  style: GoogleFonts.prompt(
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '• Unsynced Local Audits: ${localAudits.length}',
                                  style: GoogleFonts.prompt(
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '(Note: The app automatically syncs audits to the web when submitting. This card shows your local progress.)',
                                  style: GoogleFonts.prompt(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: Text(
                                  'Close',
                                  style: GoogleFonts.prompt(color: themeColor),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.prompt(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.grey.shade800,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.prompt(
            fontSize: 11,
            color: isDark ? Colors.blueGrey.shade400 : Colors.blueGrey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildNumberDropdown({
    required String label,
    required int value,
    required int max,
    int min = 1,
    required ValueChanged<int> onChanged,
  }) {
    final effectiveMin = min;
    final effectiveMax = max < min ? min : max;
    final safeValue = value < effectiveMin ? effectiveMin : (value > effectiveMax ? effectiveMax : value);
    return DropdownButtonFormField<int>(
      key: ValueKey('number_dropdown_${label}_${effectiveMin}_$effectiveMax'),
      value: safeValue,
      decoration: InputDecoration(labelText: label),
      items: [
        for (var number = effectiveMin; number <= effectiveMax; number++)
          DropdownMenuItem(value: number, child: Text(number.toString())),
      ],
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }

  Widget _buildSurahDropdown({
    required String label,
    required String value,
    int min = 1,
    required ValueChanged<String> onChanged,
  }) {
    final parsed = int.tryParse(value) ?? 1;
    final effectiveMin = min < 1 ? 1 : (min > 114 ? 114 : min);
    final safeValue = parsed < effectiveMin ? effectiveMin : (parsed > 114 ? 114 : parsed);
    return DropdownButtonFormField<String>(
      key: ValueKey('surah_dropdown_${label}_$effectiveMin'),
      value: safeValue.toString(),
      decoration: InputDecoration(labelText: label),
      items: [
        for (var surah = effectiveMin; surah <= 114; surah++)
          DropdownMenuItem(
            value: surah.toString(),
            child: Text(widget.repository.getSurahName(surah.toString())),
          ),
      ],
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }

  Widget _buildAyahDropdown({
    required String label,
    required String value,
    required int max,
    required ValueChanged<String> onChanged,
  }) {
    final normalizedValue = _clampAyah(value, max);
    final effectiveMax = max < 1 ? 1 : max;
    return DropdownButtonFormField<String>(
      key: ValueKey('ayah_dropdown_${label}_$effectiveMax'),
      value: normalizedValue,
      decoration: InputDecoration(labelText: label),
      items: [
        for (var ayah = 1; ayah <= effectiveMax; ayah++)
          DropdownMenuItem(
            value: ayah.toString(),
            child: Text(ayah.toString()),
          ),
      ],
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }

  String _clampAyah(String value, int max) {
    if (max < 1) return '1';
    final ayah = int.tryParse(value) ?? 1;
    if (ayah < 1) return '1';
    if (ayah > max) return max.toString();
    return ayah.toString();
  }

  VerseRef _juzStartRef(int juz) {
    const starts = <int, List<int>>{
      1: [1, 1],
      2: [2, 142],
      3: [2, 253],
      4: [3, 93],
      5: [4, 24],
      6: [4, 148],
      7: [5, 82],
      8: [6, 111],
      9: [7, 88],
      10: [8, 41],
      11: [9, 93],
      12: [11, 6],
      13: [12, 53],
      14: [15, 1],
      15: [17, 1],
      16: [18, 75],
      17: [21, 1],
      18: [23, 1],
      19: [25, 21],
      20: [27, 56],
      21: [29, 46],
      22: [33, 31],
      23: [36, 28],
      24: [39, 32],
      25: [41, 47],
      26: [46, 1],
      27: [51, 31],
      28: [58, 1],
      29: [67, 1],
      30: [78, 1],
    };
    final start = starts[juz] ?? starts[1]!;
    return toVerseRef(start[0], start[1]);
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = Provider.of<SettingsProvider>(context);

    return Material(
      color: isDark
          ? (settings.themeColor == 'sepia'
                ? const Color(0xFF261D17)
                : const Color(0xFF1E293B))
          : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? (settings.themeColor == 'sepia'
                        ? const Color(0xFF33251D)
                        : const Color(0xFF334155).withOpacity(0.2))
                  : Colors.grey.shade200,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.prompt(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? Colors.blueGrey.shade200
                      : Colors.blueGrey.shade800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
