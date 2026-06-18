// lib/widgets/verse_card.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/verse.dart';
import '../data/quran_repository.dart';
import '../providers/settings_provider.dart';
import '../providers/bookmark_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/notes_provider.dart';
import '../providers/stats_provider.dart';

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
  bool _showAuditBox = false;
  bool _showNotesBox = false;
  
  final TextEditingController _auditController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  
  bool _isSavingAudit = false;
  bool _auditSaved = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      if (settings.alwaysShowArabic) {
        _loadArabic();
      }
      
      // Load initial personal note
      final notesProv = Provider.of<NotesProvider>(context, listen: false);
      _notesController.text = notesProv.getNoteForVerse(widget.verse.surahId, widget.verse.id);
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

    final fetched = await widget.repository.fetchArabicVerse(widget.verse.surahId, widget.verse.id);
    
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
      'source': 'Mobile App'
    };

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final userHost = settings.webHostUrl;
    bool success = false;
    
    // Attempt API save
    try {
      final List<Uri> urls = [];
      // Use the new shared PHP backend for audit reports
      urls.add(Uri.parse('https://quran.salamthailand.com/save_audit.php'));

      for (var url in urls) {
        try {
          final res = await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(auditData),
          ).timeout(const Duration(seconds: 2));

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
      cachedAudits.add(json.encode({
        'timestamp': DateTime.now().toIso8601String(),
        'surahId': widget.verse.surahId,
        'verseId': widget.verse.id,
        'comment': comment,
        'synced': success,
        'auditorName': prefs.getString('auditorName') ?? 'Mobile User',
        'source': 'Mobile App',
      }));
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
          content: Text(success ? 'Audit submitted successfully!' : 'Audit saved locally offline!'),
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
    notesProv.saveNote(widget.verse.surahId, widget.verse.id, _notesController.text);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Personal note saved!'),
        duration: Duration(seconds: 1),
      ),
    );
    setState(() {
      _showNotesBox = false;
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
    final themeColor = settings.getPrimaryColor();
    final highlightColor = settings.getHighlightColor();

    // Auto-reset check for individual Arabic toggle when global setting changes
    final alwaysShow = settings.alwaysShowArabic;
    if (_lastGlobalArabicState != null && _lastGlobalArabicState != alwaysShow) {
      _isArabicVisible = alwaysShow;
    }
    _lastGlobalArabicState = alwaysShow;

    if (isHighlighted) {
      // Log reading stat
      WidgetsBinding.instance.addPostFrameCallback((_) {
        statsProv.logVerseRead(widget.verse.surahId, widget.verse.id);
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

    // Force load if global is on
    if (settings.alwaysShowArabic && !_isArabicVisible && widget.verse.arabic.isEmpty && !widget.verse.isArabicLoading) {
      _loadArabic();
    }

    final hasNote = notesProv.getNoteForVerse(widget.verse.surahId, widget.verse.id).isNotEmpty;

    return GestureDetector(
      onTap: () {
        if (!isHighlighted) {
          progress.setVerseIndexAndScroll(widget.index);
        }
      },
      child: AnimatedScale(
        scale: isHighlighted ? 1.015 : 1.0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Stack(
            children: [
              // Base Card Background (Normal)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? (settings.themeColor == 'sepia' ? const Color(0xFF261D17) : const Color(0xFF1E293B))
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
                          ? (settings.themeColor == 'sepia' ? const Color(0xFF33251D) : const Color(0xFF1E2E3E))
                          : (settings.themeColor == 'sepia' ? const Color(0xFFF6E6C3) : const Color(0xFFF0FDFA)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: highlightColor,
                        width: 2.5,
                      ),
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Bookmark Button
                            Consumer<BookmarkProvider>(
                              builder: (context, bookmarkProvider, child) {
                                final isBookmarked = bookmarkProvider.isBookmarked(widget.verse.surahId, widget.verse.id);
                                return IconButton(
                                  iconSize: 20,
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  icon: Icon(
                                    isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                                    color: isBookmarked ? Colors.amber.shade600 : (isDark ? Colors.blueGrey.shade400 : Colors.blueGrey.shade500),
                                  ),
                                  onPressed: () {
                                    bookmarkProvider.toggleBookmark(widget.verse.surahId, widget.verse.id);
                                  },
                                );
                              },
                            ),
                            // Visibility Button
                            if (!settings.alwaysShowArabic)
                              IconButton(
                                iconSize: 20,
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                icon: Icon(
                                  _isArabicVisible ? Icons.visibility_off : Icons.visibility,
                                  color: isDark ? Colors.blueGrey.shade400 : Colors.blueGrey.shade500,
                                ),
                                onPressed: () {
                                  if (!_isArabicVisible) {
                                    _loadArabic();
                                  } else {
                                    setState(() {
                                      _isArabicVisible = false;
                                    });
                                  }
                                },
                              ),
                          ],
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
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.teal),
                            ),
                          ),
                        )
                      else
                        Directionality(
                          textDirection: TextDirection.rtl,
                          child: Text(
                            widget.verse.arabic,
                            style: arabicStyle,
                          ),
                        ),
                      const SizedBox(height: 14),
                      Divider(color: isDark ? Colors.blueGrey.shade800 : const Color(0xFFE2E8F0)),
                    ],
                    
                    const SizedBox(height: 14),
                    
                    // Translations Container
                    if (settings.showThaiV3) ...[
                      const SizedBox(height: 8),
                      _buildTranslationBlock(
                        label: 'Thai V3 (Revised)',
                        text: widget.verse.thaiV3,
                        labelBg: isDark ? const Color(0xFF042F2E) : Colors.teal.shade50,
                        labelFg: isDark ? Colors.teal.shade200 : Colors.teal.shade800,
                        textStyle: GoogleFonts.prompt(
                          fontSize: 16,
                          height: 1.65,
                          color: isDark ? Colors.white : (settings.themeColor == 'sepia' ? const Color(0xFF2E1705) : const Color(0xFF0F172A)),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (settings.showThaiV2) ...[
                      const SizedBox(height: 12),
                      _buildTranslationBlock(
                        label: 'Thai V2 (Original)',
                        text: widget.verse.thaiV2,
                        labelBg: isDark ? Colors.amber.shade900 : Colors.amber.shade50,
                        labelFg: isDark ? Colors.amber.shade200 : Colors.amber.shade800,
                        textStyle: GoogleFonts.prompt(
                          fontSize: 15,
                          height: 1.65,
                          color: isDark ? const Color(0xFFE2E8F0) : (settings.themeColor == 'sepia' ? const Color(0xFF2E1705) : const Color(0xFF334155)),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (settings.showEnglish) ...[
                      const SizedBox(height: 12),
                      _buildTranslationBlock(
                        label: 'English Translation',
                        text: widget.verse.english,
                        labelBg: isDark ? Colors.blue.shade900 : Colors.blue.shade50,
                        labelFg: isDark ? Colors.blue.shade200 : Colors.blue.shade800,
                        textStyle: GoogleFonts.prompt(
                          fontSize: 14,
                          height: 1.6,
                          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],


                    if (hasNote) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.brown.withOpacity(0.2) : Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? Colors.brown.withOpacity(0.4) : Colors.amber.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.edit_note, size: 18, color: isDark ? Colors.amber.shade200 : Colors.amber.shade800),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                notesProv.getNoteForVerse(widget.verse.surahId, widget.verse.id),
                                style: GoogleFonts.prompt(
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  color: isDark ? Colors.amber.shade100 : Colors.amber.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Action buttons (Audit and Personal Notes)
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _showNotesBox = !_showNotesBox;
                              _showAuditBox = false;
                            });
                          },
                          icon: Icon(Icons.edit_note, size: 16, color: themeColor),
                          label: Text('Note', style: GoogleFonts.prompt(fontSize: 12, color: themeColor)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _showAuditBox = !_showAuditBox;
                              _showNotesBox = false;
                            });
                          },
                          icon: Icon(Icons.bug_report_outlined, size: 16, color: Colors.blueGrey),
                          label: Text('Audit', style: GoogleFonts.prompt(fontSize: 12, color: Colors.blueGrey)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          ),
                        ),
                      ],
                    ),

                    // Collapsible Personal Note Input
                    if (_showNotesBox) ...[
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
                                  onPressed: () => setState(() => _showNotesBox = false),
                                  child: Text('Cancel', style: GoogleFonts.prompt(fontSize: 12)),
                                ),
                                ElevatedButton(
                                  onPressed: () => _savePersonalNote(notesProv),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: themeColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  ),
                                  child: Text('Save', style: GoogleFonts.prompt(fontSize: 12)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Collapsible Audit Input
                    if (_showAuditBox) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black26 : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.withOpacity(0.1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            TextField(
                              controller: _auditController,
                              style: GoogleFonts.prompt(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Enter audit error report/fix details...',
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
                                  onPressed: () => setState(() => _showAuditBox = false),
                                  child: Text('Cancel', style: GoogleFonts.prompt(fontSize: 12, color: Colors.grey)),
                                ),
                                ElevatedButton(
                                  onPressed: _isSavingAudit ? null : _submitAuditComment,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  ),
                                  child: _isSavingAudit
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : Text(_auditSaved ? 'Saved ✓' : 'Submit Audit', style: GoogleFonts.prompt(fontSize: 12)),
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
      ),
    );
  }

  Widget _buildTranslationBlock({
    required String label,
    required String text,
    required Color labelBg,
    required Color labelFg,
    required TextStyle textStyle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: labelBg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: GoogleFonts.prompt(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: labelFg,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          text,
          style: textStyle,
        ),
      ],
    );
  }
}
