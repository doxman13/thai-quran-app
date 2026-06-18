// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/progress_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/stats_provider.dart';
import '../data/quran_repository.dart';
import 'reading_screen.dart';
import 'bookmarks_screen.dart';
import 'notes_screen.dart';

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

  void _navigateToReading(BuildContext context, String surahId, int jumpToIndex) {
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
      MaterialPageRoute(builder: (_) => BookmarksScreen(repository: widget.repository)),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = Provider.of<ProgressProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final stats = Provider.of<StatsProvider>(context);
    
    final themeColor = settings.getPrimaryColor();
    final highlightColor = settings.getHighlightColor();

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
                          color: isDark ? Colors.blueGrey.shade400 : Colors.blueGrey.shade600,
                        ),
                      ),
                    ],
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
              const SizedBox(height: 24),

              // Streak & Stats Dashboard Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [themeColor.withOpacity(0.15), themeColor.withOpacity(0.35)]
                        : [themeColor.withOpacity(0.05), themeColor.withOpacity(0.12)],
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
                            Icon(Icons.local_fire_department, color: Colors.orange.shade700, size: 28),
                            const SizedBox(width: 8),
                            Text(
                              '${stats.streakCount} Day Streak',
                              style: GoogleFonts.prompt(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          stats.streakCount > 0 ? 'Keep it up!' : 'Start reading!',
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
                        _buildStatItem('Today', stats.todayReadCount.toString(), isDark),
                        _buildStatItem('This Week', stats.weekReadCount.toString(), isDark),
                        _buildStatItem('This Month', stats.monthReadCount.toString(), isDark),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('Read Completed', progress.completedReadCount.toString(), isDark),
                        _buildStatItem('Check Completed', progress.completedCheckCount.toString(), isDark),
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
                        color: isDark ? Colors.blueGrey.shade200 : Colors.blueGrey.shade800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownButton<String>(
                    value: progress.currentProfile,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: GoogleFonts.prompt(
                      color: themeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    underline: Container(
                      height: 1.5,
                      color: themeColor,
                    ),
                    items: ProgressProvider.profiles.map((profile) {
                      return DropdownMenuItem<String>(
                        value: profile,
                        child: Text(profile),
                      );
                    }).toList(),
                    onChanged: (newProfile) {
                      if (newProfile != null) {
                        progress.switchProfile(newProfile);
                      }
                    },
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
                    colors: [themeColor, themeColor.withRed((themeColor.red - 20).clamp(0, 255))],
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
                        const Icon(Icons.bookmark_added, color: Colors.white70, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '${progress.currentProfile} Progress',
                          style: GoogleFonts.prompt(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.repository.getSurahName(progress.currentSurahId),
                      style: GoogleFonts.prompt(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Last Read Verse: ${progress.lastVerseIndex + 1}',
                      style: GoogleFonts.prompt(color: Colors.white.withOpacity(0.85), fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => _navigateToReading(context, progress.currentSurahId, progress.lastVerseIndex),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: themeColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        elevation: 0,
                      ),
                      child: Text('Continue Reading', style: GoogleFonts.prompt(fontWeight: FontWeight.bold)),
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
                  color: isDark ? Colors.blueGrey.shade200 : Colors.blueGrey.shade800,
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
                      final localAudits = prefs.getStringList('local_audits') ?? [];
                      final completedCheck = Provider.of<ProgressProvider>(context, listen: false).completedCheckCount;
                      
                      if (context.mounted) {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text('Audit Sync Status', style: GoogleFonts.prompt(fontWeight: FontWeight.bold, color: themeColor)),
                            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('• Completely Audited: ~$completedCheck Surahs', style: GoogleFonts.prompt(color: isDark ? Colors.white : Colors.black87)),
                                const SizedBox(height: 12),
                                Text('• Unsynced Local Audits: ${localAudits.length}', style: GoogleFonts.prompt(color: isDark ? Colors.white : Colors.black87)),
                                const SizedBox(height: 16),
                                Text('(Note: The app automatically syncs audits to the web when submitting. This card shows your local progress.)', style: GoogleFonts.prompt(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: Text('Close', style: GoogleFonts.prompt(color: themeColor)),
                              ),
                            ],
                          )
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

  Widget _buildActionCard(BuildContext context, {required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = Provider.of<SettingsProvider>(context);
    
    return Material(
      color: isDark
          ? (settings.themeColor == 'sepia' ? const Color(0xFF261D17) : const Color(0xFF1E293B))
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
                  ? (settings.themeColor == 'sepia' ? const Color(0xFF33251D) : const Color(0xFF334155).withOpacity(0.2))
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
                  color: isDark ? Colors.blueGrey.shade200 : Colors.blueGrey.shade800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
