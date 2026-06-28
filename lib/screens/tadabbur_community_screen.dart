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
  bool _showFilters = false;

  final _postController = TextEditingController();
  bool _isPosting = false;
  bool _isAnonymous = false;
  String _postSurahId = '1';
  String _postVerseId = '1';

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
        surahId: _postSurahId,
        verseId: _postVerseId,
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
            icon: Icon(
              _filterSurahId != null ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: _filterSurahId != null ? primaryColor : colors.textStrong,
            ),
            tooltip: 'Filter reflections',
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
          IconButton(
            icon: Icon(settings.isDarkMode ? Icons.light_mode : Icons.dark_mode, color: primaryColor),
            onPressed: () => settings.toggleDarkMode(!settings.isDarkMode),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showFilters) _buildFilterBar(colors, primaryColor),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: primaryColor))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildComposeSection(colors, primaryColor),
                      const SizedBox(height: 16),
                      if (_feed.isEmpty)
                        _buildEmptyState(colors)
                      else
                        ..._feed.map((note) => _CommunityNoteCard(
                              note: note,
                              repository: widget.repository,
                              colors: colors,
                              primaryColor: primaryColor,
                              onLike: () => _handleLike(note),
                              onOpenVerse: (surahId, verseId) => _openVerse(surahId, verseId),
                            )),
                    ],
                  ),
          ),
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
                dropdownColor: colors.surface,
                iconEnabledColor: colors.textStrong,
                hint: Text('All Surahs', style: GoogleFonts.prompt(fontSize: 12, color: colors.textStrong)),
                style: GoogleFonts.prompt(fontSize: 12, color: colors.textStrong),
                items: [
                  DropdownMenuItem(value: null, child: Text('All Surahs', style: GoogleFonts.prompt(color: colors.textStrong))),
                  ...surahIds.map((id) => DropdownMenuItem(
                        value: id,
                        child: Text('${widget.repository.getSurahName(id)} ($id)', style: GoogleFonts.prompt(color: colors.textStrong)),
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
                  dropdownColor: colors.surface,
                  iconEnabledColor: colors.textStrong,
                  hint: Text('Ayah', style: GoogleFonts.prompt(fontSize: 12, color: colors.textStrong)),
                  style: GoogleFonts.prompt(fontSize: 12, color: colors.textStrong),
                  items: [
                    DropdownMenuItem(value: null, child: Text('All', style: GoogleFonts.prompt(color: colors.textStrong))),
                    ...List.generate(
                      widget.repository.getSurahVerses(_filterSurahId!).length,
                      (i) => DropdownMenuItem(value: (i + 1).toString(), child: Text('${i + 1}', style: GoogleFonts.prompt(color: colors.textStrong))),
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
              icon: Icon(Icons.clear, size: 18, color: colors.textStrong),
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

  Widget _buildComposeSection(AppThemeColors colors, Color primaryColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surahIds = List.generate(114, (i) => (i + 1).toString());
    final versesCount = widget.repository.getSurahVerses(_postSurahId).length;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? colors.surface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? colors.borderSoft : Colors.grey.shade300),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SHARE A REFLECTION',
            style: GoogleFonts.prompt(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Surah', style: GoogleFonts.prompt(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: colors.borderSoft),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _postSurahId,
                          isExpanded: true,
                          style: GoogleFonts.prompt(fontSize: 12, color: colors.textStrong),
                          items: surahIds.map((id) => DropdownMenuItem(
                                value: id,
                                child: Text('${widget.repository.getSurahName(id)}'),
                              )).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() { _postSurahId = val; _postVerseId = '1'; });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ayah', style: GoogleFonts.prompt(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: colors.borderSoft),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _postVerseId,
                          isExpanded: true,
                          style: GoogleFonts.prompt(fontSize: 12, color: colors.textStrong),
                          items: List.generate(versesCount, (i) => DropdownMenuItem(
                            value: (i + 1).toString(), child: Text('${i + 1}'),
                          )),
                          onChanged: (val) {
                            if (val != null) setState(() => _postVerseId = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Translation Preview Box
          Builder(builder: (context) {
            final verse = widget.repository.getVerse(_postSurahId, _postVerseId);
            final translationText = verse?.thaiV3 ?? verse?.thaiV2 ?? '';
            if (translationText.isEmpty) return const SizedBox.shrink();
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.borderSoft),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Translation Preview ($_postSurahId:$_postVerseId)',
                    style: GoogleFonts.prompt(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    translationText,
                    style: GoogleFonts.prompt(
                      fontSize: 12,
                      color: colors.foreground,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            );
          }),
          TextField(
            controller: _postController,
            style: GoogleFonts.prompt(fontSize: 14, color: colors.textStrong),
            decoration: InputDecoration(
              hintText: 'What did you learn or reflect on from this Ayah?...',
              hintStyle: GoogleFonts.prompt(fontSize: 12, color: Colors.grey),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colors.borderSoft)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colors.borderSoft)),
              contentPadding: const EdgeInsets.all(12),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () => setState(() => _isAnonymous = !_isAnonymous),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    children: [
                      Icon(
                        _isAnonymous ? Icons.check_box : Icons.check_box_outline_blank,
                        size: 16,
                        color: _isAnonymous ? primaryColor : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text('Post anonymously', style: GoogleFonts.prompt(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: _isPosting || _postController.text.trim().isEmpty ? null : _handlePost,
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: _isPosting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Share Reflection', style: GoogleFonts.prompt(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final primaryColor = settings.getPrimaryColor();

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
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? colors.surfaceMuted.withOpacity(0.5) : Colors.amber.shade50.withOpacity(0.5),
                border: Border(
                  left: BorderSide(color: primaryColor.withOpacity(0.5), width: 3),
                ),
                borderRadius: const BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
              ),
              child: Text(
                repository.getVerse(note.surahId, note.verseId)?.thaiV3 ?? '',
                style: GoogleFonts.prompt(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.blueGrey.shade300 : Colors.blueGrey.shade700,
                  height: 1.6,
                ),
              ),
            ),
            Text(note.noteText, style: GoogleFonts.prompt(fontSize: 14, height: 1.6, color: isDark ? colors.textStrong : const Color(0xFF1E293B))),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                InkWell(
                  onTap: () => onOpenVerse(note.surahId, note.verseId),
                  child: Row(
                    children: [
                      const Text('📖 ', style: TextStyle(fontSize: 12)),
                      Text(
                        'Read in Mushaf',
                        style: GoogleFonts.prompt(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: primaryColor,
                        ),
                      ),
                    ],
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
