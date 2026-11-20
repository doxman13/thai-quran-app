// lib/screens/notes_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../data/quran_repository.dart';
import '../data/offline_surah_names.dart';
import '../shared/shared.dart';
import '../theme/app_theme.dart';
import '../widgets/verse_share_sheet.dart';
import 'reading_screen.dart';

class NotesScreen extends StatelessWidget {
  final QuranRepository repository;

  const NotesScreen({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    final notesProv = Provider.of<NotesProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = settings.getPrimaryColor();

    final isThai = settings.languageCode == 'th';

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
      appBar: AppBar(
        elevation: 0,
        title: Text(
          isThai ? 'บันทึกและข้อคิดส่วนตัว' : 'Personal Notes & Thoughts',
          style: GoogleFonts.notoSansThai(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        foregroundColor: colorScheme.onSurface,
      ),
      body: noteEntries.isEmpty
          ? _buildEmptyState(colorScheme, isThai)
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
                  repository: repository,
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
                          isThai ? 'ลบบันทึก' : 'Delete Note',
                          style: GoogleFonts.notoSansThai(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        content: Text(
                          isThai
                              ? 'คุณแน่ใจหรือไม่ว่าต้องการลบบันทึกส่วนตัวนี้?'
                              : 'Are you sure you want to delete this personal note?',
                          style: GoogleFonts.notoSansThai(color: colorScheme.onSurfaceVariant),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(
                              isThai ? 'ยกเลิก' : 'Cancel',
                              style: GoogleFonts.notoSansThai(),
                            ),
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
                            child: Text(
                              isThai ? 'ลบ' : 'Delete',
                              style: GoogleFonts.notoSansThai(),
                            ),
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

  Widget _buildEmptyState(ColorScheme colorScheme, bool isThai) {
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
              isThai ? 'ยังไม่มีบันทึกส่วนตัว' : 'No personal notes yet.',
              style: GoogleFonts.notoSansThai(
                fontSize: 18,
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isThai
                  ? 'คุณสามารถเพิ่มบันทึกในอายะฮฺต่าง ๆ ได้โดยตรงขณะอ่านอัลกุรอาน'
                  : 'You can add notes to any verse while reading the Quran.',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansThai(
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

class _NoteCard extends StatefulWidget {
  final QuranRepository repository;
  final ColorScheme colorScheme;
  final Color primaryColor;
  final String surahName;
  final String surahId;
  final String verseId;
  final String noteContent;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NoteCard({
    required this.repository,
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
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard> {
  late Future<String> _arabicFuture;

  @override
  void initState() {
    super.initState();
    _arabicFuture = widget.repository.fetchArabicVerse(
      widget.surahId,
      widget.verseId,
    );
  }

  @override
  void didUpdateWidget(covariant _NoteCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.surahId != widget.surahId ||
        oldWidget.verseId != widget.verseId) {
      _arabicFuture = widget.repository.fetchArabicVerse(
        widget.surahId,
        widget.verseId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isThai = Provider.of<SettingsProvider>(context, listen: false).languageCode == 'th';
    final colors = context.appColors;
    final cleanSurahName = widget.surahName.replaceFirst(RegExp(r'^\d+\.\s*'), '');

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: colors.borderSoft),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header row: surah reference + share + delete button
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.primaryLight,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        border: Border.all(color: colors.primaryLightBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.menu_book_rounded, size: 12, color: colors.primary),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '$cleanSurahName ${widget.surahId}:${widget.verseId}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.notoSansThai(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: colors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    onTap: () {
                      final verseObj = widget.repository.getVerse(
                        widget.surahId,
                        widget.verseId,
                      );
                      final translationText = resolveVerseTranslationText(
                        context: context,
                        verseKey: '${widget.surahId}:${widget.verseId}',
                        verse: verseObj,
                        repository: widget.repository,
                      );
                      VerseShareSheet.show(
                        context,
                        surahId: widget.surahId,
                        verseId: widget.verseId,
                        surahName: surahDisplayName(
                          widget.surahId,
                          isThai: isThai,
                        ),
                        translationText: translationText,
                        reflectionText: widget.noteContent.trim().isNotEmpty
                            ? widget.noteContent
                            : null,
                        repository: widget.repository,
                        isThai: isThai,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.share_outlined,
                        size: 18,
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    onTap: widget.onDelete,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: colors.danger,
                      ),
                    ),
                  ),
                ],
              ),
              FutureBuilder<String>(
                future: _arabicFuture,
                builder: (context, snapshot) {
                  final arabic = snapshot.data;
                  if (arabic == null || arabic.trim().isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: colors.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        border: Border.all(color: colors.borderSoft),
                      ),
                      child: Text(
                        formatArabicAyahText(arabic, verseNumber: widget.verseId),
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        locale: const Locale('ar'),
                        style: TextStyle(
                          fontFamily: 'UthmanicHafs',
                          fontWeight: FontWeight.w400,
                          fontSize: 17,
                          height: 2.0,
                          color: colors.textStrong,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              // Note body with left accent bar
              Container(
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: colors.borderSoft),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(width: 3, color: widget.primaryColor),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                            child: Text(
                              widget.noteContent,
                              style: GoogleFonts.notoSansThai(
                                fontSize: 14,
                                color: colors.textStrong,
                                height: 1.6,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Footer: tap to read link
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    isThai ? 'แตะเพื่อเปิดอ่านอายะฮฺ' : 'Tap to read verse',
                    style: GoogleFonts.notoSansThai(
                      fontSize: 11,
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 12, color: colors.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
