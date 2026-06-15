// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/progress_provider.dart';
import '../data/quran_repository.dart';
import 'reading_screen.dart';
import 'bookmarks_screen.dart';

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

    if (result != null) {
      final targetSurah = result['surahId'];
      if (result.containsKey('verseIndex')) {
        _navigateToReading(context, targetSurah, result['verseIndex']);
      } else if (result.containsKey('verseId')) {
        // We navigate to the surah, and pass the verseId so the ReadingScreen can resolve it.
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = Provider.of<ProgressProvider>(context);

    if (!_isInit) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.teal)),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              // Header
              Text(
                'Thai Quran',
                style: GoogleFonts.prompt(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Read the Quran with meaning and clarity.',
                style: GoogleFonts.prompt(
                  fontSize: 16,
                  color: isDark ? Colors.blueGrey.shade300 : Colors.blueGrey.shade600,
                ),
              ),
              const SizedBox(height: 40),
              
              // Continue Reading Card
              if (progress.isInitialized)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.teal.shade700, Colors.teal.shade900],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.teal.withOpacity(0.3),
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
                          const Icon(Icons.menu_book, color: Colors.white70, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Last Read',
                            style: GoogleFonts.prompt(color: Colors.white70, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.repository.getSurahName(progress.currentSurahId),
                        style: GoogleFonts.prompt(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Scroll Index: ${progress.lastVerseIndex}',
                        style: GoogleFonts.prompt(color: Colors.teal.shade100, fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => _navigateToReading(context, progress.currentSurahId, progress.lastVerseIndex),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.teal.shade900,
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
              
              // Quick Actions
              Text(
                'Quick Actions',
                style: GoogleFonts.prompt(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.blueGrey.shade100 : Colors.blueGrey.shade800,
                ),
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      context,
                      title: 'Read from Start',
                      icon: Icons.play_arrow_rounded,
                      color: Colors.indigo.shade400,
                      onTap: () => _navigateToReading(context, '1', 0),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionCard(
                      context,
                      title: 'My Bookmarks',
                      icon: Icons.bookmarks_rounded,
                      color: Colors.amber.shade600,
                      onTap: () => _navigateToBookmarks(context),
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

  Widget _buildActionCard(BuildContext context, {required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.blueGrey.shade800 : Colors.blueGrey.shade100),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.prompt(
                  fontWeight: FontWeight.w500,
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
