import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../data/quran_repository.dart';
import '../data/tadabbur_repository.dart';
import '../models/tadabbur_note.dart';
import '../theme/app_theme.dart';
import 'reading_screen.dart';
import 'tadabbur_community_screen.dart';

class TadabburPrivateScreen extends StatefulWidget {
  final QuranRepository repository;

  const TadabburPrivateScreen({Key? key, required this.repository}) : super(key: key);

  @override
  State<TadabburPrivateScreen> createState() => _TadabburPrivateScreenState();
}

class _TadabburPrivateScreenState extends State<TadabburPrivateScreen> {
  final _repo = TadabburRepository();
  List<TadabburNote> _notes = [];
  bool _loading = true;
  String? _selectedSurahId;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() => _loading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() {
          _notes = [];
          _loading = false;
        });
        return;
      }
      final data = await _repo.fetchUserNotes();
      if (mounted) {
        setState(() {
          _notes = data;
          if (data.isNotEmpty && _selectedSurahId == null) {
            _selectedSurahId = data.first.surahId;
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteNote(String noteId, NotesProvider notesProv) async {
    try {
      final note = _notes.firstWhere((n) => n.id == noteId);
      await notesProv.deleteNote(note.surahId, note.verseId);

      final updated = _notes.where((n) => n.id != noteId).toList();
      setState(() {
        _notes = updated;
        if (_selectedSurahId != null &&
            !updated.any((n) => n.surahId == _selectedSurahId)) {
          _selectedSurahId = updated.isNotEmpty ? updated.first.surahId : null;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<TadabburNote> get _currentNotes {
    if (_selectedSurahId == null) return [];
    return _notes.where((n) => n.surahId == _selectedSurahId).toList();
  }

  Map<String, List<TadabburNote>> get _surahGroups {
    final acc = <String, List<TadabburNote>>{};
    for (final note in _notes) {
      acc.putIfAbsent(note.surahId, () => []).add(note);
    }
    return acc;
  }

  List<String> get _sortedSurahIds {
    return _surahGroups.keys.toList()..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final notesProv = Provider.of<NotesProvider>(context);
    final primaryColor = settings.getPrimaryColor();
    final colors = settings.getAppColors();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surfaceContainerLow,
        elevation: 0,
        shape: Border(bottom: BorderSide(color: colorScheme.outline, width: 1)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Favorites & Reflections',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: colorScheme.onSurface),
        ),
        actions: [
          IconButton(
            icon: Icon(settings.isDarkMode ? Icons.light_mode : Icons.dark_mode, color: primaryColor),
            onPressed: () => settings.toggleDarkMode(!settings.isDarkMode),
          ),
          IconButton(
            icon: Icon(Icons.public, color: primaryColor),
            tooltip: 'Community Reflections',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TadabburCommunityScreen(repository: widget.repository),
                ),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : _notes.isEmpty
              ? _buildEmptyState(colors)
              : LayoutBuilder(
                   builder: (context, constraints) {
                     final showSidebar = constraints.maxWidth > 700;
                    if (showSidebar) {
                      return Row(
                        children: [
                          _buildSidebar(colors, primaryColor, notesProv),
                          Expanded(child: _buildMainContent(colors, primaryColor, notesProv)),
                        ],
                      );
                    }
                    return _buildMobileLayout(colors, primaryColor, notesProv);
                  },
                ),
    );
  }

  Widget _buildEmptyState(AppThemeColors colors) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.edit_note_outlined, size: 64, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            'No reflections yet',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            'Add reflections while reading the Quran.',
            style: GoogleFonts.inter(fontSize: 13, color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(AppThemeColors colors, Color primaryColor, NotesProvider notesProv) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(right: BorderSide(color: colorScheme.outline, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Surahs',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: colorScheme.onSurface),
            ),
          ),
          Divider(height: 1, color: colorScheme.outline),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: _sortedSurahIds.length,
              itemBuilder: (context, index) {
                final surahId = _sortedSurahIds[index];
                final count = _surahGroups[surahId]!.length;
                final isActive = _selectedSurahId == surahId;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    onTap: () => setState(() => _selectedSurahId = surahId),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isActive ? colorScheme.primaryContainer : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: isActive ? colorScheme.primary : colorScheme.surface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                surahId,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: isActive ? colorScheme.onPrimary : colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.repository.getSurahName(surahId),
                              style: GoogleFonts.prompt(
                                fontSize: 13,
                                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                color: isActive ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isActive ? colorScheme.primary.withOpacity(0.2) : colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$count',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(AppThemeColors colors, Color primaryColor, NotesProvider notesProv) {
    final notes = _currentNotes;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: notes.isEmpty
          ? _buildEmptyState(colors)
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: notes.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final note = notes[index];
                return _NoteCard(
                  note: note,
                  repository: widget.repository,
                  colors: colors,
                  primaryColor: primaryColor,
                  onDelete: () => _deleteNote(note.id, notesProv),
                  onOpenVerse: (surahId, verseId) => _openVerse(surahId, verseId),
                  onTogglePublic: (note) async {
                    try {
                      await notesProv.saveNote(
                        surahId: note.surahId,
                        verseId: note.verseId,
                        noteText: note.noteText,
                        isPublic: !note.isPublic,
                        isAnonymous: note.isAnonymous,
                      );
                      await _loadNotes();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  onEdit: (note, newText) async {
                    try {
                      await notesProv.saveNote(
                        surahId: note.surahId,
                        verseId: note.verseId,
                        noteText: newText.trim(),
                        isPublic: note.isPublic,
                        isAnonymous: note.isAnonymous,
                      );
                      await _loadNotes();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                );
              },
            ),
    );
  }

  Widget _buildMobileLayout(AppThemeColors colors, Color primaryColor, NotesProvider notesProv) {
    return Column(
      children: [
        _buildSurahTabs(colors, primaryColor),
        Expanded(child: _buildMainContent(colors, primaryColor, notesProv)),
      ],
    );
  }

  Widget _buildSurahTabs(AppThemeColors colors, Color primaryColor) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: colorScheme.outline, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _sortedSurahIds.map((surahId) {
            final isActive = _selectedSurahId == surahId;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: isActive ? colorScheme.primaryContainer : colorScheme.surface,
                  foregroundColor: isActive ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                  side: BorderSide(color: isActive ? colorScheme.primary : colorScheme.outline, width: isActive ? 1.5 : 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => setState(() => _selectedSurahId = surahId),
                child: Text(
                  '${widget.repository.getSurahName(surahId)} ($surahId)',
                  style: GoogleFonts.prompt(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _openVerse(String surahId, String verseId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReadingScreen(
          repository: widget.repository,
          initialSurah: surahId,
          initialVerseId: verseId,
        ),
      ),
    );
  }
}

class _NoteCard extends StatefulWidget {
  final TadabburNote note;
  final QuranRepository repository;
  final AppThemeColors colors;
  final Color primaryColor;
  final VoidCallback onDelete;
  final void Function(String surahId, String verseId) onOpenVerse;
  final Future<void> Function(TadabburNote) onTogglePublic;
  final Future<void> Function(TadabburNote, String) onEdit;

  const _NoteCard({
    required this.note,
    required this.repository,
    required this.colors,
    required this.primaryColor,
    required this.onDelete,
    required this.onOpenVerse,
    required this.onTogglePublic,
    required this.onEdit,
  });

  @override
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard> {
  bool _isEditing = false;
  final _editController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _editController.text = widget.note.noteText;
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final note = widget.note;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InkWell(
                  onTap: () => widget.onOpenVerse(note.surahId, note.verseId),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${widget.repository.getSurahName(note.surahId)} ${note.surahId}:${note.verseId}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  timeago.format(note.updatedAt),
                  style: GoogleFonts.inter(fontSize: 10, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isEditing)
              Column(
                children: [
                  TextField(
                    controller: _editController,
                    maxLines: 5,
                    style: GoogleFonts.prompt(fontSize: 14),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => setState(() => _isEditing = false),
                        child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          await widget.onEdit(note, _editController.text);
                          if (mounted) setState(() => _isEditing = false);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                        ),
                        child: Text('Save', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  note.noteText.isNotEmpty
                      ? Text(
                          note.noteText,
                          style: GoogleFonts.prompt(fontSize: 14, height: 1.6),
                        )
                      : Text(
                          'Favorited this verse (no reflection text added)',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (note.noteText.isNotEmpty)
                        InkWell(
                          onTap: () => widget.onTogglePublic(note),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: note.isPublic
                                  ? Colors.green.withOpacity(0.1)
                                  : colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: note.isPublic
                                    ? Colors.green.withOpacity(0.3)
                                    : colorScheme.outlineVariant,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  note.isPublic ? Icons.public : Icons.lock_outline,
                                  size: 14,
                                  color: note.isPublic ? Colors.green : colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  note.isPublic ? 'Public' : 'Private',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: note.isPublic ? Colors.green : colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.edit_outlined, size: 18, color: colorScheme.primary),
                        tooltip: 'Edit',
                        onPressed: () => setState(() => _isEditing = true),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade400),
                        tooltip: 'Unfavorite',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text('Remove from Favorites', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                              content: Text('Are you sure you want to unfavorite this verse?', style: GoogleFonts.inter()),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.bold))),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    widget.onDelete();
                                  },
                                  child: Text('Unfavorite', style: GoogleFonts.inter(color: colorScheme.error, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
