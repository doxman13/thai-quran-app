// lib/widgets/verse_card.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/verse.dart';
import '../data/quran_repository.dart';
import '../providers/settings_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/notes_provider.dart';
import '../providers/stats_provider.dart';
import '../providers/local_reading_provider.dart';
import '../shared/shared.dart';

class VerseCard extends StatefulWidget {
  final Verse verse;
  final QuranRepository repository;
  final int index;

  const VerseCard({
    Key? key,
    required this.verse,
    required this.repository,
    required this.index,
  }) : super(key: key);

  @override
  State<VerseCard> createState() => _VerseCardState();
}

class _VerseCardState extends State<VerseCard> {
  bool _isArabicVisible = false;
  bool? _lastGlobalArabicState;

  // Audit and personal notes states
  bool _isMenuVisible = false;
  bool _showAuditBox = false;
  bool _showNotesBox = false;
  bool _showTafsirBox = false;
  bool _showMoreTools = false;

  final TextEditingController _auditController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _isSavingAudit = false;
  bool _auditSaved = false;
  String _shareStatus = '';

  @override
  void initState() {
    super.initState();
    _isArabicVisible = widget.verse.isArabicVisible;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      if (settings.alwaysShowArabic || widget.verse.isArabicVisible) {
        _loadArabic();
      }

      // Load initial personal note
      final notesProv = Provider.of<NotesProvider>(context, listen: false);
      _notesController.text = notesProv.getNoteForVerse(
        widget.verse.surahId,
        widget.verse.id,
      );
    });
  }

  @override
  void dispose() {
    _auditController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadArabic() async {
    if (widget.verse.arabic.isNotEmpty) {
      setState(() {
        _isArabicVisible = true;
      });
      return;
    }

    setState(() {
      widget.verse.isArabicLoading = true;
      _isArabicVisible = true;
    });

    final fetched = await widget.repository.fetchArabicVerse(
      widget.verse.surahId,
      widget.verse.id,
    );

    if (mounted) {
      setState(() {
        widget.verse.arabic = fetched;
        widget.verse.isArabicLoading = false;
      });
    }
  }

  Future<void> _submitAuditComment() async {
    final comment = _auditController.text.trim();
    if (comment.isEmpty) return;

    setState(() {
      _isSavingAudit = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final auditData = {
      'surahId': widget.verse.surahId,
      'verseId': widget.verse.id,
      'comment': comment,
      'auditorName': prefs.getString('auditorName') ?? 'Mobile User',
      'source': 'Mobile App',
    };

    bool success = false;

    // Attempt API save
    try {
      final List<Uri> urls = [];
      // Use the new shared PHP backend for audit reports
      urls.add(Uri.parse('https://quran.salamthailand.com/save_audit.php'));

      for (var url in urls) {
        try {
          final res = await http
              .post(
                url,
                headers: {'Content-Type': 'application/json'},
                body: json.encode(auditData),
              )
              .timeout(const Duration(seconds: 2));

          if (res.statusCode == 200 || res.statusCode == 201) {
            success = true;
            break;
          }
        } catch (_) {
          // continue trying other urls
        }
      }
    } catch (_) {}

    // Save to local cached audits list in SharedPreferences as fallback/record
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedAudits = prefs.getStringList('local_audits') ?? [];
      cachedAudits.add(
        json.encode({
          'timestamp': DateTime.now().toIso8601String(),
          'surahId': widget.verse.surahId,
          'verseId': widget.verse.id,
          'comment': comment,
          'synced': success,
          'auditorName': prefs.getString('auditorName') ?? 'Mobile User',
          'source': 'Mobile App',
        }),
      );
      await prefs.setStringList('local_audits', cachedAudits);
    } catch (e) {
      debugPrint('Error caching audit: $e');
    }

    if (mounted) {
      setState(() {
        _isSavingAudit = false;
        _auditSaved = true;
        _auditController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Audit submitted successfully!'
                : 'Audit saved locally offline!',
          ),
          backgroundColor: success ? Colors.teal : Colors.amber.shade800,
        ),
      );

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _auditSaved = false;
          });
        }
      });
    }
  }

  void _savePersonalNote(NotesProvider notesProv) {
    notesProv.saveNote(
      widget.verse.surahId,
      widget.verse.id,
      _notesController.text,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tadabbur note saved!'),
        duration: Duration(seconds: 1),
      ),
    );
    setState(() {
      _showNotesBox = false;
    });
  }

  Future<void> _copyShareText(NotesProvider notesProv) async {
    final note = notesProv.getNoteForVerse(
      widget.verse.surahId,
      widget.verse.id,
    );
    final payload = SharePayload(
      surahId: widget.verse.surahId,
      verseId: widget.verse.id,
      verseKey: widget.verse.verseKey,
      surahName: widget.repository.getSurahName(widget.verse.surahId),
      arabic: widget.verse.arabic,
      translation: widget.verse.thaiV3,
      translationVersion: 'thai_v3',
      quickNote: note,
      url:
          'thai-quran-app://surah/${widget.verse.surahId}#v-${widget.verse.id}',
    );
    final text = formatVerseShareText(
      payload,
      note.trim().isEmpty ? 'translation_only' : 'translation_with_quick_note',
    );

    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    setState(() => _shareStatus = 'Copied');
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _shareStatus = '');
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final progress = Provider.of<ProgressProvider>(context);
    final notesProv = Provider.of<NotesProvider>(context);
    final statsProv = Provider.of<StatsProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isHighlighted = widget.index == progress.lastVerseIndex;
    if (!isHighlighted) {
      _isMenuVisible = false;
    }
    final themeColor = settings.getPrimaryColor();
    final highlightColor = settings.getHighlightColor();

    // Auto-reset check for individual Arabic toggle when global setting changes
    final alwaysShow = settings.alwaysShowArabic;
    if (_lastGlobalArabicState != null &&
        _lastGlobalArabicState != alwaysShow) {
      _isArabicVisible = alwaysShow;
    }
    _lastGlobalArabicState = alwaysShow;

    if (isHighlighted) {
      // Log reading stat
      WidgetsBinding.instance.addPostFrameCallback((_) {
        statsProv.logVerseRead(widget.verse.surahId, widget.verse.id);
        final localReading = Provider.of<LocalReadingProvider>(
          context,
          listen: false,
        );
        final activeProfile = localReading.activeProfile;
        final verseRef = toVerseRef(widget.verse.surahId, widget.verse.id);
        if (activeProfile != null &&
            activeProfile.current.verseKey != verseRef.verseKey) {
          localReading.updateProfileProgress(activeProfile.id, verseRef);
          localReading.addRecentReading(
            verse: verseRef,
            profileId: activeProfile.id,
          );
        }
      });
    }

    TextStyle arabicStyle;
    switch (settings.arabicFontFamily) {
      case 'UthmanicHafs':
        arabicStyle = TextStyle(
          fontFamily: 'UthmanicHafs',
          fontSize: settings.arabicFontSize,
          height: 2.0,
          color: isDark ? Colors.white : const Color(0xFF1E293B),
        );
        break;
      case 'AmiriQuran':
        arabicStyle = GoogleFonts.amiriQuran(
          fontSize: settings.arabicFontSize,
          height: 2.0,
          color: isDark ? Colors.white : const Color(0xFF1E293B),
        );
        break;
      case 'ScheherazadeNew':
        arabicStyle = GoogleFonts.scheherazadeNew(
          fontSize: settings.arabicFontSize,
          height: 2.0,
          color: isDark ? Colors.white : const Color(0xFF1E293B),
        );
        break;
      case 'Amiri':
        arabicStyle = GoogleFonts.amiri(
          fontSize: settings.arabicFontSize,
          height: 2.0,
          color: isDark ? Colors.white : const Color(0xFF1E293B),
        );
        break;
      default:
        arabicStyle = TextStyle(
          fontFamily: 'UthmanicHafs',
          fontSize: settings.arabicFontSize,
          height: 2.0,
          color: isDark ? Colors.white : const Color(0xFF1E293B),
        );
    }

    // Force load if Arabic should be visible (globally or locally) and is not loaded yet
    if ((settings.alwaysShowArabic || _isArabicVisible) &&
        widget.verse.arabic.isEmpty &&
        !widget.verse.isArabicLoading) {
      _loadArabic();
    }

    final hasNote = notesProv
        .getNoteForVerse(widget.verse.surahId, widget.verse.id)
        .isNotEmpty;

    return GestureDetector(
      onTap: () {
        if (!isHighlighted) {
          progress.setVerseIndexAndScroll(widget.index);
        } else {
          setState(() {
            _isMenuVisible = !_isMenuVisible;
          });
        }
      },
      onLongPress: () {
        if (isHighlighted) {
          setState(() {
            _isMenuVisible = !_isMenuVisible;
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Stack(
          children: [
              // Base Card Background (Normal)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? (settings.themeColor == 'sepia'
                              ? const Color(0xFF261D17)
                              : const Color(0xFF1E293B))
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),

              // Highlighted Card Background (Fades in/out)
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity: isHighlighted ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOut,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? (settings.themeColor == 'sepia'
                                ? const Color(0xFF33251D)
                                : const Color(0xFF1E2E3E))
                          : (settings.themeColor == 'sepia'
                                ? const Color(0xFFF6E6C3)
                                : const Color(0xFFF0FDFA)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: highlightColor, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: themeColor.withOpacity(isDark ? 0.35 : 0.12),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Content Layer
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? themeColor.withOpacity(0.25)
                                : themeColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Verse ${widget.verse.id}',
                            style: GoogleFonts.prompt(
                              color: isDark ? highlightColor : themeColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          _shareStatus,
                          style: GoogleFonts.prompt(
                            color: isDark
                                ? Colors.blueGrey.shade300
                                : Colors.blueGrey.shade500,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    // Arabic Text Area
                    if (_isArabicVisible || settings.alwaysShowArabic) ...[
                      const SizedBox(height: 14),
                      if (widget.verse.isArabicLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.teal,
                              ),
                            ),
                          ),
                        )
                      else
                        Directionality(
                          textDirection: TextDirection.rtl,
                          child: RichText(
                            text: TextSpan(
                              style: arabicStyle,
                              children: [
                                TextSpan(
                                  text: (() {
                                    final parts = widget.verse.arabic.split(' | ');
                                    return settings.arabicFontFamily == 'UthmanicHafs'
                                        ? parts.join(' ')
                                        : parts[0];
                                  })(),
                                ),
                                if (settings.arabicFontFamily != 'UthmanicHafs')
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isDark ? Colors.blueGrey.shade800 : Colors.grey.shade300,
                                          width: 1,
                                        ),
                                        color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        widget.verse.id,
                                        style: GoogleFonts.prompt(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.blueGrey.shade300 : Colors.blueGrey.shade600,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 14),
                      Divider(
                        color: isDark
                            ? Colors.blueGrey.shade800
                            : const Color(0xFFE2E8F0),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Translations Container
                    if (settings.showThaiV3) ...[
                      const SizedBox(height: 8),
                      _buildTranslationBlock(
                        label: 'Thai 3',
                        text: widget.verse.thaiV3,
                        labelFg: isDark
                            ? Colors.blueGrey.shade400
                            : Colors.blueGrey.shade500,
                        textStyle: GoogleFonts.prompt(
                          fontSize: 16,
                          height: 1.65,
                          color: isDark
                              ? Colors.white
                              : (settings.themeColor == 'sepia'
                                    ? const Color(0xFF2E1705)
                                    : const Color(0xFF0F172A)),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                    if (settings.showThaiV2) ...[
                      const SizedBox(height: 12),
                      _buildTranslationBlock(
                        label: 'Thai 2',
                        text: widget.verse.thaiV2,
                        labelFg: isDark
                            ? Colors.blueGrey.shade500
                            : Colors.blueGrey.shade400,
                        textStyle: GoogleFonts.prompt(
                          fontSize: 15,
                          height: 1.65,
                          color: isDark
                              ? const Color(0xFFE2E8F0)
                              : (settings.themeColor == 'sepia'
                                    ? const Color(0xFF2E1705)
                                    : const Color(0xFF334155)),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                    if (settings.showEnglish) ...[
                      const SizedBox(height: 12),
                      _buildTranslationBlock(
                        label: 'English',
                        text: widget.verse.english,
                        labelFg: isDark
                            ? Colors.blueGrey.shade500
                            : Colors.blueGrey.shade400,
                        textStyle: GoogleFonts.prompt(
                          fontSize: 14,
                          height: 1.6,
                          color: isDark
                              ? const Color(0xFFE2E8F0)
                              : const Color(0xFF334155),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],

                    if (hasNote) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.brown.withOpacity(0.2)
                              : Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark
                                ? Colors.brown.withOpacity(0.4)
                                : Colors.amber.shade200,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.edit_note,
                              size: 18,
                              color: isDark
                                  ? Colors.amber.shade200
                                  : Colors.amber.shade800,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                notesProv.getNoteForVerse(
                                  widget.verse.surahId,
                                  widget.verse.id,
                                ),
                                style: GoogleFonts.prompt(
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  color: isDark
                                      ? Colors.amber.shade100
                                      : Colors.amber.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Action buttons
                    if (isHighlighted && _isMenuVisible) ...[
                      const SizedBox(height: 16),
                      Consumer<LocalReadingProvider>(
                        builder: (context, localReading, child) {
                          final isBookmarked = localReading.isBookmarked(
                            widget.verse.surahId,
                            widget.verse.id,
                          );

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // 1. Bookmark
                                  _buildActionIcon(
                                    tooltip: 'Bookmark',
                                    icon: isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                                    active: isBookmarked,
                                    color: Colors.amber.shade700,
                                    onPressed: () {
                                      localReading.toggleBookmark(
                                        widget.verse.surahId,
                                        widget.verse.id,
                                      );
                                    },
                                  ),
                                  // 2. Short Tafsir
                                  if (widget.verse.shortTafsir != null)
                                    _buildActionIcon(
                                      tooltip: 'Short tafsir',
                                      icon: Icons.menu_book_outlined,
                                      active: _showTafsirBox,
                                      color: themeColor,
                                      onPressed: () {
                                        setState(() {
                                          _showTafsirBox = !_showTafsirBox;
                                          _showNotesBox = false;
                                          _showAuditBox = false;
                                          _showMoreTools = false;
                                        });
                                      },
                                    ),
                                  // 3. Arabic toggle with custom "ع" icon
                                  Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Tooltip(
                                      message: _isArabicVisible ? 'Hide Arabic' : 'Show Arabic',
                                      child: Material(
                                        type: MaterialType.transparency,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(8),
                                          onTap: () {
                                            if (!_isArabicVisible) {
                                              _loadArabic();
                                              widget.verse.isArabicVisible = true;
                                            } else {
                                              setState(() {
                                                _isArabicVisible = false;
                                                widget.verse.isArabicVisible = false;
                                              });
                                            }
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            width: 34,
                                            height: 34,
                                            decoration: BoxDecoration(
                                              color: _isArabicVisible ? themeColor.withOpacity(0.12) : Colors.transparent,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: _isArabicVisible ? themeColor.withOpacity(0.3) : Colors.transparent,
                                                width: 1,
                                              ),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              'ع',
                                              style: GoogleFonts.amiri(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: _isArabicVisible ? themeColor : (isDark ? Colors.blueGrey.shade300 : Colors.blueGrey.shade600),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // 4. More tools (three dots)
                                  _buildActionIcon(
                                    tooltip: 'More verse tools',
                                    icon: Icons.more_horiz,
                                    active: _showMoreTools,
                                    color: themeColor,
                                    onPressed: () {
                                      setState(() {
                                        _showMoreTools = !_showMoreTools;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              if (_showMoreTools) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A).withOpacity(0.3) : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark ? Colors.blueGrey.shade800.withOpacity(0.5) : Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildActionIcon(
                                        tooltip: 'Tadabbur note',
                                        icon: Icons.edit_note_outlined,
                                        active: _showNotesBox || hasNote,
                                        color: themeColor,
                                        onPressed: () {
                                          setState(() {
                                            _showNotesBox = !_showNotesBox;
                                            _showAuditBox = false;
                                            _showTafsirBox = false;
                                            _showMoreTools = false;
                                          });
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      _buildActionIcon(
                                        tooltip: 'Share',
                                        icon: Icons.ios_share_outlined,
                                        color: themeColor,
                                        onPressed: () {
                                          setState(() => _showMoreTools = false);
                                          _copyShareText(notesProv);
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      _buildActionIcon(
                                        tooltip: 'Report error',
                                        icon: Icons.report_problem_outlined,
                                        active: _showAuditBox,
                                        color: Colors.blueGrey,
                                        onPressed: () {
                                          setState(() {
                                            _showAuditBox = !_showAuditBox;
                                            _showNotesBox = false;
                                            _showTafsirBox = false;
                                            _showMoreTools = false;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ],

                    // Collapsible Short Tafsir
                    if (isHighlighted && _showTafsirBox && widget.verse.shortTafsir != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? Colors.blueGrey.shade800
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Short tafsir',
                                  style: GoogleFonts.prompt(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: themeColor,
                                  ),
                                ),
                                Text(
                                  widget.verse.shortTafsirSource ??
                                      'QuranEnc Thai Mokhtasar',
                                  style: GoogleFonts.prompt(
                                    fontSize: 10,
                                    color: isDark
                                        ? Colors.blueGrey.shade300
                                        : Colors.blueGrey.shade500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.verse.shortTafsir!,
                              style: GoogleFonts.prompt(
                                fontSize: 14,
                                height: 1.7,
                                color: isDark
                                    ? const Color(0xFFE2E8F0)
                                    : const Color(0xFF334155),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Collapsible Personal Note Input
                    if (isHighlighted && _showNotesBox) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black26 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            TextField(
                              controller: _notesController,
                              style: GoogleFonts.prompt(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Enter personal notes/thoughts...',
                                hintStyle: GoogleFonts.prompt(fontSize: 13),
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.all(10),
                                isDense: true,
                              ),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () =>
                                      setState(() => _showNotesBox = false),
                                  child: Text(
                                    'Cancel',
                                    style: GoogleFonts.prompt(fontSize: 12),
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () => _savePersonalNote(notesProv),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: themeColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 6,
                                    ),
                                  ),
                                  child: Text(
                                    'Save',
                                    style: GoogleFonts.prompt(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Collapsible Audit Input
                    if (isHighlighted && _showAuditBox) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black26 : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.1),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            TextField(
                              controller: _auditController,
                              style: GoogleFonts.prompt(fontSize: 14),
                              decoration: InputDecoration(
                                hintText:
                                    'Enter audit error report/fix details...',
                                hintStyle: GoogleFonts.prompt(fontSize: 13),
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.all(10),
                                isDense: true,
                              ),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () =>
                                      setState(() => _showAuditBox = false),
                                  child: Text(
                                    'Cancel',
                                    style: GoogleFonts.prompt(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: _isSavingAudit
                                      ? null
                                      : _submitAuditComment,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 6,
                                    ),
                                  ),
                                  child: _isSavingAudit
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          _auditSaved
                                              ? 'Saved ✓'
                                              : 'Submit Audit',
                                          style: GoogleFonts.prompt(
                                            fontSize: 12,
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
  }

  Widget _buildTranslationBlock({
    required String label,
    required String text,
    required Color labelFg,
    required TextStyle textStyle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: textStyle),
        const SizedBox(height: 5),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            label,
            style: GoogleFonts.prompt(
              fontSize: 10,
              fontWeight: FontWeight.w400,
              color: labelFg,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionIcon({
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool active = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: tooltip,
      iconSize: 20,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        backgroundColor: active ? color.withOpacity(0.12) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: active ? color.withOpacity(0.3) : Colors.transparent,
            width: 1,
          ),
        ),
      ),
      icon: Icon(
        icon,
        color: active ? color : (isDark ? Colors.blueGrey.shade300 : Colors.blueGrey.shade600),
      ),
      onPressed: onPressed,
    );
  }
}
