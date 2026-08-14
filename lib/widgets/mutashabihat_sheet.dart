import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/offline_quran_database_service.dart';

class MutashabihatSheet extends StatefulWidget {
  final String verseKey;

  const MutashabihatSheet({
    super.key,
    required this.verseKey,
  });

  static Future<void> show(BuildContext context, String verseKey) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => MutashabihatSheet(verseKey: verseKey),
    );
  }

  @override
  State<MutashabihatSheet> createState() => _MutashabihatSheetState();
}

class _MutashabihatSheetState extends State<MutashabihatSheet> {
  Map<String, dynamic>? _currentVerse;
  List<Map<String, dynamic>>? _mutashabihat;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final current = await OfflineQuranDatabaseService.getVerse(widget.verseKey);
      final similar = await OfflineQuranDatabaseService.getMutashabihat(widget.verseKey);

      if (mounted) {
        setState(() {
          _currentVerse = current;
          _mutashabihat = similar;
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      debugPrint("Error loading mutashabihat: $e\n$stack");
      if (mounted) {
        setState(() {
          _mutashabihat = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.sync_alt_rounded,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'โองการที่คล้ายคลึงกัน (آيات متشابهة)',
                        style: GoogleFonts.notoSansThai(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        'ช่วยในการจำและเปรียบเทียบโองการที่คล้ายกัน',
                        style: GoogleFonts.notoSansThai(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          Divider(
            height: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.25),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _mutashabihat == null || _mutashabihat!.isEmpty
                    ? Center(
                        child: Text(
                          'ไม่พบโองการที่คล้ายคลึงกันสำหรับ ${widget.verseKey}',
                          style: GoogleFonts.notoSansThai(
                            fontSize: 15,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        physics: const BouncingScrollPhysics(),
                        children: [
                          // Current verse banner
                          if (_currentVerse != null) ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: colorScheme.primary.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primary,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'โองการปัจจุบัน: ${widget.verseKey}',
                                          style: GoogleFonts.notoSansThai(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: colorScheme.onPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _currentVerse!['text_uthmani'] as String? ?? '',
                                    textDirection: TextDirection.rtl,
                                    style: const TextStyle(
                                      fontFamily: 'Tajweed',
                                      fontSize: 22,
                                      height: 1.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          Text(
                            'โองการที่ตรงกัน (${_mutashabihat!.length} โองการ)',
                            style: GoogleFonts.notoSansThai(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 10),

                          ..._mutashabihat!.map((item) {
                            final vKey = item['verse_key'] as String? ?? '';
                            final textUthmani = item['text_uthmani'] as String? ?? '';
                            final transTh = item['translation_th'] as String? ?? '';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: colorScheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: colorScheme.secondaryContainer,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'ซูเราะฮ์ $vKey',
                                          style: GoogleFonts.notoSansThai(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: colorScheme.onSecondaryContainer,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  Text(
                                    textUthmani,
                                    textDirection: TextDirection.rtl,
                                    style: const TextStyle(
                                      fontFamily: 'Tajweed',
                                      fontSize: 22,
                                      height: 1.8,
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  Divider(
                                    height: 1,
                                    color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                                  ),
                                  const SizedBox(height: 10),

                                  Text(
                                    transTh,
                                    style: GoogleFonts.notoSansThai(
                                      fontSize: 14,
                                      height: 1.5,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
