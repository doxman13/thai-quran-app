// lib/screens/bookmarks_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/settings_provider.dart';
import '../providers/local_reading_provider.dart';
import '../providers/progress_provider.dart';
import '../data/quran_repository.dart';

class BookmarksScreen extends StatelessWidget {
  final QuranRepository repository;
  const BookmarksScreen({Key? key, required this.repository}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final progress = Provider.of<ProgressProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final localReading = Provider.of<LocalReadingProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = settings.getPrimaryColor();

    return Scaffold(
      appBar: AppBar(
        title: Text('บุ๊กมาร์ก (Bookmarks)', style: GoogleFonts.prompt()),
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Auto-Save Section
          Text(
            'อ่านล่าสุด (Continue Reading)',
            style: GoogleFonts.prompt(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? settings.getHighlightColor() : primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Icon(Icons.history, color: primaryColor),
              title: Text(
                repository.getSurahName(progress.currentSurahId),
                style: GoogleFonts.prompt(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'อายะฮฺที่ (Verse Index): ${progress.lastVerseIndex}',
                style: GoogleFonts.prompt(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // Return to main screen, it already uses progress.currentSurahId
                Navigator.pop(context, {
                  'surahId': progress.currentSurahId,
                  'verseIndex': progress.lastVerseIndex,
                });
              },
            ),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Manual Bookmarks Section
          Text(
            'อายะฮฺที่บันทึกไว้ (Saved Verses)',
            style: GoogleFonts.prompt(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? settings.getHighlightColor() : primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          
          if (localReading.bookmarks.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'ยังไม่มีอายะฮฺที่บันทึกไว้ กดปุ่มบุ๊กมาร์กที่อายะฮฺเพื่อบันทึกที่นี่',
                style: GoogleFonts.prompt(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            )
          else
            ...localReading.bookmarks.map((bookmark) {
              final surahId = bookmark.verse.surahId;
              final verseId = bookmark.verse.verseId;
              
              return Card(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: Icon(Icons.bookmark, color: Colors.amber.shade600),
                  title: Text(
                    '${repository.getSurahName(surahId)}, อายะฮฺที่ $verseId',
                    style: GoogleFonts.prompt(fontWeight: FontWeight.w500),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () {
                      localReading.removeBookmark(bookmark.id);
                    },
                  ),
                  onTap: () {
                    // Navigate back with data
                    Navigator.pop(context, {
                      'surahId': surahId,
                      'verseId': verseId,
                    });
                  },
                ),
              );
            }).toList(),
        ],
      ),
    );
  }
}
