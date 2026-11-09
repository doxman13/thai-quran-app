import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/notes_provider.dart';
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
import 'tadabbur_community_screen.dart';
import '../widgets/auth_bottom_sheet.dart';

class TadabburPrivateScreen extends StatefulWidget {
  final QuranRepository repository;

  const TadabburPrivateScreen({super.key, required this.repository});

  @override
  State<TadabburPrivateScreen> createState() => _TadabburPrivateScreenState();
}

class _TadabburPrivateScreenState extends State<TadabburPrivateScreen> {
  final _repo = TadabburRepository();
  final _foundationRepository = QuranFoundationRepository();
  List<TadabburNote> _notes = [];
  Map<String, String> _reviewStatuses = {};
  bool _loading = true;
  bool _isSyncing = false;
  String? _selectedSurahId;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() => _loading = true);
    final user = Supabase.instance.client.auth.currentUser;
    final notesProv = context.read<NotesProvider>();

    if (user != null) {
      try {
        await notesProv.syncWithSupabase();
        final remoteNotes = await _repo.fetchUserNotes();
        final statuses = await _repo.fetchUserReviewStatuses();
        if (mounted) {
          final localMap = {
            for (final n in notesProv.personalNotes.values)
              '${n.surahId}:${n.verseId}': n,
          };
          final mergedMap = <String, TadabburNote>{...localMap};
          for (final n in remoteNotes) {
            mergedMap['${n.surahId}:${n.verseId}'] = n;
          }
          final list = mergedMap.values.toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

          setState(() {
            _notes = list;
            _reviewStatuses = statuses;
            if (_notes.isNotEmpty &&
                _selectedSurahId != null &&
                !_notes.any((n) => n.surahId == _selectedSurahId)) {
              _selectedSurahId = null;
            }
            _loading = false;
          });
          return;
        }
      } catch (e) {
        debugPrint('TadabburPrivateScreen remote fetch error: $e');
      }
    }

    // Guest mode or offline fallback
    if (mounted) {
      final list = notesProv.personalNotes.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      setState(() {
        _notes = list;
        if (_notes.isNotEmpty &&
            _selectedSurahId != null &&
            !_notes.any((n) => n.surahId == _selectedSurahId)) {
          _selectedSurahId = null;
        }
        _loading = false;
      });
    }
  }

  Future<void> _handleManualSync() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      final notesProv = context.read<NotesProvider>();
      await notesProv.syncWithSupabase();
      await _loadNotes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ซิงค์ข้อมูลเรียบร้อยแล้ว')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการซิงค์: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
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
          _selectedSurahId = null;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('failed_to_delete', args: {'error': '$e'}),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<TadabburNote> get _currentNotes {
    if (_selectedSurahId == null) return _notes;
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
    return _surahGroups.keys.toList()
      ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
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

  void _openProfile() {
    AuthBottomSheet.show(context).then((_) => _loadNotes());
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final notesProv = Provider.of<NotesProvider>(context);
    final primaryColor = settings.getPrimaryColor();
    final colors = settings.getAppColors();
    final user = Supabase.instance.client.auth.currentUser;

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
                          'บันทึกตดับบุรส่วนตัว',
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
                      if (user != null)
                        InkWell(
                          onTap: _isSyncing ? null : _handleManualSync,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: colors.borderSoft),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.sync,
                                  size: 15,
                                  color: _isSyncing
                                      ? colors.textMuted
                                      : colors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _isSyncing ? 'ซิงค์...' : 'ซิงค์',
                                  style: GoogleFonts.notoSansThai(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _isSyncing
                                        ? colors.textMuted
                                        : colors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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

            // ── Guest Sync Banner (if not logged in) ─────────────────────────
            if (user == null) _buildGuestPromptCard(colors),

            // ── Horizontal Surah Filter Strip (Mobile) ───────────────────────
            if (!_loading && _notes.isNotEmpty)
              _buildHorizontalSurahStrip(colors),

            // ── Body Content ────────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: primaryColor,
                      ),
                    )
                  : _notes.isEmpty
                  ? _buildEmptyState(colors)
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final showSidebar = constraints.maxWidth > 700;
                        if (showSidebar) {
                          return Row(
                            children: [
                              _buildSidebar(colors, primaryColor, notesProv),
                              Expanded(
                                child: _buildMainContent(
                                  colors,
                                  primaryColor,
                                  notesProv,
                                ),
                              ),
                            ],
                          );
                        }
                        return _buildMainContent(
                          colors,
                          primaryColor,
                          notesProv,
                        );
                      },
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
          // Active Tab: บันทึกส่วนตัว
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
                Icon(Icons.lock_outline, size: 14, color: colors.primary),
                const SizedBox(width: 6),
                Text(
                  'บันทึกส่วนตัว (${_notes.length})',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // Inactive Tab: ชุมชนตดับบุร
          InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radius - 4),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => TadabburCommunityScreen(
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
                  Icon(Icons.public, size: 14, color: colors.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    'ชุมชนตดับบุร',
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
        ],
      ),
    );
  }

  Widget _buildGuestPromptCard(AppThemeColors colors) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF6EFE3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE8DFC8)),
            ),
            child: const Center(
              child: Icon(
                Icons.cloud_off_outlined,
                size: 18,
                color: Color(0xFF8A6530),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'บันทึกในเครื่อง (โหมดผู้เยี่ยมชม)',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colors.foreground,
                  ),
                ),
                Text(
                  'เข้าสู่ระบบเพื่อซิงค์ข้อมูลไปยังทุกอุปกรณ์',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 11,
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _openProfile,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'เข้าสู่ระบบ',
                style: GoogleFonts.notoSansThai(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
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
            label: 'ทั้งหมด (${_notes.length})',
            isSelected: _selectedSurahId == null,
            colors: colors,
            onTap: () => setState(() => _selectedSurahId = null),
          ),
          ..._sortedSurahIds.map((surahId) {
            final count = _surahGroups[surahId]!.length;
            final surahName = widget.repository
                .getSurahName(surahId)
                .replaceAll(RegExp(r'^\d+\.\s*'), '');
            return _buildSurahChip(
              label: '$surahName ($count)',
              isSelected: _selectedSurahId == surahId,
              colors: colors,
              onTap: () => setState(() => _selectedSurahId = surahId),
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

  Widget _buildEmptyState(AppThemeColors colors) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2EE),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFB7D4C7)),
              ),
              child: const Center(
                child: Icon(
                  Icons.edit_note_outlined,
                  size: 32,
                  color: Color(0xFF0E5A4A),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'ยังไม่มีบันทึกการใคร่ครวญ',
              style: GoogleFonts.notoSansThai(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.foreground,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'คุณสามารถกดไอคอนตดับบุร (💭) บนอายะฮฺใดก็ได้ในหน้าอ่าน\nเพื่อจดบันทึกข้อคิดและเก็บรวบรวมไว้ที่นี่',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansThai(
                fontSize: 13,
                color: colors.textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _openVerse('1', '1'),
                  icon: const Icon(Icons.translate, size: 15),
                  label: Text(
                    'อ่านฉบับแปล',
                    style: GoogleFonts.notoSansThai(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => _openMushaf('1', '1'),
                  icon: const Icon(Icons.menu_book, size: 15),
                  label: Text(
                    'เปิดมุศหัฟ',
                    style: GoogleFonts.notoSansThai(fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8A6530),
                    side: const BorderSide(color: Color(0xFFE8DFC8)),
                    backgroundColor: const Color(0xFFF6EFE3),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
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

  Widget _buildSidebar(
    AppThemeColors colors,
    Color primaryColor,
    NotesProvider notesProv,
  ) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(right: BorderSide(color: colors.borderSoft, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'หมวดหมู่ซูเราะฮฺ',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colors.foreground,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF2EE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_notes.length}',
                    style: GoogleFonts.notoSansThai(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0E5A4A),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.borderSoft),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: _sortedSurahIds.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  final isActive = _selectedSurahId == null;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                      onTap: () => setState(() => _selectedSurahId = null),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? colors.primary.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.all_inclusive,
                              size: 16,
                              color: isActive ? colors.primary : colors.textMuted,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'ทุกซูเราะฮฺ',
                                style: GoogleFonts.notoSansThai(
                                  fontSize: 13,
                                  fontWeight: isActive
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isActive
                                      ? colors.primary
                                      : colors.foreground,
                                ),
                              ),
                            ),
                            Text(
                              '${_notes.length}',
                              style: GoogleFonts.notoSansThai(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isActive
                                    ? colors.primary
                                    : colors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                final surahId = _sortedSurahIds[index - 1];
                final count = _surahGroups[surahId]!.length;
                final isActive = _selectedSurahId == surahId;
                final surahName = widget.repository
                    .getSurahName(surahId)
                    .replaceAll(RegExp(r'^\d+\.\s*'), '');

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    onTap: () => setState(() => _selectedSurahId = surahId),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? colors.primary.withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? colors.primary
                                  : colors.surfaceMuted,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Text(
                                surahId,
                                style: GoogleFonts.notoSansThai(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isActive
                                      ? Colors.white
                                      : colors.foreground,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              surahName,
                              style: GoogleFonts.notoSansThai(
                                fontSize: 13,
                                fontWeight: isActive
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isActive
                                    ? colors.primary
                                    : colors.foreground,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '$count',
                            style: GoogleFonts.notoSansThai(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isActive
                                  ? colors.primary
                                  : colors.textMuted,
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

  Widget _buildMainContent(
    AppThemeColors colors,
    Color primaryColor,
    NotesProvider notesProv,
  ) {
    final notes = _currentNotes;
    if (notes.isEmpty) return _buildEmptyState(colors);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      itemCount: notes.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final note = notes[index];
        final reviewStatus = _reviewStatuses[note.id];

        return _NoteCard(
          note: note,
          reviewStatus: reviewStatus,
          repository: widget.repository,
          colors: colors,
          primaryColor: primaryColor,
          onDelete: () => _deleteNote(note.id, notesProv),
          onOpenVerse: (surahId, verseId) => _openVerse(surahId, verseId),
          onOpenMushaf: (surahId, verseId) => _openMushaf(surahId, verseId),
          onTogglePublic: (note) async {
            final user = Supabase.instance.client.auth.currentUser;
            if (user == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('กรุณาเข้าสู่ระบบก่อนแชร์สู่ชุมชน'),
                ),
              );
              return;
            }

            final currentStatus = _reviewStatuses[note.id];

            if (note.isPublic) {
              // 1. Revert from public to private
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: colors.surface,
                  title: Text(
                    'เปลี่ยนเป็นบันทึกส่วนตัว',
                    style: GoogleFonts.notoSansThai(
                      fontWeight: FontWeight.bold,
                      color: colors.foreground,
                    ),
                  ),
                  content: Text(
                    'ต้องการยกเลิกการแชร์สู่ชุมชนใช่หรือไม่? บันทึกนี้จะไม่ปรากฏในชุมชนอีกต่อไป',
                    style: GoogleFonts.notoSansThai(
                      color: colors.foreground,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(
                        context.tr('cancel'),
                        style: GoogleFonts.notoSansThai(
                          fontWeight: FontWeight.bold,
                          color: colors.textMuted,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(
                        'เปลี่ยนเป็นส่วนตัว',
                        style: GoogleFonts.notoSansThai(
                          color: colors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                try {
                  await notesProv.saveNote(
                    surahId: note.surahId,
                    verseId: note.verseId,
                    noteText: note.noteText,
                    isPublic: false,
                    isAnonymous: note.isAnonymous,
                  );
                  await _repo.cancelReviewRequest(note.id);
                  await _loadNotes();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('เปลี่ยนเป็นบันทึกส่วนตัวแล้ว')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              }
            } else if (currentStatus == 'open' || currentStatus == 'reviewing') {
              // 2. Pending review -> Allow cancel request
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: colors.surface,
                  title: Text(
                    'ยกเลิกคำขอตรวจสอบ',
                    style: GoogleFonts.notoSansThai(
                      fontWeight: FontWeight.bold,
                      color: colors.foreground,
                    ),
                  ),
                  content: Text(
                    'บันทึกนี้กำลังอยู่ระหว่างรอแอดมินตรวจสอบเพื่อแชร์สู่ชุมชน คุณต้องการยกเลิกคำขอใช่หรือไม่?',
                    style: GoogleFonts.notoSansThai(
                      color: colors.foreground,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(
                        context.tr('cancel'),
                        style: GoogleFonts.notoSansThai(
                          fontWeight: FontWeight.bold,
                          color: colors.textMuted,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(
                        'ยกเลิกคำขอ',
                        style: GoogleFonts.notoSansThai(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await _repo.cancelReviewRequest(note.id);
                await _loadNotes();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ยกเลิกคำขอตรวจสอบเรียบร้อยแล้ว')),
                  );
                }
              }
            } else {
              // 3. Private -> Request to submit for admin review
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: colors.surface,
                  title: Row(
                    children: [
                      Icon(Icons.rate_review_outlined, color: colors.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'ส่งให้แอดมินตรวจสอบ',
                          style: GoogleFonts.notoSansThai(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: colors.foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
                  content: Text(
                    'เพื่อรักษาความถูกต้องและคุณภาพของเนื้อหา บันทึกนี้จะถูกส่งให้แอดมินตรวจสอบก่อนแสดงในชุมชนสาธารณะ เมื่อได้รับอนุมัติ บันทึกจะแสดงสู่สาธารณะโดยอัตโนมัติ',
                    style: GoogleFonts.notoSansThai(
                      fontSize: 13,
                      height: 1.5,
                      color: colors.foreground,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(
                        context.tr('cancel'),
                        style: GoogleFonts.notoSansThai(
                          fontWeight: FontWeight.bold,
                          color: colors.textMuted,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'ส่งตรวจสอบ',
                        style: GoogleFonts.notoSansThai(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                try {
                  await notesProv.saveNote(
                    surahId: note.surahId,
                    verseId: note.verseId,
                    noteText: note.noteText,
                    isPublic: false,
                    isAnonymous: note.isAnonymous,
                  );
                  await _repo.submitForPublicReview(note);
                  await _loadNotes();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('ส่งบันทึกให้แอดมินตรวจสอบเรียบร้อยแล้ว'),
                        backgroundColor: Color(0xFF0E5A4A),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('เกิดข้อผิดพลาด: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
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
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context.tr(
                        'failed_to_update',
                        args: {'error': '$e'},
                      ),
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
        );
      },
    );
  }
}

class _NoteCard extends StatefulWidget {
  final TadabburNote note;
  final String? reviewStatus;
  final QuranRepository repository;
  final AppThemeColors colors;
  final Color primaryColor;
  final VoidCallback onDelete;
  final void Function(String surahId, String verseId) onOpenVerse;
  final void Function(String surahId, String verseId) onOpenMushaf;
  final Future<void> Function(TadabburNote) onTogglePublic;
  final Future<void> Function(TadabburNote, String) onEdit;

  const _NoteCard({
    required this.note,
    this.reviewStatus,
    required this.repository,
    required this.colors,
    required this.primaryColor,
    required this.onDelete,
    required this.onOpenVerse,
    required this.onOpenMushaf,
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
  void didUpdateWidget(covariant _NoteCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.note.noteText != widget.note.noteText && !_isEditing) {
      _editController.text = widget.note.noteText;
    }
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final note = widget.note;
    final surahName = widget.repository
        .getSurahName(note.surahId)
        .replaceAll(RegExp(r'^\d+\.\s*'), '');
    final surahAr = offlineSurahNamesAr[note.surahId];
    final verseObj = widget.repository.getVerse(note.surahId, note.verseId);
    final translationText = resolveVerseTranslationText(
      context: context,
      verseKey: '${note.surahId}:${note.verseId}',
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
          // ── Verse Quote Box ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(10),
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
                // Surah Header & Read Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              '$surahName (${note.surahId}:${note.verseId})',
                              style: GoogleFonts.notoSansThai(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: colors.primary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (surahAr != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              surahAr,
                              style: const TextStyle(
                                fontFamily: 'UthmanicHafs',
                                fontSize: 14,
                                color: Color(0xFF0E5A4A),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        InkWell(
                          onTap: () =>
                              widget.onOpenVerse(note.surahId, note.verseId),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'อ่านบริบท',
                                  style: GoogleFonts.notoSansThai(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: colors.primary,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 10,
                                  color: colors.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () =>
                              widget.onOpenMushaf(note.surahId, note.verseId),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6EFE3),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFE8DFC8),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.menu_book,
                                  size: 11,
                                  color: Color(0xFF8A6530),
                                ),
                                const SizedBox(width: 4),
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
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Arabic Verse Calligraphy
                FutureBuilder<String>(
                  future: widget.repository.fetchArabicVerse(
                    note.surahId,
                    note.verseId,
                  ),
                  builder: (context, snapshot) {
                    final arabic = snapshot.data;
                    if (arabic == null || arabic.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        arabic,
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontFamily: 'UthmanicHafs',
                          fontSize: 18,
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
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.6,
                      color: colors.foreground,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Reflection Note Content ────────────────────────────────────────
          if (_isEditing)
            Column(
              children: [
                TextField(
                  controller: _editController,
                  maxLines: 4,
                  style: GoogleFonts.notoSansThai(
                    fontSize: 14,
                    color: colors.foreground,
                    height: 1.5,
                  ),
                  decoration: InputDecoration(
                    hintText: 'เขียนข้อคิดหรือการใคร่ครวญของคุณ...',
                    hintStyle: GoogleFonts.notoSansThai(
                      fontSize: 13,
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
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _editController.text = widget.note.noteText;
                          _isEditing = false;
                        });
                      },
                      child: Text(
                        context.tr('cancel'),
                        style: GoogleFonts.notoSansThai(
                          fontWeight: FontWeight.bold,
                          color: colors.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        await widget.onEdit(note, _editController.text);
                        if (mounted) setState(() => _isEditing = false);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        context.tr('save'),
                        style: GoogleFonts.notoSansThai(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          else ...[
            if (note.noteText.isNotEmpty)
              Text(
                note.noteText,
                style: GoogleFonts.notoSansThai(
                  fontSize: 14,
                  height: 1.6,
                  color: colors.foreground,
                ),
              )
            else
              Text(
                'บันทึกเป็นอายะฮฺโปรด (ยังไม่ได้ระบุข้อความใคร่ครวญ)',
                style: GoogleFonts.notoSansThai(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: colors.textMuted,
                ),
              ),
            const SizedBox(height: 14),

            // ── Footer Meta & Actions ────────────────────────────────────────
            Row(
              children: [
                // Visibility toggle & status pill
                InkWell(
                  onTap: () => widget.onTogglePublic(note),
                  borderRadius: BorderRadius.circular(16),
                  child: () {
                    if (note.isPublic) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF2EE),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFB7D4C7)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.public, size: 13, color: Color(0xFF0E5A4A)),
                            const SizedBox(width: 4),
                            Text(
                              'แชร์สู่ชุมชน',
                              style: GoogleFonts.notoSansThai(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0E5A4A),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (widget.reviewStatus == 'open' || widget.reviewStatus == 'reviewing') {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.hourglass_top_rounded, size: 13, color: Color(0xFFB45309)),
                            const SizedBox(width: 4),
                            Text(
                              'รอตรวจสอบ',
                              style: GoogleFonts.notoSansThai(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFB45309),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (widget.reviewStatus == 'rejected') {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.close_rounded, size: 13, color: Color(0xFFB91C1C)),
                            const SizedBox(width: 4),
                            Text(
                              'ไม่อนุมัติ (ส่งใหม่)',
                              style: GoogleFonts.notoSansThai(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFB91C1C),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.surfaceMuted,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.borderSoft),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_outline, size: 13, color: colors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            'เฉพาะฉัน',
                            style: GoogleFonts.notoSansThai(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    );
                  }(),
                ),
                if (note.likesCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDE8E8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Text('❤️', style: TextStyle(fontSize: 10)),
                        const SizedBox(width: 3),
                        Text(
                          '${note.likesCount}',
                          style: GoogleFonts.notoSansThai(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFC81E1E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  timeago.format(note.updatedAt),
                  style: GoogleFonts.notoSansThai(
                    fontSize: 11,
                    color: colors.textMuted,
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 17,
                    color: colors.primary,
                  ),
                  tooltip: context.tr('edit'),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _isEditing = true),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 17,
                    color: Colors.red.shade400,
                  ),
                  tooltip: 'ลบบันทึก',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: colors.surface,
                        title: Text(
                          'ลบบันทึกการใคร่ครวญ',
                          style: GoogleFonts.notoSansThai(
                            fontWeight: FontWeight.bold,
                            color: colors.foreground,
                          ),
                        ),
                        content: Text(
                          'คุณต้องการลบบันทึกของอายะฮฺนี้ใช่หรือไม่?',
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
                              widget.onDelete();
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
            ),
          ],
        ],
      ),
    );
  }
}
