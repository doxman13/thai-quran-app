import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../providers/settings_provider.dart';
import '../data/quran_repository.dart';
import '../data/tadabbur_repository.dart';
import '../models/tadabbur_note.dart';
import '../theme/app_theme.dart';
import 'reading_screen.dart';

class TadabburCommunityScreen extends StatefulWidget {
  final QuranRepository repository;

  const TadabburCommunityScreen({Key? key, required this.repository}) : super(key: key);

  @override
  State<TadabburCommunityScreen> createState() => _TadabburCommunityScreenState();
}

class _TadabburCommunityScreenState extends State<TadabburCommunityScreen> {
  final _repo = TadabburRepository();
  List<TadabburNote> _feed = [];
  bool _loading = true;
  String? _filterSurahId;
  String? _filterVerseId;

  final _postController = TextEditingController();
  bool _isPosting = false;
  bool _isAnonymous = false;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }

  Future<void> _loadFeed() async {
    setState(() => _loading = true);
    try {
      final data = await _repo.fetchCommunityNotes(
        _filterSurahId ?? '0',
        _filterVerseId ?? '0',
      );
      if (mounted) {
        setState(() {
          _feed = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleLike(TadabburNote note) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to like reflections.')),
      );
      return;
    }
    try {
      await _repo.toggleLike(note.id);
      setState(() {
        _feed = _feed.map((n) {
          if (n.id == note.id) {
            final newLiked = !n.userLiked;
            return TadabburNote(
              id: n.id,
              userId: n.userId,
              surahId: n.surahId,
              verseId: n.verseId,
              noteText: n.noteText,
              isPublic: n.isPublic,
              isAnonymous: n.isAnonymous,
              likesCount: newLiked ? n.likesCount + 1 : (n.likesCount > 0 ? n.likesCount - 1 : 0),
              language: n.language,
              createdAt: n.createdAt,
              updatedAt: n.updatedAt,
              userEmail: n.userEmail,
              userLiked: newLiked,
              synced: n.synced,
            );
          }
          return n;
        }).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to like: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handlePost() async {
    final text = _postController.text.trim();
    if (text.isEmpty) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to share reflections.')),
      );
      return;
    }

    setState(() => _isPosting = true);
    try {
      final note = await _repo.saveNote(TadabburNote(
        id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
        userId: user.id,
        surahId: _filterSurahId ?? '1',
        verseId: _filterVerseId ?? '1',
        noteText: text,
        isPublic: true,
        isAnonymous: _isAnonymous,
        likesCount: 0,
        language: 'th',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        userEmail: _isAnonymous ? 'Anonymous' : user.email ?? 'Reader',
        userLiked: false,
        synced: true,
      ));
      if (note != null) {
        setState(() {
          _feed = [note, ..._feed];
          _postController.clear();
          _isAnonymous = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final primaryColor = settings.getPrimaryColor();
    final colors = settings.getAppColors();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surfaceMuted,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.textStrong),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Community Reflections',
          style: GoogleFonts.prompt(fontWeight: FontWeight.w900, color: colors.textStrong),
        ),
        actions: [
          IconButton(
            icon: Icon(settings.isDarkMode ? Icons.light_mode : Icons.dark_mode, color: primaryColor),
            onPressed: () => settings.toggleDarkMode(!settings.isDarkMode),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(colors, primaryColor),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: primaryColor))
                : _feed.isEmpty
                    ? _buildEmptyState(colors)
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _feed.length,
                        itemBuilder: (context, index) {
                          final note = _feed[index];
                          return _CommunityNoteCard(
                            note: note,
                            repository: widget.repository,
                            colors: colors,
                            primaryColor: primaryColor,
                            onLike: () => _handleLike(note),
                            onOpenVerse: (surahId, verseId) => _openVerse(surahId, verseId),
                          );
                        },
                      ),
          ),
          _buildComposeBar(colors, primaryColor),
        ],
      ),
    );
  }

  Widget _buildFilterBar(AppThemeColors colors, Color primaryColor) {
    final surahIds = List.generate(114, (i) => (i + 1).toString());
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.borderSoft)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _filterSurahId,
                isExpanded: true,
                hint: Text('All Surahs', style: GoogleFonts.prompt(fontSize: 12)),
                style: GoogleFonts.prompt(fontSize: 12),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Surahs')),
                  ...surahIds.map((id) => DropdownMenuItem(
                        value: id,
                        child: Text('${widget.repository.getSurahName(id)} ($id)'),
                      )),
                ],
                onChanged: (val) {
                  setState(() {
                    _filterSurahId = val;
                    _filterVerseId = null;
                  });
                  _loadFeed();
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (_filterSurahId != null)
            SizedBox(
              width: 72,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _filterVerseId,
                  isExpanded: true,
                  hint: Text('Ayah', style: GoogleFonts.prompt(fontSize: 12)),
                  style: GoogleFonts.prompt(fontSize: 12),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All')),
                    ...List.generate(
                      widget.repository.getSurahVerses(_filterSurahId!).length,
                      (i) => DropdownMenuItem(value: (i + 1).toString(), child: Text('${i + 1}')),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() => _filterVerseId = val);
                    _loadFeed();
                }),
              ),
            ),
          if (_filterSurahId != null) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.clear, size: 18),
              tooltip: 'Clear filter',
              onPressed: () {
                setState(() {
                  _filterSurahId = null;
                  _filterVerseId = null;
                });
                _loadFeed();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildComposeBar(AppThemeColors colors, Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.borderSoft)),
      ),
      padding: EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 12 + MediaQuery.of(context).viewInsets.bottom),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _postController,
              style: GoogleFonts.prompt(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Share a reflection...',
                hintStyle: GoogleFonts.prompt(fontSize: 12, color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              maxLines: 2,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              _isAnonymous ? Icons.person_off : Icons.person_outline,
              color: _isAnonymous ? primaryColor : Colors.grey,
            ),
            tooltip: 'Anonymous',
            onPressed: () => setState(() => _isAnonymous = !_isAnonymous),
          ),
          ElevatedButton(
            onPressed: _isPosting || _postController.text.trim().isEmpty ? null : _handlePost,
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            child: _isPosting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('Post', style: GoogleFonts.prompt(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppThemeColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forum_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No reflections yet',
            style: GoogleFonts.prompt(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to share your reflection!',
            style: GoogleFonts.prompt(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
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

class _CommunityNoteCard extends StatelessWidget {
  final TadabburNote note;
  final QuranRepository repository;
  final AppThemeColors colors;
  final Color primaryColor;
  final VoidCallback onLike;
  final void Function(String surahId, String verseId) onOpenVerse;

  const _CommunityNoteCard({
    required this.note,
    required this.repository,
    required this.colors,
    required this.primaryColor,
    required this.onLike,
    required this.onOpenVerse,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? colors.surface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? colors.borderSoft : Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: primaryColor.withOpacity(0.15),
                  child: Text(
                    (note.isAnonymous ? 'A' : (note.userEmail?.split('@').first ?? 'R')).substring(0, 1).toUpperCase(),
                    style: GoogleFonts.prompt(fontSize: 10, fontWeight: FontWeight.w800, color: primaryColor),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    note.isAnonymous ? 'Anonymous' : (note.userEmail ?? 'Reader'),
                    style: GoogleFonts.prompt(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? colors.textStrong : const Color(0xFF1E293B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: () => onOpenVerse(note.surahId, note.verseId),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isDark ? colors.borderSoft : Colors.grey.shade400),
                    ),
                    child: Text(
                      '${repository.getSurahName(note.surahId)} ${note.surahId}:${note.verseId}',
                      style: GoogleFonts.prompt(fontSize: 10, fontWeight: FontWeight.w700, color: primaryColor),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              timeago.format(note.updatedAt),
              style: GoogleFonts.prompt(fontSize: 10, color: isDark ? Colors.blueGrey.shade400 : Colors.blueGrey.shade600),
            ),
            const SizedBox(height: 10),
            Text(note.noteText, style: GoogleFonts.prompt(fontSize: 14, height: 1.6, color: isDark ? colors.textStrong : const Color(0xFF1E293B))),
            const SizedBox(height: 12),
            Row(
              children: [
                InkWell(
                  onTap: onLike,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: note.userLiked ? Colors.red.withOpacity(0.1) : colors.surfaceMuted,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: note.userLiked ? Colors.red.withOpacity(0.3) : colors.borderSoft,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(note.userLiked ? '❤️' : '🤍', style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text(
                          '${note.likesCount}',
                          style: GoogleFonts.prompt(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
