import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qcf_quran/qcf_quran.dart' as qcf;
import 'package:volume_key_board/volume_key_board.dart';

import '../models/mushaf_models.dart';
import '../theme/app_theme.dart';
import 'mushaf_reader_screen.dart';
import '../data/quran_foundation_repository.dart';
import '../data/quran_repository.dart';
import '../models/hifz_task.dart';
import '../providers/hifz_session_provider.dart';
import '../widgets/gundal_tally_widget.dart';
import '../providers/mushaf_audio_provider.dart';

import 'package:wakelock_plus/wakelock_plus.dart';
import '../providers/settings_provider.dart';

String _toArabicVerseNumber(int number) {
  return '';
}



class HifzMemorizeScreen extends StatefulWidget {
  final QuranRepository quranRepository;
  final QuranFoundationRepository foundationRepository;
  final int initialPage;
  final int surahNumber;
  final int startVerse;
  final int endVerse;

  const HifzMemorizeScreen({
    super.key,
    required this.quranRepository,
    required this.foundationRepository,
    this.initialPage = 1,
    this.surahNumber = 1,
    this.startVerse = 1,
    this.endVerse = 3,
  });

  @override
  State<HifzMemorizeScreen> createState() => _HifzMemorizeScreenState();
}

class _HifzMemorizeScreenState extends State<HifzMemorizeScreen> {
  static const _channel = MethodChannel('com.example.thai_quran_app/key_events');
  late HifzSessionProvider _hifzProvider;
  bool _isMushafView = true;
  bool _isSurahMode = true;
  int _selectedPage = 1;
  late int _selectedRepeatStart;
  late int _selectedStartVerse;
  late int _selectedEndVerse;
  late int _currentPage;
  final FocusNode _focusNode = FocusNode();
  final FocusNode _hiddenInputFocusNode = FocusNode();
  final TransformationController _transformationController = TransformationController();

  bool _isVerseHidden(int verseNum, HifzTask? currentTask) {
    if (currentTask == null) return false;
    if (verseNum < _selectedRepeatStart || verseNum > _selectedEndVerse) {
      return false;
    }
    final targetVerse = currentTask.verseNumbers.last;
    if (verseNum > targetVerse) {
      return true;
    }
    if (verseNum < targetVerse) {
      if (currentTask.type == TaskType.cumulativeLink) {
        return currentTask.mode == TextVisibilityMode.hidden;
      } else {
        return false;
      }
    }
    return currentTask.mode == TextVisibilityMode.hidden;
  }

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _selectedPage = widget.initialPage;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showRangeSelectionModal(context);
        final settings = Provider.of<SettingsProvider>(context, listen: false);
        if (settings.keepAwake) {
          WakelockPlus.enable();
        }
      }
    });
    _selectedRepeatStart = widget.startVerse;
    _selectedStartVerse = widget.startVerse;
    _selectedEndVerse = widget.endVerse;
    _hifzProvider = HifzSessionProvider(
      surahNumber: widget.surahNumber,
      repeatStart: _selectedRepeatStart,
      startVerse: _selectedStartVerse,
      endVerse: _selectedEndVerse,
    );

    DateTime? lastClickTime;
    _channel.setMethodCallHandler((call) async {
      if (call.method == "keyClick") {
        final audio = Provider.of<MushafAudioProvider>(context, listen: false);
        if (audio.isPlaying) return; // Disable key clicks when playing recitation

        final now = DateTime.now();
        if (lastClickTime != null && now.difference(lastClickTime!).inMilliseconds < 450) {
          return;
        }
        lastClickTime = now;
        if (mounted && !_hifzProvider.isSessionCompleted) {
          _hifzProvider.incrementProgress();
          HapticFeedback.lightImpact();
        }
      }
    });
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    _hiddenInputFocusNode.dispose();
    _focusNode.dispose();
    _transformationController.dispose();
    WakelockPlus.disable();
    super.dispose();
  }



// Note: To allow selecting a surah inside _showRangeSelectionModal, we'll track a tempSurah variable in the modal builder state
  void _showRangeSelectionModal(BuildContext context) {
    int tempSurah = _hifzProvider.currentTask?.verseNumbers.isNotEmpty == true 
        ? _hifzProvider.surahNumber 
        : widget.surahNumber;
    int tempRepeat = _selectedRepeatStart;
    int tempStart = _selectedStartVerse;
    int tempEnd = _selectedEndVerse;
    bool tempIsSurahMode = _isSurahMode;
    int tempPage = _selectedPage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final colorScheme = Theme.of(context).colorScheme;
            final textTheme = Theme.of(context).textTheme;
            
            // Logic for calculating max ranges depending on mode
            int totalVerses = qcf.getVerseCount(tempSurah);
            int minVerse = 1;
            int maxVerse = totalVerses;
            
            if (!tempIsSurahMode) {
              final pageItems = qcf.getPageData(tempPage);
              if (pageItems.isNotEmpty) {
                 final first = pageItems.first;
                 final last = pageItems.last;
                 // Limit to the surah of the first item on that page
                 tempSurah = first['surah'];
                 minVerse = first['start'];
                 maxVerse = last['end'];
              }
            }

            final count = tempEnd - tempStart + 1;

            return Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Select Memorization Range',
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('Surah Mode')),
                        ButtonSegment(value: false, label: Text('Page Mode')),
                      ],
                      selected: {tempIsSurahMode},
                      onSelectionChanged: (val) {
                        setModalState(() {
                          tempIsSurahMode = val.first;
                          if (!tempIsSurahMode) {
                             final pageItems = qcf.getPageData(tempPage);
                             if (pageItems.isNotEmpty) {
                               tempSurah = pageItems.first['surah'];
                               tempStart = pageItems.first['start'];
                               tempRepeat = tempStart;
                               tempEnd = pageItems.last['end'];
                               if (tempEnd - tempStart + 1 > 30) tempEnd = tempStart + 29;
                             }
                          } else {
                             tempSurah = widget.surahNumber;
                             tempStart = 1;
                             tempRepeat = 1;
                             tempEnd = 3;
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (tempIsSurahMode) ...[
                    Text('Select Surah', style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: tempSurah,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: List.generate(114, (i) => i + 1).map((v) {
                        final surahName = widget.quranRepository.getSurahName(v.toString());
                        return DropdownMenuItem(
                          value: v,
                          child: Text('$v. $surahName'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            tempSurah = val;
                            final limit = qcf.getVerseCount(tempSurah);
                            tempStart = 1;
                            tempRepeat = 1;
                            tempEnd = limit > 3 ? 3 : limit;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    Text('Select Page', style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: tempPage,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: List.generate(604, (i) => i + 1).map((v) => DropdownMenuItem(value: v, child: Text('Page $v'))).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            tempPage = val;
                            final pageItems = qcf.getPageData(tempPage);
                             if (pageItems.isNotEmpty) {
                               tempSurah = pageItems.first['surah'];
                               tempStart = pageItems.first['start'];
                               tempRepeat = tempStart;
                               tempEnd = pageItems.last['end'];
                               if (tempEnd - tempStart + 1 > 30) tempEnd = tempStart + 29;
                             }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Repeat From',
                              style: textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<int>(
                              value: tempRepeat,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              items: List.generate(maxVerse - minVerse + 1, (i) => minVerse + i)
                                  .where((v) => v <= tempStart)
                                  .map((v) {
                                return DropdownMenuItem(
                                  value: v,
                                  child: Text('Verse $v'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(() {
                                    tempRepeat = val;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Start Verse',
                              style: textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<int>(
                              value: tempStart,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              items: List.generate(maxVerse - minVerse + 1, (i) => minVerse + i).map((v) {
                                return DropdownMenuItem(
                                  value: v,
                                  child: Text('Verse $v'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(() {
                                    tempStart = val;
                                    if (tempRepeat > tempStart) tempRepeat = tempStart;
                                    if (tempEnd < tempStart) tempEnd = tempStart;
                                    if (tempEnd - tempStart + 1 > 30) tempEnd = tempStart + 29;
                                    if (tempEnd > maxVerse) tempEnd = maxVerse;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'End Verse',
                              style: textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<int>(
                              value: tempEnd,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              items: List.generate(maxVerse - minVerse + 1, (i) => minVerse + i)
                                  .where((v) => v >= tempStart && (v - tempStart + 1) <= 30)
                                  .map((v) {
                                return DropdownMenuItem(
                                  value: v,
                                  child: Text('Verse $v'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(() {
                                    tempEnd = val;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Selected Verses:'),
                        Text(
                          '$count / 30',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: count > 30 ? colorScheme.error : colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedRepeatStart = tempRepeat;
                          _selectedStartVerse = tempStart;
                          _selectedEndVerse = tempEnd;
                          _isSurahMode = tempIsSurahMode;
                          _selectedPage = tempPage;
                          if (tempIsSurahMode) {
                            _currentPage = qcf.getPageNumber(tempSurah, tempStart);
                          } else {
                            _currentPage = tempPage;
                          }
                          // If Surah changed, make sure to re-init HifzSessionProvider with the new Surah
                          if (_hifzProvider.surahNumber != tempSurah) {
                            _hifzProvider = HifzSessionProvider(
                              surahNumber: tempSurah,
                              repeatStart: tempRepeat,
                              startVerse: tempStart,
                              endVerse: tempEnd,
                            );
                          } else {
                            _hifzProvider.initRoutine(tempRepeat, tempStart, tempEnd);
                          }
                        });
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Apply Range'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showGundalReportModal(BuildContext context, HifzSessionProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;
        final elapsed = DateTime.now().difference(provider.startTime);
        final elapsedStr =
            '${elapsed.inMinutes}m ${elapsed.inSeconds % 60}s';

        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Gundal Session Analytics Report',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              // Session Stats Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      context,
                      'Total Recitations',
                      '${provider.totalRecitationsCount}',
                      Icons.repeat,
                    ),
                    _buildStatItem(
                      context,
                      'Time Elapsed',
                      elapsedStr,
                      Icons.timer_outlined,
                    ),
                    _buildStatItem(
                      context,
                      'Routine Done',
                      '${(provider.routineProgress * 100).round()}%',
                      Icons.check_circle_outline,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Gundal Grid Matrix',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Table(
                    border: TableBorder.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    children: [
                      TableRow(
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHigh,
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Text(
                              'Verse',
                              style: textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Text(
                              'Gundal Tally Marks',
                              style: textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                      for (int v = provider.startVerse; v <= provider.endVerse; v++)
                        TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Text(
                                'Verse $v',
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Center(
                                child: GundalTallyWidget(
                                  count: provider.verseTallyMap[v] ?? 0,
                                  height: 28,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text('Close Report'),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Icon(icon, color: colorScheme.primary, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ChangeNotifierProvider<HifzSessionProvider>.value(
      value: _hifzProvider,
      child: Consumer<HifzSessionProvider>(
        builder: (context, provider, child) {
          final currentTask = provider.currentTask;
          final isCompleted = provider.isSessionCompleted;

          return Focus(
            focusNode: _focusNode,
            autofocus: true,
            canRequestFocus: true,
            child: Scaffold(
            appBar: AppBar(
              title: const Text('Hifz Memorization'),
              centerTitle: true,
              actions: [
                 Consumer<MushafAudioProvider>(
                   builder: (context, audio, _) {
                     final isPlayingCurrentRange = audio.isPlaying &&
                         audio.playlist.isNotEmpty &&
                         audio.playlist.any((v) => v.surahId == provider.surahNumber.toString() &&
                             int.parse(v.verseId) >= _selectedStartVerse &&
                             int.parse(v.verseId) <= _selectedEndVerse);

                     if (audio.isLoading) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12.0),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }

                      return IconButton(
                        icon: Icon(isPlayingCurrentRange ? Icons.stop_circle_outlined : Icons.play_circle_outline),
                        tooltip: isPlayingCurrentRange ? 'Stop Playback' : 'Play Range',
                        onPressed: () {
                          if (isPlayingCurrentRange) {
                            audio.stop();
                          } else {
                            // Generate list of verse IDs from _selectedStartVerse to _selectedEndVerse
                            final verseIds = List.generate(
                              _selectedEndVerse - _selectedStartVerse + 1,
                              (i) => _selectedStartVerse + i,
                            );
                            audio.playRange(provider.surahNumber.toString(), verseIds);
                          }
                        },
                      );
                   },
                 ),
                 IconButton(
                   icon: Icon(provider.isPeekActive ? Icons.visibility : Icons.visibility_off),
                   tooltip: provider.isPeekActive ? 'Hide Verses' : 'Reveal Verses',
                   onPressed: () {
                     provider.setPeekActive(!provider.isPeekActive);
                   },
                 ),
                 IconButton(
                   icon: const Icon(Icons.tune_outlined),
                   tooltip: 'Select Range (Max 10)',
                   onPressed: () => _showRangeSelectionModal(context),
                 ),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, icon: Icon(Icons.view_list), label: Text('List')),
                    ButtonSegment(value: true, icon: Icon(Icons.menu_book), label: Text('Mushaf')),
                  ],
                  selected: {_isMushafView},
                  onSelectionChanged: (val) {
                    setState(() {
                      _isMushafView = val.first;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.analytics_outlined),
                  tooltip: 'Session Report',
                  onPressed: () => _showGundalReportModal(context, provider),
                ),
              ],
            ),
            body: Stack(
              children: [
                // Hidden 0x0 TextField to forcefully attach Flutter to Android InputMethodManager on page load
                Positioned(
                  left: -100,
                  top: -100,
                  child: SizedBox(
                    width: 1,
                    height: 1,
                    child: TextField(
                      focusNode: _hiddenInputFocusNode,
                      autofocus: true,
                      readOnly: true,
                      showCursor: false,
                      enableInteractiveSelection: false,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Column(
                    children: [
                      // Header info
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        color: colorScheme.surfaceContainerLow,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Target Verses: $_selectedStartVerse - $_selectedEndVerse',
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.chevron_left, size: 20),
                                  onPressed: _currentPage > 1
                                      ? () => setState(() => _currentPage--)
                                      : null,
                                ),
                                Text(
                                  'Page $_currentPage',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.chevron_right, size: 20),
                                  onPressed: _currentPage < 604
                                      ? () => setState(() => _currentPage++)
                                      : null,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Container(
                          margin: _isMushafView
                              ? const EdgeInsets.symmetric(horizontal: 4, vertical: 8)
                              : const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(_isMushafView ? 8 : 16),
                            border: Border.all(
                              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                            ),
                          ),
                          child: isCompleted
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.stars_rounded,
                                        size: 64,
                                        color: colorScheme.primary,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Routine Completed!',
                                        style: textTheme.headlineMedium
                                            ?.copyWith(
                                          color: colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Great job memorizing these verses.',
                                        style: textTheme.bodyMedium,
                                      ),
                                      const SizedBox(height: 24),
                                      FilledButton.icon(
                                        onPressed: () =>
                                            provider.resetSession(),
                                        icon: const Icon(Icons.replay),
                                        label: const Text('Restart Session'),
                                      ),
                                    ],
                                  ),
                                )
                              : _isMushafView
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          final targetKey = currentTask != null && currentTask.verseNumbers.isNotEmpty
                                              ? '${provider.surahNumber}:${currentTask.verseNumbers.first}'
                                              : null;
                                          final isHidden = currentTask != null &&
                                              currentTask.mode == TextVisibilityMode.hidden &&
                                              !provider.isPeekActive;

                                          final availWidth = constraints.maxWidth;
                                          final isTablet = constraints.maxWidth > 600 || constraints.maxHeight > 900;
                                          
                                          // Keep standard sp/h to preserve proper Surah header frame aspect ratio, while scaling font size dynamically
                                          final fontSize = isTablet 
                                              ? (availWidth / 15.0).clamp(32.0, 64.0) 
                                              : (availWidth / 16.0).clamp(22.0, 40.0);

                                          final horizontalPadding = isTablet ? 16.0 : 8.0;
                                          final verticalPadding = isTablet ? 12.0 : 8.0;
                                          final paddedWidth = (constraints.maxWidth - (horizontalPadding * 2)).clamp(100.0, double.infinity);
                                          final paddedHeight = (constraints.maxHeight - (verticalPadding * 2)).clamp(100.0, double.infinity);
                                          return Stack(
                                            children: [
                                              Positioned.fill(
                                                child: Padding(
                                                  padding: const EdgeInsets.all(8.0),
                                                  child: InteractiveViewer(
                                                    transformationController: _transformationController,
                                                    minScale: 1.0,
                                                    maxScale: 3.5,
                                                    child: FutureBuilder<MushafPage>(
                                                      future: widget.foundationRepository.fetchPage(
                                                        mushafId: 2,
                                                        pageNumber: _currentPage,
                                                      ),
                                                      builder: (context, snapshot) {
                                                        if (!snapshot.hasData) {
                                                          return const Center(
                                                            child: CircularProgressIndicator(),
                                                          );
                                                        }
                                                        final mushafPage = snapshot.data!;
                                                        final activeVerseKey = (currentTask != null && currentTask.verseNumbers.isNotEmpty)
                                                            ? '${provider.surahNumber}:${currentTask.verseNumbers.last}'
                                                            : null;
                                                        final activeVerseKeys = currentTask != null
                                                            ? currentTask.verseNumbers.map((v) => '${provider.surahNumber}:$v').toSet()
                                                            : const <String>{};

                                                        final surahStartsByLine = <int, List<String>>{};
                                                        for (final verse in mushafPage.verses) {
                                                          if (verse.verseId != '1' || verse.words.isEmpty) continue;
                                                          final lineNumber = verse.words.first.lineNumber;
                                                          surahStartsByLine.putIfAbsent(lineNumber, () => []).add(verse.surahId);
                                                        }

                                                        final verseEndWords = <MushafWord>{};
                                                        for (final verse in mushafPage.verses) {
                                                          if (verse.words.isNotEmpty) {
                                                            verseEndWords.add(verse.words.last);
                                                          }
                                                        }

                                                        final layout = MushafLayoutProfile.forMushaf(2);
                                                        final fontFamily = widget.foundationRepository.getFontFamily(2, _currentPage);

                                                        return SingleChildScrollView(
                                                          physics: const ClampingScrollPhysics(),
                                                          child: Center(
                                                            child: FittedBox(
                                                              fit: BoxFit.fitWidth,
                                                              child: SizedBox(
                                                                width: layout.pageWidth,
                                                                child: Column(
                                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                                  children: [
                                                                    for (final line in mushafPage.lines) ...[
                                                                      for (final surahId in surahStartsByLine[line.first.lineNumber] ?? const <String>[])
                                                                        QcfSurahHeader(
                                                                          surahNumber: int.tryParse(surahId) ?? 0,
                                                                          colors: AppTheme.colors(isDark: Theme.of(context).brightness == Brightness.dark),
                                                                        ),
                                                                      Builder(
                                                                        builder: (context) {
                                                                          return MushafLine(
                                                                            line: line,
                                                                            fontFamily: fontFamily,
                                                                            mushafId: 2,
                                                                            pageNumber: mushafPage.pageNumber,
                                                                            lineWidth: layout.lineWidth,
                                                                            lineHeight: layout.lineHeight,
                                                                            lineVerticalPadding: layout.lineVerticalPadding,
                                                                            wordPadding: layout.wordPadding,
                                                                            verseEndWords: verseEndWords,
                                                                            surahStartsByLine: surahStartsByLine,
                                                                            highlightedVerseKey: activeVerseKey,
                                                                            highlightedVerseKeys: activeVerseKeys,
                                                                            onVerseTap: (_) {},
                                                                            onVerseLongPressStart: (_) {},
                                                                            onVerseLongPress: (_) {},
                                                                            isVerseHidden: (verseKey) {
                                                                              final parts = verseKey.split(':');
                                                                              if (parts.length < 2) return false;
                                                                              final surahNum = int.tryParse(parts[0]) ?? 0;
                                                                              final verseNum = int.tryParse(parts[1]) ?? 0;
                                                                              if (surahNum != provider.surahNumber) return false;
                                                                              return _isVerseHidden(verseNum, currentTask);
                                                                            },
                                                                            isPeekActive: provider.isPeekActive,
                                                                          );
                                                                        },
                                                                      ),
                                                                    ],
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                              ),
                                           if (isHidden)
                                                Positioned.fill(
                                                  child: GestureDetector(
                                                    behavior: HitTestBehavior.opaque,
                                                    onLongPressStart: (_) => provider.setPeekActive(true),
                                                    onLongPressEnd: (_) => provider.setPeekActive(false),
                                                    onLongPressCancel: () => provider.setPeekActive(false),
                                                    onLongPressUp: () => provider.setPeekActive(false),
                                                    onTapUp: (_) => provider.setPeekActive(false),
                                                    child: const SizedBox.expand(),
                                                  ),
                                                ),
                                               Positioned(
                                                 bottom: 16,
                                                 right: 16,
                                                 child: Column(
                                                   mainAxisSize: MainAxisSize.min,
                                                   children: [
                                                     FloatingActionButton.small(
                                                       heroTag: 'zoom_in',
                                                       backgroundColor: colorScheme.surfaceContainerHigh.withValues(alpha: 0.9),
                                                       child: Icon(Icons.zoom_in, color: colorScheme.primary),
                                                       onPressed: () {
                                                         final Matrix4 matrix = _transformationController.value.clone();
                                                         final double currentScale = matrix.getMaxScaleOnAxis();
                                                         final double newScale = (currentScale + 0.25).clamp(1.0, 3.5);
                                                         final double ratio = newScale / currentScale;
                                                         final double x = paddedWidth / 2;
                                                         final double y = paddedHeight / 2;
                                                         
                                                         matrix.translate(x, y);
                                                         matrix.scale(ratio);
                                                         matrix.translate(-x, -y);
                                                         _transformationController.value = matrix;
                                                       },
                                                     ),
                                                     const SizedBox(height: 8),
                                                     FloatingActionButton.small(
                                                       heroTag: 'zoom_out',
                                                       backgroundColor: colorScheme.surfaceContainerHigh.withValues(alpha: 0.9),
                                                       child: Icon(Icons.zoom_out, color: colorScheme.primary),
                                                       onPressed: () {
                                                         final Matrix4 matrix = _transformationController.value.clone();
                                                         final double currentScale = matrix.getMaxScaleOnAxis();
                                                         final double newScale = (currentScale - 0.25).clamp(1.0, 3.5);
                                                         final double ratio = newScale / currentScale;
                                                         final double x = paddedWidth / 2;
                                                         final double y = paddedHeight / 2;
                                                         
                                                         matrix.translate(x, y);
                                                         matrix.scale(ratio);
                                                         matrix.translate(-x, -y);
                                                         _transformationController.value = matrix;
                                                       },
                                                     ),
                                                   ],
                                                 ),
                                               ),
                                            ],
                                          );
                                        },
                                      ),
                                    )
                                  : ListView.separated(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: (_selectedEndVerse - _selectedStartVerse + 1),
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    int verseNum = _selectedStartVerse + index;
                                    bool isTarget = currentTask != null &&
                                        currentTask.verseNumbers
                                            .contains(verseNum);
                                    bool isHidden = _isVerseHidden(verseNum, currentTask) &&
                                        !provider.isPeekActive;

                                    return GestureDetector(
                                      onLongPressStart: isHidden
                                          ? (_) => provider.setPeekActive(true)
                                          : null,
                                      onLongPressEnd: isHidden
                                          ? (_) => provider.setPeekActive(false)
                                          : null,
                                      onLongPressCancel: isHidden
                                          ? () => provider.setPeekActive(false)
                                          : null,
                                      onLongPressUp: isHidden ? () => provider.setPeekActive(false) : null,
                                      onTapUp: isHidden ? (_) => provider.setPeekActive(false) : null,
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: isTarget
                                              ? (isHidden
                                                  ? colorScheme.primaryContainer.withValues(alpha: 0.04)
                                                  : colorScheme.primaryContainer.withValues(alpha: 0.08))
                                              : colorScheme.surfaceContainerLow,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color: isTarget
                                                ? colorScheme.primary
                                                : colorScheme.outlineVariant
                                                    .withValues(alpha: 0.3),
                                            width: isTarget ? 1.5 : 1.0,
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            if (!isHidden)
                                              IconButton(
                                                icon: Icon(
                                                  Icons.volume_up_outlined,
                                                  color: isTarget ? colorScheme.primary : null,
                                                ),
                                                onPressed: () {
                                                  context.read<MushafAudioProvider>().playSingleIndependentVerse('${provider.surahNumber}:$verseNum');
                                                },
                                              ),
                                            Expanded(
                                              child: FutureBuilder<String>(
                                                future: widget.quranRepository.fetchArabicVerse(
                                                  provider.surahNumber.toString(),
                                                  verseNum.toString(),
                                                ),
                                                builder: (context, snapshot) {
                                                  final arabicText = snapshot.data ?? '';
                                                  final cleanedText = arabicText.split(' | ').join(' ');
                                                   return Directionality(
                                                    textDirection: TextDirection.rtl,
                                                    child: RichText(
                                                      textAlign: TextAlign.right,
                                                      softWrap: true,
                                                      text: TextSpan(
                                                        style: const TextStyle(
                                                          fontFamily: 'UthmanicHafs',
                                                          fontSize: 28,
                                                          height: 2.0,
                                                          letterSpacing: 0.0,
                                                          wordSpacing: 0.0,
                                                        ),
                                                        children: [
                                                          TextSpan(
                                                            text: cleanedText,
                                                            style: TextStyle(
                                                              color: isHidden
                                                                  ? Colors.transparent
                                                                  : (isTarget
                                                                      ? textTheme.bodyLarge?.color
                                                                      : textTheme.bodyLarge?.color?.withValues(alpha: 0.6)),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            )
                                      ],
                                      ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
      ],
    ),
            bottomNavigationBar: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (currentTask != null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentTask.type == TaskType.singleVerse
                                      ? 'Verse ${currentTask.verseNumbers.join(', ')} (${currentTask.mode.name.toUpperCase()})'
                                      : 'Link ${currentTask.verseNumbers.first}–${currentTask.verseNumbers.last} (${currentTask.mode.name.toUpperCase()})',
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currentTask.mode == TextVisibilityMode.hidden
                                      ? 'Recite from memory'
                                      : 'Read clearly',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: colorScheme.outlineVariant
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                GundalTallyWidget(
                                  count: currentTask.currentProgress,
                                  height: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '/ ${currentTask.targetRepetitions}',
                                  style: textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Consumer<MushafAudioProvider>(
                        builder: (context, audio, _) {
                          final isPlaying = audio.isPlaying;
                          return SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: isPlaying ? null : () => provider.incrementProgress(),
                              icon: const Icon(Icons.add_circle_outline),
                              label: const Text('Tally (+1)'),
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          );
                        },
                      ),
                    ] else ...[
                      Text(
                        'Session Completed',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: () =>
                            _showGundalReportModal(context, provider),
                        icon: const Icon(Icons.assessment_outlined),
                        label: const Text('View Analytics Report'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
        },
      ),
    );
  }
}
