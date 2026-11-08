import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../providers/settings_provider.dart';
import '../data/quran_repository.dart';
import '../data/quran_foundation_repository.dart';
import '../data/offline_surah_names.dart';
import '../data/medina_mushaf_pages.dart';
import '../data/tadabbur_repository.dart';
import '../models/tadabbur_note.dart';
import '../theme/app_theme.dart';
import '../shared/shared.dart';
import 'reading_screen.dart';
import 'mushaf_reader_screen.dart';
import 'tadabbur_private_screen.dart';
import 'profile_screen.dart';

class TadabburCommunityScreen extends StatefulWidget {
  final QuranRepository repository;

  const TadabburCommunityScreen({super.key, required this.repository});

  @override
  State<TadabburCommunityScreen> createState() =>
      _TadabburCommunityScreenState();
}

class _TadabburCommunityScreenState extends State<TadabburCommunityScreen> {
  final _repo = TadabburRepository();
  final _foundationRepository = QuranFoundationRepository();
  List<TadabburNote> _feed = [];
  bool _loading = true;
  String? _filterSurahId;
  String? _filterVerseId;
  bool _showCompose = false;

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
        SnackBar(
          content: Text(
            'กรุณาเข้าสู่ระบบเพื่อกดถูกใจ',
            style: GoogleFonts.notoSansThai(),
          ),
          action: SnackBarAction(
            label: 'เข้าสู่ระบบ',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(
                    repository: widget.repository,
                  ),
                ),
              );
            },
          ),
        ),
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
              likesCount: newLiked
                  ? n.likesCount + 1
                  : (n.likesCount > 0 ? n.likesCount - 1 : 0),
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
          SnackBar(
            content: Text(
              context.tr('failed_to_like', args: {'error': '$e'}),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handlePost() async {
    final text = _postController.text.trim();
    if (text.isEmpty) return;

    final user = Supabase.instance.client.auth.currentUser;
    setState(() => _isPosting = true);
    try {
      final note = await _repo.saveNote(
        TadabburNote(
          id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
          userId: user?.id ?? 'guest-${DateTime.now().millisecondsSinceEpoch}',
          surahId: _postSurahId,
          verseId: _postVerseId,
          noteText: text,
          isPublic: true,
          isAnonymous: _isAnonymous,
          likesCount: 0,
          language: 'th',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          userEmail: _isAnonymous
              ? 'ผู้ไม่ประสงค์ออกนาม'
              : (user?.email ?? 'ผู้ใคร่ครวญอัลกุรอาน'),
          userLiked: false,
          synced: user != null,
        ),
      );
      if (note != null) {
        setState(() {
          _feed = [note, ..._feed];
          _postController.clear();
          _isAnonymous = false;
          _showCompose = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('แบ่งปันข้อคิดเรียบร้อยแล้ว')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('failed_to_post', args: {'error': '$e'}),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  Future<void> _handleDeleteNote(String noteId) async {
    try {
      await _repo.deleteNote(noteId);
      setState(() {
        _feed = _feed.where((n) => n.id != noteId).toList();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ลบข้อคิดเรียบร้อยแล้ว')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการลบ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  void _openMushaf(String surahId, String verseId) {
    final sId = int.tryParse(surahId) ?? 1;
    final vId = int.tryParse(verseId) ?? 1;
    final pageNumber = getMedinaMushafPageNumber(sId, vId);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MushafReaderScreen(
          quranRepository: widget.repository,
          foundationRepository: _foundationRepository,
          initialPage: pageNumber,
          initialHighlightVerseKey: '$sId:$vId',
        ),
      ),
    );
  }

  Map<String, int> get _surahCounts {
    final counts = <String, int>{};
    for (final note in _feed) {
      counts[note.surahId] = (counts[note.surahId] ?? 0) + 1;
    }
    return counts;
  }

  List<String> get _activeSurahIds {
    return _surahCounts.keys.toList()
      ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
  }

  List<TadabburNote> get _filteredFeed {
    if (_filterSurahId == null) return _feed;
    return _feed.where((n) {
      if (n.surahId != _filterSurahId) return false;
      if (_filterVerseId != null && n.verseId != _filterVerseId) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final primaryColor = settings.getPrimaryColor();
    final colors = settings.getAppColors();
    final user = Supabase.instance.client.auth.currentUser;
    final displayedFeed = _filteredFeed;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Editorial Header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'การใคร่ครวญอัลกุรอาน',
                          style: GoogleFonts.notoSansThai(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ชุมชนตดับบุร',
                          style: GoogleFonts.notoSansThai(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: colors.foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      // Toggle compose button
                      InkWell(
                        onTap: () =>
                            setState(() => _showCompose = !_showCompose),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: _showCompose
                                ? colors.primary
                                : colors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _showCompose
                                  ? colors.primary
                                  : colors.borderSoft,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _showCompose ? Icons.close : Icons.edit_note,
                                size: 16,
                                color: _showCompose
                                    ? Colors.white
                                    : colors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _showCompose ? 'ปิด' : 'เขียนข้อคิด',
                                style: GoogleFonts.notoSansThai(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _showCompose
                                      ? Colors.white
                                      : colors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Dark mode toggle
                      InkWell(
                        onTap: () {
                          settings.toggleDarkMode(!settings.isDarkMode);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: colors.borderSoft),
                          ),
                          child: Icon(
                            settings.isDarkMode
                                ? Icons.light_mode
                                : Icons.dark_mode,
                            color: colors.foreground,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Unified Sub-Module Switcher ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: _buildSubModuleSwitcher(colors),
            ),

            // ── Surah Filter Chips Strip ────────────────────────────────────
            if (!_loading && _feed.isNotEmpty)
              _buildHorizontalSurahStrip(colors),

            // ── Feed / Compose Area ──────────────────────────────────────────
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: primaryColor,
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      children: [
                        if (_showCompose) ...[
                          _buildComposeSection(colors, primaryColor, user),
                          const SizedBox(height: 16),
                        ],
                        if (displayedFeed.isEmpty)
                          _buildEmptyState(colors)
                        else
                          ...displayedFeed.map((note) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _CommunityNoteCard(
                                note: note,
                                repository: widget.repository,
                                colors: colors,
                                primaryColor: primaryColor,
                                currentUserId: user?.id,
                                onLike: () => _handleLike(note),
                                onDelete: () => _handleDeleteNote(note.id),
                                onOpenVerse: (surahId, verseId) =>
                                    _openVerse(surahId, verseId),
                                onOpenMushaf: (surahId, verseId) =>
                                    _openMushaf(surahId, verseId),
                              ),
                            );
                          }),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubModuleSwitcher(AppThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tab 1: บันทึกส่วนตัว (Inactive)
          InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radius - 4),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => TadabburPrivateScreen(
                    repository: widget.repository,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 14, color: colors.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    'บันทึกส่วนตัว',
                    style: GoogleFonts.notoSansThai(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Tab 2: ชุมชนตดับบุร (Active)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppTheme.radius - 4),
              border: Border.all(color: colors.borderSoft),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.public, size: 14, color: colors.primary),
                const SizedBox(width: 6),
                Text(
                  'ชุมชนตดับบุร (${_feed.length})',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalSurahStrip(AppThemeColors colors) {
    return Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _buildSurahChip(
            label: 'ทุกซูเราะฮฺ (${_feed.length})',
            isSelected: _filterSurahId == null,
            colors: colors,
            onTap: () => setState(() {
              _filterSurahId = null;
              _filterVerseId = null;
            }),
          ),
          ..._activeSurahIds.map((surahId) {
            final count = _surahCounts[surahId] ?? 0;
            final surahName = widget.repository
                .getSurahName(surahId)
                .replaceAll(RegExp(r'^\d+\.\s*'), '');
            return _buildSurahChip(
              label: '$surahName ($count)',
              isSelected: _filterSurahId == surahId,
              colors: colors,
              onTap: () => setState(() {
                _filterSurahId = surahId;
                _filterVerseId = null;
              }),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSurahChip({
    required String label,
    required bool isSelected,
    required AppThemeColors colors,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? colors.primary : colors.surface,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(
              color: isSelected ? colors.primary : colors.borderSoft,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.notoSansThai(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : colors.foreground,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComposeSection(
    AppThemeColors colors,
    Color primaryColor,
    User? user,
  ) {
    final surahIds = List.generate(114, (i) => (i + 1).toString());
    final versesCount =
        widget.repository.getSurahVerses(_postSurahId).length;
    final verseObj =
        widget.repository.getVerse(_postSurahId, _postVerseId);
    final translationText = resolveVerseTranslationText(
      context: context,
      verseKey: '$_postSurahId:$_postVerseId',
      verse: verseObj,
    );

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: colors.borderSoft),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ร่วมแบ่งปันข้อคิดใคร่ครวญ (ตดับบุร)',
                style: GoogleFonts.notoSansThai(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: colors.foreground,
                ),
              ),
              if (user == null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6EFE3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE8DFC8)),
                  ),
                  child: Text(
                    'โหมดผู้เยี่ยมชม',
                    style: GoogleFonts.notoSansThai(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF8A6530),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Surah & Ayah Selectors
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ซูเราะฮฺ',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: colors.surfaceMuted,
                        border: Border.all(color: colors.borderSoft),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _postSurahId,
                          isExpanded: true,
                          dropdownColor: colors.surface,
                          style: GoogleFonts.notoSansThai(
                            fontSize: 12,
                            color: colors.foreground,
                          ),
                          items: surahIds.map((id) {
                            final name = widget.repository
                                .getSurahName(id)
                                .replaceAll(RegExp(r'^\d+\.\s*'), '');
                            return DropdownMenuItem(
                              value: id,
                              child: Text(
                                '$id. $name',
                                style: GoogleFonts.notoSansThai(
                                  fontSize: 12,
                                  color: colors.foreground,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _postSurahId = val;
                                _postVerseId = '1';
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'อายะฮฺ',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: colors.surfaceMuted,
                        border: Border.all(color: colors.borderSoft),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _postVerseId,
                          isExpanded: true,
                          dropdownColor: colors.surface,
                          style: GoogleFonts.notoSansThai(
                            fontSize: 12,
                            color: colors.foreground,
                          ),
                          items: List.generate(versesCount, (i) {
                            final ayahNum = (i + 1).toString();
                            return DropdownMenuItem(
                              value: ayahNum,
                              child: Text(
                                'อายะฮฺที่ $ayahNum',
                                style: GoogleFonts.notoSansThai(
                                  fontSize: 12,
                                  color: colors.foreground,
                                ),
                              ),
                            );
                          }),
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
          if (translationText.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  left: BorderSide(color: colors.primary, width: 3),
                  top: BorderSide(color: colors.borderSoft),
                  right: BorderSide(color: colors.borderSoft),
                  bottom: BorderSide(color: colors.borderSoft),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'คำแปล ($_postSurahId:$_postVerseId)',
                    style: GoogleFonts.notoSansThai(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    translationText,
                    style: GoogleFonts.notoSansThai(
                      fontSize: 12,
                      color: colors.foreground,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

          TextField(
            controller: _postController,
            style: GoogleFonts.notoSansThai(
              fontSize: 13,
              color: colors.foreground,
            ),
            decoration: InputDecoration(
              hintText: 'เขียนข้อคิดหรือการใคร่ครวญของคุณ...',
              hintStyle: GoogleFonts.notoSansThai(
                fontSize: 12,
                color: colors.textMuted,
              ),
              filled: true,
              fillColor: colors.surfaceMuted,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: colors.borderSoft),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: colors.borderSoft),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: colors.primary, width: 1.5),
              ),
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
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 2,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isAnonymous
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: 16,
                        color: _isAnonymous ? colors.primary : colors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'โพสต์โดยไม่ระบุชื่อ',
                        style: GoogleFonts.notoSansThai(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: _isPosting || _postController.text.trim().isEmpty
                    ? null
                    : _handlePost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isPosting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'แบ่งปันข้อคิด',
                        style: GoogleFonts.notoSansThai(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppThemeColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2EE),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFB7D4C7)),
              ),
              child: const Center(
                child: Icon(
                  Icons.forum_outlined,
                  size: 28,
                  color: Color(0xFF0E5A4A),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'ยังไม่มีข้อคิดในหมวดนี้',
              style: GoogleFonts.notoSansThai(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.foreground,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'มาร่วมเป็นคนแรกที่แบ่งปันข้อคิดจากอายะฮฺนี้กันเถอะ!',
              style: GoogleFonts.notoSansThai(
                fontSize: 12,
                color: colors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => setState(() => _showCompose = true),
              icon: const Icon(Icons.edit_note, size: 16),
              label: Text(
                'เขียนข้อคิดคนแรก',
                style: GoogleFonts.notoSansThai(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
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
  final String? currentUserId;
  final VoidCallback onLike;
  final VoidCallback onDelete;
  final void Function(String surahId, String verseId) onOpenVerse;
  final void Function(String surahId, String verseId) onOpenMushaf;

  const _CommunityNoteCard({
    required this.note,
    required this.repository,
    required this.colors,
    required this.primaryColor,
    required this.currentUserId,
    required this.onLike,
    required this.onDelete,
    required this.onOpenVerse,
    required this.onOpenMushaf,
  });

  @override
  Widget build(BuildContext context) {
    final surahName = repository
        .getSurahName(note.surahId)
        .replaceAll(RegExp(r'^\d+\.\s*'), '');
    final surahAr = offlineSurahNamesAr[note.surahId];
    final verseObj = repository.getVerse(note.surahId, note.verseId);
    final translationText = resolveVerseTranslationText(
      context: context,
      verseKey: '${note.surahId}:${note.verseId}',
      verse: verseObj,
    );

    final isAuthor = currentUserId != null && currentUserId == note.userId;
    final isGuestAuthor = note.userId.startsWith('guest-');
    final canDelete = isAuthor || isGuestAuthor;

    final authorName = note.isAnonymous
        ? 'ผู้ไม่ประสงค์ออกนาม'
        : (note.userEmail?.split('@').first ?? 'ผู้ใคร่ครวญอัลกุรอาน');

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: colors.borderSoft),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Author Header ──────────────────────────────────────────────────
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFEAF2EE),
                child: Text(
                  authorName.substring(0, 1).toUpperCase(),
                  style: GoogleFonts.notoSansThai(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0E5A4A),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authorName,
                      style: GoogleFonts.notoSansThai(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: colors.foreground,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      timeago.format(note.updatedAt),
                      style: GoogleFonts.notoSansThai(
                        fontSize: 10,
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              // Surah & Verse Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.borderSoft),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$surahName ${note.surahId}:${note.verseId}',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                    ),
                    if (surahAr != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        surahAr,
                        style: const TextStyle(
                          fontFamily: 'UthmanicHafs',
                          fontSize: 12,
                          color: Color(0xFF0E5A4A),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Verse Quote Box ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(color: colors.primary, width: 3.5),
                top: BorderSide(color: colors.borderSoft),
                right: BorderSide(color: colors.borderSoft),
                bottom: BorderSide(color: colors.borderSoft),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Arabic text
                FutureBuilder<String>(
                  future: repository.fetchArabicVerse(
                    note.surahId,
                    note.verseId,
                  ),
                  builder: (context, snapshot) {
                    final arabic = snapshot.data;
                    if (arabic == null || arabic.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        arabic,
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontFamily: 'UthmanicHafs',
                          fontSize: 17,
                          height: 2.1,
                          color: colors.foreground,
                        ),
                      ),
                    );
                  },
                ),
                // Thai Translation
                if (translationText.isNotEmpty)
                  Text(
                    translationText,
                    style: GoogleFonts.notoSansThai(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                      color: colors.foreground,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Note Text ──────────────────────────────────────────────────────
          Text(
            note.noteText,
            style: GoogleFonts.notoSansThai(
              fontSize: 13,
              height: 1.6,
              color: colors.foreground,
            ),
          ),
          const SizedBox(height: 14),

          // ── Footer Actions ─────────────────────────────────────────────────
          Row(
            children: [
              // Like Button
              InkWell(
                onTap: onLike,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: note.userLiked
                        ? const Color(0xFFFDE8E8)
                        : colors.surfaceMuted,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: note.userLiked
                          ? const Color(0xFFF98080)
                          : colors.borderSoft,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        note.userLiked ? '❤️' : '🤍',
                        style: const TextStyle(fontSize: 11),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${note.likesCount}',
                        style: GoogleFonts.notoSansThai(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: note.userLiked
                              ? const Color(0xFFC81E1E)
                              : colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              // Meaning Reader button
              InkWell(
                onTap: () => onOpenVerse(note.surahId, note.verseId),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'อ่านฉบับแปล',
                        style: GoogleFonts.notoSansThai(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 9,
                        color: colors.primary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Mushaf button
              InkWell(
                onTap: () => onOpenMushaf(note.surahId, note.verseId),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6EFE3),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE8DFC8)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.menu_book,
                        size: 11,
                        color: Color(0xFF8A6530),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'มุศหัฟ',
                        style: GoogleFonts.notoSansThai(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF8A6530),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (canDelete) ...[
                const SizedBox(width: 6),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: Colors.red.shade400,
                  ),
                  tooltip: 'ลบข้อคิดนี้',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: colors.surface,
                        title: Text(
                          'ลบข้อคิดนี้',
                          style: GoogleFonts.notoSansThai(
                            fontWeight: FontWeight.bold,
                            color: colors.foreground,
                          ),
                        ),
                        content: Text(
                          'คุณต้องการลบข้อคิดที่คุณแบ่งปันนี้ใช่หรือไม่?',
                          style: GoogleFonts.notoSansThai(
                            color: colors.foreground,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(
                              context.tr('cancel'),
                              style: GoogleFonts.notoSansThai(
                                fontWeight: FontWeight.bold,
                                color: colors.textMuted,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              onDelete();
                            },
                            child: Text(
                              'ลบ',
                              style: GoogleFonts.notoSansThai(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
