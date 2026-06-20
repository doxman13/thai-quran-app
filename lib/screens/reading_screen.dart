// lib/screens/reading_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/progress_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/local_reading_provider.dart';
import '../models/verse.dart';
import '../widgets/verse_card.dart';
import '../data/quran_repository.dart';
import 'bookmarks_screen.dart';

class ReadingScreen extends StatefulWidget {
  final QuranRepository repository;
  final String? initialSurah;
  final int? initialVerseIndex;
  final String? initialVerseId;
  final bool openSettingsPanel;

  const ReadingScreen({
    Key? key,
    required this.repository,
    this.initialSurah,
    this.initialVerseIndex,
    this.initialVerseId,
    this.openSettingsPanel = false,
  }) : super(key: key);

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  List<Verse> verses = [];
  String _currentSurah = '1';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await widget.repository.init();

    if (widget.initialSurah != null) {
      if (widget.initialVerseId != null) {
        _loadSurah(widget.initialSurah!);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final index = verses.indexWhere((v) => v.id == widget.initialVerseId);
          if (index != -1) {
            Provider.of<ProgressProvider>(
              context,
              listen: false,
            ).setVerseIndexAndScroll(index);
          }
        });
      } else {
        _loadSurah(
          widget.initialSurah!,
          jumpToIndex: widget.initialVerseIndex ?? 0,
        );
      }

      if (widget.openSettingsPanel) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showSettingsSheet();
        });
      }
    } else {
      final provider = Provider.of<ProgressProvider>(context, listen: false);
      while (!provider.isInitialized) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      _loadSurah(provider.currentSurahId, jumpToIndex: provider.lastVerseIndex);
    }
  }

  void _loadSurah(String surahId, {int jumpToIndex = 0}) {
    final provider = Provider.of<ProgressProvider>(context, listen: false);
    provider.setChangingSurah(true); // Disable listener

    setState(() {
      _isLoading = true;
      _currentSurah = surahId;
    });

    provider.setCurrentSurah(surahId);

    final loadedVerses = widget.repository.getSurahVerses(surahId);
    provider.setTotalVerses(loadedVerses.length);

    setState(() {
      verses = loadedVerses;
      _isLoading = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (verses.isNotEmpty && provider.itemScrollController.isAttached) {
          provider.itemScrollController.jumpTo(index: jumpToIndex);
        }
        // Safely re-enable listener after jump finishes
        Future.delayed(const Duration(milliseconds: 100), () {
          provider.setChangingSurah(false);
        });
      });
    });
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Consumer<SettingsProvider>(
          builder: (context, settings, child) {
            final isDark = settings.isDarkMode;
            final primaryColor = settings.getPrimaryColor();

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
                    Text(
                      'Display Settings',
                      style: GoogleFonts.prompt(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Dark Mode Toggle
                    SwitchListTile(
                      title: Text(
                        'Dark Mode',
                        style: GoogleFonts.prompt(fontWeight: FontWeight.w500),
                      ),
                      value: settings.isDarkMode,
                      activeColor: primaryColor,
                      onChanged: (val) => settings.toggleDarkMode(val),
                    ),

                    // Arabic Display Toggle
                    SwitchListTile(
                      title: Text(
                        'Always Show Arabic Text',
                        style: GoogleFonts.prompt(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        'If unchecked, click the eye icon to reveal.',
                        style: GoogleFonts.prompt(fontSize: 12),
                      ),
                      value: settings.alwaysShowArabic,
                      activeColor: primaryColor,
                      onChanged: (val) => settings.toggleAlwaysShowArabic(val),
                    ),

                    const Divider(height: 24),
                    Text(
                      'Translation Languages',
                      style: GoogleFonts.prompt(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      title: Text(
                        'Thai V3 (Revised)',
                        style: GoogleFonts.prompt(),
                      ),
                      value: settings.showThaiV3,
                      activeColor: primaryColor,
                      onChanged: (val) {
                        if (val != null) settings.setShowThaiV3(val);
                      },
                    ),
                    CheckboxListTile(
                      title: Text(
                        'Thai V2 (Original)',
                        style: GoogleFonts.prompt(),
                      ),
                      value: settings.showThaiV2,
                      activeColor: primaryColor,
                      onChanged: (val) {
                        if (val != null) settings.setShowThaiV2(val);
                      },
                    ),
                    CheckboxListTile(
                      title: Text('English', style: GoogleFonts.prompt()),
                      value: settings.showEnglish,
                      activeColor: primaryColor,
                      onChanged: (val) {
                        if (val != null) settings.setShowEnglish(val);
                      },
                    ),

                    const Divider(height: 32),

                    // Color Themes Options
                    Text(
                      'Theme Palette',
                      style: GoogleFonts.prompt(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildColorDot(context, 'teal', Colors.teal, settings),
                        _buildColorDot(
                          context,
                          'emerald',
                          const Color(0xFF10B981),
                          settings,
                        ),
                        _buildColorDot(context, 'blue', Colors.blue, settings),
                        _buildColorDot(
                          context,
                          'purple',
                          Colors.purple,
                          settings,
                        ),
                        _buildColorDot(
                          context,
                          'sepia',
                          Colors.amber,
                          settings,
                        ),
                        _buildColorDot(
                          context,
                          'grey',
                          Colors.blueGrey,
                          settings,
                        ),
                      ],
                    ),

                    const Divider(height: 32),

                    // Arabic Font Family Choice
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Arabic Font Style',
                          style: GoogleFonts.prompt(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        DropdownButton<String>(
                          value: settings.arabicFontFamily,
                          dropdownColor: isDark
                              ? const Color(0xFF1E293B)
                              : Colors.white,
                          style: GoogleFonts.prompt(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                          underline: Container(),
                          items: const [
                            DropdownMenuItem(
                              value: 'UthmanicHafs',
                              child: Text('Uthmanic Hafs'),
                            ),
                            DropdownMenuItem(
                              value: 'AmiriQuran',
                              child: Text('Amiri Quran'),
                            ),
                            DropdownMenuItem(
                              value: 'ScheherazadeNew',
                              child: Text('Scheherazade New'),
                            ),
                            DropdownMenuItem(
                              value: 'Amiri',
                              child: Text('Amiri Regular'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) settings.setArabicFontFamily(val);
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Arabic Font Size Choice
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Arabic Font Size',
                              style: GoogleFonts.prompt(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${settings.arabicFontSize.round()} px',
                              style: GoogleFonts.prompt(
                                color: primaryColor,
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
                          activeColor: primaryColor,
                          inactiveColor: primaryColor.withOpacity(0.2),
                          onChanged: (val) => settings.setArabicFontSize(val),
                        ),
                        const Divider(height: 32),
                        Text(
                          'Web Sync Settings',
                          style: GoogleFonts.prompt(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: TextEditingController(
                            text: settings.webHostUrl,
                          ),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (val) {
                            settings.setWebHostUrl(val);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Web host URL updated!'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          style: GoogleFonts.prompt(fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Web Server URL',
                            labelStyle: GoogleFonts.prompt(
                              color: primaryColor,
                              fontSize: 13,
                            ),
                            hintText: 'e.g. https://your-quran-web.com',
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            suffixIcon: const Icon(Icons.sync),
                          ),
                        ),
                        const Divider(height: 32),
                        Text(
                          'Offline Audits Cache',
                          style: GoogleFonts.prompt(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FutureBuilder<int>(
                          future: SharedPreferences.getInstance().then(
                            (prefs) =>
                                (prefs.getStringList('local_audits') ?? [])
                                    .length,
                          ),
                          builder: (context, snapshot) {
                            final count = snapshot.data ?? 0;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'You have $count unsynced audit reports saved locally.',
                                  style: GoogleFonts.prompt(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.blueGrey.shade300
                                        : Colors.blueGrey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: count > 0
                                            ? () async {
                                                final prefs =
                                                    await SharedPreferences.getInstance();
                                                final cached =
                                                    prefs.getStringList(
                                                      'local_audits',
                                                    ) ??
                                                    [];
                                                final jsonl = cached
                                                    .map((e) {
                                                      try {
                                                        final Map<
                                                          String,
                                                          dynamic
                                                        >
                                                        data = json.decode(e);
                                                        return json.encode({
                                                          'timestamp':
                                                              data['timestamp'] ??
                                                              DateTime.now()
                                                                  .toIso8601String(),
                                                          'surahId':
                                                              data['surahId'],
                                                          'verseId':
                                                              data['verseId'],
                                                          'comment':
                                                              data['comment'],
                                                        });
                                                      } catch (_) {
                                                        return e;
                                                      }
                                                    })
                                                    .join('\n');

                                                await Clipboard.setData(
                                                  ClipboardData(text: jsonl),
                                                );
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Copied audits in JSONL format to clipboard!',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              }
                                            : null,
                                        icon: const Icon(
                                          Icons.copy_all,
                                          size: 18,
                                        ),
                                        label: Text(
                                          'Copy JSONL',
                                          style: GoogleFonts.prompt(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryColor,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: count > 0
                                            ? () async {
                                                final confirm = await showDialog<bool>(
                                                  context: context,
                                                  builder: (ctx) => AlertDialog(
                                                    title: Text(
                                                      'Clear Cache?',
                                                      style: GoogleFonts.prompt(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    content: Text(
                                                      'Are you sure you want to clear all locally cached audit logs?',
                                                      style:
                                                          GoogleFonts.prompt(),
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                              ctx,
                                                              false,
                                                            ),
                                                        child: Text(
                                                          'Cancel',
                                                          style:
                                                              GoogleFonts.prompt(),
                                                        ),
                                                      ),
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                              ctx,
                                                              true,
                                                            ),
                                                        child: Text(
                                                          'Clear',
                                                          style:
                                                              GoogleFonts.prompt(
                                                                color:
                                                                    Colors.red,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                                if (confirm == true) {
                                                  final prefs =
                                                      await SharedPreferences.getInstance();
                                                  await prefs.remove(
                                                    'local_audits',
                                                  );
                                                  if (context.mounted) {
                                                    Navigator.pop(
                                                      context,
                                                    ); // close sheet to refresh
                                                    _showSettingsSheet(); // reopen sheet
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Local audit cache cleared.',
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                }
                                              }
                                            : null,
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                          color: Colors.red,
                                        ),
                                        label: Text(
                                          'Clear Cache',
                                          style: GoogleFonts.prompt(
                                            fontSize: 12,
                                            color: Colors.red,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          side: const BorderSide(
                                            color: Colors.red,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ],
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

  Widget _buildColorDot(
    BuildContext context,
    String colorName,
    Color color,
    SettingsProvider settings,
  ) {
    final isSelected = settings.themeColor == colorName;
    return GestureDetector(
      onTap: () => settings.setThemeColor(colorName),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: colorName == 'sepia' ? const Color(0xFFE5C158) : color,
            shape: BoxShape.circle,
          ),
          child: isSelected
              ? const Icon(Icons.check, color: Colors.white, size: 18)
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ProgressProvider>(context, listen: false);
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = settings.getPrimaryColor();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.repository.getSurahName(_currentSurah),
              style: GoogleFonts.prompt(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Consumer2<LocalReadingProvider, ProgressProvider>(
              builder: (context, localReading, progressProv, child) {
                final activeProfile = localReading.activeProfile;
                final profileName = activeProfile?.name ?? 'Free Read';
                final activeVerseId = (progressProv.lastVerseIndex >= 0 &&
                        progressProv.lastVerseIndex < verses.length)
                    ? verses[progressProv.lastVerseIndex].id
                    : '1';
                return Text(
                  '$profileName · $_currentSurah:$activeVerseId',
                  style: GoogleFonts.prompt(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmarks_outlined, color: Colors.white),
            tooltip: 'Bookmarks',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      BookmarksScreen(repository: widget.repository),
                ),
              );

              if (result != null) {
                final targetSurah = result['surahId'];

                if (targetSurah == _currentSurah) {
                  final targetIndex = result.containsKey('verseIndex')
                      ? result['verseIndex'] as int
                      : verses.indexWhere((v) => v.id == result['verseId']);
                  if (targetIndex != -1) {
                    provider.setVerseIndexAndScroll(targetIndex);
                  }
                } else {
                  if (result.containsKey('verseIndex')) {
                    _loadSurah(targetSurah, jumpToIndex: result['verseIndex']);
                  } else if (result.containsKey('verseId')) {
                    final targetVerseId = result['verseId'];
                    _loadSurah(targetSurah);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final index = verses.indexWhere(
                        (v) => v.id == targetVerseId,
                      );
                      if (index != -1) {
                        provider.setVerseIndexAndScroll(index);
                      }
                    });
                  }
                }
              }
            },
          ),
          IconButton(
            icon: Text(
              'Aa',
              style: GoogleFonts.prompt(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            tooltip: 'Appearance',
            onPressed: _showSettingsSheet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : ScrollablePositionedList.builder(
              itemCount: verses.length + 1,
              itemBuilder: (context, index) {
                if (index == verses.length) {
                  return _buildCompletionCard(
                    context,
                    provider,
                    settings,
                    isDark,
                  );
                }
                return VerseCard(
                  key: ValueKey('${verses[index].surahId}_${verses[index].id}'),
                  verse: verses[index],
                  repository: widget.repository,
                  index: index,
                );
              },
              itemScrollController: provider.itemScrollController,
              itemPositionsListener: provider.itemPositionsListener,
              padding: const EdgeInsets.only(top: 12, bottom: 100),
            ),
      bottomNavigationBar: _isLoading
          ? null
          : Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 10,
                bottom: MediaQuery.of(context).padding.bottom + 10,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? Colors.blueGrey.shade800.withOpacity(0.4)
                        : Colors.grey.shade200,
                    width: 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Consumer2<LocalReadingProvider, ProgressProvider>(
                builder: (context, localReading, progressProv, child) {
                  final currentIndex = progressProv.lastVerseIndex;
                  final totalCount = verses.length;
                  final hasPrev = currentIndex > 0;
                  final hasNext = currentIndex < totalCount - 1;

                  final dropdownItems = List.generate(totalCount, (index) {
                    final verseId = verses[index].id;
                    return DropdownMenuItem<int>(
                      value: index,
                      child: Text(
                        '$_currentSurah:$verseId',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  });

                  final safeValue = (currentIndex >= 0 && currentIndex < totalCount) ? currentIndex : 0;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: hasPrev
                            ? () {
                                progressProv.setVerseIndexAndScroll(currentIndex - 1);
                              }
                            : null,
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        style: IconButton.styleFrom(
                          disabledForegroundColor: isDark ? Colors.blueGrey.shade800 : Colors.grey.shade300,
                          foregroundColor: primaryColor,
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 40,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isDark ? Colors.blueGrey.shade800.withOpacity(0.5) : Colors.grey.shade300,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              key: ValueKey('reading_ayah_dropdown_${_currentSurah}_$totalCount'),
                              value: safeValue,
                              isExpanded: true,
                              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                              items: dropdownItems,
                              onChanged: (index) {
                                if (index != null) {
                                  progressProv.setVerseIndexAndScroll(index);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _showSettingsSheet,
                        icon: Text(
                          'ع',
                          style: GoogleFonts.amiri(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: primaryColor.withOpacity(0.12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: primaryColor.withOpacity(0.3)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: hasNext
                            ? () {
                                progressProv.setVerseIndexAndScroll(currentIndex + 1);
                              }
                            : null,
                        icon: const Icon(Icons.arrow_forward_ios_rounded),
                        style: IconButton.styleFrom(
                          disabledForegroundColor: isDark ? Colors.blueGrey.shade800 : Colors.grey.shade300,
                          foregroundColor: primaryColor,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }

  Widget _buildCompletionCard(
    BuildContext context,
    ProgressProvider progressProv,
    SettingsProvider settingsProv,
    bool isDark,
  ) {
    final primaryColor = settingsProv.getPrimaryColor();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.blueGrey.shade800.withOpacity(0.5)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '🎉 สิ้นสุดซูเราะฮฺแล้ว',
            style: GoogleFonts.prompt(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.blueGrey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'คุณอ่านมาถึงอายะฮฺสุดท้ายของซูเราะฮฺ $_currentSurah แล้ว ทำเครื่องหมายเพื่อบันทึกสถิติของคุณ',
            textAlign: TextAlign.center,
            style: GoogleFonts.prompt(
              fontSize: 13,
              color: isDark ? Colors.blueGrey.shade300 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    progressProv.incrementCompletedRead();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'บันทึกการอ่านซูเราะฮฺที่จบแล้ว!',
                          style: GoogleFonts.prompt(color: Colors.white),
                        ),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  child: Text(
                    '📖 อ่านจบแล้ว',
                    style: GoogleFonts.prompt(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    progressProv.incrementCompletedCheck();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'บันทึกการตรวจสอบซูเราะฮฺที่จบแล้ว!',
                          style: GoogleFonts.prompt(color: Colors.white),
                        ),
                        backgroundColor: const Color(0xFFF43F5E), // Rose 500
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBE123C), // Rose 700
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  child: Text(
                    '🔍 ตรวจสอบจบแล้ว',
                    style: GoogleFonts.prompt(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
