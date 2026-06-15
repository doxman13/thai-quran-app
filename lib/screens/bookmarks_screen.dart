// lib/screens/bookmarks_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/bookmark_provider.dart';
import '../providers/progress_provider.dart';
import '../data/quran_repository.dart';

class BookmarksScreen extends StatelessWidget {
  final QuranRepository repository;
  const BookmarksScreen({Key? key, required this.repository}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final progress = Provider.of<ProgressProvider>(context);
    final bookmarksProv = Provider.of<BookmarkProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Bookmarks', style: GoogleFonts.prompt()),
        backgroundColor: Colors.teal.shade800,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Auto-Save Section
          Text(
            'Continue Reading',
            style: GoogleFonts.prompt(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.teal.shade200 : Colors.teal.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Icon(Icons.history, color: Colors.teal),
              title: Text(
                repository.getSurahName(progress.currentSurahId),
                style: GoogleFonts.prompt(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Verse Index: ${progress.lastVerseIndex}',
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
            'Saved Verses',
            style: GoogleFonts.prompt(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.teal.shade200 : Colors.teal.shade700,
            ),
          ),
          const SizedBox(height: 8),
          
          if (bookmarksProv.bookmarks.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'No verses saved yet. Tap the bookmark icon on any verse to save it here.',
                style: GoogleFonts.prompt(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            )
          else
            ...bookmarksProv.bookmarks.map((bKey) {
              final parts = bKey.split(':');
              final surahId = parts[0];
              final verseId = parts[1];
              
              return Card(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: Icon(Icons.bookmark, color: Colors.amber.shade600),
                  title: Text(
                    '${repository.getSurahName(surahId)}, Ayat $verseId',
                    style: GoogleFonts.prompt(fontWeight: FontWeight.w500),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () {
                      bookmarksProv.toggleBookmark(surahId, verseId);
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
