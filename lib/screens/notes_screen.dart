// lib/screens/notes_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../data/quran_repository.dart';
import '../theme/app_theme.dart';
import 'reading_screen.dart';

class NotesScreen extends StatelessWidget {
  final QuranRepository repository;

  const NotesScreen({Key? key, required this.repository}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final notesProv = Provider.of<NotesProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = settings.getPrimaryColor();

    // Convert notes map into a sorted list of entries
    final noteEntries = notesProv.personalNotes.entries.toList()
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
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surfaceContainerLow,
        elevation: 0,
        title: Text(
          'Personal Notes & Thoughts',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurface,
          ),
        ),
        foregroundColor: colorScheme.onSurface,
      ),
      body: noteEntries.isEmpty
          ? _buildEmptyState(colorScheme)
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: noteEntries.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final entry = noteEntries[index];
                final keyParts = entry.key.split(':');
                final surahId = keyParts[0];
                final verseId = keyParts[1];
                final noteContent = entry.value.noteText;
                final surahName = repository.getSurahName(surahId);

                return _NoteCard(
                  colorScheme: colorScheme,
                  primaryColor: primaryColor,
                  surahName: surahName,
                  surahId: surahId,
                  verseId: verseId,
                  noteContent: noteContent,
                  onTap: () {
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
                  onDelete: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: colorScheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                          side: BorderSide(color: colorScheme.outlineVariant),
                        ),
                        title: Text(
                          'Delete Note',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        content: Text(
                          'Are you sure you want to delete this personal note?',
                          style: GoogleFonts.inter(color: colorScheme.onSurfaceVariant),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text('Cancel', style: GoogleFonts.inter()),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: colorScheme.error,
                              foregroundColor: colorScheme.onError,
                            ),
                            onPressed: () {
                              notesProv.deleteNote(surahId, verseId);
                              Navigator.pop(ctx);
                            },
                            child: Text('Delete', style: GoogleFonts.inter()),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.edit_note_rounded,
                size: 56,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No personal notes yet.',
              style: GoogleFonts.inter(
                fontSize: 18,
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You can add notes to any verse while reading the Quran.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final ColorScheme colorScheme;
  final Color primaryColor;
  final String surahName;
  final String surahId;
  final String verseId;
  final String noteContent;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NoteCard({
    required this.colorScheme,
    required this.primaryColor,
    required this.surahName,
    required this.surahId,
    required this.verseId,
    required this.noteContent,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: surah reference + delete button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.menu_book_rounded, size: 12, color: colorScheme.onPrimaryContainer),
                        const SizedBox(width: 6),
                        Text(
                          '$surahName $surahId:$verseId',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onDelete,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Note body with left accent bar
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                  border: Border(
                    left: BorderSide(color: primaryColor, width: 3),
                  ),
                ),
                child: Text(
                  noteContent,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: colorScheme.onSurface,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Footer: tap to read link
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Tap to read verse',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 12, color: colorScheme.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
