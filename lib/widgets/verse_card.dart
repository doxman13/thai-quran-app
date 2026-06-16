// lib/widgets/verse_card.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/verse.dart';
import '../data/quran_repository.dart';
import '../providers/settings_provider.dart';
import '../providers/bookmark_provider.dart';
import '../providers/progress_provider.dart';

class VerseCard extends StatefulWidget {
  final Verse verse;
  final bool useThaiV3;
  final QuranRepository repository;
  final int index;

  const VerseCard({
    Key? key,
    required this.verse,
    required this.repository,
    required this.index,
    this.useThaiV3 = true,
  }) : super(key: key);

  @override
  State<VerseCard> createState() => _VerseCardState();
}

class _VerseCardState extends State<VerseCard> {
  bool _isArabicVisible = false;

  @override
  void initState() {
    super.initState();
    // Check global settings after frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      if (settings.alwaysShowArabic) {
        _loadArabic();
      }
    });
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

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final progress = Provider.of<ProgressProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isHighlighted = widget.index == progress.lastVerseIndex;

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

    // Force show if global setting is on
    if (settings.alwaysShowArabic && !_isArabicVisible && widget.verse.arabic.isEmpty && !widget.verse.isArabicLoading) {
      _loadArabic();
    }

    return AnimatedScale(
      scale: isHighlighted ? 1.025 : 1.0,
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
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
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
                    color: isDark ? const Color(0xFF1E2E3E) : const Color(0xFFF0FDFA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.teal.shade400,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.teal.withOpacity(isDark ? 0.35 : 0.12),
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.teal.shade900 : Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.verse.id,
                  style: GoogleFonts.prompt(
                    color: isDark ? Colors.teal.shade200 : Colors.teal.shade700,
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
                          color: isBookmarked ? Colors.amber.shade600 : (isDark ? Colors.blueGrey.shade400 : Colors.blueGrey.shade400),
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
                        color: isDark ? Colors.blueGrey.shade400 : Colors.blueGrey.shade400,
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
            const SizedBox(height: 12),
            if (widget.verse.isArabicLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.teal),
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
            const SizedBox(height: 12),
            Divider(color: isDark ? Colors.blueGrey.shade700 : const Color(0xFFF1F5F9)),
          ],
          
          const SizedBox(height: 16),
          
          // Thai Translation
          Text(
            widget.useThaiV3 ? widget.verse.thaiV3 : widget.verse.thaiV2,
            style: GoogleFonts.prompt(
              fontSize: 16, // Reduced font size as requested
              height: 1.6,
              color: isDark ? Colors.blueGrey.shade200 : const Color(0xFF334155),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    ),
  ],
),
),
);
}
}
