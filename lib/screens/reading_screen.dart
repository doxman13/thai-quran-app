// lib/screens/reading_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/progress_provider.dart';
import '../providers/settings_provider.dart';
import '../models/verse.dart';
import '../widgets/verse_card.dart';
import '../data/quran_repository.dart';
import 'bookmarks_screen.dart';

class ReadingScreen extends StatefulWidget {
  final QuranRepository repository;
  final String? initialSurah;
  final int? initialVerseIndex;
  final String? initialVerseId;

  const ReadingScreen({
    Key? key,
    required this.repository,
    this.initialSurah,
    this.initialVerseIndex,
    this.initialVerseId,
  }) : super(key: key);

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  List<Verse> verses = [];
  bool _useThaiV3 = true;
  String _currentSurah = '1';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    // If coming from another screen, repository might already be init.
    // If not, it returns instantly.
    await widget.repository.init();
    
    if (widget.initialSurah != null) {
      if (widget.initialVerseId != null) {
        // We need to load surah first, then find the index.
        _loadSurah(widget.initialSurah!);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final index = verses.indexWhere((v) => v.id == widget.initialVerseId);
          if (index != -1) {
            Provider.of<ProgressProvider>(context, listen: false).itemScrollController.jumpTo(index: index);
          }
        });
      } else {
        _loadSurah(widget.initialSurah!, jumpToIndex: widget.initialVerseIndex ?? 0);
      }
    } else {
      // Fallback to progress provider
      final provider = Provider.of<ProgressProvider>(context, listen: false);
      while (!provider.isInitialized) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      _loadSurah(provider.currentSurahId, jumpToIndex: provider.lastVerseIndex);
    }
  }

  void _loadSurah(String surahId, {int jumpToIndex = 0}) {
    setState(() {
      _isLoading = true;
      _currentSurah = surahId;
    });

    final provider = Provider.of<ProgressProvider>(context, listen: false);
    provider.setCurrentSurah(surahId);

    final loadedVerses = widget.repository.getSurahVerses(surahId);
    provider.setTotalVerses(loadedVerses.length);

    setState(() {
      verses = loadedVerses;
      _isLoading = false;
    });

    if (jumpToIndex > 0 && verses.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final provider = Provider.of<ProgressProvider>(context, listen: false);
        Future.delayed(const Duration(milliseconds: 300), () {
          provider.itemScrollController.jumpTo(index: jumpToIndex);
        });
      });
    }
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Consumer<SettingsProvider>(
          builder: (context, settings, child) {
            return Padding(
              padding: EdgeInsets.only(
                top: 24.0,
                left: 24.0,
                right: 24.0,
                bottom: 24.0 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Display Settings', style: GoogleFonts.prompt(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    
                    // Dark Mode Toggle
                    CheckboxListTile(
                      title: Text('Dark Mode', style: GoogleFonts.prompt()),
                      value: settings.isDarkMode,
                      activeColor: Colors.teal,
                      onChanged: (val) {
                        if (val != null) settings.toggleDarkMode(val);
                      },
                    ),
                    
                    // Arabic Display Toggle
                    CheckboxListTile(
                      title: Text('Always Show Arabic Text', style: GoogleFonts.prompt()),
                      subtitle: Text('If unchecked, click the eye icon to reveal.', style: GoogleFonts.prompt(fontSize: 12)),
                      value: settings.alwaysShowArabic,
                      activeColor: Colors.teal,
                      onChanged: (val) {
                        if (val != null) settings.toggleAlwaysShowArabic(val);
                      },
                    ),

                    // Translation Version
                    CheckboxListTile(
                      title: Text('Use Thai V3 Translation', style: GoogleFonts.prompt()),
                      subtitle: Text('Uncheck to use Thai V2 Original.', style: GoogleFonts.prompt(fontSize: 12)),
                      value: _useThaiV3,
                      activeColor: Colors.teal,
                      onChanged: (val) {
                        setState(() {
                          _useThaiV3 = val ?? true;
                        });
                      },
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Divider(),
                    ),

                    // Arabic Font Family Choice
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Arabic Font Style', style: GoogleFonts.prompt(fontWeight: FontWeight.w500)),
                          DropdownButton<String>(
                            value: settings.arabicFontFamily,
                            dropdownColor: settings.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                            style: GoogleFonts.prompt(
                              color: settings.isDarkMode ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                            underline: Container(), // Hide standard underline
                            items: const [
                              DropdownMenuItem(value: 'UthmanicHafs', child: Text('Uthmanic Hafs')),
                              DropdownMenuItem(value: 'AmiriQuran', child: Text('Amiri Quran')),
                              DropdownMenuItem(value: 'ScheherazadeNew', child: Text('Scheherazade New')),
                              DropdownMenuItem(value: 'Amiri', child: Text('Amiri Regular')),
                            ],
                            onChanged: (val) {
                              if (val != null) settings.setArabicFontFamily(val);
                            },
                          ),
                        ],
                      ),
                    ),

                    // Arabic Font Size Choice
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Arabic Font Size', style: GoogleFonts.prompt(fontWeight: FontWeight.w500)),
                              Text(
                                '${settings.arabicFontSize.round()} px',
                                style: GoogleFonts.prompt(
                                  color: Colors.teal,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: settings.arabicFontSize,
                            min: 20.0,
                            max: 48.0,
                            divisions: 14,
                            activeColor: Colors.teal,
                            inactiveColor: Colors.teal.withOpacity(0.2),
                            onChanged: (val) {
                              settings.setArabicFontSize(val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ProgressProvider>(context, listen: false);

    // List of Surah numbers 1-114
    final surahList = List.generate(114, (i) => (i + 1).toString());

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal.shade800,
        elevation: 0,
        title: Row(
          children: [
            // Surah Dropdown
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _currentSurah,
                  dropdownColor: Colors.teal.shade900,
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                  style: GoogleFonts.prompt(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 16),
                  items: surahList.map((String id) {
                    return DropdownMenuItem<String>(
                      value: id,
                      child: Text(widget.repository.getSurahName(id)),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null && newValue != _currentSurah) {
                      _loadSurah(newValue);
                      // Force provider to update surah mapping
                      provider.itemPositionsListener.itemPositions.removeListener(() {});
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Ayat Dropdown (if verses loaded)
            if (!_isLoading && verses.isNotEmpty)
              Consumer<ProgressProvider>(
                builder: (context, progressProv, child) {
                  return DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: (progressProv.lastVerseIndex >= 0 && progressProv.lastVerseIndex < verses.length)
                          ? verses[progressProv.lastVerseIndex].id
                          : (verses.isNotEmpty ? verses[0].id : '1'),
                      hint: Text('Ayat', style: GoogleFonts.prompt(color: Colors.white70)),
                      dropdownColor: Colors.teal.shade900,
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                      style: GoogleFonts.prompt(color: Colors.white, fontSize: 14),
                      items: verses.map((verse) {
                        return DropdownMenuItem<String>(
                          value: verse.id,
                          child: Text('Ayat ${verse.id}'),
                        );
                      }).toList(),
                      onChanged: (String? ayatId) {
                        if (ayatId != null) {
                          final index = verses.indexWhere((v) => v.id == ayatId);
                          if (index != -1) {
                            progressProv.itemScrollController.scrollTo(
                              index: index,
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeInOutCubic,
                            );
                          }
                        }
                      },
                    ),
                  );
                },
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmarks),
            tooltip: 'Bookmarks',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => BookmarksScreen(repository: widget.repository)),
              );

              if (result != null) {
                final targetSurah = result['surahId'];
                
                if (targetSurah == _currentSurah) {
                  // Scroll smoothly within the same surah
                  final targetIndex = result.containsKey('verseIndex')
                      ? result['verseIndex'] as int
                      : verses.indexWhere((v) => v.id == result['verseId']);
                  if (targetIndex != -1) {
                    Future.delayed(const Duration(milliseconds: 100), () {
                      provider.itemScrollController.scrollTo(
                        index: targetIndex,
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeInOutCubic,
                      );
                    });
                  }
                } else {
                  // Load different surah and jump
                  if (result.containsKey('verseIndex')) {
                    _loadSurah(targetSurah, jumpToIndex: result['verseIndex']);
                  } else if (result.containsKey('verseId')) {
                    final targetVerseId = result['verseId'];
                    
                    setState(() {
                      _isLoading = true;
                      _currentSurah = targetSurah;
                    });

                    final loadedVerses = widget.repository.getSurahVerses(targetSurah);

                    setState(() {
                      verses = loadedVerses;
                      _isLoading = false;
                    });

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final index = verses.indexWhere((v) => v.id == targetVerseId);
                      if (index != -1) {
                        Future.delayed(const Duration(milliseconds: 300), () {
                          provider.itemScrollController.jumpTo(index: index);
                        });
                      }
                    });
                  }
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: _showSettingsSheet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : ScrollablePositionedList.builder(
              itemCount: verses.length,
              itemBuilder: (context, index) {
                return VerseCard(
                  key: ValueKey('${verses[index].surahId}_${verses[index].id}'),
                  verse: verses[index],
                  repository: widget.repository,
                  useThaiV3: _useThaiV3,
                  index: index,
                );
              },
              itemScrollController: provider.itemScrollController,
              itemPositionsListener: provider.itemPositionsListener,
              padding: const EdgeInsets.only(top: 16, bottom: 450),
            ),
    );
  }
}
