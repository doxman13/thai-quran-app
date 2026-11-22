import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/tadabbur_note.dart';
import '../providers/notes_provider.dart';
import '../data/tadabbur_repository.dart';
import '../theme/app_theme.dart';

class TadabburAccordion extends StatefulWidget {
  final String surahId;
  final String verseId;
  final VoidCallback onCancel;

  const TadabburAccordion({
    super.key,
    required this.surahId,
    required this.verseId,
    required this.onCancel,
  });

  @override
  State<TadabburAccordion> createState() => _TadabburAccordionState();
}

class _TadabburAccordionState extends State<TadabburAccordion> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _notesController = TextEditingController();
  
  bool _isPublic = false;
  bool _isSaving = false;
  bool _saveSuccess = false;

  List<TadabburNote> _communityNotes = [];
  bool _isLoadingCommunity = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Load existing personal note state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notesProv = Provider.of<NotesProvider>(context, listen: false);
      final existingNote = notesProv.getNoteObjectForVerse(widget.surahId, widget.verseId);
      if (existingNote != null) {
        setState(() {
          _notesController.text = existingNote.noteText;
          _isPublic = existingNote.isPublic;
        });
      }
    });

    _fetchCommunityNotes();
  }

  Future<void> _fetchCommunityNotes() async {
    setState(() => _isLoadingCommunity = true);
    final repo = TadabburRepository();
    final results = await Future.wait([
      repo.fetchCommunityNotes(widget.surahId, widget.verseId),
      repo.fetchQuranReflectNotes(
        surahId: widget.surahId,
        verseId: widget.verseId,
        limit: 10,
      ),
    ]);
    final notes = [...results[0], ...results[1]];
    if (mounted) {
      setState(() {
        _communityNotes = notes;
        _isLoadingCommunity = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _saveNote(NotesProvider notesProv) async {
    setState(() => _isSaving = true);

    final existing = notesProv.getNoteObjectForVerse(widget.surahId, widget.verseId);
    final text = _notesController.text.trim();
    final isAlreadyPublic = existing?.isPublic ?? false;
    final textChanged = existing != null && existing.noteText.trim() != text;
    final shouldSubmitReview =
        _isPublic && text.isNotEmpty && (!isAlreadyPublic || textChanged);
    final isPublicToSave = (isAlreadyPublic && !textChanged) ? _isPublic : false;

    try {
      await notesProv.saveNote(
        surahId: widget.surahId,
        verseId: widget.verseId,
        noteText: text,
        isPublic: isPublicToSave,
        isAnonymous: true,
      );

      if (shouldSubmitReview) {
        final savedObj = notesProv.getNoteObjectForVerse(widget.surahId, widget.verseId);
        if (savedObj != null) {
          await TadabburRepository().submitForPublicReview(savedObj);
        }
      }
    } catch (e) {
      debugPrint('TadabburAccordion: Error saving note: $e');
    }

    if (mounted) {
      setState(() => _isSaving = false);
      if (text.isNotEmpty) {
        setState(() => _saveSuccess = true);
        Future.delayed(const Duration(milliseconds: 1600), () {
          if (mounted) {
            setState(() => _saveSuccess = false);
            widget.onCancel();
          }
        });
      } else {
        widget.onCancel();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notesProv = Provider.of<NotesProvider>(context);
    final colors = context.appColors;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: colors.borderSoft,
        ),
      ),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelStyle: GoogleFonts.notoSansThai(fontWeight: FontWeight.w600, fontSize: 13),
            unselectedLabelStyle: GoogleFonts.notoSansThai(fontSize: 13),
            indicatorColor: colors.primary,
            labelColor: colors.textStrong,
            unselectedLabelColor: colors.textMuted,
            tabs: const [
              Tab(text: 'My Note'),
              Tab(text: 'Community'),
            ],
          ),
          SizedBox(
            height: 320, // fixed height for content area
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMyNoteTab(isDark, notesProv, colors),
                _buildCommunityTab(isDark, notesProv, colors),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyNoteTab(bool isDark, NotesProvider notesProv, AppThemeColors colors) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: TextField(
              controller: _notesController,
              style: GoogleFonts.notoSansThai(fontSize: 14, color: colors.textStrong),
              decoration: InputDecoration(
                hintText: 'Write your reflection (Tadabbur)...',
                hintStyle: GoogleFonts.notoSansThai(fontSize: 13, color: colors.textMuted),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.all(10),
              ),
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: Text('Public Note', style: GoogleFonts.notoSansThai(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textStrong)),
            subtitle: Text('Share with community', style: GoogleFonts.notoSansThai(fontSize: 10, color: colors.textMuted)),
            value: _isPublic,
            onChanged: (val) => setState(() => _isPublic = val),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: widget.onCancel,
                child: Text('Cancel', style: GoogleFonts.notoSansThai(fontSize: 12, color: colors.textMuted)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isSaving || _saveSuccess ? null : () => _saveNote(notesProv),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.textInverse,
                ),
                child: _isSaving
                    ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: colors.textInverse))
                    : Text(
                        _saveSuccess ? 'Saved ✓' : 'Save Note',
                        style: GoogleFonts.notoSansThai(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityTab(bool isDark, NotesProvider notesProv, AppThemeColors colors) {
    if (_isLoadingCommunity) {
      return Center(child: CircularProgressIndicator(color: colors.primary));
    }

    if (_communityNotes.isEmpty) {
      return Center(
        child: Text(
          'No public notes yet. Be the first to share your reflection!',
          style: GoogleFonts.notoSansThai(color: colors.textMuted, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _communityNotes.length,
      separatorBuilder: (_, _) => Divider(color: colors.borderSoft),
      itemBuilder: (context, index) {
        final note = _communityNotes[index];
        final authorName = note.isQuranReflect
            ? ((note.userEmail ?? '').trim().isNotEmpty
                ? note.userEmail!.trim()
                : 'QuranReflect')
            : (note.isAnonymous
                ? 'Anonymous'
                : (note.userEmail?.split('@').first ?? 'Someone'));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: colors.primaryLight,
                  child: Text(
                    authorName.substring(0, 1).toUpperCase(),
                    style: GoogleFonts.notoSansThai(fontSize: 10, fontWeight: FontWeight.w600, color: colors.primary),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.notoSansThai(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textStrong),
                        ),
                      ),
                      if (note.isQuranReflect) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.primaryLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'QuranReflect',
                            style: GoogleFonts.notoSansThai(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: colors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  timeago.format(note.createdAt),
                  style: GoogleFonts.notoSansThai(fontSize: 10, color: colors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              note.noteText,
              style: GoogleFonts.notoSansThai(fontSize: 13, height: 1.5, color: colors.foreground),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                InkWell(
                  onTap: note.isQuranReflect
                      ? null
                      : () {
                          setState(() {});
                          notesProv.toggleLikeLocally(note, () {
                            _fetchCommunityNotes();
                          });
                        },
                  child: Row(
                    children: [
                      Icon(
                        note.userLiked ? Icons.favorite : Icons.favorite_border,
                        size: 16,
                        color: note.userLiked ? colors.danger : colors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${note.likesCount}',
                        style: GoogleFonts.notoSansThai(fontSize: 11, color: colors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
