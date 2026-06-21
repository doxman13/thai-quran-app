// lib/screens/notes_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../data/quran_repository.dart';
import 'reading_screen.dart';

class NotesScreen extends StatelessWidget {
  final QuranRepository repository;

  const NotesScreen({Key? key, required this.repository}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final notesProv = Provider.of<NotesProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = settings.getPrimaryColor();

    // Convert notes map into a sorted list of entries
    final noteEntries = notesProv.notes.entries.toList()
      ..sort((a, b) {
        final aParts = a.key.split(':');
        final bParts = b.key.split(':');
        final aSurah = int.tryParse(aParts[0]) ?? 0;
        final bSurah = int.tryParse(bParts[0]) ?? 0;
        if (aSurah != bSurah) return aSurah.compareTo(bSurah);
        final aVerse = int.tryParse(aParts[1]) ?? 0;
        final bVerse = int.tryParse(bParts[1]) ?? 0;
        return aVerse.compareTo(bVerse);
      });

    return Scaffold(
      appBar: AppBar(
        title: Text('Personal Notes & Thoughts', style: GoogleFonts.prompt()),
        backgroundColor: primaryColor,
      ),
      body: noteEntries.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.edit_note,
                    size: 80,
                    color: isDark
                        ? Colors.blueGrey.shade700
                        : Colors.blueGrey.shade200,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No personal notes yet.',
                    style: GoogleFonts.prompt(
                      fontSize: 18,
                      color: isDark
                          ? Colors.blueGrey.shade400
                          : Colors.blueGrey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: Text(
                      'You can add notes to any verse while reading the Quran.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.prompt(
                        fontSize: 14,
                        color: isDark
                            ? Colors.blueGrey.shade500
                            : Colors.blueGrey.shade400,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: noteEntries.length,
              itemBuilder: (context, index) {
                final entry = noteEntries[index];
                final keyParts = entry.key.split(':');
                final surahId = keyParts[0];
                final verseId = keyParts[1];
                final noteContent = entry.value;

                final surahName = repository.getSurahName(surahId);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  color: isDark
                      ? (settings.themeColor == 'sepia'
                            ? const Color(0xFF261D17)
                            : const Color(0xFF1E293B))
                      : Colors.white,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      // Navigate to reading screen for this verse
                      // Make sure to set the progress profile first if needed
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReadingScreen(
                            repository: repository,
                            initialSurah: surahId,
                            initialVerseId: verseId,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    surahName,
                                    style: GoogleFonts.prompt(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: primaryColor,
                                    ),
                                  ),
                                  Text(
                                    'Verse $verseId',
                                    style: GoogleFonts.prompt(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.blueGrey.shade400
                                          : Colors.blueGrey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () {
                                  // Confirm delete
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: Text(
                                        'Delete Note',
                                        style: GoogleFonts.prompt(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      content: Text(
                                        'Are you sure you want to delete this personal note?',
                                        style: GoogleFonts.prompt(),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: Text(
                                            'Cancel',
                                            style: GoogleFonts.prompt(),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            notesProv.deleteNote(
                                              surahId,
                                              verseId,
                                            );
                                            Navigator.pop(ctx);
                                          },
                                          child: Text(
                                            'Delete',
                                            style: GoogleFonts.prompt(
                                              color: Colors.redAccent,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.edit_note,
                                color: Colors.amber.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  noteContent,
                                  style: GoogleFonts.prompt(
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.blueGrey.shade200
                                        : const Color(0xFF334155),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Tap to read verse',
                                  style: GoogleFonts.prompt(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.teal.shade300
                                        : Colors.teal.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 12,
                                  color: isDark
                                      ? Colors.teal.shade300
                                      : Colors.teal.shade700,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
